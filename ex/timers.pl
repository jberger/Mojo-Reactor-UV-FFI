#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::Reactor::UV::FFI;
use Mojo::IOLoop;

die 'Failed to detect Mojo::Reactor::UV::FFI' 
  unless Mojo::IOLoop->singleton->reactor->isa('Mojo::Reactor::UV::FFI');

my $i = 0;
my $id;
$id = Mojo::IOLoop->recurring( 1 => sub { 
  say 'tick ' . ++$i . '/3';
  Mojo::IOLoop->remove($id) if $i == 3;
});

Mojo::IOLoop->timer( 4 => sub {
  say 'Boom';
});

Mojo::IOLoop->start;

