#= The frontend's evaluation of LAPACK external functions (EvalFunctionExt.jl): each routine declared as MSL declares
   it ('external "FORTRAN 77"'), called in a constant binding, so the frontend evaluates it; the flat model's values are
   compared with LinearAlgebra's. =#

import LinearAlgebra

"""The flat model's constants `name => value` of model `M`, built from `functions` and the `constants` lines."""
function _lapackConstants(functions::String, constants::String)::Dict{String, Float64}
  local model::String = "model M\n" * functions * "\n" * constants * "\nend M;"
  local text::String = string(OMFrontend.instantiate("M"; string = model))
  local values::Dict{String, Float64} = Dict{String, Float64}()
  for m::RegexMatch in eachmatch(r"constant (?:Real|Integer) '?([^' ]+)'? = ([^;]+);", text)
    values[m.captures[1]] = parse(Float64, m.captures[2])
  end
  return values
end

"""The values of the constant array `name` in `values`: `name[1]`, `name[2]`, ... (or `name[i,j]` row by row)."""
function _lapackVector(values::Dict{String, Float64}, name::String, n::Int)::Vector{Float64}
  return Float64[values["$name[$i]"] for i in 1:n]
end

function _lapackMatrix(values::Dict{String, Float64}, name::String, m::Int, n::Int)::Matrix{Float64}
  return Float64[values["$name[$i,$j]"] for i in 1:m, j in 1:n]
end

const _LAPACK_A::Matrix{Float64} = [4.0 1.0 2.0; 1.0 3.0 0.0; 2.0 0.0 5.0]
const _LAPACK_A_MO::String = "{{4, 1, 2}, {1, 3, 0}, {2, 0, 5}}"
const _LAPACK_B::Vector{Float64} = [1.0, 2.0, 3.0]
const _LAPACK_B_MO::String = "{1, 2, 3}"
#= Overdetermined: 4 x 2. =#
const _LAPACK_C::Matrix{Float64} = [1.0 1.0; 1.0 2.0; 1.0 3.0; 1.0 4.0]
const _LAPACK_C_MO::String = "{{1, 1}, {1, 2}, {1, 3}, {1, 4}}"
const _LAPACK_D::Vector{Float64} = [6.0, 5.0, 7.0, 10.0]
const _LAPACK_D_MO::String = "{6, 5, 7, 10}"

@testset "LAPACK evaluation (EvalFunctionExt)" begin
  @testset "dgesv" begin
    local v::Dict{String, Float64} = _lapackConstants("""
      function solve
        input Real A[3, 3]; input Real b[3]; output Real x[3] = b; output Integer info;
      protected
        Real Awork[3, 3] = A; Integer ipiv[3];
      external "FORTRAN 77" dgesv(3, 1, Awork, 3, ipiv, x, 3, info);
      end solve;
      function solveInfo
        input Real A[2, 2]; input Real b[2]; output Integer info; output Real x[2] = b;
      protected
        Real Awork[2, 2] = A; Integer ipiv[2];
      external "FORTRAN 77" dgesv(2, 1, Awork, 2, ipiv, x, 2, info);
      end solveInfo;""",
      "constant Real x[3] = solve($_LAPACK_A_MO, $_LAPACK_B_MO);
       constant Integer info = solveInfo({{1, 2}, {2, 4}}, {1, 1});")
    @test _lapackVector(v, "x", 3) ≈ _LAPACK_A \ _LAPACK_B
    @test v["info"] == 2.0 #= singular: U[2, 2] = 0 =#
  end

  @testset "dgetrf, dgetrs, dgetri" begin
    local v::Dict{String, Float64} = _lapackConstants("""
      function lu
        input Real A[3, 3]; output Real LU[3, 3] = A; output Integer pivots[3]; output Integer info;
      external "FORTRAN 77" dgetrf(3, 3, LU, 3, pivots, info);
      end lu;
      function luSolve
        input Real A[3, 3]; input Real b[3]; output Real x[3] = b;
      protected
        Real LU[3, 3]; Integer pivots[3]; Integer info;
      algorithm
        (LU, pivots, info) := lu(A);
        x := solveLU(LU, pivots, b);
      end luSolve;
      function solveLU
        input Real LU[3, 3]; input Integer pivots[3]; input Real b[3]; output Real x[3] = b;
      protected
        Integer info;
      external "FORTRAN 77" dgetrs("N", 3, 1, LU, 3, pivots, x, 3, info);
      end solveLU;
      function inv
        input Real A[3, 3]; output Real Ainv[3, 3];
      protected
        Integer pivots[3]; Integer info;
      algorithm
        (Ainv, pivots, info) := lu(A);
        Ainv := invLU(Ainv, pivots);
      end inv;
      function invLU
        input Real LU[3, 3]; input Integer pivots[3]; output Real inv[3, 3] = LU;
      protected
        Integer lwork = 3 * 64; Real work[3 * 64]; Integer info;
      external "FORTRAN 77" dgetri(3, inv, 3, pivots, work, lwork, info);
      end invLU;
      function invInfo
        input Real LU[2, 2]; output Integer info;
      protected
        Real inv[2, 2] = LU; Integer pivots[2] = {1, 2}; Real work[64];
      external "FORTRAN 77" dgetri(2, inv, 2, pivots, work, 64, info);
      end invInfo;""",
      "constant Real x[3] = luSolve($_LAPACK_A_MO, $_LAPACK_B_MO);
       constant Real Ainv[3, 3] = inv($_LAPACK_A_MO);
       constant Real LU[3, 3] = lu($_LAPACK_A_MO);
       constant Integer info = invInfo({{1, 2}, {0, 0}});")
    @test _lapackVector(v, "x", 3) ≈ _LAPACK_A \ _LAPACK_B
    @test _lapackMatrix(v, "Ainv", 3, 3) ≈ inv(_LAPACK_A)
    local f::LinearAlgebra.LU = LinearAlgebra.lu(_LAPACK_A)
    @test _lapackMatrix(v, "LU", 3, 3) ≈ f.factors
    @test v["info"] == 2.0 #= U[2, 2] = 0: singular =#
  end

  @testset "dgels, dgelsy, dgelsx" begin
    local v::Dict{String, Float64} = _lapackConstants("""
      function ls
        input Real A[4, 2]; input Real b[4]; output Real x[4] = b;
      protected
        Real Awork[4, 2] = A; Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dgels("N", 4, 2, 1, Awork, 4, x, 4, work, lwork, info);
      end ls;
      function lsy
        input Real A[4, 2]; input Real b[4]; output Real x[4] = b; output Integer rank;
      protected
        Real Awork[4, 2] = A; Integer jpvt[2] = zeros(2); Real rcond = 1e-12; Integer lwork = 64; Real work[64];
        Integer info;
      external "FORTRAN 77" dgelsy(4, 2, 1, Awork, 4, x, 4, jpvt, rcond, rank, work, lwork, info);
      end lsy;
      function lsyRank
        input Real A[4, 2]; input Real b[4]; output Integer rank;
      protected
        Real x[4];
      algorithm
        (x, rank) := lsy(A, b);
      end lsyRank;
      function lsx
        input Real A[4, 2]; input Real b[4]; output Real x[4] = b; output Integer rank;
      protected
        Real Awork[4, 2] = A; Integer jpvt[2] = zeros(2); Real rcond = 1e-12; Real work[64]; Integer info;
      external "FORTRAN 77" dgelsx(4, 2, 1, Awork, 4, x, 4, jpvt, rcond, rank, work, info);
      end lsx;
      function lsxLwork
        input Real A[4, 2]; input Real b[4]; output Real x[4] = b;
      protected
        Real Awork[4, 2] = A; Integer jpvt[2] = zeros(2); Real rcond = 1e-12; Real work[64]; Integer rank;
        Integer info;
      external "FORTRAN 77" dgelsx(4, 2, 1, Awork, 4, x, 4, jpvt, rcond, rank, work, 64, info);
      end lsxLwork;""",
      "constant Real x[4] = ls($_LAPACK_C_MO, $_LAPACK_D_MO);
       constant Real y[4] = lsy($_LAPACK_C_MO, $_LAPACK_D_MO);
       constant Integer r = lsyRank({{1, 2}, {2, 4}, {3, 6}, {4, 8}}, $_LAPACK_D_MO);
       constant Real z[4] = lsx($_LAPACK_C_MO, $_LAPACK_D_MO);
       constant Real w[4] = lsxLwork($_LAPACK_C_MO, $_LAPACK_D_MO);")
    local expected::Vector{Float64} = _LAPACK_C \ _LAPACK_D
    @test _lapackVector(v, "x", 2) ≈ expected
    @test _lapackVector(v, "y", 2) ≈ expected
    @test v["r"] == 1.0
    @test _lapackVector(v, "z", 2) ≈ expected
    @test _lapackVector(v, "w", 2) ≈ expected
  end

  @testset "dgglse" begin
    #= min |A x - c| subject to B x = d: x1 + x2 = 1. =#
    local v::Dict{String, Float64} = _lapackConstants("""
      function lse
        input Real A[4, 2]; input Real c[4]; input Real B[1, 2]; input Real d[1]; output Real x[2];
      protected
        Real Awork[4, 2] = A; Real Bwork[1, 2] = B; Real cwork[4] = c; Real dwork[1] = d; Integer lwork = 64;
        Real work[64]; Integer info;
      external "FORTRAN 77" dgglse(4, 2, 1, Awork, 4, Bwork, 1, cwork, dwork, x, work, lwork, info);
      end lse;""",
      "constant Real x[2] = lse($_LAPACK_C_MO, $_LAPACK_D_MO, {{1, 1}}, {1});")
    local x::Vector{Float64} = _lapackVector(v, "x", 2)
    @test x[1] + x[2] ≈ 1.0
    #= On the line x = (1 - t, t): |C x - d|² is least at t = (C[:,2] - C[:,1])'(d - C[:,1]) / |C[:,2] - C[:,1]|². =#
    local e::Vector{Float64} = _LAPACK_C[:, 2] - _LAPACK_C[:, 1]
    local t::Float64 = (e' * (_LAPACK_D - _LAPACK_C[:, 1])) / (e' * e)
    @test x ≈ [1 - t, t]
  end

  @testset "dgtsv, dgbsv" begin
    #= Tridiagonal T = [2 -1 0; -1 2 -1; 0 -1 2]; dgbsv with kl = ku = 1 in band storage (2 kl + ku + 1 rows). =#
    local v::Dict{String, Float64} = _lapackConstants("""
      function tri
        input Real sub[2]; input Real diag[3]; input Real sup[2]; input Real b[3]; output Real x[3] = b;
      protected
        Real subw[2] = sub; Real diagw[3] = diag; Real supw[2] = sup; Integer info;
      external "FORTRAN 77" dgtsv(3, 1, subw, diagw, supw, x, 3, info);
      end tri;
      function band
        input Real AB[4, 3]; input Real b[3]; output Real x[3] = b;
      protected
        Real Awork[4, 3] = AB; Integer ipiv[3]; Integer info;
      external "FORTRAN 77" dgbsv(3, 1, 1, 1, Awork, 4, ipiv, x, 3, info);
      end band;""",
      "constant Real x[3] = tri({-1, -1}, {2, 2, 2}, {-1, -1}, $_LAPACK_B_MO);
       constant Real y[3] = band({{0, 0, 0}, {0, -1, -1}, {2, 2, 2}, {-1, -1, 0}}, $_LAPACK_B_MO);")
    local T::Matrix{Float64} = [2.0 -1.0 0.0; -1.0 2.0 -1.0; 0.0 -1.0 2.0]
    @test _lapackVector(v, "x", 3) ≈ T \ _LAPACK_B
    @test _lapackVector(v, "y", 3) ≈ T \ _LAPACK_B
  end

  @testset "dgesvd" begin
    local v::Dict{String, Float64} = _lapackConstants("""
      function sv
        input Real A[4, 2]; output Real sigma[2]; output Real U[4, 4]; output Real VT[2, 2];
      protected
        Real Awork[4, 2] = A; Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dgesvd("A", "A", 4, 2, Awork, 4, sigma, U, 4, VT, 2, work, lwork, info);
      end sv;""",
      "constant Real s[2] = sv($_LAPACK_C_MO);")
    @test _lapackVector(v, "s", 2) ≈ LinearAlgebra.svdvals(_LAPACK_C)
  end

  @testset "dgeev, dhseqr, dgegv" begin
    #= Eigenvalues of R = [0 -1; 1 0] (±i) and of the symmetric A (real); dhseqr on R (already Hessenberg); dgegv for
       (A, I), the same eigenvalues as A. =#
    local v::Dict{String, Float64} = _lapackConstants("""
      function eig
        input Real A[2, 2]; output Real re[2]; output Real im[2];
      protected
        Real Awork[2, 2] = A; Real vl[1, 2]; Real vr[2, 2]; Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dgeev("N", "V", 2, Awork, 2, re, im, vl, 1, vr, 2, work, lwork, info);
      end eig;
      function eigIm
        input Real A[2, 2]; output Real im[2];
      protected
        Real re[2];
      algorithm
        (re, im) := eig(A);
      end eigIm;
      function eig3
        input Real A[3, 3]; output Real re[3]; output Real im[3];
      protected
        Real Awork[3, 3] = A; Real vl[1, 3]; Real vr[1, 3]; Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dgeev("N", "N", 3, Awork, 3, re, im, vl, 1, vr, 1, work, lwork, info);
      end eig3;
      function hess
        input Real H[2, 2]; output Real wr[2]; output Real wi[2];
      protected
        Real Hwork[2, 2] = H; Real Z[2, 2]; Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dhseqr("E", "N", 2, 1, 2, Hwork, 2, wr, wi, Z, 2, work, lwork, info);
      end hess;
      function hessIm
        input Real H[2, 2]; output Real wi[2];
      protected
        Real wr[2];
      algorithm
        (wr, wi) := hess(H);
      end hessIm;
      function geig
        input Real A[3, 3]; input Real B[3, 3]; output Real alphar[3]; output Real alphai[3]; output Real beta[3];
      protected
        Real Awork[3, 3] = A; Real Bwork[3, 3] = B; Real vl[3, 3]; Real vr[3, 3]; Integer lwork = 64; Real work[64];
        Integer info;
      external "FORTRAN 77" dgegv("N", "N", 3, Awork, 3, Bwork, 3, alphar, alphai, beta, vl, 3, vr, 3, work, lwork, info);
      end geig;
      function geigValues
        input Real A[3, 3]; input Real B[3, 3]; output Real lambda[3];
      protected
        Real alphar[3]; Real alphai[3]; Real beta[3];
      algorithm
        (alphar, alphai, beta) := geig(A, B);
        lambda := {alphar[i] / beta[i] for i in 1:3};
      end geigValues;""",
      "constant Real re[2] = eig({{0, -1}, {1, 0}});
       constant Real im[2] = eigIm({{0, -1}, {1, 0}});
       constant Real ev[3] = eig3($_LAPACK_A_MO);
       constant Real hre[2] = hess({{0, -1}, {1, 0}});
       constant Real him[2] = hessIm({{0, -1}, {1, 0}});
       constant Real gev[3] = geigValues($_LAPACK_A_MO, {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}});")
    @test all(abs.(_lapackVector(v, "re", 2)) .< 1e-12)
    @test sort(_lapackVector(v, "im", 2)) ≈ [-1.0, 1.0]
    @test sort(_lapackVector(v, "ev", 3)) ≈ LinearAlgebra.eigvals(LinearAlgebra.Symmetric(_LAPACK_A))
    @test all(abs.(_lapackVector(v, "hre", 2)) .< 1e-12)
    @test sort(_lapackVector(v, "him", 2)) ≈ [-1.0, 1.0]
    @test sort(_lapackVector(v, "gev", 3)) ≈ LinearAlgebra.eigvals(LinearAlgebra.Symmetric(_LAPACK_A))
  end

  @testset "dgeqpf, dorgqr" begin
    #= Q R = A P: the columns of Q are orthonormal and |R[i, i]| = |diag of the pivoted R|. =#
    local v::Dict{String, Float64} = _lapackConstants("""
      function qr
        input Real A[4, 2]; output Real QR[4, 2] = A; output Real tau[2]; output Integer p[2];
      protected
        Real work[6]; Integer info;
      algorithm
        p := zeros(2);
        (QR, p, tau, info) := qrExt(A, p);
      end qr;
      function qrExt
        input Real A[4, 2]; input Integer p0[2]; output Real QR[4, 2] = A; output Integer p[2] = p0; output Real tau[2];
        output Integer info;
      protected
        Real work[6];
      external "FORTRAN 77" dgeqpf(4, 2, QR, 4, p, tau, work, info);
      end qrExt;
      function q
        input Real A[4, 2]; output Real Q[4, 2];
      protected
        Real tau[2]; Integer p[2]; Integer lwork = 64; Real work[64]; Integer info;
      algorithm
        (Q, tau, p) := qr(A);
        Q := orgqr(Q, tau);
      end q;
      function orgqr
        input Real QR[4, 2]; input Real tau[2]; output Real Q[4, 2] = QR;
      protected
        Integer lwork = 64; Real work[64]; Integer info;
      external "FORTRAN 77" dorgqr(4, 2, 2, Q, 4, tau, work, lwork, info);
      end orgqr;""",
      "constant Real R[4, 2] = qr($_LAPACK_C_MO);
       constant Real Q[4, 2] = q($_LAPACK_C_MO);")
    local Q::Matrix{Float64} = _lapackMatrix(v, "Q", 4, 2)
    @test Q' * Q ≈ LinearAlgebra.I(2)
    local R::Matrix{Float64} = _lapackMatrix(v, "R", 4, 2)
    local f = LinearAlgebra.qr(_LAPACK_C, LinearAlgebra.ColumnNorm())
    @test abs.([R[1, 1], R[2, 2]]) ≈ abs.(LinearAlgebra.diag(f.R))
    #= Q R (upper triangle) is A with its columns permuted. =#
    local AP::Matrix{Float64} = Q * [R[1, 1] R[1, 2]; 0.0 R[2, 2]]
    @test AP ≈ _LAPACK_C[:, f.p]
  end
end
