#!/usr/bin/env perl

use strict;
use warnings;

use Text::CSV;
use LWP::UserAgent;
use JSON::PP qw(decode_json);
use URI::Escape qw(uri_escape);
use Time::HiRes qw(usleep sleep);

##########################################################
# CONFIGURATION
##########################################################

#my $API_KEY = 'PUT_YOUR_API_KEY_HERE';
my $API_KEY = 'f1e0da87fa291f391e7192bef74c0d504b08';

my $INPUT  = shift || 'biosamples-from-ncbi.tsv';
my $OUTPUT = shift || 'biosample_assemblies.tsv';

##########################################################

my $ua = LWP::UserAgent->new(
    agent   => 'BioSampleAssemblyLookup/1.0',
    timeout => 60,
);

my $csv = Text::CSV->new({
    sep_char => "\t",
    binary   => 1,
});

open(my $IN, "<", $INPUT)
    or die "Cannot open $INPUT: $!\n";

open(my $OUT, ">", $OUTPUT)
    or die "Cannot write $OUTPUT: $!\n";

my $header = $csv->getline($IN);

my %col;
for my $i (0 .. $#$header) {
    $col{$header->[$i]} = $i;
}

die "Column 'biosample' not found\n"
    unless exists $col{'biosample'};

print $OUT join("\t",
    qw(
        biosample
        has_assembly
        assembly_accessions
    )
), "\n";

while (my $row = $csv->getline($IN)) {

    my $biosample = $row->[ $col{'biosample'} ];

    next unless defined $biosample and $biosample ne '';

    print STDERR "Processing $biosample\n";

    my $uid = biosample_uid($biosample);

    unless ($uid) {

        print $OUT join("\t",
            $biosample,
            "NO",
            ""
        ), "\n";

        next;
    }

    my @assemblies = get_assemblies($uid);

    print $OUT join("\t",
        $biosample,
        (@assemblies ? 'YES' : 'NO'),
        join(';', @assemblies)
    ), "\n";
}

close $IN;
close $OUT;

##########################################################
# FUNCTIONS
##########################################################

sub biosample_uid {

    my ($biosample) = @_;

    my $url =
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
      . "?db=biosample"
      . "&retmode=json"
      . "&term=" . uri_escape($biosample . "[Accession]")
      . "&api_key=$API_KEY";

    my $json = fetch_json($url);

    return unless $json;

    return unless exists $json->{esearchresult};

    my $ids = $json->{esearchresult}->{idlist};

    return unless $ids;
    return unless @$ids;

    return $ids->[0];
}

sub get_assemblies {

    my ($biosample_uid) = @_;

    my $url =
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi"
      . "?dbfrom=biosample"
      . "&db=assembly"
      . "&id=$biosample_uid"
      . "&retmode=json"
      . "&api_key=$API_KEY";

    my $json = fetch_json($url);

    return unless $json;

    my @assembly_uids;

    foreach my $linkset (@{ $json->{linksets} || [] }) {

        foreach my $db (@{ $linkset->{linksetdbs} || [] }) {

            push @assembly_uids, @{ $db->{links} || [] };
        }
    }

    return unless @assembly_uids;

    my $summary_url =
        "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
      . "?db=assembly"
      . "&id=" . join(",", @assembly_uids)
      . "&retmode=json"
      . "&api_key=$API_KEY";

    my $summary = fetch_json($summary_url);

    return unless $summary;
    return unless exists $summary->{result};

    my %seen;
    my @assemblies;

    foreach my $uid (@assembly_uids) {

        next unless exists $summary->{result}{$uid};

        my $rec = $summary->{result}{$uid};

        my $acc = $rec->{assemblyaccession};

        next unless defined $acc;
        next if $seen{$acc}++;

        push @assemblies, $acc;
    }

    return @assemblies;
}

sub fetch_json {

    my ($url) = @_;

    my $attempts = 0;

    while ($attempts < 5) {

        $attempts++;

        # stay comfortably below NCBI limits
        usleep(200000);

        my $response = $ua->get($url);

        if ($response->is_success) {

            my $content = $response->decoded_content;

            my $json;

            eval {
                $json = decode_json($content);
            };

            if ($@) {
                warn "JSON parse error:\n$content\n";
                return;
            }

            return $json;
        }

        if ($response->code == 429) {

            warn "Rate limited. Sleeping 5 seconds...\n";
            sleep(5);
            next;
        }

        warn "URL: $url\n";
        warn "HTTP: " . $response->status_line . "\n";

        return;
    }

    return;
}
