use 5.008;
use strict;
use warnings;
package Dist::Zilla::Plugin::Twitter;
# ABSTRACT: a module for CPAN

use Carp qw/confess/;
use Moose 0.99;
use WWW::Shorten::TinyURL 1 ();
use Net::Twitter 3 ();
use namespace::autoclean 0.09;

# extends, roles, attributes, etc.
with 'Dist::Zilla::Role::AfterRelease';
with 'Dist::Zilla::Role::TextTemplate';

has 'tweet' => (
  is  => 'ro',
  isa => 'Str',
  default => 'Released {{$DIST}}-{{$VERSION}} {{$URL}}'
);

has 'tweet_url' => (
  is  => 'ro',
  isa => 'Str',
  default => 'http://frepan.64p.org/~{{$AUTHOR}}/{{$TARBALL}}'
);


# methods

sub after_release {
    my $self = shift;
    my $tgz = shift || 'unknowntarball';
    my $zilla = $self->zilla;

    my $cpan_id = '';
    for my $plugin ( @{ $zilla->plugins_with( -Releaser ) } ) {
      if ( my $user = eval { $plugin->user } ) {
        $cpan_id = $user;
        last;
      }
    }
    confess "Can't determine your CPAN user id from a release plugin"
      unless length $cpan_id;

    my $stash = {
      DIST => $zilla->name,
      VERSION => $zilla->version,
      TARBALL => "$tgz",
      AUTHOR => lc $cpan_id,
    };

    my $longurl = $self->fill_in_string($self->tweet_url, $stash);
    $stash->{URL} = WWW::Shorten::TinyURL::makeashorterlink($longurl);

    my $msg = $self->fill_in_string( $self->tweet, $stash);

    my $nt = Net::Twitter->new(
      useragent_class => $ENV{DZ_TWITTER_USERAGENT} || 'LWP::UserAgent',
      traits => ['API::REST'],
      netrc => 1,
    );
    $nt->update($msg);

    $self->log($msg);
    return 1;
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=for Pod::Coverage
  after_release

=begin wikidoc

= SYNOPSIS

  use Dist::Zilla::Plugin::Twitter;

= DESCRIPTION

This module might be cool, but you'd never know it from the lack
of documentation.

= USAGE

Good luck!

== Configuration

   # in .netrc
   machine api.twitter.com
     login YOUR_TWITTER_USER_NAME
     password YOUR_TWITTER_PASSWORD

= SEE ALSO

Maybe other modules do related things.

=end wikidoc

=cut

