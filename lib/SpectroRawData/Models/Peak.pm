package SpectroRawData::Models::Peak;

##############################################################################
# Load essentials here, other modules loaded on demand later
#
use strict;
use Carp;
use base qw/CommonPackage/;

##############################################################################
# Define some constants
#
use vars qw($VERSION);
$VERSION  = '0.1';

##############################################################################
# Object accessors
#
sub moz { return $_[0]->_accessor('x', $_[1]); }
sub intensity { return $_[0]->_accessor('y', $_[1]); }
sub charge { return $_[0]->_accessor('z', $_[1]); }

##############################################################################
# Method: getMass()
#
sub getMass
{
my( $self ) = @_;
my $charge = $self->charge;
return if !defined $charge;
my $protonMass =  1.00727646688;
my $mass = ($self->moz * $charge) - ($charge * $protonMass);

return $mass;
}

