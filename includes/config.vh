///////////////////////////////////////////////////////////////////////////////

//
// MIT License
// 
// Copyright (C) 2016, 2017 Revanth Kamaraj (Email: revanth91kamaraj@gmail.com)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

///////////////////////////////////////////////////////////////////////////////

//
// Filename --
// config.vh
//
// Summary --
// ZAP processor configuration.
//
// Detail --
// This file consists of a set of defines that may be used to configure the
// processor. In particular, define SIM if you are simulating the design and
// do not define it if you are synthesizing. 
//

///////////////////////////////////////////////////////////////////////////////

`ifndef __CONFIG_VH__
`define __CONFIG_VH__

        //
        // SIM is defined for simulation and 
        // undefined for synthesis.
        //
        `define SIM 

        //
        // To create cache scenarios when simulating the design. 
        // (define/undefine as needed)...
        //
        `undef  FORCE_ICACHE_EN
        `undef  FORCE_DCACHE_EN
        `undef  FORCE_I_CACHEABLE
        `undef  FORCE_D_CACHEABLE
        `define FORCE_I_RAND_CACHEABLE
        `define FORCE_D_RAND_CACHEABLE
        
`endif

///////////////////////////////////////////////////////////////////////////////
