use Test::Most;

use WebService::NationBuilder;
use Data::Dumper;
use Carp qw(croak);
use Log::Any::Adapter;
use Log::Dispatch;

my @ARGS = qw(NB_ACCESS_TOKEN NB_SUBDOMAIN);
for (@ARGS) {croak "$_ not in ENV" unless defined $ENV{$_}};
my %params = map { (lc substr $_, 3) => $ENV{$_} } @ARGS;

sub _enable_logging {
    my $log = Log::Dispatch->new(
        outputs => [
            [
                'Screen',
                min_level => 'debug',
                stderr    => 1,
                newline   => 1,
            ]
        ],
    );

    Log::Any::Adapter->set(
        'Dispatch',
        dispatcher => $log,
    );
}

my $nb = WebService::NationBuilder->new(%params);
my $page_txt = 'paginating with %s page(s)';
my @page_totals = (1, 10, 100, 1000);
my $max_id = 10000;
my $test_tag = 'test_tag';
#_enable_logging;

subtest 'set_tag, get_person_tags' => sub {
    for my $p (@{$nb->get_people}) {
        my $set_tag = $nb->set_tag($p->{id}, $test_tag);
        my $expected_tag = { person_id => $p->{id}, tag => $test_tag };
        cmp_deeply $set_tag, $expected_tag,
            "set tag \"$test_tag\" for person @{[$p->{id}]}"
            or diag explain $set_tag;
        my $get_person_tags = $nb->get_person_tags($p->{id});
        cmp_bag $get_person_tags, [$expected_tag],
            "get tag \"$test_tag\" for person @{[$p->{id}]}"
            or diag explain $get_person_tags;
    }
};

subtest 'get_tags' => sub {
    for (@page_totals) {
        ok $nb->get_tags({per_page => $_}),
            sprintf $page_txt, $_;
    }

    my $all_tags = $nb->get_tags;
    cmp_deeply $all_tags, superbagof({name => $test_tag}),
        "found common tag \"$test_tag\""
        or diag explain $all_tags;
};

subtest 'delete_tag' => sub {
    for my $p (@{$nb->get_people}) {
        my $tags = $nb->get_person_tags($p->{id});
        for my $tag (@$tags) {
            ok $nb->delete_tag($p->{id}, $tag->{tag}),
                "delete tag \"@{[$tag->{tag}]}\" for person @{[$p->{id}]}";
        }
        $tags = $nb->get_person_tags($p->{id});
        cmp_bag $tags, [],
            "get no tags for person @{[$p->{id}]}"
            or diag explain $tags;
    }

    my $all_tags = $nb->get_tags;
    cmp_deeply $all_tags, superbagof({name => $test_tag}),
        "found common tag \"$test_tag\""
        or diag explain $all_tags;
};

subtest 'match_person' => sub {
    for my $p (@{$nb->get_people}) {
        my $match_params = {};
        my @matches = qw(email first_name last_name phone mobile);
        for (@matches) {
            $match_params->{$_} = $p->{$_} if $p->{$_};
        }
        my $mp = $nb->match_person($match_params);
        cmp_deeply $mp, superhashof($p),
            "found matching person @{[$p->{email}]}"
            or diag explain $mp;
    }

    is $nb->match_person => undef,
        'unmatched person undef';

    is $nb->match_person({email => $max_id}) => undef,
        "unmatched person $max_id";
};

subtest 'get_person' => sub {
    for my $p (@{$nb->get_people}) {
        my $mp = $nb->get_person($p->{id});
        cmp_deeply $mp, superhashof($p),
            "found identified person @{[$p->{id}]}"
            or diag explain $mp;
    }

    dies_ok { $nb->get_person }
        'id param missing';

    is $nb->get_person($max_id) => undef,
        "undefined person $max_id";
};

subtest 'get_people' => sub {
    for (@page_totals) {
        ok $nb->get_people({per_page => $_}),
            sprintf $page_txt, $_;
    }
};

subtest 'get_sites' => sub {
    is $nb->get_sites->[0]{slug}, $params{subdomain},
        'nationbuilder slug matches subdomain';

    for (@page_totals) {
        ok $nb->get_sites({per_page => $_}),
            sprintf $page_txt, $_;
    }
};

done_testing;