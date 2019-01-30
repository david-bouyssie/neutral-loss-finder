package SpectroRawData::Models::IsotopicProfile;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SpectroRawData::Models::Spectrum/; ### TODO : remove PeakList

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub charge { return $_[0]->_accessor('z', $_[1]); }
sub retentionTime { return $_[0]->_accessor('time', $_[1]); }
sub scanRef { return $_[0]->_accessor('scan', $_[1]); }
sub monoIsotopicPeakNumber { return $_[0]->_accessor('mono', $_[1]); }
sub intensity { return $_[0]->_accessor('int', $_[1]); }

##############################################################################
# Method: getMonoIsotopicPeak()
#
sub getMonoIsotopicPeak { return $_[0]->getPeak('number',$_[0]->monoIsotopicPeakNumber ); }

##############################################################################
# Method: getTrueNumOfPeaks()
#
sub getTrueNumOfPeaks
{
my $self = shift;
my $numOfPeaks = $self->getNumOfPeaks;
my $monoPeakPos = $self->monoIsotopicPeakNumber - 1;
my $trueNumOfPeaks = $numOfPeaks - $monoPeakPos;
return $trueNumOfPeaks;
}

##############################################################################
# Method: getDeltaMoz()
#
sub getDeltaMoz
{
my( $self, $moz ) = @_;
my $delta = $self->getMonoIsotopicPeak->moz - $moz;
return $delta;
}

##############################################################################
# Method: computeIntensity()
#
sub computeIntensity
{
my $self = shift;
my $sum;

$self->_iterator('peakNumber','=', $self->monoIsotopicPeakNumber - 1 );
my $peakNum = 1;

while( my $peak = $self->getPeak('next' ) )
  {
  $sum += $peak->intensity;
  $peakNum++;
  last if $peakNum > 2;
  }

$self->_resetIterator('peakNumber');

return $self->intensity( $sum );
}

##############################################################################
# Method: isValid()
#
sub isValid
{
my( $self, $charge ) = @_;
my $valid = 1;

my $monoPeak = $self->getMonoIsotopicPeak;
my $secondPeak = $self->getPeak('number', $self->monoIsotopicPeakNumber + 1);
return 0 if !defined $monoPeak or $monoPeak->intensity eq 0;

if( defined $secondPeak )
  {
  my $mass = $charge*$monoPeak->moz;
  my $ratio2_1 = $secondPeak->intensity / $monoPeak->intensity;
  $valid = 0 if $ratio2_1 > ($mass/700);
  
#  my $thirdPeak = $self->getPeak('number', $self->monoIsotopicPeakNumber + 2) if $valid;
#  
#  if( defined $thirdPeak )
#    {
#    my $ratio3_1 = $thirdPeak->intensity / $monoPeak->intensity;
#    $valid = 0 if $ratio3_1 > ($mass/1500); # TODO : check this value

#    if( $valid and $secondPeak->intensity ne 0)
#      {
#      my $ratio3_2 = $thirdPeak->intensity / $secondPeak->intensity;
#      $valid = 0 if $ratio3_2 > ($mass/700); # TODO : check this value
#      }
#    }
  }

#my $mass_tol = 0.3;
#my $nbPeaks = $self->getNumOfPeaks();

#if( $nbPeaks > 2 and $self->charge() < 5)
#  {
#  my $delta = 1-( $self->charge()*( $self->getPeak( 'number', 3)->moz() -
#                                    $self->getPeak( 'number', 1)->moz())/2 );
#  if( $delta > $mass_tol ) { $valid = 0; } 
#  
#  my $mass = $self->charge()*$self->getPeak( 'number', 1)->moz();
#  if( $valid )
#    {  
#    my $ratio2_1 = $self->getPeak( 'number', 2)->intensity()/
#                   $self->getPeak( 'number', 1)->intensity();
#    if( $ratio2_1 > ($mass/1000) ) { $valid = 0; }
#    } 
#    
#  if( $valid )
#    {  
#    my $ratio3_1 = $self->getPeak( 'number', 3)->intensity()/
#                   $self->getPeak( 'number', 1)->intensity();
#    if( $ratio3_1 > ($mass/2000) ) { $valid = 0; }
#    }   
#  
#  if( $valid )
#    {  
#    my $ratio3_2 = $self->getPeak( 'number', 3)->intensity()/
#                  $self->getPeak( 'number', 2)->intensity();
#    if( $ratio3_2 > ($mass/1500) ) { $valid = 0; }
#    }            
#  } 
#else { $valid = 0; }  

return $valid;
}

1;
