package SpectroRawData::Data::AlignmentMatrix;

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
# Object accessors
#
sub getChannels { return $_[0]->_arrayAccessor('channels'); }
sub getChannelShifts { return $_[0]->_arrayAccessor('channelShifts' ); }
sub _channelIndexes { return $_[0]->_accessor('channelIndexes', $_[1] ); } #Index of the channel values
sub _scalingFactor { return $_[0]->_accessor('scalingFactor', $_[1] ); }

##############################################################################
# Method: createChannels()
#
#
sub createChannels
{
my( $self, $mappedChannels, $numOfChannels, $scalingFactor ) = @_;
my @firstChannel = keys(%{ $mappedChannels});
croak "createChannels: input is empty" if not scalar( @firstChannel ) > 0;
croak "createChannels: undefined number of channels" if !defined $numOfChannels;
my $curNC = scalar(@{ $mappedChannels->{$firstChannel[0]} });
croak "createChannels: the specified number of channels doesn't match the provided data" if $curNC ne $numOfChannels;

#Sort the first channel
@firstChannel = sort { $a <=> $b } @firstChannel;
my $channels = [];
my $precValues = [];
foreach my $channelPos (0..$numOfChannels-1)
  { $precValues->[$channelPos] = []; }

#Remove bad time marks (hypothesis => the events must be in the same order)
my %valuesToRemove;
my $prevSlope;
foreach my $value (@firstChannel)
  {
  my $otherValues = $mappedChannels->{$value};
  my $updatePreviousValues = 1;
  foreach my $channelPos (1..$numOfChannels-1)
    {
    my $otherValue = $otherValues->[$channelPos];
    if( defined $otherValue )
      {
      if( defined $precValues->[$channelPos]->[1] and
          $otherValue <= $precValues->[$channelPos]->[1] )
        {
        if( $otherValue > $precValues->[$channelPos]->[0] )
          { $valuesToRemove{ $precValues->[0]->[1] } = 1; } #remove previous value
        else { $valuesToRemove{ $value } = 1; $updatePreviousValues=0; } #remove current value
        }

#      #Slope analysis (TODO: use outlier test)
#      if(defined $precValues->[$channelPos]->[0] )
#        {
#        if( defined $prevSlope )
#          {
#          my @shifts;
#          $shifts[0] = $precValues->[$channelPos]->[1] - $precValues->[0]->[1];
#          $shifts[1] = $otherValue - $value;
#          my $curSlope = abs($shifts[1]/$shifts[0]);
#          
#          if( $curSlope/$prevSlope > 4 or $curSlope/$prevSlope < 1/4 )
#            { $valuesToRemove{ $value } = 1; $updatePreviousValues=0; }
#          else { $prevSlope = $curSlope; }
#          }
#        else
#          {
#          my @shifts;
#          $shifts[0] = $precValues->[$channelPos]->[0] - $precValues->[0]->[0];
#          $shifts[1] = $precValues->[$channelPos]->[1] - $precValues->[0]->[1];
#          $prevSlope = abs($shifts[1]/$shifts[0]);
#          }
#        }
          
      if( $updatePreviousValues eq 1 )
        {
        $precValues->[$channelPos]->[0] = $precValues->[$channelPos]->[1];
        $precValues->[$channelPos]->[1] = $otherValue;
        }
      }
    else { $valuesToRemove{ $value } = 1; $updatePreviousValues=0; }
    }

  if( $updatePreviousValues eq 1 ) #update the previous values
    {
    $precValues->[0]->[0] = $precValues->[0]->[1];
    $precValues->[0]->[1] = $value;
    }
  }

foreach my $value (@firstChannel)
  {
  if( not defined $valuesToRemove{ $value } )
    {
    my $otherValues = $mappedChannels->{$value};
    foreach my $channelPos (1..$numOfChannels-1)
      {
      my $otherValue = $otherValues->[$channelPos];
      push(@{ $channels->[$channelPos] }, $otherValue );
      }
    push( @{ $channels->[0] }, $value );
    }
  }

$_[0]->_arrayAccessor('channels', $channels );
$_[0]->_computeIndexes( $scalingFactor );
$_[0]->_computeShifts();

return $channels;
}

##############################################################################
# Function: round()
#
sub round { return sprintf("%.f", $_[0]); }

##############################################################################
# Function: equation()
#
sub equation
{
my( $x1, $y1, $x2, $y2 ) = @_;
#print "x1:$x1 y1:$y1 x2:$x2 y2:$y2 \n";
my $deltaX = $x2 - $x1;
croak "Can't compute an equation with two identical x values ($x1)" if $deltaX eq 0;
my $a = ($y2 - $y1)/$deltaX;
my $b = $y1 - ($a*$x1);
return [ $a, $b];
}

##############################################################################
# Method: _computeIndexes()
#
sub _computeIndexes
{
my( $self, $scalingFactor ) = @_; #$scalingFactor => 60 to index in minutes
$scalingFactor = 1 if !defined $scalingFactor;
$self->_scalingFactor( $scalingFactor );

my $channels = $self->getChannels;
my $indexes = [];
my $numOfChannels = scalar(@$channels);

foreach my $channelPos (0..$numOfChannels-1)
  {
  my $channel = $channels->[$channelPos];
  my $index = {};
  
  my $markPos = 0;
  foreach my $value (@$channel)
    {
    my $roundedValue = round($value/$scalingFactor);
    $index->{$roundedValue} = $markPos if !defined $index->{$roundedValue};
    $markPos++;
    }
    
  $indexes->[$channelPos] = $index;
  }
$self->_channelIndexes( $indexes );

return 1;
}

##############################################################################
# Method: _computeShifts()
#
sub _computeShifts
{
my( $self ) = @_;
my $channels = $self->getChannels;
my $shifts = [];
my $numOfChannels = scalar(@$channels);
my $numOfMarks = scalar(@{$channels->[0]});

foreach my $markPos (0..$numOfMarks-1)
  {
  my $firstChannelMark = $channels->[0]->[$markPos];
  
  foreach my $channelPos (1..$numOfChannels-1)
    {
    my $curChannelMark = $channels->[$channelPos]->[$markPos];
    my $shift = $curChannelMark - $firstChannelMark;
    $shifts->[$channelPos-1]->[$markPos] = $shift;
    }
  }
  
$self->_arrayAccessor( 'channelShifts', $shifts );
}

##############################################################################
# Method: getUniversalValue()
#
sub getUniversalValue
{
my( $self, $channelNum, $value ) = @_;
return $value if $channelNum eq 1;

my $channels = $self->getChannels;
croak "getUniversalValue: undefined channel number" if not defined $channelNum;
croak "getUniversalValue: channel number must be > 0" if $channelNum <= 0;
croak "getUniversalValue: invalid channel number" if $channelNum > scalar(@$channels);
croak "getUniversalValue: undefined value" if not defined $value;

my $channelPos = $channelNum - 1;
my $values = $channels->[$channelPos];
my $index = $self->_channelIndexes->[$channelPos];
my $shifts = $self->getChannelShifts->[$channelPos-1];
my $shift = $self->_getShift( $value, $values, $index, $shifts );

return $value - $shift;
}

##############################################################################
# Method: getTheoricalValue()
#
sub getTheoricalValue
{
my( $self, $channelNum, $value ) = @_;
return $value if $channelNum eq 1;

my $channels = $self->getChannels;
croak "getUniversalValue: undefined channel number" if not defined $channelNum;
croak "getUniversalValue: channel number must be > 0" if $channelNum <= 0;
croak "getUniversalValue: invalid channel number" if $channelNum > scalar(@$channels);
croak "getUniversalValue: undefined value" if not defined $value;

my $values = $channels->[0];
my $index = $self->_channelIndexes->[0];
my $shifts = $self->getChannelShifts->[$channelNum-2];
my $shift = $self->_getShift( $value, $values, $index, $shifts );

return $value + $shift;
}


##############################################################################
# Method: _getShift()
#
sub _getShift
{
my( $self, $value, $values, $index, $shifts ) = @_;

my $nearestPos = $self->_getNearestValuePos( $values, $index, $value );
my $nearestVal = $values->[$nearestPos];
my $delta = $nearestVal - $value;
my $overRange = ( $value < $values->[0] or $value > $values->[-1]) ? 1 : 0;

my $shift;
if( $delta eq 0 or $overRange ) { $shift = $shifts->[$nearestPos]; }
else
  {
  my $otherPos;
  if( $delta < 0 ) { $otherPos = $nearestPos + 1;  }
  else { $otherPos = $nearestPos - 1; }
  if( $otherPos >= scalar(@$values) ) { return $shifts->[$nearestPos]; }
  my( $a, $b ) = @{ equation( $nearestVal, $shifts->[$nearestPos], $values->[$otherPos], $shifts->[$otherPos] ) };
  $shift = $value * $a + $b;
  }

return $shift;
}
#TODO => create a value finder object (SuperArray object ?)

##############################################################################
# Method: _getNearestIndexValue()
#
sub _getNearestIndexValue
{
my( $self, $index, $value ) = @_;
croak "undefined index" if not defined $index;
croak "undefined value" if not defined $value;

my $roundedValue = round($value);
my $indexValue = $index->{$roundedValue};
if(!defined $indexValue )
  {
  my $curDelta;
  my @roundedValueList = keys(%{$index});
  @roundedValueList = sort { $a <=> $b } @roundedValueList;

  foreach my $curRoundedValue (@roundedValueList)
    {
    my $delta = abs( $curRoundedValue - $roundedValue );
    if( !defined $curDelta or ($delta < $curDelta and $curRoundedValue < $roundedValue) )
      { $indexValue = $index->{$curRoundedValue}; $curDelta = $delta;	}
    else { last; }
    }
  }

return $indexValue;
}

##############################################################################
# Method: _getNearestValuePos()
#
sub _getNearestValuePos
{
my( $self, $values, $index, $value, $startingPoint ) = @_;
croak "undefined values" if not defined $values;
croak "undefined index" if not defined $index;
croak "undefined value" if not defined $value;

my $nearestPos;
my $curDelta;

### TESTS ###
if( $value < $values->[0] ) { return 0; }
if( $value > $values->[-1] ) { return -1; }

my $numOfValues = scalar(@$values);
croak '_getNearestValuePos: empty values !' if $numOfValues == 0;

if(!defined $startingPoint ) { $startingPoint = $self->_getNearestIndexValue($index, $value); }

my $pos = $startingPoint;
if( $startingPoint >= $numOfValues ) { $pos = $numOfValues-1; }
$nearestPos = $pos;

### PROCESSING ###
my $startingValue = $values->[$pos];
my $startingDelta = $startingValue - $value;

my $nearestFound;
do{
  if( $startingDelta == 0 ) { $nearestPos = $pos; $nearestFound = 1; }
  elsif( $pos >= $numOfValues ) { $nearestFound = 1; } #TODO : throwError
  else
    {
    my $curValue = $values->[$pos];
    my $delta = abs( $curValue - $value );
  	if( !defined $curDelta or $delta <= $curDelta ) {	$nearestPos = $pos; $curDelta = $delta;	}
    if( $curDelta == 0) { $nearestFound = 1; }

    if( $startingDelta < 0 )
      { if( $curDelta ne $delta and $curValue > $value ) { $nearestFound = 1; } $pos++; }
    else { if( $curDelta ne $delta and $curValue < $value ) { $nearestFound = 1; } $pos--;  }
		}
  }until( $nearestFound );

return $nearestPos;
}

##############################################################################
# Method: toTSVFile()
#
sub toTSVFile
{
my( $self, $filePath ) = @_;

open( FOUT,">$filePath") or die $!;

my $channels = $self->getChannels;
my $nbChannels = scalar(@$channels);
my $firstChannel = $channels->[0];
my $nbValues = scalar(@$firstChannel);

foreach my $valuePos (0..$nbValues-1)
  {
  my @values;
  foreach my $channelPos (0..$nbChannels-1)
    { push(@values, $channels->[$channelPos]->[$valuePos]); }
  print FOUT join("\t", @values)."\n";
  }

close FOUT;

return 1;
}


##############################################################################
# Method: getNumOfValues()
#
#
sub getNumOfValues
{
my( $self ) = @_;
my $firstChannel = $self->getChannels->[0];
return scalar(@$firstChannel);
}

1;

