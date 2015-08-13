package Logbot::IRC;
use Mojo::Base 'Mojo::IRC';
use Mojo::IOLoop;
use Mojo::IOLoop::Delay;
use Mojo::Log;

use experimental qw(postderef signatures);
use Data::Dumper qw(Dumper);

use constant DEBUG => $ENV{LOGBOT_DEBUG} ? 1 : 0;

has channels => sub { [ '#blorgbot' ] };
has log => sub { state $irc = Mojo::Log->new };
has polite_delay => sub { 2 };

sub new {
	my $self = shift->SUPER::new(@_);

	$self->on(irc_join => sub ($, $msg) {
		$self->emit(joined => $msg->{params}[0]);
	});

	$self->on(irc_privmsg => sub ($, $msg) {
		# message->{prefix} looks like this:
		# FoobarUser!US_0@1799.lobby.springrts.com
		my @prefix = split/!/, $msg->{prefix};
		my $user = shift @prefix;
		my ($channel, $message) = $msg->{params}->@[0, 1];

		warn "$channel >>>>> $user: $message\n" if DEBUG;

		$self->emit(message => $channel, $user, $message);
	});

	$self->on(error => sub {
		my ($self, $err) = @_;
		$self->log->warn("error in IRC connection: $err");
	});

	$self->on(close => sub {
		Mojo::IOLoop->timer($self->polite_delay => sub {
			$self->connect;
		});
	});

	$self->on(irc_rpl_welcome => sub ($, $params) {
		Mojo::IOLoop->delay(
			sub ($d) {
				Mojo::IOLoop->timer($self->polite_delay => $d->begin);
			},
			sub ($d) {
				for my $chan ($self->channels->@*) {
					$self->join($chan, $d->begin);
				}
			},
			sub ($d, @write_errs) {
				die @write_errs if grep { $_ } @write_errs;
				$self->emit('joined_all_channels');
			}
		)->catch(sub ($d, @errs) {
			$self->log->error("errors joining channels: " . join "\n", @errs);
		})->wait;
	});

	return $self;
}

sub connect ($self, $cb = '') {
	$cb = ref $cb eq 'CODE' ? $cb : sub {
		$self->log->info("logbot has connected to " . $self->server);
	};

	$self->register_default_event_handlers;

	$self->SUPER::connect($cb);
}

sub join ($self, $chan, $cb) {
	$self->write(join => $chan, $cb);
}

sub say ($self, $channel, $message, $cb = sub {}) {
	warn "$channel <<<<< $message\n" if DEBUG;
	$self->write(PRIVMSG => $channel, ":$message", $cb);
}

sub announce ($self, $channels, $message, $cb = sub {}) {
	Mojo::IOLoop->delay(
		sub ($d) {
			for my $chan ($channels->@*) {
				for my $chunk ($message->@*) {
					$self->say($chan, $chunk, $d->begin);
				}
			}
		},
		sub ($d, @err) {
			my @errors = grep { $_ } @err;
			die @errors if @errors;

			$self->$cb;
		}
	)->wait;
}

1;

=head1 NAME

Logbot::IRC -- wrapper around Mojo::IRC for the notification/logbot

=head1 SYNOPSIS

	my $irc = Logbot::IRC->new(
		channels => [qw( #foo #bar #baz) ],
		nick => '[S44]BlorgBot',
		user => '[S44]BlorgBot',
		pass => 'something_secret',
		server => 'irc.springrts.com:6667',
	);

	$irc->connect;
	# echo bot in all active channels
	$irc->on(message => sub ($, $channel, $user, $message) {
		$irc->say($channel => "$user says $message!");
	});

=head1 DESCRIPTION

	This transforms Mojo::IRC events into a slightly higher level interface.

=cut
