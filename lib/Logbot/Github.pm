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
	issue_comment => sub ($p, $cb) {
		my $comment = $p->{comment};
		my $issue = $p->{issue};
		Mojo::IOLoop->delay(
			sub ($d) {
				die "no comment data" if !$comment;

				$ua->post('http://git.io' => form => { url => $comment->{html_url} } => $d->begin);
			},
			sub ($d, $tx) {
				die $tx->error if $tx->error;
				my $link = $tx->res->headers->location // $comment->{html_url};
				my $preview = substr $comment->{body}, 0, 60;
				if (length $preview < length $comment->{body}) {
					$preview .= '...';
				}
				$preview =~ s/^\s+//g;
				$preview =~ s/\s+$//g;
				my $res = "$p->{sender}->{login} commented on $issue->{title} (#$issue->{number}): $preview. $link";
				$cb->($d, $res);
			}
		)->catch( sub ($d, $err) {
			say "error blorg in github; $err";
			$cb->($d, '', $err);
		})->wait;
	},

	issues => sub ($p, $cb) {
		my $issue = $p->{issue};
		Mojo::IOLoop->delay(
			sub ($d) {
				die "no issue data" if !$issue;

				$ua->post('http://git.io' => form => { url => $issue->{html_url} } => $d->begin);
			},
			sub ($d, $tx) {
				die $tx->error if $tx->error;
				my $link = $tx->res->headers->location // $issue->{html_url};
				# 'kanatohodets opened #43: airplanes fly oddly. review: git.io/asdfds'
				my $res = "$p->{sender}->{login} $p->{action} #$issue->{number}: $issue->{title}. review: $link";
				$cb->($d, $res);
			}
		)->catch( sub ($d, $err) {
			say "error blorg in github; $err";
			$cb->($d, '', $err);
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
