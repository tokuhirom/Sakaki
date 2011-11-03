package Sakaki::Formatter::Xatena;
use strict;
use warnings;
use utf8;

use Text::Xatena;

sub moniker { 'xatena' }

my $xatena = Text::Xatena->new();

sub format {
    my ($self, $src) = @_;
    return $xatena->format($src);
}

1;

