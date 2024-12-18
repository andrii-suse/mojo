use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Test::More;

plan skip_all => 'set TEST_HYPNOTOAD to enable this test (developer only!)'
  unless $ENV{TEST_HYPNOTOAD} || $ENV{TEST_ALL};

use IO::Socket::INET;
use Mojo::File qw(curfile tempdir);
use Mojo::IOLoop::Server;
use Mojo::Server::Hypnotoad;
use Mojo::UserAgent;

subtest 'Content of environ file' => sub {
  my $dir    = tempdir;
  my $script = $dir->child('myapp.pl');
  my $log    = $dir->child('mojo.log');
  my $port1  = Mojo::IOLoop::Server->generate_port;
  $script->spew(<<EOF);
use Mojolicious::Lite;
use Mojo::IOLoop;

app->log->path('$log');

plugin Config => {
  default => {
    hypnotoad => {
      listen => ['http://127.0.0.1:$port1'],
      workers => 1
    }
  }
};

app->log->level('trace');

get '/hello' => {
    text => 'Hello Hypnotoad!'
};

get '/environ' => sub {
  my \$c = shift;
  my \$res = `uname -a; cat /etc/*release; hexdump -C /proc/\$\$/environ`;
  \$c->render(text => \$res);
};

app->start;
EOF

  my $prefix = curfile->dirname->dirname->sibling('script');
  open my $start, '-|', $^X, "$prefix/hypnotoad", $script;
  sleep 3;
  sleep 1 while !_port($port1);
  my $old = _pid($dir->child('hypnotoad.pid'));
  my $ua  = Mojo::UserAgent->new;

  subtest 'Application is alive' => sub {
    my $tx = $ua->get("http://127.0.0.1:$port1/hello");
    ok $tx->is_finished, 'transaction is finished';
    ok $tx->keep_alive,  'connection will be kept alive';
    ok !$tx->kept_alive, 'connection was not kept alive';
    is $tx->res->code, 200,                'right status';
    is $tx->res->body, 'Hello Hypnotoad!', 'right content';
  };
  subtest 'Environ file' => sub {
    my $tx = $ua->get("http://127.0.0.1:$port1/environ");
    ok $tx->is_finished, 'transaction is finished';
    is $tx->res->code, 200, 'right status';
    my $first = $tx->res->body;
    print STDERR "respond: $first";

    # like $first, qr/test \d+!/, 'right content';
  };
};

sub _pid {
  my $path = shift;
  return undef unless open my $file, '<', $path;
  my $pid = <$file>;
  chomp $pid;
  return $pid;
}

sub _port { IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => shift) }

done_testing();
