package SpectroRawData::Models::Scan;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/SpectroRawData::Models::Scans/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub id { return $_[0]->_accessor('id', $_[1]); }
sub number { return $_[0]->_accessor('number', $_[1]); }
sub channel { return $_[0]->_accessor('channel', $_[1]); }
sub msLevel { return $_[0]->_accessor('msLevel', $_[1]); }
sub polarity { return $_[0]->_accessor('polarity', $_[1]); }
sub retentionTime { return $_[0]->_accessor('retTime', $_[1]); }
sub lowestMoz { return $_[0]->_accessor('lowestMoz', $_[1]); }
sub highestMoz { return $_[0]->_accessor('highestMoz', $_[1]); }
sub TIC { return $_[0]->_accessor('TIC', $_[1]); }
sub numOfPeaks { return $_[0]->_accessor('numOfPeaks', $_[1]); }
sub basePeak { return $_[0]->_objectAccessor('basePeak', $_[1],'SpectroRawData::Models::Peak'); }
sub precursorPeak { return $_[0]->_objectAccessor('precursorPeak', $_[1],'SpectroRawData::Models::Peak'); }
sub peaks { return $_[0]->_objectAccessor('peaks', $_[1],'SpectroRawData::Models::Peaks'); }
sub description { return $_[0]->_accessor('description', $_[1]); }
sub isCentroided { return $_[0]->_accessor('isCentroided', $_[1]); }

##############################################################################
# Method: computeId()
#
sub computeId
{
my( $self ) = @_;
require Digest::CRC;
my $digester = Digest::CRC->new(type=>"crc32");
$digester->add($self->retentionTime);
$self->id( $digester->hexdigest );
}

1;
