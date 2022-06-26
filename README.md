# What is this?

This is a [QB64](https://github.com/QB64-Phoenix-Edition/QB64pe) compatible simplified library based on [Libxmp](https://github.com/libxmp/libxmp). [Libxmp](https://github.com/libxmp/libxmp) is a library that renders [module files](https://en.wikipedia.org/wiki/Module_file) to PCM data. It supports over 90 mainstream and obscure module formats including [Protracker (MOD)](https://en.wikipedia.org/wiki/MOD_(file_format)), [Scream Tracker 3 (S3M)](https://en.wikipedia.org/wiki/S3M_(file_format)), [Fast Tracker II (XM)](https://en.wikipedia.org/wiki/XM_(file_format)), and [Impulse Tracker (IT)](https://en.wikipedia.org/wiki/Impulse_Tracker#IT_file_format).

This is also loosely based on a [similar library](https://qb64phoenix.com/forum/showthread.php?tid=29) by [RhoSigma](https://github.com/RhoSigma-QB64).

![Screenshot](screenshots/screenshot1.png)
![Screenshot](screenshots/screenshot2.png)

## Features

- Easy plug-&-play API optimized for demos & games
- Works with the 64-bit QB64 complier (unlike RhoSigma's library that is 32-bit only)
- Lixmp is statically linked to the complied executable (no DLL dependency)
- Demo player that shows how to use the library

## API

```VB
Function XMPLoadFile%% (sFileName As String)
Sub XMPStartPlayer
Sub XMPUpdatePlayer
Sub XMPStopPlayer
Function XMPGetVolume%
Sub XMPSetVolume (nVolume As Integer)
```
