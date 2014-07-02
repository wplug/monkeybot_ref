# Infobot user extension stubs 
# $Id: myRoutines.pl,v 1.43 2003/12/27 17:21:00 jeremy Exp $

use DBI;
use Net::Dict;

# Dictionary information
@dictOptions = qw(elements web1913 wn gazetteer jargon foldoc easton hitchcock devils world02 vera);
$dictServer = "dict.org";
$dictdb = "wn"; # Default database

# put your routines in here.

@howAreYa = ("just great", "peachy", "mas o menos", 
	 "you know how it is", "eh, ok", "pretty good. how about you");

@factoid = ("what\'s that you want?", 
            "Quiet you! I don't feel like reciting a fact right now.",
	    "I\'m just a bot...",
	    "Why don\'t you say something witty?"
	   );

# Idle out in X seconds (between 1-2 hours)
$IDLE_OUT = int(rand(3660) + 3600);

# Word length for WOTD game
$WOTD_LENGTH = 4;

# Maximum number of times to go off about a subject
$MAX_CONVERSE = 8;


sub myRoutines {
    # called after it decides if it's been addressed.
    # you have access tothe global variables here, 
    # which is bad, but anyway.

    # you can return 'NOREPLY' if you want to stop
    # processing past this point but don't want 
    # an answer. if you don't return NOREPLY, it
    # will let all the rest of the default processing
    # go to it. think of it as 'catching' the event.

    # $addressed is whether the infobot has been 
    #			named or, if a private or standalone
    #			context, addressed is always 'true'

    # $msgType can be 'public', 'private', maybe 'dcc_chat'

    # $who is the sender of the message

    # $message is the current state of the input, after
    #		  the addressing stuff stripped off the name

    # $origMessage is the text of the original message before
    #			  any normalization or processing

    # you have access to all the routines in urlIrc.pl too,
    # of course.

    # example:

    # Give the bot a method to strike up conversations
    $last_comment = time;
    
    #	I'm disabling this code until I can figure out why it's breaking
    # billings 03/07/2004
    #$SIG{ALRM}    = sub {
    #	&say(&make_random_statement(&rand_db())); 
    #	$IDLE_OUT = int(rand(3660) + 3600);
    #};
    #alarm($IDLE_OUT);
    
    if ($addressed) {
	# only if the infobot is addressed
	if ($message =~ /how (the hell )?are (ya|you)( doin\'?g?)?\?*$/) {
	    return $howAreYa[rand($#howAreYa)];
	}elsif($message =~ /factoid$/){
	    
	    my $val = &make_random_statement(&rand_db());
	    return $val;
	    # Copy the word of the day to $wotd
	}elsif($message =~ /wotd ([a-z0-9]+)+/){
	    my $tmp = $1;
	    if(length($tmp) >= $WOTD_LENGTH){ 
		$WOTD = $tmp;
		$WOTD_AGE = time;
		$WOTD_USER = $who;
		&log_new_WOTD($WOTD,$who);
		return ("Gotcha. Word of the day saved ($WOTD).");
	    }
	}elsif($message =~ /what is the wotd\?/i){
	    
	    return ("$who: The word is $WOTD. I learned it from $WOTD_USER on " . strftime("%c",localtime($WOTD_AGE)) ) if $WOTD;
	    return ("$who: I have not picked a word, yet.");
	}elsif($message =~ /tell (.*) about (.*)/i){
	    # TODO make tell_user send /msgs, but ensure that the people are in
	    # the channel before doing this ... no telling to people outside of
	    # #wplug
	    &tell_user($1,$2);
	    return "NOREPLY";
	}elsif($message =~ /kick (.*)\'s ass[!]+$/i){
	    &say("\cAACTION kicks $1\'s ass! \cA");   
	    return("NOREPLY");
	    
	    # TODO broken ... 
	    # Check for request to being a converstation
#       }elsif ($message =~ /converse\s+(.*)/i){  
#          &converse($1);
#	      return "NOREPLY";
	    
	} 
	

# NOTE: From here on out, we are not being addressed!
	
	} else {
	# we haven't been addressed, but we are still listening
	    if($message =~ /$WOTD/i){
		   my $statement = &exclaim_wotd();
		   if($statement !~ /^\s*$/) {
		   	&say($statement);
		   }
		   return "NOREPLY";
		}

    }

#    if($message =~ /^\S*:?define [ \S]+/i){
#	&say("$who: OK ... checking on that for you.");
#    	my @response = &dictionary($message);
#	if($#response < 0){
#		return("$who: Sorry, I don't know anything about that.");
#	}else{
#		foreach $reply (@response){
#			&msg($who, "$reply") if ($reply !~ /^[\s\n]*$/);
#		}
#	}
#	return "NOREPLY";
#   }
	
    # another example: rot13 
    #if ($message =~ /^rot13\s+(.*)/i) {
	#   # rot13 it
	#   my $reply = $1;
	#   $reply =~ y/A-Za-z/N-ZA-Mn-za-m/;
	#   return $reply;
    #}

    # Scan for words to use for the wotd
	# but don't be too agressive. This will prevent the user from guessing the
	# word out of something that was recently said. Be sure not to use words 
	# when $who is not known.
	if(!$WOTD && ($who ne "") && (int(rand(100)) < 2)){
	   my @tmp = split(/\s/,$message);
	   @tmp = grep(/.../,@tmp); # Remove the words that are <= 3 chars long
	   $WOTD = $tmp[rand($#tmp)];
	   $WOTD =~ s/[^\d\w]+//g;
       $WOTD_AGE = time;
	   $WOTD_USER = $who;
	   if(length($WOTD) <= $WOTD_LENGTH){
	      $WOTD = undef;
		  $WOTD_AGE = undef;
		  $WOTD_USER = undef;
	   }else{
	      &log_new_WOTD($WOTD,$who);
  	      #&say("I just set $WOTD as the wotd");
	   }
	}

	# Age out today's word of the day
	if($WOTD_AGE && (time - $WOTD_AGE) > 86400){ # There are 86,400 seconds in one day
	   #&say("The wotd ($WOTD) just expired.");
	   $WOTD = undef;
	   $WOTD_AGE = undef;
	   $WOTD_USER = undef;
	}


	

# I've commented these commands out, since the mysql database
# is no longer online.  
# --Tue Feb  4 13:34:47 EST 2003
# --billings
#    if($message =~ /^(when is the )?next (meeting|GUM|install)\?/i){
#	   &report_meeting_information($2);
#	   return "Make a note of it!";
#	}
#	if($message =~ /^wplug news/i){
#	    &report_news_listing();
#		return "";
#    }
#	if($message =~ /^read wplug news ([0-9]+)+/i){
#	    &report_news_information($1);
#		return "";
#    }
	
    return undef;	# do nothing and let the other routines have a go
    # Extras.pl is called next; look there for more complex examples.
}

sub report_meeting_information($type){
   
   my $type = shift;
   my $statement = "";
   my $sth; my $dbh;
   
   return unless $type;

   my $dbh = DBI->connect("DBI:mysql:announcements", 'announcements','midnight' ) || return $dbh->errstr;
   
   $statement = "SELECT * from announcements ORDER BY serial DESC LIMIT 1";
   $sth = $dbh->prepare($statement) || return  $dbh->errstr;
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();

   SWITCH: {
     if($type =~ /(meeting|GUM)/i){
        &say("$who: The next meeting is on " . $ref->{'nextmeeting'});
		&say("Where: " . $ref->{'nextmeetingloc'});
		&say($ref->{'meetingdetails'});

        last SWITCH;
	 }
	 if($type =~ /install/){
        &say("$who: The next install fest is on " . $ref->{'nextfest'});
		&say("Where: " . $ref->{'nextfestloc'});
		&say($ref->{'festdetails'});

	    last SWITCH;
     }
	 
   }
   
   $sth->finish();

   # Disconnect from the database.
   $dbh->disconnect();

   return;
}

# Get a request from the user and list the news headers
sub report_news_listing(){

   my $statement = "";
   my $sth; my $dbh;

   my $dbh =  DBI->connect("DBI:mysql:web", 'web','midnight' ) || return $dbh->errstr;
   $statement = "SELECT id,title,date FROM news ORDER BY id DESC LIMIT 5";
   $sth = $dbh->prepare($statement) || return  $dbh->errstr;
   $sth->execute();
   &msg($who, "News for #wplug");
   while(my $ref = $sth->fetchrow_hashref()){
      &msg($who, "[$ref->{id}] $ref->{title} ($ref->{date})");
   }
   &msg($who, "use 'read wplug news <#>' to view the specific item");

   $dbh->disconnect;
   return undef;

}

# Get a news item based on the id
sub report_news_information($id){
   
   my $id = shift;
   my $statement = "";
   my $sth; my $dbh;
   
   my $dbh = DBI->connect("DBI:mysql:web", 'web','midnight' ) || return $dbh->errstr;
   
   $statement = "SELECT title,date,author,author_email,text from news ";

   if($id){ $statement .= " WHERE id=\"$id\" "; }

   $statement .= "ORDER BY id DESC LIMIT 1";
   
   $sth = $dbh->prepare($statement) || return  $dbh->errstr;
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();

   if($ref->{author} && $ref->{date} && $ref->{text}){
      &msg($who, $ref->{author} . " stated on " .$ref->{date} ." ". $ref->{text});
   }else{
      &msg($who, "I\'m sorry, but that news item is not available.");
   }

   $sth->finish();

   # Disconnect from the database.
   $dbh->disconnect();

   return;
}

sub exclaim_wotd{

   $reply = "";
   if(length($WOTD) >= $WOTD_LENGTH){
      $reply = "$who: You said the word! It was \"$WOTD\".  I had learned that word from $WOTD_USER on " . strftime("%c",localtime($WOTD_AGE));
	  $reply .= ".  That was fun. I\'ll pick a new word in a few minutes.";
   }
   $WOTD = undef;
   $WOTD_AGE = undef;
   $WOTD_USER = undef;
   return($reply);

}

sub make_random_statement {

   my ($dbname, $key, $no_locking,$val,$ans);

   $dbname = shift;

   my $rdb = $DBMS{$dbname};
   my @key_array = getDBMKeys($dbname);

   srand(time);
   $key = int(rand $#key_array);

   # Give the following a couple of shots .. if it doesn't work, give up.
   my $count = 0;
   do{
      $count++;

	  # Sometimes, bots have many <reply> and $who responses
      if($count == 5){ # Attempt another random jump
	     srand(time);
		 $key = int(rand $#key_array);
	  }

	  # Move ahead by one .. we'll do this so fast that resetting the rand
	  # by time will probably give us the same number again
      $key = ($key++) % $#key_array;

      $val = $key_array[$key] . " $dbname ";
      $ans = &get($dbname,$key_array[$key]);
   }
   while($ans =~ /(\<reply\>|\$who)+/gi && $count < 10);
   
   if($count >= 10){
      $val = $factoid[rand($#factoid)];
	  $ans = "";
   }
   
   return ($val . &split_up_data($ans));

}

# Pick a db at random and return it
sub rand_db(){

 @db = ("is", "are");
 return $db[rand($#db +1)];

}

# Tell a user about something we learned
sub tell_user($user,$factoid){
  my $user = shift;
  my $factoid = shift;
  my ($dbname, $db ,$val,$ans);

  return unless ($who && $user && $factoid);
  
  $db = "is";
  $ans = &get($db,$factoid);

  if(!$ans){
     $db = "are";
	 $ans = &get($db,$factoid);
  }

  if($ans){
	 $ans = &split_up_data($ans);
     &say("$user: $who told me to tell you that $factoid $db $ans");
  }

  return;
}

# Because date may be formatted as "also |"'s
sub split_up_data($data){

   my $data = shift;

   return $data unless($data =~ /\|/);

   my(@ans) = split(/\|/, $data);

   return($ans[int (rand($#ans))]);

}

# Debugging log
sub log_new_WOTD($WOTD,$who){

    my $WOTD = shift;
    my $who  = shift;

    open(LOG, ">>/tmp/monkeybot-wotd.log");
    print LOG "monkeybot($$) $WOTD learned from $who on " .  strftime("%c",localtime(time)) ."\n";
    close(LOG);

}

# Try to build a conversation from phrases that have been learned
sub converse{

   my $about = shift;
   my $printed = 0;
   my $counter = 0;

   &msg("Gerr","trying to converse about \"$about\"");
   
   # Try to get  a factoid
   $factoid = &pick_factoid($about);


   # We should now have a factoid; copy out one of the items
   $factoid = &split_up_data($factoid);
   
   return if $factoid =~ /^$/;
   &msg("Gerr","GOT (1st try): $factoid");
   
   # TODO add in a controlled loop here ... 
   do{
      
      $printed = 0;
	  $counter++;

      # Pick a word out of the value part of the key value pair
      @factoids = split(/\s/,$factoid);
      
      # Clear our current factoid
      $old_factoid = $factoid;
      $factoid = "";

      for(my $i = 0; $i <= $#factoids; $i++){
		  next if(length(@factoids[$i]) <= 3);
		  $about = @factoids[$i];
	      &msg("Gerr", "Examining \"$about\"");
	      $factoid = &pick_factoid($about);
          $factoid = &split_up_data($about);
		  next if (!$factoid); 
		  &msg("Gerr", "Answer: $factoid");
	      if(($factoid) && ($factoid !~ /$old_factoid/)){
#			 &msg("Gerr", "Going to go with: $factoid");
#		  }if ($factoid !~ $old_factoid){ # Got a factoid!
			 &msg("Gerr", "Going to go with: $factoid -- 2");
			 $i = $#factoids + 10;
		  }
	  }
	  

      &msg("Gerr","GOT (try #$counter): $factoid");
	  if($factoid !~ /$old_factoid/){
	     $printed = 1;
         &msg("Gerr", $factoid);
	  }

	  if($factoid =~ /^$/){
	     &msg("Gerr", "Giving up on this conversation...");
		 return "NOREPLY";
	  }

   }while($counter < $MAX_CONVERSE && $printed);

   # TODO end controlled loop
   
   return "NOREPLY";
   

}

sub pick_factoid($key){
   my $key = shift;
   my $factoid = "";
   my ($db, $dbname);

   $key =~ /([a-z0-9\-]+)+/i;
   $key = $1;

   if($key =~ /^$/){
      $factoid = &make_random_statement("is");
	  $factoid = &make_random_statement("are") unless ($factoid != "");
   }else{
	   sleep(2);
       $db = "is";
	   $factoid = &get($db,$key);
	   if(!$factoid){
		  $db = "are";
		  $factoid = &get($db,$key);
	   }

   }
   if(length($factoid) < 3){
      if($key){
         &say("$who: I don't know anything about $key.");
	  }
      return "";
   }
   
   # put it all together ...
   $factoid = "$key $db $factoid";
   return ($factoid);
}

sub dictionary($){
	
	my $command = shift;
	my $word;
	my $dict;
	my $db = $dictdb;
	my $dref;
	my $def;

	if($command =~ /define (\S+) ([ \S]+)/) {
		$db   = $1;
		$word = $2;

		if(! grep(/$db/, @dictOptions))
		{
			return &dictUsage;
		}
	}elsif($command =~ /define ([ \S]+)/){
		$word = $1;
		if($word =~ /^(help)$/)
		{
			return &dictUsage;
		}
	}else{
		return;
	}

	$dict = Net::Dict->new($dictServer);
	$dref = $dict->define($word , $db);

	# Take only one entry ... override the rest
	foreach $i (@{$dref}){
		($db, $def) = @{$i};
	}

	return $def;

}

sub dictUsage{

	my $help = "";
	$help =  "I only know how to look up words in these dictionaries: ";
	foreach(@dictOptions){ $help .= "$_ "; }
	$help .= "\nWhy don't you try again? 'define [db] statement'";

	return $help;

}

1;

