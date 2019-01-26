---
layout: post
title: "C-evo-x Goals"
---

I have some specific short term goals for the C-evo-x project.  Medium and long
term goals are naturally broader and fuzzier.

## Short Term

Currently, the C-evo source code that's available from the [C-evo site][11]
isn't complete and can't be built as-is.  The first task of C-evo-x is to
gather together all the pieces in one place and make them buildable "out of the
box" for anyone who clones the C-evo-x repo or downloads the source.

[11]: http://c-evo.org/files/files.php

The next job is build clean up.  Both the Delphi and C# sources produce a bunch
of compiler wornings that should be fixed.  Updating to modern versions of
Delphi and Visual C# is the next milestone.

In the short term, I'm intentionally keeping changes to the source code to a
minimum.

## Medium Term

C-evo is ["legacy code"][21] in the sense that there is no automated test
suite.  Figuring out how to add some tests to the project is high on the agenda
in the mid term.  Making the C-evo source testable will probably require some
changes to the code.

[21]: https://en.wikipedia.org/wiki/Legacy_code

Splitting up the game into separate, independently built modules is another
important part of the medium term goals.  Modularity and testing tend to be
synergistic.

Along with better code organization, there are a bunch of small UI improvements
I've long wanted to make, such as a "Go To City" command.

## Long Term

Delphi has a very small development community these days.  C# has never gained
wide acceptance outside of the Microsoft world.  I'm not a regular user of
either language and while they're both fine languages (thanks [Anders][31]!),
my personal preferences and interests lies elsewhere.

[31]: https://en.wikipedia.org/wiki/Anders_Hejlsberg

Rebuilding C-evo in a more widely used language with a vibrant development
community is the final broad goal.  Right now, the choices that seem practical
to me are C, C++ or Rust.  Any of these three would make the core game engine
portable to Linux, macOS and iOS.  But that decision is still a ways off.


