package Sakaki;
use strict;
use warnings;
use utf8;
use parent qw/Amon2/;
our $VERSION='0.01';
use 5.010001;

use Sakaki::Exceptions;

__PACKAGE__->load_plugin(qw/DBI/);

sub root_dir {
	my $c = shift;
	return $c->config->{root_dir} // die "Missing configuration for root_dir";
}

# initialize database
use DBI;
sub setup_schema {
    my $self = shift;
    my $dbh = $self->dbh();
    my $driver_name = $dbh->{Driver}->{Name};
    my $fname = lc("sql/${driver_name}.sql");
    open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
    my $source = do { local $/; <$fh> };
    for my $stmt (split /;/, $source) {
        $dbh->do($stmt) or die $dbh->errstr();
    }
}

1;
