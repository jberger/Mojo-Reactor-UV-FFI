package Mojo::Reactor::UV::FFI;

use Mojo::Base 'Mojo::Reactor';

use List::MoreUtils qw/first_index/;
use FFI::Raw;

use constant LIB => $ENV{MOJO_REACTOR_UV_FFI_LIB} || '/usr/local/lib/libuv.so';

our @Handle_Types = qw/
  unknown
  async
  check
  fs_event
  fs_poll
  handle
  idle
  pipe
  poll
  prepare
  process
  stream
  tcp
  timer
  tty
  udp
  signal
/;

has ids => sub { {} };
has loop => sub { shift->loop_new };
has running => 0;

sub _build_ffi_method {
  my $name = shift;
  my $caller = caller;
  my $ffi = FFI::Raw->new(LIB, $name, map { FFI::Raw->$_ } @_);
  my $sub = sub { local @_ = @_; $_[0] = $ffi; goto $ffi->can('call') };
  no strict 'refs';
  *{"${caller}::$name"} = $sub;
}

_build_ffi_method uv_version => 'uint';

_build_ffi_method uv_version_string => 'str';

sub version {
  my $self = shift;
  require Scalar::Util;
  return Scalar::Util::dualvar($self->uv_version, $self->uv_version_string);
}

_build_ffi_method uv_loop_new => 'ptr';

_build_ffi_method uv_run => qw/int ptr int/;

_build_ffi_method uv_stop => qw/void ptr/;

sub start {
  my $self = shift;
  return if $self->running;
  $self->running(1);
  $self->loop_start($self->loop);
}

sub stop {
  my $self = shift;
  return unless $self->running;
  $self->loop_stop($self->loop);
  $self->running(0);
}

_build_ffi_method uv_timer_init => qw/int ptr ptr/;

_build_ffi_method uv_timer_start => qw/int ptr ptr uint64 unint64/;

_build_ffi_method uv_timer_stop => qw/int ptr/;

sub recurring {
  my $self  = shift;
  my $size  = $self->handle_size('timer');
  my $timer = FFI::Raw::memptr($size);
  $self->uv_timer_init($self->loop, $timer);

  my $timeout = shift * 1000;
  my $cb = shift;
  my $sub = sub { shift->$cb(); return }
  my $ffi_cb = FFI::Raw::callback($sub, FFI::Raw::void, FFI::Raw::ptr, FFI::int);
  $self->uv_timer_start($timer, $ffi_cb, $timeout, $timeout);

  my $id = $timer->tostr;
  $self->ids->{$id} = $timer;
  return $id
}

sub remove {
  my ($self, $id) = @_;
  my $timer = delete $self->ids->{$id};
  $self->uv_timer_stop($timer);
}

_build_ffi_method uv_handle_size => qw/uint uint/;

sub handle_size {
  my ($self, $type) = @_;
  $type = lc $type;
  return $self->uv_handle_size(first_index { $_ eq $type } @Handle_Types);
}



1;

