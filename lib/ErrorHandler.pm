package ErrorHandler;

use strict;
use base qw/CommonPackage/;
use vars qw( $VERSION );
$VERSION = '0.1';

##############################################################################
# Method: Error()
# Set a new error or return the last error
# 
sub error
{
my( $self, $msg, $code ) = @_;

if( defined $msg )
  {
  my @calInfos = caller(1);
  my $error = new Error;
  $error->message($msg);
  $error->code($code) if defined $code;
  $error->package($calInfos[0]);
  $error->file($calInfos[1]);
  $error->line($calInfos[2]);
  $error->location('package '.$calInfos[0].' at '. $calInfos[1] . ' line '. $calInfos[2]);
  $self->addError($error);
  }
else
  {
  my $nbErrors = $self->getNumOfErrors;
  return $self->getError('number',$nbErrors);
  }
}

##############################################################################
# Method: getStackTraceAsString()
#
sub getStackTraceAsString
{
my $self = shift;
my $stackTrace = "Error stack trace:\n";
while( my $error = $self->getError('next') )
  { $stackTrace .= $error->message .' ('. $error->location . ")\n"; }
return $stackTrace;
}

##############################################################################
# Method: addError()
#
sub addError { $_[0]->_addElement($_[1],'errors','error'); }

##############################################################################
# Method: deleteError()
#
sub deleteError { $_[0]->_deleteElement('errors','error',$_[1]); }

##############################################################################
# Method: deleteLastError()
#
sub deleteLastError { $_[0]->_deleteElement('errors','error',$_[0]->getNumOfErrors); }

##############################################################################
# Method: getError()
#
sub getError
{
my( $self, $query, $value) = @_;

if( $query ne 'number' and $query ne 'next' )
  { die "getError: can't use $query as a query method !"; }

my $error = $self->_getElement($query,$value,'errors','error','CommonPackage');
if( defined $error ) { bless($error, 'Error'); }
return $error;
}

##############################################################################
# Method: getNumOfErrors()
#
sub getNumOfErrors { return $_[0]->_getNumOfElements('errors','error'); }


1;



package Error;

use strict;
use base qw/CommonPackage/;
use vars qw( $VERSION );
$VERSION = '0.1';

sub message { return $_[0]->_accessor('message',$_[1]); }
sub code { return $_[0]->_accessor('code',$_[1]); }
sub package { return $_[0]->_accessor('package',$_[1]); }
sub file { return $_[0]->_accessor('file',$_[1]); }
sub line { return $_[0]->_accessor('line',$_[1]); }
sub location { return $_[0]->_accessor('location',$_[1]); }

1;

