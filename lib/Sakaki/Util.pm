package Sakaki::Util;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);

our @EXPORT_OK = qw(slurp);

sub slurp {
    my $filename = shift;
    open my $fh,'<:utf8', $filename;
    my $body = do { local $/; <$fh>};
    close $fh;
    return $body;
}


1;

