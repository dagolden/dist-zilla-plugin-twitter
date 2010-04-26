# crudly adapted from t/lib/TestUA.pm in Net::Twitter
use strict;
use warnings;
package LWP::TestUA;

use base 'LWP::UserAgent';

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->add_handler(
    request_send => sub { 
      my $res = HTTP::Response->new(200, 'OK');
      $res->content('{"test":"success"}');
      return $res
    },
  );
  return $self;
}

1;

