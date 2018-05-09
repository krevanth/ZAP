`include "zap_defines.vh"

module model_ram_dual #(parameter SIZE_IN_BYTES = 4096)  (

input                   i_clk,

input                   i_wb_cyc,
input                   i_wb_stb,
input [31:0]            i_wb_adr,
input [31:0]            i_wb_dat,
input  [3:0]            i_wb_sel,
input                   i_wb_we,

// unused.
input                   i_wb_cyc2,
input                   i_wb_stb2,
input   [31:0]          i_wb_adr2,
input   [31:0]          i_wb_dat2,
input   [3:0]           i_wb_sel2,
input                   i_wb_we2,

output reg [31:0]       o_wb_dat,
output reg [31:0]       o_wb_dat2, // unused.

output reg              o_wb_ack,
output reg              o_wb_ack2 // unused.

);

integer seed = `SEED;
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

initial o_wb_ack = 1'd0;


// Wishbone RAM model.
always @ (negedge i_clk)
begin:blk
        reg stall;

        stall = $random(seed);

        if ( !i_wb_we && i_wb_cyc && i_wb_stb && !stall )
        begin
                o_wb_ack         <= 1'd1;
                o_wb_dat         <= ram [ i_wb_adr >> 2 ];
        end
        else if ( i_wb_we && i_wb_cyc && i_wb_stb && !stall )
        begin
                o_wb_ack         <= 1'd1;
                o_wb_dat         <= 'dx;

                if ( i_wb_sel[0] ) ram [ i_wb_adr >> 2 ][7:0]   <= i_wb_dat[7:0];
                if ( i_wb_sel[1] ) ram [ i_wb_adr >> 2 ][15:8]  <= i_wb_dat[15:8];
                if ( i_wb_sel[2] ) ram [ i_wb_adr >> 2 ][23:16] <= i_wb_dat[23:16];
                if ( i_wb_sel[3] ) ram [ i_wb_adr >> 2 ][31:24] <= i_wb_dat[31:24];
        end
        else
        begin
                o_wb_ack    <= 1'd0;
                o_wb_dat    <= 'dx;
        end
end

// Wishbone RAM model.
always @ (negedge i_clk)
begin:blk2
        reg stall2;

        stall2 = $random(seed);

        if ( !i_wb_we2 && i_wb_cyc2 && i_wb_stb2 && !stall2 )
        begin
                o_wb_ack2         <= 1'd1;
                o_wb_dat2         <= ram [ i_wb_adr2 >> 2 ];
        end
        else if ( i_wb_we2 && i_wb_cyc2 && i_wb_stb2 && !stall2 )
        begin
                o_wb_ack2         <= 1'd1;
                o_wb_dat2         <= 'dx;

                if ( i_wb_sel2[0] ) ram [ i_wb_adr2 >> 2 ][7:0]   <= i_wb_dat2[7:0];
                if ( i_wb_sel2[1] ) ram [ i_wb_adr2 >> 2 ][15:8]  <= i_wb_dat2[15:8];
                if ( i_wb_sel2[2] ) ram [ i_wb_adr2 >> 2 ][23:16] <= i_wb_dat2[23:16];
                if ( i_wb_sel2[3] ) ram [ i_wb_adr2 >> 2 ][31:24] <= i_wb_dat2[31:24];
        end
        else
        begin
                o_wb_ack2    <= 1'd0;
                o_wb_dat2    <= 'dx;
        end
end

endmodule

///////////////////////////////////////////////////////////////////////////////


module zap_test; // +nctop+zap_test

// Bench related.

//`define STALL
//`define IRQ_EN
//`define MAX_CLOCK_CYCLES 100000

// CPU config.
parameter RAM_SIZE                      = 32768;
parameter START                         = 1992;
parameter COUNT                         = 120;
parameter DATA_SECTION_TLB_ENTRIES      = 4;
parameter DATA_LPAGE_TLB_ENTRIES        = 8;
parameter DATA_SPAGE_TLB_ENTRIES        = 16;
parameter DATA_CACHE_SIZE               = 1024;
parameter CODE_SECTION_TLB_ENTRIES      = 4;
parameter CODE_LPAGE_TLB_ENTRIES        = 8;
parameter CODE_SPAGE_TLB_ENTRIES        = 16;
parameter CODE_CACHE_SIZE               = 1024;
parameter FIFO_DEPTH                    = 4;
parameter BP_ENTRIES                    = 1024;
parameter STORE_BUFFER_DEPTH            = 32;

///////////////////////////////////////////////////////////////////////////////

reg             i_clk;
reg             i_reset;

reg             i_irq;
reg             i_fiq;

wire            instr_wb_cyc;
wire            instr_wb_stb;
wire [3:0]      instr_wb_sel;
wire            instr_wb_we;
wire [127:0]     instr_wb_dat[1:0];
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

initial
begin
      
$display("parameter RAM_SIZE              %d", RAM_SIZE           ); 
$display("parameter START                 %d", START              ); 
$display("parameter COUNT                 %d", COUNT              ); 
$display("parameter FIFO_DEPTH            %d", u_zap_top.FIFO_DEPTH);

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

`ifdef TLB_DEBUG
        $display("TLB_DEBUG defined!");
`endif

// CPU config.

$display("parameter DATA_SECTION_TLB_ENTRIES      = %d", DATA_SECTION_TLB_ENTRIES    ) ;
$display("parameter DATA_LPAGE_TLB_ENTRIES        = %d", DATA_LPAGE_TLB_ENTRIES      ) ;
$display("parameter DATA_SPAGE_TLB_ENTRIES        = %d", DATA_SPAGE_TLB_ENTRIES      ) ;
$display("parameter DATA_CACHE_SIZE               = %d", DATA_CACHE_SIZE             ) ;
$display("parameter CODE_SECTION_TLB_ENTRIES      = %d", CODE_SECTION_TLB_ENTRIES    ) ;
$display("parameter CODE_LPAGE_TLB_ENTRIES        = %d", CODE_LPAGE_TLB_ENTRIES      ) ;
$display("parameter CODE_SPAGE_TLB_ENTRIES        = %d", CODE_SPAGE_TLB_ENTRIES      ) ;
$display("parameter CODE_CACHE_SIZE               = %d", CODE_CACHE_SIZE             ) ;
$display("parameter STORE_BUFFER_DEPTH            = %d", STORE_BUFFER_DEPTH          ) ;
end

wire ird_en, drd_en;
reg [1023:0] tick;

initial tick = 0;

integer errm;
integer perc = 32'hffffffff;

always @ (posedge i_clk)
begin
	`ifdef DISP_PERC
                perc =  (tick * 100)/`MAX_CLOCK_CYCLES; 
                draw_line(perc);
                tick=tick + 1;
	`endif
end

task draw_line ( input [31:0] x ) ;
begin: mt1
	`ifdef DISP_PERC
        	$display("COMPLETED :: %d percent", x);
	`endif
end        
endtask

wire [2:0] data_wb_cti; // Cycle Type Indicator.

// =========================
// Processor core.
// =========================
zap_top #(
        // Configure FIFO depth and BP entries.
        .FIFO_DEPTH(FIFO_DEPTH),
        .BP_ENTRIES(BP_ENTRIES),
        .STORE_BUFFER_DEPTH(STORE_BUFFER_DEPTH),

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
        .i_reset(i_reset),
        .i_irq(i_irq),
        .i_fiq(i_fiq),

        .o_wb_cyc(data_wb_cyc),
        .o_wb_stb(data_wb_stb),
        .o_wb_adr(data_wb_adr),
        .o_wb_we(data_wb_we),
        .o_wb_cti(data_wb_cti),
        .i_wb_dat(data_wb_din[0][31:0]),
        .o_wb_dat(data_wb_dout),
        .i_wb_ack(data_wb_ack),
        .o_wb_sel(data_wb_sel)

);

// ===============================
// RAM
// ===============================
model_ram_dual
#(
        .SIZE_IN_BYTES  (RAM_SIZE)
)
U_MODEL_RAM_DATA
(
        .i_clk(i_clk),

        .i_wb_cyc(data_wb_cyc),
        .i_wb_stb(data_wb_stb),
        .i_wb_adr(data_wb_adr),
        .i_wb_we(data_wb_we),
        .o_wb_dat(data_wb_din[0][31:0]),
        .i_wb_dat(data_wb_dout),
        .o_wb_ack(data_wb_ack),
        .i_wb_sel(data_wb_sel),

        .i_wb_cyc2(0),
        .i_wb_stb2(0),
        .i_wb_adr2(0),
        .i_wb_we2 (0),
        .o_wb_dat2(),
        .o_wb_ack2(),
        .i_wb_sel2(0),
        .i_wb_dat2(0)
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

integer seed = `SEED;

`ifdef IRQ_EN

always @ (negedge i_clk)
begin
        i_irq = $random;
end

`endif

initial i_reset = 1'd0;

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

        @(posedge i_clk);
        i_reset <= 1;
        @(posedge i_clk);
        i_reset <= 0;

        repeat(`MAX_CLOCK_CYCLES) @(negedge i_clk);

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("DATA mem[%d] = %x", i, {U_MODEL_RAM_DATA.ram[(i/4)]});
        end

        $finish;
end

endmodule
