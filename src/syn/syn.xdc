create_clock     -period 7.140 -name i_clk -waveform {0.000 3.570} [get_ports i_clk]

set_input_delay  -clock [get_clocks i_clk] -min -add_delay 3.570 [get_ports {i_wb_dat[*]}]
set_input_delay  -clock [get_clocks i_clk] -min -add_delay 3.570 [get_ports i_fiq]
set_input_delay  -clock [get_clocks i_clk] -min -add_delay 3.570 [get_ports i_irq]
set_input_delay  -clock [get_clocks i_clk] -min -add_delay 3.570 [get_ports i_reset]
set_input_delay  -clock [get_clocks i_clk] -min -add_delay 3.570 [get_ports i_wb_ack]

set_input_delay  -clock [get_clocks i_clk] -max -add_delay 3.570 [get_ports {i_wb_dat[*]}]
set_input_delay  -clock [get_clocks i_clk] -max -add_delay 3.570 [get_ports i_fiq]
set_input_delay  -clock [get_clocks i_clk] -max -add_delay 3.570 [get_ports i_irq]
set_input_delay  -clock [get_clocks i_clk] -max -add_delay 3.570 [get_ports i_reset]
set_input_delay  -clock [get_clocks i_clk] -max -add_delay 3.570 [get_ports i_wb_ack]

set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports {o_wb_adr[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports {o_wb_cti[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports {o_wb_dat[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports {o_wb_sel[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports o_wb_cyc]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports o_wb_stb]
set_output_delay -clock [get_clocks i_clk] -max -add_delay  2.000 [get_ports o_wb_we]

set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_adr[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_cti[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_dat[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_sel[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_cyc]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_we]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_stb]


