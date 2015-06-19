package Logbot;
use Mojo::Base 'Mojolicious';
use Logbot::IRC;
use experimental qw(postderef signatures);

sub startup ($c) {
	my $config = $c->plugin('Config');

	my $r = $c->routes;

	$c->helper(irc => sub {
		state $irc = Logbot::IRC->new(
			channels => $config->{irc}->{channels},
			user => $config->{irc}->{user},
			nick => $config->{irc}->{nick},
			server => $config->{irc}->{server},
			pass => $config->{irc}->{pass},
		);
	});

	$c->irc->on(message => sub ($irc, $channel, $user, $message) {
		$irc->say($user => "hi $user. did you say $message?");
	});

	$c->irc->connect;
}

1;
