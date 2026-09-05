#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use JSON::PP;

### Input and output files

my $input         = 'pseudomonas-results.html';
my $output        = 'ncppb-pseudomonas.tsv';
my $sorted_output = 'ncppb-pseudomonas-alphabetical.tsv';


### Columns to extract

my @columns = (
    'NCPPB_number',
    'taxon',
    'genus',
    'species',
    'sub_species',
    'pathovar',
    'catalogue_name',
    'name_as_received',
    'synonyms',
    'organism_author',
    'organism_type',
    'type_strain',
    'pathotype_strain',
    'country_of_origin',
    'country_of_isolation',
    'location',
    'location_name',
    'host',
    'isolated_from',
    'isolated_by',
    'donor',
    'donor_institution',
    'donor_reference',
    'year_of_accession',
    'year_of_isolation',
    'pathogenic_to',
    'pathogenicity_confirmed',
    'literature',
    'public_notes',
    'other_collections',
    'sequence_types',
    'sequenced',
    'sequencing_notes',
    'url_link_ncbi',
    'url_link_q_bank',
    'detail_url',
);


### Clean values for TSV output

sub clean_value {

    my ($value) = @_;

    return '' unless defined $value;

    # Arrays
    if (ref($value) eq 'ARRAY') {
        return join(', ', map { clean_value($_) } @$value);
    }

    # Hashes
    if (ref($value) eq 'HASH') {
        return join(
            '; ',
            map {
                $_ . '=' . clean_value($value->{$_})
            } sort keys %$value
        );
    }

    # Remove line breaks and tabs so every record occupies
    # exactly one line of the TSV file.

    $value =~ s/\r\n/ /g;
    $value =~ s/\r/ /g;
    $value =~ s/\n/ /g;
    $value =~ s/\t/ /g;

    return $value;
}


### Clean URLs
#
# Convert Markdown links such as:
#
# [https://example.org](https://example.org)
#
# to:
#
# https://example.org

sub clean_url {

    my ($value) = @_;

    $value = clean_value($value);

    if ($value =~ /^\[(.*?)\]\((.*?)\)$/) {
        return $2;
    }

    return $value;
}


### Read the HTML as UTF-8 text

open my $in, '<:encoding(UTF-8)', $input
    or die "Cannot read $input: $!\n";

local $/;

my $html = <$in>;

close $in;


### Locate the embedded completeDataset JSON

my $marker = 'completeDataset = [';

my $pos = index($html, $marker);

die "Could not find '$marker' in $input\n"
    if $pos == -1;

$pos += length('completeDataset = ');

my $json_text = substr($html, $pos);


### Decode the JSON array
#
# IMPORTANT:
#
# $html was already decoded from UTF-8 above, so JSON::PP
# must receive a Perl Unicode string. Do NOT use ->utf8(1)
# here.

my $json = JSON::PP->new;

my ($data, $characters_read) = $json->decode_prefix($json_text);

die "Could not decode completeDataset JSON\n"
    unless ref($data) eq 'ARRAY';


print "Number of records: ", scalar(@$data), "\n";


### Convert one NCPPB record into a TSV row

sub record_to_tsv {

    my ($record) = @_;

    my @values;

    for my $column (@columns) {

        my $value;

        if ($column eq 'NCPPB_number') {

            $value = $record->{name};

        }
        elsif ($column eq 'catalogue_name') {

            $value = $record->{name_2};

        }
        elsif ($column eq 'url_link_ncbi') {

            $value = clean_url($record->{$column});

        }
        elsif ($column eq 'url_link_q_bank') {

            $value = clean_url($record->{$column});

        }
        elsif ($column eq 'detail_url') {

            my $ncppb = clean_value($record->{name});

            $value = "https://ncppb.fera.co.uk/furtherinfo/$ncppb";

        }
        else {

            $value = clean_value($record->{$column});
        }

        $value = '' unless defined $value;

        push @values, $value;
    }

    return join("\t", @values);
}


### Write the complete TSV

open my $out, '>:encoding(UTF-8)', $output
    or die "Cannot write $output: $!\n";

print $out join("\t", @columns), "\n";

for my $record (@$data) {

    print $out record_to_tsv($record), "\n";
}

close $out;

print "Wrote $output\n";


### Sort records alphabetically by catalogue name
#
# Case-insensitive alphabetical ordering.
#
# NCPPB number is used as a secondary sort key if two
# records have the same catalogue name.

my @sorted_data = sort {

    my $name_a = clean_value($a->{name_2});
    my $name_b = clean_value($b->{name_2});

    lc($name_a) cmp lc($name_b)
        ||
    ($a->{name} // 0) <=> ($b->{name} // 0)

} @$data;


### Write the alphabetically sorted TSV

open my $sorted, '>:encoding(UTF-8)', $sorted_output
    or die "Cannot write $sorted_output: $!\n";

print $sorted join("\t", @columns), "\n";

for my $record (@sorted_data) {

    print $sorted record_to_tsv($record), "\n";
}

close $sorted;

print "Wrote $sorted_output\n";
print "Sorted ", scalar(@sorted_data), " records by catalogue name\n";

