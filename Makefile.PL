use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mojolicious::Plugin::Ubic',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/Ubic.pm',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Ubic.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    '::usr::lib::perl::5.14::auto::POSIX::autosplit.ix' => '0',
    '::usr::lib::perl::5.14::auto::POSIX::load_imports.al' => '0',
    'Class::Accessor' => '0.34',
    'JSON' => '2.59',
    'JSON::XS' => '2.34',
    'List::MoreUtils' => '0.33',
    'Module::Implementation' => '0.07',
    'Module::Runtime' => '0.013',
    'Mojo::Base' => '0',
    'Mojolicious::Plugin' => '0',
    'Params::Validate' => '1.08',
    'Sub::Name' => '0.05',
    'Try::Tiny' => '0.18',
    'Ubic' => '1.56',
    'common::sense' => '3.6',
  },
  BUILD_REQUIRES => {

  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mojolicious-Plugin-Ubic',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-Ubic',
      repository => 'git://github.com/',
     #MailingList => 'some-mailing@list.org',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
  #MIN_PERL_VERSION => 5.10,
  #EXE_FILES => ['bin/my-app'],
);
