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
#
# TSV fields must not contain literal tabs or line breaks.
#
# We also remove Unicode line/paragraph separators because these can
# sometimes occur in scraped web data and may be interpreted as line
# breaks by downstream software.
#
# ASCII double quotes are converted to Unicode left/right quotation
# marks for GitHub compatibility. GitHub's TSV renderer can otherwise
# interpret embedded ASCII quotes as CSV-style quoting.

sub clean_value {

    my ($value) = @_;

    return '' unless defined $value;


    ### Arrays

    if (ref($value) eq 'ARRAY') {

        return join(
            ', ',
            map { clean_value($_) } @$value
        );
    }


    ### Hashes

    if (ref($value) eq 'HASH') {

        return join(
            '; ',
            map {
                $_ . '=' . clean_value($value->{$_})
            } sort keys %$value
        );
    }


    ### Convert to a string

    $value = "$value";


    ### Remove ordinary line breaks

    $value =~ s/\r\n/ /g;
    $value =~ s/\r/ /g;
    $value =~ s/\n/ /g;


    ### Remove Unicode line and paragraph separators

    $value =~ s/\x{2028}/ /g;    # LINE SEPARATOR
    $value =~ s/\x{2029}/ /g;    # PARAGRAPH SEPARATOR


    ### Tabs would create additional TSV fields

    $value =~ s/\t/ /g;


    ### Replace ASCII double quotes
    #
    # GitHub's TSV renderer appears to use CSV-style quoting rules.
    # Converting ordinary ASCII quotes prevents strings such as:
    #
    # "Bacterium betle"
    #
    # from being interpreted as malformed CSV quoting.
    #
    # The underlying wording is retained, but with typographic quotes.

    $value =~ s/"/\x{201C}/g;


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


### Read the HTML as UTF-8

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
# The HTML has already been decoded from UTF-8.
# Therefore JSON::PP must receive a Perl Unicode string.
#
# Do NOT use ->utf8(1) here.

my $json = JSON::PP->new;

my ($data, $characters_read) =
    $json->decode_prefix($json_text);

die "Could not decode completeDataset JSON\n"
    unless ref($data) eq 'ARRAY';


print "Number of records: ", scalar(@$data), "\n";


### Convert one NCPPB record into a TSV row

sub record_to_tsv {

    my ($record) = @_;

    my @values;

    for my $column (@columns) {

        my $value;


        ### NCPPB number

        if ($column eq 'NCPPB_number') {

            $value = $record->{name};
        }


        ### Catalogue name

        elsif ($column eq 'catalogue_name') {

            $value = $record->{name_2};
        }


        ### NCBI URL

        elsif ($column eq 'url_link_ncbi') {

            $value = clean_url($record->{$column});
        }


        ### Q-bank URL

        elsif ($column eq 'url_link_q_bank') {

            $value = clean_url($record->{$column});
        }


        ### Construct NCPPB detail URL

        elsif ($column eq 'detail_url') {

            my $ncppb = clean_value($record->{name});

            $value =
                "https://ncppb.fera.co.uk/furtherinfo/$ncppb";
        }


        ### All other fields

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
# NCPPB number is the secondary sort key.

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
print "Sorted ",
      scalar(@sorted_data),
      " records by catalogue name\n";


### Final validation

print "\nChecking TSV structure...\n";

open my $check, '<:encoding(UTF-8)', $output
    or die "Cannot check $output: $!\n";

my $line_number = 0;
my $bad_lines   = 0;

while (my $line = <$check>) {

    $line_number++;

    chomp $line;

    my @fields = split(/\t/, $line, -1);

    if (scalar(@fields) != scalar(@columns)) {

        print "WARNING: line $line_number contains ",
              scalar(@fields),
              " fields; expected ",
              scalar(@columns),
              "\n";

        $bad_lines++;
    }
}

close $check;


if ($bad_lines == 0) {

    print "TSV validation passed: ";
    print $line_number;
    print " lines, ";
    print scalar(@columns);
    print " fields per line.\n";
}
else {

    print "TSV validation FAILED: ";
    print $bad_lines;
    print " problematic lines.\n";
}

