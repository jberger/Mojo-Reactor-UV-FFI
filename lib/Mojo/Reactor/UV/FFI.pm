package Mojo::Reactor::UV::FFI;

$ENV{MOJO_REACTOR} ||= __PACKAGE__;

use Mojo::Base 'Mojo::Reactor';

use Mojo::Reactor::UV::FFI::Util ':all';

use List::MoreUtils qw/first_index/;
use FFI::Raw;

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

_ffi_method uv_version => 'uint';

_ffi_method uv_version_string => 'str';

sub version {
  my $self = shift;
  require Scalar::Util;
  return Scalar::Util::dualvar($self->uv_version, $self->uv_version_string);
}

_ffi_method uv_strerror => qw/str int/;

_ffi_method uv_loop_new => qw/ptr/;

_ffi_method uv_run => qw/int ptr int/;

_ffi_method uv_stop => qw/void ptr/;

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

_ffi_method uv_now => qw/uint64 ptr/;

sub now { my $self = shift; $self->uv_now($self->loop) }

_ffi_method uv_timer_init => qw/int ptr ptr/;

_ffi_method uv_timer_start => qw/int ptr ptr uint64 uint64/;

_ffi_method uv_timer_stop => qw/int ptr/;

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
    $self->_sandbox("Timer $id", $cb); 
    $self->remove($id) unless $recurring; 
    return;
  };
  my $ffi_cb = _ffi_callback $sub, qw/void ptr int/;
  $self->uv_timer_start($timer, $ffi_cb, $timeout, $recurring ? $timeout : 0);

  $self->timers->{$id} = {
    timer => $timer,
    cb    => $ffi_cb,
  };
  return $id
}

_ffi_method uv_timer_again => qw/int ptr/;

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

_ffi_method uv_handle_size => qw/uint uint/;

sub handle_size {
  my ($self, $type) = @_;
  $type = lc $type;
  return $self->uv_handle_size(first_index { $_ eq $type } @Handle_Types);
}

sub _sandbox {
  my ($self, $event, $cb) = (shift, shift, shift);
  eval { $self->$cb(@_); 1 } or $self->emit(error => "$event failed: $@");
}

1;

