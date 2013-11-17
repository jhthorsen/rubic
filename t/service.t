use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Path qw( remove_tree make_path );

{
  use Mojolicious::Lite;

  $ENV{UBIC_DEFAULT_USER} = getpwuid $<;
  $ENV{UBIC_DIR} = 't/ubic';
  $ENV{UBIC_SERVICE_DIR} = 't/ubic/service';

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
  make_path 't/ubic/service/foo';
  make_path 't/ubic/lock';
  make_path 't/ubic/tmp';
  open my $SERVICE, '>', 't/ubic/service/foo/test123' or die $!;
  print $SERVICE "use parent 'Ubic::Service'; sub status { 'running' } bless {}\n";
  close $SERVICE;

  $t->get_ok('/dummy/service/foo.test123/yikes')
    ->status_is(400)
    ->json_is('/error', 'Invalid command')
    ;

  $t->get_ok('/dummy/service/foo.test123')
    ->status_is(200)
    ->json_is('/status', 'running')
    ->json_is('/error', undef)
    ;

  $t->get_ok('/dummy/service/foo.test123/status')
    ->status_is(200)
    ->json_is('/status', 'running')
    ->json_is('/error', undef)
    ;
}

remove_tree 't/ubic';
done_testing;
