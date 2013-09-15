#!/usr/bin/perl
use strict;
use utf8;
# use warnings  qw(FATAL utf8);    # Fatalize encoding glitches.
# use open      qw(:std :utf8);    # Undeclared streams in UTF-8.
# use charnames qw(:full :short);  # Unneeded in v5.16.
use File::Copy;
use File::Path;
use Cwd qw{abs_path};

$\ = "\n";
$, =",";


@ARGV >=3 or die qq|Usage $0 sourceDir  destinationDir pattern [tag1 [tag2 ... [tagN]]]|;

my ($dir, $dest, $pattern, @tags) = @ARGV;

my $path = abs_path($0);
$path =~ s/[^\\\/]*$//;
abs_path($dest);
$dest =~ s/[\\\/]$//;
@tags = map{ qq|"$_"|} @tags;

getFolders($dir);

sub getFolders{
	my $dir = shift;
	print qq|Get dir $dir|;
	if ($dir =~ $pattern){
		print qq|$path/2flickr.pl "$dir" "$dest" @tags|;
		print qx|$path/2flickr.pl "$dir" "$dest" @tags|;
	}else{
		opendir DIR, $dir or warn qq|Nao foi possivel abrir o directorio $dir| and return;
		my @subdirs = grep {-d qq|$dir/$_| and $_ ne '.' and $_ ne '..'} readdir DIR;
		closedir DIR;
		foreach my $subdir (@subdirs){
			getFolders(qq|$dir/$subdir|);
		}
	}
}
