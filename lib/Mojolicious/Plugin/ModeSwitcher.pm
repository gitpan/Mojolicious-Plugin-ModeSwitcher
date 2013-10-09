package Mojolicious::Plugin::ModeSwitcher;

use Mojo::Base 'Mojolicious::Plugin';
use Data::Dumper;

our $VERSION = '0.02';

sub register {
  my ( $plugin, $app ) = @_;

  $app->helper(
    switch_config => sub {
      my ( $self, %arg ) = @_;
      my $mode = $self->app->mode;

      if ( $arg{reload} ) {
        delete $self->stash->{'switch_config'};
        delete $self->stash->{'switch_config_err'};
      }

      if ( !$self->stash( 'switch_config' ) ) {
        my $conf = {};

        if ( $arg{file} && -r $arg{file} ) {
          $conf = _load_file( $arg{file}, $mode );
        }

        if ( !$conf->{_err} ) {
          if ( $arg{include} ) {
            foreach my $param ( keys %{$conf} ) {
              next if $conf->{$param} !~ /\.(yml|json)$/;
              $conf->{$param} = _load_file( $conf->{$param}, $mode, 1 );
            }
          }

          if ( $arg{eval} && $arg{eval}{$mode} ) {
            my $ret = eval $arg{eval}{$mode}{code};

            if ( $@ ) {
              $conf->{switch_config_err} = $@;
            }
            else {
              if ( $arg{eval}{$mode}{key} ) {
                $conf->{ $arg{eval}{$mode}{key} } = $ret;
              }
              else {
                $conf = $ret;
              }
            }
          }

          push @{ $app->renderer->paths }, $conf->{templates_path} if $conf->{templates_path};
          push @{ $app->static->paths },   $conf->{static_path}    if $conf->{static_path};

          $self->stash( switch_config => $conf );
        }
        else {
          $self->stash( switch_config_err => $conf->{_err} );
        }
      }
      return $self->stash( 'switch_config' );
    }
  );
}

sub _load_package {
  my $ext = shift;
  my %lst = (
    yml  => [qw( YAML::XS YAML YAML::Tiny )],
    json => [qw( JSON::XS JSON Mojo::JSON )]
  );

  foreach my $pkg ( @{ $lst{$ext} } ) {
    eval "use $pkg";
    if ( !$@ ) {
      my $ret = $pkg . "::";
      if ( $pkg =~ /^YAML/ ) { $ret .= 'Load'; }
      elsif ( $pkg ~~ [ 'JSON::XS', 'JSON' ] ) { $ret .= 'decode_json'; }
      else                                     { $ret .= 'decode'; }
      return { err => 0, name => $ret };
    }
  }
  return { err => 'No module name found' };
}

sub _load_file {
  my ( $file, $mode, $without ) = @_;
  my $ext = ( $file =~ /\.(\w+$)/ )[0];

  my $src;
  eval {
    open my $fh, $file or return;
    $src .= $_ while <$fh>;
    close $fh;
  };

  return { _err => $@ || $! } if $@ || $!;

  my $pkg = _load_package( $ext );
  return { _err => $pkg->{err} } if $pkg->{err};

  my $res = eval $pkg->{name} . '($src)';
  return { _err => $@ } if $@;
  return $res->{$mode} ? $res->{$mode} : $res;
}

1;

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::ModeSwitcher - Configuration change by MOJO_MODE

=head1 ARGUMENTS

=head2 file

Reads the yml/json stream from a file instead of a string

=head2 reload

Reload configuration

=head2 include

If your configuration has a file.(yml|json), ModeSwitcher replace the value of the contents of the file

=head2 eval

Eval code

=head1 SPECIAL NAMES

If your configuration has B<static_path> or B<templates_path>, ModeSwitcher will make the:

  push @{ $app->renderer->paths }, $conf->{templates_path}
  push @{ $app->static->paths },   $conf->{static_path}

=head1 SYNOPSIS

  $self->plugin( 'ModeSwitcher' );
  ...
  $self->switch_config(
    file => 'etc/conf.yml'
    eval => {
      development => {
        code => '..',
        key  => 'db'
      },
      production  => { code => '..' }
    },
  );
  ...
  print self->stash( 'switch_config' )->{db_name};

=head1 AUTHOR

Grishkovelli L<grishkovelli@gmail.com>

=head1 Git

https://github.com/grishkovelli/Mojolicious-Plugin-ModeSwitcher

=head1 COPYRIGHT

Copyright (C) 2013, Grishkovelli.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
