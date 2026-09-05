#!/usr/bin/env perl

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);

my $search_url  = 'https://ncppb.fera.co.uk/';
my $results_url = 'https://ncppb.fera.co.uk/results';

# ------------------------------------------------------------
# User agent + persistent cookies
# ------------------------------------------------------------

my $cookie_jar = HTTP::Cookies->new;

my $ua = LWP::UserAgent->new(
    agent      => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36',
    cookie_jar => $cookie_jar,
);

$ua->default_header(
    'Accept' =>
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
);

$ua->default_header('Accept-Language' => 'en-GB,en-US;q=0.9,en;q=0.8');
$ua->default_header('Upgrade-Insecure-Requests' => '1');

# ------------------------------------------------------------
# GET search page
# ------------------------------------------------------------

print "Getting search page...\n";

my $response = $ua->get(
    $search_url,
    'Referer' => $search_url,
);

die "GET failed: ", $response->status_line, "\n"
    unless $response->is_success;

my $html = $response->decoded_content;

print "GET status: ", $response->status_line, "\n";
print "GET length: ", length($html), "\n";

# ------------------------------------------------------------
# Extract CSRF token
# ------------------------------------------------------------

$html =~ /name=["']_token["'][^>]*value=["']([^"']+)["']/i
    or die "Could not find CSRF token\n";

my $token = $1;

print "CSRF token obtained\n";

# ------------------------------------------------------------
# Show cookies obtained from GET
# ------------------------------------------------------------

my $cookie_count = 0;

$cookie_jar->scan(sub {
    my ($version, $key, $val, $path, $domain,
        $port, $path_spec, $secure, $expires,
        $discard, $rest) = @_;

    print "Cookie: $key\n";
    $cookie_count++;
});

print "Cookies obtained: $cookie_count\n";

# ------------------------------------------------------------
# POST search
# ------------------------------------------------------------

print "Searching for Pseudomonas...\n";

$response = $ua->post(
    $results_url,
    [
        _token        => $token,
        ncppbNum      => '',
        taxonDrop     => '',
        taxonSearch   => 'pseudomonas',
        hostDrop      => '',
        cultureSearch => '',
        sortResultsBy => 'radioNcppbNum',
    ],
    'Referer' => $search_url,
    'Origin'  => 'https://ncppb.fera.co.uk',
);

print "POST status: ", $response->status_line, "\n";

die "POST failed\n"
    unless $response->is_success;

my $results = $response->decoded_content;

print "Results length: ", length($results), "\n";

open my $fh, '>:encoding(UTF-8)', 'pseudomonas-results.html'
    or die "Cannot write pseudomonas-results.html: $!\n";

print $fh $results;

close $fh;

print "Saved pseudomonas-results.html\n";


