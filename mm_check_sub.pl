
sub mywget 
{
     my $my_wget_file = $_[0];
	 my $my_local_file = $_[1];
	 my $cmd = "/usr/bin/wget --timeout=30 $my_wget_file -O $my_local_file";
     my ($status, $output) = executeCommand($cmd);
     if (-z $my_local_file) { 
	 print "Bad file $my_local_file removing it!\n"; 
	 print "check your wget cmd line: $cmd\n\n";
	 unlink $my_local_file or warn "Unable to remove '$my_local_file': $!";
	 $mywget = "false";
    } else {
	     print "file $my_local_file downloaded\n\n"; 
		 $mywget = "true";
	}
}
sub add_new_torrent 
{    
	if ($OSNAME eq "linux") {
	($t_status, $t_output) = executeCommand('systemctl start transmission');
	 $transmission_cmd = 'transmission-remote -a ';
	}
    if ($OSTYPE eq "cygwin") {
     $transmission_cmd = 'cmd.exe /C  transmission-remote -a ' ;
    }
    my $t_file = $_[0];
	$transmission_cmd = $transmission_cmd . $t_file;
	 #print "$transmission_cmd\n";
    local ($t_status, $t_output) = executeCommand($transmission_cmd);
	#print "$t_output\n";
	my $test_torrent = "failed";
	if ($t_output =~ /success/) {$test_torrent = "success";}
	# Error: invalid or corrupt torrent file
	# localhost:9091/transmission/rpc/ responded: "success"
	# [2015-05-29 17:14:52.428 IDT] transmission-remote: Couldn't connect to server	
	$add_new_torrent = $test_torrent;
}

## slurp - read a file into a scalar or list
sub slurp {
    my $file = shift;
    local *F;
    open F, "< $file" or die "Error opening '$file' for read: $!";
    if(not wantarray){
        local $/ = undef;
        my $string = <F>;
        close F;
        return $string;
    }
    local $/ = "";
    my @a = <F>;
    close F;
    return @a;
}


sub search_all_folder
{
my ($folder) = @_;
    if ( -d $folder ) {
        chdir $folder;
        opendir my $dh, $folder or die "can't open the directory: $!";
        while ( defined( my $file = readdir($dh) ) ) {
             chomp $file;
             next if $file eq '.' or $file eq '..';
             search_all_folder("$folder/$file");  ## recursive call
			 next unless ($file =~ m/\.mkv$/ or $file =~ m/\.avi$/ or $file =~ m/\.mp4$/ );
             #print "$folder $file \n ";
			 push @search_all_folder, $file . "," .$folder;
        }
        closedir $dh or die "can't close directory: $!";
    }
	
}

#clean torrent
sub clean_torrent_by_file
{
   my $t_file = $_[0];
   my $cmd = "transmission-remote -l";
   my ($status, $output) = executeCommand($cmd);
   my @ans = split(/\n/, $output);
   #print "$t_file\n";
 foreach my $line ( @ans ) {
   if ($line =~ /100%/ and $line =~ /\Q$t_file\E/){
   my @id = split(/\s+/, $line);
   #print "line: $id[1]\n";
   clean_torrent_by_id($id[1]);
   }
 }
}
sub clean_torrent_by_id
{    
    my $t = $_[0];
	if ($OSNAME eq "linux") {
	 $transmission_cmd = 'transmission-remote -t '.$t.' -r';
	}
    if ($OSTYPE eq "cygwin") {
     $transmission_cmd = 'cmd /R "${transmission_dir}/transmission-remote -t '.$t.' -r' ;
    } 
	print "$transmission_cmd\n";
    local ($t_status, $t_output) = executeCommand($transmission_cmd);
}
sub executeCommand
{
 local $SIG{ALRM} = sub { die "Timeout\n" };
 eval {
   alarm 10; # change to timeout length
   my $command = join ' ', @_;
   ($? >> 8, $_ = qx{$command 2>&1});
  # alarm 0;
 };
}

sub use_iconv_on_srt
{
       $srt_file = $_[0];
      if (-e "/usr/bin/iconv") {
	    my $cmd = '/usr/bin/iconv -t "WINDOWS-1255" ' . $srt_file . ' > /tmp/tmp_iconv.srt';
        print "$cmd\n\n";
		my ($status, $output) = executeCommand($cmd);  
        rename  "/tmp/tmp_iconv.srt" , $srt_file;
       }
}

sub clean_dir
{
       $dir = $_[0];
	   
}
sub shell_email
 {

     if ($OSNAME eq "linux") {
        $email_cmd = ' mail';
     }
     if ($OSNAME eq "cygwin") {
       $email_cmd = "email";
   #   set $send_mail_alias = `echo $send_mail_alias | tr " " ","` 
    }
            $dir = $_[3];
			my ($status, $output) = executeCommand('df -h ' . $dir . '| grep -v Filesystem' );
			$t =(split/\s+/,$output)[1];
			$n = (split/\s+/,$output)[3];
		    $total_disk =  "TOTAL DISK Left $n Out of $t\n";
           $info = $_[0];
		   $jpg = $_[1];
		   $send_mail_alias = $_[2];
		   $email_cmd = 'printf "'. $total_disk .' \n\n ' . $info . ' \n\n '. $jpg . '"| '. $email_cmd .' -s "New TV_SERIES --> '.$name .'" '.$send_mail_alias;
         # print "$email_cmd\n"     ;    
		  executeCommand($email_cmd);
}

 1;