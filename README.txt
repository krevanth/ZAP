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

Features:
- Supports v4 ARM instructions.
- Supports v1 Thumb instructions.

Current limitations :
- In Alpha stage of development. Very experimental and buggy at the moment.
- No long multiply, long MAC, LDC, STC, CDP.
- No branch prediction.
- No MMU.

A simple dual port cache model is provided in testbench/cache.v for simulation
purposes.

Progress:
I am currently working CP15.

Detailed instruction on simulating this may be found at...
https://hackaday.io/project/14771/instructions

To see a demo of the processing executing some simple code, source the
do_it.csh script in the /debug folder. You must have arm-none-eabi-* toolchain
installed on your system along with iverilog.
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
