use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojolicious::Plugin::Ubic',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/Ubic.pm',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Ubic.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Ubic' => '1.50',
    'Mojolicious' => '4.30',
  },
  BUILD_REQUIRES => {
    'Test::More' => 0.90,
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojolicious-Plugin-Ubic',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-Ubic',
      repository => 'git://github.com/jhthorsen/mojolicious-plugin-ubic',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  #EXE_FILES => ['bin/my-app'],
);
