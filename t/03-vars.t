use strict;
use warnings;
use Test::More tests => 31;
do "t/lib/helpers.pl";

BEGIN { use_ok('YAML::AppConfig') }

# TEST: Variable usage.
{
    my $app = YAML::AppConfig->new( file => 't/data/vars.yaml' );
    ok($app, "Created object.");

    # Check basic retrieval
    is( $app->get_dapper, "life", "Checking variables." );
    is( $app->get_breezy, "life is good", "Checking variables." );
    is( $app->get_hoary, "life is good, but so is food",
        "Checking variables." );
    is( $app->get_stable,
        "life is good, but so is food and so, once again, life is good.",
        "Checking variables." );
    is( $app->get_nonvar, '$these are $non $vars with a var, life',
        "Checking variables." );

    # Check get()'s no resolve flag
    is( $app->get( 'breezy', 1 ), '$dapper is good',
        "Checking variables, no resolve." );
    is( $app->get_hoary(1), '$breezy, but so is food',
        "Checking variables, no resolve." );

    # Check basic setting
    $app->set_dapper("money");
    is( $app->get_dapper, "money", "Checking variables." );
    is( $app->get_breezy, "money is good", "Checking variables." );
    is( $app->get_hoary, "money is good, but so is food",
        "Checking variables." );
    is( $app->get_stable,
        "money is good, but so is food and so, once again, money is good.",
        "Checking variables." );
    is( $app->get_nonvar, '$these are $non $vars with a var, money',
        "Checking variables." );

    # Check that our circular references break.
    for my $n ( 1 .. 4 ) {
        my $method = "get_circ$n";
        eval { $app->$method };
        like( $@, qr/Circular reference/, "Checking that get_circ$n failed" );
    }

    # Break the circular reference.
    $app->set_circ1("dogs");
    is($app->get_circ1, "dogs", "Checking circularity removal.");
    is($app->get_circ2, "dogs lop bop oop", "Checking circularity removal.");
    is($app->get_circ3, "dogs lop bop", "Checking circularity removal.");
    is($app->get_circ4, "dogs lop", "Checking circularity removal.");

    # Test that we can't load up references as vars.
    is( $app->get_norefs, '$list will not render, nor will $hash',
        "Checking that references are not used as variables." );

    # Look in the heart of our deep data structures
    is_deeply($app->get_list,
      [[[[[[[
        [
         'money', 
         "money is good, but so is food and so, once again, money is good.",
        ], 
        "money is good, but so is food" 
      ]]]]]]], "Testing nested list.");
    is_deeply(
        $app->get_hash,
        {
            key => {
                key => {
                    key => {
                        key => { key => 'money is good', other => 'money' },
                        something => 'money'
                    }
                }
            }
        },
        "Testing nested hash."
    );
}

# TEST: no_resolve
{
    my $app
        = YAML::AppConfig->new( file => 't/data/vars.yaml', no_resolve => 1 );
    ok($app, "Created object.");

    # Check basic retrieval
    is( $app->get_dapper, "life", "Checking variables, no_resolve => 1" );
    is( $app->get_breezy, '$dapper is good',
        "Checking variables, no_resolve => 1" );
    is(
        $app->get_hoary, '$breezy, but so is food',
        "Checking variables, no_resolve => 1"
    );
    is(
        $app->get_stable,
        '$hoary and so, once again, $breezy.',
        "Checking variables, no_resolve => 1"
    );
    is(
        $app->get_nonvar, '$these are $non $vars with a var, $dapper',
        "Checking variables, no_resolve => 1"
    );
}
