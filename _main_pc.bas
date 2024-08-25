'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


#cmdline "-gen gcc" 
' -fpmode fast -fpu sse"
' -g -Wc -gstabs+ para depurar
' con -O 2 da error



#include "SDL2\SDL.BI"
#include "windows.bi"


' prefiero asi las boleanas
'#undef Bool
'  #define Bool UByte
'#undef TRUE
'  #define TRUE 1
'#undef FALSE
'  #define FALSE 0

'#include "crt\math.bi" ' ceil(), floor(), M_PI, pow(), fabs(), sqrt(), etc
#Include "crt\stdio.bi" ' printf(), scanf(), fopen(), etc
'#Include "crt\stdlib.bi" ' allocate,calloc(), etc
'#Include "crt\mem.bi" ' memset(var,val,size) -> variable ptr, valor, tamano usar sizeof(variable))
'#Include "crt\string.bi" ' memcpy(dest ptr,orig ptr,long)


#include "vars.bi"
#include "types.bi"
#include "util.bas"

#Include "ac97dev_WM9705.bas"
#Include "cp15.bas"
#Include "CPU.bas"
#Include "deviceDellAximX3.bas"
#Include "icache.bas"
#Include "keys.bas"
#Include "mem.bas"
#Include "mmiodev_AximX3cpld.bas"
#Include "mmiodev_W86L488.bas"
#Include "MMU.bas"
#Include "nand.bas"
#Include "pxa255_DSP.bas"
#Include "pxa255_UDC.bas"
#Include "pxa270_UDC.bas"
#Include "pxa270_IMC.bas"
#Include "pxa270_KPC.bas"
#Include "pxa270_WMMX.bas"
#Include "pxa_AC97.bas"
#Include "pxa_DMA.bas"
#Include "pxa_GPIO.bas"
#Include "pxa_I2C.bas"
#Include "pxa_I2S.bas"
#Include "pxa_IC.bas"
#Include "pxa_LCD.bas"
#Include "pxa_MemCtrl.bas"
#Include "pxa_MMC.bas"
#Include "pxa_PWM.bas"
#Include "pxa_PwrClk.bas"
#Include "pxa_RTC.bas"
#Include "pxa_SSP.bas"
#Include "pxa_TIMR.bas"
#Include "pxa_UART.bas"
#Include "RAM.bas"
#Include "ROM.bas"
#Include "socPXA.bas"
#Include "vSD.bas"



#define SD_SECTOR_SIZE		(512ULL)


Dim Shared As FILE ptr mSdCard= NULL 



Function socExtSerialReadChar() As long
	Dim As long i, ret = CHAR_NONE 
   'print "....LEYENDO de socExtSerialReadChar SIN HACER ...."

	return ret 
End Function

' salida de datos UART a consola desde HOSTING AXIM-X3
Sub socExtSerialWriteChar(chr_ As Long)
	COLOR 2
	if (chr_ And &hFF00)=0 Then 
		print chr(chr_); 
	else
		print " >> EC_0x",HEX(chr_,2);
	EndIf
   COLOR 7
End Sub


Function prvSdSectorR(secNum As uLong , buf As Any Ptr) As Bool
	return fseek(mSdCard, SD_SECTOR_SIZE * secNum, SEEK_SET) = 0 AndAlso fread(buf, 1, SD_SECTOR_SIZE, mSdCard) = SD_SECTOR_SIZE 
End Function

Function prvSdSectorW(secNum As uLong , buf As Any Ptr) As Bool
	return fseek(mSdCard, SD_SECTOR_SIZE * secNum, SEEK_SET) = 0 AndAlso fwrite(buf, 1, SD_SECTOR_SIZE, mSdCard) = SD_SECTOR_SIZE 
End Function



'Sub usage( self As string)
'	Print "USAGE: EXE {-r ROMFILE.bin | --x} [-g gdbPort] [-s SDCARD_IMG.bin] [-n NAND.bin]"
'	Sleep 
'	end 
'End Sub





 '------------------------ MAIN --------------------------
	'screen 18

	dim as uLong romLen = 0, sdSecs = 0 
	'Dim As Byte ptr self '= argv(0) 
	'dim As Bool noRomMode = false 
	dim as FILE ptr nandFile = NULL 
	dim as FILE ptr romFile = NULL 
	dim as uByte ptr rom = NULL 
	Dim As long gdbPort = -1 
	'dim as ULongInt sdSize 
	dim as SoC_T ptr soc
	'Dim As long c 
	
#if 0
	while 1 '((c = getopt(argc, argv, "g:s:r:n:hx")) != -1) switch (c) {
		case "g" 	'gdb port
			gdbPort = IIf(optarg , atoi(optarg) ,-1) 
			if (gdbPort < 1024) OrElse (gdbPort > 65535) Then usage(self)
		
		case "s" 	'sd card
			if optarg Then mSdCard = fopen(optarg, "r+b")
			if mSdCard=0 Then usage(self)

			fseek(mSdCard, 0, SEEK_END) 
			sdSize = ftell(mSdCard) 
			if (sdSize mod SD_SECTOR_SIZE) Then 
				printf(!"SD card image not a multiple of %u bytes\n", SD_SECTOR_SIZE) 
				Sleep : End 
			EndIf
  
			sdSize \= SD_SECTOR_SIZE 
			if (sdSize Shr 32) Then 
				'printf(!"SD card too big: %llu sectors\n", (unsigned long long)sdSize);
				' jepalza, el anterior da advertencia en windows, pero en linux he leido que no
				' de todos modos, este cambio mio, podria no ser correcto.... ojito pues.
				printf(!"SD card too big: %lu sectors\n", (unsigned long)sdSize) 
				Sleep : End 
			EndIf
  
			sdSecs = sdSize 
			printf(!"opened %lu-sector sd card image\n", (long)sdSecs) 
		
		case "r" 	'ROM
			if (optarg) Then romFile = fopen(optarg, "rb")
		
		case "x" 	'NO_ROM mode
			noRomMode = true 
		
		case "n" 	'NAND
			if (optarg) Then nandFile = fopen(optarg, "r+b")
		
		Case Else 
			usage(self) 
   Wend
#endif
	
	romFile = fopen("..\NOR_AximX3\AximX3.NOR.bin", "rb")
	'if ((romFile<>0) AndAlso (noRomMode<>0)) OrElse ((romFile<>0) AndAlso (noRomMode=0)) Then 
		'usage(self)
	'EndIf
  
	
	if (romFile) Then 
		fseek(romFile, 0, SEEK_END) 
		romLen = ftell(romFile) 
		rewind(romFile) 
	
		rom = cast(UByte ptr,allocate(romLen) )
		if rom=0 Then 
			MiPrint "CANNOT ALLOC ROM"
			sleep : end
		EndIf
  
		if (romLen <> fread(rom, 1, romLen, romFile)) Then 
			MiPrint "CANNOT READ ROM"
			sleep : end 
		EndIf
  
		fclose(romFile) 
	EndIf
  
	print "Leidos ";romLen;" bytes De ROM"

	' NOTA: el tipo de SOC lo determina la rutina "deviceGetSocRev"
	'       devuelve SIEMPRE "1" que indica SOC PXA26x
	'       seria para una AXIM-X3
	'       si queremos un SOC PXA270, deberia devolver "2"

	soc = socInit(cast(any ptr ptr,rom), @romLen, iif(romLen , 1 , 0), sdSecs, _ 
			cast(SdSectorR,@prvSdSectorR), cast(SdSectorW,@prvSdSectorW), _
			nandFile, gdbPort, deviceGetSocRev() ) ' ultimo parametro=1=SOC_PXA26x 
	
	print "dir cpu en main    : ";hex(soc->cpu->coproc(15),8),hex(soc->cpu->coproc(15)->regXfer,8),hex(soc->cpu->coproc(15)->userdata,8)
		dim as byte ptr pp=soc->cpu->coproc(15)->userData	
		for f as integer=0 to 31
			'print hex(pp[f],2);" ";
		next
		print	
	print "Maquina SOC PXA270 inicializada. Ejecutamos CPU"
	socRun(soc) 
	beep
	MiPrint "fin" 
	sleep

