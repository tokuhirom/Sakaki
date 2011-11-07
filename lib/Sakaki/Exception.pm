package Sakaki::Exception;
use strict;
use warnings;
use utf8;

use overload
    q{""} => \&as_string,
;

sub new {
	my $class = shift;
	my %args = @_==1 ? %{$_[0]} : @_;
	bless {%args}, $class;
}

sub reason {
	my $self = shift;
	$self->{reason} = shift if @_==1;
	$self->{reason};
}

sub as_string {
    shift->reason;
}

sub throw {
	my $class = shift;
	Carp::croak($class->new(@_));
}

1;
