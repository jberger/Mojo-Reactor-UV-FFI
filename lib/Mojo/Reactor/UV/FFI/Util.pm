package Mojo::Reactor::UV::FFI::Util;

use Mojo::Base -strict;

use FFI::Raw;
use Math::Int64; # required when FFI::Raw uses 64 bit ints

use Exporter 'import';
use Carp;

our @EXPORT_OK = qw/_build_ffi_method _p/;

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

use constant LIB => $ENV{MOJO_REACTOR_UV_FFI_LIB} || '/usr/local/lib/libuv.so';

sub _build_ffi_method {
  my $name = shift;
  my $caller = caller;

  my $ffi = FFI::Raw->new( LIB, $name, map { FFI::Raw->can($_)->() } @_ );
  my $sub = sub { local @_ = @_; $_[0] = $ffi; goto $ffi->can('call') };
  no strict 'refs';
  *{"${caller}::$name"} = $sub;
}

sub _p ($) { FFI::Raw::MemPtr->new_from_ptr(shift) }

1;

