package t::Util;
BEGIN {
    unless ($ENV{PLACK_ENV}) {
        $ENV{PLACK_ENV} = 'test';
    }
	if ($ENV{PLACK_ENV} eq 'deployment') {
		die "Do not run a test script on deployment environment";
	}
}
use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'extlib', 'lib', 'perl5'));
use lib File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'lib'));
use parent qw/Exporter/;
use Test::More 0.98;
use File::Path;
use File::Temp ();

our @EXPORT = qw(slurp create_repository);

{
    # utf8 hack.
    binmode Test::More->builder->$_, ":utf8" for qw/output failure_output todo_output/;                       
    no warnings 'redefine';
    my $code = \&Test::Builder::child;
    *Test::Builder::child = sub {
        my $builder = $code->(@_);
        binmode $builder->output,         ":utf8";
        binmode $builder->failure_output, ":utf8";
        binmode $builder->todo_output,    ":utf8";
        return $builder;
    };
}


sub slurp {
	my $fname = shift;
	open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
	do { local $/; <$fh> };
}

# initialize database
use Sakaki;
{
    mkpath('db');
    unlink 'db/test.db' if -f 'db/test.db';

    my $c = Sakaki->new();
    $c->setup_schema();
}

sub create_repository {
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    return Sakaki::Repository->new(root_dir => $tmpdir);
}

1;
