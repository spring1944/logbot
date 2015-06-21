package Logbot::Github;
use v5.20.0;
use warnings;

use Mojo::IOLoop;
use Mojo::UserAgent;
use Data::Dumper qw(Dumper);

use Exporter 'import';

our @EXPORT = qw(parse_event);

use experimental qw(postderef signatures);

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(5);

my %notification_blacklist = (
	'spring1944/master' => 1
);

my %handlers = (
	push => sub ($p, $cb) {
		my $commit = $p->{head_commit};
		my $repo = $p->{repository};
		my $ref = $p->{ref} =~ s/refs\/heads\///gr;

		Mojo::IOLoop->delay(
			sub ($d) {
				die "blacklisted repo/branch" if $notification_blacklist{"$repo/$ref"};
				get_short_url($p->{compare}, $d->begin(0));
			},
			sub ($d, $link) {
				my $preview = (split "\n", $commit->{message})[0] // '';
				my $short_sha = substr $p->{after}, 0, 6;
				$preview = _trim($preview);
				my $message = sprintf("%s pushed %s to %s/%s: %s %s",
					$p->{sender}->{login},
					$short_sha,
					$repo->{name},
					$ref,
					$preview,
					$link);

				$cb->([$message]);
			}
		)->catch(sub ($d, $err) {
			if ($err eq "blacklisted repo/branch") {
				$cb->([]);
			} else {
				# rethrow
				die $err;
			}
		})->wait;
	},

	issue_comment => sub ($p, $cb) {
		my $comment = $p->{comment};
		my $issue = $p->{issue};
		my $repo = $p->{repository};
		Mojo::IOLoop->delay(
			sub ($d) {
				get_short_url($comment->{html_url}, $d->begin(0));
			},
			sub ($d, $link) {
				my $preview = substr $comment->{body}, 0, 60;
				$preview = _trim($preview);

				if (length $preview < length $comment->{body}) {
					$preview .= '...';
				}

				my $message = sprintf("%s commented on %s (%s #%s): %s %s",
					$p->{sender}->{login},
					$issue->{title},
					$repo->{name},
					$issue->{number},
					$preview,
					$link);

				$cb->([$message]);
			},
		)->wait;
	},

	issues => sub ($p, $cb) {
		my $issue = $p->{issue};
		my $repo = $p->{repository};
		Mojo::IOLoop->delay(
			sub ($d) {
				get_short_url($issue->{html_url}, $d->begin(0));
			},
			sub ($d, $link) {
				# 'kanatohodets opened #43: airplanes fly oddly. review: git.io/asdfds'
				my $message = sprintf("%s %s %s #%s: %s. %s",
					$p->{sender}->{login},
					$p->{action},
					$repo->{name},
					$issue->{number},
					$issue->{title},
					$link);

				$cb->([$message]);
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
			$cb->($link);
		}
	)->catch(sub ($d, $err) {
		$cb->($shortlink_target);
	})->wait;
}

sub parse_event ($event_type, $payload, $cb) {
	die "unknown event: $event_type " . Dumper($payload). "\n" if not $handlers{$event_type};
	$handlers{$event_type}->($payload, $cb);
}

sub _trim ($str) {
	return $str =~ s/^\s+|\s+$//gr
}

1;
