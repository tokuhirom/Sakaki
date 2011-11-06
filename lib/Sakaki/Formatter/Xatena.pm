package Sakaki::Formatter::Xatena;
use strict;
use warnings;
use utf8;

use Text::Xatena;
use Text::Xatena::Node::SuperPre;

sub moniker { 'xatena' }

my $xatena = Text::Xatena->new();

sub format {
    my ($self, $src) = @_;
    local $Text::Xatena::Node::SuperPre::SUPERPRE_CLASS_NAME = 'prettyprint code';
    return $xatena->format($src);
}

1;

