module soc_top
(
                input wire                              i_clk,                  // ZAP clock.        
                input wire                              i_reset,                // Active high synchronous reset.
                output reg                              o_led                   // LED.
);

wire [31:0] idata;
wire        wr_en;
wire [31:0] daddress;
wire [31:0] iddata, oddata;
wire [3:0]  ben;
wire [31:0] iaddress;

zap_top
u_zap_top
(
                
                .i_clk(i_clk),                   // ZAP clock.        
                .i_reset(i_reset),               // Active high synchronous reset.
                
                .i_instruction(idata),           // A 32-bit ZAP instruction or a microcode instruction.
                .i_valid(1'd1),                  // Instruction valid.
                .i_instr_abort(1'd0),            // Instruction abort fault.
                
                .i_copro_done(1'd1),
                
                .o_read_en(),                    // Memory load
                .o_write_en(wr_en),              // Memory store.
                .o_address(daddress),            // Memory address.
                
                .o_mem_translate(),
                
                .i_data_stall(1'd0),
                
                .i_data_abort(1'd0),
                
                .i_rd_data(iddata),
                .o_wr_data(oddata),

                .o_ben(ben),                     // Byte enables for memory write.
                
                .i_fiq(1'd0),                   // FIQ signal.
                .i_irq(1'd0),                   // IRQ signal.
                
                .o_copro_dav(),
                .o_copro_word(),
                .o_copro_reg(),
                
                .i_copro_reg_en      (1'd0),     // Coprocessor controls register file.
                .i_copro_reg_wr_index(6'd0),     // Register write index.
                .i_copro_reg_rd_index(6'd0),     // Register read index.
                .i_copro_reg_wr_data (32'd0),     // Register write data.

                .o_copro_reg_rd_data(),          // Coprocessor read data from register file.

                .o_fiq_ack(),                   // FIQ acknowledge.
                .o_irq_ack(),                   // IRQ acknowledge.
                
                .o_pc(iaddress),                 // Program counter.

                .o_cpsr()                        // CPSR. Cache must use this to determine VM scheme for instruction fetches.
);

// SRAM.
zap_cache_main
u_zap_cache_main
(
        .i_clk(i_clk),

        .i_daddress(daddress),
        .i_iaddress(iaddress),

        .o_ddata(iddata),
        .o_idata(idata),

        .i_ben(ben),

        .i_ddata(oddata),

        .i_wr_en(wr_en)
);

// Data write to 6000 is connected to the LED.
// If you write to that, the LED will take that value.
always @ (posedge i_clk)
begin
        if ( i_reset )
                o_led <= 0;
        else if ( daddress == 6000 && wr_en )
                o_led <= |oddata;
end

endmodule

`ifdef SIM
module zap_with_cache_test;

        reg i_clk;
        reg i_reset; 

        zap_with_cache u_zap_with_cache (.i_clk(i_clk), .i_reset(i_reset));

        always #1 i_clk = !i_clk;

        initial
        begin
                $dumpfile("zap_with_cache_test.vcd");
                $dumpvars;

                $display("Sim started!");

                i_clk   = 0;
                i_reset = 1;

                @(negedge i_clk);
                i_reset = 0;

                repeat(1000) 
                        @(posedge i_clk);

                $display("Finish!");
                $finish; 
        end

endmodule
`endif

