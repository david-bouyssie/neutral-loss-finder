package SpectroRawData::Data::Index;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SerializablePackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = $class->SUPER::new(@_);
bless($self, $class);

$self->scanNumberList([]);
$self->msScanIds([]);
$self->msLevelList([]);
$self->channelList([]);
$self->retentionTimeList([]);
$self->ticList([]);
$self->basePeakMozList([]);
$self->basePeakIntList([]);
$self->startList([]);
$self->sizeList([]);

return($self);
}

##############################################################################
# Object accessors
#
sub scanNumberList { return $_[0]->_arrayAccessor('scanNumberList', $_[1], $_[2]); }
sub msScanIds { return $_[0]->_arrayAccessor('msScanIds', $_[1], $_[2]); }
sub msLevelList { return $_[0]->_arrayAccessor('msLevelList', $_[1], $_[2]); }
sub channelList { return $_[0]->_arrayAccessor('channelList', $_[1], $_[2]); }
sub retentionTimeList { return $_[0]->_arrayAccessor('retTimeList', $_[1], $_[2]); }
sub ticList { return $_[0]->_arrayAccessor('ticList', $_[1], $_[2]); }
sub basePeakMozList { return $_[0]->_arrayAccessor('basePeakMozList', $_[1], $_[2]); }
sub basePeakIntList { return $_[0]->_arrayAccessor('basePeakIntList', $_[1], $_[2]); }
sub startList { return $_[0]->_arrayAccessor('startList', $_[1], $_[2]); }
sub sizeList { return $_[0]->_arrayAccessor('sizeList', $_[1], $_[2]); }
sub timeMatrix { return $_[0]->_objectAccessor('timeMatrix', $_[1],'SpectroRawData::Data::AlignmentMatrix'); }

##############################################################################
# Method: addScanIndex()
#
sub addScanIndex
{
my( $self, $scanIndex ) = @_;

push(@{$self->scanNumberList}, $scanIndex->number);
push(@{$self->msScanIds}, $scanIndex->id ) if $scanIndex->msLevel eq 1;
push(@{$self->msLevelList}, $scanIndex->msLevel);
push(@{$self->channelList}, $scanIndex->channel);
push(@{$self->retentionTimeList}, $scanIndex->retentionTime);
push(@{$self->ticList}, $scanIndex->TIC);
push(@{$self->basePeakMozList}, $scanIndex->basePeak->moz);
push(@{$self->basePeakIntList}, $scanIndex->basePeak->intensity);
push(@{$self->startList}, $scanIndex->start);
push(@{$self->sizeList}, $scanIndex->size);
croak "addScanIndex: the current scan number doesn't match the current scan index" if
      $scanIndex->number ne $self->getNumOfScans;

return $scanIndex;
}

##############################################################################
# Method: getScanIndex()
#
sub getScanIndex
{
my( $self, $query, $value, $updateIterator ) = @_;

my $nbElems = $self->getNumOfScanIndexes();
my $object;

if( defined $nbElems )
  {
  if( $query eq 'number' )
    {
    if( $value > 0 and $value <= $nbElems )
      {
      my $scanId = $self->msScanIds->[$value-1];
      $object = $self->_makeScanIndex( $scanId );
      $self->_iterator('scanIndexes','=',$scanId) if $updateIterator;
      }
    else { $self->throwError("getScanIndex: number $value over range !"); return; }
    }
  elsif( $query eq 'id' and defined $value )
    {
    if( $value > 0 and $value <= $nbElems )
      {
      $object = $self->_makeScanIndex( $value );
      $self->_iterator('scanIndexes','=',$value) if $updateIterator;
      }
    else { $self->throwError("getScanIndex: id $value over range !"); return; }
    }
  elsif( $query eq 'next' )
    {
    my $id = $self->_iterator('scanIndexes','+');
    if( $id <= $nbElems ) { $object = $self->getScanIndex( 'id', $id ); }
    else { $self->_resetIterator('scanIndexes'); }
    }
  }
  
return $object;
}

##############################################################################
# Method: getNumOfScanIndexes()
#
sub getNumOfScanIndexes { return scalar(@{$_[0]->scanNumberList}); }

##############################################################################
# Method: getNumOfScans()
#
sub getNumOfScans { return scalar(@{$_[0]->msScanIds}); }

##############################################################################
# Method: _makeScanIndex()
#
sub _makeScanIndex
{
my( $self, $id ) = @_;
my $pos = $id-1;

my $hash = { id => $id,
             number => $self->scanNumberList->[$pos],
             msLevel => $self->msLevelList->[$pos],
             channel => $self->channelList->[$pos],
             retTime => $self->retentionTimeList->[$pos],
             TIC => $self->ticList->[$pos],
             start => $self->startList->[$pos],
             size => $self->sizeList->[$pos],
             basePeak => { 'x' => $self->basePeakMozList->[$pos], 'y' => $self->basePeakIntList->[$pos] },
           };
           
require SpectroRawData::Models::ScanIndex;
my $scanIndex = new SpectroRawData::Models::ScanIndex( $hash );

#$scanIndex->id($id);
#$scanIndex->number( $self->scanNumberList->[$pos] );
#$scanIndex->msLevel( $self->msLevelList->[$pos] );
#$scanIndex->channel( $self->channelList->[$pos] );
#$scanIndex->retentionTime( $self->retentionTimeList->[$pos] );
#$scanIndex->TIC( $self->ticList->[$pos] );
#$scanIndex->start( $self->startList->[$pos] );
#$scanIndex->size( $self->sizeList->[$pos] );

#require SpectroRawData::Models::Peak;
#my $basePeak = new SpectroRawData::Models::Peak;
#$basePeak->moz( $self->basePeakMozList->[$pos] );
#$basePeak->intensity( $self->basePeakIntList->[$pos] );
#$scanIndex->basePeak( $basePeak );

return $scanIndex;
}

1;

