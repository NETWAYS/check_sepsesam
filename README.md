check_sepsesam
==============

This plugin checks the status of backups in the SEP Sesam Database.

It requires that the Sesam init script has been sourced; e.g. add the
following line to `/etc/init.d/icinga` 

    . /var/opt/sesam/var/ini/sesam2000.profile
	
or type

	source /var/opt/sesam/var/ini/sesam2000.profile
	
in the bash command line to integrade in script or try on command line.

The plugin checks the status of all backups which match the Host / Task
that have been completed since the last check and delivers the data in
multi-line format.

It is possible to separate multiple hosts and/or tasks with commas.

Backups that are still running will not be included in the results.
    
### Usage

    check_sepsesam [options]

    --warning
        warning level - if there are less than this number of successful
        backups then warn

    --critical
        critical level - if there are less than this number of successful
        backups then return critical

    --anyerror
        return critical if any backup was not successful (overrides
        warning/critical values)

    --noperfdata
        disable performance data (if graphing is not required)

    --lastcheck
        The time of the last check in seconds since 1 Jan 1970 (unixtime)

    --until
        Ignores any backups COMPLETED after this date (in the same format as
        lastcheck)

    --host
        The hostname to check. Multiple values may be separated by commas

    --task
        The task name to check. Multiple values may be separated by commas
		
	--outdated
		The time if the backup state switch to OUTDATED (in days)
	
	--lastbackup
		Only show the last backupjob (may shows outdated jobs)
		
	--enablemsg
		Enable error message output
		
	--usehtml
		Use HTML output for monitoring systems like check-mk
		
	--debug
		Enable debug mode to show all messages like sql query
		
### Examples

check_sepsesam.pl
- show all tasks from all hosts in database

check_sepsesam.pl -H <HOSTNAME>
- show all task from <HOSTNAME> in database

check_sepsesam.pl -H <HOSTNAME1>, <HOSTNAME2>, <HOSTNAME3>
- show all task from <HOSTNAME1>, <HOSTNAME2>, <HOSTNAME3> in database

check_sepsesam.pl -H <HOSTNAME> --lastcheck `date -d "yesterday 08:00" +%s` --until `date -d "today 08:00" +%s`
- show all task from <HOSTNAME> between yesterday 8 AM to today 8 AM

check_sepsesam.pl -H <HOSTNAME> --lastbackup
- show all task from <HOSTNAME> but only the newest backups (maybe outdated)

check_sepsesam.pl -H <HOSTNAME> --lastbackup --outdated=7
- show all task from <HOSTNAME> but only the newest backups and mark all backups older then 7 days as OUTDATED

check_sepsesam.pl -H <HOSTNAME> --lastbackup --outdated=7 --enablemsg
- show all task from <HOSTNAME> but only the newest backups and mark all backups older then 7 days as OUTDATED
  and show the error message to all FAILED and WARNING states

check_sepsesam.pl -H <HOSTNAME> --lastbackup --outdated=7 --enablemsg --usehtml
- show all task from <HOSTNAME> but only the newest backups and mark all backups older then 7 days as OUTDATED
  and show the error message to all FAILED and WARNING states and format with HTML (for eg. CheckMK)

check_sepsesam.pl -H <HOSTNAME> --lastbackup --outdated=7 --enablemsg --usehtml --noperfdata
- show all task from <HOSTNAME> but only the newest backups and mark all backups older then 7 days as OUTDATED
  and show the error message to all FAILED and WARNING states and format with HTML (for eg. CheckMK)
  and disable all performance data (performance data make problems with some monitoring systems)










