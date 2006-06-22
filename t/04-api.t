use strict;
use warnings;
use Test::More tests => 10;
do "t/lib/helpers.pl";

BEGIN { use_ok('YAML::AppConfig') }

# TEST: config and config_keys
{
    my $app = YAML::AppConfig->new( file => 't/data/config.yaml' );
    ok( $app, "Object created." );
    is_deeply( $app->config, { foo => 1, bar => 2, eep => '$foo' },
        "config() method." );
    is_deeply( [ $app->config_keys ], [qw(bar eep foo)],
        "config_keys() method." );
}

# TEST: merge
{
    my $app = YAML::AppConfig->new( file => 't/data/basic.yaml' );
    ok( $app, "Object created." );
    is( $app->get_foo, 1, "Checking foo before merge()." );
    is( $app->get_bar, 2, "Checking bar before merge()." );
    $app->merge( file => 't/data/merge.yaml' );
    is( $app->get_foo, 2,  "Checking foo after merge()." );
    is( $app->get_bar, 2,  "Checking bar after merge()." );
    is( $app->get_baz, 3, "Checking bar after merge()." );
}
