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

## Right pointing triangles

This is used on the first tab of the start dialog to call out the `cevo.org`
website.

    (1, 400) to (92, 425) [91 wide, 25 tall]

## Icon for game window menu

This is the C-evo / C-evo-x icon for the game menu in the upper left corner of
the game window menu.

    (145, 38) to (181, 74) [36 wide, 36 tall] 

## Treasury icon 

This is the icon for the payment option in diplomatic negotiations.

    (145, 1) to (181, 37) [36 wide, 36 tall]

## Refresh icon

This is overlaid on the end turn button.

    (124, 1) to (138, 15) [14 wide, 14 tall]

## Research icon

    (145, 75) to (181, 111) [36 wide, 36 tall]

## Starship departed

    (1, 279) to (141, 399) [140 wide, 120 tall]

## Ground unit icon

    (142, 246) to (178, 282) [36 wide, 36 tall]

## Sea unit icon

    (142, 283) to (178, 319) [36 wide, 36 tall]

## Air unit icon

    (142, 320) to (178, 356) [36 wide, 36 tall]

## Weight icon, selected

    (123, 400) to (141, 420) [18 wide, 20 tall]

## Weight icon, unselected

    (105, 400) to (123, 420) [18 wide, 20 tall]

