#!/usr/bin/env perl

use strict;
use warnings;
use XML::LibXML;

my $input  = 'biosamples.xml';
my $output = 'biosamples-from-ncbi.tsv';

print STDERR "Reading $input ...\n";
    
# Read the complete file
    open my $in, '<:encoding(UTF-8)', $input
    or die "Cannot open $input: $!";

local $/;
my $xml = <$in>;

close $in;

# NCBI efetch may return several BioSampleSet XML documents
# concatenated together. Remove XML declarations and DOCTYPE
# declarations, then wrap all BioSampleSet elements in one root.

$xml =~ s/<\?xml[^>]*\?>//g;
$xml =~ s/<!DOCTYPE\s+BioSampleSet\s*>//g;

$xml = "<NCBI_BioSamples>\n$xml\n</NCBI_BioSamples>\n";

my $parser = XML::LibXML->new();
my $doc = $parser->parse_string($xml);

my @samples = $doc->findnodes('//BioSample');

print STDERR "Found ", scalar(@samples), " BioSample records\n";

# Store metadata for each sample

my @records;
my %fields;

for my $sample (@samples) {

    my %record;

    # BioSample accession
    my $accession = $sample->getAttribute('accession') // '';
    $record{'biosample'} = $accession;
    $fields{'biosample'} = 1;

    # Submission accession, if present
    my $submission_id = $sample->getAttribute('id') // '';
    $record{'biosample_id'} = $submission_id;
    $fields{'biosample_id'} = 1;

    # Organism
    my ($organism) = $sample->findnodes('./Description/Organism/OrganismName');
    if ($organism) {
        $record{'organism'} = $organism->textContent;
        $fields{'organism'} = 1;
    }

    # Taxonomy ID
    my ($taxid) = $sample->findnodes('./Description/Organism/OrganismName/TaxonomyId');
    if ($taxid) {
        $record{'taxid'} = $taxid->textContent;
        $fields{'taxid'} = 1;
    }

    # Sample title
    my ($title) = $sample->findnodes('./Description/Title');
    if ($title) {
        $record{'title'} = $title->textContent;
        $fields{'title'} = 1;
    }

    # All BioSample attributes
    for my $attr ($sample->findnodes('./Attributes/Attribute')) {

        my $name = $attr->getAttribute('attribute_name') // '';
        next unless length $name;

        my $value = $attr->textContent // '';

        # Convert attribute names into safe column names
        $name =~ s/\s+/_/g;
        $name =~ s/[^A-Za-z0-9_.-]/_/g;

        # Avoid overwriting core fields
        $name = "attr_$name"
            if exists $record{$name};

        # If an attribute occurs more than once, join the values
        if (exists $record{$name} && length $record{$name}) {
            $record{$name} .= ';' . $value;
        }
        else {
            $record{$name} = $value;
        }

        $fields{$name} = 1;
    }

    push @records, \%record;
}

# Sort metadata fields alphabetically, but put key fields first
my @preferred = qw(
    biosample
    biosample_id
    organism
    taxid
    title
);

my %preferred = map { $_ => 1 } @preferred;

my @other_fields =
    sort grep { !$preferred{$_} } keys %fields;

my @columns = (@preferred, @other_fields);

open my $fh, '>:encoding(UTF-8)', $output
    or die "Cannot open $output: $!";

print $fh join("\t", @columns), "\n";

for my $record (@records) {

    my @values;

    for my $column (@columns) {
        my $value = $record->{$column} // '';

        # Protect TSV structure
        $value =~ s/\r?\n/ /g;
        $value =~ s/\t/ /g;

        push @values, $value;
    }

    print $fh join("\t", @values), "\n";
}

close $fh;

print STDERR "Wrote $output\n";
print STDERR "Records: ", scalar(@records), "\n";
print STDERR "Columns: ", scalar(@columns), "\n";

