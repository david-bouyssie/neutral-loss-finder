package CommonPackage;

# Load essentials here, other modules loaded on demand later
use strict;
use Carp;
use Exporter qw/import/;
require ErrorHandler;

##############################################################################
# Define some constants
#
our @EXPORT = qw/New/;
our $VERSION  = '0.1';
my $errorHandler = new ErrorHandler;

##############################################################################
# Object constructor
#
sub new
{
my $this = shift;
my $class = ref($this) || $this;
my $self = {};
bless($self, $class);

$self->_deleteContent;
$self->_content(shift);

return($self);
}

##############################################################################
# Function: New()
# Create an object from his class name
sub New
{
my( $class, @params ) = @_;
my $object = {};
eval "require $class" or croak $@;
bless($object,$class);
$object = $object->new( @params );
return $object;
}

##############################################################################
# Method: throwError()
#
sub throwError { shift; $errorHandler->error(@_); }

##############################################################################
# Method: errorHandler()
#
sub errorHandler
{
my( $self, $eh ) = @_;
$errorHandler = $eh if defined $eh;
return $errorHandler;
}

##############################################################################
# Method: selfDumper()
#
sub selfDumper
{
my $self = shift;
require Data::Dumper;
return Data::Dumper::Dumper($self->_content);
}

##############################################################################
# Method: clone()
#
sub clone
{
my $self = shift;
my $class = ref($self);
require Storable;
my $clonedContent = Storable::dclone($self->_content);
return New( $class, $clonedContent );
}

##############################################################################
# Method: _content()
#
sub _content
{
my( $self, $content ) = @_;
my @calInfos = caller(0);
$self->{data} = $content if( defined $content and $calInfos[0] ne 'main' );
return $self->{data};
}

##############################################################################
# Method: _deleteContent()
#
sub _deleteContent
{
my $self = shift;
$self->{data} = {};
}

##############################################################################
# Method: _delete()
#
sub _delete
{
my( $self, $key ) = @_;
delete $self->_content->{$key} if defined $key;
}


##############################################################################
# Accessor: _accessor()
#
sub _accessor
{
my( $self, $key, $value ) = @_;
my @calInfos = caller(0);
if( defined $key )
  {
  $self->_content->{$key} = $value if( defined $value and $calInfos[0] ne 'main' );
  return $self->_content->{$key} ;
  }
}

##############################################################################
# Accessor: _utf8Accessor()
#
sub _utf8Accessor
{
my( $self, $key, $value ) = @_;
return $self->_accessor($key, $value );

#$value = $self->_accessor($key, $value );

#if( defined $value )
#  {
#  require Encode;
#  Encode::from_to($value, "UTF-8", "iso-8859-1" );
#  return $value;
#  }
#return undef;
}

##############################################################################
# Accessor: _base64Accessor()
#
sub _base64Accessor
{
my( $self, $key, $value ) = @_;

if( defined $key )
  {
  require MIME::Base64;
  if( defined $value )
    {
    my $base64Value = MIME::Base64::encode_base64( $value );
    $self->_content->{$key} = $base64Value;
    return $value;
    }
  else { return MIME::Base64::decode_base64( $self->_content->{$key} ); }
  }

}

##############################################################################
# Accessor: _arrayAccessor()
#
sub _arrayAccessor
{
my( $self, $key, $array ) = @_;
if( defined $array and ref($array) ne 'ARRAY' )
  {croak "_arrayAccessor: an array must be provided"; }
#$string = join('%',@{$array});
#my @retArray = split( /%/, $self->_accessor($key, $string ) );
return $self->_accessor($key, $array );
}

##############################################################################
# Accessor: _arrayUpdater()
#
sub _arrayUpdater
{
my( $self, $key, $newValues ) = @_;

if(defined $newValues and scalar(@$newValues) > 0 )
  {
  my $array = $self->_arrayAccessor( $key );
  if( defined $array and scalar(@$array) > 0 )
    {
    my @values = @$array;
    push( @values, @$newValues );
    my %hash = map { $_ => 1 } @values;
    return $self->_arrayAccessor( $key, [keys(%hash)] );
    }
  else { return $self->_arrayAccessor( $key, $newValues ); }
  }
else { return $self->_arrayAccessor( $key ); }
}


##############################################################################
# Accessor: _hashAccessor()
#
sub _hashAccessor
{
my( $self, $accessorKey, $hashName, $hashValues ) = @_;
if(not defined $self->_accessor($accessorKey) ) { $self->_accessor($accessorKey, {}); }

if( defined $accessorKey and defined $hashName  )
  {
  if(not defined $self->_accessor($accessorKey)->{$hashName} )
    { $self->_accessor($accessorKey)->{$hashName} = {}; }
  $self->_accessor($accessorKey)->{$hashName} = $hashValues if defined $hashValues;
  return $self->_accessor($accessorKey)->{$hashName};
  }
elsif( defined $accessorKey ) { return $self->_accessor($accessorKey); }
}

##############################################################################
# Accessor: _objectAccessor()
#
sub _objectAccessor
{
my( $self, $key, $object, $class ) = @_;

if( defined $key )
  {
  my $newObject = New( $class );

  if( not defined $self->_accessor($key) ) { $self->_accessor($key, {}); }
  if( defined $object ) { $newObject->_content($self->_accessor($key, $object->_content)); }
  else { $newObject->_content($self->_accessor($key)); }
#  return undef if scalar(keys(%{$self->_accessor($key)})) == 0;
  return $newObject;
  }
}

##############################################################################
# Accessor: _objectHashAccessor()
#
sub _objectHashAccessor
{
my( $self, $accessorKey, $hashName, $object, $class ) = @_;

if( defined $accessorKey )
  {
  my $newObject = New( $class );

  if( not defined $self->_accessor($accessorKey) ) { $self->_accessor($accessorKey, {}); }
  if( defined $object )
    { $newObject->_content($self->_hashAccessor( $accessorKey, $hashName, $object->_content )); }
  else { $newObject->_content( $self->_hashAccessor( $accessorKey, $hashName ) ); }
  #return undef if !defined $self->_hashAccessor( $accessorKey, $hashName );
  return $newObject;
  }
}

##############################################################################
# Method: _initialize()
#
sub _initialize
{
my $self = shift;
foreach my $field (@_)
  {
  $self->_accessor($field,{});
  $self->_resetIterator($field);
  }
}

##############################################################################
# Method: _index()
#
sub _index
{
my( $self, $elNames ) = @_;
if( defined $elNames )
  {
  $self->_content->{'indexes'}->{$elNames} = {} if !defined $self->_content->{'indexes'}->{$elNames};
  return $self->_content->{'indexes'}->{$elNames};
  }
}

##############################################################################
# Method: _iterator()
#
sub _iterator
{
my( $self, $elNames, $operator, $value ) = @_;
if( defined $elNames)
  {
  $self->{iterators}->{$elNames} += 1 if $operator eq '+';
  $self->{iterators}->{$elNames} -= 1 if $operator eq '-';
  $self->{iterators}->{$elNames} = $value if $operator eq '=';
  return $self->{iterators}->{$elNames};
  }
}

##############################################################################
# Method: _resetIterator()
#
sub _resetIterator
{
my( $self, $iterator ) = @_;
croak "_resetIterator: undefined iterator !" if (not defined $iterator );
$self->{iterators}->{$iterator} = 0 ;
}

##############################################################################
# Method: _addElement()
#
sub _addElement
{
my( $self, $object, $elNames, $elName, $class ) = @_;

if( defined $object )
  {
  if( defined $class )
    {
    my $objectRef = ref($object);
    croak "_addElement : unexpect object class ('$objectRef' instead of '$class')" if $objectRef ne $class;
    }
  croak "_addElement : undefined object " if not defined $object;

  push( @{$self->_content->{$elNames}->{$elName} } , $object->_content );
  }
}

##############################################################################
# Method: _addIndexedElement()
#
sub _addIndexedElement
{
my( $self, $object, $elNames, $elName, $class ) = @_;
my $id = $object->_content->{id};
croak "_addIndexedElement : can't index element with undefined id !" if not defined $id;
$self->_addElement( $object, $elNames, $elName, $class );
$self->_index( $elNames )->{$id} = $self->_getNumOfElements($elNames,$elName);
}

##############################################################################
# Method: _deleteElement()
#
sub _deleteElement
{
my( $self, $elNames, $elName, $elNumber ) = @_;

if( defined $elNames and defined $elName and $elNumber eq int($elNumber) )
  {
  my $nbElems = $self->_getNumOfElements($elNames,$elName);
  if( $elNumber > 0 and $elNumber <= $nbElems )
    { 
    splice( @{$self->_content->{$elNames}->{$elName}},$elNumber-1, 1 );
    $self->_iterator($elNames,'-') if( $self->_iterator($elNames) > 0 );
    return 1;
    }
  else {return undef; }
  }
else { croak "_deleteElement: undefined argument(s)"; }
}

##############################################################################
# Method: _deleteIndexedElement()
#
sub _deleteIndexedElement
{
my( $self, $elNames, $elName, $query ) = @_;
my $elNumber;
if( ref($query) eq 'HASH' and defined $query->{id})
  { $elNumber = $self->_getIndexedElementNumber( $elNames, $query->{id} ); }
else { $elNumber = $query; }

my $id = $self->_content->{$elNames}->{$elName}->[$elNumber-1]->{id};
croak "_deleteIndexedElement: can't delete indexed element with undefined id !" if not defined $id;
$self->_deleteElement( $elNames, $elName, $elNumber );
delete $self->_index( $elNames )->{$query->{id}};

my $numOfElements = $self->_getNumOfElements($elNames, $elName);
foreach my $number ($elNumber..$numOfElements)
  {
  my $elId = $self->_content->{$elNames}->{$elName}->[$number-1]->{id};
  croak "_deleteIndexedElement: element id is missing !" if !defined $elId;
  $self->_index( $elNames )->{$elId} = $number;
  }
}

##############################################################################
# Method: _getElement()
#
sub _getElement
{
my( $self, $query, $value, $elNames, $elName, $class ) = @_;

my $nbElems = $self->_getNumOfElements($elNames,$elName);
my $match;

if( defined $nbElems )
  {
  if( $query eq 'number' )
    {
    if( $value > 0 and $value <= $nbElems )
      { $match = $self->_content->{$elNames}->{$elName}->[$value-1]; }
    else { return undef; }
    }
  elsif( $query eq "next" )
    {
    my $number = $self->_iterator($elNames,'+');
    if( $number <= $nbElems )
      {$match = $self->_getElement( 'number', $number, $elNames, $elName, $class ); }
    else { $self->_resetIterator($elNames); }
    }
  elsif( defined $query )
    {
    my $pos = 0;
    do{
      my $element = $self->_content->{$elNames}->{$elName}->[$pos];
      if( $element->{$query} eq $value ) { $match = $element; }
      $pos++;
      }until( $match ne undef or $pos eq $nbElems );
    }
  }

my $object = {};
if( defined $match and ref($match) ne $class )
  { $object = New( $class, $match ); }
else { $object = $match; }

return $object;
}

##############################################################################
# Method: _getIndexedElementNumber()
#
sub _getIndexedElementNumber { return $_[0]->_index( $_[1] )->{$_[2]}; }

##############################################################################
# Method: _getIndexedElement()
#
sub _getIndexedElement
{
my( $self, $query, $value, $elNames, $elName, $class ) = @_;
my $object;
if( $query eq 'id' )
  {
  my $elNumber = $self->_getIndexedElementNumber( $elNames, $value );
  $object = $self->_getElement('number', $elNumber, $elNames, $elName, $class ) if defined $elNumber;
  }
else { $object = $self->_getElement($query, $value, $elNames, $elName, $class ); }

return $object;
}

##############################################################################
# Method: _getNumOfElements()
#
sub _getNumOfElements
{
my( $self, $elNames, $elName ) = @_;
my $number;
if(ref($self->_content->{$elNames}->{$elName}) eq 'ARRAY' )
  { $number = scalar(@{$self->_content->{$elNames}->{$elName} });}
return $number;
}

##############################################################################
# Method: _checkSharingStatus()
#
sub _checkSharingStatus
{
my( $self, $testVariable, $sharingScript ) = @_;
require Win32::MMF::Shareable; #on linux use IPC::Shareable
tie my $isSharingStarted, "Win32::MMF::Shareable", $testVariable;

if(not $isSharingStarted )
  {
  require Proc::Background;
  my $process = Proc::Background->new("perl $sharingScript");
  }
}


1;

