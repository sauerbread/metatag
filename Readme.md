# Metatag - a metadata library
Metatag is a metadata read/write library for Nim that supports id3v2.3.0 and flac metadata.
Its only dependency is [`nim-lang/zip`](https://github.com/nim-lang/zip) and `zlib` & `iconv` (on Unix).

## Usage
Metatag is relatively _"low level"_. It gives you raw access to relevant frames & attached Pictures for id3 and
vorbis comments & pictures for flac. Skim through the [id3v2 spec](https://id3.org/id3v2.3.0#Declared_ID3v2_frames)
for frame ids or the [vorbis comment spec](https://www.xiph.org/vorbis/doc/v-comment.html#fieldnames) for flac fieldnames. However the usage section, should guide you enough.

### Read a mp3 file
In this example we are reading a mp3 file, echoing all text & picture frames and exporting the pictures.
```nim
import std/[enumerate, streams, strformat]
import metatag/id3

var tag = readId3("music.mp3")

for textFrame in tag.textFrames: # echo all text frames
  echo fmt"id: {textFrame.id}"
  echo fmt"content: {textFrame.content}"

for userDefinedFrame in tag.userDefinedFrames: # a.k.a. TXXX & WXXX
  echo fmt"id: {userDefinedFrame.id}"
  echo fmt"description: {userDefinedFrame.description}"
  echo fmt"content: {userDefinedFrame.content}"

for (i, picture) in enumerate(1, tag.attachedPictures): # echo all pictures & exporting them 
  echo fmt"picture: '{picture.mime}', '{picture.pictureType}', '{picture.description}'"

  var filename:string
  case picture.mime:
    of "image/jpeg":
      filename = fmt"picture ({i}).jpg"
    of "image/png":
      filename = fmt"picture ({i}).png"
    of "image/webp":
      filename = fmt"picture ({i}).webp"
    else:
      filename = fmt"picture ({i}).dat"

  var strm = newFileStream(filename, fmWrite)
  var picbuffer = picture.data
  strm.writeData(picbuffer[0].addr,picbuffer.len)
  strm.close()
```

### Write to a mp3 file
In this example we are creating a new tag and an attached picture, reading the cover
and write the tag to the file.
```nim
import std/streams
import metatag/id3

# Create the tag
var tag = Id3Tag(
  textFrames: @[
    ("TIT2", "Girlfriend"),
    ("TPE1", "Avril Lavigne"),
    ("TALB", "The Best Damn Thing"),
    ("TRCK", "1"),
    ("TCON", "Pop-punk"),
    ("TYER", "2007"),
    ("TPUB", "RCA Records")
  ],
  urlFrames: @[
    ("WOAF", "https://music.youtube.com/watch?v=Bg59q4puhmg"),
    ("WOAR", "https://www.avrillavigne.com/"),
    ("WPUB", "https://www.rcarecords.com/")
  ],
  userDefinedFrames: @[
    ("TXXX", "BARCODE", "886970377423")
  ]
)

# Create an attached picture
var strm = newFileStream("picture.jpg", fmRead)

tag.attachedPictures.add(
  AttachedPicture(
    mime: "image/jpeg",
    pictureType: 3,
    description: "Idk. the cover I guess.",
    data: cast[seq[byte]](strm.readAll())
  )
)

strm.close()

# Write the tag to your file
writeId3("music.mp3", tag)
```

### Read a flac file
In this example we are reading a flac file, echoing all comments & pictures and exporting them.
```nim
import std/[enumerate, streams, strformat]
import metatag/flac

var tag = readFlac("music.flac")

echo tag.vendorString # Read the vendor string

for comment in tag.userComment: # echo every user comment
  echo fmt"fieldname: {comment.fieldname}"
  echo fmt"content: {comment.content}"

for (i, picture) in enumerate(1, tag.pictures): # echo all pictures & exporting them
  echo fmt"picture: '{picture.pictureType}', '{picture.mime}', '{picture.description}'"

  var filename:string
  case picture.mime:
    of "image/jpeg":
      filename = fmt"picture ({i}).jpg"
    of "image/png":
      filename = fmt"picture ({i}).png"
    of "image/webp":
      filename = fmt"picture ({i}).webp"
    else: # Some Devs doesnt set the mime type
      filename = fmt"picture ({i}).dat"

  var strm = newFileStream(filename, fmWrite)
  var picbuffer = picture.data
  strm.writeData(picbuffer[0].addr,picbuffer.len)
  strm.close()
```

### Write to a flac file
In this example we are creating a new tag and a flac picture, reading the cover
and write the tag to the file.
```nim
import std/streams
import metatag/flac

# Create the tag
var tag = FlacTag(
  userComment: @[
    ("TITLE", "Girlfriend"),
    ("ALBUM", "The Best Damn Thing"),
    ("TRACKNUMBER", "1"),
    ("ARTIST", "Avril Lavigne"),
    ("ORGANIZATION", "RCA Records"),
    ("GENRE", "Pop-punk"),
    ("CONTACT", "https://www.rcarecords.com/")
  ]
)

# Create a flac picture
var strm = newFileStream("picture.jpg", fmRead)

tag.pictures.add(
  FlacPicture(
    pictureType: 3,
    mime: "image/jpeg",
    description: "Cover of the album",
    data: cast[seq[byte]](strm.readAll())
  )
)

strm.close()

# Write the tag to your file
writeFlac("music.flac", tag)
```

## FAQ
1. _Can you support `x` metadata format?_<br>
   Maybe, currently the most popular metadata formats are supported.
   If you want to help out, consider contributing.

2. _How can I help?_<br>
   You're more than welcome to contribute to this library, grab
   yourself a module and try to improve it or write a new parser
   for a soon to be supported format.

3. _Well, reading this file doesnt work, but it should?_<br>
   Everything in this library _should work™_. However this library
   is written according to the specs and handles _"dirty files"_
   with mediocre success. Plz be gentle.

4. _How does it compare to [Taglib](https://taglib.org/)?_<br>
   Metatag is badly written, supports less formats, doesnt handle
   edge cases at all and not all features are supported. On the 
   other hand, it's written from scratch in Nim, _"easy"_ to use,
   reasonable fast and coded like my grandma _could_ understand.

5. _What is unsupported?_<br>
   ID3v2.3.0: UTF16BE frames on Win, unsynchronisation, encryption,
   Synchronised lyrics and more ...
   Miscellaneous: ID3v2.4.0, ID3v2.2.0
   
6. _Great music taste._<br>
   Thanks.

## License
```txt
Metatag - a tag reading/writing library
Copyright (C) 2022 Sauerbread

Metatag is licensed under the MIT License
```