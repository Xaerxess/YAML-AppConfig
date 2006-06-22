use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'YAML::AppConfig',
    ABSTRACT     => 'Manage config files with YAML and variable references.',
    AUTHOR       => 'Matthew O\'Connor <matthew@canonical.org>',
    VERSION_FROM => 'lib/YAML/AppConfig.pm',
    PREREQ_PM    => {
        pick_a_yaml(),
        Storable => 0,
        Carp => 0,
        UNIVERSAL => 0,
    },
);

sub pick_a_yaml {
    eval { require YAML::Syck; };
    return $@ ? ( 'YAML' => 0.38 ) : ( 'YAML::Syck' => 0 );
}
