#include <stdio.h>
#include <stdint.h>
#include <Windows.h>
#include "ISPDLL.h"

void writeBufferToFile(const char *name, const void *buf, long size) {
	FILE *f = fopen(name, "wb");
	if (f) {
		fwrite(buf, 1, size, f);
		fclose(f);
	} else {
		printf("<!> could not open '%s' for writing\n", name);
	}
}

int main(int argc, char **argv) {
	if (argc != 2) {
		printf("Error: no MTP file specified\n");
		printf("Usage: %s stuff.mtp\n", argv[0]);
		return 0;
	}

	PBYTE programBuf, optionBuf, dataBuf;
	WORD programSize, optionSize, dataSize;

	int result = LoadFile(argv[1], programBuf, programSize, optionBuf, optionSize, dataBuf, dataSize);
	printf("Result: %d\n", result);
	printf("ProgramSize: %d\n", programSize);
	printf("OptionSize: %d\n", optionSize);
	printf("DataSize: %d\n", dataSize);

	writeBufferToFile("program.bin", programBuf, programSize * 2);
	writeBufferToFile("option.bin", optionBuf, optionSize * 2);
	writeBufferToFile("data.bin", dataBuf, dataSize * 2);

	MCUINFO m;
	m.cbSize = sizeof(m);
	GetMCUInfo(&m);
	printf("MCU:%s PageSize:%d MaxProgramPage:%d MaxLockPage:%d BootloaderSize:%d\n", m.szMcuName, m.nPageSize, m.nMaxProgramPage, m.nMaxLockPage, m.nBootloaderSize);

	return 0;
}


