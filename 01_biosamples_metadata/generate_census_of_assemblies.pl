#!/usr/bin/env perl

use strict;
use warnings;

my $assemblies_from_ncbi  = 'biosample_assemblies.tsv';
my $assemblies_from_phytobacexplorer = 'phytobacexplorer-13-aug-2026.tsv';
my $biosample_metadata_from_ncbi = 'biosamples-from-ncbi.tsv';


warn "Getting NCBI genome assemblies from file '$assemblies_from_ncbi'\n";
warn "Getting PhytoBacExplorer assemblies from file '$assemblies_from_phytobacexplorer'\n";
warn "Getting NCBI BioSample data from file '$biosample_metadata_from_ncbi'\n"; 

my %biosample_has_assembly;
my %biosample2phytobacexplorer;
my %biosample2ncbi;
my %biosample_ncbi_metadata;

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

### Close the phytobacexplorer assemblies file for reading
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

### Close the phytobacexplorer assemblies file for reading 
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
### Close the NCBI assemblies file for reading
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
my %count2fields;
foreach my $field (keys %ncbi_metadata_fields) {
    my $count =  $ncbi_metadata_fields{$field};
    $count2fields{$count}{$field}++;
}
foreach my $count (sort {$b<=>$a} keys %count2fields) {
    foreach my $field (keys %{ $count2fields{$count} }) {
	if ($count > 10) {
	    warn "'$field'\toccurs $count times\n";
	    push @ncbi_metadata_fields, $field;
	}
    }
}

### Print a header line
print "BioSample";
print "\t";

print "PhytobacExplorer name";
print "\t";

print "PhytoBacExplorer Uberstrain";
print "\t";

print "PhytoBacExplorer comment";
print "\t";

print "NCBI assembly";
print "\t";

foreach my $field (@ncbi_metadata_fields) {
    print "NCBI $field";
    print "\t";
}
print "\n";

### Print a summary of the assemblies
foreach my $biosample( sort keys %biosample_has_assembly) {
    my $ncbi_accessions = $biosample2ncbi{$biosample}{'assembly_accessions'};
    my $phytobacexplorer_accessions = $biosample2phytobacexplorer{$biosample}{'assembly_accessions'};
    my $phytobacexplorer_name = $biosample2phytobacexplorer{$biosample}{'name'};
    my $phytobacexplorer_comment = $biosample2phytobacexplorer{$biosample}{'comment'};
        
    ### Resolve any undefined values
    if (defined $ncbi_accessions) {
	# OK
    } else {
	$ncbi_accessions = '';
    }
    if (defined $phytobacexplorer_accessions) {
	# OK
    } else {
	$phytobacexplorer_accessions = '';
    }
    if (defined $phytobacexplorer_name) {
        # OK                                                                                                                                                            
    } else {
	$phytobacexplorer_name = '';
    }
    if (defined $phytobacexplorer_comment) {
        # OK
    } else {
        $phytobacexplorer_comment = '';
    }
    
    ### Print the info
    print "$biosample";
    print "\t";

    print "$phytobacexplorer_name";
    print "\t";

    print "$phytobacexplorer_accessions";
    print "\t";

    print "$phytobacexplorer_comment";
    print "\t";
    
    print "$ncbi_accessions";
    print "\t";

    foreach my $field (@ncbi_metadata_fields) {
	if (defined $biosample_ncbi_metadata{$biosample}{$field}) {
	    print "$biosample_ncbi_metadata{$biosample}{$field}";
	}
	print "\t";
    }
    print "\n";
}

