#!/usr/bin/perl
use strict;
use Flickr::API;
use Digest::MD5 qw|md5_hex|;
use Data::Dumper;
use Browser::Open qw|open_browser|;
use Storable;
use Flickr::Upload;
use Cwd qw{abs_path};
use Digest::SHA qw(sha256);


$\ = "\n";

my $msg = q|Now goto to your browser and in the new opened window give authorization, close that window (or the browser) and then return here and enter C to continue|;

my $api_key = '19b47264d5e18d50962ac56345510fbc';
my $shared_secret = '9f01bc4567657508';

my $api = new Flickr::API({
	key => $api_key,
	secret => $shared_secret
});

my $hashfile="config.hash";
store {}, $hashfile unless -r $hashfile;
my $hash=retrieve($hashfile);
print join(",", %$hash), "\n";
$hash->{cnt}++;
store $hash, $hashfile;

while(! defined $hash->{auth_token}){
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
		my $ctl = <>;
		chomp $ctl;
		last if $ctl =~ /^c$/i;
	};
	print 'Get token...';
	my $response = $api->execute_method('flickr.auth.getToken',{
		frob => $frob
	});
	print 'Check answer...';
	my $r = $response->decoded_content(charset => 'none');
	warn qq|Warning:\n$r| and next unless $r =~ /<rsp[^>]+stat\s*=\s*"ok".*>/i;
	print 'Extract token...';
	$r =~ /<token>(.+)<\/token>/ or die qq|ERROR:\n$r|;
	my $token = $1;
	print 'Save token...';
	$hash->{auth_token} = $token;
	store $hash, $hashfile;
};

@ARGV >=2 or die qq|Usage $0 sourceDir  pattern [tag1 [tag2 ... [tagN]]]|;

my ($dir, $pattern, @tags) = @ARGV;


sub getFolders{
	my $dir = shift;
	print qq|Get dir $dir|;
	if ($dir =~ $pattern){
		backup($dir,@tags);
	}else{
		opendir DIR, $dir or warn qq|Nao foi possivel abrir o directorio $dir| and return;
		my @subdirs = grep {-d qq|$dir/$_| and $_ ne '.' and $_ ne '..'} readdir DIR;
		closedir DIR;
		foreach my $subdir (@subdirs){
			getFolders(qq|$dir/$subdir|);
		}
	}
}

sub backup{
	my ($dir,@tags) = @_;

	opendir DIR, $dir or warn qq|'nao foi possivel abrir o directorio corrente'|;

	my @files = grep {/\.(jpg|nef)$/i} readdir DIR;
	foreach (@files){
		my $path = abs_path(qq|$dir/$_|);
		my $id = getFileID($path);
		next if defined $hash->{ids}->{$id};
		my @localtags = (
			qq|dir:path="$path"|,
			qq|meta:id="$id"|,
			qq|file:name="$_"|,
			map {qq|dir:step="$_"|} grep {/[^\s]/} split /\//, $path
		);
		pop @localtags; #discard filename from dir:step tags
		eval{
			upload($path,$id,@localtags,@tags);
		};
		warn $@ if $@;
	}


}
sub getFileID{
        warn(q|getFileID: File not defined|) and return undef unless defined $_[0];
        warn(q|getFileID: File not $_[0] found|) and return undef unless -e $_[0];
        my $sha = Digest::SHA->new();
        $sha->addfile($_[0],'b');
        return $sha->hexdigest;
}

my $ua = Flickr::Upload->new({
	key => $api_key,
	secret => $shared_secret
});

sub upload{
	my ($file,$id, @tags) = @_;
	#print "Upload file $file";
	my $photoid = $ua->upload(
		photo => $file,
		auth_token => $hash->{auth_token},
		tags => (join ' ', @tags),
		is_public => 0,
		is_private => 1
	) or warn "Failed to upload $file" and return;
	$hash->{ids}->{$id} = $photoid;
	print "File $file uploaded to $photoid";
	store $hash, $hashfile;
}

getFolders($dir);
