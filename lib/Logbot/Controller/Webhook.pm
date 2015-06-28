package Logbot::Controller::Webhook;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::IOLoop;

use Logbot::Github qw(parse_event);

use Digest::SHA qw(hmac_sha1_hex);

use experimental qw(postderef signatures);

sub event ($c) {
	my $content = $c->req->body;
	my $org = $c->stash('organization');
	my $org_config = $c->config->{orgs}->{$org};

	if ($org_config) {
		my $secret = $org_config->{github}->{webhook_secret};
		my $hash = hmac_sha1_hex($content, $secret);
		my $signature = $c->req->headers->header('X-Hub-Signature') // '';

		# thanks, github
		$signature =~ s/^sha1=//g;

		if ($signature and $hash eq $signature) {
			my $event_type = $c->req->headers->header('X-Github-Event') // 'UNKNOWN EVENT';

			Mojo::IOLoop->delay(
				sub ($d) {
					parse_event($event_type, $c->req->json, $d->begin(0));
				},
				sub ($d, $msg_chunks) {

					my $channels = $org_config->{channels} // [];
					my ($has_chan, $has_message) = (scalar $msg_chunks->@*, scalar $channels->@*);

					if ($has_chan and $has_message) {
						$c->irc->announce($channels, $msg_chunks, $d->begin);
					} else {
						$d->pass;
					}
				},
				sub ($d) {
					$c->render(text => "ok thanks");
				}
			)->catch( sub ($d, $err) {
				$c->app->log->warn($err);
				$c->render(status => 400, text => 'bad request/irc trouble');
			})->wait;
		} else {
			$c->render(status => 401, text => "unauthorized");
		}
	} else {
		$c->render(status => 400, text => "unknown organization: $org");
	}
}

1;
