use 5.008;
use strict;
use warnings;
use utf8;
package Dist::Zilla::Plugin::Twitter;
# ABSTRACT: Twitter when you release with Dist::Zilla
# VERSION

use Dist::Zilla 4 ();
use Carp qw/confess/;
use Moose 0.99;
use Math::BigFloat;
use Net::Twitter 3 ();
use Net::Netrc;
use WWW::Shorten::Simple ();  # A useful interface to WWW::Shorten
use WWW::Shorten 3.02 ();     # For latest updates to dead services
use WWW::Shorten::TinyURL (); # Our fallback
use namespace::autoclean 0.09;

# extends, roles, attributes, etc.
with 'Dist::Zilla::Role::AfterRelease';
with 'Dist::Zilla::Role::TextTemplate';

has 'tweet' => (
  is  => 'ro',
  isa => 'Str',
  default => 'Released {{$DIST}}-{{$VERSION}}{{$TRIAL}} {{$URL}}'
);

has 'tweet_url' => (
  is  => 'ro',
  isa => 'Str',
  default => 'http://cpan.cpantesters.org/authors/id/{{$AUTHOR_PATH}}/{{$DIST}}-{{$VERSION}}{{$TRIAL}}.readme',
);

has 'url_shortener' => (
  is    => 'ro',
  isa   => 'Str',
  default => 'TinyURL',
);

has 'hash_tags' => (
  is  => 'ro',
  isa => 'Str',
);

has '_rand_seeds' => (
  is => 'ro',
  isa => 'Str',
  default => sub { join "", split ' ', << 'END' },
03884190589791863469189060237853049564342773167744114729807611832669412883895228
31253625161198905176053401597356713056921023097406105061880584999571024672060794
86013918021617497503618418233574380087737346557246997678896429825127827468101095
25791892498554477762923406156183181408721453703891765969738832180609156490372403
73511438297337107994372696325115656972981744733701363540887119817314093624711160
40256764967308723577201512346790358311345991172296590467003539628919786528527817
65026441862982391128038211373455990051026195631971521523474734405270902106760713
79412792816831779140828276921475379686838748037593273782341892407870310086816287
86365891218283705850533472614273877630015460792954614844517592283486923196509341
49394607802342863532904382417320994958127855500862324333866126835346221923828125
END
);

# methods

sub after_release {
    my $self = shift;
    my $tgz = shift || 'unknowntarball';
    my $zilla = $self->zilla;

    my $cpan_id = '';
    for my $plugin ( @{ $zilla->plugins_with( -Releaser ) } ) {
      if ( my $user = eval { $plugin->user } || eval { $plugin->username } ) {
        $cpan_id = uc $user;
        last;
      }
    }
    confess "Can't determine your CPAN user id from a release plugin"
      unless length $cpan_id;

    my $path = substr($cpan_id,0,1)."/".substr($cpan_id,0,2)."/$cpan_id";

    my $stash = {
      DIST => $zilla->name,
      VERSION => $zilla->version,
      TRIAL   => ( $zilla->is_trial ? '-TRIAL' : '' ),
      TARBALL => "$tgz",
      AUTHOR_UC => $cpan_id,
      AUTHOR_LC => lc $cpan_id,
      AUTHOR_PATH => $path,
    };
    my $module = $zilla->name;
    $module =~ s/-/::/g;
    $stash->{MODULE} = $module;

    my $longurl = $self->fill_in_string($self->tweet_url, $stash);
    foreach my $service (($self->url_shortener, 'TinyURL')) { # Fallback to TinyURL on errors
      my $shortener = WWW::Shorten::Simple->new($service);
      $self->log("Trying $service");
      $stash->{URL} = eval { $shortener->shorten($longurl) } and last;
    }

    my $msg = $self->fill_in_string( $self->tweet, $stash);
    if (defined $self->hash_tags) {
        $msg .= " " . $self->hash_tags;
    }

    my ($l, $p);

    eval {
        ($l,$p) = Net::Netrc->lookup('api.twitter.com')->lpa;
    } or confess "Can't get Twitter credentials from .netrc";
    my $nt = Net::Twitter->new(
      useragent_class => $ENV{DZ_TWITTER_USERAGENT} || 'LWP::UserAgent',
      traits => [qw/API::REST OAuth/],
      $self->_pp_sign($l,$p),
    );
    $nt->xauth($l,$p);
    $nt->update($msg);

    $self->log($msg);
    return 1;
}

sub _pp_sign {
  my ($self,$l,$p) = @_;
  my $n = Math::BigFloat->new( map {s{.}{.};$_} $self->_rand_seeds );
  eval join'',map{$n*=256;$n->bsub($l=$n->copy->bfloor);chr$l}1..100;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=for Pod::Coverage
  after_release

=begin wikidoc

= SYNOPSIS

In your {dist.ini}:

  [Twitter]
  hash_tags = #foo
  url_shortener = TinyURL

In your {.netrc}:

   machine api.twitter.com
     login YOUR_TWITTER_USER_NAME
     password YOUR_TWITTER_PASSWORD

= DESCRIPTION

This plugin will use [Net::Twitter] with the login and password in your
{.netrc} file to send a release notice to Twitter.  By default, it will include
a link to your README file as extracted on a fast CPAN mirror.  This works
very nicely with [Dist::Zilla::Plugin::ReadmeFromPod].

The default configuration is as follows:

  [Twitter]
  tweet_url = http://cpan.cpantesters.org/authors/id/{{$AUTHOR_PATH}}/{{$DIST}}-{{$VERSION}}{{$TRIAL}}.readme
  tweet = Released {{$DIST}}-{{$VERSION}}{{$TRIAL}} {{$URL}}
  url_shortener = TinyURL

The {tweet_url} is shortened with [WWW::Shorten::TinyURL] or
whichever other service you choose and
appended to the {tweet} messsage.  The following variables are
available for substitution in the URL and message templates:

      DIST        # Foo-Bar
      VERSION     # 1.23
      TRIAL       # -TRIAL if is_trial, empty string otherwise.
      TARBALL     # Foo-Bar-1.23.tar.gz
      AUTHOR_UC   # JOHNDOE
      AUTHOR_LC   # johndoe
      AUTHOR_PATH # J/JO/JOHNDOE
      URL         # http://tinyurl.com/...

You must be using the {UploadToCPAN} or {FakeRelease} plugin for this plugin to
determine your CPAN author ID.

You can use the {hash_tags} option to append hash tags (or anything,
really) to the end of the message generated from {tweet}.

  [Twitter]
  hash-tags = #perl #cpan #foo

=end wikidoc

=cut

