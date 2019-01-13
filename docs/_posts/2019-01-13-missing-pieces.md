---
layout: post
title: "Missing Pieces"
---

Getting started with the [C-evo source code][11] was an exercise in [yak
shaving][12].  Step one: download the source.  Step two: find a copy of Delphi 4.
That turned out to be easy; the [WinWorld software archive][13] has a great
collection of old software, including [Delphi 4][14].

[11]: http://c-evo.org/files/download.php?cevosrc.cevosrc.zip
[12]: https://en.wiktionary.org/wiki/yak_shaving
[13]: https://winworldpc.com/home
[14]: https://winworldpc.com/product/delphi/4x

Step three: build the Delphi code.  The build fails with an error: "Could not
create output file".  Fortunately I've found [Vasilii's][21] and [Jiří's][22]
C-evo forks.  By reading through their early commits, I figure out that the
`.dof` files have absolute paths in them.  After some poking around in Delphi,
[I figure out][23] where the output directories are specified in the project
options.  Let's put all build output into a `tmp\` directory.

[21]: https://gitlab.com/vn971/cevo
[22]: https://launchpad.net/c-evo
[23]: https://github.com/donmccaughey/C-evo-x/commit/7d9cdd83f3ee82f65639b7bec5d013fb0c3bbd2f

Step four: begin build automation.  It turns out that Delphi 4 can't create the
output directories you specify if they don't exist.  Most developers in that
era just built into the source tree, but I hate doing that.  Fortunately for
me, Delphi ships with Borland's version of `make`, so [`Makefile`][31] to the
rescue.  Also, the Delphi compiler is perfectly happy to build a whole project
if you give it a `.dpr` file.  I like being able to do everything from the
command line.

[31]: https://github.com/donmccaughey/C-evo-x/blob/master/Makefile

Step five: run the game.  Now I'm seeing lots of alert boxes with the message
_"[FILENOTFOUND]"_ followed by _"Runtime error 216 at 00002F28"_ and ending
with an _"Application Error"_ alert.  Looking around the source files, I can't
find any graphics or sound files.  This stumped me for a while.  I can see
where commits in Vasilii's and Jiří's repos where the resource files are added,
but no mention of where they came from.  I look through the C-evo site, but
nothing on the _Files_ page or elsewhere.  Finally it dawns on me: all the
graphics and sound files are installed with the game.  I look in `C:\Program
Files (x86)\C-evo\` and find them all.

I copy the resource files into corresponding location in the build output
directory and now I can build from source and play the game.  Cool!  I add a
`Resources\` directory to the `C-evo-x` project, add the binary files and write
out about 100 new targets in the `Makefile` to copy each file into the build
output directory.  This is tedious but once it's done, `make` will always do
the right thing.

Now I'm down to two missing pieces: there's no project to build the installer,
and I can't find the source code for `StdAI.dll`.

