package Rubic;

=head1 NAME

Rubic - Remote admin tool for ubic

=head1 VERSION

0.07

=head1 DESCRIPTION

The distribution contains a web server "rubic" which allow you to run L<Ubic>
commands using a L<REST API|Mojolicious::Plugin::Ubic/ACTIONS>. It also has
a HTML based web interface or easy administration for humans.

This is L<Ubic::Ping::Service> on steroids.

See also L<Mojolicious::Plugin::Ubic>.

=head1 SYNOPSIS

  $ rubic daemon --listen http://*:5000

Look for "Base path" in the output. Example:

  [Sun Nov 17 13:45:06 2013] [info] Base path: /e3927cec591094d8294dfff30f1110f3

Point your browser at C<http://localhost:5000/e3927cec591094d8294dfff30f1110f3>

=head2 Environment variables

=over 4

=item * UBIC_BASE_PATH

Set your own "Base path" instead of using the auto-generated. This should be
something very long to make it "impossible" to brute force.

=item * MOJO_CONFIG

Possible to configure the application using a config file in Perl format.

=back

=head1 FAQ

=over 4

=item What is ubic?

See L<Ubic::Manual::FAQ>.

=item Why this weird "Base path"?

Just to make it a bit safer, without requiring user/password. It is possible
to make it safer by mouting the plugin in your own L<Mojolicious> application,
where you can add any sort of authentication you want.

=item What about SSL support?

It should be supported out of the box if you install L<IO::Socket::SSL>:

  $ rubic daemon --listen https://*:5000

See L<Mojo::Server::Daemon/listen> for more inforation about the C<--listen>
argument.

=back

=cut

use strict;

our $VERSION = '0.07';

=head1 COPYRIGHT

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
