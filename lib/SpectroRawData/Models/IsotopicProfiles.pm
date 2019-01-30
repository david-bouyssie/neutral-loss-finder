package SpectroRawData::Models::IsotopicProfiles;

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
# Method: removeInvalid()
#
sub removeInvalid
{
my $self = shift;

my $profileNumber=1;
while( my $profile = $self->getIsotopicProfile('next') )
  {
  if( $profile->isValid ) { $profileNumber++; }
  else { $self->deleteIsotopicProfile($profileNumber); }
  }
 
}

##############################################################################
# Method: addIsotopicProfile()
#
sub addIsotopicProfile { $_[0]->_addElement($_[1],'isotopicProfiles','isotopicProfile'); }

##############################################################################
# Method: deleteIsotopicProfile()
#
sub deleteIsotopicProfile { $_[0]->_deleteElement('isotopicProfiles','isotopicProfile',$_[1]); }

##############################################################################
# Method: getIsotopicProfile()
#
sub getIsotopicProfile
{
my( $self, $query, $value) = @_;

if( $query ne 'number' and $query ne 'next' and $query ne 'scan' )
  { $self->throwError("can't use $query as a query method"); return; }

return $self->_getElement($query,$value,'isotopicProfiles','isotopicProfile','SpectroRawData::Models::IsotopicProfile');
}

##############################################################################
# Method: getNumOfIsotopicProfiles()
#
sub getNumOfIsotopicProfiles { return $_[0]->_getNumOfElements('isotopicProfiles','isotopicProfile'); }

##############################################################################
# Method: getElutionProfile()
#
sub getElutionProfile
{
my( $self, $scanSelection ) = @_;
$scanSelection = defined $scanSelection ? $scanSelection : [];

my $numOfProfiles = $self->getNumOfIsotopicProfiles;
return undef if not $numOfProfiles;

require SpectroRawData::Models::ElutionProfile;
my $elutionProfile = new SpectroRawData::Models::ElutionProfile();
my( @dataPoints, $minPos, $maxPos );
my $pos = 0;

foreach my $profileNum (1..$numOfProfiles)
  {
  my $isotopicProfile = $self->getIsotopicProfile('number', $profileNum);
  my $scanRef = $isotopicProfile->scanRef;
  my $retTime = $isotopicProfile->retentionTime;
  #  if( !defined $scanSelection or ($scanRef >= $scanSelection->[0] and $scanRef <= $scanSelection->[1]) )

  my $xValue = $retTime || $scanRef;
  my $intensity = $isotopicProfile->intensity;
  push( @dataPoints, [$xValue, $intensity]);
  
  $minPos = $pos if !defined $minPos and $scanRef >= $scanSelection->[0];
  $maxPos = $pos if $scanRef <= $scanSelection->[1];
    
  $pos++;
  }

my $selection = [$minPos, $maxPos] if defined $minPos and defined $maxPos and $maxPos >= $minPos;

### Set elution profile data points and compute properties
$elutionProfile->dataPoints( \@dataPoints );
$elutionProfile->computeProperties( $selection );
### Set retention time
my $ipAtApex = $self->getIsotopicProfile('number', $elutionProfile->apexPos + 1);
$elutionProfile->retentionTime( $ipAtApex->retentionTime );
$elutionProfile->maxIntensityScan( $ipAtApex->scanRef );

return $elutionProfile;
}

##############################################################################
# Method: getSelection()
#
sub getSelection
{
my( $self, $scanSelection ) = @_;
croak "getSelection: undefined scan selection" if !defined $scanSelection;

my $numOfProfiles = $self->getNumOfIsotopicProfiles;
return undef if not $numOfProfiles;

my( $minPos, $maxPos );
my $pos = 0;

foreach my $profileNum (1..$numOfProfiles)
  {
  my $isotopicProfile = $self->getIsotopicProfile('number', $profileNum);
  my $scanRef = $isotopicProfile->scanRef;

  $minPos = $pos if !defined $minPos and $scanRef >= $scanSelection->[0];
  $maxPos = $pos if $scanRef <= $scanSelection->[1];

  $pos++;
  }

my $selection = [$minPos, $maxPos] if defined $minPos and defined $maxPos and $maxPos >= $minPos;

return $selection;
}

##############################################################################
# Method: getScanWindow()
#
sub getScanWindow
{
my( $self ) = @_;
my $numOfProfiles = $self->getNumOfIsotopicProfiles;
return undef if not $numOfProfiles;

my( $minScan, $maxScan );
$minScan = $self->getIsotopicProfile('number', 1)->scanRef;
$maxScan = $self->getIsotopicProfile('number', $numOfProfiles)->scanRef;

my $scanWindow = [$minScan, $maxScan] if defined $minScan and defined $maxScan;

return $scanWindow;
}

###############################################################################
## Method: findPartners()
##
#sub findPartners
#{
#my $self = shift;
#my @delta = @{shift()};
#my $mass_tol = shift;
#my $nb_partners = scalar(@delta)+1;
#require SpectroRawData::Models::Partners;
#require SpectroRawData::Models::IsotopicProfiles;
#my $partners = new SpectroRawData::Models::Partners;
#use Data::Dumper;

#my $nb_dists= $self->getNumOfProfiles()-1;
#for( my $dist_num=1;$dist_num <= $nb_dists; $dist_num++ )
#  {
#  my( @distrib_list, @mass_list );
#  $distrib_list[0]= $self->getProfile( 'distribution_num', $dist_num);
#  my $mono_peak_num = $distrib_list[0]->monoIsotopicPeakNum();
#  my $charge = $distrib_list[0]->charge();
#  $mass_list[0] = $distrib_list[0]->getPeak( 'peak_num', $mono_peak_num )->moz();
#  $mass_list[1] = $mass_list[0]+($delta[0])/$charge;
#  $distrib_list[1]= $self->getProfile( 'nearest_moz', [$mass_list[1], $mass_tol] );
#  if( defined $distrib_list[1] )
#    {
#    if( $distrib_list[0]->charge() eq $distrib_list[1]->charge() )
#      {
#      my $distribs = new SpectroRawData::Models::IsotopicProfiles();
#      $distribs->addProfile( $distrib_list[0] );
#      $distribs->addProfile( $distrib_list[1] );
#      $partners->addPartner( $distribs );
#      }
#    }
#  }
#
#return $partners;
#}
#
#sub isEquivalent
#{
#my( $self, $a, $b, $tol ) = @_;
#my $equivalent =0;
#my $delta = abs($a - $b);

#if( $delta < $tol ) { $equivalent =1; }
#return $equivalent;
#}

###############################################################################
## Method: collapseSplittedProfiles()
##
#sub collapseSplittedProfiles
#{
#my $self = shift;

#require SpectroRawData::Models::IsotopicProfiles;
#require SpectroRawData::Models::IsotopicProfile;
#my $distribs = new SpectroRawData::Models::IsotopicProfiles();

#my $nb_dists= $self->getNumOfProfiles();
#my $is_splitted;
#for( my $dist_num=2;$dist_num <= $nb_dists; $dist_num++ )
#  {
#  my @distrib_list;
#  $distrib_list[0]= $self->getProfile( 'distribution_num', $dist_num-1);
#  $distrib_list[1]= $self->getProfile( 'distribution_num', $dist_num  );
#  if( ( $distrib_list[1]->getPeak( 'peak_num', 1)->moz() eq
#        $distrib_list[0]->getPeak( 'peak_num', 2)->moz()) and
#        ($distrib_list[1]->charge() eq $distrib_list[0]->charge() ) )
#    {
#    my $new_peak_num = $distrib_list[0]->getNumOfPeaks();
#    my $max_peak_num = $distrib_list[1]->getNumOfPeaks();
#    my $new_distrib = $distrib_list[0];
#    for(my $num=$new_peak_num;$num<=$max_peak_num;$num++)
#      { $new_distrib->addPeak( $distrib_list[1]->getPeak('peak_num' => $num )); }
#    if( $new_distrib->isValid() )
#      {
#      $distribs->addProfile( $distrib_list[0] );
#      $is_splitted =1;
#      $dist_num++;
#      }
#    else { $distribs->addProfile( $distrib_list[0] ); $is_splitted=0;}
#    }
#  else { $distribs->addProfile( $distrib_list[0] ); $is_splitted=0;}
#  }

#if( $is_splitted == 0 )
#  { $distribs->addProfile( $self->getProfile('distribution_num',$nb_dists ) ); }

#return $distribs;
#}

