# --
# Kernel/System/CustomerAuth/LDAP.pm - provides the ldap authentification 
# Copyright (C) 2002-2003 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: LDAP.pm,v 1.3 2003-01-03 00:34:23 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see 
# the enclosed file COPYING for license information (GPL). If you 
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --
# Note: 
# available objects are: ConfigObject, LogObject and DBObject
# --

package Kernel::System::CustomerAuth::LDAP;

use strict;
use Net::LDAP;

use vars qw($VERSION);
$VERSION = '$Revision: 1.3 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

# --
sub new {
    my $Type = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    # --
    # check needed objects
    # --
    foreach ('LogObject', 'ConfigObject', 'DBObject') {
        $Self->{$_} = $Param{$_} || die "No $_!";
    }

    # --
    # Debug 0=off 1=on
    # --
    $Self->{Debug} = 0;

    # --
    # get ldap preferences
    # --
    $Self->{Host} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::Host')
     || die "Need Customer::AuthModule::LDAPHost in Kernel/Config.pm";
    $Self->{BaseDN} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::BaseDN')
     || die "Need Customer::AuthModule::LDAPBaseDN in Kernel/Config.pm";
    $Self->{UID} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::UID')
     || die "Need Customer::AuthModule::LDAPBaseDN in Kernel/Config.pm";
    $Self->{SearchUserDN} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::SearchUserDN') || '';
    $Self->{SearchUserPw} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::SearchUserPw') || '';
    $Self->{GroupDN} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::GroupDN') || '';
    $Self->{AccessAttr} = $Self->{ConfigObject}->Get('Customer::AuthModule::LDAP::AccessAttr') || '';
   
    return $Self;
}
# --
sub Auth {
    my $Self = shift;
    my %Param = @_;
    # --
    # check needed stuff
    # --
    foreach (qw(User Pw)) {
      if (!$Param{$_}) {
        $Self->{LogObject}->Log(Priority => 'error', Message => "Need $_!");
        return;
      }
    }
    # --
    # get params
    # --
    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # --
    # just in case for debug!
    # --
    if ($Self->{Debug} > 0) {
        $Self->{LogObject}->Log(
          Priority => 'notice',
          Message => "CustomerUser: '$Param{User}' tried to login with Pw: '$Param{Pw}' (REMOTE_ADDR: $RemoteAddr)",
        );
    }

    # --
    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    # --
    my $LDAP = Net::LDAP->new($Self->{Host}) or die "$@";
    if (!$LDAP->bind(dn => $Self->{SearchUserDN}, password => $Self->{SearchUserPw})) {
        $Self->{LogObject}->Log(
          Priority => 'error',
          Message => "First bind failed!",
        );
        return;
    }
    # --
    # perform user search
    # --
    my $Filter = "($Self->{UID}=$Param{User})";
    my $Result = $LDAP->search ( 
        base   => $Self->{BaseDN},
        filter => $Filter, 
    ); 
    # --
    # get whole user dn
    # --
    my $UserDN = '';
    foreach my $Entry ($Result->all_entries) {
        $UserDN = $Entry->dn();
    }
    # --
    # log if there is no LDAP user entry
    # --
    if (!$UserDN) {
        # --
        # failed login note
        # --
        $Self->{LogObject}->Log(
          Priority => 'notice',
          Message => "CustomerUser: $Param{User} login failed, no LDAP entry found!".
            "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr).",
        );
        # --
        # take down session
        # --
        $LDAP->unbind;
        return;
    }

    # --
    # check if user need to be in a group!
    # --
    if ($Self->{AccessAttr} && $Self->{GroupDN}) {
        # --
        # just in case for debug
        # --
        if ($Self->{Debug} > 0) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message => "check for groupdn!",
            );
        } 
        # --
        # search if we're allowed to
        # --
        my $Filter2 = "($Self->{AccessAttr}=$Param{User})";
        my $Result2 = $LDAP->search (
            base   => $Self->{GroupDN},
            filter => $Filter2 
        );
        # --
        # extract it
        # --
        my $GroupDN = '';
        foreach my $Entry ($Result2->all_entries) {
            $GroupDN = $Entry->dn();
        }
        # --
        # log if there is no LDAP entry
        # --
        if (!$GroupDN) {
            # --
            # failed login note
            # --
            $Self->{LogObject}->Log(
              Priority => 'notice',
              Message => "CustomerUser: $Param{User} login failed, no LDAP group entry found".
                "GroupDN='$Self->{GroupDN}', Filter='$Filter2'! (REMOTE_ADDR: $RemoteAddr).",
            );
            # --
            # take down session 
            # --
            $LDAP->unbind;
            return;
        }
    }        
    
    # --
    # bind with user data -> real user auth.
    # --
    $Result = $LDAP->bind(dn => $UserDN, password => $Param{Pw});
    if ($Result->code) {
        # --
        # failed login note
        # --
        $Self->{LogObject}->Log(
          Priority => 'notice',
          Message => "CustomerUser: $Param{User} login failed: '".$Result->error."' (REMOTE_ADDR: $RemoteAddr).",
        );
        # --
        # take down session
        # --
        $LDAP->unbind;
        return;
    }
    else {
        # --
        # login note
        # --
        $Self->{LogObject}->Log(
          Priority => 'notice',
          Message => "CustomerUser: $Param{User} logged in (REMOTE_ADDR: $RemoteAddr).",
        );
        # --
        # take down session
        # --
        $LDAP->unbind;
        return 1;
    }
}
# --

1;

