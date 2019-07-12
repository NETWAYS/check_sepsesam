#!/usr/bin/perl

# edited by hermanntoast at 11.07.2019 (www.hermann-toast.de / info@hermann-toast.de)

=pod

=head1 COPYRIGHT

 
This software is Copyright (c) 2009 NETWAYS GmbH, William Preston
                               <support@netways.de>

(Except where explicitly superseded by other copyright notices)

=head1 LICENSE

This work is made available to you under the terms of Version 2 of
the GNU General Public License. A copy of that license should have
been provided with this software, but in any event can be snarfed
from http://www.fsf.org.

This work is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 or visit their web page on the internet at
http://www.fsf.org.


CONTRIBUTION SUBMISSION POLICY:

(The following paragraph is not intended to limit the rights granted
to you to modify and distribute this software under the terms of
the GNU General Public License and is only of importance to you if
you choose to contribute your changes and enhancements to the 
community by submitting them to NETWAYS GmbH.)

By intentionally submitting any modifications, corrections or
derivatives to this work, or any other work intended for use with
this Software, to NETWAYS GmbH, you confirm that
you are the copyright holder for those contributions and you grant
NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
royalty-free, perpetual, license to use, copy, create derivative
works based on those contributions, and sublicense and distribute
those contributions and any derivatives thereof.

Nagios and the Nagios logo are registered trademarks of Ethan Galstad.

=head1 NAME

check_sepsesam

=head1 SYNOPSIS

Shows the status of backup jobs

=head1 OPTIONS

check_sepsesam [options] 

=over

=item   B<--warning>

warning level - if there are less than this number of successful backups then warn

=item   B<--critical>

critical level - if there are less than this number of successful backups then return critical

=item   B<--anyerror>

return critical if any backup was not successful (overrides warning/critical values)

=item   B<--noperfdata>

disable performance data (if graphing is not required)

=item   B<--lastcheck>

The time of the last check in seconds since 1 Jan 1970 (unixtime)

=item   B<--until>

Ignores any backups COMPLETED after this date (in the same format as lastcheck)

=item   B<--host>

The hostname to check.  Multiple values may be separated by commas

=item   B<--task>

The task name to check.  Multiple values may be separated by commas

=item   B<--outdated>

The time if the backup state switch to OUTDATED (in days)

=item   B<--lastbackup>

Only show the last backupjob (may shows outdated jobs)

=back

=head1 DESCRIPTION

This plugin checks the status of backups in the SEP Sesam Database.

It requires that the Sesam init script has been sourced; e.g.
add the following line to /etc/init.d/nagios 
. /var/opt/sesam/var/ini/sesam2000.profile

The plugin checks the status of all backups which match the Host / Task that
have been completed since the last check and delivers the data in multi-line
format.

It is possible to separate multiple hosts and/or tasks with commas.

Backups that are still running will not be included in the results.


=head1 EXAMPLES

check_sepsesam.pl -H host1 -T testbackup -l $LASTSERVICECHECK$

- checks all backups with name testbackup on host1 since the last
check; always returns OK


check_sepsesam.pl -H host1,host2,host3 -T testbackup,fullbackup -l $LASTSERVICECHECK$ -w 2 -c 1

- checks various tasks on host1, host2 and host3.  Returns a warning if less than 2 were successful.
Returns a critical if less than 1 was successful


check_sepsesam.pl -H host1,host2,host3 -T backup -l $LASTSERVICECHECK$ --anyerror

- returns a critical if any of the matching backups failed


check_sepsesam.pl --lastcheck `date -d "yesterday 08:00" +%s` --until `date -d "today 08:00" +%s` --anyerror

- checks all hosts between two dates


check_sepsesam.pl -H host1,host2,host3 --lastbackup --usehtml --outdated=7

- returns a the last backup with html tags und mark backups older then 7 days as OUTDATED


=cut

use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my @results;
my %taghash;
my @temparr = split(/\//, $0);
my $filename = $temparr[$#temparr];

my $sql_bin = 'sm_db';
my $sql_path = undef;
my $lastCheck = undef;
my $outdated = undef;
my $lastbackup;
my $enablemsg;
my $usehtml;
my $help = undef;
my $task = undef;
my $errors = 0;
my $warnings = 0;
my $completed = 0;
my $after = '1970-01-01 00:00:00';
my $hostname = ''; 
my $warn = 0;
my $crit = 0;
my $exitval = 'UNKNOWN';


Getopt::Long::Configure('bundling');
my $clps = GetOptions(
	"l|lastcheck=i" => \$lastCheck,
	"o|outdated=i" => \$outdated,
	"lastbackup" => \$lastbackup,
	"enablemsg" => \$enablemsg,
	"usehtml" => \$usehtml,
	"u|until=i"     => \$until,
	"H|host=s"      => \$hostname,
	"T|task=s"      => \$task,
	"w|warning=i"   => \$warn,
	"c|critical=i"  => \$crit,
	"anyerror!"     => \$anyerror,
	"n|noperfdata!" => \$noperfdata,
	"h|help"    => \$help
);

pod2usage( -verbose => 2, -noperldoc => 1) if ($help);

if ($lastCheck)
{
	# only look for backups newer than the last check
	# lastcheck is time_t
	# N.B. we are assuming that the times in the DB are local times
	$after = timetToIso8601($lastCheck);
}  

foreach my $i (split(':', $ENV{'PATH'})) {
	if (-x "$i/$sql_bin") {
		$sql_path = $i; 
		last;
	}
}

nagexit('UNKNOWN', "Binary not found ($sql_bin).\nMaybe you want to source the init script (/var/opt/sesam/var/ini/sesam2000.profile)?") unless defined($sql_path);

my $query = "";

if ($lastbackup) {
	# query to get only the last backupjob
	$query .= "SELECT DISTINCT ON (r.task) c.name, r.task, l.name as location, r.start_time, r.stop_time, r.throughput, r.state, r.msg, (ROUND((r.blocks/1024),2)) as size FROM clients AS c LEFT JOIN results AS r ON r.client = c.name LEFT JOIN locations AS l ON c.location=l.id  WHERE r.task IS NOT NULL";
}
else {
	$query .= "select c.name,l.name as location,r.task,r.start_time,r.stop_time,(round((r.blocks/1024.),2)) as size,r.throughput,r.state,r.msg from clients as c left join locations as l on c.location=l.id  left join results as r on r.client=c.name where r.stop_time >'".$after."' and r.state<>'a'";
}

$query .= " and r.stop_time <='".timetToIso8601($until)."'" if ($until);

if ($hostname =~ /,/) {
	# we have a list of multiple hosts
	my @hostlist = split(',', $hostname);
	$query .= " and c.name in ('".join("','", @hostlist)."')";
}
elsif ($hostname ne '') {
	$query .= " and c.name ='".$hostname."'";
}

if ($task) {
	if ($task =~ /,/) {
		# we have a list of multiple tasks
		my @tasklist = split(',', $task);
		$query .= " and r.task in ('".join("','", @tasklist)."')";
	}
	else {
		$query .= " and r.task ='".$task."'";
	}
}

if($lastbackup) {
	# sort to get the last backupjob
	$query .= " ORDER BY r.task, r.start_time DESC";
}

print "$sql_path/$sql_bin \"$query\"\n";
my $retval = `$sql_path/$sql_bin "$query"`;

nagexit('UNKNOWN', "$sql_path/$sql_bin returned error ".($? >> 8).".\nMaybe you want to source the init script (/var/opt/sesam/var/ini/sesam2000.profile) in your start script?") if ($? gt 0);

foreach my $i (split('\n', $retval)) {
	push (@results, {parseReply($i)}) if ($i =~ /^\|/);
}


foreach my $i (@results) {
	my $status = convertState($$i{'state'});

	# Check for backup age (older then X days (60*60*24*X))
	if ($outdated ne '') {
		$taskunixtime = `date -d "$$i{'start_time'}" +%s`;
		$currentunixtime = `date +%s`;

		if (($currentunixtime - $taskunixtime) > (60 * 60 * 24 * $outdated)) {
			$status = "OUTDATED";
		}
	}
			
	# format size to a readable string
	my $size = $$i{'size'};
	$size =~ s/ \/://g;
	$size =~ s/NULL/0/;
	
	if ($size  > (1024 * 1024)) {
		$size = sprintf("%.2f", (($size / 1024) / 1024));
		$size .= 'TB';
	}
	elsif ($size  > 1024) {
		$size = sprintf("%.2f", ($size / 1024));
		$size .= 'GB';
	}
	else {
		$size .= 'MB';
	}
			
	# monitoring systems like check-mk like html output
	if ($usehtml) {
		if ($status eq 'FAILED' || $status eq 'BROKEN') {
			$statusline .= "<b class=\"stmark state2\">CRIT</b> <b>$statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size</b>";
			($enablemsg) ? $statusline .= "<br><span style=\"color:gray\"> Message: $$i{'msg'}</span>" : "";
			$statusline .= "\'<br>";
		}
		elsif ($status eq 'UNKNOWN' || $status eq 'WARNING') {
			$statusline .= "<b class=\"stmark state1\">WARN</b> $statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size";
			($enablemsg) ? $statusline .= "<br><span style=\"color:gray\"> Message: $$i{'msg'}</span>" : "";
			$statusline .= "\'<br>";
		}
		elsif ($status eq 'OUTDATED') {
			$statusline .= "<b class=\"stmark\" style=\"color:white;background-color:#CC2EFA\">OUT</b> $statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size\'<br>";
		}
		elsif ($status eq 'RUNNING') {
			$statusline .= "<b class=\"stmark\" style=\"color:white;background-color:blue\">RUNNING</b> $statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size\'<br>";
		}
		else {
			$statusline .= "<b class=\"stmark\" style=\"color:white;background-color:green\">OK</b> $statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size\'<br>";
		}
	}
	else {
		if ($status eq 'FAILED' || $status eq 'BROKEN') {
			$statusline .= "$statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size";
			($enablemsg) ? $statusline .= "\n Message: $$i{'msg'}" : "";
			$statusline .= "\' \n";
		}
		elsif ($status eq 'UNKNOWN' || $status eq 'WARNING') {
			$statusline .= "$statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size";
			($enablemsg) ? $statusline .= "\n Message: $$i{'msg'}" : "";
			$statusline .= "\' \n";
		}
		elsif ($status eq 'OUTDATED') {
			$statusline .= "$statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size\' \n";
		}
		else {
			$statusline .= "$statusCode $$i{'task'} - \'$status  Started at: $$i{'start_time'} Size: $size\' \n";
		}
	}

	# The units are actually GB/h but this may cause problems with some grapher addons :-(
	my $throughput = $$i{'throughput'};
	$throughput =~ s/[ \/:]//g;
	$throughput =~ s/NULL/0GBh/;

	$perfdata .= " ".uniqueTag($$i{'location'}.'_'.$$i{'name'}.'_'.$$i{'task'})."::$filename::";
	$perfdata .= "size=$size tput=$throughput";
	$perfdata .= " durn=".timeDiffSecs($$i{'start_tim'}, $$i{'stop_time'});
			
	# Count the backup states
	next if ($status eq 'RUNNING');
	$errors++ if ($status eq 'FAILED' || $status eq 'BROKEN' || $status eq 'OUTDATED');
	$warnings++ if ($status eq 'UNKNOWN' || $status eq 'WARNING');
	$completed++;
	
} # End for loop

my $retstr = "";

if ($usehtml) {
	$retstr = ($completed - $errors)." of $completed backups successful with $warnings warnings <br><br>";
}
else {
	$retstr = ($completed - $errors)." of $completed backups successful with $warnings warnings \n";
}

if ($errors > 0 ) {
	$exitval = "2 SEP-Sesam-$hostname - CRITICAL";
}
elsif (($completed - $errors) < $crit) {
	$exitval = "2 SEP-Sesam-$hostname - CRITICAL";
}
elsif ($warnings > 0) {
	$exitval = "1 SEP-Sesam-$hostname - WARNING";
}
else {
	$exitval = "0 SEP-Sesam-$hostname - OK";
}

$perfdata = " sepsesam::check_multi::plugins=$completed time=0.00".$perfdata;

$perfdata = '' if ($noperfdata);
nagexit($exitval, "$retstr $perfdata $statusline");

sub uniqueTag {
	my ($tag) = @_;

	$tag =~ s/[^a-zA-Z0-9_\.-]//g;

	my $suffix = '';
	
	while (exists($taghash{$tag.$suffix})) {
		$suffix++;
	}
	
	$taghash{$tag.$suffix} = '1';
	return ($tag.$suffix);
}


sub parseReply {
	# Creates a hash from the reply

	my ($line) = @_;
	my %out;

	for my $i (split('\|', $line))
	{
		$i =~ /([^=]*)=(.*)/ or next;
		$out{$1} = $2;
	}

	return %out;
}

sub nagexit {
	my $errlevel = shift;
	my $string = shift;

	print "$errlevel: $string\n";
	exit $ERRORS{$errlevel};
}

sub timetToIso8601 {
	# convert a time_t value to YYYY-MM-DD HH:MM:SS

	my ($t) = @_;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($t);
	return (sprintf('%04d-%02d-%02d %02d:%02d:%02d', ($year + 1900), ($mon + 1), $mday, $hour, $min, $sec));
}

sub timeDiffSecs {
	my ($start, $end) = @_;

	my $timediff=localtime($end)-localtime($start);
	return (abs($timediff));
}

sub timeDiff {
	my ($start, $end) = @_;

	my $timediff=localtime($end)-localtime($start);

	my $days = int($timediff / 86400);
	$timediff = $timediff - ($days * 86400);
	my $hours = int($timediff / 3600);
	$timediff = $timediff - ($hours * 3600);
	my $mins = int($timediff / 60);
	$timediff = $timediff - ($mins * 60);

	return (0) if ($days > 99);

	return (sprintf('%02d:%02d:%02d:%02s', $days, $hours, $mins, $timediff));
}

sub convertState {
	# convert the sesam state to a suitable return value

	my %stateMap = (
		'0' => 'OK',
		'X' => 'FAILED',
		'a' => 'RUNNING',
		'1' => 'WARNING',
		'3' => 'BROKEN'
	);
	
	my ($state) = @_;

	return ($stateMap{$state}) if defined($stateMap{$state});
	return 'UNKNOWN';
}

