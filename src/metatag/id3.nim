# SPDX-License-Identifier: MIT
# Spec: https://id3.org/id3v2.3.0

import std/[encodings, streams, strutils]
import zip/zlib
import endianstream

const id3PictureType* = [
  "Other",
  "32x32 pixels 'file icon' (PNG only)",
  "Other file icon",
  "Cover (front)",
  "Cover (back)",
  "Leaflet page",
  "Media (e.g. label side of CD)",
  "Lead artist/lead performer/soloist",
  "Artist/performer",
  "Conductor",
  "Band/Orchestra",
  "Composer",
  "Lyricist/text writer",
  "Recording Location",
  "During recording",
  "During performance",
  "Movie/video screen capture",
  "A bright coloured fish",
  "Illustration",
  "Band/artist logotype",
  "Publisher/Studio logotype",
]

type
  Id3Tag* = object
    textFrames*, urlFrames*: seq[tuple[id: string, content: string]]
    userDefinedFrames*: seq[tuple[id: string, description: string, content: string]]
    involvedPeople*: seq[string]
    unsychLyrics*, comments*: seq[tuple[lang: string, content: string]]
    attachedPictures*: seq[AttachedPicture]
  
  AttachedPicture* = object
    mime*: string
    pictureType*: range[0..20] # id3PictureType
    description*: string
    data*: seq[byte]

proc decodeSize(strm: Stream): int =
  var buf = strm.readStr(4)
  result = ((buf[0].int shl 21) +
            (buf[1].int shl 14) +
            (buf[2].int shl 7) +
            buf[3].int) + 10

proc encodeSize(encsize: int): array[4, byte] = 
  result[3] = byte(encsize and 0x7F)
  result[2] = byte((encsize shr 7) and 0x7F)
  result[1] = byte((encsize shr 14) and 0x7F)
  result[0] = byte((encsize shr 21) and 0x7F)

proc getTermChar(encoding: uint8): string = 
  if encoding == 0x00:
    "\0" 
  else: 
    "\0\0"

template decodeContent(content: string, encoding: uint8) = # We wanna reuse the open converter
  if content.len == 0: # skip if nothing is there.
    discard
  elif encoding == 0x00:
    content = fromISO88591.convert(content)
  elif encoding == 0x01:
    if (content[0].byte == 0xFF) and (content[1].byte == 0xFE):
       content = fromUTF16.convert(content[2..^1]) # Get rid of BOM
    else:
      when not defined(windows):
        content = fromUTF16BE.convert(content[2..^1])
      else:
        raise newException(EncodingError, "UTF16BE frames are unsupported on Windows.")
  else:
    raise newException(EncodingError, "This frame contains an unsupported encoding.")

proc readId3*(filename: string): Id3Tag =
  let strm = newFileStream(filename, fmRead)
  defer: strm.close()

  var fromISO88591 = open("UTF-8", "ISO-8859-1")
  var fromUTF16 = open("UTF-8", "UTF-16")
  when not defined(windows): 
    var fromUTF16BE = open("UTF-8", "UTF-16BE")

  if not ((strm.readStr(3) == "ID3") and (strm.readUint16BE() == 0x0300)):
    raise newException(IOError, "The file doesnt seem to be a id3v2.3.0 file.")

  let tagFlags = strm.readUint8()
  let unsynchronisation = (tagFlags and 0x80) != 0
  let extendedHeader = (tagFlags and 0x40) != 0
  let tagSize = decodeSize(strm)

  if unsynchronisation:
      raise newException(IOError, "Unsynchronisation is unsupported.")

  if extendedHeader: # Its not necessary, we dont care
    strm.setPosition(strm.readUint32BE().int + strm.getPosition())

  while (strm.getPosition() < tagSize + 10) and (strm.peekUint8() != 0x00):
    var frameID = strm.readStr(4)
    var frameSize = strm.readUint32BE().int

    strm.setPosition(strm.getPosition() + 1) # Skip boring flags
    var frameFlags = strm.readUint8() # The right ones.
    var compression = (frameFlags and 0x80) != 0
    var encryption = (frameFlags and 0x40) != 0
    var groupingIdentity = (frameFlags and 0x20) != 0

    if compression: # Skip decompressed size, we dont care
      strm.setPosition(strm.getPosition() + 4)
    if encryption: # Too broad for our scope
      raise newException(IOError, "This frame seem to be encrypted & is unsupported.")
    if groupingIdentity: # We dont sign, we dont care
      strm.setPosition(strm.getPosition() + 1)

    var frameBuffer = strm.readStr(frameSize)

    if compression:
      frameBuffer = uncompress(frameBuffer, stream=ZLIB_STREAM)

    var fstrm = newStringStream(frameBuffer) # framestream Im just lazy to type
    defer: fstrm.close()

    if (frameID[0] == 'T') and (frameID != "TXXX"):
      var encoding = fstrm.readUint8()
      var content = fstrm.readStr(frameSize - 1)

      decodeContent(content, encoding)
      result.textFrames.add((frameID, content))

    elif (frameID[0] == 'W') and (frameID != "WXXX"):
      var encoding:uint8 = 0x00 
      var content = fstrm.readStr(frameSize)
      decodeContent(content, encoding)
      result.textFrames.add((frameID, content))

    elif (frameID == "TXXX") or (frameID == "WXXX"):
      var encoding = fstrm.readUint8()
      var content = fstrm.readStr(frameSize - 1).rsplit(getTermChar(encoding), 1)
      
      decodeContent(content[0], encoding) # Description
      if frameID == "TXXX":
        decodeContent(content[1], encoding) # TXXX according to encoding
      else:  
        decodeContent(content[1], 0x00) # WXXX URLS are always ISO

      result.userDefinedFrames.add((frameID, content[0],content[1]))

    elif frameID == "IPLS":
      var encoding = fstrm.readUint8()
      var content = fstrm.readStr(frameSize - 1)

      for ipls in content.split(getTermChar(encoding)):
        var people = ipls
        decodeContent(people, encoding)
        result.involvedPeople.add(people)

    elif (frameID == "USLT") or (frameID == "COMM"):
      var encoding = fstrm.readUint8()
      var language = fstrm.readStr(3)
      var content = fstrm.readStr(frameSize - 4).split(getTermChar(encoding), 1)[1]

      decodeContent(content, encoding)

      if frameID == "USLT":
        result.unsychLyrics.add((language, content))
      else:
        result.comments.add((language, content))

    elif frameID == "APIC":
      var resultPicture: AttachedPicture
      var encoding = fstrm.readUint8()
      
      var mimeBuf = fstrm.readStr(1)
      while mimeBuf != "\0":
        resultPicture.mime &= mimeBuf
        mimeBuf = fstrm.readStr(1)
      decodeContent(resultPicture.mime, 0x00)

      resultPicture.pictureType = fstrm.readUint8()

      var descrBuf = if encoding == 0x00: fstrm.readStr(1) else: fstrm.readStr(2)
      while descrBuf != getTermChar(encoding):
        resultPicture.description &= descrBuf
        descrBuf = if encoding == 0x00: fstrm.readStr(1) else: fstrm.readStr(2)
      decodeContent(resultPicture.description, encoding)

      var pictureBufferLength = frameSize - fstrm.getPosition()
      resultPicture.data.setLen(pictureBufferLength)
      if fstrm.readData(resultPicture.data[0].addr, pictureBufferLength) != pictureBufferLength:
        raise newException(IOError, "Error while reading id3 picture.")

      result.attachedPictures.add(resultPicture)

  fromISO88591.close()
  fromUTF16.close()
  when not defined(windows):
    fromUTF16BE.close()

proc writeId3*(filename: string, tag: Id3Tag): void =
  var strm = newFileStream(filename, fmRead)
  
  if not ((strm.readStr(3) == "ID3")):
    raise newException(IOError, "The file doesnt seem to be a id3v2 file.")

  strm.setPosition(strm.getPosition() + 3) # dont care
  strm.setPosition(strm.getPosition() + decodeSize(strm)) # skip tag
  
  let fileContent = strm.readAll() # Read everything else

  strm.close()

  strm = newFileStream(filename, fmWrite)
  var toISO88591 = open("ISO-8859-1", "UTF-8")
  var toUTF16 = open("UTF-16", "UTF-8")

  # Header = I, D, 3, ver: 03, rev: 00, flags: n0pe
  var tagHeader = [byte 0x49, 0x44, 0x33, 0x03, 0x00, 0x00]
  strm.writeData(tagHeader.addr, 6)

  # Placeholder size, comeback later.
  var placeholderSize = [byte 0x00, 0x00, 0x00, 0x00]
  strm.writeData(placeholderSize.addr, 4)

  # Handy consts.
  var frameFlags = [byte 0x00, 0x00]
  var isoByte = 0x00.byte
  var utfByte = 0x01.byte
  var utfBOM = [byte 0xFF, 0xFE]
  var isoTerminated = 0x00.byte
  var utfTerminated = [byte 0x00, 0x00]
  var emptyUtfTerminated = [byte 0xFF, 0xFE, 0x00, 0x00, 0x00, 0x00] # BOM, NULL, Terminated

  for textFrame in tag.textFrames:
    strm.write(textFrame.id)
    strm.writeUint32BE((textFrame.content.len*2 + 3).uint32) # UTF16=len*2
    strm.writeData(frameFlags.addr, 2)

    strm.writeData(utfByte.addr, 1)
    strm.writeData(utfBOM.addr, 2)
    strm.write(toUTF16.convert(textFrame.content))

  for urlFrame in tag.urlFrames:
    strm.write(urlFrame.id)
    strm.writeUint32BE(urlFrame.content.len.uint32)
    strm.writeData(frameFlags.addr, 2)

    strm.write(toISO88591.convert(urlFrame.content))

  for userDefinedFrame in tag.userDefinedFrames:
    strm.write(userDefinedFrame.id)

    if userDefinedFrame.id == "TXXX":
      strm.writeUint32BE((userDefinedFrame.description.len*2 + userDefinedFrame.content.len*2 + 7).uint32)
      strm.writeData(frameFlags.addr, 2)

      strm.writeData(utfByte.addr, 1)
      strm.writeData(utfBOM.addr, 2)
      strm.write(toUTF16.convert(userDefinedFrame.description))
      strm.writeData(utfTerminated.addr, 2)
      strm.writeData(utfBOM.addr, 2)
      strm.write(toUTF16.convert(userDefinedFrame.content))
    else:
      strm.writeUint32BE((userDefinedFrame.description.len*2 + userDefinedFrame.content.len + 5).uint32)
      strm.writeData(frameFlags.addr, 2)

      strm.writeData(utfByte.addr, 1)
      strm.writeData(utfBOM.addr, 2)
      strm.write(toUTF16.convert(userDefinedFrame.description))
      strm.writeData(utfTerminated.addr, 2)
      strm.write(toISO88591.convert(userDefinedFrame.content))


  if tag.involvedPeople.len != 0:
    var peopleSize = 0
    for people in tag.involvedPeople:
      peopleSize += people.len*2 + 4 # UTF-16 + utfBOM + utfTerminated
    
    strm.write("IPLS")
    strm.writeUint32BE((peopleSize + 2).uint32)
    strm.writeData(frameFlags.addr, 2)
    strm.writeData(utfByte.addr, 1)

    for people in tag.involvedPeople:
      strm.writeData(utfBOM.addr, 2)
      strm.write(toUTF16.convert(people))
      strm.writeData(utfTerminated.addr, 2)


  for lyrics in tag.unsychLyrics:
    strm.write("USLT")
    strm.writeUint32BE((lyrics.content.len*2 + 8).uint32)
    strm.writeData(frameFlags.addr, 2)

    strm.writeData(utfByte.addr, 1)
    strm.write(lyrics.lang)
    strm.writeData(utfTerminated.addr, 2)
    strm.writeData(utfBOM.addr, 2)
    strm.write(toUTF16.convert(lyrics.content))

  for comment in tag.comments:
    strm.write("COMM")
    strm.writeUint32BE((comment.content.len*2 + 12).uint32)
    strm.writeData(frameFlags.addr, 2)

    strm.writeData(utfByte.addr, 1)
    strm.write(comment.lang)
    strm.writeData(emptyUtfTerminated.addr, 6)
    strm.writeData(utfBOM.addr, 2)
    strm.write(toUTF16.convert(comment.content))

  for picture in tag.attachedPictures:
    strm.write("APIC")
    var picbuffer = picture.data

    if picture.description.len == 0: # Save Space and Itunes Bugs
      strm.writeUint32BE((picbuffer.len + picture.mime.len + 4).uint32)
      strm.writeData(frameFlags.addr, 2)

      strm.writeData(isoByte.addr, 1)
      strm.write(picture.mime)
      strm.writeData(isoTerminated.addr, 1)
      strm.write(picture.pictureType.byte)
      strm.writeData(isoTerminated.addr, 1)
      strm.writeData(picBuffer[0].addr, picBuffer.len)        
    else:
      strm.writeUint32BE((picture.mime.len + picture.description.len*2 + picbuffer.len + 7).uint32)
      strm.writeData(frameFlags.addr, 2)
      
      strm.writeData(utfByte.addr, 1)
      strm.write(picture.mime)
      strm.writeData(isoTerminated.addr, 1)
      strm.write(picture.pictureType.byte)
      strm.writeData(utfBOM.addr, 2)
      strm.write(toUTF16.convert(picture.description))
      strm.writeData(utfTerminated.addr, 2)
      strm.writeData(picBuffer[0].addr, picBuffer.len)

  var tagSize = strm.getPosition() - 10 # Totalsize - Header
  var encodedSize = encodeSize(tagSize)

  # Its Rewind Time
  strm.setPosition(6)
  strm.writeData(encodedSize.addr, 4)
  strm.setPosition(tagSize)

  strm.write(fileContent)

  toISO88591.close()
  toUTF16.close()
  strm.close()
