package YAML::AppConfig;
use strict;
use warnings;
use Carp;
use UNIVERSAL qw(isa);
use Storable qw(dclone);  # For Deep Copy

####################
# Global Variables
####################
our $VERSION = '0.14';
our @YAML_PREFS = qw(YAML::Syck YAML);

#########################
# Class Methods: Public
#########################
sub new {
    my ($class, %args) = @_;
    my $self = bless( \%args, ref($class) || $class );

    # Load a YAML parser.
    $self->{yaml_class} = $self->_load_yaml_class();

    # Load config from file, string, or object.
    if ( exists $self->{file} ) {
        my $load_file = eval "\\&$self->{yaml_class}::LoadFile";
        $self->{config} = $load_file->( $self->{file} );
    } elsif ( exists $self->{string} ) {
        my $load = eval "\\&$self->{yaml_class}::Load";
        $self->{config} = $load->( $self->{string} );
    } elsif ( exists $self->{object} ) {
        $self->{config} = dclone( $self->{object}->{config} );
    } else {
        $self->{config} = {};
    }

    # Initialize internal state
    $self->_install_accessors();  # Install convenience accessors.
    $self->{stack} = [];  # For finding circular references.

    return $self;
}

#############################
# Instance Methods: Public
#############################
sub config {
    my $self = shift;
    return $self->{config};
}

sub config_keys {
    my $self = shift;
    return sort keys %{$self->config};
}

sub get {
    my $self = shift;
    $self->{stack} = [];    # Don't know if we exited cleanly, so empty stack.
    return $self->_get(@_);
}

# Inner get, so we can clear the stack above.  Listed here for readability.
sub _get {
    my ( $self, $key, $no_resolve ) = @_;
    return unless exists $self->config->{$key};
    return $self->config->{$key} if $self->{no_resolve} or $no_resolve;
    croak "Circular reference in $key detected."
        if grep {$key eq $_} @{$self->{stack}};
    push @{$self->{stack}}, $key;
    my $value = $self->_resolve_refs($self->config->{$key});
    pop @{$self->{stack}};
    return $value;
}

sub set {
    my ($self, $key, $value) = @_;
    return $self->config->{$key} = $value;
}

sub merge {
    my ( $self, %args ) = @_;
    my $other_conf = $self->new( %args );
    for my $key ( $other_conf->config_keys ) {
        $self->set( $key, $other_conf->get( $key, 'no vars' ) );
    }
}

##############################
# Instance Methods: Private
##############################

# void _resolve_refs(Scalar $value)
#
# Recurses on $value until a non-reference scalar is found, in which case we
# defer to _resolve_scalar.  In this manner things like hashes and arrays are
# traversed depth-first.
sub _resolve_refs {
    my ( $self, $value ) = @_;
    if ( not ref $value ) {
        $value = $self->_resolve_scalar($value);
    }
    elsif ( isa $value, 'HASH' ) {
        $value = dclone($value);
        for my $key ( keys %$value) {
            $value->{$key} = $self->_resolve_refs( $value->{$key} );
        }
        return $value;
    }
    elsif ( isa $value, 'ARRAY' ) {
        $value = dclone($value);
        for my $item (@$value) {
            $item = $self->_resolve_refs( $item );
        }
    }
    elsif ( isa $value, 'SCALAR' ) {
        $value = $self->_resolve_scalar($$value);
    } 
    else {
        my ($class, $type) = map ref, ($self, $value);
        die "${class}::_resolve_refs() can't handle $type references.";
    }

    return $value;
}

# void _resolve_scalar(String $value)
#
# This function should only be called with strings (or numbers), not
# references.  $value is treated as a string and is searched for $foo type
# variables, which are then resolved.  The new string with variables resolved
# is returned.
sub _resolve_scalar {
    my ( $self, $value ) = @_;
    return unless defined $value;
    my @parts = grep length, # Empty strings are useless, discard them
                     split /((?<!\\)\$(?:{\w+}|\w+))/, $value;
    for my $part (@parts) {
        if ( $part =~ /^(?<!\\)\$(?:{(\w+)}|(\w+))$/) {
            my $name = $1 || $2;
            $part = $self->_get($name) if exists $self->config->{$name};
        } else {
            $part =~ s/(\\*)\\(\$(?:{(\w+)}|(\w+)))/$1$2/g; # Unescape slashes
        }
    }
    return $parts[0] if @parts == 1 and ref $parts[0]; # Preserve references
    return join "", map { defined($_) ? $_ : "" } @parts;
}

# void _load_yaml_class
#
# Attempts to load a YAML class that can parse YAML for us.  We prefer the
# yaml_class attribute over everything, then fall back to a previously loaded
# YAML parser from @YAML_PREFS, and failing that try to load a parser from
# @YAML_PREFS.
sub _load_yaml_class {
    my $self = shift;

    # Always use what we were given.
    if (defined $self->{yaml_class}) {
        eval "require $self->{yaml_class}; 0;";
        croak "$@\n" if $@;
        return $self->{yaml_class};
    }

    # Use what's already been loaded.
    for my $module (@YAML_PREFS) {
        my $filename = $module . ".pm";
        $filename =~ s{::}{/};
        return $self->{yaml_class} = $module if exists $INC{$filename};
    }

    # Finally, try and load something.
    for my $module (@YAML_PREFS) {
        eval "require $module; 0;";
        return $self->{yaml_class} = $module unless $@;
    }

    die "Could not load: " . join(" or ", @YAML_PREFS);
}

# void _install_accessors(void)
#
# Installs convienence methods for getting and setting configuration values.
# These methods are just curryed versions of get() and set().
sub _install_accessors {
    my $self = shift;
    for my $key ($self->config_keys) {
        next unless $key and $key =~ /^[a-zA-Z_]\w*$/;
        for my $method (qw(get set)) {
            no strict 'refs';
            no warnings 'redefine';
            my $method_name = ref($self) . "::${method}_$key";
            *{$method_name} = sub { $_[0]->$method($key, $_[1]) };
        }
    }
}

1;
__END__

=head1 NAME

YAML::AppConfig - Manage configuration files with YAML and variable reference.

=head1 SYNOPSIS

    use YAML::AppConfig;

    my $string = <<'YAML';
    ---
    etc_dir: /opt/etc
    foo_dir: $etc_dir/foo
    bar_dir : ${foo_dir}bar
    some_array:
        - $foo_dir/place
    YAML

    # Can also load form a file or other YAML::AppConfig object.  
    # Just use file => or object => instead of string =>
    my $conf = YAML::AppConfig->new(string => $string);

    # Get variables in two different ways, both equivalent.
    $conf->get("etc_dir");    # returns /opt/etc
    $conf->get_foo_dir;       # returns /opt/etc/foo

    # Get at the raw, uninterpolated values, in three equivalent ways:
    $conf->get("etc_dir", 1); # returns '$etc_dir/foo'
    $conf->get_etc_dir(1);    # returns '$etc_dir/foo'
    $conf->config->{foo_dir}; # returns '$etc_dir/foo'

    # Set etc_dir in three different ways, all equivalent.
    $conf->set("etc_dir", "/usr/local/etc");
    $conf->set_etc_dir("/usr/local/etc");
    $conf->config->{etc_dir} = "/usr/local/etc";

    # Notice that changed variables affect other variables:
    $config->get_foo_dir;          # now returns /usr/local/etc/foo
    $config->get_some_array->[0];  # returns /usr/local/etc/foo/place

    # You can escape variables for concatenation purposes:
    $config->get_bar_dir;  # Returns '/usr/local/etc/foobar'

=head1 DESCRIPTION

YAML::AppConfig extends the work done in L<Config::YAML> and
L<YAML::ConfigFile> to allow variable reference between settings.  Essentialy
your configuration file is a hash serialized to YAML.  Scalar values that have
$foo_var type values in them will have interpolation done on them.  If $foo_var
is a key in the configuration file it will be substituted, otherwise it will be
left alone.  $foo_var must be a reference to a scalar value and not a hash or
array, otherwise it won't be interpolated.

Either L<YAML> or L<YAML::Syck> is used underneath.  You can also specify your
own YAML parser by using the C<yaml_class> attribute to C<new()>.  By default
the value of the C<yaml_class> attribute is preferred over everything.  Failing
that, we check to see if C<YAML::Syck> or C<YAML> is loaded, and if so use that
(prefering Syck).  If nothing is loaded and the C<yaml_class> attribute was not
given then we try to load a YAML parser, starting with C<YAML::Syck> and then
trying C<YAML>.  If this is Too AI for you and bites your ass then you can
force behavior using C<yaml_class>, which is really why it exists.

=head1 USING VARIABLES

Variable names refer to items at the top of the YAML configuration.  There is
currently no way to refer to items nested inside the configuration.  If a
variable is not known, because it doesn't match the name of a top level
configuration key, then no substitution is done on it and it is left verbatim
in the value.

Variables names must match one of C</\$\w+/> or C</\${\w+}/>.  Just like in
Perl the C<${foo}> form is to let you have values of the form C<${foo}bar> and
have the variable be treated as C<$foo> instead of C<$foobar>.  

You can escape a variable by using a backslash before the dollar sign.  For
example C<\$foo> will result in a literal C<$foo> being used, and thus no
interpolation will be done on it.  If you should want a literal C<\$foo> then
use two slashes, C<\\$foo>.  Should you want a literal C<\\$foo> then use three
slashes, and so on.  Escaping can be used with C<${foo}> style variables too.

Variables can be references to more complex data structures.  So it's possible
to define a list and assign it to a top level configuration key and then reuse
that list anywhere else in the configuration file.  Just like in Perl, if a
variable refering to a reference is used in a string the raw memory address
will be its value, so be warned.

=head1 METHODS

=head2 new(%args)

Creates a new YAML::AppConfig object and returns it.  new() accepts the
following key values pairs:

=over 8

=item file

The name of the file which contains your YAML configuration.

=item string

A string containing your YAML configuration.

=item object

A L<YAML::AppConfig> object which will be deep copied into your object.

=item no_resolve

If true no attempt at variable resolution is done on calls to C<get()>.

=item yaml_class

The name of the class we should use to find our C<LoadFile> and C<Load>
functions for parsing YAML files and strings, respectively.  The named class
should provide both C<LoadFile> and C<Load> as functions and should be loadable
via C<require>.

=back

=head2 get(key, [no_resolve])

Given C<$key> the value of that setting is returned, same as C<get_$key>.  If
C<$no_resolve> is passed in then the raw value associated with C<$key> is
returned, no variable interpolation is done.

=head2 set(key, value)

Similar to C<get()> except you can also provide a value for the setting.

=head2 get_*([no_resolve])

Convenience methods to retrieve values using a method, see C<get>.  For
example if foo_bar is a configuration value in your YAML file then
C<get_foo_bar> retrieves its value.  These methods are curried versions of
C<get>.  These functions all take a single optional argument, C<$no_resolve>,
which is the same as C<get()'s> C<$no_resolve>.

=head2 set_*(value)

A convience method to set values using a method, see C<set> and C<get_*>.
These methods are curried versions of C<set>.

=head2 config

Returns the hash reference to the raw config hash.  None of the values are
interpolated, this is just the raw data.

=head2 config_keys

Returns the keys in C<config()> sorted from first to last.

=head2 merge(%args)

Merge takes another YAML configuration and merges it into this one.  C<%args>
are the same as those passed to C<new()>, so the configuration can come from a
file, string, or existing L<YAML::AppConfig> object.

=head1 AUTHORS

Matthew O'Connor E<lt>matthew@canonical.orgE<gt>

Original implementations by Kirrily "Skud" Robert (as L<YAML::ConfigFile>) and
Shawn Boyette (as L<Config::YAML>).

=head1 SEE ALSO

L<YAML>, L<YAML::Syck>, L<Config::YAML>, L<YAML::ConfigFile>

=head1 COPYRIGHT

Copyright 2006 Matthew O'Connor, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
