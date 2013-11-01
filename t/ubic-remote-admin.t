use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Cwd 'abs_path';
use File::Path qw( remove_tree );

$ENV{MOJO_CONFIG} = abs_path 't/ubic-remote-admin.conf';
plan skip_all => $@ unless do 'script/ubic-remote-admin';

{
  $ENV{$_} = 't/ubic' for qw( UBIC_SERVICE_DIR UBIC_DIR UBIC_DEFAULT_USER );
  remove_tree 't/ubic';

  my $t = Test::Mojo->new;
  is $t->app->log->level, 'warn', 'log level';
  is $t->app->log->path, 't/ubic-remote-admin.log', 'log path';

  $t->get_ok('/some/path/services')->json_is('/foo', 42);
  #diag $t->tx->res->body;
}

done_testing;
