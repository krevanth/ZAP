#!/usr/bin/perl -w

###############################################################################
# Perl script to translate GCC generated binary files into Verilog memory
# files.
#
# Usage: perl bin2mem.pl <Binary File> <Target Verilog File>
###############################################################################

use strict;
use warnings;

# Read command line arguments.
my $bin_file = $ARGV[0];
my $target_verilog_file = $ARGV[1];

# Generate Verilog file.
die "*E: Verilog file creation error...\n" if 
        system("rm -f $target_verilog_file ; touch $target_verilog_file");

# Open the binary and Verilog file using different file handles.
open(my $fh, "<$bin_file") or die 
        "Bin file $ARGV[0] could not be opened for reading...!\n";

open(GH, ">$target_verilog_file") or die 
        "Target verilog file could not be opened for writing...\n";

# Read file in binary mode.
binmode $fh;

# Memory pointer.
my $counter = 0;

#
# As long as there are bytes to read from the binary file, we will write out
# those bytes. The ord function returns to numeric value of the byte from 0
# to 255 corresponding to bytes 8'b0000_0000 to 8'b1111_1111.
#
while (read($fh, my $buf, 1) == 1) { # Get a byte from the file.

        # Print the numeric value of the byte.
        my $line = sprintf("mem[$counter] = 8'h%x;\n", ord $buf);        

        # Print to the Verilog file.
        print GH $line;

        # Increment memory pointer by 1 since we are dealing with bytes.
        $counter++;
}

# Close both the files.
close($fh);
close(GH);

print "Done...\n";
exit 0;
