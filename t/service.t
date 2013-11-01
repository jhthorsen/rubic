use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Path qw( remove_tree make_path );

{
  use Mojolicious::Lite;

  $ENV{$_} = 't/ubic' for qw( UBIC_SERVICE_DIR UBIC_DIR UBIC_DEFAULT_USER );

  plugin Ubic => {
    route => app->routes->route('/dummy'),
    json => { foo => 'bar' },
  };
}

my $t = Test::Mojo->new;

{
  remove_tree 't/ubic';
  $t->get_ok('/dummy/service/foo/status')->status_is(404)->json_is('/error', 'Not found');
}

{
  make_path 't/ubic/foo';
  open my $SERVICE, '>', 't/ubic/foo/test123' or die $!;
  print $SERVICE "use parent 'Ubic::Service'; sub status { 'running' } bless {}\n";
  close $SERVICE;

  $t->get_ok('/dummy/service/foo.test123/yikes')->status_is(400)->json_is('/error', 'Invalid command');
  $t->get_ok('/dummy/service/foo.test123')->json_is('/status', 'running');
  $t->get_ok('/dummy/service/foo.test123/status')->json_is('/status', 'running');
  #diag $t->tx->res->body;
}

done_testing;
