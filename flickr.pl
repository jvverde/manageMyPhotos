#!/usr/bin/perl
use strict;
use Flickr::API;
use Data::Dumper;
use Browser::Open qw|open_browser|;
use Storable;
use Flickr::Upload;
use Cwd qw{abs_path};
use Digest::SHA qw(sha256);
use File::Copy qw(cp);
use XML::XPath;
use Getopt::Long;

$\ = "\n";

my $sync = undef;
my $auth = undef;
my $stop = undef;
sub tsktsk {
    $SIG{INT} = \&tsktsk;
    print "OK! I will stop soon";
    $stop = 1;
}
$SIG{INT} = \&tsktsk;

GetOptions ('sync|s' => \$sync, 'auth|a' => \$auth);

@ARGV >=3 or die qq|Usage $0 [options] profile sourceDir  pattern [tag1 [tag2 ... [tagN]]]|;

my ($profile, $dir, $pattern, @tags) = @ARGV;

my $msg = q|Now goto to your browser and
	1-Give Authorization in the new opened window
	2-Close that window (or the browser)
	3-Return here
	4-Enter C to (C)ontinue|;

my $api_key = '19b47264d5e18d50962ac56345510fbc';
my $shared_secret = '9f01bc4567657508';

my $api = new Flickr::API({
	key => $api_key,
	secret => $shared_secret
});

my $hashfile = qq|.$profile.profile|;
store {}, $hashfile unless -r $hashfile;
my $hash = retrieve($hashfile) or die 'Corrupted profile';
cp $hashfile, qq|$hashfile.old|;
#print Dumper $hash;
#print join(",", %$hash), "\n";
$hash->{cnt}++;
store $hash, $hashfile;

undef $hash->{auth_token} if $auth;

while(! defined $hash->{auth_token} || ! defined $hash->{nsid}){
	my $permission_wanted = 'write';
	print 'Get frob...';
	my $response = $api->execute_method('flickr.auth.getFrob');
	my $r = $response->decoded_content(charset => 'none');
	warn qq|Warning:\n$r|, next unless $r =~ /<rsp[^>]+stat\s*=\s*"ok".*>/i;
	$r =~ /<frob>(.+)<\/frob>/ or die qq|ERROR:\n$r|;
	my $frob = $1;
	while(1){
		my $url = $api->request_auth_url($permission_wanted,$frob);
		print $msg;
		#print $url;
		open_browser($url);
		print "Enter C to continue";
		my $ctl = <STDIN>;
		chomp $ctl;
		last if $ctl =~ /^c$/i;
	};
	print 'Get token...';
	my $response = $api->execute_method('flickr.auth.getToken',{
		frob => $frob
	});
	print 'Check answer...';
	my $r = $response->decoded_content(charset => 'none');
	print $r;
	warn qq|Warning:\n$r| and next unless $r =~ /<rsp[^>]+stat\s*=\s*"ok".*>/i;
	print 'Extract token...';
	$r =~ /<token>(.+)<\/token>/ or die qq|ERROR:\n$r|;
	my $token = $1;
	print 'Save token...';
	$hash->{auth_token} = $token;
	$r =~ /<user\s+nsid\s*=\s*"([^"]+)"\s+username\s*=\s*"([^"]+)"\s+fullname\s*=\s*"([^"]+)"/
		or die qq|ERROR:\n$r|;
	$hash->{nsid} = $1;
	$hash->{username} = $2;
	$hash->{fullname} = $3;
	store $hash, $hashfile;
};

syncFromFlickr() if ($sync);
getFolders($dir);


sub syncFromFlickr{
	my $page = shift || 1;
	my $response = $api->execute_method('flickr.photos.search', {
		user_id => $hash->{nsid},
		auth_token => $hash->{auth_token},
	  #machine_tags => "meta:id=",
	  extras => 'machine_tags',
		per_page => 500,
		page => $page
	});
	warn $response->status_line and return unless $response->is_success;
	my $answer  = $response->decoded_content(charset => 'none');
	my $xp = XML::XPath->new(xml => $answer);
	warn qq|Wrong answer:\n\t$answer|
		and return if $xp->getNodeText('/rsp/@stat')->value ne 'ok';
  my $npages = $xp->getNodeText('/rsp/photos/@pages')->value;
  my $npage = $xp->getNodeText('/rsp/photos/@page')->value;
	print "Sync page $npage of $npages";
  my @photos = $xp->find('/rsp/photos/photo')->get_nodelist();
  foreach (@photos){
  	#print Dumper $_;
  	my $xp = XML::XPath->new(context => $_);
  	my $photoid = $xp->getNodeText('@id')->value;
  	my $mt = $xp->getNodeText('@machine_tags')->value;
  	$mt =~ /meta:id\s*=\s*([0-9a-f]+)/i;
  	my $id = $1;
  	unless($hash->{ids}->{$id}){
  		print "$id does not exists in local cache";
	  	$hash->{ids}->{$id} = $photoid;
  	}
  }
  store $hash, $hashfile;
  exit if $stop;
  syncFromFlickr($page+1) if $page < $npages;
}

sub getFolders{
	my $dir = shift;
	exit if $stop;
	print qq|Get dir $dir|;
	if ($dir =~ $pattern){
		backup($dir,@tags);
	}
	getSubFolders($dir);
}

sub getSubFolders{
	my $dir = shift;
	opendir DIR, $dir or warn qq|Nao foi possivel abrir o directorio $dir| and return;
	my @subdirs = grep {-d qq|$dir/$_| and $_ ne '.' and $_ ne '..'} readdir DIR;
	closedir DIR;
	foreach my $subdir (@subdirs){
		getFolders(qq|$dir/$subdir|);
	}
}

sub backup{
	my ($dir,@tags) = @_;

	opendir DIR, $dir or warn qq|'nao foi possivel abrir o directorio corrente'|;

	my @files = grep {/\.(jpg|nef)$/i} readdir DIR;
	foreach (@files){
		my $path = abs_path(qq|$dir/$_|);
		eval{
			upload($path,@tags);
		};
		warn $@ if $@;
		exit if $stop;
	}
}

sub upload{
	my ($file,@tags) = @_;
	my $ua = Flickr::Upload->new({
		key => $api_key,
		secret => $shared_secret
	});
	#print "Upload file $file";
	my $mtime =  (stat($file))[9];
	return if $hash->{filenae} eq $mtime;
	my $id = getFileID($file);
	return if defined $hash->{ids}->{$id};
	if (checkFlickrPhoto($id) == 0){ #if not yet on flickr upload
		my @localtags = (
			qq|dir:path="$file"|,
			qq|meta:id="$id"|,
			q|time:modification="|.localtime($mtime).q|"|,
			map {qq|dir:step="$_"|} grep {/[^\s]/} split /\//, $file
		);
		pop @localtags; #discard filename from dir:step tags


		my $photoid = $ua->upload(
			photo => $file,
			auth_token => $hash->{auth_token},
			tags => (join ' ', @tags, @localtags),
			is_public => 0
		) or warn "Failed to upload $file" and return;
		print "File $file uploaded to flickr (photoid = $photoid)";
		$hash->{ids}->{$id} = $photoid;
	}else{
		print "File $file ($id) is already on flickr";
		$hash->{ids}->{$id} = 0;
	}
	$hash->{filename} = $mtime;
	store $hash, $hashfile;
}

sub getFileID{
	warn(q|getFileID: File not defined|) and return undef unless defined $_[0];
	warn(q|getFileID: File not $_[0] found|) and return undef unless -e $_[0];
	my $sha = Digest::SHA->new();
	$sha->addfile($_[0],'b');
	return $sha->hexdigest;
}

sub checkFlickrPhoto{
	my $id = shift;
	#print "Check photo $id";
	my $response = $api->execute_method('flickr.photos.search', {
		user_id => $hash->{nsid},
		auth_token => $hash->{auth_token},
	  machine_tags => qq|meta:id="$id"|
	});
	my $answer  = $response->decoded_content(charset => 'none');
	my $xp = XML::XPath->new(xml => $answer);
	warn qq|Wrong answer:\n\t$answer|
		and return undef if $xp->getNodeText('/rsp/@stat')->value ne 'ok';
  my $nphotos = $xp->getNodeText('/rsp/photos/@total')->value;
  return $nphotos;
}
