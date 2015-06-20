package Logbot;
use Mojo::Base 'Mojolicious';

use Logbot::IRC;

use experimental qw(postderef signatures);

sub startup ($app) {
	my $config = $app->plugin('Config');

	$app->helper(config => sub {
		state $config = $config;
	});

	$app->helper('reply.exception' => sub ($c, $err) {
		$app->log->error("broken page: ", $err->message);
		$c->render(status => 500, text => "server error\n");
	});

	$app->helper(irc => sub {
		state $irc = Logbot::IRC->new(
			channels => $config->{irc}->{channels},
			user => $config->{irc}->{user},
			nick => $config->{irc}->{nick},
			server => $config->{irc}->{server},
			pass => $config->{irc}->{pass},
		);
	});

	$app->irc->connect;

	my $bot_is_ready;
	$app->irc->on(joined_all_channels => sub {
		$bot_is_ready = 1;
	});

	$app->hook(before_dispatch => sub ($c) {
		$c->render(status => 503, text => 'not yet ready') if not $bot_is_ready;
	});

	my $r = $app->routes;
	$r->post('/event')->to('webhook#event');
}


1;
