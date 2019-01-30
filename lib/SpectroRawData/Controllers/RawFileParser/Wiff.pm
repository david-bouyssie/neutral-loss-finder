package SpectroRawData::Controllers::RawFileParser::Wiff;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use File::Basename;
use File::Slurp;
use Win32::OLE;
#use Win32::OLE::Variant;
use base qw/SpectroRawData::Controllers::RawFileParser::Base/;
use SpectroRawData::Models::Scan;
use SpectroRawData::Models::Peaks;
use SpectroRawData::Models::PeakList;
use SpectroRawData::Models::Peak;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Method: openFile()
#
sub openFile
{
my( $self, $sampleNumber, $periodNumber ) = @_;
$self->{sampleNumber} = ( int($sampleNumber) eq $sampleNumber ) ? $sampleNumber : 1;
$self->{periodNumber} = ( int($periodNumber) eq $periodNumber ) ? $periodNumber : 0;

my $wiffFile = $self->file;
my $FMANSpecData = Win32::OLE->new("Analyst.FMANSpecData") || die "Could not start FMANSpecData\n";
$FMANSpecData->{WiffFileName} = $wiffFile or die "could not open $wiffFile\n";
$self->{specData} = $FMANSpecData;
$self->{wiffObject} = $FMANSpecData->GetWiffFileObject() or die "no WiffObject\n";
$self->{numOfCycles} = $self->{wiffObject}->GetActualNumberOfCycles($self->{sampleNumber} , $self->{periodNumber});
$self->{numOfExperiments} = $self->{wiffObject}->GetNumberOfExperiments($self->{sampleNumber} , $self->{periodNumber});
$self->title( $self->{wiffObject}->GetSampleName($self->{sampleNumber}) );
$self->_loadExperimentInfos;

my $FMANChromData = Win32::OLE->new("Analyst.FMANChromData") or die "Could not start FMANChromData\n";
$FMANChromData->{'WiffFileName'}= $wiffFile or die "could not load $wiffFile\n";
$self->{chromData} = $FMANChromData;
$self->{chromData}->SetToTIC($self->{sampleNumber}, $self->{periodNumber}, 0);
#alternative to get the number of cycles
#$self->{chromData}->GetNumberOfDataPoints();
#$self->_getSpectrum(0, 10);
#$self->_computeCycleFromTime( 10 );
} 


sub _loadExperimentInfos
{
my $self = shift;

my @expInfos;
for( my $expNum = 0; $expNum < $self->{numOfExperiments}; $expNum++ )
  { push(@expInfos, $self->{wiffObject}->GetExperimentObject($self->{sampleNumber}, $self->{periodNumber}, $expNum) ); }

$self->{experimentInfos} = \@expInfos;
}

###############################################################################
## Method: _computeCycleFromTime()
##
#sub _computeCycleFromTime
#{
#my( $self, $time ) = @_;
#my( $wiffPeriod, $wiffCycle);

##my $time = Win32::OLE::Variant->new('VT_R4', 10);
##$self->{wiffObject}->GetActualPeriodAndCycleFromTime(0, 0, $time, \$wiffPeriod, \$wiffCycle );
##print $wiffPeriod . "o";
##print $self->{wiffObject}->GetActualNumberOfCycles($self->{sampleNumber}, $self->{periodNumber});
##print $self->getNumOfScans();

##print $self->{wiffObject}->GetActualNumberOfSamples();

#return 1;
#}

##############################################################################
# Method: _computeTimeFromCycle()
#
sub _computeTimeFromCycle
{
my( $self, $cycle ) = @_;
return $self->{chromData}->GetDataPointXValue($cycle) * 60;
}

##############################################################################
# Method: closeFile()
#
sub closeFile 
{
my $self = shift;
#$self->{wiffObject}->NewData(1,1,1);
#$self->{wiffObject}->WiffFileChanged();
$self->{wiffObject}->CloseWiffFile();
$self->{wiffObject} = undef;
$self->{specData} = undef;
$self->{chromData} = undef;
my $txtFile =$self->file .'.txt';
unlink $txtFile;
}

##############################################################################
# Method: loadFile()
#
sub loadFile
{
my $self = shift;
require SpectroRawData::Data::RawFile;
my $rawFile = new SpectroRawData::Data::RawFile();
my $scans = new SpectroRawData::Models::Scans();

while( my $scan = $self->getScan('next') )
  { $scans->addScan($scan) if $scan->id; } #TODO : change this test (not correct after computeId)
#print "scans loaded !\n";
$rawFile->scans($scans);

return $rawFile;
}

##############################################################################
# Method: getScan()
#
sub getScan
{
my( $self, $query, $value, $updateIterator ) = @_;

my $nbScans = $self->getNumOfScans();
my $scan;

if( defined $nbScans )
  {
  if( $query eq 'number' or $query eq 'id' )
    {
    my $time = $self->_computeTimeFromCycle( $value );
    if( defined $time )
      {
      $scan = $self->_getSpectra($time);
      $self->_iterator('scanNumber','=',$value) if $updateIterator;
      }
    }
  elsif( $query eq 'time' ) { $scan = $self->_getSpectra($value); }
  elsif( $query eq 'next' )
    {
    my $scanNumber = $self->_iterator('scanNumber','+');
    if( $scanNumber <= $nbScans ) { $scan = $self->getScan( 'number', $scanNumber ); }
    else { $self->_resetIterator('scanNumber'); }
    }
  elsif( $query eq 'previous' )
    {
    my $scanNumber = $self->_iterator('scanNumber','-');
    if( $scanNumber <= $nbScans ) { $scan = $self->getScan( 'number', $scanNumber ); }
    else { $self->_resetIterator('scanNumber'); }
    }
  else { $self->throwError("Can't use $query as a query method "); return; }
  }

return $scan;
}


##############################################################################
# Method: getNumOfScans()
#
sub getNumOfScans { return $_[0]->{numOfCycles}; }

##############################################################################
# Method: _getSpectra()
#
sub _getSpectra
{
my( $self, $time ) = @_;

#    if( $value > 0 and $value <= $nbScans )
#      {

#      }
#    else { $self->throwError("Spectrum number $value over range !"); return; }
#print $time." time\n";
my $scan = $self->_getSpectrum(0, $time);

if( $scan->TIC > 0 )
  {
  my $scanNumber = $self->_iterator('scanNumber');
  #print 'get spectra => scan num = ' . $scanNumber ."\n";

  #print 'scan tic : ' .  $scan->TIC ."\n";
  if( defined $scanNumber ) { $scan->id($scanNumber); $scanNumber++; }
  
#  # GOOD CODE FOR MS/MS handling
#  #now add the MS/MS scans with at least one peak
#  for( my $expNum = 1; $expNum < $self->{numOfExperiments}; $expNum++ )
#    {
#    my $spectrum = $self->_getSpectrum($expNum, $time);
#    if( defined $scanNumber ) { $spectrum->id($scanNumber); $scanNumber++; }
#    $scan->addScan( $spectrum ) if $spectrum->TIC > 0;
#    }
#  # GOOD CODE FOR MS/MS handling
  
  #print $scan->selfDumper();
  }

return $scan;
}


##############################################################################
# Method: _getSpectrum()
#
sub _getSpectrum
{
my( $self, $experimentNumber, $time ) = @_;

my $spectrum = new SpectroRawData::Models::Scan;
my $peaks = new SpectroRawData::Models::Peaks;

if( $self->{experimentInfos}->[$experimentNumber]->ScanType() > 8 )
  { $spectrum->msLevel(2); } #m = re.search(r'[(]([0-9.]+)[)]',self.theFMANSpecData.DataTitle)
else { $spectrum->msLevel(1); }

$self->{specData}->SetSpectrum($self->{sampleNumber}, $self->{periodNumber}, $experimentNumber, $time, $time);

#$self->{specData}->Threshold(1000000000000);
#$parser->minTicThreshold
my $numOfPoints = $self->{specData}->GetNumberOfDataPoints();
my $totIonCurrent =0;
my( @masses, @intensities, $mozIndex );
  
if( $numOfPoints < 50 )
  {
  #old method
  foreach my $pointNumber ( 1..$numOfPoints )
    {
    my $intensity = $self->{specData}->GetDataPointYValue($pointNumber);
    if( $intensity > $self->intensityThreshold )
      {
      my $mass= $self->{specData}->GetDataPointXValue($pointNumber);
      my $intMass = int($mass);
      $mozIndex->{$intMass} = $pointNumber if !defined $mozIndex->{$intMass};
      push( @masses, $mass);
      push( @intensities, $intensity);
      }
    $totIonCurrent += $intensity;
    }
  }
else
  {
  #new method2
  my $txtFile =$self->file .'.txt';
  $self->{specData}->SaveToTextFile($txtFile);
  my $fileContent = read_file( $txtFile ); 
  my @lines = split(/\n/,$fileContent);

  my $peakNum=1;
  foreach my $line (@lines)
    { 
    my @peakValues = split(/\t/, $line );
    if( $peakValues[1] > $self->intensityThreshold )
      {
      my $intMass = int($peakValues[0]);
      $mozIndex->{$intMass} = $peakNum if !defined $mozIndex->{$intMass};
      push( @masses, $peakValues[0]);
      push( @intensities, $peakValues[1]);
      }
    $totIonCurrent += $peakValues[1];
    $peakNum++;
    }
  
  }
  
#print "tic : " . $totIonCurrent ."\n";
if( $totIonCurrent > $self->ticThreshold )
  {
  $peaks->loadArrays( \@masses, \@intensities, $mozIndex );
  #TODO : call computeBase64Data if loadFile has been called
  $spectrum->retentionTime($time);
  $spectrum->peaks( $peaks );
  $spectrum->TIC($totIonCurrent);
  $spectrum->computeId;
  }
#else { print "spectrum tic under threshold : " . $totIonCurrent."\n"; }

return $spectrum;
}


#sub indexFile
#{
#my $self = shift;
#$self->{'index_file'} = 'index_' . $self->{file};
#print "need to create the idnexing method\n";
#}  

#sub loadIndex
#{
#my $self = shift;

#croak 'loadIndex: undefined input file !' if $self->{file} eq undef;
#my $dir = dirname($self->{file});
#my $file = basename($self->{file});
#my $indexFile = $dir . '/index_' . $file;

#my $index_parser = new XML::Simple (KeyAttr=>[], ForceArray => ['oneIndexedElement'] );
#$self->{'index'} = $index_parser->XMLin($indexFile);

#}   
  
##############################################################################
# Method: getSpectrum()
#
#sub getSpectrum
#{
#my $self = shift;
#if(@_ ne 2) {croak "Arguments must be a unique 'query_string => value' pair ";}
#my $query_method = shift;
#my $value = shift;

#my $spectrum_match;
#my $nb_spectra = $self->getNumOfSpectra();

#if( not defined($self->{'index'}) )
#  { croak "getSpectrum: index not loaded, you forgot to call the loadIndex() method !"; }

#if( defined $nb_spectra )
#  {
#  if( $query_method eq "spectrum_num" )
#    {
#    my( $spectrum_num, $spectrum_type ) = @{$value};
#  
#    if( $spectrum_num > 0 and $spectrum_num <= $nb_spectra )
#      {
#      my $scan = $self->parseMzXmlElement($spectrum_num+2);
#      $spectrum_match = $self->scanToSpectrum( $scan, $spectrum_type );    
#      }
#    else { croak "Spectrum number $spectrum_num over range !";}
#    }
#  elsif( $query_method eq "ret_time" )
#    {
#    my( $ret_time, $spectrum_type ) = @{$value};  
#    if( not defined($self->{'ret_time_mapper'}) )
#      { croak "getSpectrum: retention time not loaded, you forgot to call the loadRetentionTimes() method !"; }
#    $spectrum_match = $self->getSpectrumAtTime( $ret_time, $spectrum_type );  
#    }
#  else
#    { croak "Can't use $query_method as a query method !";}
#  }

#return $spectrum_match;
#}

#sub getNumOfSpectra
#{
#my $self = shift;
#my $number;
#if(defined $self->{'index'}->{indexedElements}->{oneIndexedElement}->[0] )
#  { $number = scalar(@{$self->{'index'}->{indexedElements}->{oneIndexedElement} })-3;} 
#return $number;
#}

#sub loadRetentionTimes
#{
#my $self = shift;

#my $nb_scans = @{$self->{'index'}->{indexedElements}->{oneIndexedElement}};
#for(my $i=3; $i<$nb_scans;$i++)
#  {
#  my $ret_time = $self->{'index'}->{indexedElements}->{oneIndexedElement}->[$i]->{attr}->{value};
#  my $time; 
#  if( $ret_time =~ /(\d+)/ )
#    { $time = int($1/60); }
#  $self->{'ret_time_mapper'}->{$time} = $i if $self->{'ret_time_mapper'}->{$time} eq undef;
#  }
#  
#}

#      
#sub getSpectrumAtTime
#{
#my $self = shift; 
#my $ret_time = shift;
#my $spectrum_type = shift;

#croak 'getSpectrumAtTime: you need to define a file before searching a scan !' if $self->{file} eq undef;

#my $index = $self->{'index'};
#my $file = $self->{file};   
#my $time_tol = 3;

#croak 'mzXmlSpectrumFinder: file index not loaded !' if $index eq undef;

#use Data::Dumper;
## print Dumper($self->{'index'}->{indexedElements}->{oneIndexedElement}->[0]);
## print Dumper($self->{'index'}->{indexedElements}->{oneIndexedElement}->[1]);
## print Dumper($self->{'index'}->{indexedElements}->{oneIndexedElement}->[2]);

#my $nb_scans = @{$self->{'index'}->{indexedElements}->{oneIndexedElement}};
#my $time = int($ret_time/60);

#my $start_pos = $self->{'ret_time_mapper'}->{$time} || 3;
#my $scan ;

#for(my $i=$start_pos; $i<$nb_scans;$i++)
#  {
#  my $tmp_ret_time = $self->{'index'}->{indexedElements}->{oneIndexedElement}->[$i]->{attr}->{value};
#  my $tmp_time; 
#  if( $tmp_ret_time =~ /(\d+)/ ) { $tmp_time = $1; } 
#  my $delta = abs($ret_time - $tmp_time);  
#  if( $delta < $time_tol )
#    {  
#    $scan = $self->parseMzXmlElement($i);
#    my $tmp_ret_time = $self->{'index'}->{indexedElements}->{oneIndexedElement}->[$i]->{attr}->{value};
#    my $tmp_time; 
#    if( $tmp_ret_time =~ /(\d+)/ ) { $tmp_time = $1; }    
#    if( $delta > abs($ret_time - $tmp_time) ) {next; }
#    else { last; }                
#    }
#  } 

#my $spectrum;
#if(defined $scan ) { $spectrum = $self->scanToSpectrum( $scan, $spectrum_type ); }

#return $spectrum;  
#} 

#sub scanToSpectrum
#{
#my $self = shift; 
#my $scan = shift;
#my $spectrum_type = shift;
#my $spectrum;

#if( $spectrum_type eq 1)
#  { $spectrum = new SpectroRawData::Models::MsSpectrum();  }
#elsif( $spectrum_type eq 2)
#  { $spectrum = new SpectroRawData::Models::MsMsSpectrum();  }
# 
#my $peaks = new SpectroRawData::Models::Peaks(); 
#$peaks->base64Peaks($scan->{scan}->{peaks}->{content});
#$peaks->pairOrder( $scan->{scan}->{peaks}->{pairOrder});  
#$peaks->byteOrder( $scan->{scan}->{peaks}->{byteOrder});  
#$peaks->precision( $scan->{scan}->{peaks}->{precision}); 

#$spectrum->peaks($peaks);  
#$spectrum->polarity($scan->{scan}->{polarity});  
#my $ret_time; 
#if( $scan->{scan}->{retentionTime} =~ /(\d+)[\.,](\d+)/ ) { $ret_time = $1.'.'.$2; }
#$spectrum->retentionTime($ret_time); 
#$spectrum->lowestMoz($scan->{scan}->{lowMz}); 
#$spectrum->highestMoz($scan->{scan}->{highMz});   
#$spectrum->totIonCurrent($scan->{scan}->{totIonCurrent});
#$spectrum->peaksCount($scan->{scan}->{peaksCount});
#my $peak = new SpectroRawData::Models::Peak(); 
#$peak->moz($scan->{scan}->{basePeakMz} );
#$peak->intensity($scan->{scan}->{basePeakIntensity});  
#$spectrum->basePeak($peak);     
# 
#return $spectrum;  
#}


#sub parseMzXmlElement
#{
#my $self = shift; 
#my $pos = shift;

#my $index_element = $self->{'index'}->{indexedElements}->{oneIndexedElement}->[$pos];
#my $start = $index_element->{'pos'}->{'startByte'};
#my $length = $index_element->{'pos'}->{'lengthByte'};
#my $element_parser = new XML::Simple ( KeepRoot => 1 ); 
#my $xml_element;

#if( defined $start and defined $length )
#  {
#  my $readed_block;
#  seek($self->{fhandle},$start,0);
#  read($self->{fhandle}, $readed_block, $length);
#  $xml_element = $element_parser->XMLin($readed_block);
#  }

#return $xml_element;
#}


1;
