#!/usr/bin/env perl

our $VERSION = '1.0';

BEGIN {
  push(@INC, './lib');
}

use 5.12.0;
use strict;

use Carp;
use Data::Dumper;
use DBIx::Simple;
use File::Basename qw/dirname/;
use Getopt::Long;
use JSON;
use File::Slurp;
use MIME::Base64;
use Pod::Usage;
use XML::Simple;

use SpectroRawData::Models::Scans;
use SpectroRawData::Controllers::MSMSParser;

my( $mgfFile, $lossMass, $mozTol, $mozTolUnit, $maxNumOfLosses, $max_nb_highest_peaks, $min_relative_intensity, $verbose, $help, $man);

unless(  GetOptions(
                  "file_path=s"=>\$mgfFile,
                  "loss_mass=f"=>\$lossMass,
                  "moz_tol=f"=>\$mozTol,
                  "moz_tol_unit=s"=>\$mozTolUnit,
                  "max_nb_losses=i"=> \$maxNumOfLosses,
                  "max_highest_peaks=i"=> \$max_nb_highest_peaks,
                  "min_rel_intensity=f" => \$min_relative_intensity,
                  "verbose"=>\$verbose,
                  "help"=>\$help,
                  "man"=>\$man,
                 )) {pod2usage(-verbose=>1, -exitval=>2); }

if( $help || $man || !$mgfFile || !$lossMass || !$mozTol || !$mozTolUnit || !$maxNumOfLosses )
	{ pod2usage(-verbose=>$man?2:1, -exitval=>2, -output=>\*STDOUT); }
	
my $protonMass =  1.00727646688;
#my $max_nb_highest_peaks = 5;  
#my $min_relative_intensity = 0.5;

#my $lossMass = 162;
#my $chargeStates = [ 2 ];
#my $mozTol = 0.4;
#my $numOfLosses = 2;

my $dir = dirname( $mgfFile );
my $mgFileWithoutExtension = $mgfFile;
$mgFileWithoutExtension =~ s/\.mgf$//;

my $outputFile = $mgFileWithoutExtension .'_neutral_loss_report.txt';
my $mgfFilteredFile = $mgFileWithoutExtension .'_neutral_loss_filtered.mgf';

my $msmsReader =  new SpectroRawData::Controllers::MSMSParser( $mgfFile );
$msmsReader->openFile();

### Open a DBI connection to the index file
my $index_file = $mgfFile . '.idx';
my $index_db = DBIx::Simple->connect("dbi:SQLite:dbname=$index_file") or die DBIx::Simple->error;

open( FILE, ">", $outputFile) or die $!;

print FILE "prec. mass\tprec. m/z\tprec. Z\tfrag. m/z\tfrag. delta m/z\tfrag. z\tfrag. intensity\tbase peak intensity\t#losses\ttitle\tfragment putative spectra\t#matching spectra\n";

my $spectraWithNeutralLosses = new SpectroRawData::Models::Scans();
my $processedSpectra = 0;

while (my $spectrum = $msmsReader->getScan('next'))
  {
  $processedSpectra++;
  say "Processed $processedSpectra spectra" if $processedSpectra % 100 == 0;

  ### Retrieve peaks
  my $peaks = $spectrum->peaks;
  my $mozList = $peaks->mozList;
  my $intensities = $peaks->intensities;
  
  ### Sort peaks m/z by intensity
  my $mozMapper;
  my $peakPos = 0;
  
  my @peakList;
  foreach my $moz (@$mozList)
    {
    push( @peakList, [$moz, $intensities->[$peakPos] ] );
    $peakPos++;
    }
  
  my @sortedPeaksByInt = sort { $b->[1] <=> $a->[1] } @peakList;
  my $highestPeak = $sortedPeaksByInt[0];
  my $intensityCutoff = $highestPeak->[1] * $min_relative_intensity;
  
  ### Retrieve n highest peaks
  my @highestPeaks;
  for my $peakPos (0..$max_nb_highest_peaks-1) {
    my $peak = $sortedPeaksByInt[$peakPos];
    last if $peak->[1] < $intensityCutoff;
    
    push( @highestPeaks, $peak );
  }
    
  my $precursor = $spectrum->precursorPeak;
  my $precMoz = $precursor->moz;
  my $precCharge = $precursor->charge;
  my $precMass = ($precMoz * $precCharge) - ( $precCharge * $protonMass );
  my $mozTolInDa = get_moz_tol_in_daltons( $precMoz, $mozTol, $mozTolUnit );

  my $title =  $spectrum->description;
  
  #print "Searching for precursor ion " . $precMoz .' ('.$precCharge."+) in '$title' \n" if defined $verbose;
  
  my $fragment = searchFragments( \@highestPeaks, $precMoz, $precCharge, $lossMass, $mozTolInDa, $maxNumOfLosses );

  if( defined $fragment )
    {
    my $charge = $fragment->{charge};
    my $fragmentMass = ($fragment->{moz} * $charge ) - ( $charge * $protonMass );
    my $massTol = $mozTolInDa * $charge;
    my( $minFragMass, $maxFragMass )  = ( $fragmentMass - $massTol, $fragmentMass + $massTol );
    my @matching_spectra_titles = $index_db->query("SELECT description FROM peaklistindex WHERE precursorMass > $minFragMass AND precursorMass < $maxFragMass")->flat();
    
    print FILE join("\t", sprintf("%.5f",$precMass), $precMoz, $precCharge,
                          @$fragment{'moz','delta', 'charge', 'intensity'}, $highestPeak->[1], $fragment->{numOfLosses}, $title ,
                          join(", ", @matching_spectra_titles ),
                          scalar(@matching_spectra_titles),
                          ) ."\n";
    
    $spectraWithNeutralLosses->addScan( $spectrum );
    }

  }
  
close FILE;

### Export spectra with detected neutral losses
#open( MGF, ">", $mgfFilteredFile ) or die $!;
$msmsReader->writeFile( $spectraWithNeutralLosses, $mgfFilteredFile );
#close MGF;

use Data::Dumper;

sub searchFragments
{
my( $highestPeaks, $precMoz, $charge, $lossMass, $tol, $numOfLosses ) = @_;

my $fragment;
### Iterate over neutral losses
for my $lossNumber (1..$numOfLosses) {

  ### Search for this neutral loss
  my $isLossMatched = 0;
  for my $peak (@$highestPeaks) {
    my $curLossMoz = $lossMass*$lossNumber/$charge;
    my $peakMoz = $peak->[0];
    my $delta = sprintf("%.4f",abs($precMoz-$curLossMoz-$peakMoz) );
  
    ### Check if current peak is matching the neutral loss
    if( $delta < $tol ) {
      $fragment = { delta => $delta, moz => $peakMoz, intensity => $peak->[1], charge => $charge, numOfLosses => 0 } if !defined $fragment;
      $fragment->{numOfLosses} += 1;
      $isLossMatched = 1;
      last; ### skip next peaks if neutral loss is matched
    }
  }
  last if not $isLossMatched; ### stop if neutral loss is not matched
}

return $fragment;
}

sub get_moz_tol_in_daltons {
  my( $moz, $moz_tol, $moz_tol_unit) = @_;
  
  if ( $moz_tol_unit eq 'Da' ) { return $moz_tol; }
  elsif( $moz_tol_unit eq 'ppm' ) { return $moz_tol * $moz / 1000000; }
  else { die "unknown m/z tolerance unit '$moz_tol_unit'"; }
}

1;

