package SpectroRawData::Controllers::MSMSParser::Base;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use File::Spec;
use base qw/CommonPackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object destructor
#
sub DESTROY
{
my $self = shift;
$self->closeFile();
} 

##############################################################################
# Object accessors
#
sub file
{
my $file = File::Spec->rel2abs($_[1]) if defined $_[1];
return $_[0]->_accessor('file', $file);
}

##############################################################################
# Method: _indexFile()
#
sub _indexFile
{
my $self = shift;
return $self->file .'.idx';
}

##############################################################################
# Method: closeFile()
#
sub closeFile
{
my $self = shift;
close $self->{fileHandle} if defined $self->{fileHandle};
}

##############################################################################
# Method: _initIndex()
#
sub _initIndex
{
my $self = shift;
return if defined $self->{dbh};

my $indexFile = $self->_indexFile;

if( not -f $indexFile ) { $self->_buildIndex(); }
else { $self->_openIndex(); }
}

##############################################################################
# Method: _openIndex()
#
sub _openIndex
{
my( $self ) = @_;

my $dbPath = $self->_indexFile;
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbPath","","", {RaiseError => 1, AutoCommit => 0} );
$self->{dbh} = $dbh;

return $dbh;
}

##############################################################################
# Method: _createIndexDB()
#
sub _createIndexDB
{
my( $self ) = @_;
my $dbh = $self->{dbh};
croak "_createIndex: undefined database handler" if !defined $dbh;

### Creation of a database to store the peak-list index
my @columns = ( 'id INTEGER PRIMARY KEY AUTOINCREMENT',
                'description TEXT',
                'blockStart INTEGER',
                'blockLength INTEGER',
                'precursorMass FLOAT',
                'precursorMoz FLOAT',
                'precursorCharge INTEGER',
                'minRetTime FLOAT',
                'maxRetTime FLOAT',
                'minScanNumber INTEGER',
                'maxScanNumber INTEGER',
                'minCycleNumber INTEGER',
                'maxCycleNumber INTEGER',
              );

my $columnsAsString = join(', ', @columns);

### Creation of the tables
$dbh->do("CREATE TABLE IF NOT EXISTS peaklistIndex ($columnsAsString)");
$dbh->commit();

return 1;
}

##############################################################################
# Method: selectScans()
#
sub selectScans
{
my( $self, $filters, $orderBy ) = @_;
croak "getScan: undefined select filter" if not defined $filters;

my $selectFilter;
if( ref($filters) eq 'ARRAY' ) { $selectFilter = $self->_buildIdFilter( $filters ); }
elsif( ref($filters) ne 'HASH' ) { $selectFilter = $filters; }

my $selectString = "SELECT * FROM peaklistIndex";
$selectString .= " WHERE $selectFilter" if $selectFilter ne '*';
$selectString .= " ORDER BY $orderBy" if defined $orderBy;

my $selection = $self->{dbh}->selectall_arrayref($selectString);

require SpectroRawData::Models::Scans;
my $scans = new SpectroRawData::Models::Scans;

foreach my $index (@$selection)
  { $scans->addScan( $self->_indexToScan( $index ) ); }

return $scans;
}

##############################################################################
# Private method: _buildIdFilter()
#
sub _buildIdFilter
{
my( $self, $ids ) = @_;
my @conditions;

foreach my $id (@$ids)
  {
  my $string = "'".$id."'";
  push( @conditions, "id = $string");
  }

return join(" OR ",@conditions);
}

##############################################################################
# Method: getScan()
#
sub getScan
{
my( $self, $query, $value, $params ) = @_; #set or not the iterator to the scan number

my $nbScans = $self->getNumOfScans();
my $scan;

if( defined $nbScans )
  {
  if( $query eq 'number' ) { $scan = $self->_getScan($value); }
  elsif( $query eq 'next' )
    {
    my $scanNumber = $self->_iterator('scanNumber','+');
    if( $scanNumber <= $nbScans ) { $scan = $self->_getScan($scanNumber); }
    else { $self->_resetIterator('scanNumber'); }
    }
  elsif( $query eq 'previous' )
    {
    my $scanNumber = $self->_iterator('scanNumber','-');
    if( $scanNumber > 0 ) { $scan = $self->_getScan($scanNumber); }
    else { $self->_resetIterator('scanNumber'); }
    }
  else { croak "Can't use $query as a query method "; }
  }

return $scan;
}

##############################################################################
# Method: _getScan()
#
sub _getScan
{
my( $self, $number ) = @_;
my $dbh = $self->{dbh};
croak "_getScan: undefined database handler" if !defined $dbh;

my @row = $dbh->selectrow_array("SELECT * FROM peaklistIndex WHERE id = $number");
return undef if scalar(@row) eq 0;

return $self->_indexToScan( \@row );
}

##############################################################################
# Method: _indexToScan()
#
sub _indexToScan
{
my( $self, $scanIndex ) = @_;
croak "_indexToScan: undefined scan index" if !defined $scanIndex;

require SpectroRawData::Models::Scan;
my $msmsScan = new SpectroRawData::Models::Scan;
$msmsScan->id($scanIndex->[0]);
$msmsScan->msLevel(2);
$msmsScan->description($scanIndex->[1]);
$msmsScan->retentionTime($scanIndex->[7]);

require SpectroRawData::Models::Peak;
my $precursorPeak = new SpectroRawData::Models::Peak();
$precursorPeak->moz($scanIndex->[5]);
$precursorPeak->charge($scanIndex->[6]);

$msmsScan->precursorPeak( $precursorPeak );

return $self->_readSpectrum( $msmsScan, $scanIndex->[2], $scanIndex->[3] );
}

##############################################################################
# Method: getNumOfScans()
#
sub getNumOfScans
{
my( $self ) = @_;
my $dbh = $self->{dbh};
croak "getNumOfScan: undefined database handler" if !defined $dbh;
my @row = $dbh->selectrow_array('SELECT seq FROM sqlite_sequence WHERE name = "peaklistIndex"');

return $row[0];
}

##############################################################################
# Interface: _readSpectrum()
#
sub _readSpectrum
{
my( $self, $scan, $blockStart, $blockLength ) = @_;

return $scan;
}

##############################################################################
# Method: parseDescription()
#
sub parseDescription # TODO : use this method in dat parser
{
my( $self, $description ) = @_;
croak "parseDescription: undefiend description" if !defined $description;
my $descInfos;

if( $description =~ /.+\.dta$/i )
  {
  ### EX: OTKAC080604_12.1010.1010.3.dta
  my @stringParts = split(/\./,$description);
  $descInfos->{rawFile} = $stringParts[0].'.RAW';
  $descInfos->{minScanNumber} = $stringParts[1];
  $descInfos->{maxScanNumber} = $stringParts[2];
  }
elsif( $description =~ /spectrumId=.+ PeakProcessing=.+/i )
  {
  ### EX: spectrumId=938 PeakProcessing=discrete Polarity=positive ScanMode=MassScan TimeInMinutes=0.000000 acqNumber=1695
  my @stringParts = split(/\s/,$description);
  my($key, $value) = split(/=/, $stringParts[5] );
  $descInfos->{minScanNumber} = $value;
  $descInfos->{maxScanNumber} = $value;
  }
elsif( $description =~ /.+\.wiff/i )
  {
  ### EX: File: QSKAC070730019.wiff, Sample: Cyto C (sample number 1), Elution: 43.977 min, Period: 1, Cycle(s): 2480 (Experiment 2)
  my @stringParts = split(/, /,$description);

  if( $stringParts[0] =~/File: (.+)/i ) { $descInfos->{rawFile} = $1; }

  if( $stringParts[1] =~/Sample: (.+) \(sample number (\d+)\)/i )
    {
    my $sampleName = $1; $sampleName =~ s/\004//; #delete strange character
    $descInfos->{sampleName} = $sampleName;
    $descInfos->{rawFileSample} = int($2);
    }

  if( $stringParts[2] =~/Elution: (.+?) to (.+?) min/i )
    {
    my( $firstVal, $secondVal ) = ($1,$2);
    if( $firstVal =~ /(\d+)\.(\d+)/ ) { $descInfos->{minRetTime} = 60*($1 . '.' . $2); }
    elsif( $firstVal =~ /(\d+)/ ) { $descInfos->{minRetTime} = 60*$1; }
    if( $secondVal =~ /(\d+)\.(\d+)/ ) { $descInfos->{maxRetTime} = 60*($1 . '.' . $2); }
    elsif( $secondVal =~ /(\d+)/ ) { $descInfos->{maxRetTime} = 60*$1; }
    }
  elsif( $stringParts[2] =~/Elution: (.+?) min/i )
    {
    my $val = $1;
    if( $val =~ /(\d+)\.(\d+)/ ) { $descInfos->{minRetTime} = 60*($1 . '.' . $2); }
    elsif( $val =~ /(\d+)/ ) { $descInfos->{minRetTime} = 60*$1; }
    $descInfos->{maxRetTime} = $descInfos->{minRetTime};
    }

  ### EX: Cycle(s): 2480, 2490 or Cycle(s): 2480
  if( $stringParts[4] =~/Cycle\(s\): (\d+) \(Experiment (\d+)\)/i )
    { $descInfos->{maxCycleNumber} = $descInfos->{minCycleNumber} = $1; }
  elsif( $description =~/Cycle\(s\): (\d+), (\d+)/i )
    {
    $descInfos->{minCycleNumber} = $1;
    $descInfos->{maxCycleNumber} = $2;
    }
  }
elsif( $description =~ /FinneganScanNumber/i )
  {
  ### EX: Elution from: 41.435 to 41.435 period: 0 experiment: 1 cycles: 1 precIntensity: 2600.0
  ###     FinneganScanNumber: 1979 MStype: enumIsNormalMS rawFile: 20061110LL02.RAW
  if( $description =~/Elution from: (\S+?) to (\S+?) period:/i )
    {
    my( $firstVal, $secondVal ) = ($1,$2);
    if( $firstVal =~ /(\d+)\.(\d+)/ ) { $descInfos->{minRetTime} = 60*($1 . '.' . $2); }
    elsif( $firstVal =~ /(\d+)/ ) { $descInfos->{minRetTime} = 60*$1; }
    if( $secondVal =~ /(\d+)\.(\d+)/ ) { $descInfos->{maxRetTime} = 60*($1 . '.' . $2); }
    elsif( $secondVal =~ /(\d+)/ ) { $descInfos->{maxRetTime} = 60*$1; }
    }
  if( $description =~/FinneganScanNumber: (\d+) MStype: .+ rawFile: (.+)/i )
    {
    $descInfos->{maxScanNumber} = $descInfos->{minScanNumber} = $1;
    $descInfos->{rawFile} = $2;
    }
  }
elsif($description =~ /scan id:\s+(\d+)/i )
  {
  ### EX: scan id : 938
  $descInfos->{minScanNumber} = $1;
  $descInfos->{maxScanNumber} = $1;
  }

return $descInfos;
}


1;
