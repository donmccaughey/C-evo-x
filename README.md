# C-evo-x

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game for
Windows by [Steffen Gerlach][12].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de


## License

C-evo and C-evo-x are in the public domain.


## Prerequisites

The following software is required to build C-evo-x.

 - A Bash shell such as [Git BASH][21].
 - Borland [Delphi 4.0][22] or later.
 - Visual C# and Visual C++ from Microsoft [Visual Studio 2010 Express][23] or later.

[21]: https://gitforwindows.org
[22]: https://winworldpc.com/product/delphi/4x
[23]: https://visualstudio.microsoft.com/vs/older-downloads/


## Components

The C-evo-x code is assembled from a number of different sources.

 - `AI_Kit_C\`: contains Charles Nadolski's [Version 14 C++ Blank AI Template][31].
 - `AI_Template\`: contains the C# AI template and source for the `CevoDotNet.exe` game loader; installed with [C-evo 1.2.0][32].
 - `Configurator\`: source for the C# `Configurator.exe` program; part of the [C-evo 1.2.0 source][33].
 - `Delphi_AI_Kit\`: source for the [Delphi AI Development Kit][34].
 - `Project\`: Delphi code for the game; part of the [C-evo 1.2.0 source][33].
 - `Protocol\`: Delphi code for the AI protocol shared with the Delphi AI Development Kit; part of the [C-evo 1.2.0 source][33].
 - `Resources\`: external graphic, sound and text configuration files used by the game; installed with [C-evo 1.2.0][32].

See the [`LICENSE`][35] file for the list of contributors.

[31]: http://c-evo.org/files/download.php?cevoaikitc.cevoaikitc.zip
[32]: http://c-evo.org/files/download.php
[33]: http://c-evo.org/files/download.php?cevosrc.cevosrc.zip
[34]: http://c-evo.org/files/download.php?cevodelphiaikit.cevodelphiaikit.zip
[35]: https://github.com/donmccaughey/c_evo_x/blob/master/LICENSE


## Building

The `Makefile` located in the project root directory will build all the
components and place build output into a `tmp\` directory in the root of the
project.  The `Makefile` expects to run in a Bash shell.  The version of `make`
that is installed with Delphi can be used to execute the `Makefile`.

The `Makefile` contains a number of targets.  Type

	make help

to see the full list.  Two notable targets: `all` and `clean`.  The `all`
target is the default and will build the game and all the AIs.  The `clean`
target will remove all build output.

Follow these steps to make sure your system is set up and ready to build:

1. Ensure you have all the prerequisites installed.
1. Check that the Delphi compiler `dcc32.exe`, the Borland resource compiler
   `brcc32.exe` and Borland `make.exe` are available on the `PATH` of your Bash
   shell.  These files are installed in a directory like `C:\Program Files
   (x86)\Borland\Delphi4\Bin`.
1. Check that `MSBuild.exe` is available on the `PATH` of your Bash shell.
   This file is part of .NET and is installed in a directory like
   `C:\Windows\Microsoft.NET\Framework\v4.0.30319\`.

To build, open a Bash shell, navigate to the project root and run the
`Makefile`:

	make	# or: make all

To remove all build output, run:

	make clean

**Note:** You _must_ run the `Makefile` build at least once to create the
`tmp\` output directory structure, compile the `.res` files and copy the
external resource files into place.  The Delphi projects depend on these steps
and will fail without them.

After running the `Makefile` build, you can open any of the individual IDE
projects and build and run from within that IDE.


## Project Structure

### The Delphi Projects

There are four Delphi projects: three projects for building the game and one
for building the Delphi sample AI.

The core game can be built in two ways: as a single integrated executable or as
a DLL and loader.

The `Project\Integrated.dpr` project builds the game as a single integrated
executable named `Integrated.exe`.  The `Integrated.exe` executable can only
load non-.NET AIs, including Delphi and C++ AIs.

The `Project\cevo.dpr` project compiles the game code into a DLL named
`cevo.dll`.

The `Project\CevoWin32.dpr` project creates a simple `CevoWin32.exe` executable
that loads the game DLL and non-.NET AIs, including Delphi and C++ AIs.

The `Delphi_AI_Kit\AIProject.dpr` project builds the Delphi sample AI into a
DLL named `AIProject.dll`.


### The C# Projects

There are three C# projects: one for the Configurator and two for sample AIs in C#.

The `Configurator\Configurator.sln` solution and
`Configurator\Configurator.csproj` C# project build the `Configurator.exe`
application, a stand-alone program for setting game parameters, installing
localizations and downloading maps and AIs.

The `AI_Template\Project\AI.sln` solution and `AI_Template\Project\AI.csproj`
C# project build the C# sample AI into a DLL named `AI.dll`.

The `AI_Template\CevoDotNet\CevoDotNet.csproj` C# project builds the
`CevoDotNet.exe` loader program which loads the `cevo.DLL` game DLL and all AI
DLLs, including AIs written in .NET languages like C#.  The `CevoDotNet.csproj`
is also referenced by the `AI_Template\Project\AI.sln` solution.


### The C++ Projects

The `AI_Kit_C\MyAI.sln` solution and `AI_Kit_C\MyAI.vcxproj` C++ project build the C++ sample AI into a DLL named `MyAI.dll`.

The `AI_Kit_C\HAL_source\HAL.sln` solution and `AI_Kit_C\HAL_source\HAL.vcxproj` C++ project build the HAL AI into a DLL named `HAL.dll`.


## Related

- [C-evo at Launchpad][31], a fork of C-evo by [Jiří Hajda][32].
- [cevo at GitLab][33], a fork of C-evo by [Vasilii Novikov][34] (last active in 2016).

[31]: https://launchpad.net/c-evo
[32]: https://launchpad.net/~chronoscz
[33]: https://gitlab.com/vn971/cevo
[34]: https://diasp.de/u/vn971

