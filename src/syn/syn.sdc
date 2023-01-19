#
# (C) 2016-2022 Revanth Kamaraj (krevanth)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.
#

# Target 170MHz clock speed.
create_clock -period 5.000 -name i_clk -waveform {0.000 2.500} [get_ports i_clk]

# Inputs are directly driven from FF.
set_input_delay -clock [get_clocks i_clk] -add_delay 1.000 [get_ports {i_wb_dat[*]}]
set_input_delay -clock [get_clocks i_clk] -add_delay 1.000 [get_ports i_reset]
set_input_delay -clock [get_clocks i_clk] -add_delay 1.000 [get_ports i_wb_ack]
set_input_delay -clock [get_clocks i_clk] -add_delay 1.000 [get_ports i_wb_err]

#
# False path. Design ensures it is silent when MMU setting changes. The through
# syntax is not preferable, but need it to work around a Vivado bug.
#
set_false_path -through [get_pins l_generate_with_cache_mmu.u_data_cache/u_zap_tlb/u_zap_tlb_fsm/i_mmu_en]

# Design has double flop synchronizer.
set_false_path -from [get_ports i_fiq]
set_false_path -from [get_ports i_irq]

# Output pin configuration.
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports {o_wb_adr[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports {o_wb_cti[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports {o_wb_dat[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports {o_wb_sel[*]}]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports o_wb_cyc]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports o_wb_stb]
set_output_delay -clock [get_clocks i_clk] -max -add_delay 2.000 [get_ports o_wb_we]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_adr[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_cti[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_dat[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports {o_wb_sel[*]}]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_cyc]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_we]
set_output_delay -clock [get_clocks i_clk] -min -add_delay -1.000 [get_ports o_wb_stb]


