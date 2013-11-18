package Mojolicious::Plugin::Ubic;

=head1 NAME

Mojolicious::Plugin::Ubic - Remote ubic admin

=head1 SYNOPSIS

  #!perl
  use Mojolicious::Lite;

  plugin Ubic => {
    data_dir => '/path/to/ubic/data',
    default_user => 'ubicadmin',
    layout => 'my_layout',
    remote_servers => [...],
    route => app->routes->route('/something/secure'),
    service_dir => '/path/to/ubic/service',
    valid_actions => [...],
    json => {
      some => 'default values',
    },
  };

  app->start;

See L</register> for config description.

=head1 DESCRIPTION

This L<Mojolicious> plugin allow you to query status of the running L<Ubic>
services and also start/stop/restart/reload/... them.

This is L<Ubic::Ping::Service> on steroids.

=cut

use Mojo::Base 'Mojolicious::Plugin';
use Sys::Hostname;
use Ubic;
use Ubic::Settings;
use constant DEBUG => $ENV{UBIC_DEBUG} || 0;

=head1 ACTIONS

=head2 command

  POST /service/:service_name/start
  POST /service/:service_name/reload
  POST /service/:service_name/restart
  POST /service/:service_name/stop

Used to control a given service. The actions act like <ubic> from the command
line. The return value contain "status". Example:

  {"status":"running"}

=cut

sub command {
  my($self, $c) = @_;
  my $command = $c->stash('command');
  my $name = $c->stash('name');
  my $json = $self->_json;
  my $valid = grep { $command eq $_ } @{ $self->{valid_actions} };

  if(!$valid) {
    $json->{error} = 'Invalid command';
    return $c->render(json => $json, status => 400);
  }
  if(!Ubic->has_service($name)) {
    $json->{error} = 'Not found';
    return $c->render(json => $json, status => 404);
  }

  if(Ubic->service($name)->isa('Ubic::Multiservice')) {
    $json->{error} = 'Cannot run actions on multiservice';
    return $c->render(json => $json, status => 400);
  }

  eval {
    $json->{status} = '' .Ubic->$command($name);
    1;
  } or do {
    $json->{error} = $@ || 'Unknown error';
  };

  $c->render(json => $json, status => $json->{error} ? 500 : 200);
}

=head2 index

  GET /

Draw a table of services using HTML.

=cut

sub index {
  my($self, $c) = @_;
  my $ua = $c->ua;

  $c->stash(layout => $self->{layout})->render_later;

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      for($self->_remote_servers($c)) {
        my $url = $_->clone;
        $url->query->param(flat => 1);
        push @{ $url->path }, 'services';
        warn "[UBIC] remote_url=$url\n" if DEBUG;
        $ua->get($url, $delay->begin);
      }
    },
    sub {
      my($delay, @tx) = @_;
      my @remotes;

      for my $tx (@tx) {
        if(my $json = $tx->res->json) {
          push @remotes, $json;
        }
        else {
          push @remotes, { error => $tx->res->code || 'Did not respond' };
        }

        $remotes[-1]{tx} = $tx;
      }

      $c->render(template => 'ubic/index', remotes => \@remotes);
    },
  );
}

=head2 proxy

  GET /proxy/#to/#service_name/:command

This resource is used to proxy commands to other servers.

=cut

sub proxy {
  my($self, $c) = @_;
  my $to = $c->stash('to');
  my $url;

  for($self->_remote_servers($c)) {
    next unless $_->host eq $to;
    $url = $_->clone;
    push @{ $url->path }, 'service', $c->stash('name'), $c->stash('command');
    last;
  }

  unless($url) {
    return $c->render(json => { error => 'Unknown host' }, status => 400);
  }

  warn "[UBIC] remote_url=$url\n" if DEBUG;

  $c->render_later->ua->get($url => sub {
    my($ua, $tx) = @_;
    $c->render(
      json => $tx->res->json || {},
      status => $tx->res->code || 500,
    );
  });
}

=head2 services

  GET /services
  GET /services/:service_name

Returns a json object with the services available and statuses:

  {
    "multi_service_name": {
      "child_service_name": {
        "status":"running"
      }
    }
  }

Is is also possible to ask for "?flat=1" which will result in this response:

  {
    "services": {
      "multi_service_name.child_service_name": {
        "status":"running"
      }
    }
  }

=cut

sub services {
  my($self, $c) = @_;
  my $flat = $c->param('flat') ? $self->_json : undef;
  my $json = $self->_json;
  my $status_method = $c->param('cached') ? 'cached_status': 'status';
  my $service;

  if(my $name = $c->stash('name')) {
    if(!Ubic->has_service($name)) {
      $json->{error} = 'Not found';
      return $c->render(json => $json, status => 404);
    }
    $service = Ubic->service($name);
  }
  else {
    $service = Ubic->root_service;
  }

  $self->_traverse($service, $json, sub {
    my($service, $data) = @_;

    unless($service->isa('Ubic::Multiservice')) {
      $data->{status} = Ubic->$status_method($service->full_name);
      $flat->{services}{$service->full_name}{status} = $data->{status} if $flat;
    }
  });

  $c->render(json => $flat ? $flat : $json);
}

=head2 status

  GET /service/:service_name
  GET /service/:service_name/status

Used to get the status of a given service. Example JSON response:

  {"status":"running"}

=cut

sub status {
  my($self, $c) = @_;
  my $name = $c->stash('name');
  my $json = $self->_json;
  my $status_method = $c->param('cached') ? 'cached_status': 'status';

  if(!Ubic->has_service($name)) {
    $json->{error} = 'Not found';
    return $c->render(json => $json, status => 404);
  }

  eval {
    $json->{status} = Ubic->$status_method($name);
    1;
  } or do {
    $json->{error} = $@;
  };

  $c->render(json => $json, status => $json->{error} ? 500 : 200);
}

=head1 METHODS

=head2 register

  $app->plugin(Ubic => \%config);

Will register the L</ACTIONS> above. Possible C<%config>:

=over 4

=item * data_dir

Default to L<Ubic::Settings/data_dir>.

=item * default_user

Default to L<Ubic::Settings/default_user>.

=item * service_dir

Default to L<Ubic::Settings/service_dir>.

=item * json

A datastructure (hash-ref) which is included in all the responses. Could
contain data such as uptime, hostname, ...

=item * layout

Used to set the layout which the L<HTML|/index> will rendered inside.
Default is "ubic" which is defined in this package.

=item * remote_servers

A list of URL which point to other web servers compatible with the API
defined in this package. This allow L</proxy> to run commands on all
servers, including the current. Example:

  [
    "http://10.1.2.3/secret/ubic/path",
    "http://10.1.2.4/other/secret/path",
  ]

=item * route

A L<Mojolicious::Route> object where the L</ACTIONS> should be mounted.

=item * command_route

A L<Mojolicious::Route> object where L</command> should be mounted. Default
is same as L</route>.

=item * valid_actions

A list of valid actions for L</command> to run. Default is:

  [ "start", "stop", "reload", "restart" ]

=back

=cut

sub register {
  my($self, $app, $config) = @_;
  my $r = $config->{route} or die "'route' is required in config";
  my $p = $config->{command_route} || $r;

  Ubic::Settings->data_dir($config->{data_dir}) if $config->{data_dir};
  Ubic::Settings->default_user($config->{default_user}) if $config->{default_user};
  Ubic::Settings->service_dir($config->{service_dir}) if $config->{service_dir};
  Ubic::Settings->check_settings;

  $self->{json} = $config->{json} || {};
  $self->{layout} = $config->{layout} || 'ubic';
  $self->{remote_servers} = $config->{remote_servers} || [];
  $self->{valid_actions} = $config->{valid_actions} || [qw( start stop reload restart )];

  for my $server (@{ $self->{remote_servers} }) {
    next if ref $server;
    $server = Mojo::URL->new($server);
  }

  $r->get('/')->name('ubic_index')->to(cb => sub { $self->index(@_) });
  $r->get('/services/*name', { name => '' })->name('ubic_services')->to(cb => sub { $self->services(@_) });
  $r->get('/service/#name/:command', { command => 'status' }, [ command => 'status' ])->to(cb => sub { $self->status(@_) });
  $p->any('/service/#name/:command')->name('ubic_service')->to(cb => sub { $self->command(@_) });
  $p->any('/proxy/#to/#name/:command')->name('ubic_proxy')->to(cb => sub { $self->proxy(@_) });

  push @{ $app->renderer->classes }, __PACKAGE__;
}

sub _json {
  return { %{ shift->{json} } };
}

sub _remote_servers {
  my($self, $c) = @_;
  my $servers = $self->{remote_servers};

  if(!$self->{init_remote_servers}++) {
    push @$servers, $c->req->url->to_abs->clone;
  }

  return @$servers;
}

sub _traverse {
  my($self, $service, $json, $cb) = @_;
  my $name = $service->name;

  if($service->isa('Ubic::Multiservice')) {
    my $name = $service->name;
    my $data = $name ? $json->{$name} ||= {} : $json;

    $data->{services} ||= {};
    $cb->($service, $data);
    $self->_traverse($_, $data->{services}, $cb) for $service->services;
  }
  else {
    $cb->($service, $json->{$name} ||= {});
  }
}

=head1 COPYRIGHT

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;

__DATA__
@@ layouts/ubic.html.ep
<!DOCTYPE html>
<head>
  <title><%= title %></title>
  <style>
    body { background: #fefefe; color: #1c2e40; margin: 0; padding: 30px 20px; font-size: 14px; font-family: sans-serif; }
    a { color: #1c2e40; text-decoration: none; }
    a.refresh { display: block; position: absolute; top: 0; padding: 4px 8px; background: #eee; border: 1px solid #aaa; border-top: 0; }
    .error { color: #900; }
    h1 { display: none; }
    h3 { margin: 10px 0 0 0; }
    table { border-spacing: 1px; width: 100%; }
    tr td { padding: 3px; }
    tr td.action { padding: 0; width: 1px; }
    tr td.action a { display: block; padding: 3px 8px; }
    tr a.is { color: #666; }
    tr.running { background: #2ecc71; }
    tr.running a.is { color: #0eac51; }
  </style>
  %= javascript '/mojo/jquery/jquery.js'; # bad idea
  <script>
  $(document).ready(function() {
    $('.action a').click(function(e) {
      $.get(this.href, function(data) { location.reload(); });
      return false;
    });
  });
  </script>
</head>
<body>
  %= content
</body>
</html>
@@ ubic/services.html.ep
% for my $name (sort keys %$services) {
  % my $data = $services->{$name};
  % my $fqn = join '.', @$pre, $name;
  % my $status = $data->{status} || 'unknown';
  <tr class="service<%= $status =~ /^running/ ? ' running' : '' %>">
    <td class="name"><%= $fqn %></td>
    <td class="status" title="<%= $status || '' %>"><%= ucfirst $status || 'Unknown' %></td>
    <td class="action"><%= link_to 'Start', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'start' }, class => $status =~ /^running/i ? 'is' : 'isnt' %></td>
    <td class="action"><%= link_to 'Stop', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'stop' }, class => $status =~ /^running/i ? 'isnt' : 'is' %></td>
    <td class="action"><%= link_to 'Reload', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'reload' }, class => 'isnt' %></td>
    <td class="action"><%= link_to 'Restart', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'restart' }, class => 'isnt' %></td>
  </tr>
% }

@@ ubic/index.html.ep
% title 'Process overview';
<h1>Ubic services overview</h1>
%= link_to 'Refresh', '', class => 'refresh', title => 'Refresh ubic service list'
<table>
% for my $remote (@$remotes) {
  <tr>
    <td colspan="6">
      <h3 class="host"><%= $remote->{hostname} || $remote->{tx}->req->url->host %></h3>
    % if($remote->{error}) {
      <div class="error"><%= $remote->{error} %></div>
    % }
    </td>
  </tr>
  % if(!$remote->{error}) {
    %= include 'ubic/services' => %$remote, pre => [], remote => $remote
  % }
% }
</table>
