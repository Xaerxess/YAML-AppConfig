package YAML::AppConfig;
use strict;
use warnings;
use Carp;
use UNIVERSAL qw(isa);
use Storable qw(dclone);  # For Deep Copy

our $VERSION = '0.12';

# Load YAML::Syck and, failing that, load YAML.
eval {
    require YAML::Syck;
    YAML::Syck->import(qw(Load LoadFile));
};
if ($@) {
    require YAML;
    YAML->import(qw(Load LoadFile));
}

#########################
# Class Methods: Public
#########################
sub new {
    my ($class, %args) = @_;
    my $self = bless( \%args, ref($class) || $class );
    $self->{stack} = [];  # For finding circular references.

    # Load config from file, then load from a string.
    $self->{config} = {};
    $self->{config} = LoadFile( $self->{file} ) if exists $self->{file};
    $self->{config} = Load( $self->{string} ) if exists $self->{string};
    $self->{config} = dclone( $self->{object}->config ) 
        if exists $self->{object};
    $self->_install_accessors();  # Install convenience accessors.

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
    my @parts = split /(\$(?:{\w+}|\w+))/, $value;
    for my $part (@parts) {
        if ( $part =~ /^\$(?:{(\w+)}|(\w+))$/) {
            my $name = $1 || $2;
            if ( exists $self->config->{$name} ) {
                $part = $self->_get($name) unless ref $self->config->{$name};
            }
        }
    }
    @parts = map { defined($_) ? $_ : "" } @parts;
    return join "", @parts;
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
    $conf->config->{etc_dr} = "/usr/local/etc";

    # Notice that when variables change that that affects other variables:
    $config->get_foo_dir;          # now returns /usr/local/etc/foo
    $config->get_some_array->[0];  # returns /usr/local/etc/foo/place

=head1 DESCRIPTION

YAML::AppConfig extends the work done in L<Config::YAML> and
L<YAML::ConfigFile> to allow variable reference between settings.  Essentialy
your configuration file is a hash serialized to YAML.  Scalar values that have
$foo_var type values in them will have interpolation done on them.  If
$foo_var is a key in the configuration file it will be substituted, otherwise
it will be left alone.  $foo_var must be a reference to a scalar value and not
a hash or array, otherwise it won't be interpolated.

Either L<YAML> or L<YAML::Syck> is used underneath.  If L<YAML::Syck> is found
it will be used over L<YAML>.

=head1 USING VARIABLES

Variables names must match one of C</\$\w+/> or C</\${\w+}/>.  Just like in
Perl the C<${foo}> form is to let you have values of the form C<${foo}bar> and
have the variable be treated as C<$foo> instead of C<$foobar>.  

If a variable is not recognized it will be left as is in the value, it won't be
interpolated away or cause a warning.  Unknown variables are not recognized, as
are variables that refer to references (e.g. hashes or arrays).  Currently
variables can only address items in the top-most level of the YAML
configuration file (i.e. the top most level of the hash the conf file
represents).

There is currently no way to escape a variable.  For simple cases this is not a
problem because unrecongnized variables are left as is.  However, if you have a
setting named C<foo> in the top of your YAML file and you want to use a literal
value of C<'$foo'> then you are, in a way, out of luck.  As a work around, you
can access the raw values from the Perl side by passing in C<$no_resolve> to
C<get()>.  I realize this is not ideal and there are still cases were you are
SOL, but I haven't hit this problem yet and so I have not been inclined to
solve it.

=head1 METHODS

=head2 new

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

=back

=head2 get(key, [no_resolve])

Given C<$key> the value of that setting is returned, same as C<get_$key>.  If
C<$no_resolve> is passed in then the raw value associated with C<$key> is
returned, no variable interpolation is done.

=head2 set(key, value)

Similar to C<get()> except you can also provide a value for the setting.

=head2 get_*

Convenience methods to retrieve values using a method, see C<get>.  For
example if foo_bar is a configuration value in your YAML file then
C<get_foo_bar> retrieves its value.  These methods are curried versions of
C<get>.  These functions all take a single optional argument, C<$no_resolve>,
which is the same as C<get()'s> C<$no_resolve>.

=head2 set_*

A convience method to set values using a method, see C<set> and C<get_*>.
These methods are curried versions of C<set>.

=head2 config

Returns the hash reference to the raw config hash.  None of the values are
interpolated, this is just the raw data.

=head2 config_keys

Returns the keys in C<config()> sorted from first to last.

=head1 AUTHORS

Original implementations by Kirrily "Skud" Robert (as L<YAML::ConfigFile>) and
Shawn Boyette (as L<Config::YAML>).

Matthew O'Connor E<lt>matthew@canonical.orgE<gt>

=head1 SEE ALSO

L<YAML>, L<YAML::Syck>, L<Config::YAML>, L<YAML::ConfigFile>

=head1 COPYRIGHT

Copyright 2006 Matthew O'Connor, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
