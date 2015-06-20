package Logbot::Controller::Webhook;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::IOLoop;

use Logbot::Github qw(parse_event);

use Digest::SHA qw(hmac_sha1_hex);

use experimental qw(postderef signatures);

sub event ($c) {
	my $content = $c->req->body;

	my $secret = $c->config->{github}->{webhook_secret};
	my $hash = hmac_sha1_hex($content, $secret);
	my $signature = $c->req->headers->header('X-Hub-Signature');

	if ($signature and $hash eq $signature) {
		my $event_type = $c->req->headers->header('X-Github-Event') // 'UNKNOWN EVENT';

		Mojo::IOLoop->delay(
			sub ($d) {
				parse_event($event_type, $c->req->json, $d->begin);
			},
			sub ($d, $parsed_event = '', $err = '') {
				die $err if $err;
				die "unrecognized event: $event_type: $content\n" if !$parsed_event;

				$c->irc->announce($parsed_event, $d->begin);
			},
			sub ($d, $err) {
				die "bad announce\n" if $err;
				$c->render(text => "ok thanks");
			}
		)->catch( sub ($d, $err) {
			$c->app->log->warn($err);
			$c->render(status => 400, text => 'bad request/irc trouble');
		})->wait;

	} else {
		$c->render(status => 401, text => "unauthorized");
	}
}

1;
