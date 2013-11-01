package Mojolicious::Plugin::Ubic;

=head1 NAME

Mojolicious::Plugin::Ubic - Remote ubic admin

=head1 VERSION

0.01

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
    $service = Ubic->service($name);
  }
  else {
    $service = Ubic->root_service;
  }

  if(!$service) {
    return $c->render(json => {}, status => 404);
  }

  $self->_traverse($service, $json, sub {
    my($service, $data) = @_;
    $data->{status} = $service->status unless $service->isa('Ubic::Multiservice');
  });

  $c->render(json => $json);
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

=head1 METHODS

=head2 register

Will register the L</ACTIONS> above.

=cut

sub register {
  my($self, $app, $config) = @_;
  my $r = $config->{route} or die "'route' is required in config";

  $self->{json} = $config->{json} || {};

  $r->get('/services/*name', { name => '' })->to(cb => sub { $self->services(@_) });
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
