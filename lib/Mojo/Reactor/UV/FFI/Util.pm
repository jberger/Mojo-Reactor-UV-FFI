package Mojo::Reactor::UV::FFI::Util;

use Mojo::Base -strict;

use FFI::Raw;
use Math::Int64; # required when FFI::Raw uses 64 bit ints

use Exporter 'import';
use Carp;

our @EXPORT_OK = qw/_ffi_method _ffi_callback _p/;

our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

use constant LIB => $ENV{MOJO_REACTOR_UV_FFI_LIB} || '/usr/local/lib/libuv.so';

sub type_map { map { FFI::Raw->can($_)->() } @_ }

sub _ffi_method {
  my $name = shift;
  my $caller = caller;

  my $ffi = FFI::Raw->new( LIB, $name, type_map @_ );
  my $sub = sub { local @_ = @_; $_[0] = $ffi; goto $ffi->can('call') };
  no strict 'refs';
  *{"${caller}::$name"} = $sub;
}

sub _ffi_callback { FFI::Raw::callback(shift, type_map @_) }

sub _p ($) { FFI::Raw::MemPtr->new_from_ptr(shift) }


1;

