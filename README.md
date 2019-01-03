# C-evo-x

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game for
Windows by [Steffen Gerlach][12].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de


## License

C-evo and C-evo-x are in the public domain.


## Prerequisites

The following software is required to build C-evo-x.

 - Borland [Delphi 4.0][21] or later.
 - Visual C# and Visual C++ from Microsoft [Visual Studio 2010 Express][22] or later.
 - [WiX Toolset 3.11.1][23] or later for building the installer.

[21]: https://winworldpc.com/product/delphi/4x
[22]: https://visualstudio.microsoft.com/vs/older-downloads/
[23]: http://wixtoolset.org


## Components

The C-evo-x code is assembled from a number of different sources.

 - `AI_Kit_C\`: contains Charles Nadolski's [Version 14 C++ Blank AI
   Template][31].
 - `AI_Template\`: contains the C# AI template and source for the
   `CevoDotNet.exe` game loader; installed with [C-evo 1.2.0][32].
 - `Configurator\`: source for the C# `Configurator.exe` program; part of the
   [C-evo 1.2.0 source][33].
 - `Delphi_AI_Kit\`: source for the [Delphi AI Development Kit][34].
 - `Installer\`: source for the MSI installer.
 - `Project\`: Delphi code for the game; part of the [C-evo 1.2.0 source][33].
 - `Protocol\`: Delphi code for the AI protocol shared with the Delphi AI
   Development Kit; part of the [C-evo 1.2.0 source][33].
 - `Resources\`: external graphic, sound and text configuration files used by
   the game; installed with [C-evo 1.2.0][32].

See the [`LICENSE`][35] file for the list of contributors.

[31]: http://c-evo.org/files/download.php?cevoaikitc.cevoaikitc.zip
[32]: http://c-evo.org/files/download.php
[33]: http://c-evo.org/files/download.php?cevosrc.cevosrc.zip
[34]: http://c-evo.org/files/download.php?cevodelphiaikit.cevodelphiaikit.zip
[35]: https://github.com/donmccaughey/c_evo_x/blob/master/LICENSE


## Build System

The `Makefile` located in the project root directory will build all the
components and place build output into a `tmp\` directory in the root of the
project.  The version of `make` that is installed with Delphi should be used to
execute the `Makefile`.

### Targets

The `Makefile` contains a number of targets.  Type

	make help

to see the full list.  Two notable targets: `all` and `clean`.  The `all`
target is the default and will build the game, all the AIs and the installer.
The `clean` target will remove all build output.

### Command Prompt Set Up

Follow these steps to make sure your system is set up and ready to build:

1. Ensure you have all the prerequisites installed.
1. Check that the Delphi compiler `dcc32.exe`, the Borland resource compiler
   `brcc32.exe` and Borland `make.exe` are available on the `PATH` of your
   command prompt.  These files are installed in a directory like `C:\Program
   Files (x86)\Borland\Delphi4\Bin`.
1. Check that `MSBuild.exe` is available on the `PATH` of your command prompt.
   This file is part of .NET and is installed in a directory like
   `C:\Windows\Microsoft.NET\Framework\v4.0.30319\`.
1. Check that the WiX commands `candle.exe` and `light.exe` are available on
   the `PATH` of your command prompt.  These files are part of the WiX Tookset
   and are installed in a directory like `C:\Program Files (x86)\WiX Toolset
   v3.11\bin`

### Building From the Command Prompt

To build, open a Windows command prompt, navigate to the project root and run
the `Makefile`:

	make

To remove all build output, run:

	make clean

### Building From the Delphi IDE

You _must_ run the `Makefile` build at least once before opening any of the
Delphi projects in the Delphi IDE.  If you do not, you may encounter errors or
warnings like the following:

* Compiler error: "Could not create output file
  '..\tmp\units\cevo\StringTables.dcu'"
    > the `tmp\` output directory structure needs to be created

* Compiler warning: "File not found: 'Res1.res'"
    > the `.rc` files need to be compiled into `.res` files

* Run error: "Could not find program, '..\tmp\CEvoWin32.exe'.
    > the `CEvoWin32` game loader needs to be built

* Run error: "[FILENOTFOUND]"
    > the external resource files need to be copied into place

* Alert "Error Reading Form": "Class TButtonA not found. Ignore the error and
  continue?"
    > the `CevoComponents` package needs to be built and installed in Delphi


## Project Structure

### The Delphi Projects

There are five Delphi projects: three projects for building the game, one for
building the Delphi sample AI and one for building a Delphi components package.

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

The `Project\CevoComponents.dpk` project builds the Delphi components package
`CevoComponents.bpl`.  The `Makefile` build uses
`scripts\install_component.cmd` to install the package into Delphi; you can
also do this manually in Delphi by clicking _Component_ | _Install Packages..._
| _Add..._.


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

- [C-evo at Launchpad][91], a fork of C-evo by [Jiří Hajda][92].
- [cevo at GitLab][93], a fork of C-evo by [Vasilii Novikov][94] (last active
  in 2016).
- [Updated C-evo AI Template][95], a fork of Steffen's C# AI Template by
  [dougmill][96].

[91]: https://launchpad.net/c-evo
[92]: https://launchpad.net/~chronoscz
[93]: https://gitlab.com/vn971/cevo
[94]: https://diasp.de/u/vn971
[95]: https://github.com/dougmill/c-evo-ai-template
[96]: https://github.com/dougmill

