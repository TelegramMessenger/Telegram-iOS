#!/bin/env perl
# countquant_x264.pl: displays statistics from x264 multipass logfiles
# by Loren Merritt, 2005-4-5

@size{I,P,B} =
@n{I,P,B} = (0)x3;

sub proc_file {
    my $fh = shift;
    while(<$fh>) {
        /type:(.) q:(\d+\.\d+) tex:(\d+) mv:(\d+) misc:(\d+)/ or next;
	$type = uc $1;
	$n{$type} ++;
	$q[int($2+.5)] ++;
	$avgq += $2;
	$avgq{$type} += $2;
        my $bytes = ($3+$4+$5)/8;
	$size{$type} += $bytes;
    }
    $size = $size{I} + $size{P} + $size{B};
    $n = $n{I} + $n{P} + $n{B};
    $n or die "unrecognized input\n";
}

if(@ARGV) {
    foreach(@ARGV) {
        open $fh, "<", $_ or die "can't open '$_': $!";
	proc_file($fh);
    }
} else {
    proc_file(STDIN);
}

for(0..51) {
    $q[$_] or next;
    printf "q%2d: %6d  %4.1f%%\n", $_, $q[$_], 100*$q[$_]/$n;
}
print "\n";
$digits = int(log($n+1)/log(10))+2;
printf "All: %${digits}d        %s  avgQP:%5.2f  avgBytes:%5d\n",
    $n, $n==$n{I}?" ":"", $avgq/$n, $size/$n;
foreach(qw(I P B S)) {
    $n{$_} or next;
    printf "%s:   %${digits}d (%4.1f%%)  avgQP:%5.2f  avgBytes:%5d\n",
        $_, $n{$_}, 100*$n{$_}/$n, $avgq{$_}/$n{$_}, $size{$_}/$n{$_};
}
print "\n";
printf "total size: $size B = %.2f KiB = %.2f MiB\n",
    $size/2**10, $size/2**20;
print "bitrate: ", join("\n       = ",
    map sprintf("%.2f kbps @ %s fps", $_*$size*8/1000/$n, $_),
    23.976, 25, 29.97), "\n";
