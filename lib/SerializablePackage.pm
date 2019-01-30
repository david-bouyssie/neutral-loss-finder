package SerializablePackage;

# Load essentials here, other modules loaded on demand later
use strict;
use Carp;
use File::Slurp;
use JSON;
use Encode;
use XML::Simple;
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
my $self = $class->SUPER::new(@_);
bless($self, $class);

#$self->_xmlParser({});

return($self);
}


##############################################################################
# Private methods
#

sub _xmlVersion { return $_[0]->_accessor('xmlVersion', $_[1]); }

sub _xmlParser
{
my( $self, $xmlParserOptions ) = @_;

if(defined $xmlParserOptions )
  {
  my %options = (KeyAttr => [], SuppressEmpty => undef);
  while( my($key, $value) = each(%{$xmlParserOptions})) { $options{$key} = $value;  }
  $self->{xmlParser} = new XML::Simple( %options );
  }

return $self->{xmlParser};
}

##############################################################################
# Public methods
#

sub writeXMLFile
{
my( $self, $xmlFile, $xmlOutOptions ) = @_;
$self->_checkFileDir($xmlFile);

my $xmlString = $self->writeXMLString( $xmlOutOptions );
open( XMLOUTPUT, ">$xmlFile") or croak "The file $xmlFile cannot be write: $!";
print XMLOUTPUT $xmlString;
close XMLOUTPUT;
}

sub writeXMLString
{
my( $self, $xmlOutOptions ) = @_;
my $xmlString;

if( defined $self->_xmlParser )
  {
#  my %options = (NoAttr => 1, RootName => 'xmlData', XMLDecl => '<?xml version="1.0" encoding="iso-8859-1"?>');
#  while( my($key, $value) = each(%{$xmlOutOptions})) { $options{$key} = $value;  }
  $xmlString =  $self->_xmlParser->XMLout($self->_content, %{$xmlOutOptions} );
  }
else { croak "writeXMLString: undefined xmlParser options !"; }

return $xmlString;
}

sub readXML
{
my( $self, $xml ) = @_;
if( $self->_xmlParser ne undef ) { $self->_content( $self->_xmlParser->XMLin($xml) ); }
else { croak "loadXMLFile: this method can't be call from the abstract class !"; }
}

sub readXMLFile
{
my( $self, $xmlFile ) = @_;
if( not -f $xmlFile ) { croak 'File '.$xmlFile.' doesn\'t exist !'; }
$self->readXML($xmlFile);
}

sub readXMLString
{
my( $self, $xmlString ) = @_;
$self->readXML($xmlString);
}

sub writeJSONFile
{
my( $self, $file ) = @_;

#$self->_checkFileDir($file);

my $jsonString = $self->writeJSONString;
open( OUTPUT, ">$file") or croak "The file $file cannot be write: $!";
print OUTPUT $jsonString;
close OUTPUT;
}

#sub writeBigJSONFile
#{
#my( $self, $file ) = @_;

#$self->_checkFileDir($file);

#require JSON::CompactFileWriter;
#my $jsonWriter = new JSON::CompactFileWriter();
#$jsonWriter->writeJSONFile($self->_content,$file);
#}

sub writeJSONString
{
my( $self, $encodeUtf8 ) = @_;

my $jsonString = JSON->new->encode($self->_content);
#Encode::from_to($jsonString, "UTF-8", "iso-8859-1" );
return $jsonString;

#return Encode::encode("UTF-8", $jsonString );
  
#if( $encodeUtf8 )
#  {
#  my $jsonString = JSON::XS->new->encode($self->_content);
#  return Encode::encode("UTF-8", $jsonString );
##  return encode_json($self->_content);
#  }
#else { return JSON::XS->new->encode($self->_content); }
}

sub readJSONFile
{
my( $self, $file ) = @_;
#Keep the two lines (read_file try to detect the variable type to return)
my $string = read_file( $file );
$self->readJSONString( $string );
}

sub readJSONString
{
my( $self, $string, $decodeUtf8 ) = @_;
$decodeUtf8 = defined $decodeUtf8 ? $decodeUtf8 : 1;

#$string = Encode::decode("UTF-8", $string );
#Encode::from_to($string, "UTF-8", "iso-8859-1" );
$self->_content( JSON->new->decode( $string) );

#if( $decodeUtf8 ) { $self->_content( decode_json($string) ); }
#else { $self->_content( JSON::XS->new->decode($string) ); }
}

sub _checkFileDir
{
my( $self, $file ) = @_;
require File::Basename;
my $dir = File::Basename::dirname($file);
if( not -d $dir ) { croak 'Directory '.$dir.' doesn\'t exist !'; }
}

1;
