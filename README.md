Here are some tools for messing with the Tecknet HyperTrak Gaming Mouse
(M009-V2) -- or as it's referred to by its OEM, the TM155.

This repository accompanies my series of blog posts about reverse-engineering
this mouse's drivers and firmware. Find it here:
https://wuffs.org/blog/mouse-adventures

All these tools are supplied under the MIT License. If you end up doing
something cool (or uncool) with this stuff, then let me know - I'd love to
know about it! There's bound to be other devices using these chips out there...

# Included Tools

## tm155-mac

A native application to control the TM155 from macOS, written using Swift and
Cocoa. Currently heavily under construction. This is my first time using Swift
and my first time using Cocoa, so the code's a bit junk, but it's a start!

This depends on the embeddable editing widgets provided by
[Hex Fiend](https://github.com/ridiculousfish/HexFiend/)'s framework.

## Firmware Patches

I've put together some patches to the TM155 firmware to fix bugs.
See the [patches.md](patches.md) file for details on these.

## mtp-extractor

This tool is written in C++ and uses the library provided as part of Holtek
I3000 to extract the code and data from a MTP file (a package produced by the
Holtek build tools ready for flashing to a Holtek microcontroller). Alas, for
this reason, it's Windows-only.

To compile and run it, you'll need the files located inside `ISPDLL/x86` after
installing I3000. Tested with Visual C++ 2017. Compile and run as follows:

    > cl mtp-extractor.cpp ISPDLL.lib
	> mtp-extractor M009-V2.mtp

To get your filthy paws on the MTP file, you'll need to install the TeckNet
drivers, grab your tool of choice for messing with Windows resources (I used
Resource Hacker) and open up `Update/x86/FwUpdate.exe`. There is one resource
inside the 'MTP' group. This is the one.

## ht68-disasm

This tool is written in Python 3. It takes the `program.bin` file output by
mtp-extractor and turns it into vaguely-readable assembly. Not quite IDA, but
it's better than nothing!

To run it, you'll need to install the parsec module from PyPI and you'll need
to place a couple of files from the HT-IDE3000 install package into a
`vendor-data` subfolder:

- **HT68FB560.fmt**: found in the MCU subfolder
- **HT68FB560.inc**: found in the Include subfolder

Then, invoke it as follows:

    $ python ht68-disasm.py HT68FB560 program.bin > program.asm

## ht68fb560.py for IDA

This is an IDAPython processor module that lets you disassemble and analyse
this mouse's firmware with... relative ease, I should probably say.

Place the `ht68fb560.py` and `ht68fb560.json` files from the `ida-module`
directory into the following location:

- Windows: `%APPDATA%/Hex-Rays/IDA Pro/procs`
- Linux, Mac: `~/.idapro/procs`

Developed for and tested with IDA 7.0.

# Proprietary Downloads

You can obtain these packages from the following locations:

- **HT-IDE3000***: http://www.holtek.com/ice-software
- **I3000**: http://www.holtek.com/programmer-software
- **TeckNet M009-V2 Drivers**: http://www.tecknet.co.uk/support/m009-v2.html
