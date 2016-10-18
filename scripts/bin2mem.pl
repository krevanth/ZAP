my $bin_file = $ARGV[0];
my $target_verilog_file = $ARGV[1];

# Generate Verilog file.
die "*E: Verilog file creation error...\n" if system("rm -f $target_verilog_file ; touch $target_verilog_file");

open(my $fh, "<$bin_file") or die "Bin file $ARGV[0] could not be opened for reading...!\n";
open(GH, ">$target_verilog_file") or die "Target verilog file could not be opened for writing...\n";

binmode $fh;

my $counter = 0;

while (read($fh, my $buf, 1) == 1) {
        my $line = sprintf("mem[$counter] = 8'h%x;\n", ord $buf);        
        print GH $line;
        $counter++;
}

close($fh);
close(GH);

print "Done...\n";
exit 0;
