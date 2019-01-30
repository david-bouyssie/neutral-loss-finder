package SpectroRawData::Controllers::IsotopicLookupTable;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/CommonPackage/;

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = $class->SUPER::new();
bless($self, $class);

return($self);
}

##############################################################################
# Object accessors
#
sub table
{
my( $self, $table )= @_;
if( defined $table and ref($table) eq 'HASH' )
  {
  my @masses = sort { $a <=> $b } keys(%$table);
  $self->{masses} = \@masses;
  }
return $_[0]->_accessor('table', $_[1]);
}

##############################################################################
# Method: loadFromFile()
#
sub loadFromFile
{
my( $self, $file ) = @_;

my $lookupTable;
open(FILE, $file ) or die "can't read $file: $!";
while( my $row = <FILE> )
  {
  my @cols = split("\t", $row );
  my $mass = shift(@cols);
  $lookupTable->{$mass} = \@cols;
  }
close FILE;

$self->table( $lookupTable );

return;
}

###############################################################################
## Method: saveToFile()
##
#sub writeFile
#{
#my( $self, $msmsSpectra, $file ) = @_;
#my $parser = $self->_loadParser( $file );

#if( defined $parser )
#  { $parser->writeFile( $msmsSpectra, $file ); return 1; }
#  
#return;
#}

##############################################################################
# Method: getIsotopicAbundances()
#
sub getIsotopicAbundances
{
my( $self, $mass ) = @_;
my $lookupTable = $self->table;
croak "getIsotopicAbundances: undefined lookup table" if !defined $lookupTable;

### Compute mass limits around the provided mass
my @massBounds;
my $tmpPos =0;
foreach my $tmpMass (@{$self->{masses}})
  {
  if( $tmpPos > 0 and $tmpMass >= $mass )
    {
    @massBounds = ($tmpMass, $self->{masses}->[$tmpPos-1]);
    last;
    }
  $tmpPos++;
  }
croak "getIsotopicAbundances: the mass '$mass' is too big to be used" if scalar(@massBounds) eq 0;
#use Data::Dumper;
#print Dumper( \@massBounds );

### Retrieve abundances for each mass bound
my @ab1 = @{ $lookupTable->{$massBounds[0]} };
my @ab2 = @{ $lookupTable->{$massBounds[1]} };

### Compute a linear interpolation for each paired abundance
my( @abMeans, $maxAbMean );

my $numOfAbundances = scalar(@ab2);
foreach my $abPos (0..$numOfAbundances-1)
  {
  my $a1 = $ab1[$abPos] || 0;
  my $a2 = $ab2[$abPos];
  
  my $eqParams = equation($massBounds[0], $a1, $massBounds[1], $a2);
  my $meanAb = $eqParams->[0] * $mass + $eqParams->[1];
  push( @abMeans, $meanAb );
  $maxAbMean = $meanAb if $meanAb > $maxAbMean;
  }

### Normalize mean abundances
@abMeans = map { 100*$_/$maxAbMean } @abMeans;

return \@abMeans;
}


##############################################################################
# Method: fitAbundances()
#
sub fitAbundances
{
my( $self, $mass, $abundances ) = @_;
my $theoAbundances = $self->getIsotopicAbundances($mass);

my $maxAb;
foreach my $abundance (@$abundances) { $maxAb = $abundance if $abundance > $maxAb; }

my @normAbundances = map { 100*$_/$maxAb } @$abundances;

### Resize abundance arrays to obtain the same size
my @theoAbResized = splice(@$theoAbundances,0, scalar(@normAbundances) );
@normAbundances = splice(@normAbundances,0, scalar(@theoAbResized) );

### Compute normalized RMSD value
my $nrmsd = rmsd( \@theoAbResized, \@normAbundances )/100;

return $nrmsd;
}

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
# Function: rmsd()
#
sub rmsd
{
my( $array1, $array2 ) = @_;
croak "rmsd: two arrays must be provided" if !defined $array1 or !defined $array2;
use Data::Dumper;
print Dumper(@$array1).Dumper(@$array2) if scalar(@$array1) ne scalar(@$array2);
croak "rmsd: the two arrays must have the same size" if scalar(@$array1) ne scalar(@$array2);

### Compute the number of values to use
my $numOfVal1 = scalar(@$array1);
my $numOfVal2 = scalar(@$array2);
my $numOfValues = $numOfVal2 > $numOfVal1 ? $numOfVal2 : $numOfVal1;

### Compute root mean square deviation
my( $sumD2, @xRange );
foreach my $valPos (0..$numOfValues-1)
  {
  my $val1 = $array1->[$valPos];
  my $val2 = $array2->[$valPos];
  my $delta2 = ($val2 - $val1)**2;
  $sumD2 += $delta2;
  }



return sqrt( $sumD2/$numOfValues);
}

1;

