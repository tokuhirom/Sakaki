package Sakaki::Formatter::Markdown;
use strict;
use warnings;
use utf8;

use Text::Markdown ();

sub moniker { 'markdown' }

sub format {
    my ($self, $src) = @_;
    return Text::Markdown::markdown($src);
}

1;

