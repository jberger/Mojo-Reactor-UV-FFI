#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::Reactor::UV::FFI;

say Mojo::Reactor::UV::FFI->version;

say "Size of timer: " . Mojo::Reactor::UV::FFI->handle_size('timer');

