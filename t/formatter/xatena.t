use strict;
use warnings;
use utf8;
use Test::More;

use Test::Requires 'Text::Xatena';
require Sakaki::Formatter::Xatena;

is(Sakaki::Formatter::Xatena->moniker(), 'xatena');
is(Sakaki::Formatter::Xatena->format(<<'...'), <<',,,');
oo
...
<p>oo</p>
,,,

is(normalize(Sakaki::Formatter::Xatena->format(<<'...')), normalize(<<',,,'));
>|perl|
use strict;
||<
...
<pre class="code prettyprint lang-perl">use strict;</pre>
,,,

done_testing;

sub normalize {
    local $_ = shift;
    s/\n$//;
    $_;
}
