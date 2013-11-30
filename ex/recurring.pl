#!/usr/bin/env perl

use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::UV::FFI' }

use Mojo::IOLoop;

my $i = 0;
my $id;
$id = Mojo::IOLoop->recurring(1 => sub { 
  say 'tick ' . ++$i . '/3';
  Mojo::IOLoop->remove($id) if $i == 3;
});

Mojo::IOLoop->start;

