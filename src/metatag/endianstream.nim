# SPDX-License-Identifier: MIT

import std/[endians, math, streams]


proc readUint16BE*(strm: Stream, s: range[1..2] = 2): uint16 {.inline.} =
  ## Read ``s`` amount from stream as ``uint16`` in BE order.
  var buffer: array[2, byte]
  if strm.readData(buffer[2 - s].addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[2, byte]
  bigEndian16(bufferResult.addr, buffer.addr)

  result = cast[uint16](bufferResult)

proc readUint16LE*(strm: Stream, s: range[1..2] = 2): uint16 {.inline.} =
  ## Read ``s`` amount from stream as ``uint16`` in LE order.
  var buffer: array[2, byte]
  if strm.readData(buffer.addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[2, byte]
  littleEndian16(bufferResult.addr, buffer.addr)

  result = cast[uint16](bufferResult)

#================================================================================

proc writeUint16BE*(strm: Stream, data: uint16, s: range[1..2] = 2): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint16`` in BE order.
  if data > (2^(8*s)-1).uint16:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[2, byte]](data)
  var bufferResult: array[2,byte]

  bigEndian16(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[2 - s].addr, s)

proc writeUint16LE*(strm: Stream, data: uint16, s: range[1..2] = 2): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint16`` in LE order.
  if data > (2^(8*s)-1).uint16:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[2, byte]](data)
  var bufferResult: array[2,byte]

  littleEndian16(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[0].addr, s)

#================================================================================

proc readUint32BE*(strm: Stream, s: range[1..4] = 4): uint32 {.inline.} =
  ## Read ``s`` amount from stream as ``uint32`` in BE order.
  var buffer: array[4, byte]
  if strm.readData(buffer[4 - s].addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[4, byte]
  bigEndian32(bufferResult.addr, buffer.addr)

  result = cast[uint32](bufferResult)

proc readUint32LE*(strm: Stream, s: range[1..4] = 4): uint32 {.inline.} =
  ## Read ``s`` amount from stream as ``uint32`` in LE order.
  var buffer: array[4, byte]
  if strm.readData(buffer.addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[4, byte]
  littleEndian32(bufferResult.addr, buffer.addr)

  result = cast[uint32](bufferResult)


#================================================================================

proc writeUint32BE*(strm: Stream, data: uint32, s: range[1..4] = 4): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint32`` in BE order.
  if data > (2^(8*s)-1).uint32:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[4, byte]](data)
  var bufferResult: array[4,byte]

  bigEndian32(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[4 - s].addr, s)

proc writeUint32LE*(strm: Stream, data: uint32, s: range[1..4] = 4): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint32`` in LE order.
  if data > (2^(8*s)-1).uint32:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[4, byte]](data)
  var bufferResult: array[4,byte]

  littleEndian32(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[0].addr, s)

#================================================================================

proc readUint64BE*(strm: Stream, s: range[1..8] = 8): uint64 {.inline.} =
  ## Read ``s`` amount from stream as ``uint64`` in BE order.
  var buffer: array[8, byte]
  if strm.readData(buffer[8 - s].addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[8, byte]
  bigEndian64(bufferResult.addr, buffer.addr)

  result = cast[uint64](bufferResult)

proc readUint64LE*(strm: Stream, s: range[1..8] = 8): uint64 {.inline.} =
  ## Read ``s`` amount from stream as ``uint64`` in LE order.
  var buffer: array[8, byte]
  if strm.readData(buffer.addr, s) != s:
    raise newException(IOError, "Error while reading stream")

  var bufferResult: array[8, byte]
  littleEndian64(bufferResult.addr, buffer.addr)

  result = cast[uint64](bufferResult)

#================================================================================

proc writeUint64BE*(strm: Stream, data: uint64, s: range[1..8] = 8): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint64`` in BE order.
  if data > (2^(8*s)-1).uint64:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[8, byte]](data)
  var bufferResult: array[8,byte]

  bigEndian64(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[8 - s].addr, s)

proc writeUint64LE*(strm: Stream, data: uint64, s: range[1..8] = 8): void {.inline.} =
  ## Write ``s`` amount to stream as ``uint64`` in LE order.
  if data > (2^(8*s)-1).uint64:
    raise newException(IOError, "Data is too big.")

  var buffer = cast[array[8, byte]](data)
  var bufferResult: array[8,byte]

  littleEndian64(bufferResult.addr, buffer.addr)
  strm.writeData(bufferResult[0].addr, s)