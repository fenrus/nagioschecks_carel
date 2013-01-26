#!/usr/bin/perl -w
#
# $HeadURL$
# $Id$
#
# Script to check snmp stuff on Chiller web interface card.
# Carel pCOWeb, FW A1.4.9 - B1.2.4
# 
# 

use strict;
use Net::SNMP;

# Check for proper args....
if ($#ARGV <= 0){
  &print_help();
}

# Initialize variables....
my $net_snmp_debug_level = 0x0;					# See http://search.cpan.org/~dtown/Net-SNMP-v6.0.1/lib/Net/SNMP.pm#debug()_-_set_or_get_the_debug_mode_for_the_module
#my $net_snmp_debug_level = 0x08;					# massa debugging

my %status = (	'UNKNOWN'  => '-1',				# Enumeration for the output Nagios states
				'OK'       => '0',
				'WARNING'  => '1',
				'CRITICAL' => '2' );

my ($ip, $community, $warn, $crit) = pars_args();		# Parse out the arguments...
my ($session, $error) = get_snmp_session($ip, $community);	# Open an SNMP connection...
my $oid_ambientair = ".1.3.6.1.4.1.9839.2.1.2.2.0"; 		# Location of ambient air temperature in carel card
my $string_errors="";

# values fetched with snmp is *10. we divide by 10 here to get correct temperature.
my $temp_ambient = get_snmp_value($session, $oid_ambientair) / 10;

# Close the connection
close_snmp_session($session);  

my $state="";
my $unitstate="OK";
	
if ($temp_ambient >= $warn)
{
	$unitstate="WARNING";  
}
if ($temp_ambient >= $crit)
{
	$unitstate="CRITICAL";  
}


# Write an output string...
my $string = "Current ambient air temperature is ".$unitstate.": " . $temp_ambient; 

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
  my $ip        = "";
  my $community = "public"; 
  my $warn		= "30";
  my $crit		= "35";
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
    if($ARGV[0] =~/^-w|^--warn/) 
    {
      $warn = $ARGV[1];
      shift @ARGV;
      shift @ARGV;
      next;
    }
    if($ARGV[0] =~/^-c|^--crit/) 
    {
      $crit = $ARGV[1];
      shift @ARGV;
      shift @ARGV;
      next;
    }
  }
  return ($ip, $community, $warn, $crit); 
} 

sub print_help() {
  print "Usage: check_carel_temp -H host -C community -w 35 -c 40 \n";
  print "Options:\n";
  print " -H --host STRING or IPADDRESS\n";
  print "   Check temperatures on the indicated host.\n";
  print " -C --community STRING\n";
  print "   Community-String for SNMP. (default public)\n";
  print " -w --warn NAGIOS warn level in degrees centigrade (default 30)\n";
  print " -c --crit NAGIOS crit level in degrees centigrade (default 35)\n";
  
  exit($status{"UNKNOWN"});
}
