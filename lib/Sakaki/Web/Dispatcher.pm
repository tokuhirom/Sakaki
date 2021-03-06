package Sakaki::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use 5.10.0;
use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Encode qw(decode_utf8);
use Data::Page::Navigation;
use Router::Simple::Sinatraish;

sub dispatch {
    my ( $class, $c ) = @_;

    if ( my $p = $class->router->match( $c->request->env ) ) {
        if (defined(my $name = $p->{name})) {
        }
        return $p->{code}->( $c, $p );
    }
    else {
        return $c->res_404();
    }
}

any '/' => sub {
    my ($c) = @_;
    my $name = 'IndexPage';
    my $entry = $c->repository->lookup($name);
    return _handle_entry($c, $entry);
};
any '/_recent' => sub {
    my ($c) = @_;
    my $current_page = 0 + ( $c->req->param('page') || 1 );
    my ( $entries, $pager ) = $c->repository->get_recent(
        entries_per_page => 50,
        current_page     => $current_page,
    );
    $c->render( 'recent.tt', { entries => $entries, pager => $pager } );
};
get '/_search' => sub {
    my ($c) = @_;

    if (defined(my $keyword = $c->req->param('keyword'))) {
        my $current_page = 0 + ( $c->req->param('page') || 1 );
        my ( $entries, $pager ) = $c->repository->search(
            keyword => $keyword,
            entries_per_page => 50,
            current_page     => $current_page,
        );
        return $c->render('search.tt', { keyword => $keyword, entries => $entries, pager => $pager });
    } else {
        return $c->render('search.tt', { keyword => $keyword });
    }
};

any '/_create' => sub {
    my ($c) = @_;

    my $name = $c->req->param('name');
    my $body = $c->req->param('body');
    my $formatter = $c->req->param('formatter');
    if ( $c->req->method eq 'POST' && ( $name && $body && $formatter ) ) {
        my $entry = Sakaki::Entry->new(
            name       => $name,
            body       => $body,
            formatter  => $formatter,
            repository => $c->repository,
        );
        if ( -e $entry->fullpath ) {
            return $c->show_error(
                'This entry is already exists: ' . $entry->name );
        }
        $entry->create();
        return $c->redirect( $entry->path );
    }

    my $formatters =
      [ map { +{ name => $_->moniker, pkg => $_ } }
          Sakaki::Formatter->available_formatters() ];

    return $c->render( 'add.tt', { formatters => $formatters } );
};

post '/_logout' => sub {
    my ($c) = @_;
    $c->session->expire();
    $c->redirect('/');
};

# this hook must be last
any '/{name:[^_].*}' => sub {
    my ( $c, $args ) = @_;

    my $name = $args->{name};
    $name = decode_utf8(uri_unescape $name);
    my $entry = $c->repository->lookup($name);
    unless ($entry) {
        my $res = $c->show_error("There is no page named: " . $name);
        $res->code(404);
        return $res;
    }

    return _handle_entry($c, $entry);
};

sub _handle_entry {
    my ($c, $entry) = @_;

    given ($c->req->param('mode')) {
    when ('edit') {
        if ($c->req->method eq 'POST') {
            $entry->body(scalar $c->req->param('body'));
            $entry->formatter(scalar $c->req->param('formatter'));
            $entry->update();
            return $c->redirect( $entry->path );
        }
        $c->fillin_form( $entry->as_hashref );
        my $formatters =
        [ map { +{ name => $_->moniker, pkg => $_ } }
            Sakaki::Formatter->available_formatters() ];
        return $c->render( 'edit.tt', { entry => $entry, formatters => $formatters } );
    }
    when ('log_detail') {
        my $hash = $c->req->param('hash') // die;
        my $log = $entry->get_log_detail($hash);
        return $c->render( 'log_detail.tt', { log => $log, entry => $entry } );
    }
    when ('log') {
        my @logs = $entry->get_log();
        return $c->render( 'log.tt', { logs => \@logs, entry => $entry } );
    }
    when ('attachments_add') {
        my $upload = $c->req->upload('file')
        // return $c->show_error("Please choose a upload file");

        if ($upload->size > 10_000_000) {
            return $c->show_error("Uploaded file too big");
        }

        open my $fh, '<', $upload->path;
        $entry->add_attachment($upload->basename, $fh);
        return $c->redirect($c->req->uri_with({mode => 'attachments'}));
    }
    when ('attachments_download') {
        my $f = $c->req->param('f') // die;
        my $attachment = $entry->get_attachment($f) // return $c->res_404();
        return $c->create_response(
            200,
            [
                'Content-Type'   => $attachment->mime_type,
                'Content-Length' => -s $attachment->fullpath
            ],
            $attachment->openr,
        );
    }
    when ('attachments') {
        return $c->render( 'attachments/list.tt', { entry => $entry } );
    }
    when ('remove') {
        if ($c->req->method eq 'POST') {
            $entry->remove();
            return $c->redirect( "/" );
        }
        return $c->render( 'remove.tt', { entry => $entry } );
    }
    default {
        $entry->html(); # pre-rendering
        return $c->render( 'show.tt', { entry => $entry } );
    }
    }
}


1;
