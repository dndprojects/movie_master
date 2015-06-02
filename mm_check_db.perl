#!/usr/bin/perl

#use strict;
use DBI;
use English qw' -no_match_vars ';

require "/home/home_ssh/dev/bin/mm_check_sub.pl";

print "Your OS Type is $OSNAME ...\n\n";

$remote_db = "/tmp/remote_movies";
$local_db = "/media/movies_for_download_local";
$local_db = "/srv/http/dev/sqlite/movies_for_download_local";
$remote_files = "http://mypogo.no-ip.org";
#$remote_files = "http://192.168.1.55";
$movies_dir = "/media/EZRA2T/DLNA/סרטים";
$tv_series_dir = "/media/EZRA2T/DLNA/סדרות";
$transmission_dir = "/media/EZRA2T/Download";
$check_for_tv = "true";
$use_iconv = "false"; # recommended for windows users this will change srt Unicode to ANSI
$use_convert = "false" ; # recommended for WDTV resize poster to 720x1080
$preferd_poster = "he" ; # options is "he" or "en"

# read user configure file
eval slurp("/root/bin/mm_options.pl");
$remote_files = "http://192.168.1.55";

my $http_remote_db  = "${remote_files}/dev/sqlite/movies" ;
print "$http_remote_db \n";

# delete remote_db file before new download
if (-e $remote_db) { print "Deleting remote db file!\n\n"; unlink $remote_db}
my $cmd = "/usr/bin/wget $http_remote_db -O $remote_db";
my ($status, $output) = executeCommand($cmd);
#print "$output\n";

# exit if no remote_db
if (not -e $remote_db or (-s $remote_db == 0)) { print "Bad remote db!\n"; exit()}

# read remote db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$remote_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $remote_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $remote_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");
$dbh->disconnect();

# read local db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$local_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $local_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $local_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");
#$dbh->disconnect();

#name,t_link,srt,jpg,t_name,status,info,num,imdb_genre,imdb_rating,imdb_id,imdb_rated,imdb_year,imdb_he_jpg,imdb_en_jpg,imdb_trailer
#check for new movie
foreach my $remote_row (@$remote_movies_row) {
   my ($name,$t_link,$srt,$jpg,$t_name,$status,$info,$num,$imdb_genre,$imdb_rating,$imdb_id,$imdb_rated,$imdb_year,$imdb_he_jpg,$imdb_en_jpg,$imdb_trailer) = @$remote_row;
   #name	t_link	srt	jpg	t_name	status	info	num	imdb_genre	imdb_rating	imdb_id	imdb_rated	imdb_year	imdb_he_jpg	imdb_en_jpg	imdb_trailer
   foreach my $local_row (@$local_movies_row) {
      my ($local_movie,$l_t_link,$l_srt,$l_jpg,$l_t_name,$local_status,$l_info) = @$local_row;
	
	if ($name eq $local_movie){
	     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
	     my $l_srt_file = ${name} . ".srt"; 
	    # redownload new srt
		#  print "$local_movie $status $local_status $movies_dir/$l_srt_file\n";
      if ($status eq "srt.redownload" and $local_status eq "done") {
         if (-e "$movies_dir/$l_srt_file") { unlink "$movies_dir/$l_srt_file";}
		     mywget("$remote_files/$srt/$srt_file","$movies_dir/$l_srt_file");
             $statement = "UPDATE movies SET status = ? WHERE name = ?";
			 $dbh->do($statement, undef, "done.redownload.srt", $name); 
      } 
	 	      $name = "";

     last;
    }
   }
   if ($name ne "" and $t_link ne "") {
     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
      my $jpg_file = $t_name =~ s/.mkv/.jpg/r; 
   #  print "$name \n";
	  print "$name  $srt_file\n";
	  my $resulte = add_new_torrent($t_link);
      print "Start Dwonloading \"$name\" Movie Over transmission \n\n";
     if ($resulte eq "success") {
	    #wget srt/jpg to tmp 
		 mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file);
		 #chose  poster ...
         if ($preferd_poster eq "he" and ! -e "/tmp/$jpg_file") {print "downloading he posrt \n" ; mywget($imdb_he_jpg,'/tmp/'.$jpg_file);}
		 if ($preferd_poster eq "en" and ! -e "/tmp/$jpg_file") {print "downloading en posrt \n" ;mywget($imdb_en_jpg,'/tmp/'.$jpg_file);}
		 if (! -e "/tmp/$jpg_file")    {print "downloading defualt posrt \n" ;mywget("$remote_files/$srt/$jpg_file",'/tmp/'.$jpg_file);}
		 #if convert 
		 if ($use_convert eq "true" and -e "/tmp/$jpg_file") {
		  my $cmd = "convert $imdb_he_jpg -resize 720x1080! '/tmp/'$jpg_file";
          executeCommand($cmd);
		 }
		
        # update local db with new movie
        # $dbh->do('INSERT INTO movies (name,t_link,srt,jpg,t_name,status,info) VALUES (?,?,?,?,?,?,?)',  undef, $name,$t_link,$srt,$jpg,$t_name,$status,$info);
     }
  }
 
}

# check for new tv
    if ($check_for_tv eq "false") {
        print "not cheaking for new tv show !\n";
       $dbh->disconnect();
       exit();
    }

    my $dir = $tv_series_dir;
    my @my_tv_shows = ();
    opendir(DIR, $dir) or die $!;
     while (my $file = readdir(DIR)) {
      next unless (-d "$dir/$file" && $file ne "." && $file ne "..");
	  push @my_tv_shows, $file;
	#print "$file\n";
    }
    closedir(DIR);
	my %my_tv_shows_h = map { $_ => 1 } @my_tv_shows;


#name,t_link,srt,jpg,t_name,status,folder,info,num

foreach my $remote_row (@$remote_tv_row) {
  
   my ($name,$t_link,$srt,$jpg,$t_name,$status,$folder,$info,$num) = @$remote_row;
   my @pf = split(/\./, $folder);
   my $spf= $pf[$#pf]; 
   my $top_folder = $folder =~ s/\.$spf//r; 
   #if(!exists($my_tv_shows_h{$top_folder})) {last;}
   
   foreach my $local_row (@$local_tv_row) {
    my ($local_tv,$l_t_link,$l_srt,$l_jpg,$l_t_name,$local_status,$l_local_floder,$l_info,$l_num) = @$local_row;
	if ($local_tv eq $name){
	   my $srt_file = $t_name =~ s/.mkv/.srt/r; 
	   my $l_srt_file = ${name} . ".srt"; 
	    # re download new srt
      if ($status eq "srt.redownload" and $local_status eq "done") {
         if (-e "$tv_series_dir/$l_srt_file") { unlink "$tv_series_dir/$top_folder/$folder/$l_srt_file";}
		     mywget("$remote_files/$srt/$srt_file","$tv_series_dir/$top_folder/$folder/$l_srt_file");
             $statement = "UPDATE tv_series SET status = ? WHERE name = ?";
			 $dbh->do($statement, undef, "done.redownload.srt", $name); 
      } 
	 $name = "";
     last;
	 }
   }
    if ($name ne "" and $t_link ne "" and exists($my_tv_shows_h{$top_folder})) {
     if ($resulte eq "success") {
	    #wget srt/jpg to tmp
     	 my $srt_file = $t_name =~ s/.mkv/.srt/r; 
         mywget('$remote_files/$srt/$srt_file','/tmp/'.$srt_file);
        # update local db with new tv_series
        $dbh->do('INSERT INTO tv_series (name,t_link,srt,jpg,t_name,status,info) VALUES (?,?,?,?,?,?,?)',  undef, $name,$t_link,$srt,$jpg,$t_name,$status,$info);
     }
  }
}


$dbh->disconnect();