package SpectroRawData::Models::Chromatogram;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SpectroRawData::Models::XYData/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub area { return $_[0]->_accessor('area', $_[1]); }
sub intensitySum { return $_[0]->_accessor('intSum', $_[1]); }
sub apex { return $_[0]->_arrayAccessor('apex', $_[1]); } ###  New => replace intensityMax
sub apexPos { return $_[0]->_accessor('apexPos', $_[1]); } ###  New => replace maxIntensityScan
sub selection { return $_[0]->_arrayAccessor('selection', $_[1]); }

##############################################################################
# Method: computeProperties()
#
sub computeProperties
{
my( $self, $selection ) = @_;
my $dataPoints = $self->dataPoints; return if !defined $dataPoints;
$selection = (defined $selection and scalar(@$selection) eq 2) ? $selection : [0, scalar(@$dataPoints)-1];

my( $area, $intensitySum, @apex, $apexPos, $prevXValue, $prevYValue );

my $pos = 0;
foreach my $dataPoint (@$dataPoints)
  {
  if( $pos >= $selection->[0] and $pos <= $selection->[1] )
    {
    my $x = $dataPoint->[0];
    my $y = $dataPoint->[1];
    $intensitySum += $y;

    if( scalar(@apex) eq 0 or $y > $apex[1] )
      {
      @apex = ( $x, $y );
      $apexPos = $pos;
      }

    if( defined $prevXValue )
      {
      my $deltaX = $x-$prevXValue;
      $area += ($y + $prevYValue ) * $deltaX / 2;
      }

    $prevXValue = $x;
    $prevYValue = $y;
    }
  $pos++;
  }

$area = $intensitySum if $intensitySum > $area; # i.e. only one point in the profile
$self->area( $area );
$self->intensitySum( $intensitySum );
$self->apex( \@apex );
$self->apexPos( $apexPos );
$self->selection( $selection );

return 1;
}



1;



