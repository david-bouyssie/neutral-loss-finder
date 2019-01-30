package SpectroRawData::Controllers::RawFileParser;

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
my $parsers = { 'wiff' => 1, 'mzxml' => 1, 'raw' => 1  };

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = $class->SUPER::new();
bless($self, $class);

my $rawFile = shift;
if( ! $self->_loadParser( $rawFile ) )
  { $self->throwError( "Can't load the appropriate raw file parser for '$rawFile' !" ); }

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
sub loadFile { return _parserCall(@_); }
sub timeToScanNumber { return _parserCall(@_); }
sub getMaxIntensity { return _parserCall(@_); }
sub getTIC { return _parserCall(@_); }
sub getBPC { return _parserCall(@_); }
sub getScan { return _parserCall(@_); }
sub getNumOfScans { return _parserCall(@_); }
sub bufferize { return _parserCall(@_); }
sub clearBuffer { return _parserCall(@_); }
sub compressData { return _parserCall(@_); }
sub maxMSLevel { return _parserCall(@_); }
sub title { return _parserCall(@_); }
sub infos { return _parserCall(@_); }
sub ticThreshold { return _parserCall(@_); }
sub intensityThreshold { return _parserCall(@_); }

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
  my $className = 'SpectroRawData::Controllers::RawFileParser::' . ucfirst( $format );
  my $parser = New( $className );
  if( !defined $parser )
    { $self->throwError( "Can't load the package with the class name $className !" ); return; }
  if( ! $parser->can('file')  )
    { $self->throwError( "The '$format' raw file parser is not well implemented !" ); return; }
  $parser->file( $file );
  $self->parser( $parser );
  }
else { $self->throwError( "No raw file parser available for '$file' !" ); return; }

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
  else { $self->trowError( "The current raw file parser can't manage the method $methodName !" ); }
  }
else { $self->throwError( "No raw file parser loaded !" ); }

return;
}

##############################################################################
# Function: getFileFormat()
#
sub getFileFormat { if( $_[0] =~ /(.+)\.(.+)/ ) { return lc($2); } }

sub getMethodName { if( $_[0] =~ /.+::(.+)/ ) { return $1; } }

1;

