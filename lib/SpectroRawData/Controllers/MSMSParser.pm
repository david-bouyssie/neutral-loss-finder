package SpectroRawData::Controllers::MSMSParser;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/CommonPackage/;
import CommonPackage qw/New/;

##############################################################################
# Define available parsers
#
my $parsers = { 'mgf' => 1 };

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = $class->SUPER::new();
bless($self, $class);

my $msmsFile = shift;
if( ! $self->_loadParser( $msmsFile ) )
  { croak "Can't load the appropriate MSMS file parser for '$msmsFile' !"; }
$self->openFile();

return($self);
}

##############################################################################
# Object accessors
#
sub parser { return $_[0]->_accessor('parser', $_[1]); }

##############################################################################
# Parser interface :
#
sub openFile { return _parserCall(@_); }
#sub closeFile { return _parserCall(@_); } autoCall in base parser
#sub getNextSpectrum { return _parserCall(@_); }
sub selectScans { return _parserCall(@_); }
sub getScan { return _parserCall(@_); }
sub getNumOfScans { return _parserCall(@_); }
sub loadFile { return _parserCall(@_); }
sub writeFile { return _parserCall(@_); }

###############################################################################
## Method: readFile()
##
#sub readFile
#{
#my( $self, $file ) = @_;
#my $parser = $self->_loadParser( $file );
#if( defined $parser )
#  {
#  my $msmsSpectra = $parser->readFile( $file );
#  return $msmsSpectra;
#  }
#return;
#}

###############################################################################
## Method: writeFile()
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
# Method: _loadParser()
#
sub _loadParser
{
my( $self, $file ) = @_;
if( not -f $file ) { croak "Can't found the file '$file'"; }

my $format = getFileFormat( $file );

my $parser;

if(defined $parsers->{$format} )
  {
  my $className = 'SpectroRawData::Controllers::MSMSParser::' . ucfirst( $format );
  my $parser = New( $className );
  if( !defined $parser )
    { croak "Can't load the package with the class name $className !"; return; }
  if( ! $parser->can('file')  )
    { croak "The '$format' MSMS file parser is not well implemented !"; return; }
  $parser->file( $file );
  $self->parser( $parser );
  }
else { croak "No MSMS file parser available for '$file' !"; return; }

return 1;
}


##############################################################################
# Method: _parserCall()
#
sub _parserCall
{
my( $self, @params ) = @_;
my @callerInfos = caller(1);

my $methodName = getMethodName($callerInfos[3]);

if( defined $self->parser )
  {
  if( $self->parser->can($methodName) )
    { return $self->parser->$methodName(@params); }
  else { croak "The current raw file parser can't manage the method $methodName !"; }
  }
else { croak "No raw file parser loaded !"; }

return;
}

##############################################################################
# Function: getFileFormat()
#
sub getFileFormat { if( $_[0] =~ /(.+)\.(.+)/ ) { return lc($2); } }

sub getMethodName { if( $_[0] =~ /.+::(.+)/ ) { return $1; } }


###############################################################################
## Method: _loadParser()
##
#sub _loadParser
#{
#my $format = getFileFormat( $_[1] );

#if(defined $parsers->{$format} )
#  {
#  my $className = 'SpectroRawData::Controllers::MSMSParser::' . ucfirst( $format );
#  my $parser = New( $className );
#  return $parser;
#  }
#  
#return;
#}

###############################################################################
## Function: getFileFormat()
##
#sub getFileFormat
#{
#if( $_[0] =~ /(.+)\.(.+)/ ) { return lc($2); }
#}

1;

