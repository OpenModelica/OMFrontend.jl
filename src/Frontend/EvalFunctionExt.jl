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

#= LAPACK routines the frontend evaluates when a binding it must evaluate calls an 'external "FORTRAN 77"' function
   (omc: NFEvalFunctionExt.mo). Each Lapack_<routine> reads the call's arguments in Fortran's order, runs Julia's LAPACK
   (LinearAlgebra.LAPACK) on the leading blocks the sizes give, and assigns the outputs back. A matrix is read as its
   leading-dimension block (`lda` x columns) and LAPACK works on the first rows of it, as in Fortran. Routines LAPACK
   has deprecated run as their successors: dgegv as dggev, dgelsx as dgelsy, dgeqpf as dgeqp3, dgbsv as dgbtrf with
   dgbtrs. The workspace arguments (work, lwork) are not used. =#

const LAPACK = LinearAlgebra.LAPACK

"""The external call's arguments, `n` of them (fails for another count)."""
function _extArgs(args::List{<:Expression}, n::Int)::Vector{Expression}
  local v::Vector{Expression} = Base.collect(Expression, args)
  length(v) == n || fail()
  return v
end

"""The value of an evaluated scalar; an empty argument is 0."""
function _number(@nospecialize(e::Expression))::Float64
  e isa REAL_EXPRESSION && return e.value
  e isa INTEGER_EXPRESSION && return Float64(e.value)
  e isa EMPTY_EXPRESSION && return 0.0
  return fail()
end

"""The elements of an evaluated array argument."""
function _elements(@nospecialize(arg::Expression))::Vector{Expression}
  local e::Expression = evalExp(arg)
  e isa ARRAY_EXPRESSION || fail()
  return e.elements
end

extInt(@nospecialize(arg::Expression))::Int = Int(_number(evalExp(arg)))
extReal(@nospecialize(arg::Expression))::Float64 = _number(evalExp(arg))

"""The first character of a string argument (a job or trans flag); 'N' for an empty one."""
function extChar(@nospecialize(arg::Expression))::Char
  local e::Expression = evalExp(arg)
  return e isa STRING_EXPRESSION && !isempty(e.value) ? e.value[1] : 'N'
end

"""A vector argument with `n` elements (cut, or padded with zeros)."""
function extVector(@nospecialize(arg::Expression), n::Int)::Vector{Float64}
  local v::Vector{Float64} = zeros(max(n, 0))
  for (i::Int, e::Expression) in enumerate(_elements(arg))
    i > n && break
    v[i] = _number(e)
  end
  return v
end

extIntVector(@nospecialize(arg::Expression), n::Int)::Vector{Int} = Int.(extVector(arg, n))

"""A matrix argument as `rows` x `cols` (cut, or padded with zeros); a vector is one column."""
function extMatrix(@nospecialize(arg::Expression), rows::Int, cols::Int)::Matrix{Float64}
  local m::Matrix{Float64} = zeros(max(rows, 0), max(cols, 0))
  for (i::Int, row::Expression) in enumerate(_elements(arg))
    i > rows && break
    if row isa ARRAY_EXPRESSION
      for (j::Int, e::Expression) in enumerate(row.elements)
        j > cols && break
        m[i, j] = _number(e)
      end
    elseif cols >= 1
      m[i, 1] = _number(row)
    end
  end
  return m
end

"""The sizes of an evaluated array (empty for a scalar)."""
function _shape(@nospecialize(e::Expression))::Vector{Int}
  e isa ARRAY_EXPRESSION || return Int[]
  return isempty(e.elements) ? [0] : [length(e.elements); _shape(e.elements[1])]
end

"""Element `(i, j)` of `m` as a literal (zero outside `m`)."""
function _scalarExp(m::AbstractMatrix{T}, i::Int, j::Int)::Expression where {T <: Union{Float64, Int}}
  local x::T = i <= Base.size(m, 1) && j <= Base.size(m, 2) ? m[i, j] : zero(T)
  return T === Int ? INTEGER_EXPRESSION(x) : REAL_EXPRESSION(x)
end

"""`m` as a literal array of size `dims` (one or two sizes; cut, or padded with zeros)."""
function _arrayExp(m::AbstractMatrix{T}, dims::Vector{Int})::Expression where {T <: Union{Float64, Int}}
  local elementTy::ModelicaType = T === Int ? TYPE_INTEGER() : TYPE_REAL()
  local vectorTy::ModelicaType = TYPE_ARRAY(elementTy, list(fromInteger(last(dims))))
  if length(dims) == 1
    return makeArray(vectorTy, Expression[_scalarExp(m, i, 1) for i in 1:dims[1]]; literal = true)
  end
  local rows::Vector{Expression} = Expression[
    makeArray(vectorTy, Expression[_scalarExp(m, i, j) for j in 1:dims[2]]; literal = true) for i in 1:dims[1]]
  return makeArray(TYPE_ARRAY(elementTy, list(fromInteger(dims[1]), fromInteger(dims[2]))), rows; literal = true)
end

"""
Assign `value` to the external call's variable `var`. An array is given the variable's size: a matrix assigned to a
vector variable gives its first column (some routines do not tell vectors from n x 1 matrices).
"""
function assignExt!(@nospecialize(var::Expression), value::Integer)::Nothing
  assignVariable(var, INTEGER_EXPRESSION(Int(value)))
  return nothing
end

function assignExt!(@nospecialize(var::Expression),
                    value::AbstractVecOrMat{T})::Nothing where {T <: Union{Float64, Int}}
  local m::AbstractMatrix{T} = value isa AbstractVector ? reshape(value, :, 1) : value
  local dims::Vector{Int} = _shape(evalExp(var))
  isempty(dims) && (dims = value isa AbstractVector ? [length(value)] : collect(Base.size(m)))
  assignVariable(var, _arrayExp(m, dims))
  return nothing
end

"""LAPACK's info for an exception of a LAPACK call (the index it reports); other exceptions are rethrown."""
function _infoOf(e::Exception)::Int
  e isa LinearAlgebra.LAPACKException && return Int(e.info)
  e isa LinearAlgebra.SingularException && return Int(e.info)
  rethrow()
end

function Lapack_dgeev(args::List{<:Expression})::Nothing
  local (jobvl::Expression, jobvr::Expression, n::Expression, a::Expression, lda::Expression, wr::Expression,
         wi::Expression, vl::Expression, _, vr::Expression, _, _, _, info::Expression) = _extArgs(args, 14)
  local N::Int = extInt(n)
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local INFO::Int = 0
  local (WR::Vector{Float64}, WI::Vector{Float64}, VL::Matrix{Float64}, VR::Matrix{Float64}) = try
    LAPACK.geev!(extChar(jobvl), extChar(jobvr), view(A, 1:N, :))
  catch e
    INFO = _infoOf(e)
    (zeros(N), zeros(N), zeros(N, N), zeros(N, N))
  end
  assignExt!(a, A); assignExt!(wr, WR); assignExt!(wi, WI); assignExt!(vl, VL); assignExt!(vr, VR)
  return assignExt!(info, INFO)
end

function Lapack_dgegv(args::List{<:Expression})::Nothing
  local (jobvl::Expression, jobvr::Expression, n::Expression, a::Expression, lda::Expression, b::Expression,
         ldb::Expression, alphar::Expression, alphai::Expression, beta::Expression, vl::Expression, _, vr::Expression,
         _, _, _, info::Expression) = _extArgs(args, 17)
  local N::Int = extInt(n)
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), N)
  local INFO::Int = 0
  local (AR::Vector{Float64}, AI::Vector{Float64}, BETA::Vector{Float64}, VL::Matrix{Float64},
         VR::Matrix{Float64}) = try
    LAPACK.ggev!(extChar(jobvl), extChar(jobvr), view(A, 1:N, :), view(B, 1:N, :))
  catch e
    INFO = _infoOf(e)
    (zeros(N), zeros(N), zeros(N), zeros(N, N), zeros(N, N))
  end
  assignExt!(alphar, AR); assignExt!(alphai, AI); assignExt!(beta, BETA); assignExt!(vl, VL); assignExt!(vr, VR)
  return assignExt!(info, INFO)
end

function Lapack_dgels(args::List{<:Expression})::Nothing
  local (trans::Expression, m::Expression, n::Expression, nrhs::Expression, a::Expression, lda::Expression,
         b::Expression, ldb::Expression, _, _, info::Expression) = _extArgs(args, 11)
  local (TRANS::Char, M::Int, N::Int) = (extChar(trans), extInt(m), extInt(n))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  #= B holds the right-hand sides in its first M (N if transposed) rows and the solution in its first N (M). =#
  local INFO::Int = try
    LAPACK.gels!(TRANS, view(A, 1:M, :), view(B, 1:(TRANS == 'N' ? M : N), :))
    0
  catch e
    _infoOf(e)
  end
  assignExt!(a, A); assignExt!(b, B)
  return assignExt!(info, INFO)
end

"""dgelsy and dgelsx (`lwork` given or not): the minimum-norm least squares solution and the rank."""
function _gelsy(m::Expression, n::Expression, nrhs::Expression, a::Expression, lda::Expression, b::Expression,
                ldb::Expression, rcond::Expression, rank::Expression, info::Expression)::Nothing
  local (M::Int, N::Int) = (extInt(m), extInt(n))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  local INFO::Int = 0
  local (X::Matrix{Float64}, RANK::Int) = try
    LAPACK.gelsy!(view(A, 1:M, :), B[1:M, :], extReal(rcond))
  catch e
    INFO = _infoOf(e)
    (zeros(N, Base.size(B, 2)), 0)
  end
  B[1:N, :] = X
  assignExt!(a, A); assignExt!(b, B); assignExt!(rank, RANK)
  return assignExt!(info, INFO)
end

function Lapack_dgelsx(args::List{<:Expression})::Nothing
  #= Older MSL versions pass an lwork argument too. =#
  local v::Vector{Expression} = _extArgs(args, listLength(args) == 12 ? 12 : 13)
  return _gelsy(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[9], v[10], v[end])
end

function Lapack_dgelsy(args::List{<:Expression})::Nothing
  local (m::Expression, n::Expression, nrhs::Expression, a::Expression, lda::Expression, b::Expression, ldb::Expression,
         _, rcond::Expression, rank::Expression, _, _, info::Expression) = _extArgs(args, 13)
  return _gelsy(m, n, nrhs, a, lda, b, ldb, rcond, rank, info)
end

function Lapack_dgesv(args::List{<:Expression})::Nothing
  local (n::Expression, nrhs::Expression, a::Expression, lda::Expression, ipiv::Expression, b::Expression,
         ldb::Expression, info::Expression) = _extArgs(args, 8)
  local N::Int = extInt(n)
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  local IPIV::Vector{Int} = zeros(Int, N)
  local INFO::Int = LAPACK.getrf!(view(A, 1:N, :), IPIV; check = false)[3]
  INFO == 0 && LAPACK.getrs!('N', view(A, 1:N, :), IPIV, view(B, 1:N, :))
  assignExt!(a, A); assignExt!(ipiv, IPIV); assignExt!(b, B)
  return assignExt!(info, INFO)
end

function Lapack_dgglse(args::List{<:Expression})::Nothing
  local (m::Expression, n::Expression, p::Expression, a::Expression, lda::Expression, b::Expression, ldb::Expression,
         c::Expression, d::Expression, x::Expression, _, _, info::Expression) = _extArgs(args, 13)
  local (M::Int, N::Int, P::Int) = (extInt(m), extInt(n), extInt(p))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), N)
  local (C::Vector{Float64}, D::Vector{Float64}) = (extVector(c, M), extVector(d, P))
  local INFO::Int = 0
  local X::Vector{Float64} = try
    LAPACK.gglse!(view(A, 1:M, :), C, view(B, 1:P, :), D)[1]
  catch e
    INFO = _infoOf(e)
    zeros(N)
  end
  assignExt!(a, A); assignExt!(b, B); assignExt!(c, C); assignExt!(d, D); assignExt!(x, X)
  return assignExt!(info, INFO)
end

function Lapack_dgtsv(args::List{<:Expression})::Nothing
  local (n::Expression, nrhs::Expression, dl::Expression, d::Expression, du::Expression, b::Expression, ldb::Expression,
         info::Expression) = _extArgs(args, 8)
  local N::Int = extInt(n)
  local (DL::Vector{Float64}, D::Vector{Float64}, DU::Vector{Float64}) =
    (extVector(dl, N - 1), extVector(d, N), extVector(du, N - 1))
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  local INFO::Int = try
    LAPACK.gtsv!(DL, D, DU, view(B, 1:N, :))
    0
  catch e
    _infoOf(e)
  end
  assignExt!(dl, DL); assignExt!(d, D); assignExt!(du, DU); assignExt!(b, B)
  return assignExt!(info, INFO)
end

function Lapack_dgbsv(args::List{<:Expression})::Nothing
  local (n::Expression, kl::Expression, ku::Expression, nrhs::Expression, ab::Expression, ldab::Expression,
         ipiv::Expression, b::Expression, ldb::Expression, info::Expression) = _extArgs(args, 10)
  local (N::Int, KL::Int, KU::Int) = (extInt(n), extInt(kl), extInt(ku))
  local AB::Matrix{Float64} = extMatrix(ab, extInt(ldab), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  local IPIV::Vector{Int} = zeros(Int, N)
  local INFO::Int = try
    copyto!(IPIV, LAPACK.gbtrf!(KL, KU, N, AB)[2])
    LAPACK.gbtrs!('N', KL, KU, N, AB, IPIV, view(B, 1:N, :))
    0
  catch e
    _infoOf(e)
  end
  assignExt!(ab, AB); assignExt!(ipiv, IPIV); assignExt!(b, B)
  return assignExt!(info, INFO)
end

function Lapack_dgesvd(args::List{<:Expression})::Nothing
  local (jobu::Expression, jobvt::Expression, m::Expression, n::Expression, a::Expression, lda::Expression,
         s::Expression, u::Expression, _, vt::Expression, _, _, _, info::Expression) = _extArgs(args, 14)
  local (M::Int, N::Int) = (extInt(m), extInt(n))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local INFO::Int = 0
  local (U::Matrix{Float64}, S::Vector{Float64}, VT::Matrix{Float64}) = try
    LAPACK.gesvd!(extChar(jobu), extChar(jobvt), view(A, 1:M, :))
  catch e
    INFO = _infoOf(e)
    (zeros(M, M), zeros(min(M, N)), zeros(N, N))
  end
  assignExt!(a, A); assignExt!(s, S); assignExt!(u, U); assignExt!(vt, VT)
  return assignExt!(info, INFO)
end

function Lapack_dgetrf(args::List{<:Expression})::Nothing
  local (m::Expression, n::Expression, a::Expression, lda::Expression, ipiv::Expression,
         info::Expression) = _extArgs(args, 6)
  local (M::Int, N::Int) = (extInt(m), extInt(n))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local IPIV::Vector{Int} = zeros(Int, min(M, N))
  local INFO::Int = LAPACK.getrf!(view(A, 1:M, :), IPIV; check = false)[3]
  assignExt!(a, A); assignExt!(ipiv, IPIV)
  return assignExt!(info, INFO)
end

function Lapack_dgetrs(args::List{<:Expression})::Nothing
  local (trans::Expression, n::Expression, nrhs::Expression, a::Expression, lda::Expression, ipiv::Expression,
         b::Expression, ldb::Expression, info::Expression) = _extArgs(args, 9)
  local N::Int = extInt(n)
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local B::Matrix{Float64} = extMatrix(b, extInt(ldb), extInt(nrhs))
  LAPACK.getrs!(extChar(trans), view(A, 1:N, :), extIntVector(ipiv, N), view(B, 1:N, :))
  assignExt!(b, B)
  return assignExt!(info, 0)
end

function Lapack_dgetri(args::List{<:Expression})::Nothing
  local (n::Expression, a::Expression, lda::Expression, ipiv::Expression, _, _, info::Expression) = _extArgs(args, 7)
  local N::Int = extInt(n)
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local INFO::Int = try
    LAPACK.getri!(view(A, 1:N, :), extIntVector(ipiv, N))
    0
  catch e
    _infoOf(e)
  end
  assignExt!(a, A)
  return assignExt!(info, INFO)
end

function Lapack_dgeqpf(args::List{<:Expression})::Nothing
  local (m::Expression, n::Expression, a::Expression, lda::Expression, jpvt::Expression, tau::Expression, _,
         info::Expression) = _extArgs(args, 8)
  local (M::Int, N::Int) = (extInt(m), extInt(n))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), N)
  local JPVT::Vector{Int} = extIntVector(jpvt, N)
  local TAU::Vector{Float64} = zeros(min(M, N))
  LAPACK.geqp3!(view(A, 1:M, :), JPVT, TAU)
  assignExt!(a, A); assignExt!(jpvt, JPVT); assignExt!(tau, TAU)
  return assignExt!(info, 0)
end

function Lapack_dorgqr(args::List{<:Expression})::Nothing
  local (m::Expression, n::Expression, k::Expression, a::Expression, lda::Expression, tau::Expression, _, _,
         info::Expression) = _extArgs(args, 9)
  local (M::Int, K::Int) = (extInt(m), extInt(k))
  local A::Matrix{Float64} = extMatrix(a, extInt(lda), extInt(n))
  LAPACK.orgqr!(view(A, 1:M, :), extVector(tau, K), K)
  assignExt!(a, A)
  return assignExt!(info, 0)
end

function Lapack_dhseqr(args::List{<:Expression})::Nothing
  local (job::Expression, compz::Expression, n::Expression, ilo::Expression, ihi::Expression, h::Expression,
         ldh::Expression, wr::Expression, wi::Expression, z::Expression, ldz::Expression, _, _,
         info::Expression) = _extArgs(args, 14)
  local N::Int = extInt(n)
  local H::Matrix{Float64} = extMatrix(h, extInt(ldh), N)
  local Z::Matrix{Float64} = extMatrix(z, extInt(ldz), N)
  local INFO::Int = 0
  local W::Vector{ComplexF64} = try
    LAPACK.hseqr!(extChar(job), extChar(compz), extInt(ilo), extInt(ihi), view(H, 1:N, :), view(Z, 1:N, :))[3]
  catch e
    INFO = _infoOf(e)
    zeros(ComplexF64, N)
  end
  assignExt!(h, H); assignExt!(wr, real.(W)); assignExt!(wi, imag.(W)); assignExt!(z, Z)
  return assignExt!(info, INFO)
end
