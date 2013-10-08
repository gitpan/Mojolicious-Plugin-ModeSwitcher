use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojolicious::Lite;

use FindBin '$Bin';
use lib "$Bin/../lib";

use_ok( 'Mojolicious::Plugin::ModeSwitcher' );

plugin 'ModeSwitcher';

get '/' => sub {
  my $self = shift;
  $self->switch_config(
    file    => 't/etc/conf.yml',
    mode    => 'development',
    include => 1
  );
  $self->render( 'test' );
};

my $t = Test::Mojo->new();
$t->get_ok( '/' )->status_is( 200 )->text_is( p => 'mojo' );

done_testing();

__DATA__
@@ test.html.ep
<p><%= $switch_config->{db_conf}{db_name} %></p>
