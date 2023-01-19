# What is this?

This is a [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe) compatible simplified library based on [Libxmp](https://github.com/libxmp/libxmp). [Libxmp](https://github.com/libxmp/libxmp) is a library that renders [module files](https://en.wikipedia.org/wiki/Module_file) to PCM data. It supports over 90 mainstream and obscure module formats including [Protracker (MOD)](https://en.wikipedia.org/wiki/MOD_(file_format)), [Scream Tracker 3 (S3M)](https://en.wikipedia.org/wiki/S3M_(file_format)), [Fast Tracker II (XM)](https://en.wikipedia.org/wiki/XM_(file_format)), and [Impulse Tracker (IT)](https://en.wikipedia.org/wiki/Impulse_Tracker#IT_file_format).

This is also loosely based on a [similar library](https://qb64phoenix.com/forum/showthread.php?tid=29) by [RhoSigma](https://github.com/RhoSigma-QB64).

![Screenshot](screenshots/screenshot1.png)
![Screenshot](screenshots/screenshot2.png)
![Screenshot](screenshots/screenshot3.png)

## Features

- Easy plug-&-play API optimized for demos & games
- Works with the 64-bit QB64 complier (unlike RhoSigma's library that is 32-bit only)
- Libxmp can be statically linked to the complied executable (no DLL dependency)
- Links to libxmp.dll on Windows. Use `$Let LIBXMP_STATIC = TRUE` before including `LibXMPLite.bi` to avoid
- Using the DLL, bypasses the QB64-PE's built-in libxmp-lite
- Demo player that shows how to use the library

## API

```VB
Function XMPFileLoad%% (sFileName As String)
Sub XMPPlayerStart
Sub XMPPlayerStop
Sub XMPPlayerRestart
Sub XMPPlayerNextPosition
Sub XMPPlayerPreviousPosition
Sub XMPPlayerSetPosition (nPosition As Long)
Sub XMPPlayerSeekTime (nTime As Long)
Sub XMPPlayerUpdate
Sub XMPPlayerVolume (nVolume As Long)
Function XMPPlayerVolume&
```

## Important note

- This uses new features introduced in [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases) and as such may not work correctly or reliably with QB64.

- IT, XM, S3M & MOD support is built into [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/). The [miniaudio](https://miniaud.io/) backend in OB64-PE uses [Libxmp-lite](https://github.com/libxmp/libxmp/tree/master/lite). So, this is not technically not required. Using it anyway will cause the library to link against QB64-PE's built-in `libxmp-lite`. To work around this, use `libxmp.dll` instead. See [this](https://github.com/a740g/QB64-LibXMPLite/blob/main/XMPlayer.bas#L9).
