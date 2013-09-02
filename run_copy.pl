#!/usr/bin/perl
use strict;
use File::Copy;
use File::Path;
use Cwd qw{abs_path cwd};

$\ = "\n";
$, =",";

my $dir = shift || '.';

my $path = abs_path($0);
$path =~ s/[^\\\/]*$//;
print $path;
print $dir;
#exit;

getFolders($dir);


sub getFolders{
	my $dir = shift;
	print qq|dir=$dir|;
	if ($dir =~ /sel/i){
		print "copy $dir";
		print `$path/copia-originais.pl "$dir"`;
	}else{
		opendir DIR, $dir or warn qq|Nao foi possivel abrir o directorio $dir| and return;
		my @folders = grep {$_ ne '.' and $_ ne '..' and $_ !~ /.+\./} readdir DIR;
		closedir DIR;
		print q|@folders = |.qq| @folders|;
		print '-------------------------------';
		foreach my $subdir (@folders){
			getFolders(qq|$dir/$subdir|);
		}
	}
}
