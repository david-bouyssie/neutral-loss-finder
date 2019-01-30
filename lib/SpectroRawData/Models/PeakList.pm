package SpectroRawData::Models::PeakList;

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
# Method: addPeak()
#
sub addPeak { $_[0]->_addElement($_[1],'peaks','peak'); }

##############################################################################
# Method: deletePeak()
#
sub deletePeak { $_[0]->_deleteElement('peaks','peak',$_[1]); }

##############################################################################
# Method: getPeak()
#
sub getPeak
{
my( $self, $query, $value) = @_;

if( $query ne 'number' and $query ne 'next' )
  { $self->throwError("can't use $query as a query method"); return; }

return $self->_getElement($query,$value,'peaks','peak','SpectroRawData::Models::Peak');
}

##############################################################################
# Method: getNumOfPeaks()
#
sub getNumOfPeaks { return $_[0]->_getNumOfElements('peaks','peak'); }


##############################################################################
# Method: getNearestPeak()
#
sub getNearestPeak
{
my( $self, $moz, $mozTol, $startingPoint ) = @_;

my $numOfPeaks = $self->getNumOfPeaks;
if( $numOfPeaks < 1 ) { return undef; }

my $nearestPeak;
my $curDelta = $mozTol;

if( defined $startingPoint )
  {
  my $peakNum = $startingPoint;
  if( $startingPoint >= $numOfPeaks ) { $peakNum = $numOfPeaks-1; }
  my $peak = $self->getPeak('number',$peakNum);
  #$nearestPeak = $peak;
  my $startingDelta = $moz - $peak->moz;
 # print "delta start : " . $startingDelta ."\n";

  my $nearestFound;
  do{
    my $peak = $self->getPeak('number',$peakNum);
    if( $startingDelta == 0 ) { $nearestPeak = $peak; $nearestFound = 1; }
    elsif( !defined $peak ) { $nearestFound = 1; }#print "bug ?\n"; }
    else
      {
      my $delta = abs( $peak->moz - $moz );
    	if( $delta <= $mozTol and $delta <= $curDelta ) {	$nearestPeak = $peak; $curDelta = $delta;	}
      if( $curDelta == 0) { $nearestFound = 1; }
      
      if( $startingDelta > 0 )
        { if( $peak->moz > $moz + $mozTol ) { $nearestFound = 1; } $peakNum++; }
      else { if( $peak->moz < $moz - $mozTol ) { $nearestFound = 1; } $peakNum--;  }
  		}
    }until( $nearestFound );

  #print "nearest peak : " . $moz . ' '. $nearestPeak->moz."\n";
  }
else
  {
  for( my $peakNum=1;$peakNum<=$numOfPeaks;$peakNum++ )
    {
    my $peak = $self->getPeak('number',$peakNum);
    if( $peak->moz > $moz + $mozTol ) { last; }
    my $delta = abs( $peak->moz - $moz );
  	if( $delta <= $mozTol and $delta <= $curDelta ) {	$nearestPeak = $peak; $curDelta = $delta;	}
    if( $curDelta == 0) { last; }
    }
  }
  
return $nearestPeak;
}

##############################################################################
# Method: getIntensityList()
#
sub getIntensityList
{
my $self = shift;
my @intensities;

while( my $peak = $self->getPeak( 'next' ) )
  { push(@intensities, $peak->intensity() ); }

return \@intensities;
}

##############################################################################
# Method: getIntSortedMozList()
#
sub getIntSortedMozList
{
my $self = shift;

}

##############################################################################
# Method: getIntensitySum()
#
sub getIntensitySum
{
my $self = shift;
my $sum;

while( my $peak = $self->getPeak('next' ) )
  { $sum += $peak->intensity; }

return $sum;
}

##############################################################################
# Method: setMozRange()
#
sub setMozRange
{
my( $self, $minMoz, $maxMoz ) = @_;

my $tmpPeakList = new SpectroRawData::Models::PeakList;
my $nbPeaks = $self->getNumOfPeaks();
foreach my $peakNum (1..$nbPeaks)
  {
  my $peak = $self->getPeak('number',$peakNum);
  if( $peak->moz > $minMoz and $peak->moz < $maxMoz ) { $tmpPeakList->addPeak($peak); }
  }

$self->_content( $tmpPeakList->_content );

return 1;
}

##############################################################################
# Method: setMozRanges()
#
sub setMozRanges
{
my( $self, $mozRanges ) = @_;

my $tmpPeakList = new SpectroRawData::Models::PeakList;
my $nbPeaks = $self->getNumOfPeaks();
foreach my $peakNum (1..$nbPeaks)
  {
  my $peak = $self->getPeak('number',$peakNum);
  foreach my $mozRange (@$mozRanges)
    { if( $peak->moz > $mozRange->{min} and $peak->moz < $mozRange->{max} ) { $tmpPeakList->addPeak($peak); } }
  }

$self->_content( $tmpPeakList->_content );

return 1;
}


##############################################################################
#                         SIGNAL PROCESSING
#

##############################################################################
# Method: keepNearestPeaks()
#
sub keepNearestPeaks
{
my( $self, $mozList, $mozTol ) = @_;
my $tmpPeakList = new SpectroRawData::Models::PeakList;
$tmpPeakList->_content({});

foreach my $moz (@$mozList)
  { $tmpPeakList->addPeak( $self->getNearestPeak( $moz, $mozTol ) ); }
  
$self->_content( $tmpPeakList->_content );

return 1;
}

##############################################################################
# Method: keepOnlyMaxima()
#
sub keepOnlyMaxima
{
my $self = shift;
my $delta_tol = 0.03;

my $tmpPeakList = new SpectroRawData::Models::PeakList;
$tmpPeakList->_content({});
my $nbPeaks = $self->getNumOfPeaks();

if(defined $nbPeaks )
  {
  #we add the first peak to the peak array
  my @peaks;
  push( @peaks, $self->getPeak( 'number', 1) );
  
  foreach my $peakNum (2..$nbPeaks)
    {
    #collect some peaks with close moz
    push( @peaks, $self->getPeak( 'number', $peakNum) );
    
    #if the moz are no longer close (according the moz tolerance)
    #or if we reach the peak list end
    if( ( not $self->isEquivalent( $peaks[-2]->moz(), $peaks[-1]->moz(), $delta_tol ) ) or
				$peakNum == $nbPeaks )
      {
      #print "no more close\n";
      my $lastPeak = scalar(@peaks)-2;
      my @intensities;
      foreach my $num (0..$lastPeak) { push( @intensities, $peaks[$num]->intensity() ); }
      #research the most intense peak
      my $maxPos = $self->_getMaxValuePos( \@intensities );
      $tmpPeakList->addPeak( $peaks[$maxPos] );
      #print $tmpPeakList->selfDumper;
      #restart the process with a new starting point
      undef @peaks;
      push( @peaks, $self->getPeak( 'number', $peakNum) );
      }
    }
  }

$self->_content( $tmpPeakList->_content );

return 1;
}

##############################################################################
# Method: _getMaxValuePos()
#
sub _getMaxValuePos
{
my( $self, $tab ) = @_;
my $pos;
my $max_val=0;
my $nb_val = scalar(@{$tab});

for( my $i=0; $i< $nb_val;$i++)
  {
  if($tab->[$i] > $max_val)
    {
    $max_val = $tab->[$i];
    $pos = $i;
    }
  }

return $pos;
}

##############################################################################
# Method: removePeaksUnderInt()
#
sub removePeaksUnderInt
{
my( $self, $intThreshold ) = @_;

my $tmpPeakList = new SpectroRawData::Models::PeakList;
$tmpPeakList->_content({});
my $nbPeaks = $self->getNumOfPeaks();
foreach my $peakNum (1..$nbPeaks)
  {
  my $peak = $self->getPeak('number',$peakNum);
  if( $peak->intensity >= $intThreshold ) { $tmpPeakList->addPeak($peak); }
  }
  
$self->_content( $tmpPeakList->_content );

return 1;
}


##############################################################################
# Method: isEquivalent()
#
sub isEquivalent
{
my( $self, $a, $b, $tol ) = @_;
my $equivalent =0;
my $delta = abs($a - $b);

if( $delta <= $tol ) { $equivalent =1; }
return $equivalent;
}


