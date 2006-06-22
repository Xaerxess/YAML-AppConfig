use strict;
use warnings;
use Test::More tests => 4;
do "t/lib/helpers.pl";

BEGIN { use_ok('YAML::AppConfig') }

# TEST: Object creation
{
    my $app = YAML::AppConfig->new();
    ok($app, "Instantiated object");
    isa_ok( $app, "YAML::AppConfig", "Asserting isa YAML::AppConfig" );
    ok( $app->can('new'), "\$app has new() method." );
}
