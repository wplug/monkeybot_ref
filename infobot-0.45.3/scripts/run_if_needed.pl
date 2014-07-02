#!/usr/bin/perl

# you will probably need to change $homedir
# and possibly the path to perl above

my $homedir = '/home/monkeybot/infobot-0.45.3';
my @ps = `ps auxwww`;

@result = grep !/grep/, @ps;
@result = grep !/su/, @result;
@result = grep /monkeybot$/, @result;

if (!@result) {
    print "trying to run new process\n";
    chdir($homedir) || die "can't chdir to $homedir";
    #system("nohup $homedir/infobot -i $homedir/files/irc.params > /dev/null &");
    system("nohup $homedir/monkeybot > /dev/null &");
} else {
    print "already running: \n";
    print "  @result\n";
}

