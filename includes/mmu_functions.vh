// MMU functions. Verilog -2001.
// Author : Revanth Kamaraj.
// MIT License (C)2016.

task kill_memory_op;
begin
        o_ram_wr_en   = 1'd0;
        o_ram_rd_en   = 1'd0;
        o_ram_address = 32'd0;
        o_ram_ben     = 4'd0;
        o_ram_wr_data = 32'd0;
end
endtask


task generate_memory_write ( input [31:0] address );
begin
           o_ram_wr_data = i_wr_data;
           o_ram_address = address;  
           o_ram_ben     = i_ben;
           o_ram_wr_en   = 1'd1;
           o_ram_rd_en   = 1'd0;
end
endtask

task generate_memory_read ( input [31:0] address );
begin
           o_ram_wr_data = 32'd0;
           o_ram_ben     = 4'd0;
           o_ram_address = address;  
           o_ram_wr_en   = 1'd0;
           o_ram_rd_en   = 1'd1;
end
endtask


