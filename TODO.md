# TODO

 - Installer: add publisher name for program entry in Settings | Apps &
   features.

 - On the start form, replace C-evo icon in upper left hand with C-evo-x icon.
 
 - Audit case of filenames, unit names and other file inclusions.

 - Audit unit names; unit names should match file names.

 - Audit `Project\Switches.pas` and determine if any should be removed.

 - Remove `Integrated.dpr`.

 - Determine if resources in `Res1.rc` (drag.cur, flathand.cur) are used.

 - Relocate C# `obj\` directories out of source tree, into `tmp\`.

 - Audit use of $IFDEF in the Delphi source code.

 - Include 48x48 and 256x256 resolution images in C-evo-x icon (Currently
   unsupported by the Delphi 4 resource compiler).

 - Make 8-bit and 4-bit color images for the C-evo-x icon in 16x16, 32x32 and
   48x48 resolution.

 - In `Graphics\Templates.bmp`, replace the "c-evo" graphic with "c-evo-x".

 - On the start form, add a link to `c-evo-x.org` to the help panel, below the
   `c-evo.org` link.

 - Update the Credits help file, adding C-evo-x credits.

 - In the Configurator, read the Configurator version from its version info
   instead of the constant defined in `MainForm.cs`.

 - In the Configurator, add a way to find C-evo-x releases.

 - Remove `cevoxp2.ico` from the Configurator project.

 - Centralize the location of shared assets that are currently duplicated into
   project subdirectories:
        * c-evo-x.ico
        * Protocol.pas
        * protocol.h

