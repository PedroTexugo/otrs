# --
# Kernel/System/Log/File.pm - file log backend 
# Copyright (C) 2002-2003 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: File.pm,v 1.5 2003-01-03 00:34:23 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see 
# the enclosed file COPYING for license information (GPL). If you 
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::Log::File;

use strict;

use vars qw($VERSION);
$VERSION = '$Revision: 1.5 $ ';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/g;

umask 002;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {}; 
    bless ($Self, $Type);

    # get logfile location
    $Self->{LogFile} = $Param{ConfigObject}->Get('LogModule::LogFile') 
      || die 'Need LogModule::LogFile param in Config.pm';

    return $Self;
}
# --
sub Log { 
    my $Self = shift;
    my %Param = @_;
    # --
    # open logfile
    # --
    if (open (LOGFILE, ">> $Self->{LogFile}")) {
        print LOGFILE "[".localtime()."]";
        if ($Param{Priority} =~ /debug/i) {
            print LOGFILE "[Debug][$Param{Module}][$Param{Line}] $Param{Message}\n";
        }
        elsif ($Param{Priority} =~ /info/i) {
            print LOGFILE "[Info][$Param{Module}] $Param{Message}\n";
        }
        elsif ($Param{Priority} =~ /notice/i) {
            print LOGFILE "[Notice][$Param{Module}] $Param{Message}\n";
        }
        elsif ($Param{Priority} =~ /error/i) {
            # --
            # print error messages to LOGFILE
            # --
            print LOGFILE "[Error][$Param{Module}][$Param{Line}] $Param{Message}\n";
        }
        else {
            # print error messages to STDERR
            print STDERR "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";
            # and of course to logfile
            print LOGFILE "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";
        }
        # --
        # close file handle
        # --
        close (LOGFILE);
        return 1;
    }
    else {
        # --
        # print error screen
        # --
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return; 
    }
}
# --
1;
