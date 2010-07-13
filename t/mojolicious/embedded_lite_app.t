#!/usr/bin/env perl

# Copyright (C) 2008-2010, Sebastian Riedel.

use strict;
use warnings;

# Disable epoll, kqueue and IPv6
BEGIN { $ENV{MOJO_POLL} = $ENV{MOJO_NO_IPV6} = 1 }

use Mojo::IOLoop;
use Test::More;

# Make sure sockets are working
plan skip_all => 'working sockets required for this test!'
  unless Mojo::IOLoop->new->generate_port;
plan tests => 18;

use FindBin;
use lib "$FindBin::Bin/lib";

# I heard you went off and became a rich doctor.
# I've performed a few mercy killings.
package TestApp;

use Mojolicious::Lite;

# Silence
app->log->level('error');

# GET /hello (embedded)
get '/hello' => sub {
    my $self = shift;
    my $name = $self->stash('name');
    $self->render_text("Hello from the $name app!");
};

# Morbo will now introduce the candidates - Puny Human Number One,
# Puny Human Number Two, and Morbo's good friend Richard Nixon.
# How's the family, Morbo?
# Belligerent and numerous.
package MyTestApp::Test1;

use Mojolicious::Lite;

# Silence
app->log->level('error');

# GET /bye (embedded)
get '/bye' => sub {
    my $self = shift;
    my $name = $self->stash('name');
    $self->pause;
    my $async = '';
    $self->client->async->get(
        '/hello/hello' => sub {
            my $client = shift;
            $self->render_text($client->res->body . "$name! $async");
            $self->finish;
        }
    )->process;
    $async .= 'success!';
};

package Mojolicious::Plugin::MyEmbeddedApp;
use base 'Mojolicious::Plugin';

sub register {
    my ($self, $app) = @_;
    $app->routes->route('/foo')
      ->detour(Mojolicious::Plugin::MyEmbeddedApp::App::app());
}

package Mojolicious::Plugin::MyEmbeddedApp::App;
use Mojolicious::Lite;

# Silence
app->log->level('error');

# GET /bar
get '/bar' => {text => 'plugin works!'};

package MyTestApp::Test2;

use Mojolicious::Lite;

# Silence
app->log->level('error');

# GET / (embedded)
get '/' => sub {
    my $self = shift;
    my $name = $self->stash('name');
    my $url  = $self->url_for;
    $self->render_text("Bye from the $name app! $url!");
};

package main;

use Mojolicious::Lite;
use Test::Mojo;

# Silence
app->log->level('error');

# /foo/* (plugin app)
plugin 'my_embedded_app';

# GET /hello
get '/hello' => 'works';

# /bye/* (dispatch to embedded app)
get('/bye' => {name => 'second embedded'})->detour('MyTestApp::Test1');

# /third/* (dispatch to embedded app)
get '/third/(*path)' =>
  {app => 'MyTestApp::Test2', name => 'third embedded', path => '/'};

# /hello/* (dispatch to embedded app)
app->routes->route('/hello')->detour(TestApp::app())->to(name => 'embedded');

# /just/* (external embedded app)
get('/just' => {name => 'working'})->detour('EmbeddedTestApp');

my $t = Test::Mojo->new;

# GET /foo/bar (plugin app)
$t->get_ok('/foo/bar')->status_is(200)
  ->content_is('plugin works!', 'right content');

# GET /hello (from main app)
$t->get_ok('/hello')->status_is(200)
  ->content_is("Hello from the main app!\n", 'right content');

# GET /hello/hello (from embedded app)
$t->get_ok('/hello/hello')->status_is(200)
  ->content_is('Hello from the embedded app!', 'right content');

# GET /bye/bye (from embedded app)
$t->get_ok('/bye/bye')->status_is(200)
  ->content_is('Hello from the embedded app!second embedded! success!',
    'right content');

# GET /third/ (from embedded app)
$t->get_ok('/third')->status_is(200)
  ->content_is('Bye from the third embedded app! /third!', 'right content');

# GET /just/works (from external embedded app)
$t->get_ok('/just/works')->status_is(200)
  ->content_is("It is working!\n", 'right content');

__DATA__
@@ works.html.ep
Hello from the main app!
