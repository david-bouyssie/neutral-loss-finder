package SpectroRawData::Controllers::mzDB;
 
##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use DBI;
use base qw/CommonPackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = $class->SUPER::new();
bless($self, $class);
$self->{arguments} = shift;

my $dbPath = $self->{arguments}->{filePath};
if( not defined $dbPath ) { croak 'Missing argument: filePath'; }
$self->dbPath( $dbPath );

### Open the mzDB
$self->dbh( $self->_openDB );

$self->{tableCols} = { scan => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5 },
                       peak => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5 },
                       isotopic_pattern => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5 },
                       feature => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5 },
                       compound => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5 },
                       ip_time => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 5, 'time' => 6 },
                       ion => { feature => 0, area => 1, firstScan => 2, lastScan => 3, moz => 4, charge => 5, intensity => 6, 'time' => 7 },
                     };

return($self);
}

##############################################################################
# Object destructor
#
sub DESTROY
{
my $self = shift;

### Close the database
$self->dbh->disconnect or warn $self->{dbh}->errstr;
}

##############################################################################
# Object accessors
#
sub dbPath { return $_[0]->_accessor('dbPath', $_[1]); }
sub dbh { return $_[0]->_accessor('dbh', $_[1]); }

##############################################################################
# Private method: _openDB()
#
sub _openDB
{
my( $self ) = @_;
my $dbPath = $self->dbPath;

### Create the DB if it not exists
$self->_createDB( $dbPath ) if not -f $dbPath;

### Open the database
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbPath","","", {RaiseError => 1, AutoCommit => 0} );

return $dbh;
}

##############################################################################
# Method: _createDB()
#
sub _createDB
{
my( $self ) = @_;

use File::Basename;
my $packageDir = dirname(__FILE__);
my $sqlFile = $packageDir.'/mzDB.sql';

use DBIx::SchemaCreator;
my $dbCreator = new DBIx::SchemaCreator();
$dbCreator->initDB( $self->dbPath , $sqlFile );

return 1;
}

##############################################################################
# Private method: _deleteDB()
#
sub _deleteDB
{
my( $self ) = @_;

### Close the connection to the current DB
$self->dbh->disconnect or warn $self->dbh->errstr;

my $dbPath = $self->dbPath;
if( -f $dbPath ) { unlink $dbPath or croak $!; }

return 1;
}

##############################################################################
# Method: getColPos()
#
sub getColPos
{
my( $self, $table, $field ) = @_;
my $tableCols = $self->{tableCols}->{$table};
croak "getColPos: undefined table name '$table'" if !defined $tableCols;
my $colPos = $self->{tableCols}->{$table}->{$field};
croak "getColPos: undefined field name '$field'" if !defined $colPos;
return $colPos;
}

##############################################################################
# Method: detectIsotopicPatterns()
#
sub detectIsotopicPatterns
{
my( $self ) = @_;



return 1;
}

##############################################################################
# Method: detectFeatures()
#
sub detectFeatures
{
my( $self, $params ) = @_;
my @paramKeys = ('mozTol', 'scanTol', 'minNumOfIP');
foreach my $paramKey (@paramKeys)
  { croak "detectFeatures: undefined parameter '$paramKey'" if !defined $params->{$paramKey}; }

use Data::Dumper;
require SpectroRawData::Models::Chromatogram;

### Create som vars
my( $mozTol, $mozTolUnit ) = @{$params->{mozTol}};
my $scanTol = $params->{scanTol};
my $minNumOfIP = $params->{minNumOfIP};

my $dbh = $self->dbh;
my $maxCharge = ($dbh->selectrow_array('SELECT max(charge) FROM isotopic_pattern'))[0];

### Delete compound and feature table rows
$dbh->do( 'DELETE FROM compound' );
$dbh->do( 'DELETE FROM feature' );
$dbh->do( 'UPDATE sqlite_sequence SET seq = 0 WHERE name = "compound"');
$dbh->do( 'UPDATE sqlite_sequence SET seq = 0 WHERE name = "feature"');

### Update views
$dbh->do( 'DROP VIEW IF EXISTS "ion"' );
$dbh->do( 'DROP VIEW IF EXISTS "ip_time"' );
$dbh->do('CREATE VIEW "ip_time" AS SELECT isotopic_pattern.*, time FROM isotopic_pattern, scan WHERE isotopic_pattern.scan = scan.id');

### Iterate on charge states
foreach my $charge (1..$maxCharge)
  {
  my $sth = $dbh->prepare( "SELECT * FROM ip_time WHERE charge = $charge ORDER BY moz" )
                  or die "Can't prepare statement: $DBI::errstr";
  $sth->execute or die "Can't execute statement: $DBI::errstr";

  ### Create a isotopic pattern buffer
  my @patterns = ( [$sth->fetchrow_array] );
  my $mozOfRef = $patterns[0]->[1];
  
  while( my @ipValues = $sth->fetchrow_array )
    {
    my $curMoz = $ipValues[1];
    my $deltaMoz = $curMoz - $mozOfRef;
    my $mozTolInDa = $self->getMassTolInDalton( $curMoz, $mozTol, $mozTolUnit );

    ### Accumulate isotopic patterns while delta mass < tolerance
    if( $deltaMoz <= $mozTolInDa ) { push( @patterns, \@ipValues ); }
    ### Detect features considering the time tolerance
    else
      {
      ### Sort patterns by retention time
      my @timeSortedPatterns = sort { $a->[-1] <=> $b->[-1] } @patterns;

      ### Clusterize isotopic patterns into features
      my $prevIsotopicPattern = shift(@timeSortedPatterns);
      my $features = [[$prevIsotopicPattern]];
      my $featurePos = 0;

      foreach my $isotopicPattern (@timeSortedPatterns)
        {
#        my $deltaTime = $isotopicPattern->[-1] - $prevIsotopicPattern->[-1];
        my $deltaScan = $isotopicPattern->[6] - $prevIsotopicPattern->[6];
        croak "detectFeatures: sorting bug => negative delta time" if $deltaScan < 0;
        $featurePos++ if $deltaScan > $scanTol;

        push( @{ $features->[$featurePos] }, $isotopicPattern );
        $prevIsotopicPattern = $isotopicPattern;
        }

      ### Insert features in the mzDB
      foreach my $feature (@$features)
        {
        ### Feature filtering according to the number of isotopic patterns
        next if scalar(@$feature) < $minNumOfIP;
        
        my $chromato = new SpectroRawData::Models::Chromatogram();
        my( @dataPoints, @ipIds );

        ### Build a chromatogram => [ time, intensity ]
        foreach my $isotopicPattern (@$feature)
          {
          push( @ipIds, $isotopicPattern->[0] );
          push( @dataPoints, [ $isotopicPattern->[-1], $isotopicPattern->[2] ] );
          }
        $chromato->dataPoints( \@dataPoints );
        $chromato->computeProperties;
        
        ### Retrieve area and apex
        my $area = $chromato->area;
        my $apex = $feature->[$chromato->apexPos]->[0];

        ### Retrieve feature scan limits
        my $firstScan = $feature->[0]->[6];
        my $lastScan = $feature->[-1]->[6];

        ### Insert the new feature
        my @featureValues = ( 'NULL', $area, $firstScan,$lastScan,$apex,'NULL');
        my $featureInsert = join(", ",@featureValues);
        $dbh->do( "INSERT INTO feature VALUES ($featureInsert)" );
        my $featureId = $dbh->func('last_insert_rowid');
        
        ### Update feature reference for the corresponding isotopic patterns
        foreach my $ipId (@ipIds) { $dbh->do("UPDATE isotopic_pattern SET feature = $featureId WHERE id = $ipId"); }
        }
        
      ### Reinit pattern buffer and moz of reference
      @patterns = ( \@ipValues );
      $mozOfRef = $curMoz;
      }
    }
  }

$dbh->do('CREATE VIEW "ion" AS SELECT feature, area, firstScan, lastScan, moz, charge, intensity, time
                               FROM feature, isotopic_pattern, scan
                               WHERE feature.apex = isotopic_pattern.id AND isotopic_pattern.scan = scan.id' );
$dbh->commit;

return 1;
}

##############################################################################
# Method: listCompounds()
#
sub listCompounds
{
my( $self, $params ) = @_;
my @paramKeys = ('massTol', 'timeTol');
foreach my $paramKey (@paramKeys)
  { croak "detectFeatures: undefined parameter '$paramKey'" if !defined $params->{$paramKey}; }

### Create som vars
my( $massTol, $massTolUnit ) = @{$params->{massTol}};
my $timeTol = $params->{timeTol};

my $dbh = $self->dbh;

### Delete compound and feature table rows
$dbh->do( 'DELETE FROM compound' );
$dbh->do( 'UPDATE sqlite_sequence SET seq = 0 WHERE name = "compound"');

#### DROP ion view
#$dbh->do( 'DROP VIEW IF EXISTS "ion"' );

### Iterate on features
my $sth = $dbh->prepare( "SELECT * FROM ion ORDER BY (moz*charge-charge*1.007)" )
                or die "Can't prepare statement: $DBI::errstr";
$sth->execute or die "Can't execute statement: $DBI::errstr";

my $mozColPos = $self->getColPos('ion','moz');
my $chargeColPos = $self->getColPos('ion','charge');
my $timeColPos = $self->getColPos('ion','time');
my $areaColPos = $self->getColPos('ion','area');

### Create a isotopic pattern buffer
my @featureBuffer = ( [$sth->fetchrow_array] );
my $chargeOfRef = $featureBuffer[0]->[ $chargeColPos ];
my $massOfRef = $self->getMass($featureBuffer[0]->[ $mozColPos ], $chargeOfRef );

while( my @featureValues = $sth->fetchrow_array )
  {
  my $curCharge = $featureValues[$chargeColPos];
  my $curMass = $self->getMass($featureValues[ $mozColPos ], $curCharge );
  my $deltaMass = $curMass - $massOfRef;
  my $massTolInDa = $self->getMassTolInDalton( $curMass, $massTol, $massTolUnit );

  ### Accumulate features while delta mass < tolerance
  if( $deltaMass <= $massTolInDa ) { push( @featureBuffer, \@featureValues ); }
  ### Detect features considering the time tolerance
  else
    {
    ### Sort features by retention time
    my @timeSortedFeatures = sort { $a->[$timeColPos] <=> $b->[$timeColPos] } @featureBuffer;
#    croak scalar(@timeSortedFeatures) if scalar(@timeSortedFeatures) > 1;

    ### Clusterize features into compounds
    my $prevFeature = shift(@timeSortedFeatures);
    my $compounds = [[$prevFeature]];
    my $compoundPos = 0;

    foreach my $feature (@timeSortedFeatures)
      {
      my $deltaTime = $feature->[$timeColPos] - $prevFeature->[$timeColPos];
      croak "listCompounds: sorting bug => negative delta time" if $deltaTime < 0;
      $compoundPos++ if $deltaTime > $timeTol;

      push( @{ $compounds->[$compoundPos] }, $feature );
      $prevFeature = $feature;
      }

    ### Insert compounds in the mzDB
    foreach my $compound (@$compounds)
      {
      my @areaSortedFeatures = sort { $b->[$areaColPos] <=> $a->[$areaColPos] } @$compound;
      my $compoundMass = $self->getMass( $areaSortedFeatures[0]->[$mozColPos], $areaSortedFeatures[0]->[$chargeColPos] );
      $compoundMass = sprintf("%.6f", $compoundMass);
      
      my @featureIds = map { $_->[0] } @$compound;

#      foreach my $feature (@$compound)
#        {
#        push( @ipIds, $isotopicPattern->[0] );
#        push( @dataPoints, [ $isotopicPattern->[-1], $isotopicPattern->[2] ] );
#        }

      ### Insert the new compound
      my @compoundValues = ( 'NULL', $compoundMass,'NULL','NULL','NULL');
      my $compoundInsert = join(", ",@compoundValues);
      $dbh->do( "INSERT INTO compound VALUES ($compoundInsert)" );
      my $compoundId = $dbh->func('last_insert_rowid');

      ### Update feature reference for the corresponding isotopic patterns
      foreach my $ftId (@featureIds) { $dbh->do("UPDATE feature SET compound = $compoundId WHERE id = $ftId"); }
      }

    ### Reinit pattern buffer and moz of reference
    @featureBuffer = ( \@featureValues );
    $massOfRef = $curMass;
    }
  }

$dbh->commit;

#CREATE view compound_ion AS
#SELECT compound, mass, moz, charge, time, number
#from compound, feature, isotopic_pattern, scan
#where compound.id = feature.compound and isotopic_pattern.id = feature.apex and scan.id = isotopic_pattern.scan

return 1;
}

###############################################################################
## Method: getKbEntryParams()
##
#sub getKbEntryParams
#{
#my($self, $entryID) = @_;
#my $quotedID = $self->dbh->quote($entryID);
#my $select = 'SELECT accession.AC, entry_index.*,  species.name  FROM accession, entry_index, species
#              WHERE entry_index.ID = accession.ID AND entry_index.speciesRef = species.id';
#my $entryIndexParams = $self->dbh->selectrow_arrayref($select);
#return $entryIndexParams;
#}

##############################################################################
# Function: flatten()
#
sub flatten
{
my @array = (@_);
my $numOfValues = scalar(@array);

if( $numOfValues <= 1 )
  {
  if( ref($array[0]) eq 'ARRAY' ) { @array = @{$array[0]};  }
  else { return @array; }
  }

$numOfValues = scalar(@array);
return undef if $numOfValues eq 0;

my @flattenArray = map { flatten($array[$_]) } (0..$numOfValues-1);

return @flattenArray;
}

##############################################################################
# Method: getMassTolInDalton()
#
sub getMassTolInDalton
{
my( $self, $mass, $massTol, $massTolUnit ) = @_;

if( $massTolUnit eq 'ppm' ) { return $massTol * $mass / 1000000; }
elsif ( $massTolUnit eq 'Da' ) { return $massTol; }
else { croak "getMassTolInDalton: undefined unit $massTolUnit"; }

return undef;
}

##############################################################################
# Method: getMass()
#
sub getMass
{
my( $self, $moz, $charge) = @_;
croak "getMass: undefined moz" if !defined $moz;
croak "getMass: undefined charge" if !defined $charge;

my $mass = ($moz*$charge) - ($charge*1.00727646688);

return $mass;
}

1;

