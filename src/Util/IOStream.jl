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

module IOStream_M

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl IOStreamType
@UniontypeDecl IOStreamData

#= TODO! change these to X_TYPE =#
@Uniontype IOStreamType begin
  @Record FILE begin
    name::String
  end
  @Record LIST begin
  end
  @Record BUFFER begin
  end
  @Record JULIA_BUFFER begin
  end
end

@Uniontype IOStreamData begin
  @Record FILE_DATA begin
    data::Int
  end
  @Record LIST_DATA begin
    data::List{String}
  end
  @Record BUFFER_DATA begin
    data::Int
  end
  #= johti17 =#
  @Record JULIA_BUFFER_DATA begin
    internalBuffer::IOBuffer
  end
end

struct IOSTREAM
  name::String
  ty::IOStreamType
  data::IOStreamData
end


const stdInput = 0::Int
const stdOutput = 1::Int
const stdError = 2::Int
const emptyStreamOfTypeList =
  IOSTREAM("emptyStreamOfTypeList", LIST(), LIST_DATA(nil))::IOSTREAM

import ..IOStreamExt

import ListUtil

function create(streamName::String, streamType::IOStreamType)::IOSTREAM
  local outStream::IOSTREAM
  outStream = begin
    local fileName::String
    local fileID::Int
    local bufferID::Int
    @match (streamName, streamType) begin
      (_, FILE(fileName)) => begin
        @assign fileID = IOStreamExt.createFile(fileName)
        IOSTREAM(streamName, streamType, FILE_DATA(fileID))
      end

      (_, LIST(__)) => begin
        IOSTREAM(streamName, streamType, LIST_DATA(nil))
      end

      (_, BUFFER(__)) => begin
        @assign bufferID = IOStreamExt.createBuffer()
        IOSTREAM(streamName, streamType, BUFFER_DATA(bufferID))
      end

      (_, JULIA_BUFFER(__)) => begin
        IOSTREAM(streamName, streamType, JULIA_BUFFER_DATA(IOBuffer()))
      end

    end
  end
  return outStream
end

function append(inStream::IOSTREAM, inString::String)::IOSTREAM
  local outStream::IOSTREAM
  outStream = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    local streamName::String
    local streamType::IOStreamType
    @match (inStream, inString) begin
      (fStream && IOSTREAM(data = FILE_DATA(fileID)), _) => begin
        IOStreamExt.appendFile(fileID, inString)
        fStream
      end

      (IOSTREAM(streamName, streamType, LIST_DATA(listData)), _) => begin
        IOSTREAM(streamName, streamType, LIST_DATA(_cons(inString, listData)))
      end

      (bStream && IOSTREAM(data = BUFFER_DATA(bufferID)), _) => begin
        IOStreamExt.appendBuffer(bufferID, inString)
        bStream
      end

      (bStream && IOSTREAM(data = JULIA_BUFFER_DATA(buffer)), _) => begin
        println(buffer, inString)
        bStream
      end

    end
  end
  return outStream
end

function appendList(inStream::IOSTREAM, inStringList::List)::IOSTREAM
  local outStream::IOSTREAM
  outStream = ListUtil.foldr(inStringList, append, inStream)
  return outStream
end

function close(inStream::IOSTREAM)::IOSTREAM
  local outStream::IOSTREAM
  @assign outStream = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    @matchcontinue inStream begin
      fStream && IOSTREAM(data = FILE_DATA(fileID)) => begin
        IOStreamExt.closeFile(fileID)
        fStream
      end
      _ => begin
        inStream
      end
    end
  end
  #=  close does nothing for list or buffer streams
  =#
  return outStream
end

function delete(inStream::IOSTREAM)
  return @assign _ = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    @match inStream begin
      IOSTREAM(data = FILE_DATA(fileID)) => begin
        IOStreamExt.deleteFile(fileID)
        ()
      end

      IOSTREAM(data = LIST_DATA(__)) => begin
        ()
      end

      IOSTREAM(data = BUFFER_DATA(bufferID)) => begin
        IOStreamExt.deleteBuffer(bufferID)
        ()
      end
      _ => begin
        ()
      end
    end
  end
end

function clear(inStream::IOSTREAM)::IOSTREAM
  local outStream::IOSTREAM
  @assign outStream = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    local name::String
    local data::IOStreamData
    local ty::IOStreamType
    @matchcontinue inStream begin
      fStream && IOSTREAM(data = FILE_DATA(fileID)) => begin
        IOStreamExt.clearFile(fileID)
        fStream
      end
      IOSTREAM(name, ty, _) => begin
        IOSTREAM(name, ty, LIST_DATA(nil))
      end
      bStream && IOSTREAM(data = BUFFER_DATA(bufferID)) => begin
        IOStreamExt.clearBuffer(bufferID)
        bStream
      end
    end
  end
  return outStream
end

function string(inStream::IOSTREAM)::String
  local string = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    local str::String
    @match inStream begin
      IOSTREAM(data = FILE_DATA(fileID)) => begin
        str = IOStreamExt.readFile(fileID)
        str
      end
      IOSTREAM(data = LIST_DATA(listData)) => begin
        str = IOStreamExt.appendReversedList(listData)
        str
      end
      IOSTREAM(data = BUFFER_DATA(bufferID)) => begin
        str = IOStreamExt.readBuffer(bufferID)
        str
      end
      IOSTREAM(data = JULIA_BUFFER_DATA(jlBuffer)) => begin
        String(take!(jlBuffer))
      end
    end
  end
  return string
end

"""  @author: adrpo
  This function will print a string depending on the second argument
  to the standard output (1) or standard error (2).
  Use IOStream.stdOutput, IOStream.stdError constants
"""
function print(inStream::IOSTREAM, whereToPrint::Int)
  return @assign _ = begin
    local listData::List{String}
    local fileID::Int
    local bufferID::Int
    local fStream::IOSTREAM
    local lStream::IOSTREAM
    local bStream::IOSTREAM
    @match (inStream, whereToPrint) begin
      (IOSTREAM(data = FILE_DATA(fileID)), _) => begin
        IOStreamExt.printFile(fileID, whereToPrint)
        ()
      end
      (IOSTREAM(data = BUFFER_DATA(bufferID)), _) => begin
        IOStreamExt.printBuffer(bufferID, whereToPrint)
        ()
      end
      (IOSTREAM(data = LIST_DATA(listData)), _) => begin
        IOStreamExt.printReversedList(listData, whereToPrint)
        ()
      end
    end
  end
end

#= /*
TODO! Global Streams to be implemented later
  IOStream.remember(IOStream, id);
  IOStream = IOStream.aquire(id);
  IOStream.forget(IOStream, id);
*/ =#

@exportAll()
end
