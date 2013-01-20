SourceCodeKit adaptation to modern objc/Mac OS X
Unfortunately the original project seems to be abandon and no license was 
provided. Any modifications from the original source are covered under
this licsense.

You can find the original version here:
http://svn.gna.org/svn/etoile/tags/Etoile-0.4.2/Languages/SourceCodeKit/

In order to compile this project a copy of libclang.a will be needed.

Here is how you can build clang:
http://clang.llvm.org/get_started.html

Place the lib and include directories at the root of this project (or modify
according to the location in which clang was built and installed)


Copyright (c) 2013, Philippe Hausler
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list 
of conditions and the following disclaimer. Redistributions in binary form must 
reproduce the above copyright notice, this list of conditions and the following 
disclaimer in the documentation and/or other materials provided with the 
distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
OF THE POSSIBILITY OF SUCH DAMAGE.