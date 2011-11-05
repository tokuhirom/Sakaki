package Sakaki::Log;
use strict;
use warnings;
use utf8;

use Mouse;

for (qw{hash author_name author_time subject}) {
    has $_ => (
        is => 'rw',
        isa => 'Str',
        required => 1,
    );
}

has 'diff' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
);

sub author_time_piece {
    Time::Piece->new(shift->author_time)
}

1;

