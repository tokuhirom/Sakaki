use strict;
use warnings;
use utf8;
use Test::More;

use Sakaki::Repository;
use Sakaki::Entry;
use File::Temp qw(tempdir);
use autodie;

my $tmpdir = tempdir(CLEANUP => 1);

my $repository = Sakaki::Repository->new(root_dir => $tmpdir);
subtest 'create' => sub {
    my $entry = Sakaki::Entry->new(
        name => 'test',
        body => 'OK',
        repository => $repository,
        formatter => 'Sakaki::Formatter::HTML',
    );
    eval {
        $entry->create();
    };
    ok(-f $entry->fullpath);
    ok(!$@) or diag $@;
};

subtest 'lookup' => sub {
    my $entry = $repository->lookup('test');
    ok(-f $entry->fullpath);
    is($entry->body, 'OK');
    is($entry->name, 'test');
    is($entry->formatter, 'Sakaki::Formatter::HTML');
};

subtest 'update' => sub {
    {
        my $entry = $repository->lookup('test');
        $entry->body('O');
        $entry->formatter('Sakaki::Formatter::Xatena');
        $entry->update();
    }

    {
        my $entry = $repository->lookup('test');
        ok(-f $entry->fullpath);
        is($entry->body, 'O');
        is($entry->name, 'test');
        is($entry->formatter, 'Sakaki::Formatter::Xatena');
    }
};

subtest 'log' => sub {
    my $entry = $repository->lookup('test');
    my @log = $entry->get_log();
    is(0+@log, 2);
    like($log[0]->subject, qr(modified));
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

subtest 'remove' => sub {
    my $entry = $repository->lookup('test');
    ok(-f $entry->fullpath);
    $entry->remove();
    ok(!-f $entry->fullpath);
};

subtest 'attachments' => sub {
    my $entry = Sakaki::Entry->new(
        name => 'T2',
        body => 'OK2',
        repository => $repository,
        formatter => 'Sakaki::Formatter::HTML',
    );
    $entry->create();
    {
        note 'add';
        open my $fh, '<', 'tmpl/show.tt';
        $entry->add_attachment('show.tt', $fh);
    }
    {
        note 'open';
        my $a = $entry->get_attachment('show.tt');
        my $fh = $a->openr;
        my $src = do { local $/; <$fh> };
        like($src, qr{include/layout.tt});
        is($a->mime_type, "application/octet-stream");
        is(-s $a->fullpath, -s 'tmpl/show.tt');
    }
    {
        note 'list';
        my @attachments = $entry->list_attachments();
        is(0+@attachments, 1);
        is($attachments[0]->name, 'show.tt');
        ok(-f $attachments[0]->fullpath);
    }
    {
        note 'remove';
        $entry->get_attachment('show.tt')->remove();
        my @attachments = $entry->list_attachments();
        is(0+@attachments, 0, 'removed');
    }
};

done_testing;

