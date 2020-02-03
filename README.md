# C-evo-x

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game for
Windows by [Steffen Gerlach][12].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de


## License

C-evo and C-evo-x are in the public domain.


## Prerequisites

The following software is required to build C-evo-x.

 - Borland [Delphi 4.0][21].
 - Visual C# and Visual C++ from Microsoft [Visual Studio 2010 Express][22].
 - [WiX Toolset 3.11.1][23].

The following software is optional.

 - [ImageMagick 7.0.8-37][24].

[YMMV][25] on other versions.  The build is tested on Windows 10 Pro (64-bit)
version 1809.

[21]: https://winworldpc.com/product/delphi/4x
[22]: https://visualstudio.microsoft.com/vs/older-downloads/
[23]: http://wixtoolset.org
[24]: https://www.imagemagick.org/
[25]: https://www.urbandictionary.com/define.php?term=ymmv


## Components

The C-evo-x code is assembled from a number of different sources.

 - `AI_Kit_C\`: contains Charles Nadolski's [Version 14 C++ Blank AI
   Template][31].
 - `AI_Template\`: contains the C# AI template and source for the
   `CevoDotNet.exe` game loader; installed with [C-evo 1.2.0][32].
 - `assets\`: source for additional graphics.
 - `Configurator\`: source for the C# `Configurator.exe` program; part of the
   [C-evo 1.2.0 source][33].
 - `Delphi_AI_Kit\`: source for the [Delphi AI Development Kit][34].
 - `docs\`: source for the [C-evo-x Docs][35] site.
 - `Installer\`: source for the MSI installer, a replacement for the C-evo's
   Inno Setup installer.
 - `Project\`: Delphi code for the game; part of the [C-evo 1.2.0 source][33].
 - `Resources\`: external graphic, sound and text configuration files used by
   the game; installed with [C-evo 1.2.0][32].
 - `scripts\`: scripts used by the `Makefile` build.
 - `StdAI\`: source for the standard AI, `StdAI.dll`, that ships with C-evo
   1.2.0; obtained directly from Steffen.

See the [`LICENSE`][36] file for the list of contributors.

[31]: http://c-evo.org/files/download.php?cevoaikitc.cevoaikitc.zip
[32]: http://c-evo.org/files/download.php
[33]: http://c-evo.org/files/download.php?cevosrc.cevosrc.zip
[34]: http://c-evo.org/files/download.php?cevodelphiaikit.cevodelphiaikit.zip
[35]: https://donmccaughey.github.io/C-evo-x/
[36]: https://github.com/donmccaughey/c_evo_x/blob/master/LICENSE


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

If the build fails with a message like:

    Error: Could not create output file '..\tmp\CevoComponents.bpl'

close the Delphi IDE and run the `make` command again.

### Asset Build Steps

Some of the game assets are generated from the original artwork.  Since these
build steps require additional tools and the outputs don't change often, the
generated assets are checked in to the repository, making these build steps
optional.  The `assets` and `clean-assets` make targets control the asset build.
Before building these targets, install ImageMagick and check that `convert.exe`
is available on the `PATH` of your command prompt.  This file is installed in a
directory like `C:\Program Files\ImageMagick-7.0.8-Q16\`.

### Installer Build Steps

The `all` and `installer` make targets will build an unsigned [MSI
installer][41] located at `tmp\C-evo-x.msi`.  You can double-click the
`C-evo-x.msi` file to install it on your system.  To debug problems with the
installer, run the following command to create an install log:

    msiexec /i tmp\C-evo-x.msi /L*V tmp\install.log

To uninstall C-evo-x, go to Settings | Apps (or Control Panel | Programs on
older Windows versions) and click on "C-evo-x" in the list.  Alternately, you
can run the following command:

    msiexec /x tmp\C-evo-x.msi

#### Signed Installer

Optionally, if you have a [Microsoft Authenticode code signing certificate][42],
you can create a signed MSI installer.  The `signed-installer` make target will
build and sign the MSI installer, which is located at `tmp\C-evo-x-1.2.2.msi`;
the `-1.2.2` suffix is the version of C-evo-x being installed.

Signing requires that `signtool.exe` is available on the `PATH` of your command
prompt. This file is part of the Windows SDK and is installed in a directory
like `C:\Program Files (x86)\Microsoft SDKs\Windows\v7.0A\Bin\`.  The make file
uses a wrapper script around `signtool.exe` located at `scripts\sign_file.cmd`.
The script requires that the following environment variables be set in your
command prompt:

* `CEVOX_CERT_PATH` - the location of your code signing certificate file
* `CEVOX_CERT_PWD` - the password to your code signing certificate
* `CEVOX_TIMESTAMP_URL` - the URL for your certificate provider's time stamp
  server.

[41]: https://en.wikipedia.org/wiki/Windows_Installer
[42]: https://blogs.msdn.microsoft.com/ieinternals/2011/03/22/everything-you-need-to-know-about-authenticode-code-signing/
[43]: https://docs.microsoft.com/en-us/windows/desktop/seccrypto/signtool

### Installing and Running the Game

To install C-evo-x, run the `C-evo-x.msi` installer and follow the
instructions.  This will install C-evo-x on your system, including shortcuts
for the Start menu.  Alternately, you can play the game directly from the build
output directory `tmp\` by running `CevoDotNet.exe` (which supports AIs built
in .NET languages), `CevoWin32.exe` (which does not support .NET AIs) or
`Integrated.exe` (the "all-in-one" build of the game, which combines `cevo.dll`
with `CevoWin32.exe`.

### Building From the Delphi IDE

You _must_ run the `Makefile` build at least once before opening any of the
Delphi projects in the Delphi IDE.  If you do not, you may encounter errors or
warnings like the following:

* Compiler error: "Could not create output file
  '..\tmp\units\cevo\StringTables.dcu'"
    > the `tmp\` output directory structure needs to be created

* Compiler warning: "File not found: 'Res1.res'"
    > the `.rc` files need to be compiled into `.res` files

* Run error: "Could not find program, '..\tmp\CevoWin32.exe'.
    > the `CevoWin32` game loader needs to be built

* Run error: "[FILENOTFOUND]"
    > the external resource files need to be copied into place

* Alert "Error Reading Form": "Class TButtonA not found. Ignore the error and
  continue?"
    > the `CevoComponents` package needs to be built and installed in Delphi

### Delphi Debug vs Release Builds

Delphi 4 projects don't have a built-in way to distinguish between debug and
release build settings and it's not possible to override all the necessary
settings via the command line due to the command line length limit of the
`dcc32.exe` compiler.

Fortunately Delphi stores a list of compiler settings for each project in a
matching `.cfg` file, so it's possible to swap between debug and release builds
by modifying the `.cfg`.  The `Makefile` build does this in order to compile
release versions of EXEs and DLLs for the installer.  Release output is placed
in `tmp\release` (while debug and shared output goes in `tmp\`).  Compiler
settings are stored in `.debug.cfg` and `.release.cfg` files for their
respective projects.  The `Makefile` build will copy over the active
configuration to `.cfg`, and will always leave the debug version behind for
building from the IDE.  The [Delphi Programming Wiki][51] describes the details
behind this technique.

[51]: https://delphi.fandom.com/wiki/Easily_Switching_between_%22Debug%22_and_%22Release%22_Builds


## Project Structure

### The Delphi Projects

There are six Delphi projects: three projects for building the game, one for
building the standard AI, one for building the Delphi sample AI and one for
building a Delphi components package.

The core game can be built in two ways: as a single integrated executable or as
a DLL and loader.

The `Project\Integrated.dpr` project builds the game as a single integrated
executable named `Integrated.exe`.  The `Integrated.exe` executable can only
load non-.NET AIs, including Delphi and C++ AIs.

The `Project\cevo.dpr` project compiles the game code into a DLL named
`cevo.dll`.

The `Project\CevoWin32.dpr` project creates a simple `CevoWin32.exe` executable
that loads the game DLL and non-.NET AIs, including Delphi and C++ AIs.

The `StdAI\StdAI.dpr` project builds `StdAI.dll`, the standard AI opponent.

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

The `AI_Kit_C\MyAI.sln` solution and `AI_Kit_C\MyAI.vcxproj` C++ project build
the C++ sample AI into a DLL named `MyAI.dll`.

The `AI_Kit_C\HAL_source\HAL.sln` solution and
`AI_Kit_C\HAL_source\HAL.vcxproj` C++ project build the HAL AI into a DLL named
`HAL.dll`.


## More Documentation

The C-evo site [Info page][81] and [FAQ][82] contain a lot of detail about the
game and its design.  Check the C-evo-x [Docs][83] and [Dev Journal][84] for
information specific to C-evo-x.

[81]: http://www.c-evo.org/text.html
[82]: http://www.c-evo.org/faq.html
[83]: https://donmccaughey.github.io/C-evo-x/
[84]: https://donmccaughey.github.io/C-evo-x/dev-journal/


## Related

- A [Lazarus port of C-evo][91] by [Jiří Hajda][92] (_[chronos][93]_).
- A [Lazarus port of C-evo][94] by [Vasilii Novikov][95]
  (_[vasaya][96]_), last active in 2016.
- [Updated C-evo AI Template][97], a fork of Steffen's C# AI Template by
  [dougmill][98] (_[Douglas][99]_).
- [FreeCiv][100], another open source version of _Civilization_.

[91]: https://app.zdechov.net/c-evo
[92]: https://launchpad.net/~chronoscz
[93]: http://www.c-evo.org/bb/memberlist.php?mode=viewprofile&u=150
[94]: https://gitlab.com/vn971/cevo
[95]: https://diasp.de/u/vn971
[96]: http://www.c-evo.org/bb/memberlist.php?mode=viewprofile&u=134
[97]: https://github.com/dougmill/c-evo-ai-template
[98]: https://github.com/dougmill
[99]: http://www.c-evo.org/bb/memberlist.php?mode=viewprofile&u=148
[100]: http://www.freeciv.org

