---
title: "Registry Keys"
---

# Registry Keys

Here are the various registry keys used by C-evo and C-evo-x.

## C-evo-x 1.2.1

Note that the keys under `HKEY_CLASSES_ROOT` are written by C-evo on start
by the procedure `TStartDlg.FormCreate()` in `Start.pas`.  The code contains
the comment

    // register file type: "C-evo-xBook" -- fails with no administrator rights!

These keys are missing when running C-evo-x on Windows 10.

### `HKEY_CLASSES_ROOT\.c-evo-x`

- (Default): string, default = "C-evo-xBook"

### `HKEY_CLASSES_ROOT\C-evo-xBook`

- (Default): string, default = "C-evo-x Book"

### `HKEY_CLASSES_ROOT\C-evo-xBook\DefaultIcon`

- (Default): string, default = "<path to executable>,0"

### `HKEY_CLASSES_ROOT\C-evo-xBook\shell\open\command`

- (Default): string, default = '<path to executable> "%1"'

### `HKEY_CURRENT_USER\Software\C-evo-x\Config`

- `CityReport`: integer

- `Gamma`: integer, default = 100

- `MapOptionChecked`: integer

- `OptionChecked`: integer

- `ResolutionX`: integer

The horizontal screen resolution when `ScreenMode` = 2.  Corresponds to the
`dmPelsWidth` field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionY`: integer

The vertical screen resolution when `ScreenMode` = 2.  Corresponds to the
`dmPelsHeight` field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionBPP`: integer

The bits per pixel when `ScreenMode` = 2.  Corresponds to the `dmBitsPerPels`
field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionFreq`: integer

The vertical refresh rate when `ScreenMode` = 2.  Corresponds to the
`dmDisplayFrequency` field in the `TDeviceMode` record / [`DEVMODE`
structure][1].

- `ScreenMode`: integer, default = 1

Valid values are 0 (run in window), 1 (full screen, keep system's video mode)
and 2 (full screen, change resolution).

- `TileWidth`: integer

- `TileHeight`: integer

### `HKEY_CURRENT_USER\Software\C-evo-x\Config\Start`

- `AutoDiff`: integer

- `AutoEnemies`: integer

- `Control0`: string, default = ":StdIntf"

- `Control1` thru `Control8`: string, default = "StdAI"

- `DefaultAI`: string

- `Diff0` thru `Diff8`: integer, default = 2

- `GameCount`: integer, default = 0

- `LandMass`: integer

- `MapCount`: integer, default = 0

- `MaxTurn`: integer

- `MultiControl`: integer, default = 0

- `WorldSize`: integer


## C-evo 1.2.0

Note that the keys under `HKEY_CLASSES_ROOT` are written by C-evo on start
by the procedure `TStartDlg.FormCreate()` in `Start.pas`.  The code contains
the comment

    // register file type: "cevo Book" -- fails with no administrator rights!

These keys are missing when running C-evo on Windows 10.

### `HKEY_CLASSES_ROOT\.cevo`

- (Default): string, default = "cevoBook"

### `HKEY_CLASSES_ROOT\cevoBook`

- (Default): string, default = "cevo Book"

### `HKEY_CLASSES_ROOT\cevoBook\DefaultIcon`

- (Default): string, default = "<path to executable>,0"

### `HKEY_CLASSES_ROOT\cevoBook\shell\open\command`

- (Default): string, default = '<path to executable> "%1"'

### `HKEY_CURRENT_USER\Software\cevo\RegVer9`

- `CityReport`: integer

- `Gamma`: integer, default = 100

- `MapOptionChecked`: integer

- `OptionChecked`: integer

- `ResolutionX`: integer

The horizontal screen resolution when `ScreenMode` = 2.  Corresponds to the
`dmPelsWidth` field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionY`: integer

The vertical screen resolution when `ScreenMode` = 2.  Corresponds to the
`dmPelsHeight` field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionBPP`: integer

The bits per pixel when `ScreenMode` = 2.  Corresponds to the `dmBitsPerPels`
field in the `TDeviceMode` record / [`DEVMODE` structure][1].

- `ResolutionFreq`: integer

The vertical refresh rate when `ScreenMode` = 2.  Corresponds to the
`dmDisplayFrequency` field in the `TDeviceMode` record / [`DEVMODE`
structure][1].

- `ScreenMode`: integer, default = 1

Valid values are 0 (run in window), 1 (full screen, keep system's video mode)
and 2 (full screen, change resolution).

- `TileWidth`: integer

- `TileHeight`: integer

### `HKEY_CURRENT_USER\Software\cevo\RegVer9\Start`

- `AutoDiff`: integer

- `AutoEnemies`: integer

- `Control0`: string, default = ":StdIntf"

- `Control1` thru `Control8`: string, default = "StdAI"

- `DefaultAI`: string

- `Diff0` thru `Diff8`: integer, default = 2

- `GameCount`: integer, default = 0

- `LandMass`: integer

- `MapCount`: integer, default = 0

- `MaxTurn`: integer

- `MultiControl`: integer, default = 0

- `WorldSize`: integer

[1]: https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-devmodea

