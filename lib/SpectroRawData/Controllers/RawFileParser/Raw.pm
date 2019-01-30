package SpectroRawData::Controllers::RawFileParser::Raw;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use File::Basename;

use base qw/SpectroRawData::Controllers::RawFileParser::Base/;
use SpectroRawData::Models::Scan;
use SpectroRawData::Models::Peaks;
use SpectroRawData::Models::Peak;
use SpectroRawData::Data::Index;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Method: openFile()
#
sub openFile
{
my( $self ) = @_;
sysopen($self->{fileHandle},$self->file,'O_RDONLY | O_BINARY');
$self->_loadIndex();

$self->infos( {isCentroided => 1} );
}

##############################################################################
# Method: _readSpectrum()
#
sub _readSpectrum
{
my( $self, $channel, $number, $scanIndex ) = @_;

my $spectrum = new SpectroRawData::Models::Scan;
$spectrum->isCentroided(1); #the available data are centroided spectra
$spectrum->msLevel($channel);

my $peaks = new SpectroRawData::Models::Peaks;
$peaks->areCentroided(1);

sysseek($self->{fileHandle},$scanIndex->start,'SEEK_SET');

my $nbPeaks;
sysread($self->{fileHandle},$nbPeaks,4);
$nbPeaks = unpack("I",$nbPeaks);

#my $nbVal = 2*$scanIndex->numOfPeaks;
my $nbVal = 2*$nbPeaks;

my( $buffer, $totIonCurrent, @mozList, @intensities, $mozIndex );

eval { sysread($self->{fileHandle},$buffer,4*$nbVal); }; #read m/z and intensity values
return undef if $@;

my @values = unpack("f$nbVal",$buffer);

my $peakNum = 1;
while( @values > 0 )
  {
  my $moz = sprintf("%0.6f", shift(@values) );
  my $intMoz= int($moz);
  $mozIndex->{$intMoz} = $peakNum if !defined $mozIndex->{$intMoz};
  my $intensity = int(shift(@values));
  push(@mozList, $moz);
  push(@intensities, $intensity);
  $totIonCurrent += $intensity;
  $peakNum++;
  }

if( !defined $self->ticThreshold or $totIonCurrent > $self->ticThreshold )
  {
  $peaks->loadArrays( \@mozList, \@intensities, $mozIndex );
  #TODO : call computeBase64Data if loadFile has been called
  $spectrum->peaks( $peaks );
#  print $scanIndex->TIC . '-'.$totIonCurrent."\n";
#  $spectrum->TIC($totIonCurrent);
  $spectrum->TIC($scanIndex->TIC);
  $spectrum->id($scanIndex->id);
  $spectrum->number($number);
  $spectrum->retentionTime( $scanIndex->retentionTime );
  $spectrum->basePeak( $scanIndex->basePeak );
  #if( $scanIndex->msLevel eq 1 ) { $spectrum->basePeak( $scanIndex->basePeak ); }
  #else { $spectrum->precursorPeak( $scanIndex->precursorPeak ); }
  }
#else { print "spectrum tic under threshold : " . $totIonCurrent."\n"; }

return $spectrum;
}

##############################################################################
# Method: _buildIndex()
#
sub _buildIndex
{
my $self = shift;
my( $block, $nbReadBlocks, $blockSize, $nbAnchoringAttempts );
$blockSize = 45000;
my $maxAnchoringAttempts = 3;

my $previousPos = 0;
while( sysread($self->{fileHandle},$block,$blockSize) )
  {
  ### Research of an anchor
#my @blocks = split(/\x20\x00\x20\x00\x20\x00\x20\x00\x20\x00\x20\x00\x20\x00\x45\x00\x6E\x00\x64\x00\x0A\x00/,$block);
  my @blocks = split(/\x00\x00\x80\x00\x00\x00/,$block);
  #my @blocks = split(/\x00\x00\x96\x43\x00\x00\xFA\x44/,$block);

  if ( scalar(@blocks) > 1 )
    {
    #Compute the end position of the anchor
#    my $start =  $blockSize*$nbReadBlocks + length($blocks[0]) + 22;
    #my $start = $blockSize*$nbReadBlocks + length($blocks[0]) - 20;
    
    ### Compute the startinfg posistion considering the length of the anchor string
    #my $start = $blockSize*$nbReadBlocks + length($blocks[0]) + 6;
    my $start = $previousPos + length($blocks[0]) + 6;
    
    if( not $self->_isStartingPoint( $start ) )
      {      
      $nbAnchoringAttempts++;
      croak "_buildIndex: can't find the beginning of MS scan data" if $nbAnchoringAttempts eq $maxAnchoringAttempts;
      
      ### Re-positionning at the last putative start
      sysseek($self->{fileHandle},$start,'SEEK_SET');
      
      ### Increment the number of read blocks
      $previousPos = $start;
      #$nbReadBlocks++;
      
      next;
      }

    
#    croak $start;

#    #Small hack
##    while( int($start/16) ne $start/16 ) { $start++; }
#    sysseek($self->{fileHandle},$start,'SEEK_SET');
#    
#    ### Search for the first "01 value"
#    sysread( $self->{fileHandle},$block, 1024 );
#    my $shift = index($block, "\x01");
#    croak "_buildIndex: can't find the 01 value" if $shift eq -1;
#    
#    $start += $shift + 12; #small hack
    
    sysseek($self->{fileHandle},$start - 4,'SEEK_SET'); ### Make a backward shift
#    croak $start;

    ### Build the raw file index
    my $index = new SpectroRawData::Data::Index();
    
    my( $curScanNumber, $curChannel, $nbScans );
    while( my $scanIndex = $self->_makeScanIndex )
      {
      $nbScans++; $scanIndex->id($nbScans);
      if( $scanIndex->msLevel eq 1 )
        {
        $curChannel = 1;
        $curScanNumber++;
        }
      else { $curChannel++; }
      $scanIndex->channel( $curChannel );
      $scanIndex->number( $curScanNumber );
      $index->addScanIndex( $scanIndex );
      }

    $self->_goToScanInfos();
    $index = $self->_extractScanInfos( $index );

    ### Save the index
    $index->writeJSONFile( $self->_indexFile );
    $self->_index( $index );
    return 1;
    }
  else { $previousPos += $blockSize; }
    #{
    #$nbReadBlocks++;
    #}
  }
return;
}

##############################################################################
# Method: _isStartingPoint()
#
sub _isStartingPoint
{
my ($self, $putative_start ) = @_;

my $tmp_buffer;    
sysseek($self->{fileHandle},$putative_start,'SEEK_SET');
sysread($self->{fileHandle},$tmp_buffer,4);
my $first_val = unpack('I',$tmp_buffer);
sysread($self->{fileHandle},$tmp_buffer,4);
my $second_val = unpack('I',$tmp_buffer);

if( $second_val-$first_val eq 1 ) { return 1; }
else { return 0; }

}

##############################################################################
# Method: _makeScanIndex()
#
sub _makeScanIndex
{
my $self = shift;
require SpectroRawData::Models::ScanIndex;
my $scanIndex = new SpectroRawData::Models::ScanIndex();
my $fhandle = $self->{fileHandle};
my( $buffer, $nbPoints, $startPos );

sysread($fhandle,$buffer,4); #checkpoint
my $checkPoint = unpack('I',$buffer);
if( not($checkPoint eq 128 or $checkPoint eq 0) )  {return; }
 # { my $pos = sysseek($fhandle,0,1); print $pos."\n"; return; }

#new method (data dependant scan)
if( $checkPoint eq 128 )
  {
  sysread($fhandle,$buffer,4); #nbPoints
  $nbPoints = unpack('I',$buffer);
  
#  print $nbPoints."\n";
  sysseek($fhandle,4*12,1); #II?ffddIII

  my $lastPos;
  foreach (1..$nbPoints)
    {
    sysread($fhandle,$buffer,4); #nbNext
    my $nbNext = unpack('I',$buffer)+2;
    $startPos = sysseek($fhandle,4*$nbNext,1); #skip unknown values
    }
  $startPos-=4;
  
  my $skip = 4+$nbPoints*16;
  sysseek($fhandle,$skip,1); #skip peaks values, annotations and resolutions

  my $noMoreFloat =0;
  do{
    sysread($fhandle,$buffer,4*3);
    my @values = unpack("I3",$buffer);
    if($values[0] eq 1 ) { $noMoreFloat=1; }
    if($values[0] eq 0 ) { return; } #my $pos = sysseek($fhandle,0,1); print $pos." end\n"; return; }
    }until( $noMoreFloat );
    
  $scanIndex->msLevel(1);
  }
elsif($checkPoint eq 0 )
  {
  $startPos = sysseek($fhandle,24,1);
  sysread($fhandle,$buffer,4); #nbPoints
  $nbPoints = unpack('I',$buffer);
  sysseek($fhandle,4*2*$nbPoints,1);
#  print $nbPoints." at $startPos\n";
  sysseek($fhandle,4*3,1);
  $scanIndex->msLevel(2);
  }
#print 'start at '.$startPos."\n";
#print 'num of peaks '.$nbPoints."\n";

$scanIndex->start($startPos);
#$scanIndex->numOfPeaks($nbPoints);

#my $pos = sysseek($fhandle,0,1);
#print $pos."\n";

return $scanIndex;
}

##############################################################################
# Method: _goToScanInfos()
#
sub _goToScanInfos
{
my( $self ) = @_;

my $fhandle = $self->{fileHandle};
sysseek($fhandle,0,2); #go to the end of the file

my $fSize = -s $self->file;
#my $blockSize = 100000000; # read about 100 Mo => TODO 5% of file size
my $blockSize = int($fSize/10); # read 10% of file size
my $block = $self->reverseSysRead( $fhandle, $blockSize );

my $string;
foreach (1..28) { $string.= '\x00'; }
$string .= '\x01\x00\x00\x00\x15\x00\x00\x00';
croak "_goToScanInfos: can't found scan info starting point" if not $block =~ /$string/;

my @blocks = split( /$string/, $block );
my $offset = length( $block ) - length( $blocks[-1] ) - 12;
sysseek($fhandle,$offset,1);

### OLD CODE ###
#my $itemString = 'I\x00t\x00e\x00m\x00';
#croak "_goToScanInfos: block size is too small" if not $block =~ /$itemString/;

#my @blocks = split( /$itemString/, $block ); 
#my $lastBlock = $blocks[-1];

#my $string;
#foreach (1..28) { $string.= '\x00'; }
#$string .= '\x01\x00\x00\x00\x15\x00\x00\x00';
#croak "_goToScanInfos: can't found scan info starting point" if not $lastBlock =~ /$string/;

##TODO: use perl index function
#my @blocks2 = split( /$string/, $lastBlock );
#my $offset = length( $block ) - length( $lastBlock ) + length( $blocks2[0] ) + 24;
#sysseek($fhandle,$offset,1);
### OLD CODE ###

return 1;
}

##############################################################################
# Method: _extractScanInfos()
#
sub _extractScanInfos
{
my( $self, $index ) = @_;

require SpectroRawData::Data::AlignmentMatrix;
my $timeMatrix = new SpectroRawData::Data::AlignmentMatrix();
my $timeMapping;

my $newIndex = new SpectroRawData::Data::Index();
while( my $scanIndex = $index->getScanIndex('next') )
  {
  my $scanInfos = $self->_readScanInfos();
  $scanIndex->retentionTime( sprintf("%0.3f", 60*$scanInfos->{retTime}) );
  $scanIndex->TIC( int($scanInfos->{tic}) );
#  $scanIndex->lowestMoz( $scanInfos->{lowMass} );
#  $scanIndex->highestMoz( $scanInfos->{highMass} );
  my $peak = new SpectroRawData::Models::Peak;
  $peak->moz( sprintf("%0.5f",$scanInfos->{peakMoz}) );
  $peak->intensity( int($scanInfos->{peakInt}) );

  $scanIndex->basePeak( $peak );
  #if( $scanInfos->{type} eq 21 ) { $scanIndex->basePeak( $peak ); } # MS level
  #elsif( $scanInfos->{type} eq 18 ) { $scanIndex->precursorPeak( $peak ); } # MSMS level
  
  if($scanIndex->msLevel eq 1 )
    { $timeMapping->{$scanIndex->number} = [undef,int($scanIndex->retentionTime)]; }

  $newIndex->addScanIndex( $scanIndex );
  }

$timeMatrix->createChannels($timeMapping,2);
$newIndex->timeMatrix($timeMatrix);
    
return $newIndex;
}

##############################################################################
# Method: _readScanInfos()
#
sub _readScanInfos
{
my( $self ) = @_;

my $fhandle = $self->{fileHandle};
my $tmpBlock;
sysread($fhandle,$tmpBlock,16);
my @integers = unpack('I4',$tmpBlock);
sysread($fhandle,$tmpBlock,48);
my @doubles = unpack('d6',$tmpBlock);

my $scanInfos = { id => $integers[1], type => $integers[2], retTime => $doubles[0],
                  tic => $doubles[1], peakInt => $doubles[2], peakMoz => $doubles[3],
                  lowMass => $doubles[4], highMass => $doubles[5]
                };

### Read other values
sysread($fhandle,$tmpBlock,4); ### unknown int
sysread($fhandle,$tmpBlock,4); ### scan id

my $scan_id = unpack('I',$tmpBlock);
if( not $scan_id > 0 ) { sysread($fhandle,$tmpBlock,8); } ### LTQ Velos compatibility fix

return $scanInfos;
}



1;


