package Logbot;
use Mojo::Base 'Mojolicious';
use Logbot::IRC;
use experimental qw(postderef signatures);

# This method will run once at server start
sub startup ($c) {
	my $config = $c->plugin('Config');

	my $r = $c->routes;

	$c->helper(irc => sub {
		state $irc = Logbot::IRC->new(
			user => $config->{irc}->{user},
			nick => $config->{irc}->{nick},
			server => $config->{irc}->{server},
			pass => $config->{irc}->{pass},
		);
	});

	$c->irc->connect;
}

1;
