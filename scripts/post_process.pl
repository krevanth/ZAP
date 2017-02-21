# This is executed on the log file to extract important information.

system("tail -n 40 $ARGV[0] | grep 'DATA'");
