package Sakaki::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::Lite;
use Sakaki::API::File;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Encode qw(decode_utf8);

any '/' => sub {
    my ($c) = @_;
    my $current_page = 0+($c->req->param('page') || 1);
    my ($entries, $pager) = Sakaki::API::File->recent(
        c => $c,
        entries_per_page => 50,
        current_page => $current_page,
    );
    $c->render('index.tt', { entries => $entries, pager => $pager });
};

get '/e/:name' => sub {
    my ($c, $args) = @_;
    my $name = $args->{name} // die;
       $name = uri_unescape $name;
       $name = decode_utf8 $name;
    my $body = Sakaki::API::File->lookup(c => $c, name => $name);
    return $c->render('show.tt', {body => $body, name => $name});
};
get '/e/:name/edit' => sub {
    my ($c, $args) = @_;
    my $name = $args->{name} // die;
       $name = uri_unescape $name;
       $name = decode_utf8 $name;
    my $body = Sakaki::API::File->lookup(c => $c, name => $name);
    return $c->render('edit.tt', {body => $body, name => $name});
};
post '/e/:name/edit' => sub {
    my ($c, $args) = @_;
    my $name = $args->{name} // die;
       $name = uri_unescape $name;
       $name = decode_utf8 $name;
    Sakaki::API::File->edit(
        c    => $c,
        name => $name,
        body => scalar $c->req->param('body')
    );
    return $c->redirect("/e/" . uri_escape_utf8 $name);
};

get '/create' => sub {
    my ($c) = @_;
    return $c->render('add.tt');
};
post '/create' => sub {
    my ($c) = @_;
    my $name = Sakaki::API::File->create(
        %{ $c->req->parameters },
        c => $c,
    );
    return $c->redirect("/e/" . uri_escape_utf8 $name);
};

post '/account/logout' => sub {
    my ($c) = @_;
    $c->session->expire();
    $c->redirect('/');
};

1;
