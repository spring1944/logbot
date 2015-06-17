package Logbot::IRC;
use Mojo::Base 'Mojo::IRC';
use Mojo::IOLoop;
use experimental qw(postderef signatures);

sub new {
	my $self = shift->SUPER::new(@_);

	$self->register_default_event_handlers;

	$self->on(irc_join => sub ($, $msg) {
		say "yay! i joined $msg->{params}[0]";
		$self->write(PRIVMSG => '#blorgbot', 'blorg', sub ($, $err) {
			say $err if $err;
			say "finished blorging";
		});
	});

	$self->on(irc_privmsg => sub ($, $msg) {
		say $msg->{prefix}, " said: ", $msg->{params}[1];
		Mojo::IOLoop->timer(1 => sub {
			$self->write(PRIVMSG => '#blorgbot', ":you said: ", $msg->{params}[1]);
		});
	});

	$self->on(error => sub ($, $err) {
		say "bad; $err";
	});

	$self->on(close => sub ($, $message) {
		Mojo::IOLoop->timer(2 => sub {
			$self->connect;
		});
	});

	$self->on(irc_rpl_welcome => sub ($, $params) {
		Mojo::IOLoop->timer(2 => sub {
			$self->write(join => '#blorgbot');
		});
	});

	return $self;
}

sub connect ($self, $cb = '') {
	$cb = ref $cb eq 'CODE' ? $cb : sub {
		say "the bot has connected!";
	};

	$self->SUPER::connect($cb);
}

1;
