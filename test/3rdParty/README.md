# Third-Party Libraries

This directory contains Modelica libraries included as git submodules for
use in the OMFrontend.jl test suite. Each library is subject to its own
license, which differs from the OSMC-PL license that governs OMFrontend.jl
itself.

## Libraries

### Modelica Buildings Library

- **Submodule path**: `Buildings/`
- **Upstream**: https://github.com/lbl-srg/modelica-buildings
- **Version**: v13 (Modelica 4.1.0)
- **Developer**: Lawrence Berkeley National Laboratory (LBL)
- **License**: Modified BSD License (3-clause BSD)

Copyright 1998-2026, Modelica Association, International Building Performance
Simulation Association (IBPSA), The Regents of the University of California
(through Lawrence Berkeley National Laboratory), and contributors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

The full license text is in `Buildings/Buildings/legal.html` inside the
submodule.

## Cloning

These libraries are not checked in as source. After cloning OMFrontend.jl,
initialize the submodules:

```
git submodule update --init --recursive
```
