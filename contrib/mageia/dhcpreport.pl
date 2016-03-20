#!/usr/bin/perl

my $path_to_leasefile = "/var/lib/dhcp/dhcpd.leases";
my $ping_ttl = .3;
my $date_format = "%m-%d-%Y %I:%M%p";

use strict;
use Net::Ping;
#To convert the UTC times to seconds since the epoch
use Time::Local;
#To format the output time
use POSIX ("strftime");
use Term::ANSIColor;
use Getopt::Long;
#use Getopt::Long (":config", "bundling");
use Term::ANSIColor (":constants");
$Term::ANSIColor::AUTORESET = 1;

#Populate all the command line variables
my ($showmac,$showatm,$showip,$showexpired,$help,$color);
GetOptions('mac|m' => \$showmac,'atm|a' => \$showatm,'ip|i=s' => \$showip,'expired|x' => \$showexpired,'help|h'=>\$help,'color|c'=>\$color);

$ENV{'REQUEST_METHOD'};

#Display the usage if they pass in --help or -h
if ($help) { die(&usage()); }

my @list;
my %hash;
my ($count,$expired_lease);

#Open the lease file to begin parsing it
open (INFILE,$path_to_leasefile); 

#print "$< - $>\n";

$expired_lease=0;
while (<INFILE>) {
        if ($_ =~ /lease (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/i) {
                
                my $ip = $1;
                my $hostname = undef;
                my $remoteid = undef;
                my $macaddr = undef;
                my $lease_start = undef;
                my $lease_end = undef;
                # Go until you see a } which is the end of record char
                while ($_ !~ /^}$/) {
                        $_ = <INFILE>;
                        if ($_ =~ /starts/) {
                                $lease_start = &leasegm_to_epoch($_);
                        }
                        elsif ($_ =~ /ends/) {
                                $lease_end = &leasegm_to_epoch($_);
                        }
                        elsif ($_ =~ /client-hostname \"(.*)\"/ ) {
                                $hostname = $1;
                        }
                        elsif ($_ =~ /option agent\.remote-id (.*);/ ) {
                                $remoteid = $1;
                        }
                        elsif ($_ =~ /hardware ethernet (.*);/ ) {
                                $macaddr = $1;
                        }
                }

                my $expired = &lease_expired($lease_end);

                #If we're not searching for ONE IP and the lease isn't expired add it to the hash
                if (!$showip && !$expired) {
                        # Put it in the hash no matter what, if showip isn't set because it will overwrite
                        $hash{$ip}={"hostname"=>$hostname,"remoteid"=>$remoteid,"mac"=>$macaddr,"lease_end"=>$lease_end};       
                        }
                elsif ($showip && $ip =~ /$showip/ && !$expired) {
                        # Only populate the hash if it matches the passed in request
                        $hash{$ip}={"hostname"=>$hostname,"remoteid"=>$remoteid,"mac"=>$macaddr,"lease_end"=>$lease_end};
                }
                elsif ($expired) { 
                        #if ($showexpired) {
                        #       my $ctime = strftime("%m-%d-%Y %I:%M%p",localtime($lease_end));
                        #       print "Expired: $ip\t($ctime)\n"; 
                        #}
                        $expired_lease++;
                }
        
                $count++;
                }
}

close INFILE;

if ($showip) { 
        print "Showing IPs that match \"$showip\"\n";
        }

@list = sort(keys %hash);
my $total = scalar(@list) + 1;  

my $maxlen;
#get the length of the longest IP
for my $ip(@list) {
        if ($maxlen < length($ip)) { $maxlen = length($ip); }   
}

my $output;
#$output .= "Content-Type: text/html\n\n";
#$output .= "Checking $total ($count dupes) leases for validity\n";
print "Checking $total leases ($expired_lease expired) for validity\n";

my $ping = Net::Ping->new("icmp");
my $count=0;

foreach my $ip (@list) {
        my $result = $ping->ping($ip,$ping_ttl);
        if ($result) { 
                $result = "Alive";
                if ($color) { $result = GREEN $result; }
                $count++;
        }
        else { 
                $result = "Dead"; 
                if ($color) { $result = RED $result; }
        }
        
        # Get the hostname part 
        my $hostname;
        $hostname = $hash{$ip}->{'hostname'};
        if (!$hostname) { 
                $hostname = "*blank*"; 
                if ($color) { $hostname = BOLD BLUE $hostname; }
        }
        
        my $lease_end;
        #If we're showing when the leases expire
        if ($showexpired) {     
                #If the year is great than 2020 (my way of representing "never") than it's a 
                #lease that doesn't expire 
                if (strftime("%Y",localtime($hash{$ip}->{lease_end})) > 2020) { 
                        $lease_end = "Never"; 
                        if ($color) { $lease_end = BOLD WHITE $lease_end; }
                        $lease_end = &padtext($lease_end,length($lease_end)+2);
                }
                #Show the date in the date format
                else {
                        $lease_end = strftime($date_format,localtime($hash{$ip}->{lease_end}));
                        $lease_end = padtext($lease_end,length($lease_end)+2);
                }
        }
        else { $lease_end = ""; }

        # Get the agentid
        my $remoteid;
        $remoteid = $hash{$ip}->{'remoteid'} or $remoteid = "none";     

        my $mac;
        if ($showmac) { $mac = $hash{$ip}->{'mac'} or $mac = ""; }
        my $atm;
        if ($showatm) { $atm = $hash{$ip}->{'remoteid'} or $atm = ""; }
        if ($showatm) { $atm = &getoption82($atm); }

        $ip = padtext($ip,$maxlen + 2);
        $mac = padtext($mac,19);

        if (!$color) { $result = padtext($result,7); }
        else { $result = padtext($result,16); }

        $atm = padtext($atm,5);
        $hostname = padtext("($hostname)",20);
        
        my $outline = "$ip$result$mac$atm$lease_end$hostname\n";        
        print $outline;
}

my $percent;
if (!$total == 0) {
        $percent = sprintf("%2.f%%", ($count/$total) * 100);
}
else {
        $percent = "100%";
}
print "$count active leases ($percent)\n";
#$output .= "$count active leases ($percent)\n";
print $output;

sub getoption82 () {
        my $data = shift;
        if (!$data) { return -1; }

        my @list = split(":",$data);
        my $vpi = hex($list[9]);
        my $vci = (hex($list[10]) * 16) + hex($list[11]);
        return "$vpi-$vci";
}

sub padtext() {
        my $str = shift;
        my $len = shift;
        if (!$str || !$len) { return $str; } 

        $str = sprintf("%-${len}s",$str);
        return $str;
}

sub leasegm_to_epoch() {
        my ($sec,$min,$hours,$mday,$mon,$year); 

        if (my @list = $_[0] =~ /(\w+)\s+(\d+)\s+(\d{4})\/(\d{1,2})\/(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})/) {
                $sec = $list[7];
                $min = $list[6];
                $hours = $list[5];
                $mday = $list[4];
                $mon = $list[3] - 1;
                $year = $list[2] - 1900;
        }
        elsif (my @list = $_[0] =~ /ends never/) {
                $sec = 1;
                $min = 1;
                $hours = 1;
                $mday = 1;
                $mon = 1;
                $year = 132;
        }
        else { die("Whoa that aint good!\n"); } 

        #print "$sec,$min,$hours,$mday,$mon,$year\n";
        my $time_string = timegm($sec,$min,$hours,$mday,$mon,$year);

        return $time_string;
}

# Check to see if the lease has expired
sub lease_expired() {
        my $lease_time = shift;
        #Make sure a lease time is passed in
        if (!$lease_time) { return undef; }

        my $time_now = time();

        #If the lease is before right now, then the lease is still good
        if ($lease_time < $time_now) { return 1; }
        #Otherwise it has expired
        else { return 0; }
}

sub usage() {
        my $output .= "$0 
        -x  --expired           show lease expiration times
        -m  --mac               show lease MAC address
        -a  --atm               show lease ATM (Option 82) information
        -i  --IP=1.2.3.4        filter for ip 1.2.3.4 (regexp)
        -c  --color             show output in color for readability
";
}
