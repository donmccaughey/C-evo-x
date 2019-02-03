---
layout: post
title: "No Warnings: A Small Milestone"
---

I reached a small milestone yesterday with C-evo-x: all the code in the Delphi,
C# and C++ projects now compiles without warnings.

The vast majority of the warnings were related to potentially uninitialized
values.  I fixed each warning or small groups of closely related warnings in
individual commits, and I tried to silence the warning with small, targeted
changes.  Since there's no test suite, I've been "forced" to play the game to
make sure my fixes didn't have any unintended side effects.

Though warnings are benign most of the time, I've long found it beneficial to
fix them quickly, otherwise it quickly becomes impossible to spot the important
ones in all the noise.

