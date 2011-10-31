package Sakaki::Entry;
use strict;
use warnings;
use utf8;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use File::stat;
use Sakaki;
use Encode qw(decode_utf8);
use Time::Piece;
use File::Spec::Functions qw(catfile);

use Mouse;

has name => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has name_raw => (
	is => 'rw',
	isa => 'Str',
	default => sub {
		my $self = shift;
		uri_escape_utf8 $self->name;
	},
);

sub new_from_raw {
	my ($self, $name_raw) = @_;
	Sakaki::Entry->new(name => decode_utf8(uri_unescape($name_raw)));
}

sub filename {
	my $self = shift;
	catfile(Amon2->context->root_dir, $self->name_raw);
}

sub mtime {
	my $self = shift;
	$self->{mtime} //= stat($self->filename)->mtime;
}

sub mtime_piece {
	my $self = shift;
	Time::Piece->new($self->mtime);
}

1;

