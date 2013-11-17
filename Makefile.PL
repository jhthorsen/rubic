use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Rubic',
  ABSTRACT_FROM => 'lib/Rubic.pm',
  VERSION_FROM => 'lib/Rubic.pm',
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
      homepage => 'https://metacpan.org/module/Rubic',
      bugtracker => 'https://github.com/jhthorsen/rubic/issues',
      repository => 'https://github.com/jhthorsen/rubic'
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  EXE_FILES => [
    'script/rubic',
  ],
);
