#!/usr/bin/perl
use strict;
use Flickr::API;
use Digest::MD5 qw|md5_hex|;
use Data::Dumper;
use Browser::Open qw|open_browser|;
use Storable;

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
				print "token=$token"; 
				$hash->{auth_token} = $token;
				store $hash, $hashfile;
};


