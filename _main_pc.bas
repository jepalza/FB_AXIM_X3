'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


#cmdline "-gen gcc"
' -fpmode fast -fpu sse"
' -g -Wc -gstabs+ para depurar
' con -O 2 da error



#include "SDL2\SDL.BI"
#include "windows.bi"


' prefiero asi las boleanas
#undef Bool
  #define Bool UByte
#undef TRUE
  #define TRUE 1
#undef FALSE
  #define FALSE 0


' printf(), scanf(), fopen(), etc
#Include "crt\stdio.bi" 


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







 '------------------------ MAIN --------------------------
	'screen 18
	
   ' necesario solo por compatibilidad, NO se emplea, se ha eliminado todo lo relacionado con DEBUG
	' eliminar esta variable requiere ir rutina por rutina quitando el parametro que lo emplea
	dim as long gdbPort =0 ' depuracion, eliminada

	dim as uByte ptr rom = NULL
	dim as SoC_T ptr soc = null

	dim as uLong romLen = 0 
	dim as uLong sdSecs = 0 
	dim as ULongInt sdSize

	dim as FILE ptr romFile  = NULL 
	dim as FILE ptr nandFile = NULL  
 
	Dim as String FICHERO_ROM="..\NOR_AximX3\AximX3.NOR.bin"	
	Dim as String FICHERO_SDCARD="" '..\NOR_AximX3\sdcard.img" 'no probado aun, de hecho, falla....
	Dim as String FICHERO_NAND="" ' no comprobado aun, dado que es para "otras" CPU, no para AXIM-X3
	
		' ** ROM **
		if FICHERO_ROM<>"" then
			romFile = fopen(FICHERO_ROM, "rb")
		endif
		
		' ** NAND **
		if FICHERO_NAND<>"" then
			nandFile = fopen(FICHERO_NAND, "r+b")
		endif
	
		' ** SD-CARD **
		if FICHERO_SDCARD<>"" then
			mSdCard = fopen(FICHERO_SDCARD, "r+b")
			fseek(mSdCard, 0, SEEK_END) 
			sdSize = ftell(mSdCard) 
			if (sdSize mod SD_SECTOR_SIZE) Then 
				print "SD card image not a multiple of ";SD_SECTOR_SIZE;" bytes"
				Sleep : End 
			EndIf
  
			sdSize \= SD_SECTOR_SIZE 
			if (sdSize Shr 32) Then 
				print "SD card too big: ";sdSize;" sectors"
				Sleep : End 
			EndIf
  
			sdSecs = sdSize 
			print "opened ";sdSecs;"-sector sd card image" 
		endif
		
	
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

