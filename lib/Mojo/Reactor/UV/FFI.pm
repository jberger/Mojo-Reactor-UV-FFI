package Mojo::Reactor::UV::FFI;

use Mojo::Base 'Mojo::Reactor';

use List::MoreUtils qw/first_index/;
use FFI::Raw;
use Math::Int64; # required when FFI::Raw uses 64 bit ints

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

has timers => sub { {} };
has loop => sub { shift->uv_loop_new };
has running => 0;

sub is_running { shift->running }

sub _build_ffi_method {
  my $name = shift;
  my $caller = caller;
  my $ffi = FFI::Raw->new(LIB, $name, map { FFI::Raw->can($_)->() } @_);
  my $sub = sub { local @_ = @_; $_[0] = $ffi; goto $ffi->can('call') };
  no strict 'refs';
  *{"${caller}::$name"} = $sub;
}

sub _p ($) { FFI::Raw::MemPtr->new_from_ptr(shift) }

_build_ffi_method uv_version => 'uint';

_build_ffi_method uv_version_string => 'str';

sub version {
  my $self = shift;
  require Scalar::Util;
  return Scalar::Util::dualvar($self->uv_version, $self->uv_version_string);
}

_build_ffi_method uv_strerror => qw/str int/;

_build_ffi_method uv_loop_new => qw/ptr/;

_build_ffi_method uv_run => qw/int ptr int/;

_build_ffi_method uv_stop => qw/void ptr/;

sub start {
  my $self = shift;
  return if $self->running;
  $self->running(1);
  $self->uv_run($self->loop, 0);
}

sub stop {
  my $self = shift;
  return unless $self->running;
  $self->uv_stop($self->loop);
  $self->running(0);
}

sub one_tick {
  my $self = shift;
  return if $self->running;
  local $self->{running} = 1;
  $self->uv_run($self->loop, 1);
}

_build_ffi_method uv_now => qw/uint64 ptr/;

sub now { my $self = shift; $self->uv_now($self->loop) }

_build_ffi_method uv_timer_init => qw/int ptr ptr/;

_build_ffi_method uv_timer_start => qw/int ptr ptr uint64 uint64/;

_build_ffi_method uv_timer_stop => qw/int ptr/;


sub timer     { shift->_timer(0, @_) }
sub recurring { shift->_timer(1, @_) }

sub _timer {
  my $self  = shift;
  my $recurring = shift;

  my $size  = $self->handle_size('timer');
  my $timer = FFI::Raw::memptr($size);
  $self->uv_timer_init($self->loop, $timer);
  my $id = $timer->tostr;

  my $timeout = 1000 * shift;
  my $cb = shift or die 'Need cb';
  my $sub = sub {
    my ($loop, $err) = @_;
    $cb->($self); 
    $self->remove($id) unless $recurring; 
    return;
  };
  my $ffi_cb = FFI::Raw::Callback->new($sub, FFI::Raw::void, FFI::Raw::ptr, FFI::Raw::int);
  $self->uv_timer_start($timer, $ffi_cb, $timeout, $recurring ? $timeout : 0);

  $self->timers->{$id} = {
    timer => $timer,
    cb    => $ffi_cb,
  };
  return $id
}

_build_ffi_method uv_timer_again => qw/int ptr/;

sub again {
  my ($self, $id) = @_;
  my $timer = $self->timers->{$id} or return;
  $self->uv_timer_again($timer->{timer});
}

sub remove {
  my ($self, $id) = @_;
  my $timer = delete $self->timers->{$id};
  $self->uv_timer_stop($timer->{timer});
}

_build_ffi_method uv_handle_size => qw/uint uint/;

sub handle_size {
  my ($self, $type) = @_;
  $type = lc $type;
  return $self->uv_handle_size(first_index { $_ eq $type } @Handle_Types);
}



1;

