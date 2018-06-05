#!/bin/bash
# Used to check CPU architecture. Does not check for libc6. You must ensure it is installed.

#// -----------------------------------------------------------------------------
#// --                                                                         --
#// --                   (C) 2016-2018 Revanth Kamaraj.                        --
#// --                                                                         -- 
#// -- --------------------------------------------------------------------------
#// --                                                                         --
#// -- This program is free software; you can redistribute it and/or           --
#// -- modify it under the terms of the GNU General Public License             --
#// -- as published by the Free Software Foundation; either version 2          --
#// -- of the License, or (at your option) any later version.                  --
#// --                                                                         --
#// -- This program is distributed in the hope that it will be useful,         --
#// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
#// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
#// -- GNU General Public License for more details.                            --
#// --                                                                         --
#// -- You should have received a copy of the GNU General Public License       --
#// -- along with this program; if not, write to the Free Software             --
#// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
#// -- 02110-1301, USA.                                                        --
#// --                                                                         --
#// -----------------------------------------------------------------------------


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

