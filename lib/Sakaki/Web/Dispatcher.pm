package Sakaki::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::Lite;
use Sakaki::API::File;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Encode qw(decode_utf8);
use FormValidator::Lite;

any '/' => sub {
    my ($c) = @_;
    my $current_page = 0 + ( $c->req->param('page') || 1 );
    my ( $entries, $pager ) = Sakaki::API::File->recent(
        c                => $c,
        entries_per_page => 50,
        current_page     => $current_page,
    );
    $c->render( 'index.tt', { entries => $entries, pager => $pager } );
};

get '/e/:name' => sub {
    my ( $c, $args ) = @_;
    my $name = $args->{name} // die;
    $name = uri_unescape $name;
    $name = decode_utf8 $name;
    my $entry = Sakaki::Entry->new( name => $name );
    return $c->render( 'show.tt', { entry => $entry, name => $name } );
};
get '/e/:name/log' => sub {
    my ( $c, $args ) = @_;
    my $name = $args->{name} // die;
    $name = uri_unescape $name;
    $name = decode_utf8 $name;
    my $log = Sakaki::API::File->log( c => $c, name => $name );
    return $c->render( 'log.tt', { log => $log, name => $name } );
};
get '/e/:name/edit' => sub {
    my ( $c, $args ) = @_;
    my $name = $args->{name} // die;
       $name = uri_unescape $name;
       $name = decode_utf8 $name;
    my $entry = Sakaki::Entry->new( name => $name );
    return $c->render( 'edit.tt', { entry => $entry } );
};
post '/e/:name/edit' => sub {
    my ( $c, $args ) = @_;
    my $name = $args->{name} // die;
    $name = uri_unescape $name;
    $name = decode_utf8 $name;
    my $entry = Sakaki::Entry->new( name => $name );
	$entry->body(scalar $c->req->param('body'));
    Sakaki::API::File->edit(
        c    => $c,
		entry => $entry,
    );
    return $c->redirect( "/e/" . uri_escape_utf8 $name);
};

any '/create' => sub {
    my ($c) = @_;

    my $name = $c->req->param('name');
    my $body = $c->req->param('body');
    my $formatter = $c->req->param('formatter');
    if ( $c->req->method eq 'POST' && ( $name && $body && $formatter ) ) {
        my $entry = Sakaki::Entry->new(
            name      => $name,
            body      => $body,
            formatter => $formatter,
        );
        if ( -e $entry->fullpath ) {
            return $c->show_error(
                'This entry is already exists: ' . $entry->name );
        }
        my $name = Sakaki::API::File->create(
            entry => $entry,
            c     => $c,
        );
        return $c->redirect( "/e/" . $entry->name_raw );
    }

    my $formatters =
      [ map { +{ name => $_->moniker, pkg => $_ } }
          Sakaki::Formatter->available_formatters() ];

    return $c->render( 'add.tt', { formatters => $formatters } );
};

post '/account/logout' => sub {
    my ($c) = @_;
    $c->session->expire();
    $c->redirect('/');
};

1;
