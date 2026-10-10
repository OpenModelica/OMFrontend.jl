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

#= The LAPACK routines the frontend evaluates (omc: Util/Lapack.mo over runtime/lapackimpl.c),
   called in Julia's LAPACK (libblastrampoline, LinearAlgebra's; loaded with Julia). Matrices
   are lists of rows, read as the leading `rows` x `cols` part into a column-major array and
   given back the same way; vectors are lists, padded with zeros. =#

const _LINEAR_ALGEBRA = Base.PkgId(Base.UUID("37e2e46d-f89d-539d-b4ee-838fcccc9c8e"), "LinearAlgebra")
const _BlasInt = Int64
const _FUNCTIONS = Dict{Symbol, Ptr{Cvoid}}()
const _FUNCTIONS_LOCK = ReentrantLock()

#= The routine's entry in libblastrampoline (ILP64: the `64_` suffix). =#
function _fn(name::Symbol)::Ptr{Cvoid}
  return lock(_FUNCTIONS_LOCK) do
    get!(_FUNCTIONS, name) do
      local la = Base.require(_LINEAR_ALGEBRA)
      la.BlasInt === _BlasInt || error("Lapack: LinearAlgebra's BlasInt is $(la.BlasInt)")
      local handle = Base.Libc.Libdl.dlopen(la.libblastrampoline)
      Base.Libc.Libdl.dlsym(handle, Symbol(name, "64_"))
    end
  end
end

function _matrix(data::List{<:List{<:AbstractFloat}}, rows::Int, cols::Int)::Matrix{Float64}
  local a = zeros(Float64, max(rows, 1), max(cols, 1))
  local i = 0
  for row in data
    i += 1
    i > rows && break
    local j = 0
    for v in row
      j += 1
      j > cols && break
      a[i, j] = v
    end
  end
  return a
end

function _matrixList(a::Matrix{Float64}, rows::Int, cols::Int)::List{List{AbstractFloat}}
  local res::List{List{AbstractFloat}} = nil
  for i in rows:-1:1
    local row::List{AbstractFloat} = nil
    for j in cols:-1:1
      row = Cons{AbstractFloat}(a[i, j], row)
    end
    res = Cons{List{AbstractFloat}}(row, res)
  end
  return res
end

function _vector(data::List{<:AbstractFloat}, n::Int)::Vector{Float64}
  local v = zeros(Float64, max(n, 1))
  local i = 0
  for x in data
    i += 1
    i > n && break
    v[i] = x
  end
  return v
end

function _vectorList(v::Vector{Float64}, n::Int)::List{AbstractFloat}
  local res::List{AbstractFloat} = nil
  for i in n:-1:1
    res = Cons{AbstractFloat}(v[i], res)
  end
  return res
end

function _intVector(data::List{<:Integer}, n::Int)::Vector{_BlasInt}
  local v = zeros(_BlasInt, max(n, 1))
  local i = 0
  for x in data
    i += 1
    i > n && break
    v[i] = x
  end
  return v
end

function _intList(v::Vector{_BlasInt}, n::Int)::List{Int}
  local res::List{Int} = nil
  for i in n:-1:1
    res = Cons{Int}(Int(v[i]), res)
  end
  return res
end

_char(s::String)::Ref{UInt8} = Ref{UInt8}(isempty(s) ? UInt8('N') : UInt8(s[1]))

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
  local a = _matrix(inA, inLDA, inN)
  local wr = zeros(max(inN, 1)); local wi = zeros(max(inN, 1))
  local vl = zeros(max(inLDVL, 1), max(inN, 1)); local vr = zeros(max(inLDVR, 1), max(inN, 1))
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgeev_), Cvoid,
    (Ref{UInt8}, Ref{UInt8}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ptr{Float64},
     Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}, Clong, Clong),
    _char(inJOBVL), _char(inJOBVR), inN, a, max(inLDA, 1), wr, wi, vl, max(inLDVL, 1), vr, max(inLDVR, 1), work, inLWORK, info, 1, 1)
  return (_matrixList(a, inLDA, inN), _vectorList(wr, inN), _vectorList(wi, inN),
          _matrixList(vl, inLDVL, inN), _matrixList(vr, inLDVR, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
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
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inN)
  local alphar = zeros(max(inN, 1)); local alphai = zeros(max(inN, 1)); local beta = zeros(max(inN, 1))
  local vl = zeros(max(inLDVL, 1), max(inN, 1)); local vr = zeros(max(inLDVR, 1), max(inN, 1))
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgegv_), Cvoid,
    (Ref{UInt8}, Ref{UInt8}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}, Clong, Clong),
    _char(inJOBVL), _char(inJOBVR), inN, a, max(inLDA, 1), b, max(inLDB, 1), alphar, alphai, beta,
    vl, max(inLDVL, 1), vr, max(inLDVR, 1), work, inLWORK, info, 1, 1)
  return (_vectorList(alphar, inN), _vectorList(alphai, inN), _vectorList(beta, inN),
          _matrixList(vl, inLDVL, inN), _matrixList(vr, inLDVR, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
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
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inNRHS)
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgels_), Cvoid,
    (Ref{UInt8}, Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64},
     Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}, Clong),
    _char(inTRANS), inM, inN, inNRHS, a, max(inLDA, 1), b, max(inLDB, 1), work, inLWORK, info, 1)
  return (_matrixList(a, inLDA, inN), _matrixList(b, inLDB, inNRHS), _vectorList(work, max(inLWORK, 1)), Int(info[]))
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
  List{Int},
  Integer,
  Integer,
}
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inNRHS)
  local lwork = max(min(inM, inN) + 3 * inN, 2 * min(inM, inN) + inNRHS)
  local work = _vector(inWORK, lwork)
  local jpvt = _intVector(inJPVT, inN)
  local rank = Ref{_BlasInt}(0); local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgelsx_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{_BlasInt}, Ref{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}),
    inM, inN, inNRHS, a, max(inLDA, 1), b, max(inLDB, 1), jpvt, Float64(inRCOND), rank, work, info)
  return (_matrixList(a, inLDA, inN), _matrixList(b, inLDB, inNRHS), _intList(jpvt, inN), Int(rank[]), Int(info[]))
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
  List{Int},
  Integer,
  List{AbstractFloat},
  Integer,
}
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inNRHS)
  local work = _vector(inWORK, inLWORK)
  local jpvt = _intVector(inJPVT, inN)
  local rank = Ref{_BlasInt}(0); local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgelsy_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{_BlasInt}, Ref{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inM, inN, inNRHS, a, max(inLDA, 1), b, max(inLDB, 1), jpvt, Float64(inRCOND), rank, work, inLWORK, info)
  return (_matrixList(a, inLDA, inN), _matrixList(b, inLDB, inNRHS), _intList(jpvt, inN), Int(rank[]),
          _vectorList(work, max(inLWORK, 1)), Int(info[]))
end

function dgesv(
  inN::Int,
  inNRHS::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inB::List{<:List{<:AbstractFloat}},
  inLDB::Int,
)::Tuple{List{List{AbstractFloat}}, List{Int}, List{List{AbstractFloat}}, Integer}
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inNRHS)
  local ipiv = zeros(_BlasInt, max(inN, 1))
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgesv_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inN, inNRHS, a, max(inLDA, 1), ipiv, b, max(inLDB, 1), info)
  return (_matrixList(a, inLDA, inN), _intList(ipiv, inN), _matrixList(b, inLDB, inNRHS), Int(info[]))
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
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inN)
  local c = _vector(inC, inM); local d = _vector(inD, inP); local x = zeros(max(inN, 1))
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgglse_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inM, inN, inP, a, max(inLDA, 1), b, max(inLDB, 1), c, d, x, work, inLWORK, info)
  return (_matrixList(a, inLDA, inN), _matrixList(b, inLDB, inN), _vectorList(c, inM), _vectorList(d, inP),
          _vectorList(x, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
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
  local dl = _vector(inDL, inN - 1); local d = _vector(inD, inN); local du = _vector(inDU, inN - 1)
  local b = _matrix(inB, inLDB, inNRHS)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgtsv_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inN, inNRHS, dl, d, du, b, max(inLDB, 1), info)
  return (_vectorList(dl, inN - 1), _vectorList(d, inN), _vectorList(du, inN - 1), _matrixList(b, inLDB, inNRHS), Int(info[]))
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
)::Tuple{List{List{AbstractFloat}}, List{Int}, List{List{AbstractFloat}}, Integer}
  local ab = _matrix(inAB, inLDAB, inN); local b = _matrix(inB, inLDB, inNRHS)
  local ipiv = zeros(_BlasInt, max(inN, 1))
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgbsv_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt},
     Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inN, inKL, inKU, inNRHS, ab, max(inLDAB, 1), ipiv, b, max(inLDB, 1), info)
  return (_matrixList(ab, inLDAB, inN), _intList(ipiv, inN), _matrixList(b, inLDB, inNRHS), Int(info[]))
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
  local lds = min(inM, inN)
  #= U's columns by JOBU; with "N" or "O" it is not referenced, given back as the m columns of
     the caller's U (MSL's dgesvd_sigma: U[m, m]) =#
  local ucol = startswith(inJOBU, "A") ? inM : startswith(inJOBU, "S") ? lds : inM
  local a = _matrix(inA, inLDA, inN); local s = zeros(max(lds, 1))
  local u = zeros(max(inLDU, 1), max(ucol, 1)); local vt = zeros(max(inLDVT, 1), max(inN, 1))
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgesvd_), Cvoid,
    (Ref{UInt8}, Ref{UInt8}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64},
     Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}, Clong, Clong),
    _char(inJOBU), _char(inJOBVT), inM, inN, a, max(inLDA, 1), s, u, max(inLDU, 1), vt, max(inLDVT, 1),
    work, inLWORK, info, 1, 1)
  return (_matrixList(a, inLDA, inN), _vectorList(s, lds), _matrixList(u, inLDU, ucol),
          _matrixList(vt, inLDVT, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
end

function dgetrf(
  inM::Int,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
)::Tuple{List{List{AbstractFloat}}, List{Int}, Integer}
  local a = _matrix(inA, inLDA, inN)
  local npiv = min(inM, inN)
  local ipiv = zeros(_BlasInt, max(npiv, 1))
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgetrf_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt}, Ref{_BlasInt}),
    inM, inN, a, max(inLDA, 1), ipiv, info)
  return (_matrixList(a, inLDA, inN), _intList(ipiv, npiv), Int(info[]))
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
  local a = _matrix(inA, inLDA, inN); local b = _matrix(inB, inLDB, inNRHS)
  local ipiv = _intVector(inIPIV, inN)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgetrs_), Cvoid,
    (Ref{UInt8}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt}, Ptr{Float64},
     Ref{_BlasInt}, Ref{_BlasInt}, Clong),
    _char(inTRANS), inN, inNRHS, a, max(inLDA, 1), ipiv, b, max(inLDB, 1), info, 1)
  return (_matrixList(b, inLDB, inNRHS), Int(info[]))
end

function dgetri(
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inIPIV::List{<:Integer},
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{List{List{AbstractFloat}}, List{AbstractFloat}, Integer}
  local a = _matrix(inA, inLDA, inN)
  local ipiv = _intVector(inIPIV, inN)
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgetri_), Cvoid,
    (Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}),
    inN, a, max(inLDA, 1), ipiv, work, inLWORK, info)
  return (_matrixList(a, inLDA, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
end

function dgeqpf(
  inM::Int,
  inN::Int,
  inA::List{<:List{<:AbstractFloat}},
  inLDA::Int,
  inJPVT::List{<:Integer},
  inWORK::List{<:AbstractFloat},
)::Tuple{List{List{AbstractFloat}}, List{Int}, List{AbstractFloat}, Integer}
  local a = _matrix(inA, inLDA, inN)
  local jpvt = _intVector(inJPVT, inN)
  local ntau = min(inM, inN)
  local tau = zeros(max(ntau, 1))
  local work = _vector(inWORK, 3 * inN)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dgeqpf_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{_BlasInt}, Ptr{Float64}, Ptr{Float64}, Ref{_BlasInt}),
    inM, inN, a, max(inLDA, 1), jpvt, tau, work, info)
  return (_matrixList(a, inLDA, inN), _intList(jpvt, inN), _vectorList(tau, ntau), Int(info[]))
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
  local a = _matrix(inA, inLDA, inN)
  local tau = _vector(inTAU, inK)
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dorgqr_), Cvoid,
    (Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ptr{Float64},
     Ref{_BlasInt}, Ref{_BlasInt}),
    inM, inN, inK, a, max(inLDA, 1), tau, work, inLWORK, info)
  return (_matrixList(a, inLDA, inN), _vectorList(work, max(inLWORK, 1)), Int(info[]))
end

function dhseqr(
  inJOB::String,
  inCOMPZ::String,
  inN::Int,
  inILO::Int,
  inIHI::Int,
  inH::List{<:List{<:AbstractFloat}},
  inLDH::Int,
  inZ::List{<:List{<:AbstractFloat}},
  inLDZ::Int,
  inWORK::List{<:AbstractFloat},
  inLWORK::Int,
)::Tuple{
  List{List{AbstractFloat}},
  List{AbstractFloat},
  List{AbstractFloat},
  List{List{AbstractFloat}},
  List{AbstractFloat},
  Integer,
}
  local h = _matrix(inH, inLDH, inN); local z = _matrix(inZ, inLDZ, inN)
  local wr = zeros(max(inN, 1)); local wi = zeros(max(inN, 1))
  local work = _vector(inWORK, inLWORK)
  local info = Ref{_BlasInt}(0)
  ccall(_fn(:dhseqr_), Cvoid,
    (Ref{UInt8}, Ref{UInt8}, Ref{_BlasInt}, Ref{_BlasInt}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt},
     Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ref{_BlasInt}, Ptr{Float64}, Ref{_BlasInt}, Ref{_BlasInt}, Clong, Clong),
    _char(inJOB), _char(inCOMPZ), inN, inILO, inIHI, h, max(inLDH, 1), wr, wi, z, max(inLDZ, 1),
    work, inLWORK, info, 1, 1)
  return (_matrixList(h, inLDH, inN), _vectorList(wr, inN), _vectorList(wi, inN), _matrixList(z, inLDZ, inN),
          _vectorList(work, max(inLWORK, 1)), Int(info[]))
end

@exportAll()
end
