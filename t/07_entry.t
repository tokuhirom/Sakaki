use strict;
use warnings;
use utf8;
use Test::More 0.98;
use t::Util;
use autodie;

use Sakaki::Entry;

my $repo = create_repository();

subtest 'serialize' => sub {
    my $e = Sakaki::Entry->new(
        name => "テスト",
        body => "yay\nyay\nhoi",
        formatter => 'Sakaki::Formatter::HTML',
        repository => $repo,
    );
    is($e->serialize(), _chop(<<'...'));
formatter: Sakaki::Formatter::HTML

yay
yay
hoi
...
};

subtest 'deserialize' => sub {
    open my $fh, '<', \<<'...';
formatter: Sakaki::Formatter::HTML

yay
yay
hoi
...

    my %opts = Sakaki::Entry->deserialize($fh);

    is(join(',', sort keys %opts), 'body,formatter');
    is($opts{formatter}, 'Sakaki::Formatter::HTML');
    is($opts{body}, "yay\nyay\nhoi\n");
};

done_testing;

sub _chop {
    local $_ = shift;
    s/\n$//;
    $_;
}
