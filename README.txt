Title  : ZAP - An ARM v4T compatible processor.
Author : Revanth Kamaraj (revanth91kamaraj@gmail.com)
License: MIT License.
------------------------------------------------------------------------------

ZAP is an ARM processor compatible with v4T of the ARM instruction set. The
processor is built around a 7 stage pipeline:

    FETCH => DECODE => ISSUE => SHIFTER => ALU => MEMORY => WRITEBACK

ARM ISA Version         : v4 
THUMB ISA Version       : v1 

The pipeline is fully interlocked and fed-back. Most dependent instructions
execute without interlocks. A load accelerator allows instructions that require
a loaded register to issue 1 cycle early. Multiplication takes 4 clock cycles.

Current limitations :
- In Alpha stage of development. Very experimental.
- No long multiply/long MAC.
- No MMU included.

To run sample code...
1. Enter /debug. Make sure you set $ZAP_HOME to the root directory of the project.
2. Write some assembly code in prog.s
3. Run 'perl ../sw/do_it.pl prog.s'
4. Run 'iverilog -f files.list ../testbench/*.v -gstrict-ca-eval -g2005'
5. View zap.vcd
-------------------------------------------------------------------------------

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
