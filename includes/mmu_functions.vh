/*
MIT License

Copyright (c) 2016 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

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


