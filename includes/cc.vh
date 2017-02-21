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
// cc.vh
//
// Summary --
// Conditional codes defined.
//
// Detail --
// This file defines the 16 conditional codes defined by ARM v4.
//

///////////////////////////////////////////////////////////////////////////////

// Conditionals defined as per v4 spec.
parameter EQ =  4'h0;
parameter NE =  4'h1;
parameter CS =  4'h2;
parameter CC =  4'h3;
parameter MI =  4'h4;
parameter PL =  4'h5;
parameter VS =  4'h6;
parameter VC =  4'h7;
parameter HI =  4'h8;
parameter LS =  4'h9;
parameter GE =  4'hA;
parameter LT =  4'hB;
parameter GT =  4'hC;
parameter LE =  4'hD;
parameter AL =  4'hE;
parameter NV =  4'hF; // NeVer execute!

///////////////////////////////////////////////////////////////////////////////
