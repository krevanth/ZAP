#!/usr/bin/perl

die "*E: Failed to perform GIT ADD...\n" if system('git add .');

print "*I: Enter commit message...\n";
my $message = <STDIN>;

system("git commit -m \"$message\"");
die "*E: Failed to push changes to master...\n" if system('git push origin master');

print "All OK...\n";
