package Sakaki::API::File;
use strict;
use warnings;
use utf8;
use autodie ':all';
use Smart::Args;
use File::Spec::Functions qw(catfile rel2abs);
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Data::Page;
use File::stat;
use Encode qw(decode_utf8);
use Sakaki::Entry;
use File::pushd;
use Fcntl qw(:flock SEEK_END SEEK_SET);

sub create {
    args my $class,
         my $name,
         my $body,
         my $c,
         ;

    if ($name =~ /\.\.|\0/) {
        die "security issue: $name";
    }

    my $filename = uri_escape_utf8($name);
    {
        my $g = pushd($c->root_dir);

        if (-f $filename) {
            die "Already exists";
        }

        open my $fh, '>:utf8', $filename;
        print {$fh} $body;
        close $fh;

        system('git', 'init');
        system('git', 'add', $filename);
        system('git', 'commit', '-m', 'initial import', $filename);
    }

    $name;
}

sub lookup {
    args my $class,
         my $c,
         my $name,
         ;

    my $fullname = catfile($c->root_dir, uri_escape_utf8 $name);
    open my $fh, '<', $fullname;
    my $body = do {local $/; <$fh> };
    close $fh;

    return $body;
}

sub edit {
    args my $class,
         my $c,
         my $name,
         my $body,
         ;

    my $entry = Sakaki::Entry->new(name => $name);
    {
        my $g = pushd($c->root_dir);
        open my $fh, '+<:utf8', $entry->name_raw;
        flock($fh, LOCK_EX);
        my $src = do { local $/, <$fh> };
        if ($src eq $body) {
            return; # no changes
        }
        seek($fh, 0, SEEK_SET);
        print {$fh} $body;
        system('git', 'add', $entry->name_raw);
        system('git', 'commit', '-m', 'modified', $entry->name_raw);
        close $fh;
    }
}

sub recent {
    args my $class,
         my $c,
         my $entries_per_page => 'Int',
         my $current_page => 'Int',
         ;

    my @files;
    opendir my $dh, $c->root_dir;
    while (defined(my $f = readdir($dh))) {
        next if $f =~ /^\./;
        next unless -f catfile($c->root_dir, $f);
        push @files, Sakaki::Entry->new_from_raw($f);
    }
    @files = reverse sort { $a->mtime <=> $b->mtime } @files;

    my $pager = Data::Page->new();
    $pager->total_entries(0+@files);
    $pager->entries_per_page($entries_per_page);
    $pager->current_page($current_page);

    return ([$pager->splice(\@files)], $pager);
}

1;

