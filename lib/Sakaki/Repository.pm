package Sakaki::Repository;
use strict;
use warnings FATAL => 'all';
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
use Sakaki::Log;
use File::Path;

use Sakaki::Entry;

use Mouse;

has root_dir => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub BUILD {
    my $self = shift;

    mkpath($self->root_dir);

    unless (-f catfile($self->root_dir, 'IndexPage')) {
        my $entry = Sakaki::Entry->new(
            repository => $self,
            name => 'IndexPage',
            body => <<'...',
This is a top page of Sakaki.

- foo
- bar
- baz
...
            formatter => 'Sakaki::Formatter::Xatena',
        );
        $self->create($entry);
    }
    unless (-f catfile($self->root_dir, 'SideBar')) {
        my $entry = Sakaki::Entry->new(
            repository => $self,
            name => 'SideBar',
            body => <<'...',
sidebar.
...
            formatter => 'Sakaki::Formatter::Xatena',
        );
        $self->create($entry);
    }
}

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
            print {$fh} $entry->serialize;
            close $fh;
        }

        system('git', 'init');
        system('git', 'add', $filename);
        system('git', 'commit', '--author', 'Anonymous Coward <anonymous@example.com>', '-m', 'initial import : ' . $entry->name, $filename);
    }
}

sub update {
    my ($self, $entry) = @_;

    {
        my $g = pushd($self->root_dir);
        open my $fh, '+<:utf8', $entry->name_raw;
        flock($fh, LOCK_EX);
        my $src = do { local $/, <$fh> };

        my $serialized = $entry->serialize;

        if ($src ne $serialized) {
            seek($fh, 0, SEEK_SET);
            truncate($fh, 0);
            print {$fh} $serialized;
            system('git', 'add', $entry->name_raw);
            system('git', 'commit', '--author', 'Anonymous Coward <anonymous@example.com>', '-m', 'modified: ' . $entry->name, $entry->name_raw);
        }
        close $fh;
    }
}

sub remove {
    my ($self, $entry) = @_;

    {
        my $g = pushd($self->root_dir);

        system('git', 'rm', $entry->name_raw);
        system('git', 'commit', '--author', 'Anonymous Coward <anonymous@example.com>', '-m', 'remove page', $entry->name_raw);
    }
}

sub lookup {
    my ($self, $name) = @_;
    $name // croak;
    my $name_raw = uri_escape_utf8($name);

    my %args = do {
        my $g = pushd($self->root_dir);
        unless (-f $name_raw) {
            return undef;
        }
        open my $fh, '<:utf8', $name_raw;
        flock($fh, LOCK_SH);
        Sakaki::Entry->deserialize($fh);
    };

    return Sakaki::Entry->new(name => $name, repository => $self, %args);
}

sub get_log {
    my ($self, $entry) = @_;
    $entry // die "Missing mandatory parameter: entry";

	my $g = pushd($self->root_dir);
	# %H commit hash
	# %an author name
	# %at unix time
	# %s subject
	my $pretty = join('xyZZy', qw(%H %an %at %s));
	# TODO: paginate
    my @logs = map {
        my %args;
        @args{qw( hash author_name author_time subject )} = split /xyZZy/, $_;
        Sakaki::Log->new(%args);
      } split /\n/,
      `git log --pretty="$pretty" -50 --no-color @{[ $entry->name_raw ]}`;
    return @logs;
}

sub get_log_detail {
    my ($self, $entry, $hash) = @_;
    $entry // die "Missing mandatory parameter: entry";

	my $g = pushd($self->root_dir);
	# %H commit hash
	# %an author name
	# %at unix time
	# %s subject
	my $pretty = join('xyZZy', qw(%H %an %at %s));
	# TODO: paginate
    my $log_raw = `git log --pretty="$pretty" -p -1 --no-color '$hash^..$hash' @{[ $entry->name_raw ]}`;
    my @lines = split /\n/, $log_raw;
    my $log = do {
        my $header = shift @lines;
        my %args;
        @args{qw( hash author_name author_time subject )} = split /xyZZy/, $header;
        Sakaki::Log->new(%args);
    };
    $log->diff(join("\n", @lines));;
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

