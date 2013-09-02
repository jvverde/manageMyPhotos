#!/usr/bin/perl

use strict;
use File::Copy;
use File::Path;
$\ = "\n";
$, ="\t=>\t";
my $dir = shift @ARGV || '.';
my $orig = "$dir/../original";

opendir DIR, $dir or warn qq|'nao foi possivel abrir o directorio corrente'|;

#my %files = map {s/[^0-9]+(?=\.)//; ($_ => 1)} grep {/\.jpg/i} grep { -f $_} readdir DIR;
my %files = map {s/[^0-9]+(?=\.)//; ($_ => 1)} grep {/\.jpg$/i} readdir DIR;
my $err;
-d $orig or mkpath($orig, {
	verbose => 3,
	error => \$err,
});
if ($err and @$err) {
	for my $diag (@$err) {
		my ($file, $message) = %$diag;
		if ($file eq '') {
			print "Erro: $message\n";
		}else {
			print "problemas aop criar o directorio $file: $message\n";
		}
	}
}

foreach (keys %files){
	my $f1 = "$dir/../$_";
	my $f2 = $f1;
	my $d1 = "$orig/$_";
	print qq|$f1 => $d1|;
	move($f1,$d1);
	$f2 =~ s/\.jpg$/\.NEF/i;
	my $d2 = $d1;
	$d2 =~ s/\.jpg$/\.NEF/i;
	print qq|$f2 => $d2|;
	move($f2, $d2);
}
