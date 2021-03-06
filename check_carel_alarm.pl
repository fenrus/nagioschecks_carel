#!/usr/bin/perl -w
#
# $HeadURL$
# $Id$
#
# Script to check alarm status with snmp on Chiller web interface card.
# Works with at least Carel pCOWeb, FW A1.4.9 - B1.2.4
# 
# 

use strict;
use Net::SNMP;

# Check for proper args....
if ($#ARGV <= 0){
	&print_help();
}

# Initialize variables....
my $net_snmp_debug_level = 0x0;			# See http://search.cpan.org/~dtown/Net-SNMP-v6.0.1/lib/Net/SNMP.pm#debug()_-_set_or_get_the_debug_mode_for_the_module
#my $net_snmp_debug_level = 0x08;		# massa debugging

my %status = (	'UNKNOWN'  => '-1',		# Enumeration for the output Nagios states
		'OK'       => '0',
		'WARNING'  => '1',		# warning might not ever happen..?
		'CRITICAL' => '2' );

my ($ip, $community, $num) = pars_args();			# Parse out the arguments...
my ($session, $error) = get_snmp_session($ip, $community);	# Open an SNMP connection...

# OID to get digital data; 1.3.6.1.4.1.9839.2.1.1.X.0 where X represent the values below.

# The digital i/o represent the following stuff:
#
my %explained = (
	5 => 'Testalarm',
	14 => 'Air flow switch',
	15 => 'Emergency chiller',
	18 => 'Maintainance alarm',
	19 => 'Phase-sequency-alarm',
	26 => 'Prealarm high temp ambient air',
	29 => 'High pressure from pressure switch',
	30 => 'Low pressure from pressure switch',
	31 => 'Resistor overheating',
	32 => 'Air filter',
	33 => 'High temp ambient air',
	34 => 'Low temp ambient air',
	50 => 'Sum of all alarms',
);

# if 15 (high pressure from probe) is active the emergency cooler is running
# if 30 is active the emergency cooler can not run

my $oid_base = "1.3.6.1.4.1.9839.2.1.1."; 		# OID base for all digital i/o's
my $oid = $oid_base.$num.".0";

my $recieved_value = get_snmp_value($session, $oid);

# Close the connection
close_snmp_session($session);  

my $state="";
my $unitstate="OK";
	
#if ($recieved_value >= $warn)
#{
#	$unitstate="WARNING";  
#}
# Warning might never happen.. with binary data.
if ($recieved_value >= 1)
{
	$unitstate="CRITICAL";  
}


# Write an output string...
my $string = $explained{$num}." (".$num.") is currently ".returnstatus($recieved_value);


#Emit the output and exit with a return code matching the state...
print $string."\n";
exit($status{$unitstate});

########################################################################
##  Subroutines below here....
########################################################################
sub get_snmp_session{
	my $ip        = $_[0];
	my $community = $_[1];
	my ($session, $error) = Net::SNMP->session(
             -hostname  => $ip,
             -community => $community,
             -port      => 161,
             -timeout   => 1,
             -retries   => 3,
			 -debug		=> $net_snmp_debug_level,
			 -version	=> 2,
             -translate => [-timeticks => 0x0] 
	);
	return ($session, $error);
}

sub returnstatus{
	my $returnstatus = $_[0];
	if ($returnstatus == 1) {
		return "active";
	}
	else {
		return "not active";
	}
}

sub close_snmp_session{
	my $session = $_[0];
	$session->close();
}

sub get_snmp_value{
	my $session = $_[0];
	my $oid     = $_[1];
	my (%result) = %{get_snmp_request($session, $oid) or die ("SNMP service is not available on ".$ip) }; 
	return $result{$oid};
}

sub get_snmp_request{
	my $session = $_[0];
	my $oid     = $_[1];
	return $session->get_request( $oid );
}


sub get_snmp_table{
	my $session = $_[0];
	my $oid     = $_[1];
	return $session->get_table(	
		-baseoid =>$oid
		); 
}

sub pars_args
{
	my $ip		= "";
	my $community	= "public"; 
	my $num		= "50";
	while(@ARGV)
	{
		if($ARGV[0] =~/^-H|^--host/) 
		{
			$ip = $ARGV[1];
			shift @ARGV;
			shift @ARGV;
			next;
		}
		if($ARGV[0] =~/^-C|^--community/) 
		{
			$community = $ARGV[1];
			shift @ARGV;
			shift @ARGV;
			next;
		}
		if($ARGV[0] =~/^-N|^--num/)
		{
			$num = $ARGV[1];
			shift @ARGV;
			shift @ARGV;
			next;
		}
	}
return ($ip, $community, $num); 
} 

sub print_help() {
	print "Usage: check_carel_temp -H host -C community -w 35 -c 40 \n";
	print "Options:\n";
	print " -H --host STRING or IPADDRESS\n";
	print "   Check temperatures on the indicated host.\n";
	print " -C --community STRING\n";
	print "   Community-String for SNMP. (default public)\n";
	print " -N --num INTEGER\n";
	print "   Integer to check in alarm-table. (default 50, sum-alarm)\n";
	exit($status{"UNKNOWN"});
}
