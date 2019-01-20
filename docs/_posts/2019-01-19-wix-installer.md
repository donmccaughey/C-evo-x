---
layout: post
title: "WiX Installer"
---

Poking around in the `C-evo\` program directory, I can see by peeking inside
the `unins000.dat` file that the C-evo installer was built with [Inno
Setup][11], which is open source and still seems to be going strong.
Unfortunately, the Inno Setup project isn't included with the C-evo source.

[11]: http://www.jrsoftware.org/isinfo.php

Building a basic installer is a modest amount of work. Half the trouble is
figuring out what files to include and where they need to go; I already know
that for C-evo-x.  A quick search of the internet shows that [MSI][21]
installers seem to be the current mainstream choice.  Microsoft doesn't provide
any high level tools for building MSI installers, but more searching points me
at the [WiX Toolset][22]

[21]: https://en.wikipedia.org/wiki/Windows_Installer
[22]: http://wixtoolset.org

WiX is ... _okay_.  It's got some compelling strengths.  It's open source and
command line driven.  There's a decent tutorial and comprehensive
documentation.  I was able to define and build a minimal installer in an hour
or so by following the tutorial.  Building on that was straightforward.  The
command line tools and generated installer have just worked without hiccup.
WiX really nails these core things.

But WiX has lots of warts.  Installers are defined using a custom XML
vocabulary.  Okay, I know that building DSLs in XML was in vogue in the late
90's and early 2000's, and I've worked with plenty of them over the years.  The
elements and attributes in the WiX XML schema are all in upper camel case (like
`<Component>` and `<ComponentRef>`) which is very Microsoft-ian.

Components are the core thing in WiX, typically corresponding to an installed
file.  Unfortunately, each component need to be declared as child of both a
`<Directory>` and a `<Feature>`, but the WiX DSL doesn't allow you to place
`<Directory>` elements inside `<Feature>` elements, necessitating duplication
through the use of both `<Component>` and `<ComponentRef>` elements.  This
requirement to refer to components in multiple places means every component
need to have a unique `Id` attribute, and it's the responsibility of the
programmer to make sure `Id`s are unique for all the defined components.
There's no way to fully [DRY][31] out your WiX code.

[31]: https://en.wikipedia.org/wiki/Don't_repeat_yourself

Within certain attributes, some values have special meaning.  For example, the
`Id` attribute of `<Directory>` can be set to `ProgramFilesFolder` or
`INSTALLDIR`, which represent the `C:\Program Files\` directory and the
installation directory selected by the user, respectively.  Other attributes
allow the installer to substitute values defined elsewhere, such as the `Key`
attribute for the `<RegistryValue>` element, which can be something like
`Key='Software\[Manufacturer]\[ProductName]'`.  If the WiX documentation
enumerates all these special cases, I haven't found that part yet.

Finally, a WiX installer is built in two steps, analogous to compiling and
linking.  That's easy enough, no problem there.  The WiX compiler is called
`candle.exe` and the linker is called `light.exe`.  Ancillary tools include
`lit.exe` and `heat.exe`.  Cute, but really not very helpful.

![The installer Welcome dialog](/dev-journal/2019-01-19-wix-installer-welcome.png)

But in the end, it works.

