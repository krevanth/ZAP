#!/bin/bash

##############################################
# This file reads characters into a file. The
# Verilog testbench then opens this file and
# writes it to the UART RX character wise.
# 
# Call this like:
# bash uart_input.bash <filename> 
##############################################

IFS=""

while true
do
        read -n 1 -r char
        echo -n "$char" >> "$1"
        sync
done
