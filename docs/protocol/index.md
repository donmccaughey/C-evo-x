---
title: "The Protocol"
---

# The Protocol

    > C-evo 1.2.0, C-evo-x 1.2.1 - 1.2.2

One of the foundational goals of C-evo is to be a playground and testbed for
creating AIs.  To make the playground open to other developers, C-evo is
designed with a client-server architecture, where the game engine acts as the
_server_ and players (both human and AI) act as _clients_ that communicate with
the server using the "protocol", a binary interface of functions, data
structures and constants.

## In the Game

The most authoritative version of the protocol is the `Protocol.pas` file
included with the [game source code][11].

 - `Protocol.pas`
    - [highlighted][12]
    - [plain text][13]
    - [in the repository][14]

[11]: http://www.c-evo.org/files/download.php?cevosrc.cevosrc.zip
[12]: ./game/
[13]: ./game/Protocol.pas
[14]: https://github.com/donmccaughey/C-evo-x/blob/master/Project/Protocol.pas

## Low Level AI Development

Along with C-evo 1.2.0, [Steffen][21] [released
an AI manual and header file][22] so
that developers can build AIs in any language that can produce a Windows DLL.

 - `protocol.h`
    - [highlighted][23]
    - [plain text][24]
    - [original][25]
 - AI Development manual
    - [formatted][26]
    - [original][27]

[21]: http://www.steffengerlach.de/
[22]: http://www.c-evo.org/bb/viewtopic.php?f=5&t=60
[23]: ./c/
[24]: ./c/protocol.h
[25]: http://c-evo.org/protocol.h
[26]: ./c/aidev.html
[27]: http://c-evo.org/aidev.html


## Delphi AI Development

The [Delphi AI Development Kit][31] appears to target C-evo 1.1.0, so it's a
little out of date.  The Delphi Kit includes classes and utilities built on top
of the low level protocol.

 - `Protocol.pas`
    - [highlighted][32]
    - [plain text][33]
    - [in the repository][34]
 - Manual
    - [formatted][35]

[31]: http://www.c-evo.org/files/download.php?cevodelphiaikit.cevodelphiaikit.zip
[32]: ./delphi/
[33]: ./delphi/Protocol.pas
[34]: https://github.com/donmccaughey/C-evo-x/blob/master/Delphi_AI_Kit/Protocol.pas
[35]: ./delphi/manual.html


## C# AI Development

The C# AI Development Kit is installed with [C-evo 1.2.0][41].  The code that
describes the protocol in C# is spread around multiple files in the [`Lib\`][42]
directory.

 - `Protocol.cs`
    - [highlighted][43]
    - [plain text][44]
    - [in the repository][45]
 - Manual
    - [formatted][46]

[41]: http://www.c-evo.org/files/download.php
[42]: https://github.com/donmccaughey/C-evo-x/tree/master/AI_Template/Project/Lib
[43]: ./c-sharp/
[44]: ./c-sharp/Protocol.cs
[45]: https://github.com/donmccaughey/C-evo-x/blob/master/AI_Template/Project/Lib/Protocol.cs
[46]: ./c-sharp/AI-development-manual.html

