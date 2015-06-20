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
		my $commit = $p->{head_commit};
		my $repo = $p->{repository};
		my $ref = $p->{ref} =~ s/refs\/heads\///gr;

		Mojo::IOLoop->delay(
			sub ($d) {
				get_short_url($p->{compare}, $d->begin);
			},
			sub ($d, $link) {
				my $preview = (split "\n", $commit->{message})[0] // '';
				my $short_sha = substr $p->{after}, 0, 6;
				$preview = _trim($preview);
				my $message = ["$p->{sender}->{login} pushed $short_sha to $repo->{name}/$ref: $preview $link"];
				$cb->($d, $message);
			}
		)->wait;
	},

	issue_comment => sub ($p, $cb) {
		my $comment = $p->{comment};
		my $issue = $p->{issue};
		Mojo::IOLoop->delay(
			sub ($d) {
				get_short_url($comment->{html_url}, $d->begin);
			},
			sub ($d, $link) {
				my $preview = substr $comment->{body}, 0, 60;
				if (length $preview < length $comment->{body}) {
					$preview .= '...';
				}
				$preview = _trim($preview);
				my $message = ["$p->{sender}->{login} commented on $issue->{title} (#$issue->{number}): $preview. $link"];
				$cb->($d, $message);
			},
		)->wait;
	},

	issues => sub ($p, $cb) {
		my $issue = $p->{issue};
		Mojo::IOLoop->delay(
			sub ($d) {
				get_short_url($issue->{html_url}, $d->begin);
			},
			sub ($d, $link) {
				# 'kanatohodets opened #43: airplanes fly oddly. review: git.io/asdfds'
				my $message = ["$p->{sender}->{login} $p->{action} #$issue->{number}: $issue->{title}. review: $link"];
				$cb->($d, $message);
			}
		)->wait;
	},
);

sub get_short_url ($shortlink_target, $cb) {
	Mojo::IOLoop->delay(
		sub ($d) {
			$ua->post('http://git.io' => form => { url => $shortlink_target } => $d->begin);
		},
		sub ($d, $tx) {
			die $tx->error if $tx->error;
			my $link = $tx->res->headers->location // $shortlink_target;
			$cb->($d, $link);
		}
	)->wait;
}

sub parse_event ($event_type, $payload, $cb) {
	if ($handlers{$event_type}) {
		$handlers{$event_type}->($payload, $cb);
	} else {
		$cb->('', [], "unknown event: $event_type $payload\n");
	}
}

sub _trim ($str) {
	return $str =~ s/^\s+|\s+$//gr
}

1;
