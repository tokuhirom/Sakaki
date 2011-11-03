package Sakaki::Formatter;
use strict;
use warnings;
use utf8;
use Carp;

use Module::Find;

my @formatters = useall 'Sakaki::Formatter';

sub available_formatters {
    @formatters
}

sub is_formatter {
    my ($class, $formatter) = @_;
    $formatter || Carp::croak("Missing mandatory parameter: formatter");
    for (@formatters) {
        return 1 if $formatter eq $_;
    }
    return 0;
}

1;

