`include "zap_defines.vh"

module model_ram_dual_src #(parameter SIZE_IN_BYTES = 4096)  (

input           i_clk,

input           i_wb_cyc,
input           i_wb_stb,
input [31:0]    i_wb_adr,
input [31:0]    i_wb_dat,
input  [3:0]    i_wb_sel,
input           i_wb_we,

input           i_cache_rd_en,

output reg [31:0] o_wb_dat_nocache,
output reg [127:0] o_wb_dat_cache,
output reg        o_data_src,
output reg        o_wb_ack

);

parameter FORCE_SRC_EN = 1'd0;
parameter FORCE_SRC = 1'd0;
parameter NOREG = 1'd0;

reg [31:0] ram [SIZE_IN_BYTES/4 -1:0];

initial
begin:blk1
        integer i;
        integer j;
        reg [7:0] mem [SIZE_IN_BYTES-1:0];

                j = 0;

                for ( i=0;i<SIZE_IN_BYTES;i=i+1)
                        mem[i] = 8'd0;

                `include `MEMORY_IMAGE

                for (i=0;i<SIZE_IN_BYTES/4;i=i+1)
                begin
                        ram[i] = {mem[j+3], mem[j+2], mem[j+1], mem[j]};
                        j = j + 4;
                end
end

integer seed = `SEED;

initial
begin
        o_wb_ack = 1'd0;
end

wire [31:0] adr = ( i_wb_adr >> 4 ) << 4; // Mask lower 4 zeros.

reg [127:0] o_wb_dat_cache_t;

reg sel;

generate
if ( NOREG == 0 ) // REG is not in CPU but here.
begin
        always @ (posedge i_clk)
        begin
                if ( i_cache_rd_en )
                        o_wb_dat_cache <= o_wb_dat_cache_t;
        end
end
else // NOREG = 1; Reg is in CPU not here.
begin
        always @* o_wb_dat_cache = o_wb_dat_cache_t;
end
endgenerate

// Wishbone RAM model.
always @ (negedge i_clk)
begin:blk
        reg stall;

        stall = $random(seed);

        if ( !FORCE_SRC_EN )
                sel   = $random(seed);
        else
                sel   = FORCE_SRC;

        if ( !i_wb_we && i_wb_cyc && i_wb_stb && !stall )
        begin
                o_wb_ack <= 1'd1;

                o_wb_dat_cache_t <= 'dx;
                o_wb_dat_nocache <= 'dx;
                o_data_src       <= sel;

                if ( sel )
                        o_wb_dat_cache_t <= {     
                                                ram [((adr >> 2) + 30'h3) & 30'h3fffffff], 
                                                ram [((adr >> 2) + 30'h2) & 30'h3fffffff], 
                                                ram [((adr >> 2) + 30'h1) & 30'h3fffffff], 
                                                ram [((adr >> 2) + 30'h0) & 30'h3fffffff]
                        };  
                else
                        o_wb_dat_nocache <= ram [ i_wb_adr >> 2 ];
        end
        else if ( i_wb_we && i_wb_cyc && i_wb_stb && !stall )
        begin
                o_wb_ack <= 1'd1;

                o_wb_dat_cache_t <= 'dx;
                o_wb_dat_nocache <= 'dx;
                o_data_src       <= 'dx;

                if ( i_wb_sel[0] ) ram [ i_wb_adr >> 2 ][7:0]   <= i_wb_dat[7:0];
                if ( i_wb_sel[1] ) ram [ i_wb_adr >> 2 ][15:8]  <= i_wb_dat[15:8];
                if ( i_wb_sel[2] ) ram [ i_wb_adr >> 2 ][23:16] <= i_wb_dat[23:16];
                if ( i_wb_sel[3] ) ram [ i_wb_adr >> 2 ][31:24] <= i_wb_dat[31:24];
        end
        else
        begin
                o_wb_ack    <= 1'd0;

                o_wb_dat_cache_t <= 'dx;
                o_wb_dat_nocache <= 'dx;
                o_data_src       <= 'dx;
        end
end

endmodule

///////////////////////////////////////////////////////////////////////////////


module zap_test; // +nctop+zap_test

// Bench related.

parameter RAM_SIZE                      = 32768;

parameter START                         = 1992;
parameter COUNT                         = 120;

`define STALL
`define IRQ_EN
`define MAX_CLOCK_CYCLES 100000

// CPU config.

parameter CACHE_MMU_ENABLE              = 0;
parameter DATA_SECTION_TLB_ENTRIES      = 4;
parameter DATA_LPAGE_TLB_ENTRIES        = 8;
parameter DATA_SPAGE_TLB_ENTRIES        = 16;
parameter DATA_CACHE_SIZE               = 1024;

parameter CODE_SECTION_TLB_ENTRIES      = 4;
parameter CODE_LPAGE_TLB_ENTRIES        = 8;
parameter CODE_SPAGE_TLB_ENTRIES        = 16;
parameter CODE_CACHE_SIZE               = 1024;


///////////////////////////////////////////////////////////////////////////////

reg             i_clk;
reg             i_clk_multipump;
reg             i_reset;

reg             i_irq;
reg             i_fiq;

wire            instr_wb_cyc;
wire            instr_wb_stb;
wire [3:0]      instr_wb_sel;
wire            instr_wb_we;
wire [127:0]     instr_wb_dat[1:0];
wire            instr_src;
wire [31:0]     instr_wb_adr;
wire            instr_wb_ack;

wire            data_wb_cyc;
wire            data_wb_stb;
wire [3:0]      data_wb_sel;
wire            data_wb_we;
wire [127:0]     data_wb_din [1:0];
wire [31:0]     data_wb_dout; // dir w.r.t core.
wire [31:0]     data_wb_adr;
wire            data_wb_ack;
wire            data_src;

initial
begin
      
$display("parameter RAM_SIZE              %d", RAM_SIZE           ); 
$display("parameter START                 %d", START              ); 
$display("parameter COUNT                 %d", COUNT              ); 

`ifdef STALL
        $display("STALL defined!");
`endif

`ifdef IRQ_EN
        $display("IRQ_EN defined!");
`endif

`ifdef FIQ_EN
        $display("FIQ_EN defined!");
`endif

`ifdef MAX_CLOCK_CYCLES
        $display("MAX_CLOCK_CYCLES defined!");
`endif

// CPU config.

$display("parameter CACHE_MMU_ENABLE              = %d", CACHE_MMU_ENABLE            ) ;
$display("parameter DATA_SECTION_TLB_ENTRIES      = %d", DATA_SECTION_TLB_ENTRIES    ) ;
$display("parameter DATA_LPAGE_TLB_ENTRIES        = %d", DATA_LPAGE_TLB_ENTRIES      ) ;
$display("parameter DATA_SPAGE_TLB_ENTRIES        = %d", DATA_SPAGE_TLB_ENTRIES      ) ;
$display("parameter DATA_CACHE_SIZE               = %d", DATA_CACHE_SIZE             ) ;
$display("parameter CODE_SECTION_TLB_ENTRIES      = %d", CODE_SECTION_TLB_ENTRIES    ) ;
$display("parameter CODE_LPAGE_TLB_ENTRIES        = %d", CODE_LPAGE_TLB_ENTRIES      ) ;
$display("parameter CODE_SPAGE_TLB_ENTRIES        = %d", CODE_SPAGE_TLB_ENTRIES      ) ;
$display("parameter CODE_CACHE_SIZE               = %d", CODE_CACHE_SIZE             ) ;

end

wire ird_en, drd_en;
reg [1023:0] tick;

initial tick = 0;

integer errm;
integer perc = 32'hffffffff;

`ifdef LINUX

initial
begin
        // Write status bar out to STDERR.
        errm = $fopen("/dev/stderr");
end

always @ (posedge i_clk)
begin
        //if ( perc != (tick * 100)/`MAX_CLOCK_CYCLES ) 
        //begin
                perc =  (tick * 100)/`MAX_CLOCK_CYCLES; 
                draw_line(perc);
        //end

        tick=tick + 1;
end

task draw_line ( input [31:0] x ) ;
begin: mt1
        integer j;

        $fwrite(errm, "[");

        for(j=0;j<x;j=j+1)
        begin
                $fwrite(errm, "▇");
        end


        while(j<100)
        begin 
                $fwrite(errm, " ");
                j=j+1;
        end


        $fwrite(errm, "] %d percent", x);
        $fwrite(errm,"\015");

        if ( x == 100 )
        begin
                $fwrite(errm, "\n");
        end
end        
endtask

`endif

always @*
begin
        if ( instr_wb_dat[0] === 1'dx )
        begin
                $display("*E: Wishbone reporting x...! Terminating simulation...");        
                $finish;
        end
end

// =========================
// Processor core.
// =========================
zap_top #(

        // enable cache and mmu.
        .CACHE_MMU_ENABLE(CACHE_MMU_ENABLE),

        // data config.
        .DATA_SECTION_TLB_ENTRIES(DATA_SECTION_TLB_ENTRIES),
        .DATA_LPAGE_TLB_ENTRIES(DATA_LPAGE_TLB_ENTRIES),
        .DATA_SPAGE_TLB_ENTRIES(DATA_SPAGE_TLB_ENTRIES),
        .DATA_CACHE_SIZE(DATA_CACHE_SIZE),

        // code config.
        .CODE_SECTION_TLB_ENTRIES(CODE_SECTION_TLB_ENTRIES),
        .CODE_LPAGE_TLB_ENTRIES(CODE_LPAGE_TLB_ENTRIES),
        .CODE_SPAGE_TLB_ENTRIES(CODE_SPAGE_TLB_ENTRIES),
        .CODE_CACHE_SIZE(CODE_CACHE_SIZE)
) 
u_zap_top 
(
        .i_clk(i_clk),
        .i_clk_multipump(i_clk_multipump),
        .i_reset(i_reset),
        .i_irq(i_irq),
        .i_fiq(i_fiq),

        .o_instr_wb_cyc(instr_wb_cyc),
        .o_instr_wb_stb(instr_wb_stb),
        .o_instr_wb_adr(instr_wb_adr),
        .o_instr_wb_we(instr_wb_we),
        .i_instr_wb_err(1'd0),
        .i_instr_wb_dat(instr_wb_dat[0][31:0]),


        .i_instr_wb_ack(instr_wb_ack),
        .o_instr_wb_sel(instr_wb_sel),
        .o_data_wb_cyc(data_wb_cyc),
        .o_data_wb_stb(data_wb_stb),
        .o_data_wb_adr(data_wb_adr),
        .o_data_wb_we(data_wb_we),
        .i_data_wb_err(1'd0),
        .i_data_wb_dat(data_wb_din[0][31:0]),




        .o_data_wb_dat(data_wb_dout),
        .i_data_wb_ack(data_wb_ack),
        .o_data_wb_sel(data_wb_sel)

);

// ===========================
// CODE RAM
// ===========================
model_ram_dual_src
#(
        .SIZE_IN_BYTES  (RAM_SIZE),
        .FORCE_SRC_EN   (1'd1),
        .FORCE_SRC      (1'd0),
        .NOREG          (0) // Regd in CPU.
)
U_MODEL_RAM_CODE
(
        .i_clk(i_clk),

        .i_cache_rd_en(1'd0),
        .i_wb_cyc(instr_wb_cyc),
        .i_wb_stb(instr_wb_stb),
        .i_wb_adr(instr_wb_adr),
        .i_wb_we(instr_wb_we),
        .o_wb_dat_nocache(instr_wb_dat[0][31:0]),
        .o_wb_dat_cache(instr_wb_dat[1]),
        .o_data_src(instr_src),
        .o_wb_ack(instr_wb_ack),
        .i_wb_sel(instr_wb_sel),
        .i_wb_dat(32'd0)
);

// ===============================
// DATA RAM
// ===============================
model_ram_dual_src
#(
        .SIZE_IN_BYTES  (RAM_SIZE),
        .FORCE_SRC_EN   (1'd1),
        .FORCE_SRC      (1'd0),
        .NOREG          (0) // Regd in CPU.
)
U_MODEL_RAM_DATA
(
        .i_cache_rd_en(1'd0),
        .i_clk(i_clk),
        .i_wb_cyc(data_wb_cyc),
        .i_wb_stb(data_wb_stb),
        .i_wb_adr(data_wb_adr),
        .i_wb_we(data_wb_we),
        .o_wb_dat_nocache(data_wb_din[0][31:0]),
        .o_wb_dat_cache(data_wb_din[1]),
        .o_data_src(data_src),
        .i_wb_dat(data_wb_dout),
        .o_wb_ack(data_wb_ack),
        .i_wb_sel(data_wb_sel)

);

// ===========================
// Variables.
// ===========================
integer i;

// ===========================
// Clocks.
// ===========================
initial i_clk    = 0;
always #10 i_clk = !i_clk;

initial
begin
        i_clk_multipump = 0;

        #5;
        forever #5 i_clk_multipump = !i_clk_multipump;        
end

integer seed = `SEED;

`ifdef IRQ_EN

always @ (negedge i_clk)
begin
        i_irq = $random;
end

`endif

initial
begin
        i_irq = 0;
        i_fiq = 0;

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA INITIAL :: mem[%d] = %x", i, {U_MODEL_RAM_DATA.ram[(i/4)]});
        end

        $dumpfile(`VCD_FILE_PATH);
        $dumpvars;

        $display("Started!");

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat(`MAX_CLOCK_CYCLES) @(negedge i_clk);

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA mem[%d] = %x", i, {U_MODEL_RAM_DATA.ram[(i/4)]});
        end

        $finish;
end

endmodule
