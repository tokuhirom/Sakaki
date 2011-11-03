package Sakaki::API::File;
use strict;
use warnings;
use utf8;
use autodie ':all';
use Smart::Args;
use File::Spec::Functions qw(catfile rel2abs);
use File::stat;
use Sakaki::Entry;
use File::pushd;
use Fcntl qw(:flock SEEK_END SEEK_SET);
use Text::Xslate::Util qw(mark_raw);

use Sakaki::StripScripts;
use Sakaki::Formatter;

1;

