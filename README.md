# ZAP : An open source ARM processor (ARMv4 architecture compatible)
*Author* : Revanth Kamaraj (revanth91kamaraj@gmail.com)<br />
*License*: MIT License.<br />

##Description
ZAP is an ARM processor core based on the ARMv4 architecture "ARM" instruction set.
It is equipped with split write-through caches and memory management capabilities.
ZAP does not include the Thumb instruction set from ARMv4T.

##Current Status
Experimental.

##Features
- Compatible with the ARMv4 architecture.
- Supports a custom 16-bit instruction set.
- Pipelined architecture (8 stages) : Fetch1, Fetch2, Decode, Issue, Shift, Execute, Memory, Writeback
- Branch prediction supported.
- Split I and D cache (Size can be configured using parameters).
- Split I and D MMUs (TLB size can be configured using parameters).

##Pipeline Overview
FETCH => PRE-DECODE => DECODE => ISSUE => SHIFTER => ALU => MEMORY => WRITEBACK

The pipeline is fully bypassed to allow most dependent instructions to execute 
without stalls. The pipeline stalls for 3 cycles if there is an attempt to use 
a value loaded from memory immediately following it. 32x32+32=32 operations take 
6 clock cycles while 32x32+64=64 takes 12 clock cycles. Multiplication and 
non trivial shifts require registers a cycle early else the pipeline stalls 
for 1 cycle.

##Documentation
[Link](https://github.com/krevanth/ZAP/blob/master/docs/zap_doc.pdf)

The document is incomplete and I will try my best to update it.

##Feedback
Please provide your feedback on the google forum...
https://groups.google.com/d/forum/zap-devel

-------------------------------------------------------------------------------

##License.

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

-------------------------------------------------------------------------------
