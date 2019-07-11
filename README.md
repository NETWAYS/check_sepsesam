check_sepsesam
==============

This plugin checks the status of backups in the SEP Sesam Database.

It requires that the Sesam init script has been sourced; e.g. add the
following line to `/etc/init.d/icinga` 

    . /var/opt/sesam/var/ini/sesam2000.profile

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

