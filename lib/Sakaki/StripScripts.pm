package Sakaki::StripScripts;
use strict;
use warnings;
use utf8;
use HTML::Scrubber;

my $scrubber = HTML::Scrubber->new();
$scrubber->rules(
    img => {
        src => qr{^https?://},    # only URL with http://
        alt => 1,               # alt attributes allowed
        '*' => 0,               # deny all others
    },
    style  => 0,
    script => 0,
    link   => {
        href => qr{^https?://},    # only URL with http://
        rel  => 1,
        type => 1,
    },
    a   => {
        href => qr{^https?://},    # only URL with http://
    },
);
$scrubber->default(
    '*'    => 0,                           # default rule, deny all attributes
    'href' => qr{^(?!(?:java)?script)}i,
    'src'  => qr{^(?!(?:java)?script)}i,
    'cite'     => '(?i-xsm:^(?!(?:java)?script))',
    'language' => 0,
    'name'     => 1,                               # could be sneaky, but hey ;)
    'onblur'   => 0,
    'onchange' => 0,
    'onclick'  => 0,
    'ondblclick'  => 0,
    'onerror'     => 0,
    'onfocus'     => 0,
    'onkeydown'   => 0,
    'onkeypress'  => 0,
    'onkeyup'     => 0,
    'onload'      => 0,
    'onmousedown' => 0,
    'onmousemove' => 0,
    'onmouseout'  => 0,
    'onmouseover' => 0,
    'onmouseup'   => 0,
    'onreset'     => 0,
    'onselect'    => 0,
    'onsubmit'    => 0,
    'onunload'    => 0,
    'src'         => 0,
    'type'        => 0,
    'style'       => 0,
    'loop'        => qr{^\d+$},
    'behaivour'   => qr{^(?:scroll|alternate|slide)$},
);

sub strip {
	my ($self, $html) = @_;
	return $scrubber->scrub($html);
}

1;

