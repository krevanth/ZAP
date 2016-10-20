`default_nettype none

module ones_counter 
(
        input wire [15:0]    i_word,
        output reg [11:0]    o_offset
);

always @*
begin: blk1
        integer i;

        o_offset = 0;

        for(i=0;i<16;i=i+1)
                o_offset = o_offset + i_word[i];

        o_offset = (o_offset << 2);
end

endmodule
