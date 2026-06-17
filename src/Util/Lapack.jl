#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
* VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the OSMC (Open Source Modelica Consortium)
* Public License (OSMC-PL) are obtained from OSMC, either from the above
* address, from the URLs:
* http://www.openmodelica.org or
* https://github.com/OpenModelica/ or
* http://www.ida.liu.se/projects/OpenModelica,
* and in the OpenModelica distribution.
*
* GNU AGPL version 3 is obtained from:
* https://www.gnu.org/licenses/licenses.html#GPL
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#

module Lapack

using MetaModelica
using ExportAll

function dgeev(
  inJOBVL::String,
  inJOBVR::String,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inLDVL::Int,
  inLDVR::Int,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{List{AbstractFloat}},
  List{AbstractFloat},
  List{AbstractFloat},
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{AbstractFloat},
  Integer,
}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outVR::List{List{AbstractFloat}}
  local outVL::List{List{AbstractFloat}}
  local outWI::List{AbstractFloat}
  local outWR::List{AbstractFloat}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outWR, outWI, outVL, outVR, outWORK, outINFO)
end

function dgegv(
  inJOBVL::String,
  inJOBVR::String,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
  inLDVL::Int,
  inLDVR::Int,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{AbstractFloat},
  List{AbstractFloat},
  List{AbstractFloat},
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{AbstractFloat},
  Integer,
}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outVR::List{List{AbstractFloat}}
  local outVL::List{List{AbstractFloat}}
  local outBETA::List{AbstractFloat}
  local outALPHAI::List{AbstractFloat}
  local outALPHAR::List{AbstractFloat}

  @error "TODO: Defined in the runtime"
  return (outALPHAR, outALPHAI, outBETA, outVL, outVR, outWORK, outINFO)
end

function dgels(
  inTRANS::String,
  inM::Int,
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{List{List{AbstractFloat}}, List{List{AbstractFloat}}, List{AbstractFloat}, Integer}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outB::List{List{AbstractFloat}}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outB, outWORK, outINFO)
end

function dgelsx(
  inM::Int,
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
  inJPVT::List{<:Integer},
  inRCOND::AbstractFloat,
  inWORK::List{<:AbstractFloat},
)::Tuple{
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{Integer},
  Integer,
  Integer,
}
  local outINFO::Int
  local outRANK::Int
  local outJPVT::List{Integer}
  local outB::List{List{AbstractFloat}}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outB, outJPVT, outRANK, outINFO)
end

function dgelsy(
  inM::Int,
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
  inJPVT::List{<:Integer},
  inRCOND::AbstractFloat,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{Integer},
  Integer,
  List{AbstractFloat},
  Integer,
}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outRANK::Int
  local outJPVT::List{Integer}
  local outB::List{List{AbstractFloat}}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outB, outJPVT, outRANK, outWORK, outINFO)
end

function dgesv(
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
)::Tuple{List{List{AbstractFloat}}, List{Integer}, List{List{AbstractFloat}}, Integer}
  local outINFO::Int
  local outB::List{List{AbstractFloat}}
  local outIPIV::List{Integer}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outIPIV, outB, outINFO)
end

function dgglse(
  inM::Int,
  inN::Int,
  inP::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
  inC::List{<:AbstractFloat},
  inD::List{<:AbstractFloat},
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{AbstractFloat},
  List{AbstractFloat},
  List{AbstractFloat},
  List{AbstractFloat},
  Integer,
}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outX::List{AbstractFloat}
  local outD::List{AbstractFloat}
  local outC::List{AbstractFloat}
  local outB::List{List{AbstractFloat}}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outB, outC, outD, outX, outWORK, outINFO)
end

function dgtsv(
  inN::Int,
  inNRHS::Int,
  inDL::List{<:AbstractFloat},
  inD::List{<:AbstractFloat},
  inDU::List{<:AbstractFloat},
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
)::Tuple{
  List{AbstractFloat},
  List{AbstractFloat},
  List{AbstractFloat},
  List{List{AbstractFloat}},
  Integer,
}
  local outINFO::Int
  local outB::List{List{AbstractFloat}}
  local outDU::List{AbstractFloat}
  local outD::List{AbstractFloat}
  local outDL::List{AbstractFloat}

  @error "TODO: Defined in the runtime"
  return (outDL, outD, outDU, outB, outINFO)
end

function dgbsv(
  inN::Int,
  inKL::Int,
  inKU::Int,
  inNRHS::Int,
  inAB::List{<:List{<:AbstractFloat}},
  inLDAB::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
)::Tuple{List{List{AbstractFloat}}, List{Integer}, List{List{AbstractFloat}}, Integer}
  local outINFO::Int
  local outB::List{List{AbstractFloat}}
  local outIPIV::List{Integer}
  local outAB::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outAB, outIPIV, outB, outINFO)
end

function dgesvd(
  inJOBU::String,
  inJOBVT::String,
  inM::Int,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inLDU::Int,
  inLDVT::Int,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{List{AbstractFloat}},
  List{AbstractFloat},
  List{List{AbstractFloat}},
  List{List{AbstractFloat}},
  List{AbstractFloat},
  Integer,
}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outVT::List{List{AbstractFloat}}
  local outU::List{List{AbstractFloat}}
  local outS::List{AbstractFloat}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outS, outU, outVT, outWORK, outINFO)
end

function dgetrf(
  inM::Int,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
)::Tuple{List{List{AbstractFloat}}, List{Integer}, Integer}
  local outINFO::Int
  local outIPIV::List{Integer}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outIPIV, outINFO)
end

function dgetrs(
  inTRANS::String,
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inIPIV::List{<:Integer},
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
)::Tuple{List{List{AbstractFloat}}, Integer}
  local outINFO::Int
  local outB::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outB, outINFO)
end

function dgetri(
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inIPIV::List{<:Integer},
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{List{List{AbstractFloat}}, List{AbstractFloat}, Integer}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outWORK, outINFO)
end

function dgeqpf(
  inM::Int,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inJPVT::List{<:Integer},
  inWORK::List{<:AbstractFloat},
)::Tuple{List{List{AbstractFloat}}, List{Integer}, List{AbstractFloat}, Integer}
  local outINFO::Int
  local outTAU::List{AbstractFloat}
  local outJPVT::List{Integer}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outJPVT, outTAU, outINFO)
end

function dorgqr(
  inM::Int,
  inN::Int,
  inK::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inTAU::List{<:AbstractFloat},
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{List{List{AbstractFloat}}, List{AbstractFloat}, Integer}
  local outINFO::Int
  local outWORK::List{AbstractFloat}
  local outA::List{List{AbstractFloat}}

  @error "TODO: Defined in the runtime"
  return (outA, outWORK, outINFO)
end

@exportAll()
end
