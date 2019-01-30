package SpectroRawData::Models::Peaks;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/CommonPackage/;
use MIME::Base64;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#

#The following attributes are defined for the peaks element:
#- precision (required): the precision (in bits) of the binary floating point numbers encoded in the
#  element. This attribute can either have value 32 or 64.
#- byteOrder (required): the byte order for the binary floating point numbers must be network.
#- pairOrder (required): the order of the m/z - intensity pairs must be m/z-int.
sub precision { return $_[0]->_accessor('precision', $_[1]); }
sub byteOrder { return $_[0]->_accessor('byteOrder', $_[1]); }
sub pairOrder { return $_[0]->_accessor('pairOrder', $_[1]); }
sub base64Data { return $_[0]->_base64Accessor('base64Data', $_[1]); }
sub mozList { return $_[0]->_accessor('mozList', $_[1]); }
sub intensities { return $_[0]->_accessor('intensities', $_[1]); }
sub mozIndex { return $_[0]->_accessor('mozIndex', $_[1]); }
sub areCentroided { return $_[0]->_accessor('areCentroided', $_[1]); }

##############################################################################
# Method: loadArrays()
#
sub loadArrays
{
my( $self, $masses, $intensities, $mozIndex ) = @_;
my $nbMasses = scalar(@$masses);
my $nbIntensities = scalar(@$intensities);
return 0 if $nbMasses eq 0;

croak "loadArrays: undefined moz index !" if !defined $mozIndex;
croak "The m/z and intensity arrays have different sizes !" if( $nbMasses != $nbIntensities);

$self->mozList( $masses );
$self->intensities( $intensities );
$self->mozIndex( $mozIndex ); #index m/z values with the corresponding peak number (1..n)

return 1;
}

##############################################################################
# Method: base64Conversion()
#
sub base64Conversion
{
my( $self ) = @_;
my $masses = $self->mozList;
my $intensities = $self->intensities;
my $nbMasses = scalar(@$masses);
my @hostOrder32;

for(my $peakPos=0;$peakPos<$nbMasses;$peakPos++)
  {
  push( @hostOrder32, unpack("I", pack("f", $masses->[$peakPos] )) );
  push( @hostOrder32, unpack("I", pack("f", $intensities->[$peakPos])) );
  }

my $base64Data = pack("N*", @hostOrder32);
$self->base64Data( encode_base64($base64Data) );

delete $self->_content->{mozList};
delete $self->_content->{intensities};
delete $self->_content->{mozIndex};
}

##############################################################################
# Method: parseBase64Data()
#
sub parseBase64Data
{
my( $self ) = @_;
# "parsing not yet defined for <peaks precision!=32> tag (".($elPeaks->atts->{precision}).")" if $elPeaks->atts->{precision} ne 32;
my $base64Data = $self->base64Data;
my @hostOrder32 = unpack("N*", decode_base64($base64Data) );
my( @mozList, @intensities, $mozIndex );

# The hostOrder32 array contains a list of
# host ordered 32 bits entities which we want to re-interpret
# as floats. In Perl this means we have to
# pack it back as an int and then unpack it as a float
# This would all have been simpler if only Perl
# had had a network/host order option on unpack float
# But we don't so alas we do the ordering operation
# in the first unpack (N*) and then do the conversion
# to float in the second

### to clearly distinguish m/z from intensity:
my $peakNum = 1;
while( @hostOrder32 > 0 )
  {
  my $moz = unpack("f", pack("I", shift(@hostOrder32)));
  $moz = sprintf("%0.6f",$moz);
  my $intMoz= int($moz);
  $mozIndex->{$intMoz} = $peakNum if !defined $mozIndex->{$intMoz};
  push(@mozList, $moz);
  push(@intensities, unpack("f", pack("I", shift(@hostOrder32))) );
  $peakNum++;
  }

$self->loadArrays(\@mozList, \@intensities, $mozIndex );
}
  
##############################################################################
# Method: peakList()
#
sub peakList
{
my( $self, $peakList ) = @_;

if( ref( $peakList ) eq 'SpectroRawData::Models::PeakList' )
  {
  my( @mozList, @intensities, $mozIndex );
  my $peakNum = 1;

  while( my $peak = $peakList->getPeak('next') )
    {
    my $intMoz= int($peak->moz);
    $mozIndex->{$intMoz} = $peakNum if !defined $mozIndex->{$intMoz};
    push(@mozList, $peak->moz );
    push(@intensities, $peak->intensity );
    $peakNum++;
    }
  
  $self->loadArrays(\@mozList, \@intensities, $mozIndex );
  }
else
  {
  require SpectroRawData::Models::PeakList;
  require SpectroRawData::Models::Peak;
  
  $peakList = new SpectroRawData::Models::PeakList();
  
  my $mozList = $self->mozList;
  my $intensities = $self->intensities;
  my $maxPos = scalar(@$mozList)-1;

  foreach my $pos (0..$maxPos)
    {
    my $peak = new SpectroRawData::Models::Peak();
    $peak->moz( $mozList->[$pos] );
    $peak->intensity( $intensities->[$pos] );
    $peakList->addPeak($peak);
    }
  }

return $peakList;
}


##############################################################################
# Method: spectrum()
#
sub spectrum
{
my( $self, $peakList ) = @_;

if( ref( $peakList ) eq 'SpectroRawData::Models::Spectrum' )
  {
  my( @mozList, @intensities, $mozIndex );
  my $peakNum = 1;

  while( my $peak = $peakList->getPeak('next') )
    {
    my $intMoz= int($peak->moz);
    $mozIndex->{$intMoz} = $peakNum if !defined $mozIndex->{$intMoz};
    push(@mozList, $peak->moz );
    push(@intensities, $peak->intensity );
    $peakNum++;
    }

  $self->loadArrays(\@mozList, \@intensities, $mozIndex );
  }
else
  {
  require SpectroRawData::Models::Spectrum;
  require SpectroRawData::Models::Peak;

  $peakList = new SpectroRawData::Models::Spectrum();

  my $mozList = $self->mozList;
  my $intensities = $self->intensities;
  my $maxPos = scalar(@$mozList)-1;

  foreach my $pos (0..$maxPos)
    {
    my $peak = new SpectroRawData::Models::Peak();
    $peak->moz( $mozList->[$pos] );
    $peak->intensity( $intensities->[$pos] );
    $peakList->addPeak($peak);
    }
  }

return $peakList;
}


##############################################################################
#                         PEAK PROCESSING
#

##############################################################################
# Method: extractIsotopicProfile()
#
sub extractIsotopicProfile
{
my( $self, $charge, $moz, $mozTol, $maxNbPeaks ) = @_;
$self->parseBase64Data if !defined $self->mozList;
$maxNbPeaks = defined $maxNbPeaks ? $maxNbPeaks : 3;

my( @mozRanges, @requestedMoz );
foreach my $value (-1..$maxNbPeaks-1)
  {
  # the 1.0025 shift has been computed from statistics of the delta mass
  # (Horn at al. 2000)
  my $shift = $value <= 0 ? 1 : 1.0025; 
  my $tmpMoz = $moz + $shift*$value/$charge;
  push(@requestedMoz, $tmpMoz );
  push(@mozRanges, { min => $tmpMoz-$mozTol, max => $tmpMoz+$mozTol } );
  }
  
my $retVal = $self->getPeaksInMozRanges(\@mozRanges);
my( $tmpPeaks, $filledMozRanges ) = @$retVal if defined $retVal;

if( defined $filledMozRanges )
  {
  require 'CommonSubs.pl';
  my $monoPos = arrayPos($filledMozRanges, 2 ); #search if the second moz range (MIP) has been found

  if( defined $monoPos )
    {
    if( $self->areCentroided ) { $tmpPeaks->keepNearestPeaks( \@requestedMoz, $mozTol ); }
    else { $tmpPeaks->keepOnlyMaxima( $mozTol ); }
    
    my $tmpSpectrum = $tmpPeaks->spectrum; #convert peak array to a peakList object
    require SpectroRawData::Models::Spectrum;
    my $spectrum = new SpectroRawData::Models::Spectrum();
    
    ### If there is at least two peaks ( mono + one )
    if(scalar(@$filledMozRanges) - $monoPos >= 2 )
      {
      #remove non consecutive peaks
      my $prevFilledMozRange = $filledMozRanges->[0]-1;
      my $peakNum = 1;

      foreach my $filledMozRange (@$filledMozRanges)
        {
        if( $filledMozRange - $prevFilledMozRange > 1 ) { last; }
        else
          {
          my $tmpPeak = $tmpSpectrum->getPeak('number', $peakNum);
          last if !defined $tmpPeak;
          $spectrum->addPeak( $tmpPeak );
          }
        $prevFilledMozRange = $filledMozRange;
        $peakNum++;
        }
      }
    else { $spectrum = $tmpSpectrum; }
    
    if(defined $spectrum->getNumOfPeaks )
      {
      require SpectroRawData::Models::IsotopicProfile;
      my $isotopicProfile = new SpectroRawData::Models::IsotopicProfile;
      $isotopicProfile->_content( $spectrum->_content );
      $isotopicProfile->monoIsotopicPeakNumber( $monoPos+1 ); #set the MIP number

      return $isotopicProfile if $isotopicProfile->isValid( $charge );
      }
    }
  }
        
return;
}



##############################################################################
# Method: getNearestPeak()
#
sub getNearestPeak
{
my( $self, @params ) = @_;
my $peakPos = $self->_getNearestPeakPos( @params );
return if !defined $peakPos;

my $mozList = $self->mozList;
my $intensities = $self->intensities;

require SpectroRawData::Models::Peak;
my $peak = new SpectroRawData::Models::Peak;
$peak->moz($mozList->[$peakPos]);
$peak->intensity($intensities->[$peakPos]);

return $peak;
}

##############################################################################
# Method: _getNearestIndexValue()
#
sub _getNearestIndexValue
{
my( $self, $moz ) = @_;
my $mozIndex = $self->mozIndex;
if(!defined $mozIndex ) { $self->throwError('You have to build the moz list index first !'); return; }
my $intMoz = int($moz);
my $indexValue = $mozIndex->{$intMoz};
if(!defined $indexValue )
  {
  my $curDelta;
  my @intMozList = keys(%{$mozIndex});
  @intMozList = sort { $a <=> $b } @intMozList;
  
  foreach my $curIntMoz (@intMozList)
    {
    my $delta = abs( $curIntMoz - $intMoz );
    if( !defined $curDelta or ($delta < $curDelta and $curIntMoz < $intMoz) )
      {	$indexValue = $mozIndex->{$curIntMoz}; $curDelta = $delta;	}
    else { last; }
    }
  }

return $indexValue;
}

##############################################################################
# Method: _getNearestPeakPos()
#
sub _getNearestPeakPos
{
my( $self, $moz, $mozTol, $startingPoint ) = @_;
my $mozList = $self->mozList;
my $nearestPeakPos;
my $curDelta = $mozTol;

### TESTS ###
my $numOfPeaks = scalar(@$mozList);
if( $numOfPeaks == 0 ) { $self->throwError('Empty peaklist !'); return; }

if(!defined $startingPoint ) { $startingPoint = $self->_getNearestIndexValue($moz)-1; }
my $peakPos = $startingPoint;
if( $startingPoint >= $numOfPeaks ) { $peakPos = $numOfPeaks-1; }

### PROCESSING ###
my $startingMoz = $mozList->[$peakPos];
my $startingDelta = $moz - $startingMoz;

my $nearestFound;
do{
  if( $startingDelta == 0 ) { $nearestPeakPos = $peakPos; $nearestFound = 1; }
  elsif( $peakPos >= $numOfPeaks ) { $nearestFound = 1; } #TODO : throwError
  else
    {
    my $currrentMoz = $mozList->[$peakPos];
    my $delta = abs( $currrentMoz - $moz );
  	if( $delta <= $mozTol and $delta <= $curDelta ) {	$nearestPeakPos = $peakPos; $curDelta = $delta;	}
    if( $curDelta == 0) { $nearestFound = 1; }
    
    if( $startingDelta > 0 )
      { if( $currrentMoz > $moz + $mozTol ) { $nearestFound = 1; } $peakPos++; }
    else { if( $currrentMoz < $moz - $mozTol ) { $nearestFound = 1; } $peakPos--;  }
		}
  }until( $nearestFound );

return $nearestPeakPos;
}


##############################################################################
# Method: keepNearestPeaks()
#
sub keepNearestPeaks
{
my( $self, $requestedMozList, $mozTol ) = @_;
my $mozList = $self->mozList;
my $intensities = $self->intensities;
my(@newMozList, @newIntensities, $newMozIndex);
$newMozIndex = {};

my $peakNum = 1;
foreach my $moz (@$requestedMozList)
  {
  my $peakPos = $self->_getNearestPeakPos( $moz, $mozTol );
  if(defined $peakPos )
    {
    my $curMoz = $mozList->[$peakPos]; my $intMoz= int($curMoz);
    #print $curMoz ."\n";
    $newMozIndex->{$intMoz} = $peakNum if !defined $newMozIndex->{$intMoz};
    push(@newMozList, $curMoz );
    push(@newIntensities, $intensities->[$peakPos] );
    $peakNum++;
    }
  }

$self->loadArrays(\@newMozList, \@newIntensities, $newMozIndex );

return 1;
}

##############################################################################
# Method: keepOnlyMaxima()
#
sub keepOnlyMaxima
{
my( $self, $mozTol ) = @_;
$self->parseBase64Data if !defined $self->mozList;
$mozTol = 0.03 if !defined $mozTol;

my(@tmpMozList, @tmpIntensities, @newMozList, @newIntensities, $newMozIndex);
my $mozList = $self->mozList;
my $intensities = $self->intensities;
$newMozIndex = {};
#add artificial outlier (needed by the algorithm)
push( @$mozList, $mozList->[-1]+2*$mozTol );
push( @$intensities, 0 );
#we add the first peak to the peak array
push( @tmpMozList, $mozList->[0] );
push( @tmpIntensities, $intensities->[0] );

my $maxPos = scalar(@$mozList)-1;
my $peakNum = 1;

for(my $pos=1;$pos<=$maxPos;$pos++) # keep this to 1 !!!
  {
  #collect some close m/z
  push( @tmpMozList, $mozList->[$pos] );
  push( @tmpIntensities, $intensities->[$pos] );
  
  #if the moz are no longer close (according the moz tolerance)
  if( not $self->isEquivalent( $tmpMozList[-2], $tmpMozList[-1], $mozTol ) ) 
    {
    #no more close m/z: remove the last added intensity
    pop(@tmpIntensities) if $pos != $maxPos;
    #research the most intense value
    my $maxValuePos = $self->_getMaxValuePos( \@tmpIntensities );
    #add the value to the arrays
    my $curMoz = $tmpMozList[$maxValuePos]; my $intMoz= int($curMoz);
    $newMozIndex->{$intMoz} = $peakNum if !defined $newMozIndex->{$intMoz};
    push(@newMozList, $tmpMozList[$maxValuePos]);
    push(@newIntensities, $tmpIntensities[$maxValuePos]);
    $peakNum++;

    #restart the process with a new starting point
    @tmpMozList=(); @tmpIntensities=();
    push( @tmpMozList, $mozList->[$pos] );
    push( @tmpIntensities, $intensities->[$pos] );
    }
  }

$self->loadArrays(\@newMozList, \@newIntensities, $newMozIndex );


return 1;
}


##############################################################################
# Method: removePeaksUnderInt()
#
sub removePeaksUnderInt
{
my( $self, $intThreshold ) = @_;
$self->parseBase64Data if !defined $self->mozList;

my $mozList = $self->mozList;
my $intensities = $self->intensities;
my(@newMozList, @newIntensities, $newMozIndex);
$newMozIndex = {};

my $maxPos = scalar(@$intensities)-1;
my $peakNum = 1;
foreach my $pos (0..$maxPos)
  {
  my $curIntensity = $intensities->[$pos];
  if( $curIntensity >= $intThreshold )
    {
    my $curMoz = $mozList->[$pos]; my $intMoz= int($curMoz);
    $newMozIndex->{$intMoz} = $peakNum if !defined $newMozIndex->{$intMoz};
    push(@newMozList, $curMoz );
    push(@newIntensities, $curIntensity );
    $peakNum++;
    }
  }

$self->loadArrays(\@newMozList, \@newIntensities, $newMozIndex );

return 1;
}

##############################################################################
# Method: getPeaksInMozRanges()
#
sub getPeaksInMozRanges
{
my( $self, $mozRanges ) = @_;
$self->parseBase64Data if !defined $self->mozList;

my $mozList = $self->mozList; return if !defined $mozList;
my $intensities = $self->intensities;
my(@newMozList, @newIntensities, $newMozIndex, @filledMozRanges);
$newMozIndex = {};

my $maxPos = scalar(@$mozList)-1;
my $peakNum = 1; my $mozRangeNum =1;
foreach my $mozRange (@$mozRanges)
  {
  my $minPos = $self->_getNearestIndexValue($mozRange->{min} )-1;#peak number - 1
  my $isMozRangeFilled;
  
  foreach my $pos ($minPos..$maxPos)
    {
    my $curMoz = $mozList->[$pos];

    if( $curMoz > $mozRange->{max} ) { last; }
    elsif( $curMoz > $mozRange->{min} )
      {
      my $intMoz= int($curMoz);
      $newMozIndex->{$intMoz} = $peakNum if !defined $newMozIndex->{$intMoz};
      push(@newMozList, $curMoz );
      push(@newIntensities, $intensities->[$pos] );
      $isMozRangeFilled=1;
      $peakNum++;
      }
    }
  push(@filledMozRanges, $mozRangeNum ) if $isMozRangeFilled;
  $mozRangeNum++;
  }

my $newPeaks = new SpectroRawData::Models::Peaks();
$newPeaks->loadArrays(\@newMozList, \@newIntensities, $newMozIndex );

if( scalar(@filledMozRanges)> 0 ) { return [$newPeaks,\@filledMozRanges]; }
else { return; }
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
return 0 if $nb_val eq 1;

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
# Method: isEquivalent()
#
sub isEquivalent
{
my( $self, $a, $b, $tol ) = @_;
my $equivalent =0;
my $delta = abs($a - $b);
# '<=' doesn't work => why ?
if( $delta < $tol or $delta eq $tol ) { $equivalent =1; }
return $equivalent;
}

