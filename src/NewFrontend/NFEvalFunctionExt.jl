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

#= LAPACK routines called by the frontend's function evaluation (omc: NFEvalFunctionExt.mo):
   the external call's arguments evaluated, Lapack's routine called, its outputs assigned. =#

#= The external call's arguments, as many as the routine takes (omc matches the list's shape). =#
function _extArgs(args::List{<:Expression}, n::Int)::Vector{Expression}
  local v = Base.collect(Expression, args)
  length(v) == n || fail()
  return v
end

function Lapack_dgeev(args::List{<:Expression})
  local jobvl::Expression
  local jobvr::Expression
  local n::Expression
  local a::Expression
  local lda::Expression
  local ldvl::Expression
  local ldvr::Expression
  local work::Expression
  local lwork::Expression
  local wr::Expression
  local wi::Expression
  local vl::Expression
  local vr::Expression
  local info::Expression
  local INFO::Int
  local LDA::Int
  local LDVL::Int
  local LDVR::Int
  local LWORK::Int
  local N::Int
  local JOBVL::String
  local JOBVR::String
  local A::List{List{AbstractFloat}}
  local VL::List{List{AbstractFloat}}
  local VR::List{List{AbstractFloat}}
  local WORK::List{AbstractFloat}
  local WR::List{AbstractFloat}
  local WI::List{AbstractFloat}

  (jobvl, jobvr, n, a, lda, wr, wi, vl, ldvl, vr, ldvr, work, lwork, info) = _extArgs(args, 14)
  @assign JOBVL = evaluateExtStringArg(jobvl)
  @assign JOBVR = evaluateExtStringArg(jobvr)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign LDVL = evaluateExtIntArg(ldvl)
  @assign LDVR = evaluateExtIntArg(ldvr)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, WR, WI, VL, VR, WORK, INFO) =
    Lapack.dgeev(JOBVL, JOBVR, N, A, LDA, LDVL, LDVR, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(wr, makeRealArray(WR))
  assignVariable(wi, makeRealArray(WI))
  assignVariableExt(vl, makeRealMatrix(VL))
  assignVariableExt(vr, makeRealMatrix(VR))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgegv(args::List{<:Expression})
  local jobvl::Expression
  local jobvr::Expression
  local n::Expression
  local a::Expression
  local lda::Expression
  local b::Expression
  local ldb::Expression
  local alphar::Expression
  local alphai::Expression
  local beta::Expression
  local vl::Expression
  local ldvl::Expression
  local vr::Expression
  local ldvr::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local JOBVL::String
  local JOBVR::String
  local N::Int
  local LDA::Int
  local LDB::Int
  local LDVL::Int
  local LDVR::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local VL::List{List{AbstractFloat}}
  local VR::List{List{AbstractFloat}}
  local WORK::List{AbstractFloat}
  local ALPHAR::List{AbstractFloat}
  local ALPHAI::List{AbstractFloat}
  local BETA::List{AbstractFloat}

  (jobvl, jobvr, n, a, lda, b, ldb, alphar, alphai, beta, vl, ldvl, vr, ldvr, work, lwork, info) = _extArgs(args, 17)
  @assign JOBVL = evaluateExtStringArg(jobvl)
  @assign JOBVR = evaluateExtStringArg(jobvr)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
  @assign LDVL = evaluateExtIntArg(ldvl)
  @assign LDVR = evaluateExtIntArg(ldvr)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (ALPHAR, ALPHAI, BETA, VL, VR, WORK, INFO) =
    Lapack.dgegv(JOBVL, JOBVR, N, A, LDA, B, LDB, LDVL, LDVR, WORK, LWORK)
  assignVariable(alphar, makeRealArray(ALPHAR))
  assignVariable(alphai, makeRealArray(ALPHAI))
  assignVariable(beta, makeRealArray(BETA))
  assignVariableExt(vl, makeRealMatrix(VL))
  assignVariableExt(vr, makeRealMatrix(VR))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgels(args::List{<:Expression})
  local trans::Expression
  local m::Expression
  local n::Expression
  local nrhs::Expression
  local a::Expression
  local lda::Expression
  local b::Expression
  local ldb::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local TRANS::String
  local M::Int
  local N::Int
  local NRHS::Int
  local LDA::Int
  local LDB::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local WORK::List{AbstractFloat}

  (trans, m, n, nrhs, a, lda, b, ldb, work, lwork, info) = _extArgs(args, 11)
  @assign TRANS = evaluateExtStringArg(trans)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, B, WORK, INFO) = Lapack.dgels(TRANS, M, N, NRHS, A, LDA, B, LDB, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariableExt(b, makeRealMatrix(B))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgelsx(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local nrhs::Expression
  local a::Expression
  local lda::Expression
  local b::Expression
  local ldb::Expression
  local jpvt::Expression
  local rcond::Expression
  local rank::Expression
  local work::Expression
  local info::Expression
  local M::Int
  local N::Int
  local NRHS::Int
  local LDA::Int
  local LDB::Int
  local RANK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local JPVT::List{Int}
  local RCOND::AbstractFloat
  local WORK::List{AbstractFloat}

  if listLength(args) == 12
    (m, n, nrhs, a, lda, b, ldb, jpvt, rcond, rank, work, info) = _extArgs(args, 12)
  else
    (m, n, nrhs, a, lda, b, ldb, jpvt, rcond, rank, work, _, info) = _extArgs(args, 13)
  end
  #=  Some older versions of the MSL calls dgelsx with an extra lwork argument.
  =#
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
  @assign JPVT = evaluateExtIntArrayArg(jpvt)
  @assign RCOND = evaluateExtRealArg(rcond)
  @assign WORK = evaluateExtRealArrayArg(work)
   (A, B, JPVT, RANK, INFO) =
    Lapack.dgelsx(M, N, NRHS, A, LDA, B, LDB, JPVT, RCOND, WORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariableExt(b, makeRealMatrix(B))
  assignVariable(jpvt, makeIntegerArray(JPVT))
  assignVariable(rank, makeInteger(RANK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgelsy(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local nrhs::Expression
  local a::Expression
  local lda::Expression
  local b::Expression
  local ldb::Expression
  local jpvt::Expression
  local rcond::Expression
  local rank::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local M::Int
  local N::Int
  local NRHS::Int
  local LDA::Int
  local LDB::Int
  local RANK::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local JPVT::List{Int}
  local RCOND::AbstractFloat
  local WORK::List{AbstractFloat}

  (m, n, nrhs, a, lda, b, ldb, jpvt, rcond, rank, work, lwork, info) = _extArgs(args, 13)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
  @assign JPVT = evaluateExtIntArrayArg(jpvt)
  @assign RCOND = evaluateExtRealArg(rcond)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, B, JPVT, RANK, WORK, INFO) =
    Lapack.dgelsy(M, N, NRHS, A, LDA, B, LDB, JPVT, RCOND, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariableExt(b, makeRealMatrix(B))
  assignVariable(jpvt, makeIntegerArray(JPVT))
  assignVariable(rank, makeInteger(RANK))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgesv(args::List{<:Expression})
  local n::Expression
  local nrhs::Expression
  local a::Expression
  local lda::Expression
  local ipiv::Expression
  local b::Expression
  local ldb::Expression
  local info::Expression
  local N::Int
  local NRHS::Int
  local LDA::Int
  local LDB::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local IPIV::List{Int}

  (n, nrhs, a, lda, ipiv, b, ldb, info) = _extArgs(args, 8)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
   (A, IPIV, B, INFO) = Lapack.dgesv(N, NRHS, A, LDA, B, LDB)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(ipiv, makeIntegerArray(IPIV))
  assignVariableExt(b, makeRealMatrix(B))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgglse(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local p::Expression
  local a::Expression
  local lda::Expression
  local b::Expression
  local ldb::Expression
  local c::Expression
  local d::Expression
  local x::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local M::Int
  local N::Int
  local P::Int
  local LDA::Int
  local LDB::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local C::List{AbstractFloat}
  local D::List{AbstractFloat}
  local WORK::List{AbstractFloat}
  local X::List{AbstractFloat}

  (m, n, p, a, lda, b, ldb, c, d, x, work, lwork, info) = _extArgs(args, 13)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign P = evaluateExtIntArg(p)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
  @assign C = evaluateExtRealArrayArg(c)
  @assign D = evaluateExtRealArrayArg(d)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, B, C, D, X, WORK, INFO) =
    Lapack.dgglse(M, N, P, A, LDA, B, LDB, C, D, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariableExt(b, makeRealMatrix(B))
  assignVariable(c, makeRealArray(C))
  assignVariable(d, makeRealArray(D))
  assignVariable(x, makeRealArray(X))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgtsv(args::List{<:Expression})
  local n::Expression
  local nrhs::Expression
  local dl::Expression
  local d::Expression
  local du::Expression
  local b::Expression
  local ldb::Expression
  local info::Expression
  local N::Int
  local NRHS::Int
  local LDB::Int
  local INFO::Int
  local DL::List{AbstractFloat}
  local D::List{AbstractFloat}
  local DU::List{AbstractFloat}
  local B::List{List{AbstractFloat}}

  (n, nrhs, dl, d, du, b, ldb, info) = _extArgs(args, 8)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign DL = evaluateExtRealArrayArg(dl)
  @assign D = evaluateExtRealArrayArg(d)
  @assign DU = evaluateExtRealArrayArg(du)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
   (DL, D, DU, B, INFO) = Lapack.dgtsv(N, NRHS, DL, D, DU, B, LDB)
  assignVariable(dl, makeRealArray(DL))
  assignVariable(d, makeRealArray(D))
  assignVariable(du, makeRealArray(DU))
  assignVariableExt(b, makeRealMatrix(B))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgbsv(args::List{<:Expression})
  local n::Expression
  local kl::Expression
  local ku::Expression
  local nrhs::Expression
  local ab::Expression
  local ldab::Expression
  local ipiv::Expression
  local b::Expression
  local ldb::Expression
  local info::Expression
  local N::Int
  local KL::Int
  local KU::Int
  local NRHS::Int
  local LDAB::Int
  local LDB::Int
  local INFO::Int
  local AB::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local IPIV::List{Int}

  (n, kl, ku, nrhs, ab, ldab, ipiv, b, ldb, info) = _extArgs(args, 10)
  @assign N = evaluateExtIntArg(n)
  @assign KL = evaluateExtIntArg(kl)
  @assign KU = evaluateExtIntArg(ku)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign AB = evaluateExtRealMatrixArg(ab)
  @assign LDAB = evaluateExtIntArg(ldab)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
   (AB, IPIV, B, INFO) = Lapack.dgbsv(N, KL, KU, NRHS, AB, LDAB, B, LDB)
  assignVariableExt(ab, makeRealMatrix(AB))
  assignVariable(ipiv, makeIntegerArray(IPIV))
  assignVariableExt(b, makeRealMatrix(B))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgesvd(args::List{<:Expression})
  local jobu::Expression
  local jobvt::Expression
  local m::Expression
  local n::Expression
  local a::Expression
  local lda::Expression
  local s::Expression
  local u::Expression
  local ldu::Expression
  local vt::Expression
  local ldvt::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local JOBU::String
  local JOBVT::String
  local M::Int
  local N::Int
  local LDA::Int
  local LDU::Int
  local LDVT::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local U::List{List{AbstractFloat}}
  local VT::List{List{AbstractFloat}}
  local S::List{AbstractFloat}
  local WORK::List{AbstractFloat}

  (jobu, jobvt, m, n, a, lda, s, u, ldu, vt, ldvt, work, lwork, info) = _extArgs(args, 14)
  @assign JOBU = evaluateExtStringArg(jobu)
  @assign JOBVT = evaluateExtStringArg(jobvt)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign LDU = evaluateExtIntArg(ldu)
  @assign LDVT = evaluateExtIntArg(ldvt)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, S, U, VT, WORK, INFO) =
    Lapack.dgesvd(JOBU, JOBVT, M, N, A, LDA, LDU, LDVT, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(s, makeRealArray(S))
  assignVariableExt(u, makeRealMatrix(U))
  assignVariableExt(vt, makeRealMatrix(VT))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgetrf(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local a::Expression
  local lda::Expression
  local ipiv::Expression
  local info::Expression
  local M::Int
  local N::Int
  local LDA::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local IPIV::List{Int}

  (m, n, a, lda, ipiv, info) = _extArgs(args, 6)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
   (A, IPIV, INFO) = Lapack.dgetrf(M, N, A, LDA)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(ipiv, makeIntegerArray(IPIV))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgetrs(args::List{<:Expression})
  local trans::Expression
  local n::Expression
  local nrhs::Expression
  local a::Expression
  local lda::Expression
  local ipiv::Expression
  local b::Expression
  local ldb::Expression
  local info::Expression
  local TRANS::String
  local N::Int
  local NRHS::Int
  local LDA::Int
  local LDB::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local B::List{List{AbstractFloat}}
  local IPIV::List{Int}

  (trans, n, nrhs, a, lda, ipiv, b, ldb, info) = _extArgs(args, 9)
  @assign TRANS = evaluateExtStringArg(trans)
  @assign N = evaluateExtIntArg(n)
  @assign NRHS = evaluateExtIntArg(nrhs)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign IPIV = evaluateExtIntArrayArg(ipiv)
  @assign B = evaluateExtRealMatrixArg(b)
  @assign LDB = evaluateExtIntArg(ldb)
   (B, INFO) = Lapack.dgetrs(TRANS, N, NRHS, A, LDA, IPIV, B, LDB)
  assignVariableExt(b, makeRealMatrix(B))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgetri(args::List{<:Expression})
  local n::Expression
  local a::Expression
  local lda::Expression
  local ipiv::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local N::Int
  local LDA::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local IPIV::List{Int}
  local WORK::List{AbstractFloat}

  (n, a, lda, ipiv, work, lwork, info) = _extArgs(args, 7)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign IPIV = evaluateExtIntArrayArg(ipiv)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, WORK, INFO) = Lapack.dgetri(N, A, LDA, IPIV, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dgeqpf(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local a::Expression
  local lda::Expression
  local jpvt::Expression
  local tau::Expression
  local work::Expression
  local info::Expression
  local M::Int
  local N::Int
  local LDA::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local JPVT::List{Int}
  local WORK::List{AbstractFloat}
  local TAU::List{AbstractFloat}

  (m, n, a, lda, jpvt, tau, work, info) = _extArgs(args, 8)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign JPVT = evaluateExtIntArrayArg(jpvt)
  @assign WORK = evaluateExtRealArrayArg(work)
   (A, JPVT, TAU, INFO) = Lapack.dgeqpf(M, N, A, LDA, JPVT, WORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(jpvt, makeIntegerArray(JPVT))
  assignVariable(tau, makeRealArray(TAU))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dorgqr(args::List{<:Expression})
  local m::Expression
  local n::Expression
  local k::Expression
  local a::Expression
  local lda::Expression
  local tau::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local M::Int
  local N::Int
  local K::Int
  local LDA::Int
  local LWORK::Int
  local INFO::Int
  local A::List{List{AbstractFloat}}
  local TAU::List{AbstractFloat}
  local WORK::List{AbstractFloat}

  (m, n, k, a, lda, tau, work, lwork, info) = _extArgs(args, 9)
  @assign M = evaluateExtIntArg(m)
  @assign N = evaluateExtIntArg(n)
  @assign K = evaluateExtIntArg(k)
  @assign A = evaluateExtRealMatrixArg(a)
  @assign LDA = evaluateExtIntArg(lda)
  @assign TAU = evaluateExtRealArrayArg(tau)
  @assign WORK = evaluateExtRealArrayArg(work)
  @assign LWORK = evaluateExtIntArg(lwork)
   (A, WORK, INFO) = Lapack.dorgqr(M, N, K, A, LDA, TAU, WORK, LWORK)
  assignVariableExt(a, makeRealMatrix(A))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function Lapack_dhseqr(args::List{<:Expression})
  local job::Expression
  local compz::Expression
  local n::Expression
  local ilo::Expression
  local ihi::Expression
  local h::Expression
  local ldh::Expression
  local wr::Expression
  local wi::Expression
  local z::Expression
  local ldz::Expression
  local work::Expression
  local lwork::Expression
  local info::Expression
  local H::List{List{AbstractFloat}}
  local Z::List{List{AbstractFloat}}
  local WR::List{AbstractFloat}
  local WI::List{AbstractFloat}
  local WORK::List{AbstractFloat}
  local INFO::Int

  (job, compz, n, ilo, ihi, h, ldh, wr, wi, z, ldz, work, lwork, info) = _extArgs(args, 14)
  (H, WR, WI, Z, WORK, INFO) = Lapack.dhseqr(evaluateExtStringArg(job), evaluateExtStringArg(compz),
    evaluateExtIntArg(n), evaluateExtIntArg(ilo), evaluateExtIntArg(ihi), evaluateExtRealMatrixArg(h),
    evaluateExtIntArg(ldh), evaluateExtRealMatrixArg(z), evaluateExtIntArg(ldz),
    evaluateExtRealArrayArg(work), evaluateExtIntArg(lwork))
  assignVariableExt(h, makeRealMatrix(H))
  assignVariable(wr, makeRealArray(WR))
  assignVariable(wi, makeRealArray(WI))
  assignVariableExt(z, makeRealMatrix(Z))
  assignVariable(work, makeRealArray(WORK))
  return assignVariable(info, makeInteger(INFO))
end

function evaluateExtIntArg(@nospecialize(arg::Expression))::Int
  local value::Int = getExtIntValue(evalExp(arg))
  return value
end

function getExtIntValue(@nospecialize(exp::Expression))::Int
  local value::Int

  @assign value = begin
    @match exp begin
      INTEGER_EXPRESSION(__) => begin
        exp.value
      end

      EMPTY_EXPRESSION(__) => begin
        0
      end
    end
  end
  return value
end

function evaluateExtRealArg(@nospecialize(arg::Expression))::AbstractFloat
  local value::AbstractFloat = getExtRealValue(evalExp(arg))
  return value
end

function getExtRealValue(@nospecialize(exp::Expression))::AbstractFloat
  local value::AbstractFloat

  @assign value = begin
    @match exp begin
      REAL_EXPRESSION(__) => begin
        exp.value
      end

      EMPTY_EXPRESSION(__) => begin
        0.0
      end
    end
  end
  return value
end

function evaluateExtStringArg(@nospecialize(arg::Expression))::String
  local value::String = getExtStringValue(evalExp(arg))
  return value
end

function getExtStringValue(@nospecialize(exp::Expression))::String
  local value::String

  @assign value = begin
    @match exp begin
      STRING_EXPRESSION(__) => begin
        exp.value
      end

      EMPTY_EXPRESSION(__) => begin
        ""
      end
    end
  end
  return value
end

function evaluateExtIntArrayArg(@nospecialize(arg::Expression))::List{Int}
  local value::List{Int} = nil
  for e in Iterators.reverse(arrayElements(evalExp(arg)))
    value = Cons{Int}(getExtIntValue(e), value)
  end
  return value
end

function evaluateExtRealArrayArg(@nospecialize(arg::Expression))::List{AbstractFloat}
  return _extRealList(arrayElements(evalExp(arg)))
end

function _extRealList(expl::Vector{Expression})::List{AbstractFloat}
  local value::List{AbstractFloat} = nil
  for e in Iterators.reverse(expl)
    value = Cons{AbstractFloat}(getExtRealValue(e), value)
  end
  return value
end

#= A matrix argument as a list of rows; a vector is a matrix of one column (some external
   functions do not tell them apart). =#
function evaluateExtRealMatrixArg(@nospecialize(arg::Expression))::List{List{AbstractFloat}}
  local value::List{List{AbstractFloat}} = nil
  local array = evalExp(arg)
  array isa ARRAY_EXPRESSION || fail()
  local vector = dimensionCount(array.ty) == 1
  for e in Iterators.reverse(array.elements)
    local row = vector ? Cons{AbstractFloat}(getExtRealValue(e), nil) : _extRealList(arrayElements(e))
    value = Cons{List{AbstractFloat}}(row, value)
  end
  return value
end

"""
  Some external functions doesn't differentiate between vector and matrices, so
  we might get back a Nx1 matrix when expecting a vector. In that case it needs
  to be converted back into a vector before assigning the variable. Otherwise
  this function just calls assignVariable, so it's only needed for matrix
  arguments.
"""
function assignVariableExt(@nospecialize(variable::Expression), @nospecialize(value::Expression))
  local exp::Expression

  @assign exp = begin
    @match (typeOf(variable), value) begin
      (
        TYPE_ARRAY(dimensions = _ <| nil()),
        ARRAY_EXPRESSION(ty = TYPE_ARRAY(dimensions = _ <| _ <| nil())),
      ) => begin
        makeArray(
          unliftArray(value.ty),
          Expression[arrayScalarElement(e) for e in value.elements],
          literal = true,
        )
      end

      _ => begin
        value
      end
    end
  end
  #=  Vector variable, matrix value => convert value to vector.
  =#
  return assignVariable(variable, exp)
end

