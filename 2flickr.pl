#!/usr/bin/perl

use strict;
use File::Copy;
use File::Path;
use Cwd qw{abs_path};
use Digest::SHA qw(sha256);

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
	my $path = abs_path(qq|$dir/$_|);
	my $newName = getFileID($path);
	my $f1 = "$_";
	$f1 =~ s/(?<=\.)(jpg|nef)$/lc $1/gei;
	next if -e qq|$dest/$newName.$f1|;
	$f1 =~ s/[\s()]/\\$&/g;
	$path =~ s/[\s()]/\\$&/g;
	print qx|cp -a $path /tmp/$newName.$f1|;
	my $tag = $path;
	$tag =~ s/\//\\\\/g;
	my @localtags = ($tag, grep {/[^\s]/} split /\//, $path);
 	my $tags = join ':', @tags, @localtags;
 	$tags =~ s/[^[:ascii:]]{1,2}/#/g;
	print qx|cp -a /tmp/$newName.$f1 $dest:$tags/|;
	print qx|rm -f /tmp/$newName.$f1|;
}

sub getFileID{
        warn(q|getFileID: File not defined|) and return undef unless defined $_[0];
        warn(q|getFileID: File not $_[0] found|) and return undef unless -e $_[0];
        my $sha = Digest::SHA->new();
        $sha->addfile($_[0],'b');
        return $sha->hexdigest;
}
