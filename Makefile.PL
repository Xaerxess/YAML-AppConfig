use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'YAML::AppConfig',
    ABSTRACT     => 'Manage config files with YAML and variable references.',
    AUTHOR       => 'Matthew O\'Connor <matthew@canonical.org>',
    VERSION_FROM => 'lib/YAML/AppConfig.pm',
    PREREQ_PM    => {
        'YAML::Syck' => 0,
        'YAML'       => 0.38,
        'Storable'   => 0,
        'Carp'       => 0,
        'UNIVERSAL'  => 0,
    },
);

print "\nOnly one of YAML or YAML::Syck is required.\n\n";
