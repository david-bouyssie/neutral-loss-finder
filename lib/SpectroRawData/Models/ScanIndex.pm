package SpectroRawData::Models::ScanIndex;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SpectroRawData::Models::Scan/;
#            SpectroRawData::Data::Index

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub start { return $_[0]->_accessor('start', $_[1]); }
sub size { return $_[0]->_accessor('size', $_[1]); }

1;



