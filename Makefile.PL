use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'YAML::AppConfig',
    ABSTRACT     => 'Manage config files with YAML and variable references.',
    AUTHOR       => 'Matthew O\'Connor <matthew@canonical.org>',
    VERSION_FROM => 'lib/YAML/AppConfig.pm',
    PREREQ_PM    => {
        get_yamls(),
        'Storable'   => 0,
        'Carp'       => 0,
        'UNIVERSAL'  => 0,
    },
);

sub get_yamls {
    my @yamls;
    for my $info (['YAML::Syck' => 0], [YAML => 0.38]) {
        eval "require $info->[0]; 0;";
        push @yamls, @$info unless $@;
    }
    die "YAML >= 0.38 or YAML::Syck >= 0 required.\n" unless @yamls;
    return @yamls;
}
