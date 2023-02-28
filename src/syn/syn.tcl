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

# We targeting an Artix-7 speed grade -3 FPGA for synthesis.
create_project project_1 -part xc7a75tcsg324-3

# Add RTL files and includes for synthesis.
add_files -scan_for_includes {
../../src/rtl/zrisc_predecode_uop_sequencer.sv \
../../src/rtl/zrisc_wb_merger.sv \
../../src/rtl/zrisc_shifter_shift.sv \
../../src/rtl/zrisc_cache_fsm.sv \
../../src/rtl/zrisc_alu_main.sv \
../../src/rtl/zrisc_sync_fifo.sv \
../../src/rtl/zrisc_register_file.sv \
../../src/rtl/zrisc_core.sv \
../../src/rtl/zrisc_dual_rank_synchronizer.sv \
../../src/rtl/zrisc_mode16_decoder_main.sv \
../../src/rtl/zrisc_shifter_multiply.sv \
../../src/rtl/zrisc_decode.sv \
../../src/rtl/zrisc_decode_main.sv \
../../src/rtl/zrisc_ram_simple.sv \
../../src/rtl/zrisc_tlb.sv \
../../src/rtl/zrisc_tlb_fsm.sv \
../../src/rtl/zrisc_mem_inv_block.sv \
../../src/rtl/zrisc_predecode_coproc.sv \
../../src/rtl/zrisc_writeback.sv \
../../src/rtl/zrisc_fetch_main.sv \
../../src/rtl/zrisc_postalu_main.sv \
../../src/rtl/zrisc_decompile.sv \
../../src/rtl/zrisc_fifo.sv \
../../src/rtl/zrisc_predecode_main.sv \
../../src/rtl/zrisc_tlb_check.sv \
../../src/rtl/zrisc_shifter_main.sv \
../../src/rtl/zrisc_top.sv \
../../src/rtl/zrisc_cache.sv \
../../src/rtl/zrisc_cp15_cb.sv \
../../src/rtl/zrisc_memory_main.sv \
../../src/rtl/zrisc_ram_simple_nopipe.sv \
../../src/rtl/zrisc_mode16_decoder.sv \
../../src/rtl/zrisc_issue_main.sv \
../../src/rtl/zrisc_cache_tag_ram.sv \
../../src/rtl/zrisc_dcache_fsm.sv \
../../src/rtl/zrisc_dcache.sv \
../../src/rtl/zrisc_btb.sv \
../../src/rtl/zrisc_ram_simple_ben.sv\
}

# Create a sources_1 fileset.
update_compile_order \
-fileset sources_1

# Add XDC file into the mix, into constrs_1.
add_files -fileset constrs_1 -norecurse ../../src/syn/syn.xdc

#
# Synthesize the design with Vivado high performance defaults, as seen in
# the GUI.
#
synth_design \
-top zrisc_top \
-part xc7a75tcsg324-3 \
-gated_clock_conversion auto \
-directive PerformanceOptimized \
-retiming \
-keep_equivalent_registers \
-resource_sharing off \
-no_lc \
-shreg_min_size 5 \
-mode out_of_context

#
# Generate a timing report for the worst 1000 paths. We expect the timing
# report to be clean.
#
report_timing_summary \
-delay_type max \
-report_unconstrained \
-check_timing_verbose \
-max_paths 1000 \
-input_pins \
-file syn_timing.rpt

#
# Generate a DCP file that can be loaded for further runs to integrate
# the design into an SOC.
#
write_checkpoint zrisc.dcp

###############################################################################
# EOF
###############################################################################
