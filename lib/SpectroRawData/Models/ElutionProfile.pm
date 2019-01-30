package SpectroRawData::Models::ElutionProfile;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SpectroRawData::Models::Chromatogram/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub isotopicProfiles { return $_[0]->_objectAccessor('isotopicProfiles', $_[1], 'SpectroRawData::Models::IsotopicProfiles'); } ### TODO: remove
sub intensityMax { return $_[0]->_accessor('intMax', $_[1]); } ### TODO : remove
sub scanWindow { return $_[0]->_arrayAccessor('scanWindow', $_[1]); } ### TODO : remove
sub retentionTime { return $_[0]->_accessor('retTime', $_[1]); }
sub maxIntensityScan { return $_[0]->_accessor('maxIntScan', $_[1]); }

###############################################################################
## Method: computeProperties()
##
#sub computeProperties
#{
#my( $self, $scanSelection ) = @_;
#$scanSelection = defined $scanSelection ? $scanSelection : $self->scanWindow;
#my $isotopicProfiles = $self->isotopicProfiles;

#my( $area, $intensitySum, $intensityMax, $bestScan, $bestRetTime, $prevRetTime, $prevIntensity );
#while( my $isotopicProfile = $isotopicProfiles->getIsotopicProfile('next') )
#  {
#  my $scanRef = $isotopicProfile->scanRef;
#  if( $scanRef >= $scanSelection->[0] and $scanRef <= $scanSelection->[1] )
#    {
#    my $retTime = $isotopicProfile->retentionTime;
#    my $intensity = $isotopicProfile->intensity;
#    $intensitySum += $intensity;
#    
#    if( $intensity > $intensityMax )
#      {
#      $intensityMax = $intensity;
#      $bestScan = $scanRef;
#      $bestRetTime = $retTime;
#      }
#    
#    if( defined $prevRetTime )
#      {
#      my $deltaTime = $retTime-$prevRetTime;
#      $area += ($intensity + $prevIntensity ) * $deltaTime / 2;
#      }
#      
#    $prevRetTime = $retTime;
#    $prevIntensity = $intensity;
#    }
#  }

#$area = $intensitySum if $intensitySum > $area; # i.e. only one point in the profile
#$self->area( $area );
#$self->intensitySum( $intensitySum );
#$self->intensityMax( $intensityMax );
#$self->maxIntensityScan( $bestScan );
#$self->retentionTime( $bestRetTime );

#return 1;
#}


1;



