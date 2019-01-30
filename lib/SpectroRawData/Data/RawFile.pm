package SpectroRawData::Data::RawFile;

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
# Object accessors
#
sub name { return $_[0]->_accessor('name', $_[1]); }
#sub instrumentInfos { return $_[0]->_objectAccessor('instrumentInfos', $_[1],'SpectroRawData::Models::Instrument'); }
#sub softwareInfos { return $_[0]->_objectAccessor('softwareInfos', $_[1],'SpectroRawData::Models::Software'); }
sub scans { return $_[0]->_objectAccessor('scans', $_[1],'SpectroRawData::Models::Scans'); }


