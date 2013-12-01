#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::Reactor::UV::FFI;
my $r = Mojo::Reactor::UV::FFI->new;

say $r->version;

say "Size of timer: " . $r->_handle_size('timer');

say 'Instance: ' . $r->loop();
say "Now: " . $r->now();

