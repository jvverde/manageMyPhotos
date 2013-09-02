#!/usr/bin/perl

use strict;
use File::Copy;
use File::Path;
use Cwd qw{abs_path};
use Encode qw(decode);

$\ = "\n";
$, ="\t=>\t";

my $dir = shift || die qq|Error:\n\t$0 @ARGV\n\tUsage $0 sourceDir destinationDir|;
my $dest = shift || die qq|Error:\n\t$0 @ARGV\n\tUsage $0 sourceDir destinationDir|;
my @tags = map {s/:/~/; $_} map { s/[\s()]/\\$&/g; $_ } @ARGV;
print qq|Executing $0 $dir $dest @tags|;

opendir DIR, $dir or warn qq|'nao foi possivel abrir o directorio corrente'|;

#my %files = map {s/[^0-9]+(?=\.)//; ($_ => 1)} grep {/\.jpg/i} grep { -f $_} readdir DIR;
my @files = grep {/\.(jpg|nef)$/i} readdir DIR;
my $err;
-d $dest or mkpath($dest, {
	verbose => 3,
	error => \$err,
});
if ($err and @$err) {
	for my $diag (@$err) {
		my ($file, $message) = %$diag;
		if ($file eq '') {
			print "Erro: $message\n";
		}else {
			print "problemas ao criar o directorio $file: $message\n";
		}
	}
	exit;
}

foreach (@files){
	my $f1 = "$_";
	my $path = abs_path(qq|$dir/$_|);
	$path =~ s/[\s()]/\\$&/g;
	my $tag = $path;
	$tag =~ s/\//\\\\/g;
	my @localtags = ($tag, grep {/[^\s]/} split /\//, $path);
 	my $tags = join ':', @tags, @localtags;
 	$tags =~ s/[^[:ascii:]]{1,2}/#/g;
 	my $cmd = "cp $path $dest:$tags/";
	print $cmd;
	print qx|$cmd/|;
}
