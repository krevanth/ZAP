##################################################
#        (C) 2016-2018 Revanth Kamaraj
##################################################
# SDC Constraints for the design.
##################################################

create_clock     -period 10       [get_ports SYS_CLK]     -name  core_clk
set_input_delay  -max    5        [all_inputs]            -clock core_clk
set_input_delay  -min    1        [all_inputs]            -clock core_clk
set_output_delay -max    5        [all_outputs]           -clock core_clk
set_output_delay -min   -5        [all_outputs]           -clock core_clk

