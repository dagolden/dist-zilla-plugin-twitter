use strict;
use warnings;

use lib 't/lib';
use LWP::TestUA; # mocked UA
use Net::Netrc; # mocked version

use Test::More 0.88;
use Path::Class;

use Dist::Zilla::App::Tester;
use Test::DZil;

## SIMPLE TEST WITH DZIL::APP TESTER

$ENV{DZ_TWITTER_USERAGENT} = 'LWP::TestUA';

my $dist = 'DZ-Test';
my $result = test_dzil("corpus/$dist", [ qw(release) ]);

is($result->exit_code, 0, "dzil release would have exited 0");

my $module = $dist;
$module =~ s/-/::/g;
my $url = "http://p3rl.org/$module";
my $msg = "[Twitter] Released $dist-v1.2.2 $url #bar";

ok(
  (grep { $_ eq $msg } @{ $result->log_messages }),
  "we logged the Twitter message",
) or diag "STDOUT:\n" . $result->output . "STDERR:\n" . $result->error;

ok (
   (grep { $_ eq '[Twitter] Trying Metamark' } @{ $result->log_messages }),
   'Log claims we tried to use WWW::Shorten::Metamark',
) or diag "STDOUT:\n" . $result->output . "STDERR:\n" . $result->error;

done_testing;
