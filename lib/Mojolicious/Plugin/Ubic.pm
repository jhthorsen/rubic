package Mojolicious::Plugin::Ubic;

=head1 NAME

Mojolicious::Plugin::Ubic - Remote ubic admin

=head1 VERSION

0.03

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

our $VERSION = '0.03';

=head1 ACTIONS

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

  $self->{json} = $config->{json} || {};
  $self->{valid_actions} = $config->{valid_actions} || [qw( start stop reload restart status )];

  $r->get('/services/*name', { name => '' })
    ->name('ubic_services')
    ->to(cb => sub { $self->services(@_) })
    ;

  $r->get('/service/#name/:command', { command => 'status' })
    ->name('ubic_service')
    ->to(cb => sub { $self->service(@_) });
}

sub _json {
  return { %{ shift->{json} } };
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
