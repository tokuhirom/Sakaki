package Sakaki::Formatter::HTML;
use strict;
use warnings;
use utf8;

sub moniker { 'html' }

sub format {
    my ($self, $src) = @_;
    return $src;
}

1;
