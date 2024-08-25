


' RAM.bas
Type ArmRam 'field=1
	As uLong adr 
	As uLong sz 
	As uLong ptr buf 
End Type 
' -----------------------------------



' ROM.bas
#define STRATAFLASH_BLOCK_SIZE	&h20000ul

enum StrataFlashMode
	StrataFlashNormal,
	StrataFlashReadStatus,
	StrataFlashSeen0x60,
	StrataFlashSetSTS,
	StrataFlashReadID,
	StrataFlashReadCFI,
	StrataFlashErzCy1,
	StrataFlashWriCy1
End Enum

Type ArmRomPiece  'field=1
   As ArmRomPiece ptr next_
   As _ArmRom ptr rom 
	As ULong base_, size 
	As ULong ptr buf 
End Type 

Type ArmRom  'field=1
	As ULong start, opAddr 
   As ArmRomPiece ptr pieces 
	As RomChipType chipType ' enum
	As StrataFlashMode mode ' enum
	As UShort configReg, busyCy, stsReg, possibleConfigReg 
End Type 
' -----------------------------------


' MMU.bas
'less sets is faster
#define MMU_TLB_BUCKET_SIZE	2
#define MMU_TLB_BUCKET_NUM		128

Type ArmPrvTlb  'field=1
	As ULong pa, va 
	As ULong sz 
	As ULong ap 		:2 
	As ULong domain 	:4 
	As ULong c 			:1 
	As ULong b 			:1 
End Type 

Type ArmMmu  'field=1
   As ArmMem ptr mem 
	As ULong transTablPA 
	As UByte S 				:1 
	As UByte R 				:1 
	As UByte xscale 		:1 
	As UShort readPos(MMU_TLB_BUCKET_NUM-1) 
	As UShort replPos(MMU_TLB_BUCKET_NUM-1) 
   As ArmPrvTlb tlb(MMU_TLB_BUCKET_NUM-1, MMU_TLB_BUCKET_SIZE-1) 
	As ULong domainCfg 
End Type 
' ---------------------------------



' NAND.bas
enum K9nandState
	K9nandStateReset,
	K9nandStateReadId,
	K9nandStateProgramAddrRxing,
	K9nandStateProgramDataRxing,
	K9nandStateEraseAddrRxing,
	K9nandStateReading,
	K9nandStateStatusReading
End Enum

' K9nandAreaB, K9nandAreaC only used if flags.NAND_FLAG_SAMSUNG_ADDRESSED_VIA_AREAS is set
enum K9nandArea
	K9nandAreaA,
	K9nandAreaB,
	K9nandAreaC
End Enum

Type NAND_T  'field=1
	As NandReadyCbk readyCbk(1) 
	As any ptr readyCbkData(1) 
	
	'geometry and id
	As ULong bytesPerPage 		'main plus spare
	As ULong blocksPerDevice 
	As UShort areaSize 
	As UByte pagesPerBlockLg2 	'log base 2 (eg: if device has 32 pages per block, this will be 5)
	As UByte deviceId(5) 
	As UByte deviceIdLen 
	As UByte byteAddrBytes 
	As UByte pageAddrBytes 
	As UByte flags 
	
	'runtime state
	As K9nandState state 'enum
	As K9nandArea area  'enum
	As UByte addrBytesRxed 
	As UByte addrBytes(7) 
	As ULong pageNo 	'read & program only
	As ULong pageOfst 	'for read ops only
	As ULong busyCt 
	As UByte ptr pageBuf 
	
	'data
	As UByte ptr datas 	'stores inverted data (so 0-init is valid)
End Type 
' ---------------------------------



' pca_GPIO.bas
#define PXA_GPIO_BASE		&h40E00000UL
#define PXA_GPIO_SIZE		&h00001000UL

Type SocGpio 'field=1 
   As _SocIc ptr ic 
	As UByte socRev, nGpios 
	
	As ULong latches(3) 		'what pxa wants to be outputting
	As ULong inputs(3) 		'what pxa is receiving	[only set by the socGpioSetState() API]
	As ULong levels(3) 		'what pxa sees (it differs from above for IN pins)
	As ULong dirs(3) 			'1 = output
	As ULong riseDet(3) 		'1 = rise detect
	As ULong fallDet(3) 		'1 = fall detect
	As ULong detStatus(3) 	'1 = detect happened
	As ULong AFRs(7) 			'1, 2, 3 = alt funcs. sometimes 1 is gpio and 0 is alt func (pxa 26x only)
	
	As GpioChangedNotifF notifF(120) 
	As any ptr notifD(120) 
	
	As GpioDirsChangedF dirNotifF 
	As any ptr dirNotifD 
End Type 
' ---------------------------------



' pxa_I2C.bi
#define PXA_I2C_SIZE	&h00000024UL

#define REG_IDX_IBMR	0
#define REG_IDX_IDBR	1
#define REG_IDX_ICR	2
#define REG_IDX_ISR	3
#define REG_IDX_ISAR	4

type DevI2C 'field=1
	As I2cDeviceActionF actF 
	As Any Ptr userData 
end type
Type SocI2c  'field=1
	As _SocDma ptr dma 
	As _SocIc ptr ic 
	As uLong base_ 
	As uLong irqNo 
	As uShort icr 
	As uShort isr 
	As uByte db 
	As uByte isa 
	
		As DevI2C devs(7) 

	As uByte waitForAddr  :1 
	As uByte latentBusy	 :1 	
End Type 
' ---------------------------------



' pxa_I2S.bas
#define PXA_I2S_BASE	&h40400000UL
#define PXA_I2S_SIZE	&h00010000UL

Type SocI2s  'field=1
	As _SocDma ptr dma 
	As _SocIc  ptr ic 
	
	As uShort sacr0 
	As uShort sasr0 
	As uByte sacr1 
	As uByte sadiv 
	As uByte saimr 
	
	As uLong txFifo(15) 
	As uLong rxFifo(15) 
	As uByte txFifoEnts 
	As uByte rxFifoEnts 
End Type 
' ---------------------------------



' pxa_IC.bas
#define PXA_IC_BASE	&h40D00000UL
#define PXA_IC_SIZE	&h00010000UL

Type SocIc  'field=1
	As ArmCpu ptr cpu 
	
	As uLong ICMR(1) 	'Mask Registers
	As uLong ICLR(1) 	'Level Registers
	As uLong ICPR(1) 	'Pending registers
	As uLong ICCR 		'Control Register

	As uByte prio(39) 
	As uByte iccr2 
	
	As Bool wasIrq, wasFiq, gen2 
End Type 
' ---------------------------------



' pxa_LCD.bas
#define PXA_LCD_BASE			&h44000000UL
#define PXA_LCD_SIZE			&h00001000UL

#define LCD_STATE_IDLE			0
#define LCD_STATE_DMA_0_START	1
#define LCD_STATE_DMA_0_END	2

#define UNMASKABLE_INTS			&h7C8E

Type PxaLcd  'field=1
   As SocIc ptr ic 
   As ArmMem ptr mem 
	
	'registers
	As ULong lccr0, lccr1, lccr2, lccr3, lccr4, lccr5, liicr, trgbr, tcr 
	As ULong fbr(6), fdadr(6), fsadr(6), fidr(6), ldcmd(6) 
	As UShort lcsr 	'yes, 16-bit 
	
	'for our use
	As UShort intMask 
	
	As UByte state		  		:6 
	As UByte intWasPending	:1 
	As UByte enbChanged	  	:1 

	As UByte palete(511) 

	As ULong frameNum 
	
	As Bool hardGrafArea 
End Type 
' ---------------------------------



' pxa_MemCtrl.bas
#define PXA_MEM_CONTROLLER_BASE	&h48000000UL
#define PXA_MEM_CONTROLLER_SIZE	&h00004000UL

Type PxaMemCtrlr  'field=1
	As uLong mdcnfg, mdrefr, msc(2), mecr, sxcnfg, sxmrs, mcmem(1), mcatt(1), mcio(1), mdmrs 
	As uLong arbCntrl, bscntr(3), mdmrslp, reg_0x20 
	As uShort sa1110 
	As uByte lcdbscntr 
	As Bool g2 
End Type 
' ---------------------------------



' pxa_MMC.bas
#define PXA_MMC_BASE	&h41100000UL
#define PXA_MMC_SIZE	&h00001000UL

Type PxaMmc  'field=1
   As _SocDma PTR dma 
   As _SocIc  PTR ic 
	
	As ULong arg 
	As UShort stat, readTo, blkLen, numBlks 
	As UByte spi, iMask, iReg, cmdat, clockSpeed, resTo, cmdReg 
	As UShort respBuf(7) 
	As Bool clockOn, cmdQueued, dataXferOngoing 
	
	As _VSD2 PTR vsd 
	
	'fifo
	As ULong fifoBytes, fifoOfst 
	As UByte blockFifo(1023) 
End Type 
' ---------------------------------




' pxa_PWM.bas
#define PXA_PWM_SIZE	&h0010

Type PxaPwm  'field=1
	As uLong duty	 :11 
	As uLong per	 :10 
	As uLong ctrl	 :7 
End Type 
' -----------------------------------


' pxa_PwrClk.bas
#define PXA_CLOCK_MANAGER_BASE	&h41300000UL
#define PXA_CLOCK_MANAGER_SIZE	&h00001000UL

#define PXA_POWER_MANAGER_BASE	&h40F00000UL
#define PXA_POWER_MANAGER_SIZE	&h00000180UL

Type PxaPwrClk  'field=1
   As ArmCpu ptr cpu 
	As ULong CCCR, CKEN, OSCR 	'clocks manager regs
	'power mgr common between 255 and 270
	As ULong PMCR, PSSR, PSPR, PWER, PRER, PFER, PEDR, PCFR, PGSR(3), RCSR, PMFW 
	'power mgr 270 only
	As ULong PSTR, PVCR, PUCR, PKWR, PKSR, PCMD(31) 
	As Bool turbo, isPXA270 
End Type 
' -----------------------------------


' pxa_RTC.bas
#define PXA_RTC_BASE		&h40900000UL
#define PXA_RTC_SIZE		&h00001000UL

Type PxaRtc  'field=1
	As SocIc ptr ic 
	
	As uLong lastSeenTime 
	As uLong RCNR 		'RTC counter offset from our local time
	As uLong RTAR 		'RTC alarm
	As uLong RTTR 		'RTC trim - we ignore this alltogether
	
	As uByte RTSR 		'RTC status
End Type 
' -----------------------------------


' pxa_SSP.bas
#define PXA_SSP_SIZE	&h00010000UL

#define DMA_OFST_RX 0
#define DMA_OFST_TX 1

Type SocSsp  'field=1
	As _SocDma ptr dma 
	As _SocIc ptr ic 
	As uLong base_
	As uByte irqNo 
	As uByte dmaReqNoBase 
	
	As uLong cr0, cr1, sr 
	
	As SspClientProcF procF(7) 
	As Any ptr procD(7) 
	
	As uShort rxFifo(15), txFifo(15) 
	As uByte rxFifoUsed, txFifoUsed 
End Type 
' -----------------------------------


' pxa_TIMR.bas
#define PXA_TIMR_BASE	&h40A00000UL
#define PXA_TIMR_SIZE	&h00010000UL

Type PxaTimr  'field=1
	As SocIc ptr ic 
	
	As uLong OSMR(3) 	'Match Register 0-3
	As uLong OSCR 		'Counter Register
	As uByte OIER 		'Interrupt Enable
	As uByte OWER 		'Watchdog enable
	As uByte OSSR 		'Status Register
End Type 
' -----------------------------------


' pxa_UART.bas
#define UART_FIFO_DEPTH 64

Type UartFifo  'field=1
	As UByte read_
	As UByte write_
	As UShort buf(UART_FIFO_DEPTH-1) 
End Type 

Type SocUart  'field=1
   As SocIc ptr ic 
	As ULong baseAddr 
	
	As SocUartReadF readF 
	As SocUartWriteF writeF 
	As any ptr accessFuncsData 
	
   As UartFifo TX, RX 
	
	As UShort transmitShift 	'char currently "sending"
	As UShort transmitHolding 	'holding register for no-fifo mode
	
	As UShort receiveHolding 	'char just received
	
	As UByte irq 					:5 
	As UByte cyclesSinceRecv 	:3 
	
	As UByte IER 		'interrupt enable register
	As UByte IIR 		'interrupt information register
	As UByte FCR 		'fifo control register
	As UByte LCR 		'line control register
	As UByte LSR 		'line status register
	As UByte MCR 		'modem control register
	As UByte MSR 		'modem status register
	As UByte SPR 		'scratchpad register
	As UByte DLL 		'divisor latch low
	As UByte DLH 		'divior latch high;
	As UByte ISR 		'infrared selection register
End Type 
' -----------------------------------


' pxa255_DSP.bas
Type Pxa255dsp  'field=1
	As ULongInt acc0 
End Type 
' -----------------------------------


' pxa255_UDC.bas
#define PXA_UDC_BASE	&h40600000UL
#define PXA_UDC_SIZE	&h00001000UL

Type Pxa255Udc  'field=1
	As _SocDma ptr dma 
	As _SocIc  ptr ic 
	
	As uLong reg4 
	
	As uByte ccr, uicr0, uicr1 
End Type 
' -----------------------------------



' pxa270_IMC.bas
#define PXA270_IMC_BASE		&h58000000ul
#define PXA270_IMC_SIZE		&h0c

Type PxaImc  'field=1
	As uLong mcr 
	As uByte impmsr 
End Type 
' -----------------------------------



' pxa270_KPC.bas
#define PXA270_KPC_BASE		&h41500000ul
#define PXA270_KPC_SIZE		&h4c

Type PxaKpc  'field=1
   As SocIc ptr ic 
	
	'regs
	As ULong kpc, kpmk, kpas, kpasmkp(3) 
	As UShort kpkdi 
	As UByte kpdkChanged   :1 
	
	'stimuli
	As ULongint prevKeys 
	As UByte matrixKeys(7) 	'array indexed by column[output]. bits indexed by row (input). 1 = pressed
	As UByte directKeys 		'bitfield, 1 = down
	As UByte numMatrixKeysPressed 
	As UShort jogSta(1) 		'same format as KPREC reg, except we use bits 12..13 for jog sensor status
End Type 
' -----------------------------------



' pxa270_WMMX.bas
Union REG64 'field=1
	As Ulongint v64
	As longint s64
	As ulong v32(1)
	As long s32(1)
	As ushort v16(3)
	As short s16(3)
	As ubyte v8(7)
	As byte s8(7)
End Union

Type Pxa270wmmx  'field=1
	As REG64 wR(15) 
	As ULong wCGR(3), wCASF 'NZCV
	As UByte wCon, wCSSF 
End Type 
' -----------------------------------



' soc_PXA.bas
#define CPUID_PXA255			&h69052D06ul	'spepping A0
#define CPUID_PXA260			&h69052D06ul	'spepping B1
#define CPUID_PXA270			&h49265013ul	'stepping C0

#define SRAM_BASE				&h5c000000ul
#define SRAM_SIZE				&h00040000ul

#define ROM_BASE				&h00000000UL
#define RAM_BASE				&hA0000000UL

#define PXA_I2C_BASE			&h40301680UL
#define PXA_PWR_I2C_BASE	&h40F00180UL

Type SoC_T  'field=1
   As SocUart ptr ffUart, hwUart, stUart, btUart 
   As SocSsp  ptr ssp(2) 
   As SocGpio ptr gpio 
   As _SocAC97 ptr ac97 
   As _SocDma ptr dma 
   As SocI2s ptr i2s 
   As SocI2c ptr i2c 
   As SocIc  ptr ic 
	As Bool mouseDown 
	
   As PxaMemCtrlr ptr memCtrl 
   As PxaPwrClk ptr pwrClk 
   As SocI2c ptr pwrI2c 
   As PxaPwm ptr pwm(3) 
   As PxaTimr ptr tmr 
   As PxaMmc ptr mmc 
   As PxaRtc ptr rtc 
   As PxaLcd ptr lcd 
	
	union 'field=1
		type 'field=1 '25x\26x
		   As Pxa255dsp ptr dsp 
		   As Pxa255Udc ptr udc1 
		End Type
		 
		type 'field=1 'PXA27x
		   As Pxa270wmmx ptr wmmx 
		   As _Pxa270Udc ptr udc2 
		   As PxaImc ptr imc 
		   As PxaKpc ptr kpc 
		end type
	end union
	
	As ArmRam ptr sram
	As ArmRam ptr ram
	As ArmRam ptr ramMirror			'mirror for ram termination
	As ArmRom ptr ramWriteIgnore		'write ignore for ram termination
	As ArmRom ptr rom
	As ArmMem ptr mem
	As ArmCpu ptr cpu
	As _Keypad ptr kp
	As _VSD2   ptr vSD
   
	As _Device Ptr dev
end type
' -----------------------------------



' pxa_DMA.bas
#define PXA_DMA_BASE		&h40000000UL
#define PXA_DMA_SIZE		&h00002000UL

#define REG_DAR 	0	'descriptor
#define REG_SAR 	1	'source
#define REG_TAR 	2	'dest
#define REG_CR		3	'command
#define REG_CSR	4	'status


Type PxaDmaChannel  'field=1
	As ULong DAR 	'descriptor address register
	As ULong SAR 	'source address register
	As ULong TAR 	'target address register
	As ULong CR 	'command register
	As ULong CSR 	'control and status register
	
	As UByte dsAddrWriten   	:1 
	As UByte dtAddrWriten   	:1 
	As UByte dcmdAddrWritten   :1 
End Type 

Type SocDma  'field=1
   As SocIc Ptr ic 
   As ArmMem Ptr mem 
	
	As ULong dalgn, dpcsr 
	As ULong DINT 
   As PxaDmaChannel channels(31) 
	As UByte CMR(74) 			'channel map registers	[  we store lower 8 bits only :-)  ]
End Type 
' ---------------------------------



' pxa_AC97.bas
#define PXA_AC97_BASE	&h40500000UL
#define PXA_AC97_SIZE	&h00010000UL

Type AC97Fifo  'field=1
	As UByte readPtr 
	As UByte numItems 
	As UByte dmaChannelNum 
	As UByte isRxFifo 
	As ULong datas(15) 
	
	As UByte ptr icr
	As UByte ptr isr 
	
	As ULong lastReadSample 
End Type 

Type Ac97CodecStruct  'field=1
	As Ac97CodecRegR regR 
	As Ac97CodecRegW regW 
	As Ac97CodecFifoR fifoR 
	As Ac97CodecFifoW fifoW 
	As any ptr userData 
	
	As UShort prevReadVal 
	
	As AC97Fifo txFifo 
	As AC97Fifo rxFifo 
End Type 

Type SocAC97  'field=1
	As SocDma ptr dma 
	As SocIc  ptr ic 
	
	As UByte pocr, picr, mccr, posr, pisr, mcsr, car, mocr, mosr, micr, misr 
	As ULong gcr, gsr, pcdr 
	
	' primary audio is PCM
	' secondary is mic
	' primary modem is modem
	 As Ac97CodecStruct primaryAudio, secondaryAudio, primaryModem, secondaryModem 
End Type 
' ---------------------------------




' deviceDellAximX3.bas
Type Device  'field=1
	 As ArmRom ptr secondFlashChip 
	 As _AximX3cpld ptr CPLD 
	 As _W86L488 ptr w86L488_ 
	 As WM9705 ptr wm9705_ 
End Type 
' ---------------------------------


' mmiodev_AximX3cpld.bas
#define AXIM_X3_CPLD_BASE	&h08000000ul
#define AXIM_X3_CPLD_SIZE 	&h04

Type AximX3cpld  'field=1
	As ULong valor 
End Type 
' ------------------------------------

' mmiodev_W86L488.bas
' MMIO info
#define W86L488_SIZE 		&h10

'direct regs
#define REG_NO_CMD_RSP				&h00
#define REG_NO_STAT_CTRL			&h01
#define REG_NO_RX_TX_FIFO			&h02
#define REG_NO_INT_STAT_CTRL		&h03
#define REG_NO_GPIO					&h04
#define REG_NO_GPIO_IRQ_CTRL		&h05
#define REG_NO_INDIRECT_ADDR		&h06
#define REG_NO_INDIRECT_DATA		&h07

'indirect regs (div 1)
#define IREG_NO_XTD_STA_AND_SETT	&h00
#define IREG_NO_SDIO_CTL			&h01
#define IREG_NO_MASTER_DATA_FMT	&h02
#define IREG_NO_MASTER_BLOCK_CT	&h03
#define IREG_NO_SLAVE_DATA_FMT	&h04
#define IREG_NO_SLAVE_BLOCK_CT	&h05
#define IREG_NO_NAK_TO				&h06
#define IREG_NO_ERR_STATUS			&h07
#define IREG_NO_HOST_IFACE			&h08
#define IREG_NO_TEST					&h09
#define IREG_NO_ID_CODE				&h0a

Type W86L488  'field=1
   As SocGpio ptr gpio 
	As _VSD2 ptr vsd 
	As Byte intGpio 
	
	'As direct regs
	As UShort sta 
	As UShort ctrl 
	As UShort ints 	'status and ctrl
	As UShort indAddr 
	
	As UByte gpioInts 
	As UByte gpioPrevStates 
	As UByte gpioIrqSta 
	
	As UByte intCdIe			  	:1 	'these occupy the same bit...ugh
	As UByte intCwrRspIe		  	:1 
	As UByte intCdSta		  		:1 	'these occupy the same bit...ugh
	As UByte intCwrRspSta	  	:1 
	
	
	'indirect regs
	As UShort xtdStatus 
	As UShort settings 
	As UShort sdio 
	As UShort mDataFmt 
	As UShort mBlockCnt 
	As UShort sDataFmt 
	As UShort sBlockCnt 
	As UShort nakTO 
	As UShort errSta 
	As UShort bufSvcLen 
	As UShort hostIface 
	
	'command stuff
	As UShort cmdWhi 
	As UShort cmdWmid 
	As UByte  cmdBitsCnt	 	:3 
	
	'resp stuff
	As UShort resp(8) 

	'GPIOS: inputs are INVERTED, outputs aren´t!!!
	As UByte gpiosInput 		'as provided in (NOT INVERTED)
	As UByte gpioLatches 	'as requested for out
	As UByte gpioDirs 		'as requesed, 1 = out
End Type 
' ------------------------------------


' vSD.bas
enum RejectReason_enum
	InvalidInCurrentState,
	UnacceptableParam,
	UnknownCommand
end enum

enum State_enum
	StateIdle,
	StateReady,
	StateIdent,
	StateStby,
	StateTran,
	StateData,
	StateRcv,
	StatePrg,
	StateDis
end enum

Type VSD  'field=1
	As SdSectorR secR 
	As SdSectorW secW 
	As ULong nSec 
	As State_enum state 
	As UByte busyCount 
	
	As UShort rca 
	
	As ULong expectedBlockSz 
	As UByte dataBuf(63) 	'for short data in\out ops that are not SD user data
	
	As UByte expectDataToUs 		 :1 
	As UByte hcCard					 :1 
	As UByte acmdShift				 :1 
	As UByte reportAcmdNext			 :1 

	As UByte initWaitLeft 
	As ULong prevAcmd41Param 
	
	
	As UByte curBuf(511) 
	As ULong curSec 
	As UShort curBufLen 
	As Bool bufIsData 
	As Bool bufContinuous 
	
	As Bool haveExpectedNumBlocks 
	As ULong numBlocksExpected 
End Type 
' -------------------------------------------


' socPXA.bas
#define PXA_UDC_BASE	&h40600000UL
#define PXA_UDC_SIZE	&h00001000UL

Type _Ep  'field=1
	As ULong ccra 	'unused for ep0
	As UShort csr 
	As UShort bcr 
End Type 

Type Pxa270Udc  'field=1
	As SocDma ptr dma 
	As SocIc  ptr ic 
	
	As _Ep ep(23) 
	As ULong udccr, udcicr(1), udcisr(1), udcotgicr, udcotgisr, up2ocr 
	As UShort udcfnr 
	As UByte up3ocr 
End Type 