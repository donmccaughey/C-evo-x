# C-evo-x

C-evo-x is a fork of [C-evo][11] 1.2.0, a freeware empire building game by
[Steffen Gerlach][12].

[11]: http://c-evo.org
[12]: http://www.steffengerlach.de


## License

C-evo and C-evo-x are in the public domain.


## Building

The main C-evo-x source is located in the `Project\` directory.  Borland Delphi
4.0 or later is required to build the game.  The `Integrated.dpr` file is the
Delphi project that builds the game as a single executable named
`Integrated.exe`.

Alternately, the `CevoWin32.dpr` and `cevo.dpr` projects build the
`CevoWin32.exe` and `cevo.dll` files respectively; the executable loads and
runs the game code located in the DLL.

External graphic, sound and text configuration files are located in the
`Resources\` directory.

The `Makefile` uses the Borland Make command supplied with Delphi 4.0 to build
`CevoWin32.exe` and `cevo.dll` from the command line and also copies all
resources from the `Resources\` directory.  The build output is placed in the
`tmp\` output directory.

Note that build steps for the standard AI files are currently missing.


## Related

[vn917/cevo][31], a fork of C-evo by [Vasilii Novikov][32].

[31]: https://gitlab.com/vn971/cevo
[32]: https://diasp.de/u/vn971

