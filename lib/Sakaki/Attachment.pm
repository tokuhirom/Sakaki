package Sakaki::Attachment;
use strict;
use warnings;
use utf8;

use Mouse;
use File::stat;
use Time::Piece;
use autodie;
use Plack::MIME;

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has repository => (
    is       => 'ro',
    isa      => 'Sakaki::Repository',
    required => 1,
);

has entry => (
    is       => 'ro',
    isa      => 'Sakaki::Entry',
    required => 1,
);

has fullpath => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

sub mtime {
	my $self = shift;
	$self->{mtime} //= stat($self->fullpath)->mtime;
}
sub mtime_piece { Time::Piece->new(shift->mtime) }

sub openr {
	my $self = shift;
	open my $fh, '<', $self->fullpath;
	return $fh;
}

sub mime_type {
	my $self = shift;
	Plack::MIME->mime_type($self->name) || 'application/octet-stream';
}

sub remove {
	my $self = shift;
	$self->repository->remove_attachment($self->entry, $self->name);
}

1;

