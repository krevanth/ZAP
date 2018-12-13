##################################################
#        (C) 2016-2018 Revanth Kamaraj
##################################################
# SDC Constraints for the design.
##################################################

create_clock     -period 11.5       [get_ports SYS_CLK]     -name  core_clk
set_input_delay           5.7       [all_inputs]            -clock core_clk
set_output_delay          5.7       [all_outputs]           -clock core_clk

