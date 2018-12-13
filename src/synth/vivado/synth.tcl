#############################################
# (C) 2016-2018 Revanth Kamaraj
#############################################
# Synthesis helper script. Reads files,
# sets up device, loads XDC and call the
# synthesis program.
#############################################

set TOP_MODULE  {chip_top}
set FPGA_PART   {xc7a35tiftg256-1L}
set RTL_PATH    {../../../src/rtl}
set XDC_PATH    {../../../src/synth/vivado/synth.xdc}

create_project $TOP_MODULE -in_memory -part $FPGA_PART

add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/raminfr.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_debug_if.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_top.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_tfifo.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_sync_flops.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_receiver.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_regs.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_defines.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_transmitter.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_wb.v
add_files -verbose -scan_for_includes $RTL_PATH/External_IP/uart16550/rtl/uart_rfifo.v
add_files -verbose -scan_for_includes $RTL_PATH/timer/timer.v
add_files -verbose -scan_for_includes $RTL_PATH/TOP/chip_top.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_mem_inv_block.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_fetch_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_wb_merger.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_predecode_compress.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_cache.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_alu_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_decode.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_wb_adapter.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_predecode_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_tlb_fsm.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_ram_simple.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_predecode_mem_fsm.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_predecode_coproc.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_cache_tag_ram.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_cp15_cb.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_writeback.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_shift_shifter.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_decompile.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_memory_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_sync_fifo.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_tlb_check.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_tlb.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_core.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_shifter_multiply.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_fifo.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_cache_fsm.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_top.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_decode_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_register_file.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_shifter_main.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_thumb_decoder.v
add_files -verbose -scan_for_includes $RTL_PATH/cpu/zap_issue_main.v
add_files -verbose -scan_for_includes $RTL_PATH/vic/vic.v

read_xdc $XDC_PATH

synth_design -retiming -name $TOP_MODULE -top $TOP_MODULE -part $FPGA_PART -verilog_define SYNTHESIS -no_iobuf -mode out_of_context

report_timing -nworst 200 -from [all_registers] -to [all_registers] > reg2reg_timing_summary.rpt
report_timing -nworst 200 -from [all_registers] -to [all_outputs]   > reg2out_timing_summary.rpt 
report_timing -nworst 200 -from [all_inputs]    -to [all_registers] > in2reg_timing_summary.rpt
report_timing -nworst 200 -from [all_inputs]    -to [all_outputs]   > in2out_timing_summary.rpt

