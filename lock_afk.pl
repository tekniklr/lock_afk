#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);
use Tk;

# This program is basically a wrapper for xlock, allowing the user to set
# a message to scroll in the marquee.
# It has other bells and whistles, like forcing offlineimap and telling me
# to go home at the end of the day.
# This is also my first TK interface, which was kinda fun to figure out.

###########################################################################
## Configuration!
###########################################################################

# debugging- don't run xlock, instead print the command that would have been
# run; set to 0 for normal operation
my $debug = 0;

# away message text.  $away and $back will be filled in from the TK window
# make sure this remains in this form: (note all quotes)
# '$message = "string"';
my $message_struct = '$message = "Teri is $away. She intends to return $back."';

# This message is mirrored in the TK window as a reminder of the structure
# of the away message.
my $tk_where_prompt = "Teri is...";
my $tk_when_prompt = "She intends to return...";

# the below font names come from xfontsel

# look and feel of marquee
my $font_name = 'vtc nightofthedrippydead'; # use xfontsel for available fonts
my $font_size = 80;

# look and feel of TK window
my $tk_font_name = 'latin modern sansquotation';
my $tk_font_size = 150;


###########################################################################
## Stuff what happens happens here!
###########################################################################
START:

# default values for the where and the when
my $overnight = 0;
my $away_default = 'having lunch';
my $back_default = strftime "@ %H:%M", localtime(time + 3600); # now += 1 hour
my $time_now = strftime "%H.%M", localtime;
my $day_now = strftime "%u", localtime;
$debug and warn "Day now: ${day_now}; Time now: ${time_now}\n";
if (($day_now == 5) && ($time_now > 16)) {
	$away_default = 'gone for the weekend';
	$back_default = 'Monday morning';
	$overnight = 1;
}
elsif ($time_now > 16) {
	$away_default = 'gone for the day';
	my $tomorrow = strftime "%A", localtime(time + 86400);
	$back_default = "${tomorrow} morning";
	$overnight = 1;
}
if ($overnight == 1) {
	# if we are leaving before the last lock_afk finished, kill it
	my $scriptname = $0;
	$scriptname =~ s/.*\/([-_0-9a-zA-Z]+\.pl)/$1/;
	$debug and warn "Looking for other running instances of $scriptname\n";
	my $lock_list = `pgrep $scriptname`;
	my @lock_procs = split(/\n/, $lock_list);
	foreach my $proc (@lock_procs) {
		if ($proc != $$) {
			$debug and warn "Killing olf $scriptname process $proc\n";
			!$debug and system("kill $proc");
		}
	}
}
my ($away, $back);


# compile this here because it appears in many places below
my $tk_font = "-*-${tk_font_name}-*-*-*-*-*-${tk_font_size}-*-*-*-*-*-*";


# prompt for values with a TK window, providing defaults
my $prompt = MainWindow->new();
my $nag;

$prompt->configure(-title=>'Leaving so soon?',-background=>'black');
$prompt->Label(-text=>'Fill in the blanks:',-background=>'black',-foreground=>'white',-font=>$tk_font)->pack;

# label and entry for 'where?'
my $prompt_where_frame = $prompt->Frame(-relief=>'groove',-background=>'black')->pack(-side=>'top',-fill=>'x');
my $prompt_where_label = $prompt_where_frame->Label(-text=>$tk_where_prompt,-background=>'black',-foreground=>'white',-font=>$tk_font)->pack(-side=>'left',-fill=>'x',-anchor=>'e');
my $prompt_where_entry = $prompt_where_frame->Entry(-textvariable=>\$away,-width=>50,-background=>'white',-font=>$tk_font)->pack(-side=>'right',-pady=>3);
$prompt_where_entry->insert('end',$away_default);
$prompt_where_entry->bind('<Return>'=>\&leave);

# label and entry for 'when?'
my $prompt_when_frame = $prompt->Frame(-relief=>'groove',-background=>'black')->pack(-side=>'top',-fill=>'x');
my $prompt_when_label = $prompt_when_frame->Label(-text=>$tk_when_prompt,-background=>'black',-foreground=>'white',-font=>$tk_font)->pack(-side=>'left',-fill=>'x',-anchor=>'e');
my $prompt_when_entry = $prompt_when_frame->Entry(-textvariable=>\$back,-width=>50,-background=>'white',-font=>$tk_font)->pack(-side=>'right',-pady=>3);
$prompt_when_entry->insert('end',$back_default);
$prompt_when_entry->bind('<Return>'=>\&leave);

# submit button
my $prompt_submit_frame = $prompt->Frame(-background=>'black')->pack(-side=>'top',-anchor=>'s');
my $prompt_submit = $prompt_submit_frame->Button(-text=>'Get out of here!',-background=>'black',-foreground=>'white',-command=>\&leave,-font=>$tk_font)->pack(-side=>'bottom',-pady=>3);


# this initializes TK to do stuff, it never returns
MainLoop();


# once the submit button is clicked, this happens:
sub leave {
	$prompt->destroy;
	$debug and warn "Leaving!\n";

	# keep track of when I left
	my $gone_day = strftime "%j", localtime; # day of the year

	# sync mail one last time, as it won't run automagically when 
	# xlock is up
	if (!$debug) {
		warn "Checking mail...\n";
		system("offlineimap &");
	}

	my $message = '';
	eval $message_struct;

	# compile message
	$message =~ s/"/\\"/g;

	# compile command to be run
	my $command = "xlock -message \"${message}\" -info \"${message}\" -mode marquee -messagefont '-*-${font_name}-*-*-*-*-${font_size}-*-*-*-*-*-*-*'";

	if ($debug > 1) {
		print "$command\n";
		exit 0;
	}
	system($command); # will run command and wait for it to finish

	# if I've returned on a different day than I left, remind me to go home
	# in 8 hours
	my $back_day = strftime "%j", localtime; # day of the year
	if ($gone_day != $back_day) {
		my $hours = 8;
		$debug and warn "Good morning.  I'll remind you to leave in $hours hours.\n";
		sleep $hours*3600;
		nag();
	}
}

# will remind me to go home, possibly forcibly
sub nag {

	# nag with a TK window
	$nag = MainWindow->new();
	$nag->configure(-title=>'You\'ve been here long enough!',-background=>'black');
	$nag->Label(-text=>"Stop being such a little trooper.\nYou are only paid for 39 hours!",-background=>'black',-foreground=>'white',-font=>$tk_font)->pack;
	# submit button
	my $nag_submit_frame = $nag->Frame(-background=>'black')->pack(-side=>'top',-anchor=>'s');
	my $prompt_nag = $nag_submit_frame->Button(-text=>'Yeah, you\'re right...',-background=>'black',-foreground=>'white',-command=>\&acquiesce,-font=>$tk_font)->pack(-side=>'bottom',-pady=>3);

	MainLoop();
}

# will initialize syncing via unison, and then restart program
sub acquiesce {
	$nag->destroy;
	$debug and warn "Acquiescing!\n";
	system("/home/tekniklr/mystuff/programs/sync_charnel.pl");
	exec("/home/tekniklr/mystuff/programs/lock_afk.pl");
}
