#!/bin/bash

dpkg --print-architecture | grep amd64 

if [ $? -eq 0 ];
then
        echo "Machine is AMD64. Checking if IA32 support is present...";

        dpkg --print-foreign-architectures | grep i386 

        if [ $? -eq 0 ]; 
        then
                printf "Found IA32 support.\n";
                exit 0;
        else
                printf "\033[0;31m IA32 libraries needed to run bundled ARM GCC not found. Please install them. \n";
                exit 1;
        fi;
else
        dpkg --print-architecture | grep i386

        if [ $? -eq 0 ]; 
        then
                printf "Architecture is IA32.\n";
                exit 0;
        else
                printf "\033[0;31m Incorrect Architecture. \n";
                exit 1;
        fi;
fi;

