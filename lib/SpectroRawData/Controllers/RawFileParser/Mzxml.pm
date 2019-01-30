package SpectroRawData::Controllers::RawFileParser::Mzxml;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use File::Basename;
use Fcntl qw/O_RDONLY/;

use base qw/SpectroRawData::Controllers::RawFileParser::Base/;
use SpectroRawData::Models::Scan;
use SpectroRawData::Models::Peaks;
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
sysopen($self->{fileHandle},$self->file, O_RDONLY ) or die "Reading error : $!";
$self->_loadIndex();

$self->infos( {isCentroided => 0} ); #TODO: read it from the file
}

##############################################################################
# Method: _readSpectrum()
#
sub _readSpectrum
{
my( $self, $channel, $number, $scanIndex ) = @_;

my $spectrum = new SpectroRawData::Models::Scan;
$spectrum->id( $scanIndex->id );
$spectrum->number( $number );
$spectrum->msLevel( $scanIndex->msLevel );
$spectrum->basePeak( $scanIndex->basePeak );
$spectrum->TIC( $scanIndex->TIC );
$spectrum->retentionTime( $scanIndex->retentionTime );
#$spectrum->numOfPeaks( $scanIndex->numOfPeaks );

my( $buffer, $totIonCurrent, @mozList, @intensities, $mozIndex );

### Read the block related to the current spectrum
sysseek($self->{fileHandle},$scanIndex->start, 0 ); ### SEEK_SET
sysread($self->{fileHandle},$buffer,$scanIndex->size); #read m/z and intensity values

### Parse the readed block with an xml parser
my $scanParser = new XML::Simple ( KeepRoot => 1 );
my $xmlScan = $scanParser->XMLin( $buffer );

### Set the spectrum attributes
$spectrum->numOfPeaks($xmlScan->{scan}->{peaksCount});
$spectrum->polarity($xmlScan->{scan}->{polarity});
$spectrum->lowestMoz($xmlScan->{scan}->{startMz});
$spectrum->highestMoz($xmlScan->{scan}->{endMz});
if( defined $xmlScan->{scan}->{precursorMz} )
  {
  require SpectroRawData::Models::Peak;
  my $precursor = new SpectroRawData::Models::Peak;
  
  if( ref($xmlScan->{scan}->{precursorMz}) eq 'HASH' )
    {
    $precursor->moz( $xmlScan->{scan}->{precursorMz}->{content} );
    $precursor->intensity( $xmlScan->{scan}->{precursorMz}->{precursorIntensity} );
    $precursor->charge( $xmlScan->{scan}->{precursorMz}->{precursorCharge} );
    }
  else { $precursor->moz( $xmlScan->{scan}->{precursorMz} ); }
  
  $spectrum->precursorPeak( $precursor );
  }

### Set the peak list
my $peaks = new SpectroRawData::Models::Peaks();
$peaks->base64Data($xmlScan->{scan}->{peaks}->{content});
$peaks->pairOrder( $xmlScan->{scan}->{peaks}->{pairOrder});
$peaks->byteOrder( $xmlScan->{scan}->{peaks}->{byteOrder});
$peaks->precision( $xmlScan->{scan}->{peaks}->{precision});
$peaks->parseBase64Data if !$self->compressData;
$spectrum->peaks($peaks);

return $spectrum;
}


##############################################################################
# Method: _buildIndex()
#
sub _buildIndex
{
my $self = shift;

require XML::Simple;
require SpectroRawData::Data::AlignmentMatrix;
require InSilicoSpectro::Utils::XML::SaxIndexMaker;
my $indexMaker = InSilicoSpectro::Utils::XML::SaxIndexMaker->new();

### Index the file using a SAX parser
my $dir = dirname( __FILE__ );
my $indexParamFile = $dir . "/mzXML.indexParams.xml";
$indexMaker->readXmlIndexMaker($indexParamFile);
my( $string, $stringHdl );
my $tmpFile = $self->file . ".tmpIndex";
$indexMaker->makeIndex( $self->file, $tmpFile );

#open( $stringHdl, ">", \$string  );
#$indexMaker->printIndexXml( $stringHdl );
#close $stringHdl;

### Convert the XML index into a JSON index
my $indexParser = new XML::Simple (KeyAttr=>[], ForceArray => ['oneIndexedElement'] );
my $xmlIndex = $indexParser->XMLin( $tmpFile );
unlink $tmpFile;

my $jsonIndex  = new SpectroRawData::Data::Index();
my $timeMatrix = new SpectroRawData::Data::AlignmentMatrix();
my( $curScanNumber, $curChannel, $timeMapping, $nbScanIndexes );

foreach my $indexElem (@{ $xmlIndex->{indexedElements}->{oneIndexedElement} })
  {
  my $path = $indexElem->{path};
  if( $path eq '/mzXML/msRun/scan' or $path eq '/mzXML/msRun/scan/scan' )
    {
    my $scanIndex = $self->_makeScanIndex( $indexElem );

    if( $scanIndex->msLevel eq 1 )
      {
      $curChannel = 1;
      $curScanNumber++;
      $timeMapping->{$curScanNumber} = [undef,int($scanIndex->retentionTime)];
      }
    else { $curChannel++; }
    
    $scanIndex->channel( $curChannel );
    $scanIndex->number( $curScanNumber );
    $jsonIndex->addScanIndex( $scanIndex );
    }
#  else
#    {
#    ### Index file header infos
#    #print $path."\n";

#    }
  }
      
### Create the "retention time/scan numbers" matrix
$timeMatrix->createChannels($timeMapping,2);
$jsonIndex->timeMatrix($timeMatrix);

### Save the index
$jsonIndex->writeJSONFile( $self->_indexFile );
$self->_index( $jsonIndex );

return 1;
}

##############################################################################
# Method: _makeScanIndex()
#
sub _makeScanIndex
{
my( $self, $indexElem ) = @_;

# Example of scan index:
#
#{
#  'parentId' => '0',
#  'pos' => {
#           'lengthByte' => '16763',
#           'startByte' => '18589',
#           'lineNumber' => '20',
#           'columnNumber' => '0'
#         },
#  'id' => '5',
#  'path' => '/mzXML/msRun/scan',
#  'attr' => [
#              {
#                'value' => '51',
#                'name' => 'basePeakIntensity'
#              },
#              {
#                'value' => '301.13348427271',
#                'name' => 'basePeakMz'
#              },
#              {
#                'value' => '1',
#                'name' => 'msLevel'
#              },
#              {
#                'value' => '2',
#                'name' => 'num'
#              },
#              {
#                'value' => 'PT2.23699998855591S',
#                'name' => 'retentionTime'
#              },
#              {
#                'value' => 'TOF MS1',
#                'name' => 'scanType'
#              },
#              {
#                'value' => '3621',
#                'name' => 'totIonCurrent'
#              }
#              {
#                'value' => '1544',
#                'name' => 'peaksCount'
#              }
#            ]
#          },


my %attributes = map { $_->{name} => $_->{value} } @{ $indexElem->{attr} };
my $posInfos = $indexElem->{pos};
my( $start, $length ) = @$posInfos{'startByte','lengthByte'};

require SpectroRawData::Models::ScanIndex;
my $scanIndex = new SpectroRawData::Models::ScanIndex();
$scanIndex->start( $start );
$scanIndex->size( $length );
$scanIndex->id( $attributes{num} );
$scanIndex->msLevel( $attributes{msLevel} );
$scanIndex->TIC( $attributes{totIonCurrent} );
#$scanIndex->numOfPeaks( $attributes{peaksCount} );

### Replace comma by dot
$attributes{basePeakMz} =~ s/,/\./g;
$attributes{basePeakIntensity} =~ s/,/\./g;
$attributes{retentionTime} =~ s/,/\./g;

require SpectroRawData::Models::Peak;
my $basePeak = new SpectroRawData::Models::Peak();
$basePeak->moz( sprintf("%0.5f",$attributes{basePeakMz} ) ) if length($attributes{basePeakMz}) > 0;
$basePeak->intensity( int($attributes{basePeakIntensity} ) ) if length($attributes{basePeakIntensity}) > 0;
$scanIndex->basePeak( $basePeak );

my $retTime;
if( $attributes{retentionTime} =~ /PT(.+)S/ ) { $retTime = sprintf("%0.3f", $1); }
$scanIndex->retentionTime( $retTime );

return $scanIndex;
}


1;
