package Sakaki::Formatter::Plain;
use strict;
use warnings;
use utf8;
use Text::Xslate::Util qw(html_escape);

sub moniker { 'plain' }

sub format {
    my ($self, $src) = @_;
    return join('<br />', map { html_escape($_) } split /\r?\n/, $src);
}

1;
