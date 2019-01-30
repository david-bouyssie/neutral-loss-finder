package SpectroRawData::Controllers::RawFileParser::Base;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use File::Spec;
# use Cache::Weak;
use Clone qw/clone/;
use base qw/CommonPackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object destructor
#
sub DESTROY
{
my $self = shift;
$self->clearBuffer();
$self->closeFile();
} 

##############################################################################
# Object accessors
#
sub _index { return $_[0]->_accessor('index', $_[1]); }
sub bufferize { return $_[0]->_accessor('bufferize', $_[1]); }
sub compressData { return $_[0]->_accessor('compressData', $_[1]); }
sub maxMSLevel { return $_[0]->_accessor('maxMSLevel', $_[1]); }
sub title { return $_[0]->_accessor('title', $_[1]); }
sub infos { return $_[0]->_accessor('infos', $_[1]); }
sub ticThreshold { return $_[0]->_accessor('ticThreshold', $_[1]); }
sub intensityThreshold { return $_[0]->_accessor('intensityThreshold', $_[1]); }

sub file
{
my $file = File::Spec->rel2abs($_[1]) if defined $_[1];
return $_[0]->_accessor('file', $file);
}

##############################################################################
# Method: clearBuffer()
#
#sub clearBuffer { $_[0]->{scanBuffer} = undef; }
sub clearBuffer
{
my $self = shift;
$self->{scanBuffer} = [];
$self->{scanBufferCount} = undef;
}

# sub _clearBuffer ### TODO: remove
# {
# my $self = shift;
##delete $_[0]->{scanBuffer};
##$_[0]->{scanBuffer} = [];

# my $cache = $self->{scanCache};
# if( defined $cache )
  # {
  ### Remove weak references
  # $cache->clear;
  
  ### Create a new empty cache
  # $self->_initCache;
  # }

# }

##############################################################################
# Private method: _initCache()
#
# sub _initCache ### TODO: remove
# {
# my $self = shift;

# require File::Basename;
# my $file_name = File::Basename::basename( $self->file );
# $self->{scanCache} = Cache::Weak->new( namespace => $file_name, auto_purge => 0 );
# }

##############################################################################
# Method: closeFile()
#
sub closeFile
{
my $self = shift;
close $self->{fileHandle} if defined $self->{fileHandle};
}

##############################################################################
# Method: _indexFile()
#
sub _indexFile
{
my $self = shift;
return $self->file .'.idx';
}

##############################################################################
# Method: _loadIndex()
#
sub _loadIndex
{
my $self = shift;
my $indexFile = $self->_indexFile;

if( not -f $indexFile ) { $self->_buildIndex(); }
else
  {
  require SpectroRawData::Data::Index;
  my $index = new SpectroRawData::Data::Index();
  $index->readJSONFile( $indexFile );
  $self->_index( $index );
  }
}

###############################################################################
## Method: loadFile()
##
#sub loadFile
#{
#my $self = shift;
#require SpectroRawData::Data::RawFile;
#my $rawFile = new SpectroRawData::Data::RawFile();
#my $scans = new SpectroRawData::Models::Scans();

#while( my $scan = $self->getScan('next') )
#  { $scans->addScan($scan) if $scan->id; } #TODO : change this test (not correct after computeId)
#print "scans loaded !\n";
#$rawFile->scans($scans);

#return $rawFile;
#}

##############################################################################
# Method: _getIdNumber()
#
sub _getIdNumber
{
my( $self, $id  ) = @_;
my $number = $self->_index->scanNumberList->[$id-1];
if( defined $number and ref($number) ne 'HASH' ) {return $number;}
else {return undef; }
}

##############################################################################
# Method: timeToScanNumber()
#
sub timeToScanNumber
{
my( $self, $time ) = @_; #TIME must be in second
my $number = $self->_index->timeMatrix->getUniversalValue(2, int($time) );
if( defined $number and ref($number) ne 'HASH' ) {return sprintf("%.f", $number);}
else { return undef; }
}

##############################################################################
# Method: getMaxIntensity()
#
sub getMaxIntensity
{
my( $self, $channel ) = @_;
my $bpc = $self->getBPC($channel);
my $maxInt = 0;
foreach my $point (@$bpc) { $maxInt = $point->[1] if $point->[1] > $maxInt; }
return $maxInt;
}

##############################################################################
# Method: getTIC()
#
sub getTIC
{
my( $self, $channel ) = @_;
return $self->_getChromatogram('TIC', $channel);
}

##############################################################################
# Method: getBPC()
#
sub getBPC
{
my( $self, $channel ) = @_;
croak "getBPC: undefined channel number" if !defined $channel;
return $self->_getChromatogram('BPC', $channel);
}

##############################################################################
# Method: _getChromatogram()
#
sub _getChromatogram
{
my( $self, $type, $channel  ) = @_;
my $fileIndex = $self->_index;
my $numOfScanIndexes = $fileIndex->getNumOfScanIndexes;
my $timeList = $fileIndex->retentionTimeList;
my $intList;
if( $type eq 'TIC') { $intList = $fileIndex->ticList; }
elsif( $type eq 'BPC') { $intList = $fileIndex->basePeakIntList; }

if( length($channel) > 0 and int($channel) ne $channel )
  { croak "_getChromatogram: the channel number ($channel) must be an integer" ; }

my $channelList = $fileIndex->channelList;
my( %tmpHash, @newTimeList, @newIntList );

foreach my $scanIndexPos (0..$numOfScanIndexes-1)
  {
  if( length( $channel ) == 0 or $channelList->[$scanIndexPos] eq $channel )
    { $tmpHash{ $timeList->[$scanIndexPos] } += $intList->[$scanIndexPos]; }
  }

my @times = sort {$a <=> $b} keys(%tmpHash);
my @chromato;

foreach my $time (@times)
  { push( @chromato, [$time, $tmpHash{$time}] ) if $tmpHash{$time} > 0; }
    
return \@chromato;
}

##############################################################################
# Method: getScan()
#
sub getScan
{
my( $self, $query, $value, $updateIterator ) = @_; #set or not the iterator to the scan number

my $nbScans = $self->getNumOfScans();
my $scan;

if( defined $nbScans )
  {
  if( $query eq 'number' )
    {
    if( $value > 0 and $value <= $nbScans )
      {
      $scan = $self->_getSpectra($value);
      $self->_iterator('scanNumber','=',$value) if $updateIterator;
      }
    }
  elsif( $query eq 'id' )
    {
    my $trueScanNumber = $self->_getIdNumber($value);
    if( defined $trueScanNumber )
      {
      $scan = $self->_getSpectra($trueScanNumber) ;
      $self->_iterator('scanNumber','=',$trueScanNumber) if $updateIterator;
      }
    }
  elsif( $query eq 'time' )
    {
    my $trueScanNumber = $self->timeToScanNumber($value);
    if( defined $trueScanNumber )
      {
      $scan = $self->_getSpectra($trueScanNumber) ; 
      $self->_iterator('scanNumber','=',$trueScanNumber) if $updateIterator;
      }
    }
  elsif( $query eq 'next' )
    {
    my $scanNumber = $self->_iterator('scanNumber','+');

    if( $scanNumber <= $nbScans ) { $scan = $self->getScan( 'number', $scanNumber ); }
    else { $self->_resetIterator('scanNumber'); }
    }
  elsif( $query eq 'previous' )
    {
    my $scanNumber = $self->_iterator('scanNumber','-');
    if( $scanNumber > 0 ) { $scan = $self->getScan( 'number', $scanNumber ); }
    else { $self->_resetIterator('scanNumber'); }
    }
  #else { $scan = $self->_getSpectra($query,$value); }
  else { croak "Can't use $query as a query method "; }
  }

return $scan;
}

##############################################################################
# Method: getNumOfScans()
#
sub getNumOfScans { return $_[0]->_index->getNumOfScans; }

##############################################################################
# Method: _getSpectra()
#
sub _getSpectra_with_cache ### TODO: remove
{
my( $self, $number) = @_;

my $scan;
if( $self->bufferize )
  {  
  ### Init cache if not already done
  $self->_initCache if !defined $self->{scanCache};
  
  ### Try to retrieve cached scan
  $scan = $self->{scanCache}->get( $number );
  
  ### Load the scan if not in the cache
  if( !defined $scan )
    {
    $scan = $self->_readSpectra( $number );
    $self->{scanCache}->set( $number, $scan ) if defined $scan;
    }
  }
else { $scan = $self->_readSpectra( $number ); }

return $scan;
}

##############################################################################
# Method: _getSpectra()
#
sub _getSpectra
{
my( $self, $number) = @_;

my $scan;
if( $self->bufferize )
  {
  if( !defined $self->{scanBuffer}->[$number] )
    {
    $self->clearBuffer if $self->{scanBufferCount} == 1000;      
    $scan = $self->_readSpectra( $number );
    
    #use Scalar::Util qw/weaken/;
    $self->{scanBuffer}->[$number] = $scan;
    $self->{scanBufferCount}++;    

    #weaken( $self->{scanBuffer}->[$number] );
    }
  else { $scan = $self->{scanBuffer}->[$number]; }
  }
else { $scan = $self->_readSpectra( $number ); }

return $scan;
}

##############################################################################
# Method: readSpectrum()
#
sub readSpectrum
{
my( $self, $channel, $number, $scanIndex ) = @_;
return $self->_readSpectrum( $channel,  $number, $scanIndex ); 
}

##############################################################################
# Method: _readSpectra()
#
sub _readSpectra
{
my( $self, $number ) = @_;

my $fileIndex = $self->_index;
my $scanIndex = $fileIndex->getScanIndex('number',$number, 1);
if(!defined $scanIndex ) { $self->throwError("scan id not found: " . $number ."\n"); return; }

my $scan = $self->readSpectrum( 1, $number, $scanIndex ); 
return undef if !defined $scan; 

### Read MS/MS spectra
if( !defined $self->maxMSLevel or $self->maxMSLevel > 1 )
  {
  while( my $subScanIndex = $fileIndex->getScanIndex('next') )
    {
    last if $subScanIndex->msLevel ne 2;
    my $subScan = $self->readSpectrum( 2, $number, $subScanIndex );
    $scan->addScan( $subScan ) if defined $subScan;
    }
  $fileIndex->_resetIterator('scanIndexes');
#  my $nbMSMS = $scanIndex->getNumOfScanIndexes();
#  while( my $subScanIndex = $scanIndex->getScanIndex('next') )
#    { $scan->addScan( $self->_readSpectrum( 2, $number, $subScanIndex ) ); }
  }

#******* temporary UNUSED *******
#if( $scan->TIC > 0 )
#  {
#  #my $scanNumber = $self->_iterator('scanNumber');
#  #if( defined $scanNumber ) { $scan->id($scanNumber); $scanNumber++; }
#
#  #now add the MS/MS scans with at least one peak
#  for( my $expNum = 1; $expNum < $self->{numOfChannels}; $expNum++ )
#    {
#    my $spectrum = $self->_getSpectrum($query,$expNum, $number);
#    #$spectrum->id($scanNumber); $scanNumber++;
#    $scan->addScan( $spectrum ) if $spectrum->TIC > 0;
#    }
#  }

return $scan;
}

##############################################################################
# Interface: _readSpectrum()
#
sub _readSpectrum
{
my( $self, $channel, $number, $scanIndex ) = @_;

require SpectroRawData::Models::Scan;
my $scan = new SpectroRawData::Models::Scan;

return $scan;
}


##############################################################################
# Method: reverseSysRead()
#
sub reverseSysRead
{
my($self, $fHandle, $blockSize ) = @_;
my $curPos = sysseek($fHandle,0,1);

$curPos = 0 if $curPos eq '0 but true';
my $newPos = $curPos - $blockSize;
return if $newPos < 0;

my $retVal = sysseek($fHandle,$newPos,'SEEK_SET');
return if !defined($retVal);

my $readedBlock;
sysread($fHandle,$readedBlock,$blockSize);
sysseek($fHandle,$newPos,'SEEK_SET');
return $readedBlock;
}


1;
