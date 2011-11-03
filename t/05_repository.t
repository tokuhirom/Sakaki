use strict;
use warnings;
use utf8;
use Test::More;

use Sakaki::Repository;
use Sakaki::Entry;
use File::Temp qw(tempdir);

my $tmpdir = tempdir();

my $repository = Sakaki::Repository->new(root_dir => $tmpdir);
subtest 'create' => sub {
    eval {
        my $entry = Sakaki::Entry->new(name => 'test', repository => $repository);
        $entry->create();
    };
    ok(!$@) or diag $@;
};

subtest 'log' => sub {
    my $entry = $repository->lookup('test');
    my $log = $entry->get_log();
    like($log, qr(initial));
};

subtest 'recent' => sub {
    my ($rows, $pager) = $repository->get_recent(
        entries_per_page => 50,
        current_page     => 1,
    );
    is(ref($rows), q(ARRAY));
    isa_ok($pager, 'Data::Page');
};

subtest 'search' => sub {
    my ($rows, $pager) = $repository->search(
        keyword => 'test',
        entries_per_page => 50,
        current_page     => 1,
    );
    is(ref($rows), q(ARRAY));
    is(0+@$rows, 1);
    isa_ok($pager, 'Data::Page');
};

done_testing;

