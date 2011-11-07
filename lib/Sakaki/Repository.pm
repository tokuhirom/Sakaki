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
use File::Basename ();

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
    my $log_raw = `git log --pretty="$pretty" -p -1 --no-color '$hash' @{[ $entry->name_raw ]}`;
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

sub _attachment_filename {
    my ( $self, $entry, $filename ) = @_;
    $filename // die;

    Sakaki::Exception::ValidationError->throw("Security issue : $filename")
      if $filename =~ /\.\.|^\./;

    return File::Spec->catfile( $self->_attachment_directory($entry),
        uri_escape_utf8( File::Basename::basename($filename) ) );
}


sub _attachment_directory {
    my ( $self, $entry ) = @_;
    $entry // die;
    my $dir = File::Spec->catfile( '_attachments', $entry->name_raw );
	mkpath($dir);
	return $dir;
}

sub add_attachment {
    my ( $self, $entry, $filename, $ifh ) = @_;
    $ifh // die;

    {
        my $g = pushd( $self->root_dir );

		my $fname = $self->_attachment_filename( $entry, $filename );

		infof( "Writing attachment: %s", $fname );
		open my $ofh, '>', $fname;
		flock( $ofh, LOCK_EX );
		while (1) {
			my $read = read( $ifh, my $buf, 1024 );
			die "Error while reading attachment $fname: $!" if !defined $read;
			last if $read == 0;
			print {$ofh} $buf;
		}

        system( "git", 'add', $fname );
        system(
            'git',
            'commit',
            '--author',
            'Anonymous Coward <anonymous@example.com>',
            '-m',
            "Added attachment: " . $entry->name . ' : ' . $filename,
            $fname
        );

		close $ofh;
    }

    return;
}

sub open_attachment {
    my ( $self, $entry, $filename ) = @_;
	$filename // die;

	{
		my $g = pushd($self->root_dir);
		my $fname = $self->_attachment_filename( $entry, $filename );

		open my $ifh, '<', $fname;
		flock( $ifh, LOCK_SH );
		return $ifh;
	}
}

sub remove_attachment {
    my ( $self, $entry, $filename ) = @_;
	$filename // die;

    {
        my $g = pushd( $self->root_dir );
		my $fname = $self->_attachment_filename( $entry, $filename );
        system( "git", 'rm', $fname );
        system(
            'git',
            'commit',
            '--author',
            'Anonymous Coward <anonymous@example.com>',
            '-m',
            "Remove attachment: " . $entry->name . ' : ' . $filename,
            File::Spec->catfile(File::Spec->no_upwards(File::Spec->abs2rel($fname)))
        );
    }
}

sub list_attachments {
    my ( $self, $entry ) = @_;

	my $g = pushd( $self->root_dir );

    my $dir = $self->_attachment_directory($entry);

    opendir(my $dh, $dir);
	my @files;
    while ( defined( my $f = readdir($dh) ) ) {
        next if $f =~ /^\./;
        my $path = catfile( $dir, $f );
        next unless -f $path;
        push @files,
          Sakaki::Attachment->new(
            repository => $self,
            entry      => $entry,
            name       => decode_utf8( uri_unescape($f) ),
            fullpath   => File::Spec->rel2abs($path),
          );
    }
    @files = reverse sort { $a->mtime <=> $b->mtime } @files;
	return wantarray ? @files : \@files;
}

sub get_attachment {
	my ($self, $entry, $filename) = @_;
	$filename // die;

	my $path = File::Spec->catfile($self->root_dir, $self->_attachment_filename( $entry, $filename ));
	return Sakaki::Attachment->new(
		repository => $self,
		entry      => $entry,
		name       => decode_utf8( uri_unescape($filename) ),
		fullpath   => $path,
	);
}


1;

