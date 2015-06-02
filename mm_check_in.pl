#!/usr/bin/perl

#use strict;
use DBI;
use Cwd qw(abs_path);
use English qw' -no_match_vars ';
use File::Copy;

# read sub routines
require "/home/home_ssh/dev/bin/mm_check_sub.pl";

print "Your OS Type is $OSNAME ...\n";

$remote_db = "/tmp/remote_movies";
$local_db = "/media/movies_for_download_local";
$local_db = "/srv/http/dev/sqlite/movies_for_download_local";
$remote_files = "http://mypogo.no-ip.org";
#$remote_files = "http://192.168.1.55";
$movies_dir = "/media/EZRA2T/DLNA/סרטים";
$tv_series_dir = "/media/EZRA2T/DLNA/סדרות";
$transmission_dir = "/media/EZRA2T/Download";
$send_mail_alias = 'ezradnd@gmail.com ezradnd@walla.com';
$check_for_tv = "true";
$use_iconv = "false"; # recommended for windows users this will change srt Unicode to ANSI
$use_convert = "false" ; # recommended for WDTV resize poster to 720x1080
$preferd_poster = "he" ; # options is "he" or "en"

# read user configure file
eval slurp("/root/bin/mm_options.pl");

# exit if no local_db
if (not -e $local_db or (-s $local_db == 0)) { print "Bad local_db db!\n"; exit()}

# read local db
my $dbh = DBI->connect( "dbi:SQLite:dbname=$local_db","","",{ RaiseError => 1 },) or die $DBI::errstr;
my $local_movies_row = $dbh->selectall_arrayref("SELECT * FROM movies");
my $local_tv_row = $dbh->selectall_arrayref("SELECT * FROM tv_series");

my $path = abs_path $transmission_dir;
@transmission_files = search_all_folder($path);

foreach $a (@search_all_folder){
    my $movie_file = (split/,/,$a)[0];
	my $movie_folder = (split/,/,$a)[1];
    #print "checking movie: $movie_file \n";
	# check if file in movie db
	foreach my $local_row (@$local_movies_row) {
    my ($name,$t_link,$srt,$jpg,$t_name,$status,$info,$num,$imdb_genre,$imdb_rating,$imdb_id,$imdb_rated,$imdb_year,$imdb_he_jpg,$imdb_en_jpg,$imdb_trailer) = @$local_row;
     my $srt_file = $t_name =~ s/.mkv/.srt/r; 
     my $jpg_file = $t_name =~ s/.mkv/.jpg/r; 
	 if ($movie_file eq $t_name){
	 print "$name\n";
	 	     shell_email($info,$jpg,$send_mail_alias,$movies_dir);


	 clean_torrent_by_file($t_name);
	 #srt
	 if (! -e "/tmp/$srt_file") {print "re-dwonloading srt for $name\n"; mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file); }
	 if (-e "/tmp/$srt_file") {
	    if ($use_iconv eq "true") {use_iconv_on_srt('/tmp/'.$srt_file);}
	    #move movie file:
		move($path ."/". $movie_folder .'/'. $movie_file, $movies_dir.'/'.$name.'.mkv');
		#copy srt
		move('/tmp/'.$srt_file, $movies_dir.'/'.$srt_file);
	    #jpg
		if (! -e "/tmp/$jpg_file") { print "re-dwonloading jpg\n";
		 if ($preferd_poster eq "he" and ! -e "/tmp/$jpg_file") {print "downloading he posrt \n" ; mywget($imdb_he_jpg,'/tmp/'.$jpg_file);}
		 if ($preferd_poster eq "en" and ! -e "/tmp/$jpg_file") {print "downloading en posrt \n" ;mywget($imdb_en_jpg,'/tmp/'.$jpg_file);}
		 if (! -e "/tmp/$jpg_file")    {print "downloading defualt posrt \n" ;mywget("$remote_files/$srt/$jpg_file",'/tmp/'.$jpg_file);}
		 #if convert 
		 if ($use_convert eq "true" and -e "/tmp/$jpg_file") {
		  my $cmd = "convert $imdb_he_jpg -resize 720x1080! '/tmp/'$jpg_file";
          executeCommand($cmd);
		  }
		}
		 move('/tmp/'.$jpg_file, $movies_dir.'/'.$jpg_file);
	    #update db
	    $statement = "UPDATE movies SET status = ? WHERE name = ?";
	    $dbh->do($statement, undef, "done", $name); 
		# cleanup transmission dir
		#clean_dir($path.'/'.$movie_folder);
	     shell_email($info,$jpg,$send_mail_alias);

	 } else { print "NO SRT for $name Movie ... exiting\n";}
	 last;
	 }
	}
	
	# check if file in tv db
	foreach my $local_row (@$local_tv_row) {
    my ($name,$t_link,$srt,$jpg,$t_name,$status,$local_floder,$info,$num) = @$local_row;
	 if ($movie_file eq $t_name){
   	  my $srt_file = $t_name =~ s/.mkv/.srt/r; 
	  print "$name\n";
	 #srt
	 if (! -e "/tmp/$srt_file") {print "re-dwonloading srt for $name\n"; mywget("$remote_files/$srt/$srt_file",'/tmp/'.$srt_file); }
     if (-e "/tmp/$srt_file") {
	    if ($use_iconv eq "true") {use_iconv_on_srt('/tmp/'.$srt_file);}
		#move movie file:
		move($path ."/". $movie_folder .'/'.$movie_file, $tv_series_dir/$top_folder/$folder.'/'.$name.'.mkv');
	    #copy srt
		move('/tmp/'.$srt_file, $tv_series_dir/$top_folder/$folder.'/'.$name.'.srt');	 
	    #update db
	    $statement = "UPDATE tv_series SET status = ? WHERE name = ?";
        $dbh->do($statement, undef, "done", $name); 
		#clean_dir($path.'/'.$movie_folder);
		 #echo $total_disk "\n\n" $info "\n\n" $jpg | $email_cmd -s "New TV_SERIES --> $name" $send_mail_alias

	 last;
	 }
	}
   }
}

$dbh->disconnect();

