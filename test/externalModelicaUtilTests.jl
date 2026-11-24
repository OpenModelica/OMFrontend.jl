# Tests of the Julia port of the MSL external C functions the frontend evaluates
# (src/Util/ExternalModelicaUtil): strings, files, MAT files and zlib inflate. The expected values are
# those of the MSL 4.1.0 C code (OMRuntimeExternalC). The MAT files in test/Data are the test files of
# MSL 4.1.0 (Modelica/Resources/Data/Utilities, BSD 3-Clause); the other MAT files are written here.
# Author: John Tinnerholm

const EMU = OMFrontend.Frontend.ExternalModelicaUtil
const DATA_DIR = joinpath(@__DIR__, "Data")

"""
    MatWriter

Writes small MAT files of version 5 for the tests: numeric matrices of any class, structs, and the
compressed form of version 7 with a stored (uncompressed) DEFLATE block.
"""
module MatWriter

word(x::Integer, big::Bool)::Vector{UInt8} = (local v::UInt32 = UInt32(x); big ? reverse(reinterpret(UInt8, [v])) : reinterpret(UInt8, [v]))

"""A data element of type `type`, padded to 8 bytes."""
function element(type::Int64, payload::Vector{UInt8}, big::Bool)::Vector{UInt8}
  local out::Vector{UInt8} = vcat(word(type, big), word(length(payload), big), payload)
  append!(out, zeros(UInt8, mod(-length(out), 8)))
  return out
end

"""The bytes of `values`, in the byte order of the file."""
function bytesOf(values::Vector{T}, big::Bool)::Vector{UInt8} where {T}
  local out::Vector{UInt8} = UInt8[]
  for v::T in values
    local b::Vector{UInt8} = reinterpret(UInt8, [v])
    append!(out, big ? reverse(b) : b)
  end
  return out
end

"""The flags, dimensions and name elements of a miMATRIX."""
function head(classType::Int64, dims::Vector{Int64}, name::String, complex::Bool, big::Bool)::Vector{UInt8}
  local flags::UInt32 = UInt32(classType) | (complex ? UInt32(0x0800) : UInt32(0))
  return vcat(element(6, vcat(word(flags, big), word(0, big)), big),
              element(5, bytesOf(Int32.(dims), big), big),
              element(1, Vector{UInt8}(codeunits(name)), big))
end

"""A numeric miMATRIX: the data of type `miType` (and the same as the imaginary part when `complex`)."""
function numeric(name::String, classType::Int64, dims::Vector{Int64}, miType::Int64, data::Vector{UInt8}, big::Bool;
                 complex::Bool = false)::Vector{UInt8}
  local body::Vector{UInt8} = vcat(head(classType, dims, name, complex, big), element(miType, data, big))
  complex && append!(body, element(miType, data, big))
  return element(14, body, big)
end

"""A char miMATRIX."""
text(name::String, s::String, big::Bool)::Vector{UInt8} =
  element(14, vcat(head(4, [1, length(s)], name, false, big), element(4, bytesOf(UInt16.(collect(codeunits(s))), big), big)), big)

"""A struct miMATRIX with `fields` (miMATRIX elements, element by element, field by field)."""
function structure(name::String, dims::Vector{Int64}, fieldNames::Vector{String}, fields::Vector{Vector{UInt8}},
                   big::Bool)::Vector{UInt8}
  local nameLength::Int64 = 8
  local names::Vector{UInt8} = UInt8[]
  for f::String in fieldNames
    append!(names, codeunits(f)); append!(names, zeros(UInt8, nameLength - ncodeunits(f)))
  end
  #= the field name length is a small element: type and size in one word =#
  local lengthElement::Vector{UInt8} = vcat(word((4 << 16) | 5, big), word(nameLength, big))
  return element(14, vcat(head(2, dims, name, false, big), lengthElement, element(1, names, big), fields...), big)
end

"""The 128-byte header of version 5."""
function header(big::Bool)::Vector{UInt8}
  local text::Vector{UInt8} = Vector{UInt8}(rpad("MATLAB 5.0 MAT-file, written by the OMFrontend tests", 116))
  return vcat(text, zeros(UInt8, 8), big ? UInt8[0x01, 0x00, UInt8('M'), UInt8('I')] : UInt8[0x00, 0x01, UInt8('I'), UInt8('M')])
end

"""`data` as a zlib stream with one stored DEFLATE block."""
function storedZlib(data::Vector{UInt8})::Vector{UInt8}
  local a::UInt32 = 1
  local b::UInt32 = 0
  for x::UInt8 in data
    a = (a + x) % 65521
    b = (b + a) % 65521
  end
  local n::UInt16 = UInt16(length(data))
  return vcat(UInt8[0x78, 0x01, 0x01], reinterpret(UInt8, [n]), reinterpret(UInt8, [~n]), data,
              reverse(reinterpret(UInt8, [(b << 16) | a])))
end

"""A miCOMPRESSED element holding `matrix`."""
compressed(matrix::Vector{UInt8}, big::Bool)::Vector{UInt8} =
  (local z::Vector{UInt8} = storedZlib(matrix); vcat(word(15, big), word(length(z), big), z))

end

"""The message of the error `f` throws, `""` if none."""
errorMessage(f::Function)::String = try f(); "" catch e; sprint(showerror, e) end

@testset "ExternalModelicaUtil: MSL external functions in Julia" begin
  @testset "strings" begin
    @test EMU.Strings_scanReal("  2.5e1 rest", 1, false) == (8, 25.0)
    @test EMU.Strings_scanReal("-1.5", 1, true) == (1, 0.0)
    @test EMU.Strings_scanReal("1e", 1, false) == (1, 0.0)
    @test EMU.Strings_scanReal("1.", 1, false) == (3, 1.0)
    @test EMU.Strings_scanReal(".5x", 1, false) == (3, 0.5)
    #= out of range: strtod gives ±Inf and 0 =#
    @test EMU.Strings_scanReal("7e323", 1, false) == (6, Inf)
    @test EMU.Strings_scanReal("-1E6985", 1, false) == (8, -Inf)
    @test EMU.Strings_scanReal("8e-9190", 1, false) == (8, 0.0)
    @test EMU.Strings_scanReal(repeat("9", 120), 1, false) == (1, 0.0)
    @test EMU.Strings_scanInteger(" -42 x", 1, false) == (5, -42)
    @test EMU.Strings_scanInteger("-42", 1, true) == (1, 0)
    @test EMU.Strings_scanInteger("4.2", 1, false) == (1, 0)
    @test EMU.Strings_scanInteger("99999999999999999999", 1, false) == (21, -1)
    @test EMU.Strings_scanString("  \"quoted\" rest", 1) == (11, "quoted")
    @test EMU.Strings_scanString("\"a\\\"b\"", 1) == (7, "a\\\"b")
    @test EMU.Strings_scanString("\"\"", 1) == (1, "")
    @test EMU.Strings_scanString("\"open", 1) == (1, "")
    @test EMU.Strings_scanIdentifier(" abc_1 x", 1) == (7, "abc_1")
    @test EMU.Strings_scanIdentifier("_a", 1) == (1, "")
    @test EMU.Strings_skipWhiteSpace(" \t\nx", 1) == 4
    @test EMU.Strings_skipWhiteSpace("ab", 3) == 3
    @test EMU.Strings_compare("abc", "ABC", false) == 2
    @test EMU.Strings_compare("abc", "ABC", true) == 3
    @test EMU.Strings_compare("ab", "abc", false) == 1
    @test EMU.Strings_hashString("Modelica") == 2118346737
    @test EMU.Strings_hashString("") == -1431655766
  end

  @testset "files" begin
    local dir::String = mktempdir()
    local file::String = joinpath(dir, "lines.txt")
    write(file, "a\r\nb\n\nlast")
    @test EMU.Streams_countLines(file) == 4
    @test EMU.Streams_readLine(file, 1) == ("a\r", false)
    @test EMU.Streams_readLine(file, 3) == ("", false)
    @test EMU.Streams_readLine(file, 4) == ("last", false)
    @test EMU.Streams_readLine(file, 5) == ("", true)
    #= the file changes: the cached lines are not used =#
    EMU.Streams_print("more", file)
    @test EMU.Streams_countLines(file) == 4
    @test EMU.Streams_readLine(file, 4) == ("lastmore", false)
    EMU.Streams_close(file)
    write(file, "x\n")
    @test EMU.Streams_countLines(file) == 1
    local empty::String = joinpath(dir, "empty.txt")
    touch(empty)
    @test EMU.Streams_countLines(empty) == 0
    @test occursin("Not possible to open file", errorMessage(() -> EMU.Streams_countLines(joinpath(dir, "none"))))
    @test EMU.File_stat(file) == 2
    @test EMU.File_stat(dir) == 3
    @test EMU.File_stat(joinpath(dir, "none")) == 1
    Sys.isunix() && @test EMU.File_stat("/dev/null") == 4
    @test EMU.File_fullPathName(file) == realpath(file)
    if !Sys.iswindows()
      @test EMU.File_fullPathName(dir * "/") == realpath(dir) * "/"
      @test EMU.File_fullPathName("/none/x") == "/none/x"
      cd(dir) do
        @test EMU.File_fullPathName("none/x") == pwd() * "/none/x"
      end
    end
  end

  @testset "MAT files of MSL: versions 4, 6, 7; 7.3 is not supported" begin
    local expected::Matrix{Float64} = [11.0 12.0; 21.0 22.0; 31.0 32.0]
    for version::String in ("v4", "v6", "v7")
      local file::String = joinpath(DATA_DIR, "Test_RealMatrix_$version.mat")
      @test EMU.ModelicaIO_readMatrixSizes(file, "Matrix_A") == [3, 2]
      @test EMU.ModelicaIO_readRealMatrix(file, "Matrix_A", 3, 2, false) == expected
    end
    local v4::String = joinpath(DATA_DIR, "Test_RealMatrix_v4.mat")
    @test EMU.ModelicaIO_readRealMatrix(v4, "Matrix_B", 3, 2, false) == expected
    local v7::String = joinpath(DATA_DIR, "Test_RealMatrix_v7.mat")
    @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(v7, "nope")) ==
          "ModelicaIO_readMatrixSizes failed: Variable \"nope\" not found in file \"$v7\"."
    @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(v7, "Matrix_A.x")) ==
          "ModelicaIO_readMatrixSizes failed: Variable \"Matrix_A\" of \"Matrix_A.x\" is not a struct array."
    @test errorMessage(() -> EMU.ModelicaIO_readRealMatrix(v7, "Matrix_A", 2, 2, false)) ==
          "ModelicaIO_readRealMatrix failed: Cannot read 2 rows of array \"Matrix_A(3,2)\" from file \"$v7\""
    @test errorMessage(() -> EMU.ModelicaIO_readRealMatrix(v7, "Matrix_A", 3, 3, false)) ==
          "ModelicaIO_readRealMatrix failed: Cannot read 3 columns of array \"Matrix_A(3,2)\" from file \"$v7\""
    local v73::String = joinpath(DATA_DIR, "Test_RealMatrix_v7.3.mat")
    @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(v73, "Matrix_A")) ==
          "ModelicaIO_readMatrixSizes failed: No HDF5 support which is required to read the v7.3 MAT file \"$v73\""
    @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes("/none.mat", "A")) ==
          "ModelicaIO_readMatrixSizes failed: Not possible to open file \"/none.mat\": No such file or directory"
    local notMat::String = joinpath(mktempdir(), "text.mat")
    write(notMat, "not a MAT file at all")
    @test occursin("Not possible to open file", errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(notMat, "A")))
    #= the verbose message =#
    local shown::String = mktemp() do path::String, io::IOStream
      redirect_stdout(io) do
        EMU.ModelicaIO_readRealMatrix(v7, "Matrix_A", 3, 2, true)
      end
      flush(io)
      read(path, String)
    end
    @test shown == "... loading \"Matrix_A\" from \"$v7\"\n"
  end

  @testset "MAT files of version 5 and 7: classes, structs, byte order, compression" begin
    local dir::String = mktempdir()
    for big::Bool in (false, true)
      local W = MatWriter
      local ints::Vector{UInt8} = W.bytesOf(Int32[1, -2, 3, -4, 5, -6], big)
      local field::Vector{UInt8} = W.numeric("", 6, [2, 1], 9, W.bytesOf([1.5, 2.5], big), big)
      local inner::Vector{UInt8} = W.structure("", [1, 1], ["B"], [field], big)
      local file::String = joinpath(dir, "test_$big.mat")
      write(file, vcat(W.header(big),
                       W.numeric("I", 12, [2, 3], 5, ints, big),
                       W.numeric("S", 7, [1, 2], 7, W.bytesOf(Float32[0.5, -0.25], big), big),
                       W.numeric("U8", 9, [1, 3], 2, UInt8[1, 2, 255], big),
                       W.numeric("C", 6, [1, 2], 9, W.bytesOf([1.0, 2.0], big), big; complex = true),
                       W.text("T", "ab", big),
                       W.structure("s", [1, 1], ["A", "t"], [field, inner], big),
                       W.structure("s2", [1, 2], ["A"], [field, field], big),
                       W.compressed(W.numeric("Z", 6, [2, 2], 9, W.bytesOf([1.0, 2.0, 3.0, 4.0], big), big), big)))
      @test EMU.ModelicaIO_readRealMatrix(file, "I", 2, 3, false) == [1.0 3.0 5.0; -2.0 -4.0 -6.0]
      @test EMU.ModelicaIO_readRealMatrix(file, "S", 1, 2, false) == [0.5 -0.25]
      @test EMU.ModelicaIO_readRealMatrix(file, "U8", 1, 3, false) == [1.0 2.0 255.0]
      @test EMU.ModelicaIO_readRealMatrix(file, "Z", 2, 2, false) == [1.0 3.0; 2.0 4.0]
      @test EMU.ModelicaIO_readMatrixSizes(file, "s.A") == [2, 1]
      @test EMU.ModelicaIO_readRealMatrix(file, "s.t.B", 2, 1, false) == reshape([1.5, 2.5], 2, 1)
      @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(file, "C")) ==
            "ModelicaIO_readMatrixSizes failed: Matrix \"C\" must not be complex."
      @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(file, "T")) ==
            "ModelicaIO_readMatrixSizes failed: Matrix \"T\" is not a numeric array."
      @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(file, "s")) ==
            "ModelicaIO_readMatrixSizes failed: Matrix \"s\" is not a numeric array."
      @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(file, "s2.A")) ==
            "ModelicaIO_readMatrixSizes failed: Variable \"s2\" of \"s2.A\" is not a 1x1 struct array."
      @test errorMessage(() -> EMU.ModelicaIO_readMatrixSizes(file, "s.x")) ==
            "ModelicaIO_readMatrixSizes failed: Variable \"s.x\" not found in file \"$file\"."
      #= a missing field before the last name: the C code gives no error and no matrix =#
      @test EMU.ModelicaIO_readMatrixSizes(file, "s.x.y") == [0, 0]
    end
  end

  @testset "inflate" begin
    local data::Vector{UInt8} = Vector{UInt8}(codeunits("inflate " ^ 40))
    @test EMU.zlibDecompress(MatWriter.storedZlib(data)) == data
    local corrupt::Vector{UInt8} = MatWriter.storedZlib(data)
    corrupt[end] ⊻= 0x01
    @test errorMessage(() -> EMU.zlibDecompress(corrupt)) == "Invalid compressed data: Adler-32 checksum"
    @test errorMessage(() -> EMU.zlibDecompress(UInt8[0x78, 0x9c, 0x05])) == "Invalid compressed data: too short for a zlib stream"
    @test EMU.adler32(UInt8[]) == 0x00000001
    @test EMU.adler32(Vector{UInt8}(codeunits("Wikipedia"))) == 0x11e60398
  end

  @testset "evaluated when a model is flattened" begin
    local file::String = joinpath(DATA_DIR, "Test_RealMatrix_v7.mat")
    local source::String = """
      package ExtC
        function scanReal
          input String string; input Integer startIndex = 1; input Boolean unsigned = false;
          output Integer nextIndex; output Real number;
        external "C" ModelicaStrings_scanReal(string, startIndex, unsigned, nextIndex, number)
          annotation(Library = "ModelicaExternalC");
        end scanReal;
        function readMatrixSizes
          input String fileName; input String matrixName; output Integer dim[2];
        external "C" ModelicaIO_readMatrixSizes(fileName, matrixName, dim)
          annotation(Library = {"ModelicaIO", "ModelicaMatIO", "zlib"});
        end readMatrixSizes;
        function readRealMatrix
          input String fileName; input String matrixName; input Integer nrow; input Integer ncol;
          input Boolean verboseRead = true; output Real matrix[nrow, ncol];
        external "C" ModelicaIO_readRealMatrix(fileName, matrixName, matrix, size(matrix, 1), size(matrix, 2), verboseRead)
          annotation(Library = {"ModelicaIO", "ModelicaMatIO", "zlib"});
        end readRealMatrix;
        model M
          constant String file = "$(escape_string(file))";
          constant Integer dim[2] = readMatrixSizes(file, "Matrix_A");
          constant Real A[dim[1], dim[2]] = readRealMatrix(file, "Matrix_A", dim[1], dim[2], false);
          constant Integer next = scanReal(" 2.5e1 rest");
          Real x = A[3, 2] * time;
        end M;
      end ExtC;
      """
    local flat::String = OMFrontend.flatModelica("ExtC.M"; string = source)
    @test occursin("constant Integer 'dim[1]' = 3;", flat)
    @test occursin("constant Real 'A[2,1]' = 21.0;", flat)
    @test occursin("constant Integer next = 7;", flat)
    @test occursin("Real x = 32.0 * time;", flat)
  end
end
