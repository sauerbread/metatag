# SPDX-License-Identifier: MIT
# Spec: https://xiph.org/flac/format.html

import std/[streams, strutils]
import endianstream

type
  FlacPicture* = object
    pictureType*: range[0..19] # id3PictureType
    mime*: string
    description*: string
    width*: int
    height*: int
    colorDepth*: int
    numberOfColors*: int # For indexed pictures (e.g. GIF), 0 for not-indexed
    data*: seq[byte]

  FlacTag* = object
    vendorString*: string
    userComment*: seq[tuple[fieldname: string, content: string]]
    pictures*: seq[FlacPicture]

proc readFlacPicture(strm: Stream): FlacPicture =
  result.pictureType = strm.readUint32BE().int
  result.mime = strm.readStr(strm.readUint32BE().int)
  result.description = strm.readStr(strm.readUint32BE().int)
  result.width = strm.readUint32BE().int
  result.height = strm.readUint32BE().int
  result.colorDepth = strm.readUint32BE().int
  result.numberOfColors = strm.readUint32BE().int

  let pictureBufferLength = strm.readUint32BE().int
  result.data.setLen(pictureBufferLength)

  if strm.readData(result.data[0].addr, pictureBufferLength) != pictureBufferLength:
    raise newException(IOError, "Error while reading flac picture.")

template readVorbisComment(strm: Stream, tag: FlacTag) =
  let vendorLength = strm.readUint32LE().int
  tag.vendorString = strm.readStr(vendorLength)
  let userCommentListLength = strm.readUint32LE().int

  for i in 0 ..< userCommentListLength:
    var commentLength = strm.readUint32LE().int
    var comment = strm.readStr(commentLength).split("=", maxsplit = 1)
    tag.userComment.add((comment[0],comment[1]))

proc readFlac*(filename: string): FlacTag =
  let strm = newFileStream(filename, fmRead)
  defer: strm.close()

  if not (strm.readStr(4) == "fLaC"):
    raise newException(IOError, "The file doesnt seem to be a flac file.")

  var lastBlock = false

  while not lastBlock:
    var blockByte = strm.readUint8()
    lastBlock = (blockByte and 0x80) != 0
    var blockType:uint8 = blockByte and 0x7F
    var blockLength = strm.readUint32BE(3).int

    case blockType:
      of 4: # Vorbis Comment
        readVorbisComment(strm, result)
      of 6: # Flac Picture
        result.pictures.add(readFlacPicture(strm))
      of 0, 1, 2, 3, 5: # Everything else, dont care
        strm.setPosition(strm.getPosition() + blockLength)
      else:
        discard

proc writeFlac*(filename: string, tag: FlacTag): void =
  var strm = newFileStream(filename, fmRead)

  if not (strm.readStr(4) == "fLaC"):
    raise newException(IOError, "The file doesnt seem to be a flac file.")

  var lastBlock = false
  var previousChunks: seq[byte]

  while not lastBlock:
    var blockByte = strm.readUint8()
    lastBlock = (blockByte and 0x80) != 0
    var blockType:uint8 = blockByte and 0x7F
    var blockLength = strm.readUint32BE(3).int + 4
    # Reset position and read whole block
    strm.setPosition(strm.getPosition() - 4)

    case blockType:
      of 1, 4, 6: # 1 Padding, 4 Vorbis Comment, 6 Flac Picture
        strm.setPosition(strm.getPosition() + blockLength)
      of 0, 2, 3, 5: # Everything else
        var chunkBuffer = newSeq[byte](blockLength)
        if strm.readData(chunkBuffer[0].addr, blockLength) != blockLength:
          raise newException(IOError, "Error while reading flac file.")
        if lastBlock:
          chunkBuffer[0] = blockType # not lastBlock anymore
        previousChunks &= chunkBuffer
      else:
        discard

  let followingChunks = strm.readAll()

  strm.close()
  strm = newFileStream(filename, fmWrite)
  strm.write("fLaC")
  strm.writeData(previousChunks[0].addr, previousChunks.len)

  for picture in tag.pictures:
    var pictureBuffer = picture.data
    var blockHeader = 6
    strm.writeData(blockHeader.addr, 1)
    var pictureBlockLength = 32 + picture.mime.len + picture.description.len + picturebuffer.len
    strm.writeUint32BE(pictureBlockLength.uint32, 3)
    strm.writeUint32BE(picture.pictureType.uint32)
    strm.writeUint32BE(picture.mime.len.uint32)
    strm.write(picture.mime)
    strm.writeUint32BE(picture.description.len.uint32)
    strm.write(picture.description)
    strm.writeUint32BE(picture.width.uint32)
    strm.writeUint32BE(picture.height.uint32)
    strm.writeUint32BE(picture.colorDepth.uint32)
    strm.writeUint32BE(picture.numberOfColors.uint32)
    strm.writeUint32BE(pictureBuffer.len.uint32)
    strm.writeData(pictureBuffer[0].addr, pictureBuffer.len)

  var blockHeader = 4 or 0x80 # Set Vorbis Comment as lastBlock
  strm.writeData(blockHeader.addr, 1)
  var vorbisCommentBlockLength = 8
  vorbisCommentBlockLength += tag.vendorString.len
  vorbisCommentBlockLength += tag.userComment.len * 4
  for comment in tag.userComment:
    vorbisCommentBlockLength += comment.fieldname.len + comment.content.len
  strm.writeUint32BE(vorbisCommentBlockLength.uint32, 3)
  strm.writeUint32LE(tag.vendorString.len.uint32)
  strm.write(tag.vendorString)
  strm.writeUint32LE(tag.userComment.len.uint32)
  for comment in tag.userComment:
      strm.writeUint32LE((comment.fieldname.len + comment.content.len + 1).uint32)
      strm.write(comment.fieldname)
      strm.write("=")
      strm.write(comment.content)

  strm.write(followingChunks)
  strm.close()