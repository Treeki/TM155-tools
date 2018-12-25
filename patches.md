# TeckNet M009-V2 Firmware Patches

## Introduction

The M009-V2's firmware can be (relatively) easily reflashed using the
`FwUpdate.exe` tool supplied with TeckNet's Windows drivers.

You can extract the MTP file containing the firmware from the `FwUpdate.exe`
file's resources using your favourite Windows resource editing tool of choice.
After editing it, simply reinsert it and rerun the flashing tool. It
calculates a checksum, but you don't need to worry about that - it will go
ahead and flash just fine.

## Caveats

While I'm relatively confident that these techniques work, and I've been able
to pull them off on my own devices, I can't guarantee that this will work for
you. It might damage your mouse. Please be aware of the risks. Flash safely.

## DPI-based Lighting Patch

The official configuration tool for the M009-V2 allows you to choose between
"Standard", "Respiration" and "Neon" lighting modes, with no further
explanation. It also lets you pick a different colour for each DPI setting.

The intention appears to be that "Standard" and "Respiration" will display
the colour chosen for the active DPI stage (at a specified brightness for
"Standard" and fading in/out for "Respiration"), but in practice this doesn't
work properly.

The mouse chooses the colour to display based off the active DPI stage
whenever it reloads its lighting settings (e.g. after a configuration change),
but it doesn't change when you select a new DPI. This pretty much defeats
the entire point of having DPI-based lighting settings.

This patch fixes it by reloading the colour whenever the selected DPI
stage changes.

### Patch Data

The first portion simply replaces one call instruction in order to jump
to a new code region:

- Memory Address: 0xBE
- File Offset: 0x1EC
- Preceding Bytes: `E9 2A 91 78 BF 28 91 74`
- Original: `07 67` - `call updateDPIStageIndicator@F07`
- Patched: `F1 E1` - `call 19F1`

The second portion replaces some empty space after the USB string descriptors
with the code that performs the replacement:

- Memory Address: 0x19F1
- File Offset: 0x3452
- Preceding Bytes: `03 0E 86 03 05 09 0A 09 19 09 32 09`
- Original: ... a lot of zeroes
- Patched: `C8 7C 07 6F 89 0F 9E 67 03 0A 85 10 07 6F 08 66 07 6F`

### Disassembly

    sz intLMVar1                 ; check whether a light mode that allows
	                             ; DPI-based lighting is active
	jmp updateDPIStageIndicator  ; no? then continue with the original code

	mov A, 89h                   ; request the lighting sub-mode variable
	call ReadFromBank2           ; read a byte from bank 2 offset 89h into A

	sub A, 3                     ; A <- A - 3
	sz ACC                       ; if the result is non-zero (sub-mode != 3)
	jmp updateDPIStageIndicator  ; then we're not using DPI-based lighting

	; if we got here, we need to reload the light variables
	; call the original code that does this at address 0E08 in flash
	call lparam2_03_loadCyclingColBasedOffDpiStage
	jmp updateDPIStageIndicator  ; finally go back


