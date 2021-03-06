package ragnarok_server;

use strict;
use Socket;

use socket_raw;
use server;
use loop_socket;

our $server;
our $run_flags = 1;

our $pre_loop = undef;
our $post_loop = undef;
our $pre_on_packet = undef;

our $char_server = '127.0.0.1:6900';
our $map_server = '127.0.0.1:6900';

our $recv_packets = {
	# login packets
	#'0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
	'0AAC' => ['master_login', 'V Z30 a32 C', [qw(version username password_hex master_version)]],

	# char packets
	'0065' => ['game_login', 'a4 a4 a4 v C', [qw(accountID sessionID sessionID2 userLevel accountSex)]],
	'0066' => ['char_login', 'C', [qw(slot)]],
	'0187' => ['ban_check', 'a4', [qw(accountID)]],
	'09A1' => ['sync_received_characters'],

	# map packets
	'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
	'007D' => ['map_loaded'], # len 2
	'0360' => ['sync', 'V', [qw(time)]],
	'09D0' => ['gameguard_reply'],
};

our $send_packets = {
	# login packets
	'0AC9' => ['account_server_info', 'v a4 a4 a4 a4 a26 C a*', [qw(len sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],

	# char packets
	'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
	'099D' => ['received_characters', 'v a*', [qw(len charInfo)]],
	'0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v a128', [qw(charID mapName mapIP mapPort mapUrl)]],

	# map packets
	'02EB' => ['map_loaded', 'V a3 x2 v', [qw(syncMapSync coords unknown)]],
	'01D7' => ['player_equipment', 'a4 C v2', [qw(sourceID type ID1 ID2)]],
	'0187' => ['sync_request', 'a4', [qw(ID)]],
	'09CF' => ['gameguard_request'],
	'007E' => ['sync', 'V', [qw(time)]],
};

sub master_login {
	my $session = shift;
	my $data = pack("H*", "c90acf00343d0000cccccccc0900000000000000acfb87037267400030fc8703d42b6700c82b6700c4fb8703a36a01");
	$session->{'wbuf'} .= $data;

	my $padlen = (128-length($char_server . "\r\n"))*2;
	$data = pack("H*", "0a872e959411c6d5c2a1b5c2c0ad000000000000000000000000ce0c00008032");
	$data .= pack("a*", $char_server . "\r\n");
	$data .= pack("H*", sprintf("%0${padlen}d", 0));
	$session->{'wbuf'} .= $data;
	$session->close;
};

sub game_login {
	my $session = shift;
	my $data = pack("H*", "cccccccc");
	$session->{'wbuf'} .= $data;
	$data = pack("H*", "2d081d0003000003030000000000000000000000000000000000000000a00901000000");
	$session->{'wbuf'} .= $data;
}

sub ban_check {
	my $session = shift;
	my $data = pack("H*", "8701cccccccc");
	$session->{'wbuf'} .= $data;
}

sub sync_received_characters {
	my $session = shift;
	my $data = pack("H*", "9d099700eeeeeeeead1e190069620500376a1d003e00000000000000000000002000000000000000000000008100c3280000c32800002801ba019600a80f15000000000060000d00000000004800000000000000313233343536373800000000000000000000000000000000010101010101000000006765665f66696c6430332e67617400000000000000000000000000000000000000");
	$session->{'wbuf'} .= $data;
}

sub char_login {
	my $session = shift;

	my $padlen = (128-length($map_server . "\r\n"))*2;
	my $data = pack("H*", "c50aeeeeeeee6765665f66696c6430332e67617400000a87192d1227");
	$data .= pack("a*", $map_server . "\r\n");
	$data .= pack("H*", sprintf("%0${padlen}d", 0));

	$session->{'wbuf'} .= $data;
	$session->close;
};

sub map_login {
	my $session = shift;
	my $data = pack("H*", "8302cccccccc");
	$session->{'wbuf'} .= $data;

	$data = pack("H*", "eb02c77d160c404c40050500000f01c9040100000000000900000001004e565f42415349430000000000000000080000000f000000000900000000000000000001004d475f535245434f56455259000000000c0000000f000000010c000200000000001e0009004d475f53414645545957414c4c0000000d0000000f00000000160000000000050000000100414c5f445000a8050400000000000000050000000f00000001170000000000020000000100414c5f44454d4f4e42414e45000000000c0000000f0000000118000400000001000a000a00414c5f52555741434800000000000000090000000f0000000019000200000001000a000900414c5f504e45554d4100000000000000090000000f000000001a00040000000200f4010100414c5f54454c45504f525400000000000b0000000f000000001b000200000004001a000900414c5f57415250000400000000000000070000000f000000001c00100000000a0028000900414c5f4845414c000400000000000000070000000f000000001d00100000000a002d000900414c5f494e4341474900000000000000090000000f000000001e000100000000000d000900414c5f44454341474900000000000000090000000f000000011f000400000001000a000100414c5f484f4c595741544552000000000c0000000f00000000200004000000000023000100414c5f43525543495300000000000000090000000f0000000021000400000002001a000100414c5f414e47454c55530000000000000a0000000f000000012200100000000a0040000900414c5f424c455353494e4700000000000b0000000f0000000023001000000001000f000900414c5f43555245000400000000000000070000000f0000000036001000000000003c000900414c4c5f524553555252454354494f4e006f7800000000000041000000000000000000010050525f4d4143454d41535445525900000e0000000f0000000142001000000000000a00090050525f494d504f534954494f000000000c0000000f0000000143000100000000000800090050525f5355464652414749554d0000000d0000000f0000000044001000000000000a00090050525f415350455253494f00000000000b0000000f0000000045000200000000001400090050525f42454e4544494354494f0000000d0000000f0000000046000200000000000c00090050525f53414e435455415259000000000c0000000f0000000147001000000000000400090050525f534c4f57504f49534f4e0000000d0000000f0000000148001000000000000500090050525f53545245434f564552590000000d0000000f0000000149001000000000001400090050525f4b595249450000000000000000080000000f000000014a000400000000002800010050525f4d41474e4946494341540000000d0000000f000000014b000400000000001400010050525f474c4f52494100000000000000090000000f000000004c000100000000001400050050525f4c4558444956494e41000000000c00");
	$session->{'wbuf'} .= $data;

	$data = pack("H*", "00000f000000014d000100000000001400050050525f5455524e554e444541440000000d0000000f000000004e000100000000000a00090050525f4c455841455445524e410000000d0000000f000000004f000200000000002600090050525f4d41474e555300000000000000090000000f00000000");
	$session->{'wbuf'} .= $data;

	$data = pack("H*", "d701cccccccc0200000000d701cccccccc0300000000d701cccccccc02853e00003a010100d701cccccccc0c000000003a0101003a010100b0000000960000003a010100b000060043090000b000050077060000b0000800ae020000b0000700ae020000d701cccccccc04d10100003a010100b0001900b8880000b0001800de1c0000");
	$session->{'wbuf'} .= $data;
};

sub map_loaded {
};

sub sync {
	my $session = shift;
	$session->{'wbuf'} .= pack("H*", "7e0000000000");
	#$session->{'wbuf'} .= pack('H*', '8701cccccccc');
}

sub on_packet {
	my $session = shift;
	my $switch = sprintf("%.4X", unpack("v", $session->{'rbuf'}));

	$pre_on_packet->($session, $switch) if $pre_on_packet;

	if (exists $recv_packets->{"$switch"}) {
		my $callback = __PACKAGE__->can($recv_packets->{"$switch"}[0]);
		if ($callback) {
			$callback->($session, $recv_packets->{"switch"});
		}
	}
	$session->{'rbuf'} = '';
}

sub on_connection {
	my $client = shift;
	$client->{'packet'} = \&on_packet;
}

sub loop {
	my $timeout = 0.2;
	$timeout = $_[0] if $_[0];

	$pre_loop->() if $pre_loop;
	loop_socket::loop($timeout);
	$post_loop->() if $post_loop;

	#if (time % (socket_raw::STALL_DEFAULT/2) == 0) {
	#	foreach my $item (values %loop_socket::socket_table) {
	#		$item->{'wbuf'} .= pack('H*', '8701cccccccc') if $item->{'parent'} == $server;
	#	}
	#	sleep(1);
	#}
}

sub run {
	loop while ($run_flags);
}

sub init {
	$server = server::create_server($_[0], INADDR_ANY);
	$server->{'connection'} = \&on_connection;
}

1;
