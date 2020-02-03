---
title: "Resource Files"
---

# Resource Files

    > C-evo 1.2.0, C-evo-x 1.2.1 - 1.2.2

There are a small number of _internal_ resource files and around 100 _external_
resource files.  The internal resources are icons and cursors that are compiled
into the game's executable and/or DLL.  The external resources are installed
with the game and loaded from the filesystem when the game needs them.

## Internal Resources

`Project\cevoxp2.ico` is the icon used by the `CevoWin32.exe` and
`CevoDotNet.exe` game loaders and by the `Integrated.exe` stand-alone game
executable.  The `Project\cevo.rc` resource compiler file references the icon
and the compiled `cevo.res` is linked into the game loaders and stand-alone
game executable.

`Project\drag.cur` and `Project\flathand.cur` are custom cursors used by the
`cevo.dll` game library and the `Integrated.exe` stand-alone game executable.
The `Project\Res1.rc` resource compiler file references the cursors and the
compiled `Res1.res` file is linked into the game DLL and the stand-anone game
executable.  The cursors _are_ referenced in the source, but I don't ever
recall seeing the cursors when playing the game, so I'm unsure if they're
actually needed.

## External Resources

The game installs about 100 external resource files, which fall into a few
distinct categories: AI files, localizations, graphics, help, sounds and
tribes.  All the files on this list are installed with the game and are
referenced in the source.

The game has different search strategies for different resource file
categories, but only looks in two places: `HomeDir` and `DataDir`.  The
`Directories.pas` file defines these two variables and initializes them.

The `HomeDir` variable is initialized to the directory part of `ParamStr(0)`
(e.g. `argv[0]` in the C world, the path of the executable).

The `DataDir` variable is initialized to the user's app data directory as given
by `GetSpecialDirectory(CSIDL_APPDATA)`, plus `C-evo` (e.g. `C:\Documents and
Settings\username\Application Data\C-evo`).  If the user's app data directory is
missing, `DataDir` defaults to `HomeDir`.

On start, the game will create `${DataDir}\Saved` and `${DataDir}\Maps`
directories and copy any sample games from `${HomeDir}\AppData\Saved\*.cevo` to
`${DataDir}\Saved\`.

### AI Files

The game will look for files that match `${HomeDir}\*.ai.txt` when loading AIs.
The `*.ai.txt` file specifies the path to the corresponding DLL.

### Localizations

User interface strings are stored in two files: `Language.txt` and
`Language2.txt`.  In addition, the `Fonts.txt` controls which fonts are used,
which might need to be changed to support different character sets.

The game looks first in `${DataDir}\Localization\` for these three files, then
defaults to `${HomeDir}`.

    ${DataDir}\Localization\Fonts.txt     | ${HomeDir}\Fonts.txt
    ${DataDir}\Localization\Language.txt  | ${HomeDir}\Language.txt
    ${DataDir}\Localization\Language2.txt | ${HomeDir}\Language2.txt

The game installs the English localization by default into `HomeDir`.

### Graphics

All the graphics files are loaded from `${HomeDir}\Graphics` but the game has
logic to look for either JPEG or Windows bitmap files.

    ${HomeDir}\Graphics\Background.jpg   | ${HomeDir}\Graphics\Background.bmp
    ${HomeDir}\Graphics\BigCityMap.jpg   | ${HomeDir}\Graphics\BigCityMap.bmp
    ${HomeDir}\Graphics\Cities66x32.jpg  | ${HomeDir}\Graphics\Cities66x32.bmp
    ${HomeDir}\Graphics\Cities96x48.jpg  | ${HomeDir}\Graphics\Cities96x48.bmp
    ${HomeDir}\Graphics\City.jpg         | ${HomeDir}\Graphics\City.bmp
    ${HomeDir}\Graphics\Colors.jpg       | ${HomeDir}\Graphics\Colors.bmp
    ${HomeDir}\Graphics\Icons.jpg        | ${HomeDir}\Graphics\Icons.bmp
    ${HomeDir}\Graphics\MiliRes.jpg      | ${HomeDir}\Graphics\MiliRes.bmp
    ${HomeDir}\Graphics\Nation.jpg       | ${HomeDir}\Graphics\Nation.bmp
    ${HomeDir}\Graphics\Nation1.jpg      | ${HomeDir}\Graphics\Nation1.bmp
    ${HomeDir}\Graphics\Nation2.jpg      | ${HomeDir}\Graphics\Nation2.bmp
    ${HomeDir}\Graphics\Paper.jpg        | ${HomeDir}\Graphics\Paper.bmp
    ${HomeDir}\Graphics\SmallCityMap.jpg | ${HomeDir}\Graphics\SmallCityMap.bmp
    ${HomeDir}\Graphics\StdCities.jpg    | ${HomeDir}\Graphics\StdCities.bmp
    ${HomeDir}\Graphics\StdUnits.jpg     | ${HomeDir}\Graphics\StdUnits.bmp
    ${HomeDir}\Graphics\System.jpg       | ${HomeDir}\Graphics\System.bmp
    ${HomeDir}\Graphics\System2.jpg      | ${HomeDir}\Graphics\System2.bmp
    ${HomeDir}\Graphics\Templates.jpg    | ${HomeDir}\Graphics\Templates.bmp
    ${HomeDir}\Graphics\Terrain66x32.jpg | ${HomeDir}\Graphics\Terrain66x32.bmp
    ${HomeDir}\Graphics\Terrain96x48.jpg | ${HomeDir}\Graphics\Terrain96x48.bmp
    ${HomeDir}\Graphics\Texture0.jpg     | ${HomeDir}\Graphics\Texture0.bmp
    ${HomeDir}\Graphics\Texture1.jpg     | ${HomeDir}\Graphics\Texture1.bmp
    ${HomeDir}\Graphics\Texture2.jpg     | ${HomeDir}\Graphics\Texture2.bmp
    ${HomeDir}\Graphics\Texture3.jpg     | ${HomeDir}\Graphics\Texture3.bmp
    ${HomeDir}\Graphics\Texture4.jpg     | ${HomeDir}\Graphics\Texture4.bmp
    ${HomeDir}\Graphics\Unit.jpg         | ${HomeDir}\Graphics\Unit.bmp

The game only provides the bitmap version of graphics files.

The game can display maps at two resolutions: 66x32 and 96x48.  The
`Cities66x32.bmp` and `Terrain66x32.bmp` files are used for the lower resolution
and `Cities96x48.bmp` and `Terrain96x48.bmp` are for the higher resolution.

The five texture files `Texture0.bmp` through `Texture4.bmp` are used to change
the game UI for each of the five ages of advancement.

### Help

The help text can also be localized, so the game will look in the following
locations:

    ${DataDir}\Localization\Help\help.txt | ${HomeDir}\Help\help.txt

The game ships with the English version of the help text, stored in `HomeDir`.
The graphics embedded in the help can be overridden with JPEG versions, though
only Windows bitmaps are included with the game.  The graphic for the advances
tree is local independent.

    ${HomeDir}\Help\AdvTree.jpg | ${HomeDir}\Help\AdvTree.bmp

The other help graphics are localizable; the game will check for localized and
default JPEG and bitmap versions.

    ${DataDir}\Localization\AITShot.jpg    | ${DataDir}\Localization\AITShot.bmp    | ${HomeDir}\AITShot.jpg    | ${HomeDir}\AITShot.bmp
    ${DataDir}\Localization\CityShot.jpg   | ${DataDir}\Localization\CityShot.bmp   | ${HomeDir}\CityShot.jpg   | ${HomeDir}\CityShot.bmp
    ${DataDir}\Localization\CORRUPTION.jpg | ${DataDir}\Localization\CORRUPTION.bmp | ${HomeDir}\CORRUPTION.jpg | ${HomeDir}\CORRUPTION.bmp
    ${DataDir}\Localization\DraftShot.jpg  | ${DataDir}\Localization\DraftShot.bmp  | ${HomeDir}\DraftShot.jpg  | ${HomeDir}\DraftShot.bmp
    ${DataDir}\Localization\MoveShot.jpg   | ${DataDir}\Localization\MoveShot.bmp   | ${HomeDir}\MoveShot.jpg   | ${HomeDir}\MoveShot.bmp

### Sounds

The sound files are always loaded directly from the `${HomeDir}\Sounds`
directory.

    ${HomeDir}\Sounds\sound.txt
    ${HomeDir}\Sounds\sound.credits.txt

    ${HomeDir}\Sounds\8MM_AT_C-BlackCow-8186_hifi.mp3
    ${HomeDir}\Sounds\Boulder_-oblius-7747_hifi.mp3
    ${HomeDir}\Sounds\Cash_reg-public_d-296_hifi.mp3
    ${HomeDir}\Sounds\Hammer_o-Public_D-243_hifi.mp3
    ${HomeDir}\Sounds\sg_angry.mp3
    ${HomeDir}\Sounds\sg_autogun.mp3
    ${HomeDir}\Sounds\sg_battery.mp3
    ${HomeDir}\Sounds\sg_cavalry.mp3
    ${HomeDir}\Sounds\sg_cheers.mp3
    ${HomeDir}\Sounds\sg_crash.mp3
    ${HomeDir}\Sounds\sg_drum.mp3
    ${HomeDir}\Sounds\sg_drum2.mp3
    ${HomeDir}\Sounds\sg_fanfare.mp3
    ${HomeDir}\Sounds\sg_gain.mp3
    ${HomeDir}\Sounds\sg_harp.mp3
    ${HomeDir}\Sounds\sg_horsemen.mp3
    ${HomeDir}\Sounds\sg_invent.mp3
    ${HomeDir}\Sounds\sg_jet.mp3
    ${HomeDir}\Sounds\sg_marching.mp3
    ${HomeDir}\Sounds\sg_mechanical.mp3
    ${HomeDir}\Sounds\sg_militia.mp3
    ${HomeDir}\Sounds\sg_moan.mp3
    ${HomeDir}\Sounds\sg_musketeers.mp3
    ${HomeDir}\Sounds\sg_nono.mp3
    ${HomeDir}\Sounds\sg_plane.mp3
    ${HomeDir}\Sounds\sg_sad.mp3
    ${HomeDir}\Sounds\sg_space.mp3
    ${HomeDir}\Sounds\sg_steal.mp3
    ${HomeDir}\Sounds\sg_warning.mp3
    ${HomeDir}\Sounds\sizzle-Sith_Mas-7716_hifi.mp3
    ${HomeDir}\Sounds\Small_Sw-Public_D-262_hifi.mp3
    ${HomeDir}\Sounds\victory.mp3

The `sound.txt` file maps sound files to game events.  The `sound.credits.txt`
contains authorship information about each sound file.

### Tribes

The `*.tribe.txt` files define the available nations in the game.  These files
are localizable like the help and language files.

    ${DataDir}\Localization\Tribes\StdUnits.txt          | ${HomeDir}\Tribes\StdUnits.txt

    ${DataDir}\Localization\Tribes\Americans.tribe.txt   | ${HomeDir}\Tribes\Americans.tribe.txt
    ${DataDir}\Localization\Tribes\Babyl.tribe.txt       | ${HomeDir}\Tribes\Babyl.tribe.txt
    ${DataDir}\Localization\Tribes\British.tribe.txt     | ${HomeDir}\Tribes\British.tribe.txt
    ${DataDir}\Localization\Tribes\Chinese.tribe.txt     | ${HomeDir}\Tribes\Chinese.tribe.txt
    ${DataDir}\Localization\Tribes\Egyptians.tribe.txt   | ${HomeDir}\Tribes\Egyptians.tribe.txt
    ${DataDir}\Localization\Tribes\French.tribe.txt      | ${HomeDir}\Tribes\French.tribe.txt
    ${DataDir}\Localization\Tribes\Germans.tribe.txt     | ${HomeDir}\Tribes\Germans.tribe.txt
    ${DataDir}\Localization\Tribes\Japanese.tribe.txt    | ${HomeDir}\Tribes\Japanese.tribe.txt
    ${DataDir}\Localization\Tribes\Mongols.tribe.txt     | ${HomeDir}\Tribes\Mongols.tribe.txt
    ${DataDir}\Localization\Tribes\Persians.tribe.txt    | ${HomeDir}\Tribes\Persians.tribe.txt
    ${DataDir}\Localization\Tribes\Phoenicians.tribe.txt | ${HomeDir}\Tribes\Phoenicians.tribe.txt
    ${DataDir}\Localization\Tribes\Romans.tribe.txt      | ${HomeDir}\Tribes\Romans.tribe.txt
    ${DataDir}\Localization\Tribes\Russians.tribe.txt    | ${HomeDir}\Tribes\Russians.tribe.txt
    ${DataDir}\Localization\Tribes\Spanish.tribe.txt     | ${HomeDir}\Tribes\Spanish.tribe.txt
    ${DataDir}\Localization\Tribes\Vikings.tribe.txt     | ${HomeDir}\Tribes\Vikings.tribe.txt

The `StdUnits.txt` file contains unit definitions that are shared by all
nations.  The game ships with the English language versions of these files
installed in `HomeDir\Tribes`.

