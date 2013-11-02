package Mojolicious::Plugin::Ubic;

=head1 NAME

Mojolicious::Plugin::Ubic - Remote ubic admin

=head1 VERSION

0.04

=head1 SYNOPSIS

  #!perl
  use Mojolicious::Lite;

  plugin Ubic => {
    route => app->routes->route('/something/secure'),
    json => {
      some => 'default values',
    },
  };

  app->start;

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

our $VERSION = '0.04';

=head1 ACTIONS

=head2 index

Draw a tree using HTML.

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
        ...
      }
      ...
    }
    ...
  }

=cut

sub services {
  my($self, $c) = @_;
  my $json = $self->_json;
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
    $data->{status} = $service->status unless $service->isa('Ubic::Multiservice');
  });

  $c->render(json => $json);
}

=head2 service

  GET /:service_name
  GET /:service_name/status
  POST /:service_name/start
  POST /:service_name/reload
  POST /:service_name/restart
  POST /:service_name/stop

Used to control a given service. The actions act like <ubic> from the command
line. The return value contain "status". Example:

  {"status":"running"}

=cut

sub service {
  my($self, $c) = @_;
  my $command = $c->stash('command');
  my $name = $c->stash('name');
  my $valid = grep { $command eq $_ } @{ $self->{valid_actions} };
  my $json = $self->_json;
  my $service;

  if(!$valid) {
    $json->{error} = 'Invalid command';
    return $c->render(json => $json, status => 400);
  }
  if(!Ubic->has_service($name)) {
    $json->{error} = 'Not found';
    return $c->render(json => $json, status => 404);
  }

  $service = Ubic->service($name);

  if($service->isa('Ubic::Multiservice')) {
    $json->{error} = 'Cannot run actions on Ubic::Multiservice';
    return $c->render(json => $json, status => 400);
  }

  eval {
    $service->$command;
    $json->{status} = $service->status;
    1;
  } or do {
    $json->{error} = $@;
  };

  $c->render(json => $json, status => $json->{error} ? 500 : 200);
}

=head1 METHODS

=head2 register

Will register the L</ACTIONS> above.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $r = $config->{route} or die "'route' is required in config";
  my $p = $config->{command_route} || $r;

  Ubic::Settings->service_dir($config->{service_dir}) if $config->{service_dir};
  Ubic::Settings->data_dir($config->{data_dir}) if $config->{data_dir};
  Ubic::Settings->default_user($config->{default_user}) if $config->{default_user};
  Ubic::Settings->check_settings;

  $self->{json} = $config->{json} || {};
  $self->{layout} = $config->{layout} || 'ubic';
  $self->{remote_servers} = $config->{remote_servers} || [];
  $self->{valid_actions} = $config->{valid_actions} || [qw( start stop reload restart status )];

  for my $server (@{ $self->{remote_servers} }) {
    next if ref $server;
    $server = Mojo::URL->new($server);
  }

  $r->get('/')->name('ubic_index')->to(cb => sub { $self->index(@_) });
  $r->get('/services/*name', { name => '' })->name('ubic_services')->to(cb => sub { $self->services(@_) });
  $p->any('/service/#name/:command', { command => 'status' })->name('ubic_service')->to(cb => sub { $self->service(@_) });
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
<html>
%= content
</html>
@@ ubic/services.html.ep
% for my $name (sort keys %$services) {
  % my $data = $services->{$name};
  % if($data->{services}) {
  %= include 'ubic/services' => %$data, pre => [@$pre, $name], remote => $remote
  % } else {
    % my $fqn = join '.', @$pre, $name;
    % my $status = $data->{status} || 'unknown';
  <tr class="service<%= $status =~ /^running/ ? ' running' : '' %>">
    <td class="name"><%= $fqn %></td>
    <td class="status" title="<%= $status || '' %>"><%= ucfirst $status || 'Unknown' %></td>
    <td class="action"><%= link_to 'Start', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'start' }, class => $status =~ /^running/i ? 'is' : 'isnt' %></td>
    <td class="action"><%= link_to 'Stop', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'stop' }, class => $status =~ /^running/i ? 'isnt' : 'is' %></td>
    <td class="action"><%= link_to 'Reload', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'reload' }, class => 'isnt' %></td>
    <td class="action"><%= link_to 'Restart', ubic_proxy => { to => $remote->{tx}->req->url->host, name => $fqn, command => 'restart' }, class => 'isnt' %></td>
  % }
  </tr>
% }
</ol>

@@ ubic/index.html.ep
% title 'Process overview';
<h1>Ubic services overview</h1>
%= link_to 'Refresh', '', class => 'refresh', title => 'Refresh ubic service list'
% for my $remote (@$remotes) {
<h3 class="host"><%= $remote->{hostname} || $remote->{tx}->req->url->host %></h3>
  % if($remote->{error}) {
  <div class="error"><%= $remote->{error} %></div>
  % } else {
  <table>
    %= include 'ubic/services' => %$remote, pre => [], remote => $remote
  </table>
  % }
% }
