use strict;
use warnings;
use Test::More tests => 10;
do "t/lib/helpers.pl";
use lib 't/lib';

BEGIN { use_ok('YAML::AppConfig') }

# TEST: Object creation
{
    my $app = YAML::AppConfig->new();
    ok($app, "Instantiated object");
    isa_ok( $app, "YAML::AppConfig", "Asserting isa YAML::AppConfig" );
    ok( $app->can('new'), "\$app has new() method." );
}

# TEST: Loading a different YAML class, string.
{
    my $test_class = 'MatthewTestClass';
    my $app = YAML::AppConfig->new(string => "cows", yaml_class => $test_class);
    ok($app, "Instantiated object");
    isa_ok( $app, "YAML::AppConfig", "Asserting isa YAML::AppConfig." );
    is($app->get_string, "cows", "Testing alternate YAML class (stirng).");
}

# TEST: Loading a different YAML class, file.
{
    my $test_class = 'MatthewTestClass';
    my $app = YAML::AppConfig->new(file => "dogs", yaml_class => $test_class);
    ok($app, "Instantiated object");
    isa_ok( $app, "YAML::AppConfig", "Asserting isa YAML::AppConfig." );
    is($app->get_file, "dogs", "Testing alternate YAML class (file).");
}
