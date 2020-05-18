---
title: "Templates Bitmap"
---

# Templates Bitmap

    > C-evo 1.2.0, C-evo-x 1.2.1
    > `Resources\Graphics\Templates.bmp`
    > BMP3 182x426 182x426+0+0 8-bit sRGB 233502B 0.000u 0:00.003

This file contains various images used in the user interface.  The file is
loaded by `ScreenTools.pas` into the `Templates` `TBitmap` variable.  The
following sections of the image are used:

## Icon on start dialog tab

This is the C-evo / C-evo-x icon on the leftmost tab of the start dialog.  It is
loaded in two parts, to crop out the downward pointing triangle used by the Term
window menu.

    // part 1
    (145, 38) to (181, 65) [36 wide, 27 tall]

    // part 2
    (155, 65) to (181, 74) [26 wide, 9 tall]

## Icon for game window menu

This is the C-evo / C-evo-x icon for the game menu in the upper left corner of
the game window menu.

   (145, 38) to (181, 74) [36 wide, 36 tall] 

