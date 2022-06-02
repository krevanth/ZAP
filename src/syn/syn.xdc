# // ---------------------------------------------------------------------------
# // --                                                                       --
# // --             (C) 2016-2022 Revanth Kamaraj (krevanth)                  --
# // --                                                                       -- 
# // -- ------------------------------------------------------------------------
# // --                                                                       --
# // -- This program is free software; you can redistribute it and/or         --
# // -- modify it under the terms of the GNU General Public License           --
# // -- as published by the Free Software Foundation; either version 2        --
# // -- of the License, or (at your option) any later version.                --
# // --                                                                       --
# // -- This program is distributed in the hope that it will be useful,       --
# // -- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
# // -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
# // -- GNU General Public License for more details.                          --
# // --                                                                       --
# // -- You should have received a copy of the GNU General Public License     --
# // -- along with this program; if not, write to the Free Software           --
# // -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA         --
# // -- 02110-1301, USA.                                                      --
# // --                                                                       --
# // ---------------------------------------------------------------------------

set FREQ_MHZ   150.0

###############################################################################

set CLK_PERIOD_NS [expr 1000.0/$FREQ_MHZ]
set IN_DEL_NS     [expr $CLK_PERIOD_NS/2.0]

create_clock -period $CLK_PERIOD_NS -name i_clk [get_ports i_clk]

set_input_delay -clock [get_clocks i_clk] -min    -add_delay       $IN_DEL_NS [get_ports {i_wb_dat[*]}]
set_input_delay -clock [get_clocks i_clk] -min    -add_delay       $IN_DEL_NS [get_ports i_fiq]
set_input_delay -clock [get_clocks i_clk] -min    -add_delay       $IN_DEL_NS [get_ports i_irq]
set_input_delay -clock [get_clocks i_clk] -min    -add_delay       $IN_DEL_NS [get_ports i_reset]
set_input_delay -clock [get_clocks i_clk] -min    -add_delay       $IN_DEL_NS [get_ports i_wb_ack]
set_input_delay -clock [get_clocks i_clk] -max    -add_delay       $IN_DEL_NS [get_ports {i_wb_dat[*]}]
set_input_delay -clock [get_clocks i_clk] -max    -add_delay       $IN_DEL_NS [get_ports i_fiq]
set_input_delay -clock [get_clocks i_clk] -max    -add_delay       $IN_DEL_NS [get_ports i_irq]
set_input_delay -clock [get_clocks i_clk] -max    -add_delay       $IN_DEL_NS [get_ports i_reset]
set_input_delay -clock [get_clocks i_clk] -max    -add_delay       $IN_DEL_NS [get_ports i_wb_ack]

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



