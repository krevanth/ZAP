Title  : ZAP - An ARM v4T compatible processor.
Author : Revanth Kamaraj (revanth91kamaraj@gmail.com)
License: MIT License.
------------------------------------------------------------------------------

ZAP is an ARM processor compatible with v4T of the ARM instruction set. The
processor is built around a 9 stage pipeline:

    FETCH => PREDICT => PRE-DECODE => DECODE => ISSUE => SHIFTER => ALU => MEMORY => WRITEBACK

ARM ISA Version         : v4 
THUMB ISA Version       : v1 

The pipeline is fully bypassed to allow most dependent instructions to execute without stalls. 
The pipeline stalls for 3 cycles if there is an attempt to use a value loaded from memory immediately following it.
32x32+32=32 operations take 6 clock cycles while 32x32+64=64 takes 12 clock cycles.
Multiplication and non trivial shifts require registers a cycle early else the pipeline stalls for 1 cycle.

Features:
- Supports v4 ARM instructions.
- Supports v1 Thumb instructions.
- Branch prediction supported.

Current limitations :
- In Alpha stage of development. Very experimental and buggy at the moment.
- No MMU or cache is provided but may be attached.

A simple dual port ram model is provided in models/ram/ram.v for simulation
purposes.

See the wiki for instructions.
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
