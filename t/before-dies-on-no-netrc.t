use strict;
use warnings;

use Net::Netrc; # non-mocked version
use lib 't/lib';
use File::chdir;
use LWP::TestUA; # mocked UA

use Test::More 0.88;
use Test::Fatal;
use Path::Class;

use Dist::Zilla::App::Tester;
use Test::DZil;

## SIMPLE TEST WITH DZIL::APP TESTER

$ENV{DZ_TWITTER_USERAGENT} = 'LWP::TestUA';

my @test_data = (
    [ DZBad2 => qr/Can't get Twitter credentials from .netrc:/ ],
);

for my $data (@test_data) {

    my ($dist, $error_re) = @$data;
    local $ENV{HOME} = dir('.', 'corpus', $dist)->absolute->stringify;
    my $result = test_dzil("corpus/$dist", [ qw(release) ]);

    like $result->error, $error_re, 'got the error message we were expecting';
}

done_testing;
