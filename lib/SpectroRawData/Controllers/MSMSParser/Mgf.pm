package SpectroRawData::Controllers::MSMSParser::Mgf;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use DBI;
use base qw/SpectroRawData::Controllers::MSMSParser::Base/;

##############################################################################
# Method: openFile()
#
sub openFile
{
my( $self ) = @_;
open($self->{fileHandle},"<",$self->file) or die "Reading error : $!";
$self->_initIndex;

return 1;
}

###############################################################################
## Method: getNextSpectrum()
##
#sub getNextSpectrum
#{
#my( $self, $params ) = @_; #set or not the iterator to the scan number

#$/ = 'END IONS';
#my $fHandle = $self->{fileHandle};
#my $block = <$fHandle>;
#my $msmsSpectrum = $self->_parseFileBlock( $block, $params ) if $block =~ /BEGIN IONS/;
#$/ = "\n";

#return $msmsSpectrum;
#}

##############################################################################
# Private method: _buildIndex()
#
sub _buildIndex
{
my $self = shift;
if( defined $self->{dbh} )
  {
  $self->throwError('index already created');
  return;
  }
  
my $dbh = $self->_openIndex();
$self->_createIndexDB();

### Parse the fileto build the index
$/ = 'END IONS';
my $fHandle = $self->{fileHandle};
my $startPos = int( tell($fHandle) );

while( my $block = <$fHandle> )
  {
  if( $block =~ /BEGIN IONS/ )
    {
    ### Retrieve spectrum information
    my $length = length($block);
    my $msmsSpectrum = $self->_parseFileBlock( $block, { peaks => 0} );
    my $desc = $msmsSpectrum->description;
    my $precursor = $msmsSpectrum->precursorPeak;
    my $precMoz = $precursor->moz;
    my $precCharge = $precursor->charge;
    my $precMass = $precursor->getMass;
#    my $precMass = ($precMoz * $precCharge) - ($precCharge*$protonMass);

    ### Extract suppl. infos from the description
    my $descInfos = $self->parseDescription( $desc );
    my @descValues;
    foreach my $key ('minRetTime','maxRetTime','minScanNumber','maxScanNumber','minCycleNumber','maxCycleNumber')
      {
      my $value = $descInfos->{$key} || 'NULL';
      push(@descValues, $value );
      }

    ### Convert  values into a string
    my @values = ('NULL', $dbh->quote($desc), $startPos, $length, $precMass, $precMoz, $precCharge, @descValues );
    my $valuesAsString = join(', ', @values);
    
    ### Insert values in tth table
    $dbh->do("INSERT INTO peaklistIndex VALUES ($valuesAsString)");
    
    ### Update the start position for the next loop
    $startPos = tell($fHandle);
    }
  }
$/ = "\n";

$dbh->commit();

return;
}

##############################################################################
# Interface: _readSpectrum()
#
sub _readSpectrum
{
my( $self, $spectrum, $blockStart, $blockLength ) = @_;

my $fHandle = $self->{fileHandle};
seek($fHandle,$blockStart,0);

my $block;
read($fHandle, $block, $blockLength );

my $tmpSpectrum = $self->_parseFileBlock( $block, { header => 0 } );
$spectrum->peaks( $tmpSpectrum->peaks );

return $spectrum;
}

##############################################################################
# Method: _parseFileBlock()
#
sub _parseFileBlock
{
my( $self, $block, $params ) = @_;
my $parseHeader = defined $params->{header} ? $params->{header} : 1;
my $parsePeaks = defined $params->{peaks} ? $params->{peaks} : 1;

require SpectroRawData::Models::PeakList;
require SpectroRawData::Models::Peak;
require SpectroRawData::Models::Scan;
my $msmsSpectrum = new SpectroRawData::Models::Scan;
$msmsSpectrum->msLevel(2);
my @lines = split(/\n/, $block);

my $blockBegin = 0;
do
  {
  my $line = shift( @lines );
  if( $line =~ /BEGIN IONS/ ) { $blockBegin = 1; } #drop the BEGIN IONS tag
  }until( $blockBegin or @lines == 0 );

if( $parseHeader )
  {
  my @header = @lines[0..2];
  my $charge;
  foreach my $line (@header)
    {
    if( $line =~ /TITLE=(.*)/ ) { $msmsSpectrum->description( $1 ); }
    elsif( $line =~ /CHARGE=(\d+)\+/ ) { $charge = $1; }
    elsif( $line =~ /PEPMASS=(\d+\.\d+)/ or $line =~ /PEPMASS=(\d+)/ )
      {
      my $precursorPeak = new SpectroRawData::Models::Peak;
      $precursorPeak->moz($1);
#      if( $line =~ /PEPMASS=(.+?)\s+(.+)/ ) { $precursorPeak->intensity($2); }
#      if( $line =~ /PEPMASS=(.+?)\s+(.+?)\s+(.+)/ ) { $precursorPeak->charge($3); }

      $msmsSpectrum->precursorPeak( $precursorPeak );
      }
    }
  $msmsSpectrum->precursorPeak->charge($charge) if !defined $msmsSpectrum->precursorPeak->charge;
  }
  
return $msmsSpectrum if not $parsePeaks;

my $peakList = new SpectroRawData::Models::PeakList;
splice(@lines,0,3); #drop the 3 first elements
foreach my $line (@lines)
  {
  if( $line =~ /(\d+\.\d+)\s+(\d+\.\d+)/ )
    {
    my $peak = new SpectroRawData::Models::Peak;
    $peak->moz( $1 );
    $peak->intensity( $2 );
    $peakList->addPeak( $peak );
    }
  }

require SpectroRawData::Models::Peaks;
my $peaks = new SpectroRawData::Models::Peaks;
$peaks->peakList( $peakList );
$peaks->areCentroided( 1 );
$msmsSpectrum->peaks( $peaks );
  
return $msmsSpectrum;
}



##############################################################################
# Method: loadFile()
#
sub loadFile
{
my( $self ) = @_;

require SpectroRawData::Models::Scans;
my $msmsSpectra = new SpectroRawData::Models::Scans;
my $fHandle = $self->{fileHandle};

### Go to the file begin
seek($fHandle,0,'SEEK_SET');

### Parse the file
$/ = 'END IONS';
my $sprectrumNumber = 1;
while( my $block = <$fHandle> )
  {
  if( $block =~ /BEGIN IONS/ )
    {
    my $msmsSpectrum = $self->_parseFileBlock( $block );
    $msmsSpectrum->id($sprectrumNumber);
    $msmsSpectra->addScan( $msmsSpectrum );
    }
  $sprectrumNumber++;
  }
$/ = "\n";

return $msmsSpectra;
}

##############################################################################
# Method: writeFile()
#
sub writeFile
{
my( $self, $msmsSpectra, $file ) = @_;
my $intensityThreshold = 1;
my $ticThreshold = 100;

open(FILE,">$file") or die "can't write in $file : $!";

while( my $msmsSpectrum = $msmsSpectra->getScan('next') )
  {
  #next if $msmsSpectrum->TIC < $ticThreshold;

  my $precursorPeak = $msmsSpectrum->precursorPeak;
  croak "undefined precursor ion" if not defined $precursorPeak;
  
  my $header = "BEGIN IONS\n";
  $header .= "TITLE=" . $msmsSpectrum->description ."\n";
  $header .= "PEPMASS=" . $precursorPeak->moz ." ".
             $precursorPeak->intensity ." ". $precursorPeak->charge ."\n";
  $header .= "CHARGE=" . $precursorPeak->charge ."\n" if defined $precursorPeak->charge;
  print FILE $header;
  
  my $peaks = $msmsSpectrum->peaks;
  $peaks->parseBase64Data;
  my $mozList = $peaks->mozList;
  my $intensities = $peaks->intensities;
  my $nbPeaks = scalar( @$mozList );
  for( my $pos =0; $pos < $nbPeaks; $pos++ )
    {
    print FILE $mozList->[$pos] ." ". $intensities->[$pos] ."\n" if $intensities->[$pos] > $intensityThreshold;
    }
  
  print FILE "END IONS\n\n";
  $msmsSpectrum->_content()->{peaks} = undef;
  }

close FILE;
}

1;
