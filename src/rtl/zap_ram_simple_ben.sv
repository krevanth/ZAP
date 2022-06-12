// -----------------------------------------------------------------------------
// --                                                                         --
// --    (C) 2016-2022 Revanth Kamaraj (krevanth)                             --
// --                                                                         -- 
// -- --------------------------------------------------------------------------
// --                                                                         --
// -- This program is free software; you can redistribute it and/or           --
// -- modify it under the terms of the GNU General Public License             --
// -- as published by the Free Software Foundation; either version 2          --
// -- of the License, or (at your option) any later version.                  --
// --                                                                         --
// -- This program is distributed in the hope that it will be useful,         --
// -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
// -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
// -- GNU General Public License for more details.                            --
// --                                                                         --
// -- You should have received a copy of the GNU General Public License       --
// -- along with this program; if not, write to the Free Software             --
// -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
// -- 02110-1301, USA.                                                        --
// --                                                                         --
// -----------------------------------------------------------------------------
// --                                                                         -- 
// -- This is a pipelined memory macro for high performance.                  --
// --                                                                         --
// -----------------------------------------------------------------------------

module zap_ram_simple_ben #(
        parameter WIDTH = 32,
        parameter DEPTH = 32
)
(
        input logic                          i_clk,
        input logic                          i_clken,

        // Write and read enable.
        input logic [WIDTH/8-1:0]            i_wr_en,

        // Write data and address.
        input logic [WIDTH-1:0]              i_wr_data,
        input logic[$clog2(DEPTH)-1:0]       i_wr_addr,

        // Read address and data.
        input logic [$clog2(DEPTH)-1:0]      i_rd_addr,

        // 2 cycle delayed read data.
        output logic [WIDTH-1:0]             o_rd_data_pre,

        // 3 cycle delayed read data.
        output logic [WIDTH-1:0]             o_rd_data
);

// ----------------------------------------------------------------------------
// Stage 1
// ----------------------------------------------------------------------------

// Memory array.
logic [WIDTH-1:0] mem [DEPTH-1:0];

// Hazard detection.
logic [WIDTH-1:0]         mem_data_st1;
logic [WIDTH-1:0]         buffer_st1;
logic [WIDTH/8-1:0]       sel_st1;
logic [$clog2(DEPTH)-1:0] rd_addr_st1, rd_addr_st2;
logic [WIDTH-1:0]         rd_data_st1;

// ----------------------------------------------------------------------------

// Write logic.
always_ff @ (posedge i_clk) if ( i_clken )
begin
        for(int i=0;i<WIDTH/8;i++)
        begin
                if ( i_wr_en[i] )  
                        mem [ i_wr_addr ][ i*8 +: 8 ] <= i_wr_data [i*8 +: 8];
        end
end

// ----------------------------------------------------------------------------
// Stage 1
// ----------------------------------------------------------------------------

// Hazard Detection Logic
always_ff @ ( posedge i_clk ) if ( i_clken )
begin
        for(int i=0;i<WIDTH/8;i++)
        begin
                if ( i_wr_addr == i_rd_addr && i_wr_en[i] )
                        sel_st1[i] <= 1'd1;
                else
                        sel_st1[i] <= 1'd0;                
        end
end

// Buffer update logic.
always_ff @ ( posedge i_clk ) if ( i_clken )
begin
        buffer_st1  <= i_wr_data;
        rd_addr_st1 <= i_rd_addr;
end

// RAM Read logic.
always_ff @ (posedge i_clk) if ( i_clken )
begin
        mem_data_st1 <= mem [ i_rd_addr ];
end

// ----------------------------------------------------------------------------

// Output logic.
always_comb
begin
        for(int i=0;i<WIDTH/8;i++)
        begin
                if ( sel_st1[i] )
                        rd_data_st1[i*8 +: 8] = buffer_st1[i*8 +: 8];
                else
                        rd_data_st1[i*8 +: 8] = mem_data_st1[i*8 +: 8];
        end
end

// ----------------------------------------------------------------------------
// Stage 2
// ----------------------------------------------------------------------------

always_ff @ ( posedge i_clk ) if ( i_clken )
begin
        for(int i=0;i<WIDTH/8;i++)
        begin
                if ( i_wr_addr == rd_addr_st1 && i_wr_en[i] )
                        o_rd_data_pre[i*8 +: 8] <= i_wr_data [i*8 +: 8] ;
                else
                        o_rd_data_pre[i*8 +: 8] <= rd_data_st1 [i*8 +: 8];
        end
end

always_ff @ ( posedge i_clk ) if ( i_clken )
begin
        rd_addr_st2 <= rd_addr_st1;
end

// ----------------------------------------------------------------------------
// Stage 3
// ----------------------------------------------------------------------------

always_ff @ ( posedge i_clk ) if ( i_clken )
begin
        for(int i=0;i<WIDTH/8;i++)
        begin
                if ( i_wr_addr == rd_addr_st2 && i_wr_en[i] )
                        o_rd_data[i*8 +: 8] <= i_wr_data[i*8 +: 8];
                else
                        o_rd_data[i*8 +: 8] <= o_rd_data_pre[i*8 +: 8];
        end
end

endmodule // zap_ram_simple.v


// ----------------------------------------------------------------------------
// EOF
// ----------------------------------------------------------------------------
