#!/usr/bin/perl

system('git add .');

print "Enter commit message...\n";
my $message = <STDIN>;

system("git commit -m \"$message\"");
system('git push origin master');
