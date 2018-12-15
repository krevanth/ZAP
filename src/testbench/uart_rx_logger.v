// -----------------------------------------------------------------------------
// --                                                                         --
// --                   (C) 2016-2018 Revanth Kamaraj.                        --
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

`default_nettype none

//
// P = 0 UART0 P = 1 UART1
//
// Assumes no parity, 8 bits per character and
// 1 stop bit. 
//
// Gets UART characters from file and serializes them.
//
// If UART0, output file is `UART0_FILE_PATH_RX
// If UART1, output file is `UART1_FILE_PATH_RX
//

module uart_rx_logger #(parameter [0:0] P = 0 ) ( input wire i_clk, output reg o_line = 1'd1 ); 

integer signed    fh;
reg               feof;
integer signed    wchar;

initial
begin
        if ( P == 0 ) 
                fh = $fopen(`UART0_FILE_PATH_RX, "r+");
        else
                fh = $fopen(`UART1_FILE_PATH_RX, "r+");

        if ( fh == 0 ) 
        begin
                $display($time, " - %m :: Error: Failed to open UART input stream. Handle = %d", fh);
                $finish;
        end

        while ( 1 ) 
        begin
               wchar = $fgetc(fh);

               if ( wchar != -1 ) 
                       write_to_uart (wchar);
               else
               begin
                       @(posedge i_clk);
               end
        end
end

task write_to_uart ( input integer signed wchar );
begin
        repeat(16) @(posedge i_clk) o_line <=     1'd0;
        repeat(16) @(posedge i_clk) o_line <= wchar[0];
        repeat(16) @(posedge i_clk) o_line <= wchar[1];
        repeat(16) @(posedge i_clk) o_line <= wchar[2];
        repeat(16) @(posedge i_clk) o_line <= wchar[3];
        repeat(16) @(posedge i_clk) o_line <= wchar[4];
        repeat(16) @(posedge i_clk) o_line <= wchar[5];
        repeat(16) @(posedge i_clk) o_line <= wchar[6];
        repeat(16) @(posedge i_clk) o_line <= wchar[7];

        // Wait 1K clocks between input bytes.
        repeat(1024) @(posedge i_clk) o_line <=     1'd1;
end
endtask

endmodule // uart_rx_logger

`default_nettype wire

