Here are some tools for messing with the Tecknet HyperTrak Gaming Mouse
(M009-V2) -- or as it's referred to by its OEM, the TM155.

This repository accompanies my series of blog posts about reverse-engineering
this mouse's drivers and firmware. Find it here:
https://wuffs.org/blog/mouse-adventures

# Included Tools

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

# Proprietary Downloads

You can obtain these packages from the following locations:

- **HT-IDE3000***: http://www.holtek.com/ice-software
- **I3000**: http://www.holtek.com/programmer-software
- **TeckNet M009-V2 Drivers**: http://www.tecknet.co.uk/support/m009-v2.html
