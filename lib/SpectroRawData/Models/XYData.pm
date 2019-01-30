package SpectroRawData::Models::XYData;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/CommonPackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub dataPoints { return $_[0]->_arrayAccessor('xy', $_[1]); }
sub _yRange { return $_[0]->_arrayAccessor('yRange', $_[1]); }

##############################################################################
# Method: getNumOfPoints()
#
sub getNumOfPoints { return scalar(@{$_[0]->dataPoints}) if defined $_[0]->dataPoints; }

##############################################################################
# Method: getXRange()
#
sub getXRange
{ 
my( $self ) = @_;
my $dataPoints = $self->dataPoints;
return [] if !defined $dataPoints;

my $range = [ $dataPoints->[0]->[0], $dataPoints->[-1]->[0] ];

return $range;
}

##############################################################################
# Method: getYRange()
#
sub getYRange
{
my( $self ) = @_;
$self->_computeYRange if !defined $self->_yRange;
return $self->_yRange;
}

##############################################################################
# Method: _computeYRange()
#
sub _computeYRange
{
my( $self ) = @_;
my $dataPoints = $self->dataPoints;

my @yRange;
foreach my $dataPoint (@$dataPoints)
  {
  my $y = $dataPoint->[1];
  $yRange[0] = $y if !defined $yRange[0] or $y < $yRange[0];
  $yRange[1] = $y if $y > $yRange[1];
  }

$self->_yRange( \@yRange );

return 1;
}

1;



