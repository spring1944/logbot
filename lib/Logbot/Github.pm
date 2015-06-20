package Logbot::Github;
use v5.20.0;
use warnings;

use Mojo::IOLoop;
use Mojo::UserAgent;

use Exporter 'import';

our @EXPORT = qw(parse_event);

use experimental qw(postderef signatures);

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(5);

my %handlers = (
	push => sub ($p, $cb) {

	},
	issues => sub ($p, $cb) {
		my $issue = $p->{issue};
		Mojo::IOLoop->delay(
			sub ($d) {
				die "no issue data" if !$issue;

				$ua->post('http://git.io' => form => { url => $issue->{url} } => $d->begin);
			},
			sub ($d, $ua, $tx) {
				die $tx->error if $tx->error;
				my $link = $tx->res->headers->location // $issue->{url};
				# 'kanatohodets opened #43: airplanes fly oddly. review: git.io/asdfds'
				$cb->("$p->{sender}->{login} $p->{action} #$issue->{number}: $issue->{title}. review: $link");
			}
		)->catch( sub ($d, $err) {
			$cb->('', $err);
		})->wait;
	},
);

sub parse_event ($event_type, $payload, $cb) {
	if ($handlers{$event_type}) {
		$handlers{$event_type}->($payload, $cb);
	} else {
		$cb->();
	}
}
