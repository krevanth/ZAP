# This is executed on the log file to extract important information.
print "POST PROCESSING SCRIPT...\n";

print "Grepping $ARGV[0] for errors...\n";
system("cat $ARGV[0] | grep '*E'") or print "ERRORS detected...\n";
system("cat $ARGV[0] | grep '*W'") or print "WARNINGS detected...\n";

print "Printing last 40 entries...\n";
system("tail -n 40 $ARGV[0] | grep 'DATA'");

print "Script done...\n";

