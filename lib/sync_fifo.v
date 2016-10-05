module sync_fifo ( clk, rst, rd_en, wr_en, wr_data, rd_data, emp, full );

parameter WIDTH = 32;
parameter DEPTH = 32;

input                         clk;
input                         rst;
input                         rd_en;
input                         wr_en;
input      [WIDTH-1:0]        wr_data;

output reg [WIDTH-1:0]        rd_data;
output reg                    emp;
output reg                    full;

reg [WIDTH-1:0]               mem [DEPTH-1:0];
reg [$clog2(DEPTH):0]         rptr_ff, rptr_nxt;
reg [$clog2(DEPTH):0]         wptr_ff, wptr_nxt;
reg                           emp_nxt;
reg                           full_nxt;
reg [WIDTH-1:0]               data_nxt;

always @*
begin
        rptr_nxt = rptr_ff + (rd_en && !emp);
        wptr_nxt = wptr_ff + (wr_en && !full);

        emp_nxt  = (rptr_nxt == wptr_nxt);
        full_nxt = (rptr_nxt << 1 == wptr_nxt << 1) && !emp_nxt;

        data_nxt =  emp_nxt ? rd_data : 
        ( ( (wr_en && !full) && (rptr_nxt == wptr_ff) ) ? 
        wr_data : mem[ rptr_nxt [$clog2(DEPTH)-1:0] ] );
end

always @ (posedge clk)
        if ( rst )
                {wptr_ff, rptr_ff, rd_data, full, emp} <= 1;
        else
        begin
                {wptr_ff,  rptr_ff,  rd_data,  full,     emp} <= 
                {wptr_nxt, rptr_nxt, data_nxt, full_nxt, emp_nxt};

                mem [ wptr_ff[$clog2(DEPTH)-1:0] ] <= (wr_en && !full) ? 
                                   wr_data : mem [ wptr_ff[$clog2(DEPTH)-1:0] ];
        end

endmodule

