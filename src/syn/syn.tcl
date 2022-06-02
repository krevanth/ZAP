create_project project_1 -part xc7a35tftg256-3

add_files -scan_for_includes {
../../src/rtl/zap_predecode_uop_sequencer.sv ../../src/rtl/zap_wb_merger.sv ../../src/rtl/zap_shifter_shift.sv ../../src/rtl/zap_cache_fsm.sv ../../src/rtl/zap_alu_main.sv ../../src/rtl/zap_sync_fifo.sv ../../src/rtl/zap_register_file.sv ../../src/rtl/zap_core.sv ../../src/rtl/zap_dual_rank_synchronizer.sv ../../src/rtl/zap_thumb_decoder_main.sv ../../src/rtl/zap_shifter_multiply.sv ../../src/rtl/zap_localparams.svh ../../src/rtl/zap_decode.sv ../../src/rtl/zap_decode_main.sv ../../src/rtl/zap_ram_simple.sv ../../src/rtl/zap_tlb.sv ../../src/rtl/zap_tlb_fsm.sv ../../src/rtl/zap_mem_inv_block.sv ../../src/rtl/zap_predecode_coproc.sv ../../src/rtl/zap_writeback.sv ../../src/rtl/zap_fetch_main.sv ../../src/rtl/zap_wb_adapter.sv ../../src/rtl/zap_postalu_main.sv ../../src/rtl/zap_decompile.sv ../../src/rtl/zap_fifo.sv ../../src/rtl/zap_predecode_main.sv ../../src/rtl/zap_tlb_check.sv ../../src/rtl/zap_functions.svh ../../src/rtl/zap_shifter_main.sv ../../src/rtl/zap_top.sv ../../src/rtl/zap_cache.sv ../../src/rtl/zap_cp15_cb.sv ../../src/rtl/zap_memory_main.sv ../../src/rtl/zap_ram_simple_nopipe.sv ../../src/rtl/zap_thumb_decoder.sv ../../src/rtl/zap_defines.svh ../../src/rtl/zap_issue_main.sv ../../src/rtl/zap_cache_tag_ram.sv}

update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse ../../src/syn/syn.xdc

synth_design -top zap_top -part xc7a35tftg256-3 -retiming -mode out_of_context -flatten_hierarchy none

report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose -max_paths 1000 -input_pins -file syn_timing.rpt


