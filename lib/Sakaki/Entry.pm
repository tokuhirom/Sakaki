package Sakaki::Entry;
use strict;
use warnings;
use utf8;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use File::stat;
use Encode qw(decode_utf8);
use Time::Piece;
use File::Spec::Functions qw(catfile);
use Text::Xslate::Util qw(mark_raw);
use Smart::Args;
use File::pushd;
use Sakaki::Formatter;
use Sakaki::StripScripts;

use Sakaki;
use Sakaki::Repository;
use Sakaki::Util qw(slurp);

use Mouse;

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    trigger => sub {
        my ($self, $name) = @_;
        if ($name =~ /\.\.|\0/ || $name =~ /\.format$/) {
            die Sakaki::Exception::ValidationError->new( reason =>
                "You cannot contain some chars in the entry name for security reason."
            );
        }
    },
);

has body => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    lazy => 1,
    default => sub {
        my $self = shift;
        return slurp($self->filename);
    },
);

has formatter => (
    is => 'rw',
    isa => 'ClassName',
    required => 1,
    lazy => 1,
    trigger => sub {
        my ($self, $formatter) = @_;
        unless (Sakaki::Formatter->is_formatter($formatter)) {
            die Sakaki::Exception::ValidationError->new(
                reason => "Unknown formatter name: $formatter",
            );
        }
    },
    default => sub {
        my $self = shift;
        my $formatter = do{
            my $formatfile = catfile( $self->repository->root_dir,
                '.' . $self->name_raw . '.format' );
            if (-f $formatfile) {
                my $name = slurp($formatfile);
                $name =~ s/\r?\n$//;
                $name;
            }
        };
        $formatter ||= 'Sakaki::Formatter::Plain';
        unless (Sakaki::Formatter->is_formatter($formatter)) {
            die "Bad formatter name: $formatter";
        }
        $formatter;
    },
);

has repository => (
    is       => 'ro',
    isa      => 'Sakaki::Repository',
    required => 1,
);
for my $meth (qw(create update get_log get_log_detail remove)) {
    no strict 'refs';
    *{__PACKAGE__ . '::' . $meth} = sub {
        my ($self) = @_;
        $self->repository->$meth(@_);
    };
}

sub name_raw {
    my $self = shift;
    uri_escape_utf8 $self->name;
}

sub fullpath {
	my $self = shift;
	catfile($self->repository->root_dir, $self->name_raw);
}

sub filename { shift->fullpath }

sub mtime {
	my $self = shift;
	$self->{mtime} //= stat($self->fullpath)->mtime;
}

sub mtime_piece {
	my $self = shift;
	Time::Piece->new($self->mtime);
}


sub format {
	my $self = shift;
	$self->formatter->moniker;
}

sub html {
	my $self = shift;

	my $formatter = $self->formatter;

    my $html = $formatter->format($self->body);
       $html = Sakaki::StripScripts->strip($html);
       $html = mark_raw($html);

	return $html;
}

sub as_hashref {
	my $self = shift;
	return +{ map { $_ => $self->$_ } qw(body formatter name) };
}

sub serialize {
    my ($self) = @_;
    return 'formatter: ' . $self->formatter . "\n\n" . $self->body;
}

sub deserialize {
    my ($self, $fh) = @_;

    my %ret;
    while (my $line = <$fh>) {
        last if $line !~ /\S/;
        my ($k, $v) = ($line =~ /^([^:]+)\s*:\s*(.+)\r?\n?/);
        $ret{$k} = $v;
    }
    $ret{body} = do { local $/; <$fh> };
    return %ret;
}

1;

