#!/usr/bin/env perl

use strict;
use warnings;

my $assemblies_from_ncbi  = 'biosample_assemblies.tsv';
my $assemblies_from_phytobacexplorer = 'phytobacexplorer-13-aug-2026.tsv';
my $biosample_metadata_from_ncbi = 'biosamples-from-ncbi.tsv';
my $ncppb_metadata = 'ncppb-metadata.tsv';


warn "Getting NCBI genome assemblies from file '$assemblies_from_ncbi'\n";
warn "Getting PhytoBacExplorer assemblies from file '$assemblies_from_phytobacexplorer'\n";
warn "Getting NCBI BioSample data from file '$biosample_metadata_from_ncbi'\n"; 
warn "Getting NCPPB metadata from file '$ncppb_metadata'\n";

my %biosample_has_assembly;
my %biosample2phytobacexplorer;
my %biosample2ncbi;
my %biosample_ncbi_metadata;
my %ncppb_metadata;

### Open the biosample metadata file for reading
open my $in_ncppb, '<:encoding(UTF-8):crlf', $ncppb_metadata
    or die "Cannot open $ncppb_metadata: $!";

### Get the header line                                                                                                                                                                             
my $header_line = <$in_ncppb>;
chomp $header_line;
my @ncppb_headings = split /\t/, $header_line;


### List the NCPPB headings
warn "Headings from NCPPB metadata file:\n";
foreach my $heading (@ncppb_headings) {
    warn "\t$heading\n";                                                                                                                                         }

### Read the NCPPB metadata
while (my $readline = <$in_ncppb>) {
    my %heading2datum;
    chomp $readline;
    my @data = split /\t/, $readline;
    foreach my $heading (@ncppb_headings) {
        my $datum = shift @data;
        $heading2datum{$heading} = $datum;
    }
    my $id = $heading2datum{'NCPPB'};
    foreach my $heading (keys %heading2datum) {
        my $datum =  $heading2datum{$heading};
        if (defined $datum and length $datum) {
            $ncppb_metadata{$id}{$heading} = $datum;
	    warn "NCPPB_$id $heading => $datum\n";
        } else {
            $ncppb_metadata{$id}{$heading} = '';
        }
    }
}

### Close the file for reading
close $in_ncppb;

### Open the biosample metadata file for reading
open my $in_biosample_metadata_from_ncbi, '<:encoding(UTF-8):crlf', $biosample_metadata_from_ncbi
    or die "Cannot open $assemblies_from_phytobacexplorer: $!";

### Get the header line
my $header_line = <$in_biosample_metadata_from_ncbi>;
chomp $header_line;
my @biosample_metadata_headings = split /\t/, $header_line;

### List the BioSample metadata headings
warn "Headings from BioSamples metadata file:\n";
foreach my $heading (@biosample_metadata_headings) {
    #warn "\t$heading\n";
}

### Read the BioSample metadata
while (my $readline = <$in_biosample_metadata_from_ncbi>) {
    my %heading2datum;
    chomp $readline;
    my @data = split /\t/, $readline;
    foreach my $heading (@biosample_metadata_headings) {
        my $datum = shift @data;
        $heading2datum{$heading} = $datum;
    }
    my $biosample = $heading2datum{'biosample'};
    foreach my $heading (keys %heading2datum) {
	my $datum =  $heading2datum{$heading};
	if (defined $datum) {
	    $biosample_ncbi_metadata{$biosample}{$heading} = $datum;	
	} else {
	    $biosample_ncbi_metadata{$biosample}{$heading} = '';
	}
    }
}

### Close the file for reading
close $in_biosample_metadata_from_ncbi;

### Open the phytobacexplorer assemblies file for reading
open my $in_phytobacexplorer, '<:encoding(UTF-8):crlf', $assemblies_from_phytobacexplorer
    or die "Cannot open $assemblies_from_phytobacexplorer: $!";

### Get the header line
my $header_line = <$in_phytobacexplorer>;
chomp $header_line;
my @phytobacexplorer_headings = split /\t/, $header_line;

### List the phytobacexplorer metadata headings
warn "Headings from phytobacexplorer assemblies file:\n";
foreach my $heading (@phytobacexplorer_headings) {
    #warn "\t$heading\n";
}

### Read the phytobacexplorer assemblies
while (my $readline = <$in_phytobacexplorer>) {
    my %heading2datum;
    chomp $readline;
    my @data = split /\t/, $readline;
    foreach my $heading (@phytobacexplorer_headings) {
	my $datum = shift @data;
	$heading2datum{$heading} = $datum;
    }
    my $biosample = $heading2datum{'Sample'};
    my $status = $heading2datum{'Status'};
    my $name = $heading2datum{'Name'};
    my $comment = $heading2datum{'Comment'};
    my $assembly_accessions = $heading2datum{'Uberstrain'};
    if ($status =~m/assembled/i) {
	if (defined $biosample) {
	    $biosample2phytobacexplorer{$biosample}{'assembly_accessions'} = $assembly_accessions; 
	    $biosample2phytobacexplorer{$biosample}{'name'} = $name;
	    $biosample2phytobacexplorer{$biosample}{'comment'} = $comment;
	    $biosample_has_assembly{$biosample} ++;
	}   
    }
}

### Close the file for reading 
close $in_phytobacexplorer;

### Open the NCBI assemblies file for reading
open my $in_ncbi, '<:encoding(UTF-8):crlf', $assemblies_from_ncbi
    or die "Cannot open $assemblies_from_ncbi: $!";

### Get the header line
my $header_line = <$in_ncbi>;
chomp $header_line;
my @ncbi_headings = split /\t/, $header_line;

### List the NCBI metadata headings
warn "Headings from NCBI assemblies file:\n";
foreach my $heading (@ncbi_headings) {
    warn "\t$heading\n";
}

### Read the NCBI assemblies                                                                                                                                            
while (my $readline = <$in_ncbi>) {
    my %heading2datum;
    chomp $readline;
    my @data = split /\t/, $readline;
    foreach my $heading (@ncbi_headings) {
        my $datum = shift @data;
        $heading2datum{$heading} = $datum;
    }
    my $biosample = $heading2datum{'biosample'};
    my $has_assembly = $heading2datum{'has_assembly'};
    my $assembly_accessions = $heading2datum{'assembly_accessions'};
    if ($has_assembly =~m/yes/i) {
        if (defined $biosample) {
            $biosample2ncbi{$biosample}{'assembly_accessions'} = $assembly_accessions;
            $biosample_has_assembly{$biosample} ++;
        }
    }
}
### Close the file for reading
close $in_ncbi;

### How many BioSamples have at least one assembly?
my $count = keys %biosample_has_assembly;
warn "$count BioSamples have at least one assembly\n";

### Generate an (ordered) list of metadata fields, ordered by frequency of occurrence                                                                                
my %ncbi_metadata_fields;
my @ncbi_metadata_fields;
foreach my $biosample (keys %biosample_has_assembly ) {
    foreach my $field (keys %{ $biosample_ncbi_metadata{$biosample} } ) {
	if (length $biosample_ncbi_metadata{$biosample}{$field} ) {
	    $ncbi_metadata_fields{$field}++;
	}
    }
}

### Check each NCPPB accession for BioSample and assembly
my %matching_biosamples;
foreach my $id (sort {$a<=>$b} keys %ncppb_metadata) {
    if ($id =~ m/^\d+$/) {
	warn "\nChecking NCPPB $id\n";
	foreach my $biosample (keys %biosample_ncbi_metadata) {
	    #warn "\tChecking BioSample $biosample\n";
	    foreach my $field( keys %{$biosample_ncbi_metadata{$biosample}} ) {
		#warn "\t\tChecking whether NCPPB $id matches $biosample_ncbi_metadata{$biosample}{$field}\n"; 
		if ( $biosample_ncbi_metadata{$biosample}{$field} =~ m/NCPPB\s*$id/) {
		    warn "\t$biosample $field = $biosample_ncbi_metadata{$biosample}{$field}\n";
		    $matching_biosamples{$id}{$biosample} .= "$field = $biosample_ncbi_metadata{$biosample}{$field}; ";
		}
	    }
	}
    }
}


### Print a summary for each NCPPB strain
foreach my $id (sort {$a<=>$b} keys %ncppb_metadata) {
    print "$id";

    ### BioSample
    print "\t";
    foreach my $biosample (sort keys %{ $matching_biosamples{$id}}) {
	print "$biosample ";
    }

    ### NCBI strain
    print "\t";
    foreach my $biosample (sort keys %{ $matching_biosamples{$id}}) {
	my $ncbi_strain = $biosample_ncbi_metadata{$biosample}{'Strain'};
	if (defined $ncbi_strain) {
	    print "$ncbi_strain ";
	}
    }
    
    ### NCBI assemblies
    print "\t";
    foreach my $biosample (sort keys %{ $matching_biosamples{$id}}) {
	my $ncbi_assemblies = $biosample2ncbi{$biosample}{'assembly_accessions'};
        if (defined $ncbi_assemblies) {
	    print "$ncbi_assemblies ";
	}
    }

    ### PhytoBacExplorer assemblies 
    print "\t";
    foreach my $biosample (sort keys %{ $matching_biosamples{$id}}) {
	my $phytobacexplorer_assemblies = $biosample2phytobacexplorer{$biosample}{'assembly_accessions'};
        if (defined $phytobacexplorer_assemblies) {
	    print "$phytobacexplorer_assemblies ";
        }
    }

    ### NCPPB metadata
    foreach my $heading (@ncppb_headings) {
	print "\t";
	if (defined $ncppb_metadata{$id}{$heading}) {
	    print "$ncppb_metadata{$id}{$heading}";
	}
    }

    ### Basis for matching this NCPPB strain to this BioSample
    print "\t";
    foreach my $biosample (sort keys %{ $matching_biosamples{$id}}) {
	if (defined  $matching_biosamples{$id}{$biosample}) {
            print " $matching_biosamples{$id}{$biosample}";
	}
    }

    print "\n";
}

