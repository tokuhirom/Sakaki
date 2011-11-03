package Sakaki::Repository;
use strict;
use warnings;
use utf8;
use Carp;
use File::pushd;
use autodie ':all';
use Log::Minimal;
use Fcntl qw(:flock SEEK_END SEEK_SET);
use Smart::Args;
use File::Spec::Functions qw(catfile rel2abs);
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Encode qw(decode_utf8);
use Data::Page;

use Sakaki::Entry;

use Mouse;

has root_dir => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub create {
    my ($self, $entry) = @_;
    $entry // die;

    my $filename = $entry->name_raw;
    infof("creating $filename");
    {
        my $g = pushd($self->root_dir);

        if (-f $filename) {
            die "Already exists";
        }

        {
            open my $fh, '>:utf8', $filename;
            print {$fh} $entry->body;
            close $fh;
        }

        my $formatfile = ".${filename}.format";
        {
            open my $fh, '>:utf8', $formatfile;
            print {$fh} $entry->formatter;
            close $fh;
        }

        system('git', 'init');
        system('git', 'add', $filename, $formatfile);
        system('git', 'commit', '--author', 'Anonymous Coward <anonymous@example.com>', '-m', 'initial import', $filename, $formatfile);
    }
}

sub update {
    my ($self, $entry) = @_;

    {
        my $g = pushd($self->root_dir);
        open my $fh, '+<:utf8', $entry->name_raw;
        flock($fh, LOCK_EX);
        my $src = do { local $/, <$fh> };
        if ($src ne $entry->body) {
            seek($fh, 0, SEEK_SET);
            print {$fh} $entry->body;
            system('git', 'add', $entry->name_raw);
            system('git', 'commit', '--author', 'Anonymous Coward <anonymous@example.com>', '-m', 'modified', $entry->name_raw);
        }
        close $fh;
    }
}

sub lookup {
    my ($self, $name) = @_;
    $name // croak;

    return Sakaki::Entry->new(name => $name, repository => $self);
}

sub get_log {
    my ($self, $entry) = @_;
    $entry // die "Missing mandatory parameter: entry";

    my $log = do {
        my $g = pushd($self->root_dir);
        `git log --patience -p -50 --no-color @{[ $entry->name_raw ]}`;
    };
    return $log;
}

sub get_recent {
    args my $self,
         my $entries_per_page => 'Int',
         my $current_page => 'Int',
         ;

    my @files;
    opendir my $dh, $self->root_dir;
    while (defined(my $f = readdir($dh))) {
        next if $f =~ /^\./;
        next unless -f catfile($self->root_dir, $f);
        push @files,
          Sakaki::Entry->new(
            repository => $self,
            name       => decode_utf8( uri_unescape($f) )
          );
    }
    @files = reverse sort { $a->mtime <=> $b->mtime } @files;

    my $pager = Data::Page->new();
    $pager->total_entries(0+@files);
    $pager->entries_per_page($entries_per_page);
    $pager->current_page($current_page);

    return ([$pager->splice(\@files)], $pager);
}

sub search {
    args my $self,
         my $entries_per_page => 'Int',
         my $current_page => 'Int',
         my $keyword => 'Str',
         ;

    my @files;
    opendir my $dh, $self->root_dir;
    while (defined(my $f = readdir($dh))) {
        next if $f =~ /^\./;
        next unless -f catfile($self->root_dir, $f);
        my $name = decode_utf8( uri_unescape($f) );
        my $entry = $self->lookup($name);
        if ($entry->name =~ /\Q$keyword\E/ || $entry->body =~ /\Q$keyword\E/) {
            push @files, $entry;
        }
    }
    @files = reverse sort { $a->mtime <=> $b->mtime } @files;

    my $pager = Data::Page->new();
    $pager->total_entries(0+@files);
    $pager->entries_per_page($entries_per_page);
    $pager->current_page($current_page);

    return ([$pager->splice(\@files)], $pager);
}

1;

