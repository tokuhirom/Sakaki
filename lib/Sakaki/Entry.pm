package Sakaki::Entry;
use strict;
use warnings;
use utf8;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use File::stat;
use Sakaki;
use Encode qw(decode_utf8);
use Time::Piece;
use File::Spec::Functions qw(catfile);
use Text::Xslate::Util qw(mark_raw);

use Sakaki::Util qw(slurp);

use Mouse;

has name => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has name_raw => (
	is => 'rw',
	isa => 'Str',
	default => sub {
		my $self = shift;
		uri_escape_utf8 $self->name;
	},
);

sub new_from_raw {
	my ($self, $name_raw) = @_;
	Sakaki::Entry->new(name => decode_utf8(uri_unescape($name_raw)));
}

sub filename {
	my $self = shift;
	catfile(Amon2->context->root_dir, $self->name_raw);
}

sub mtime {
	my $self = shift;
	$self->{mtime} //= stat($self->filename)->mtime;
}

sub mtime_piece {
	my $self = shift;
	Time::Piece->new($self->mtime);
}

sub formatter {
	my $self = shift;

    my $formatter = do{
        my $formatfile = catfile( Amon2->context->root_dir,
            '.' . $self->name_raw . '.format' );
        if (-f $formatfile) {
            my $name = slurp($formatfile);
            $name =~ s/\r?\n$//;
            $name;
        } else {
            'Sakaki::Formatter::Plain'
        }
    };
    unless (Sakaki::Formatter->is_formatter($formatter)) {
        die "Bad formatter name: $formatter";
    }
	return $formatter;
}

sub format {
	my $self = shift;
	$self->formatter->moniker;
}

sub body {
	my $self = shift;
	return slurp($self->filename);
}

sub html {
	my $self = shift;

	my $formatter = $self->formatter;

    my $html = $formatter->format($self->body);
       $html = Sakaki::StripScripts->strip($html);
       $html = mark_raw($html);

	return $html;
}

1;

