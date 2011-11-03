package Sakaki::Exceptions;
use strict;
use warnings;
use utf8;

package Sakaki::Exception::ValidationError;
use Mouse;

has reason => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

use overload
    q{""} => \&as_string,
;

sub as_string {
    shift->reason;
}

1;

