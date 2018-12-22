# C-evo-x

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game for
Windows by [Steffen Gerlach][12].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de


## License

C-evo and C-evo-x are in the public domain.


## Building

The game and sample AI are written in Delphi, a variant of Object Pascal.
Borland Delphi 4.0 or later is required to build the game.  Before opening any
of the Delphi projects in the IDE, you must run the provided `Makefile` to
create output directories, generate resources and copy external resource files
into the correct location.  The `Makefile` will also compile the Delphi
projects.  All build output is placed in a `tmp\` directory created in the
project root.


## Project Structure

The `AI_Template\` directory contains two C# projects: `CevoDotNet.csproj` and `AI.csproj`, in the `AI_Template\CevoDotNet\` and `AI_Template\Project\` directories respectively.

The `Configurator\` directory contains the standalone configuration utility
written in C#.

The `Delphi_AI_Kit\` directory contains the [Delphi AI Development Kit][21]
sources.  The Delphi project in this directory geneates the `AIProject.dll`
output file for the sample AI.

The `Project\` directory contains the main game source derived from the [C-evo
1.2.0 source][22].  This directory contains three Delphi projects.  The
`Integrated.dpr` project builds the game as a single executable named
`Integrated.exe`.  The `CevoWin32.dpr` and `cevo.dpr` projects build the
`CevoWin32.exe` and `cevo.dll` files respectively; the executable loads and
runs the game code located in the DLL.

The `Protocol\` directory contains the `Protocol.pas` unit that defines the AI
communication protocol.  This code is shared between the game code in
`Project\` and the AI code in `Delphi_AI_Kit\`.

The `Resources\` directory contains external graphic, sound and text
configuration files needed by the game at runtime.  These are copied into the
correct place in the `tmp\` directory by the `Makefile` build.

Note that the code to build the standard AI (`StdAI.dll`) that ships with
[C-evo][23] is currently missing.

[21]: http://c-evo.org/files/download.php?cevodelphiaikit.cevodelphiaikit.zip
[22]: http://c-evo.org/files/download.php?cevosrc.cevosrc.zip
[23]: http://c-evo.org/files/download.php


## Related

- [C-evo at Launchpad][31], a fork of C-evo by [Jiří Hajda][32].
- [cevo at GitLab][33], a fork of C-evo by [Vasilii Novikov][34] (last active in 2016).

[31]: https://launchpad.net/c-evo
[32]: https://launchpad.net/~chronoscz
[33]: https://gitlab.com/vn971/cevo
[34]: https://diasp.de/u/vn971

