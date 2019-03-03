---
title: "Versions"
---

# Versions

Here's a list of C-evo-x versions and the file property details for key files.

## C-evo-x 1.2.1

This is the current, unreleased version.

* File `C-evo-x.msi`
    - Title: "Installation Database"
    - Subject: "C-evo-x 1.2.1 Installer"
    - Categories: ""
    - Tags: "Installer"
    - Authors: "Don McCaughey"

* File `CevoWin32.exe`
    - File description: "C-evo-x Win32 Loader"
    - File version: "1.2.1.0"
    - Product name: "C-evo-x"
    - Product version: "1.2.1.0"
    - Copyright: "In the public domain"
    - Language: "Language Neutral"

* File `cevo.dll`
    - File description: "C-evo-x Game Engine"
    - File version: "1.2.1.0"
    - Product name: "C-evo-x"
    - Product version: "1.2.1.0"
    - Copyright: "In the public domain"
    - Language: "Language Neutral"

* File `StdAI.dll`
    - File description: "C-evo-x Standard AI"
    - File version: "1.2.1.0"
    - Product name: "C-evo-x"
    - Product version: "1.2.1.0"
    - Copyright: "In the public domain"
    - Language: "Language Neutral"

* File `CevoDotNet.exe`
    - File description: "C-evo-x .NET Loader"
    - File version: "1.2.1.0"
    - Product name: "C-evo-x"
    - Product version: "1.2.1.0"
    - Copyright: "In the public domain"
    - Language: "Language Neutral"

* File `Configurator.exe`
    - File description: "C-evo-x Configurator"
    - File version: "1.2.1.0"
    - Product name: "C-evo-x"
    - Product version: "1.2.1.0"
    - Copyright: "In the public domain"
    - Language: "Language Neutral"


## C-evo 1.2.0

[C-evo 1.2.0][120] was released on 6 April 2013.

[120]: http://www.c-evo.org/files/download.php

Version resources are missing in from native executables and DLLs in C-evo 1.2.0
and set to defaults in .NET executables, which accounts for the values being
largely blank.

* File `cevosetup.exe`
    - File description: "C-evo Setup"
    - File version: "0.0.0.0"
    - Product name: "C-evo"
    - Product version: "1.2.0"
    - Copyright: ""
    - Language: "Language Neutral"

* File `CevoWin32.exe`
    - File description: ""
    - File version: ""
    - Product name: ""
    - Product version: ""
    - Copyright: ""
    - Language: ""

* File `cevo.dll`
    - File description: ""
    - File version: ""
    - Product name: ""
    - Product version: ""
    - Copyright: ""
    - Language: ""

* File `StdAI.dll`
    - File description: ""
    - File version: ""
    - Product name: ""
    - Product version: ""
    - Copyright: ""
    - Language: ""

* File `CevoDotNet.exe`
    - File description: "C-evo .Net Loader"
    - File version: "1.0.0.0"
    - Product name: "C-evo"
    - Product version: "1.0.0.0"
    - Copyright: ""
    - Language: "Language Neutral"

* File `Configurator.exe`
    - File description: "Configurator"
    - File version: "1.0.0.0"
    - Product name: "Configurator"
    - Product version: "1.0.0.0"
    - Copyright: "Copyright (C) 2013"
    - Language: "Language Neutral"


## File Properties Details

### Native Windows Resource

In the Delphi projects, file property details are specified in Windows
resource compiler `.rc` files.  Here is how properties in the File Explorer map
to the resource compiler `VERSIONINFO` statement.

Version properties are specified in the _fixed-info_ parameter as comma
separated lists of four integers like `1,2,3,4`:

    File version        FILEVERSION
    Product version     PRODUCTVERSION

Properties specified in the `"StringFileInfo"` _block_statement_ are all
explicitly null-terminated strings like `"My string info\0"`:

    File description    VALUE "FileDescription"
    File version        VALUE "FileVersion"
    Product name        VALUE "ProductName"
    Product version     VALUE "ProductVersion"
    Copyright           VALUE "LegalCopyright"

The Language property is specified in the `"VarFileInfo"` _block_statement_
using the "Translation" key, followed by numeric constants for language ID and
character set ID respectively.

    Language            VALUE "Translation"

### C# `AssemblyInfo.cs`

In the C# projects, file property details are specified in the `AssemblyInfo.cs`
file.  Here is how properties in the File Explorer map to assembly properties.

    File description    AssemblyTitle
    File version        AssemblyFileVersion
    Product name        AssemblyProduct
    Product version     AssemblyFileVersion
    Copyright           AssemblyCopyright
    Language            AssemblyCulture
    Legal Trademarks    AssemblyTrademark       (hidden if blank)

    (not visible)       AssemblyDescription
    (not visible)       AssemblyConfiguration
    (not visible)       AssemblyCompany
    (not visible)       AssemblyVersion

