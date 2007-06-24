#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# iRO (International) as of June 21 2007.
package Network::Send::ServerType18;

use strict;
use Globals qw($char $syncSync $net %config);
use Network::Send::ServerType11;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString2);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# Create a random byte string of a specified length.
sub createRandomBytes {
	my ($length) = @_;
	my $str = '';
	for (1..$length) {
		$str .= chr(rand(256));
	}
	return $str;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x93, 0x01) . createRandomBytes(3) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;

	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	$msg = pack("C*", 0xF3, 0x00) .
		createRandomBytes(3) .
		$charID .
		$accountID .
		chr(0) .
		$sessionID .
		createRandomBytes(9) .
		pack("V", getTickCount()) .
		chr($sex) .
		createRandomBytes(5);
	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C*", 0x85, 0x00, 0x00, 0x00, 0x00, 0x00) .
		getCoordString2($x, $y, 1);
		
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendTake {
	my $self = shift;
	my $itemID = shift; # $itemID = long
	my $msg = pack("C*", 0x16, 0x01) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	$msg = pack("C*", 0xA7, 0x00) . 
		pack("x6") .
		$syncSync;
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my $self = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xA2, 0x00) .
			pack("v", $index) .
			pack("V", $amount) .
			pack("x8");
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0x9B, 0x00) .
			pack("V*", $amount) .
			pack("x12") .
			pack("v*", $index);
			
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack("C*", 0x9F, 0x00) .
		pack("v*", $ID) .
		$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack("C*", 0xF7, 0x00, $head, 0x00, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0x7E, 0x00) .
		pack("v1", $amount) .
		pack("v1", $index);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack("C*", 0x8C, 0x00) .
			pack("v", $lv) .
			pack("v*", $ID) .
			pack("v*", $x) .
			pack("x4") .
			pack("v*", $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendSit {
	my $self = shift;

	my %args;
	$args{flag} = 2;
	Plugins::callHook('packet_pre/sendSit', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "sitting") {
		error "Failed to sit.\n";
		AI::dequeue();
	}
}

sub sendStand {
	my $self = shift;

	my %args;
	$args{flag} = 3;
	Plugins::callHook('packet_pre/sendStand', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}	
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "standing") {
		error "Failed to stand.\n";
		AI::dequeue();
	}
}

sub sendSkillUse {
	my $self = shift;
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	
	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq 'teleport') {
		error "Failed to use teleport skill.\n";
		AI::dequeue();
	} elsif (AI::action() ne "skill_use") {
		error "Failed to use skill.\n";
		AI::dequeue();
	}
}

1;