package SpectroRawData::Models::Scans;

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
# Method: addScan()
#
sub addScan { $_[0]->_addIndexedElement($_[1],'scans','scan','SpectroRawData::Models::Scan'); }

##############################################################################
# Method: deleteScan()
#
sub deleteScan { $_[0]->_deleteIndexedElement('scans','scan',$_[1]); }

##############################################################################
# Method: getScan()
#
sub getScan
{
my( $self, $query, $value) = @_;

if( $query ne 'number' and $query ne 'next' and $query ne 'id' )
  { $self->throwError("can't use $query as a query method"); return; }

return $self->_getIndexedElement($query,$value,'scans','scan','SpectroRawData::Models::Scan');
}

##############################################################################
# Method: getNumOfScans()
#
sub getNumOfScans { return $_[0]->_getNumOfElements('scans','scan'); }


1;
