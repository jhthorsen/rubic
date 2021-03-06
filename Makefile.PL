# Generated by git-ship. See 'git-ship --man' for help or https://github.com/jhthorsen/app-git-ship
use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Rubic',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'artistic_2',
  ABSTRACT_FROM => 'lib/Rubic.pm',
  VERSION_FROM => 'lib/Rubic.pm',
  EXE_FILES => [qw( script/rubic )],
  META_MERGE => {
    resources => {
      bugtracker => 'https://github.com/jhthorsen/rubic/issues',
      homepage => 'https://github.com/jhthorsen/rubic',
      repository => 'https://github.com/jhthorsen/rubic.git',
    },
  },
  BUILD_REQUIRES => {
  'Test::More' => '0.88'
}
,
  PREREQ_PM => {
  'Mojolicious' => '5.0',
  'Ubic' => '1.50'
}
,
  test => { TESTS => 't/*.t' },
);
