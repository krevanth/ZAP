#!/usr/bin/perl -w

die "Usage: perl bin2verilog.pl bin_file" if (@ARGV != 1);

open(my $fh, $ARGV[0]) or die "Bin file $ARGV[0] could not be opened!\n";
binmode $fh;

my $counter = 0;

while (read($fh, my $buf, 1) == 1)
{
        printf("mem[$counter] = 8'h%x;\n", ord $buf);        
        $counter++;
}
