package SpectroRawData::Models::Spectrum;

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
sub isCentroided { return $_[0]->_accessor('isCentroided', $_[1]); }
sub polarity { return $_[0]->_accessor('polarity', $_[1]); }

##############################################################################
# Method: getMozRange()
#
sub getMozRange { return $_[0]->getXRange; }

##############################################################################
# Method: getIntensityRange()
#
sub getIntensityRange { return $_[0]->getYRange; }

##############################################################################
# Method: addPeak()
#
sub addPeak
{
my( $self, $peak ) = @_;
croak "addPeak: undefined peak" if !defined $peak;

### Intialize array
$self->dataPoints([]) if !defined $self->dataPoints;
### Add peak
push(@{$self->dataPoints}, [$peak->moz, $peak->intensity] );

return $peak;
}

##############################################################################
# Method: getPeak()
#
sub getPeak
{
my( $self, $query, $value ) = @_; #set or not the iterator to the scan number

my $nbPeaks = $self->getNumOfPeaks();
my $peak;

if( defined $nbPeaks )
  {
  if( $query eq 'number' ) { $peak = $self->_getPeak( $value ); }
  elsif( $query eq 'next' )
    {
    my $peakNumber = $self->_iterator('peakNumber','+');
    if( $peakNumber <= $nbPeaks ) { $peak = $self->_getPeak( $peakNumber ); }
    else { $self->_resetIterator('peakNumber'); }
    }
  elsif( $query eq 'previous' )
    {
    my $peakNumber = $self->_iterator('peakNumber','-');
    if( $peakNumber > 0 ) { $peak = $self->_getPeak( $peakNumber ); }
    else { $self->_resetIterator('peakNumber'); }
    }
  else { croak "Can't use $query as a query method "; }
  }

return $peak;
}

##############################################################################
# Method: _getPeak()
#
sub _getPeak
{
my( $self, $number) = @_;
return undef if !defined $number or $number <= 0 or $number > $self->getNumOfPeaks;

my $dataPoint = $self->dataPoints->[$number-1];

require SpectroRawData::Models::Peak;
my $peak = new SpectroRawData::Models::Peak();
$peak->moz( $dataPoint->[0] );
$peak->intensity( $dataPoint->[1] );

return $peak;
}

##############################################################################
# Method: getNumOfPeaks()
#
sub getNumOfPeaks { return $_[0]->getNumOfPoints; }



1;
