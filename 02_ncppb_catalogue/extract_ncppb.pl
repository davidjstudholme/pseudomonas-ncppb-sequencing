#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use JSON::PP;

# ------------------------------------------------------------
# Input / output
# ------------------------------------------------------------

my $input_file = 'pseudomonas-results.html';

my $output_file = 'ncppb-pseudomonas.tsv';
my $sorted_file = 'ncppb-pseudomonas-alphabetical.tsv';

# ------------------------------------------------------------
# TSV columns
# ------------------------------------------------------------

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

my $expected_columns = scalar @columns;

# ------------------------------------------------------------
# Read HTML
# ------------------------------------------------------------

print "Reading $input_file ...\n";

open my $fh, '<', $input_file
    or die "Cannot open $input_file: $!\n";

local $/;
my $html = <$fh>;

close $fh;

# ------------------------------------------------------------
# Extract completeDataset JSON
# ------------------------------------------------------------

my $marker = 'completeDataset = [';

my $marker_pos = index($html, $marker);

die "Could not find '$marker' in $input_file\n"
    if $marker_pos == -1;

my $json_start = $marker_pos + length($marker) - 1;

my $json_text = substr($html, $json_start);

# ------------------------------------------------------------
# Decode JSON
# ------------------------------------------------------------

my $json = JSON::PP->new;

my ($dataset, $length_used);

eval {
    ($dataset, $length_used) = $json->decode_prefix($json_text);
};

if ($@) {
    die "Could not decode completeDataset JSON:\n$@\n";
}

die "Decoded JSON is not an array\n"
    unless ref($dataset) eq 'ARRAY';

print "Number of records: ", scalar(@$dataset), "\n\n";

# ------------------------------------------------------------
# Clean a value for true TSV
#
# TSV has no quoting mechanism, so tabs and newlines cannot
# occur inside fields.
#
# We also replace literal double quotes with single quotes.
# This is NOT required by TSV, but works around GitHub's
# incorrect TSV renderer, which treats double quotes as CSV
# quoting characters.
# ------------------------------------------------------------

sub clean_value {
    my ($value) = @_;

    return '' unless defined $value;

    if (ref($value) eq 'ARRAY') {
        $value = join(', ', map { clean_value($_) } @$value);
    }
    elsif (ref($value) eq 'HASH') {
        $value = join(
            '; ',
            map {
                $_ . ': ' . clean_value($value->{$_})
            } sort keys %$value
        );
    }
    elsif (ref($value)) {
        $value = "$value";
    }

    # Remove line breaks / Unicode line separators.
    $value =~ s/\r\n/ /g;
    $value =~ s/\r/ /g;
    $value =~ s/\n/ /g;
    $value =~ s/\x{2028}/ /g;
    $value =~ s/\x{2029}/ /g;

    # A literal TAB would create an additional TSV field.
    $value =~ s/\t/ /g;

    # GitHub's TSV renderer incorrectly treats " as CSV quoting.
    $value =~ s/"/'/g;

    return $value;
}

# ------------------------------------------------------------
# Clean URLs
# ------------------------------------------------------------

sub clean_url {
    my ($value) = @_;

    $value = clean_value($value);

    # Convert Markdown-style:
    # [https://example.com](https://example.com)
    # to:
    # https://example.com
    $value =~ s/^\[([^\]]+)\]\(([^)]+)\)$/$2/;

    return $value;
}

# ------------------------------------------------------------
# Convert one record to a TSV row
# ------------------------------------------------------------

sub record_to_tsv {
    my ($record) = @_;

    my @values;

    foreach my $column (@columns) {

        my $value;

        if ($column eq 'NCPPB_number') {
            $value = $record->{name};

        }
        elsif ($column eq 'catalogue_name') {
            $value = $record->{name_2};
        }
        elsif ($column eq 'detail_url') {
            my $ncppb = $record->{name};
            $value = defined($ncppb)
                ? "https://ncppb.fera.co.uk/furtherinfo/$ncppb"
                : '';
        }
        else {
            $value = $record->{$column};
        }

        if ($column eq 'url_link_ncbi' ||
            $column eq 'url_link_q_bank' ||
            $column eq 'detail_url') {

            $value = clean_url($value);
        }
        else {
            $value = clean_value($value);
        }

        push @values, $value;
    }

    # Validate BEFORE joining/writing.
    die "Internal error: record produced "
        . scalar(@values)
        . " fields; expected $expected_columns\n"
        unless scalar(@values) == $expected_columns;

    # Make absolutely sure no field still contains a tab/newline.
    foreach my $value (@values) {
        die "Internal error: field contains TAB\n"
            if $value =~ /\t/;

        die "Internal error: field contains newline\n"
            if $value =~ /[\r\n]/;
    }

    return join("\t", @values);
}

# ------------------------------------------------------------
# Create TSV rows
# ------------------------------------------------------------

my @rows;

foreach my $record (@$dataset) {

    die "Unexpected record type\n"
        unless ref($record) eq 'HASH';

    my $row = record_to_tsv($record);

    push @rows, {
        row    => $row,
        record => $record,
    };
}

# ------------------------------------------------------------
# Write TSV
# ------------------------------------------------------------

open my $out, '>:encoding(UTF-8)', $output_file
    or die "Cannot write $output_file: $!\n";

print $out join("\t", @columns), "\n";

foreach my $item (@rows) {
    print $out $item->{row}, "\n";
}

close $out;

print "Wrote $output_file\n\n";

# ------------------------------------------------------------
# Sort alphabetically by catalogue_name
# ------------------------------------------------------------

my $catalogue_index;

for my $i (0 .. $#columns) {
    if ($columns[$i] eq 'catalogue_name') {
        $catalogue_index = $i;
        last;
    }
}

die "Could not find catalogue_name column\n"
    unless defined $catalogue_index;

my @sorted_rows = sort {
    my @a = split(/\t/, $a->{row}, -1);
    my @b = split(/\t/, $b->{row}, -1);

    lc($a[$catalogue_index]) cmp lc($b[$catalogue_index])
        ||
    $a[$catalogue_index] cmp $b[$catalogue_index]
} @rows;

open my $sorted, '>:encoding(UTF-8)', $sorted_file
    or die "Cannot write $sorted_file: $!\n";

print $sorted join("\t", @columns), "\n";

foreach my $item (@sorted_rows) {
    print $sorted $item->{row}, "\n";
}

close $sorted;

print "Wrote $sorted_file\n\n";
print "Sorted ", scalar(@sorted_rows),
      " records by catalogue name\n\n";

# ------------------------------------------------------------
# Summary validation
# ------------------------------------------------------------

print "Checking TSV structure...\n";

my $expected_lines = scalar(@rows) + 1;

my $actual_lines = 0;

open my $check, '<:encoding(UTF-8)', $output_file
    or die "Cannot reopen $output_file: $!\n";

while (<$check>) {
    $actual_lines++;
}

close $check;

if ($actual_lines != $expected_lines) {
    die "TSV validation FAILED: expected $expected_lines lines, "
      . "found $actual_lines\n";
}

print "TSV validation OK: $actual_lines lines, "
    . "$expected_columns columns per row\n";

print "\nDone.\n";

