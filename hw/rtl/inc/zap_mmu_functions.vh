// ----------------------------------------------------------------------------

/* Function to generate Wishbone read signals. */
task wb_prpr_read;
input [31:0] i_address;
input [2:0]  i_cti;
begin
        o_wb_cyc_nxt = 1'd1;
        o_wb_stb_nxt = 1'd1;
        o_wb_wen_nxt = 1'd0;
        o_wb_sel_nxt = 4'b1111;
        o_wb_adr_nxt = i_address;
        o_wb_cti_nxt = i_cti;
end
endtask

// ----------------------------------------------------------------------------

/* Function to generate Wishbone write signals */
task wb_prpr_write;
input   [31:0]  i_data;
input   [31:0]  i_address;
input   [2:0]   i_cti;
input   [3:0]   i_ben;
begin
        o_wb_cyc_nxt = 1'd1;
        o_wb_stb_nxt = 1'd1;
        o_wb_wen_nxt = 1'd1;
        o_wb_sel_nxt = i_ben;
        o_wb_adr_nxt = i_address;
        o_wb_cti_nxt = i_cti;
end
endtask

// ----------------------------------------------------------------------------

/* Disables Wishbone */
task kill_access;
begin
        o_wb_cyc_nxt = 0;
        o_wb_stb_nxt = 0;
        o_wb_wen_nxt = 0;
        o_wb_sel_nxt = 0;
        o_wb_cti_nxt = CTI_CLASSIC;
end
endtask

// ----------------------------------------------------------------------------
