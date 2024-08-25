Type _Device      As Device 
Type _stub        As stub_t
Type _Keypad      As Keypad 
Type _AximX3cpld  As AximX3cpld 
Type _W86L488     As W86L488 
Type _NAND_T      As NAND_T 
Type _VSD2        As VSD
Type _icache      As icache 

Type _Pxa255dsp   As Pxa255dsp 
Type _Pxa255Udc   As Pxa255Udc 
Type _PxaImc      As PxaImc 
Type _PxaKpc      As PxaKpc 
Type _Pxa270Udc   As Pxa270Udc 
Type _Pxa270wmmx  As Pxa270wmmx 
Type _PxaLcd      As PxaLcd 
Type _PxaMemCtrlr As PxaMemCtrlr
Type _PxaMmc      As PxaMmc 
Type _PxaPwm      As PxaPwm 
Type _PxaPwrClk   As PxaPwrClk 
Type _PxaRtc      As PxaRtc 
Type _PxaTimr     As PxaTimr 

'Type _ArmCpu      As ArmCpu 
Type _ArmRam      As ArmRam 
Type _ArmRom      As ArmRom 
Type _ArmMem      As ArmMem 
Type _ArmMmu      As ArmMmu 
Type _ArmCP15     As ArmCP15 

Type _SoC         As SoC_T
Type _SocAC97     As SoCAC97
Type _SocDma      As SoCDma 
Type _SocGpio     As SoCGpio 
Type _SocI2c      As SoCI2c
Type _SocI2s      As SoCI2s 
Type _SocIc       As SoCIc 
Type _SocSsp      As SoCSsp 
Type _SocUart     As SoCUart 
Type _SocUwire    As SoCUwire 
Type _SoCPeriphs  As SoCPeriphs 

Type _SoCUartWriteF As SoCUartWriteF 
Type _SoCUartReadF  As SoCUartReadF 







'  ************  _CPU_H_

#define ARM_SR_N				&h80000000UL
#define ARM_SR_Z				&h40000000UL
#define ARM_SR_C				&h20000000UL
#define ARM_SR_V				&h10000000UL
#define ARM_SR_Q				&h08000000UL
#define ARM_SR_I				&h00000080UL
#define ARM_SR_F				&h00000040UL
#define ARM_SR_T				&h00000020UL
#define ARM_SR_M				&h0000001FUL

#define ARM_SR_MODE_USR			&h00000010UL
#define ARM_SR_MODE_FIQ			&h00000011UL
#define ARM_SR_MODE_IRQ			&h00000012UL
#define ARM_SR_MODE_SVC			&h00000013UL
#define ARM_SR_MODE_ABT			&h00000017UL
#define ARM_SR_MODE_UND			&h0000001BUL
#define ARM_SR_MODE_SYS			&h0000001FUL

#define ARV_VECTOR_OFFT_RST		&h00000000UL
#define ARM_VECTOR_OFFT_UND		&h00000004UL
#define ARM_VECTOR_OFFT_SWI		&h00000008UL
#define ARM_VECTOR_OFFT_P_ABT		&h0000000CUL
#define ARM_VECTOR_OFFT_D_ABT		&h00000010UL
#define ARM_VECTOR_OFFT_UNUSED	&h00000014UL
#define ARM_VECTOR_OFFT_IRQ		&h00000018UL
#define ARM_VECTOR_OFFT_FIQ		&h0000001CUL


'the following are for cpuGetRegExternal() and are generally used for debugging purposes
#define ARM_REG_NUM_CPSR	16
#define ARM_REG_NUM_SPSR	17

Type ArmBankedRegs 
	As ULong R13, R14 
	As ULong SPSR 			'usr mode doesn´t have an SPSR
End Type

type _ArmCoprocessor As ArmCoprocessor
Type ArmCpu 
	As ULong regs(15) 		'current active regs as per current mode
	As ULong SPSR 
	
	As Bool N, Z, C, V, Q, T, I, F 

	As UByte M 

	As ULong curInstrPC 

   As ArmBankedRegs bank_usr 		'usr regs when in another mode
   As ArmBankedRegs bank_svc 		'svc regs when in another mode
   As ArmBankedRegs bank_abt 		'abt regs when in another mode
   As ArmBankedRegs bank_und 		'und regs when in another mode
   As ArmBankedRegs bank_irq 		'irq regs when in another mode
   As ArmBankedRegs bank_fiq 		'fiq regs when in another mode
	As ULong extra_regs(4) 			'fiq regs when not in fiq mode, usr regs when in fiq mode. R8-12

	As UShort waitingIrqs 
	As UShort waitingFiqs 
	As UShort CPAR 

   As _ArmCoprocessor ptr coproc(15)

	'various other cpu config options
	As ULong vectorBase 		'address of vector base

	As ULong pid 			'for fcse
	
   As _icache  ptr ic 
   As _ArmMmu  ptr mmu 
   As _ArmMem  ptr mem 
   As _ArmCP15 ptr cp15 
	
   As _stub ptr debugStub 
End Type 




Type ArmCoprocRegXferF As Function cdecl( cpu As ArmCpu Ptr , userData As Any Ptr , two  As Bool , MRC As Bool  , op1 As uByte , Rx As uByte , CRn As uByte , CRm As uByte , op2 As uByte) As Bool
Type ArmCoprocDatProcF As Function cdecl( cpu As ArmCpu Ptr , userData As Any Ptr , two  As Bool , op1 As uByte , CRd As uByte , CRn As uByte , CRm As uByte , op2 As uByte) As Bool
Type ArmCoprocMemAccsF As Function cdecl( cpu As ArmCpu Ptr , userData As Any Ptr , two  As Bool , N   As Bool  , store As Bool , CRd As uByte , addrReg As uByte , addBefore As ULong , addAfter As ULong , options As uByte Ptr) As Bool
Type ArmCoprocTwoRegF  As Function cdecl( cpu As ArmCpu Ptr , userData As Any Ptr , MRRC As Bool , op  As uByte , Rd As uByte , Rn As uByte , CRm As uByte) As Bool

Type ArmCoprocessor 
	As ArmCoprocRegXferF regXfer 
	As ArmCoprocDatProcF dataProcessing 
	As ArmCoprocMemAccsF memAccess 
	As ArmCoprocTwoRegF  twoRegF 

	As any ptr userData 
	
	as byte dummy(32*1024) ' revisar fallo gordo
End Type 




Declare Function cpuInit(pc As ULong , mem As _ArmMem Ptr , xscale As Bool , omap As Bool , debugPort As Long , cpuid As ULong , cacheId As ULong) As ArmCpu ptr 

Declare Sub cpuReset( cpu As ArmCpu Ptr , pc As ULong) 

Declare Sub cpuCycle( cpu As ArmCpu Ptr) 
Declare Sub cpuIrq( cpu As ArmCpu Ptr , fiq As Bool , raise As Bool) 	'unraise when acknowledged


Declare Function cpuGetRegExternal( cpu As ArmCpu Ptr , reg As Ubyte) As ULong 
Declare Sub cpuSetReg( cpu As ArmCpu Ptr , reg As Ubyte , val As ULong) 
Declare Function cpuMemOpExternal( cpu As ArmCpu Ptr , buf As any Ptr , vaddr As ULong , size As Ubyte , write As Bool) As Bool 	'for external use


Declare Sub cpuCoprocessorRegister( cpu As ArmCpu Ptr , cpNum As uByte , coproc As ArmCoprocessor ptr) 

Declare Sub cpuSetVectorAddr( cpu As ArmCpu Ptr , adr As ULong) 
Declare Sub cpuSetPid( cpu As ArmCpu Ptr , pid As ULong) 
Declare Function cpuGetPid( cpu As ArmCpu Ptr) As ULong 

Declare Function cpuGetCPAR( cpu As ArmCpu Ptr) As uShort 
Declare Sub cpuSetCPAR( cpu As ArmCpu Ptr , cpar As uShort) 





'  ************  _ICACHE_H_
#define ICACHE_L		5	'line size is 2^L bytes
#define ICACHE_S		11	'number of sets is 2^S
#define ICACHE_A		1	'set associativity (less for speed)

#define ICACHE_LINE_SZ		(1 Shl ICACHE_L)
#define ICACHE_BUCKET_NUM	(1 Shl ICACHE_S)
#define ICACHE_BUCKET_SZ	ICACHE_A

#define ICACHE_ADDR_MASK	(cast(uLong,-ICACHE_LINE_SZ))
#define ICACHE_USED_MASK	1UL
#define ICACHE_PRIV_MASK	2UL

Type icacheLine 
	As uLong info 	'addr, masks
	As uByte datas(ICACHE_LINE_SZ-1) 
End Type 

Type icache 
	As _ArmMem ptr mem 
	As _ArmMmu ptr mmu 
	
	As icacheLine lines(ICACHE_BUCKET_NUM-1) ' anulo esta, por que es "1" -> , ICACHE_BUCKET_SZ-1) 
	As uByte ptr_(ICACHE_BUCKET_NUM-1) 
End Type 

Declare Function icacheInit( mem As _ArmMem Ptr ,  mmu As _ArmMmu Ptr) As _icache ptr 
Declare Function icacheFetch( ic As _icache Ptr , va As ULong , sz As Ubyte , priviledged As Bool , fsr As Ubyte Ptr , buf As any Ptr) As Bool 
Declare Sub icacheInval( ic As _icache Ptr) 
Declare Sub icacheInvalAddr( ic As _icache Ptr , addr As ULong) 






'  ************  _AC97_WM9705_H_
Type WM9705 
   As _SoCAC97 ptr ac97 
	
	As UShort digiRegs(2) 
	As UShort volumes(11) 
	
	As UShort powerdownReg 
	As UShort extdAudio 
	As UShort dacrate 
	As UShort adcrate 
	As UShort generalPurpose 
	As UShort addtlFuncCtl 
	As UShort recSelect 
	As UShort addFunc 
	As UShort mixerPathMute 
	
	'As external stimuli
	As UShort vAux(3) 	'indexed by enum WM9705auxPin
	As UShort penX, penY, penZ 
	As Bool penDown 
	
	'As for state machine
	As Bool haveUnreadPenData 
	As UByte cooIdx 
	As UByte numUnreadDatas 
	As UShort otherTwo(1) 
End Type 

enum WM9705auxPin
	WM9705auxPinBmon = 0, 'keep in mind this is divided by 3, so if battery is 3V, pass 1V to this
	WM9705auxPinAux,
	WM9705auxPinPhone,
	WM9705auxPinPcBeep
end enum

Declare function wm9705Init(ac97 As _SoCAC97 ptr) as WM9705 ptr
declare sub wm9705periodic(wm as WM9705 ptr)

declare sub wm9705setAuxVoltage(wm as WM9705 ptr, which as WM9705auxPin, mV as ULong ) 
declare sub wm9705setPen(wm as WM9705 ptr, x as Short, y as Short, press As Short) 		'raw ADC values, negative for pen up

enum WM9705REG
	RESET_ = &h00,
	VOLMASTER = &h02,
	VOLHPHONE = &h04,
	VOLMASTERMONO = &h06,
	VOLPCBEEP = &h0a,
	VOLPHONE = &h0c,
	VOLMIC = &h0e,
	VOLLINEIN = &h10,
	VOLCD = &h12,
	VOLVIDEO = &h14,
	VOLAUX = &h16,
	VOLPCMOUT = &h18,
	RECSELECT = &h1a,
	VOLRECGAIN = &h1c,
	
	GENERALPURPOSE = &h20,
	
	POWERDOWN = &h26,
	EXTDAUDIO = &h2a,
	DACRATE = &h2c,
	ADCRATE = &h32,
	
	MIXERPATHMUTE = &h5a,
	ADDFUNCCTL = &h5c,
	ADDFUNC = &h74,
	
	DIGI1 = &h76,
	DIGI2 = &h78,
	DIGI_RES = &h7A,
	VID1 = &h7c,
	VID2 = &h7e
end enum

enum WM9705sampleIdx
	WM9705sampleIdxNone = 0,
	WM9705sampleIdxX,
	WM9705sampleIdxY,
	WM9705sampleIdxPressure,
	WM9705sampleIdxBmon,
	WM9705sampleIdxAuxAdc,
	WM9705sampleIdxPhone,
	WM9705sampleIdxPcBeep
end enum








'  ************  _CP15_H_
Type ArmCP15 
   As  ArmCpu ptr cpu 
   As _ArmMmu ptr mmu 
   As _icache ptr ic 
	
	As ULong control_
	As ULong ttb 
	As ULong FSR 	'fault sttaus register
	As ULong FAR 	'fault address register
	
	union
		type 'xscale
			As ULong CPAR 	'coprocessor access register
			As ULong ACP 	'auxilary control reg for xscale
		End Type
		type 'omap
			As UByte cfg, iMin, iMax 
			As UShort tid 
		end type 
	end union
	
	As ulong mmuSwitchCy  
	
	As ulong cpuid
	As ulong cacheId
	
	As Bool xscale , omap 
end type

Declare Function cp15Init( cpu As ArmCpu Ptr , mmu As _ArmMmu Ptr , ic As _icache Ptr , cpuid As ULong , cacheId As ULong , xscale As Bool , omap As Bool) As _ArmCP15 ptr 
Declare Sub cp15SetFaultStatus( cp15 As _ArmCP15 Ptr , addr As ULong , faultStatus As Ubyte) 
Declare Sub cp15Cycle( cp15 As _ArmCP15 Ptr) 






'  ************  _ROM_H_
Enum RomChipType 
	RomWriteIgnore,
	RomWriteError,
	RomStrataFlash16x,
	RomStrataflash16x2x
End Enum 

'Type As Any Ptr ArmRom 

Declare Function romInit( mem As _ArmMem Ptr , adr As ULong , pieces As any Ptr ptr ,  pieceSizes As ULong Ptr , numPieces As ULong , chipType As RomChipType) As _ArmRom ptr







'  ************  _DEVICE_H_
Type SocPeriphs 
	'As in to deviceSetup
	As _SoCAC97 Ptr ac97 
	As _SoCGpio Ptr gpio 
	As _SoCUwire Ptr uw 
	As _SoCI2c Ptr i2c 
	As _SoCI2s Ptr i2s 
	As _SoCSsp Ptr ssp 
	As _SoCSsp Ptr ssp2 	'assp for xscale
	As _SoCSsp Ptr ssp3 	'nssp for scale
	As _ArmMem Ptr mem 
	As _SoC Ptr soc 
	
	'As PXA order: ffUart, hwUart, stUart, btUart
	As _SoCUart Ptr uarts(3) 
	
	As Any Ptr adc 		'some cases need this
	As Any Ptr kpc 		'some cases need this
	
	'As out from deviceSetup
	As _NAND_T Ptr nand 
	As _SoCUart Ptr dbgUart 
End Type 

Enum RamTermination 		'what´s after ram in phys map? (some devices probe)
	RamTerminationMirror,
	RamTerminationWriteIgnore,
	RamTerminationNone
End Enum 

'Type As Any Ptr Device 

'simple queries
Declare Function deviceHasGrafArea() As Bool 
Declare Function deviceGetRamSize() As ULong 
Declare Function deviceGetRamTerminationStyle() As RamTermination 
Declare Function deviceGetRomMemType() As RomChipType 
Declare Function deviceGetSocRev() As Ubyte 

'device handling
Declare Function deviceSetup( sp As _SoCPeriphs Ptr , kp As _Keypad Ptr , vsd As _VSD2 Ptr , nandFile As FILE Ptr) As _Device ptr 
Declare Sub deviceKey( dev As _Device Ptr , key As ULong , down As Bool) 
Declare Sub devicePeriodic( dev As _Device Ptr , cycles As ULong) 
Declare Sub deviceTouch( dev As _Device Ptr , x As Long , y As Long , press As Long) 





'  ************  _GDB_STUB_H_
Declare Function gdbStubInit( cpu As ArmCpu Ptr , port As Long) As _stub ptr 
Declare Sub gdbStubDebugBreakRequested( stub As _stub Ptr) 
Declare Sub gdbStubReportPc( stub As _stub Ptr , pc As ULong , thumb As Bool) 
Declare Sub gdbStubReportMemAccess( stub As _stub Ptr , addr As ULong , sz As Ubyte , writes As Bool) 





'  ************  _KEYS_H_
Declare Function keypadInit( gpio As _SoCGpio Ptr , matrixHasPullUps As Bool) As _Keypad ptr 
Declare Function keypadDefineRow( kp As _Keypad Ptr , rowIdx As uLong , gpio As Byte) As Bool 
Declare Function keypadDefineCol( kp As _Keypad Ptr , colIdx As uLong , gpio As Byte) As Bool 
Declare Function keypadAddGpioKey( kp As _Keypad Ptr , sdlKey As ULong , gpioNum As Byte , activeHigh As Bool) As Bool 
Declare Function keypadAddMatrixKey( kp As _Keypad Ptr , sdlKey As ULong , row As uLong , col As uLong) As Bool 

Declare Sub keypadSdlKeyEvt( kp As _Keypad Ptr , sdlKey As ULong , wentDown As Bool) 





'  ************  _MEM_H_
#define NUM_MEM_REGIONS 128

type ArmMemAccessF as function( userData as any ptr, pa as ULong, size as Ubyte, write_ As Bool, buf as any ptr) As Bool
Type ArmMemRegion 
	As ULong pa 
	As ULong sz 
	As ArmMemAccessF aF
	As any ptr uD 
End Type 

Type ArmMem 
   As ArmMemRegion regions(NUM_MEM_REGIONS-1) 
End Type 

#define MEM_ACCESS_TYPE_READ		0
#define MEM_ACCESS_TYPE_WRITE		1
#define MEM_ACCCESS_FLAG_NOERROR	&h80	'for debugger use

Declare Function memInit() As _ArmMem ptr 
Declare Sub memDeinit( mem As _ArmMem Ptr) 

Declare Function memRegionAdd( mem As _ArmMem Ptr , pa As ULong , sz As ULong , af As ArmMemAccessF ,  uD As any Ptr) As Bool 

Declare Function memAccess( mem As _ArmMem Ptr , addr As ULong , size As Ubyte , accessType As Ubyte ,  buf As any Ptr) As Bool 





'  ************  _MMIO_AXIM_X3_CPLD_H_
Declare Function aximX3cpldInit( physMem As _ArmMem Ptr) As _AximX3cpld ptr 






'  ************  _W86L488_H_
#define W86L488_BASE_T3 	&h08000000ul
#define W86L488_BASE_AXIM	&h0c000000ul

'Type As Any Ptr W86L488 

Declare Function w86l488init( physMem As _ArmMem Ptr , gpio As _SoCGpio Ptr , bases As ULong , card As _VSD2 Ptr , intPin As Long) As _W86L488 ptr  ' intPin negative for none

' inputs only
Declare Sub w86l488gpioSetVal( wl As _W86L488 Ptr , gpioNum As ULong , hi As Bool) 





'  ************  _MMU_H_
#define MMU_DISABLED_TTP			&hFFFFFFFFUL

#define MMU_MAPPING_CACHEABLE		&h0001
#define MMU_MAPPING_BUFFERABLE	&h0002
#define MMU_MAPPING_UR				&h0004
#define MMU_MAPPING_UW				&h0008
#define MMU_MAPPING_SR				&h0010
#define MMU_MAPPING_SW				&h0020

Declare Function mmuInit( mem As _ArmMem Ptr , xscaleMode As Bool) As _ArmMmu ptr 
Declare Sub mmuReset( mmu As _ArmMmu Ptr) 

Declare Function mmuTranslate( mmu As _ArmMmu Ptr , va As ULong , priviledged As Bool , writes As Bool , paP As ULong Ptr , fsrP As Ubyte Ptr , mappingInfoP As uByte Ptr) As Bool 

Declare Function mmuIsOn( mmu As _ArmMmu Ptr) As Bool 

Declare Function mmuGetTTP( mmu As _ArmMmu Ptr) As ULong 
Declare Sub mmuSetTTP( mmu As _ArmMmu Ptr , ttp As ULong) 

Declare Sub mmuSetS( mmu As _ArmMmu Ptr , on As Bool) 
Declare Sub mmuSetR( mmu As _ArmMmu Ptr , on As Bool) 
Declare Function mmuGetS( mmu As _ArmMmu Ptr) As Bool 
Declare Function mmuGetR( mmu As _ArmMmu Ptr) As Bool 

Declare Function mmuGetDomainCfg( mmu As _ArmMmu Ptr) As ULong 
Declare Sub mmuSetDomainCfg( mmu As _ArmMmu Ptr , val As ULong) 

Declare Sub mmuTlbFlush( mmu As _ArmMmu Ptr) 

Declare Sub mmuDump( mmu As _ArmMmu Ptr) 		'for calling in GDB :)






'  ************  _NAND_H_
Type NandReadyCbk As Sub( userData As Any Ptr , ready As Bool)

'options
'use 0x01 and 0x50 commands to save one bit on byte addressing
#define NAND_FLAG_SAMSUNG_ADDRESSED_VIA_AREAS	&h01
#define NAND_HAS_SECOND_READ_CMD						&h02


type NandSpecs
	as ULong bytesPerPage
	as ULong blocksPerDevice
	as uByte pagesPerBlockLg2
	as uByte flags
	as uByte devIdLen
	redim as uByte devId(0)
end type

Declare Function nandInit( nandFile As FILE Ptr , specs As NANDSpecs Ptr , readyCbk As NandReadyCbk , readyCbkData As any Ptr) As _NAND_T ptr

Declare Sub nandSecondReadyCbkSet( nand As _NAND_T Ptr , readyCbk As NandReadyCbk , readyCbkData As any Ptr) 

Declare Function nandWrite( nand As _NAND_T Ptr , cle As Bool , ale As Bool , val As uByte) As Bool 
Declare Function nandRead( nand As _NAND_T Ptr , cle As Bool , ale As Bool , valP As uByte Ptr) As Bool 

Declare Function nandIsReady( nand As _NAND_T Ptr) As Bool 

Declare Sub nandPeriodic( nand As _NAND_T Ptr) 





'  ************  _PXA255_DSP_H_
'Type As Any Ptr Pxa255dsp 
Declare Function pxa255dspInit( cpu As ArmCpu Ptr) As _Pxa255dsp ptr






'  ************  _PXA255_UDC_H_
'Type As Any Ptr Pxa255Udc 
Declare Function pxa255UdcInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _Pxa255Udc ptr 
' #endif





'  ************  _PXA270_IMC_H_
'Type As Any Ptr PxaImc 
Declare Function pxaImcInit( physMem As _ArmMem Ptr) As _PxaImc ptr





'  ************  _PXA270_KPC_H_
'Type As Any Ptr PxaKpc 
Declare Function pxaKpcInit( physMem As _ArmMem Ptr ,  ic As _SoCIc Ptr) As _PxaKpc ptr 

'keep in mind that colums are out and rows are in
Declare Sub pxaKpcMatrixKeyChange( kpc As _PxaKpc Ptr , row As Ubyte , col As Ubyte , isDown As Bool) 
Declare Sub pxaKpcDirectKeyChange( kpc As _PxaKpc Ptr , keyIdx As Ubyte , isDown As Bool) 
Declare Sub pxaKpcJogInput( kpc As _PxaKpc Ptr , jogIdx As Ubyte , up As Bool) 	'else down





'  ************  _PXA270_UDC_H_
'Type As Any Ptr Pxa270Udc 
Declare Function pxa270UdcInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _Pxa270Udc ptr 





'  ************  _PXA270_WMMX_H_
'Type As Any Ptr Pxa270wmmx 
Declare Function pxa270wmmxInit( cpu As ArmCpu Ptr) As _Pxa270wmmx ptr 




'  ************  _PXA_DMA_H_
'common
#define DMA_CMR_DREQ_0			0
#define DMA_CMR_DREQ_1			1
#define DMA_CMR_I2S_RX			2
#define DMA_CMR_I2S_TX			3
#define DMA_CMR_BTUART_RX		4
#define DMA_CMR_BTUART_TX		5
#define DMA_CMR_FFUART_RX		6
#define DMA_CMR_FFUART_TX		7
#define DMA_CMR_AC97_MIC		8
#define DMA_CMR_AC97_MODEM_RX	9
#define DMA_CMR_AC97_MODEM_TX	10
#define DMA_CMR_AC97_AUDIO_RX	11
#define DMA_CMR_AC97_AUDIO_TX	12
#define DMA_CMR_SSP_RX			13
#define DMA_CMR_SSP_TX			14
#define DMA_CMR_FICP_RX			17
#define DMA_CMR_FICP_TX			18
#define DMA_CMR_STUART_RX		19
#define DMA_CMR_STUART_TX		20
#define DMA_CMR_MMC_RX			21
#define DMA_CMR_MMC_TX			22

'PXA25x and PXA26x
#define DMA_CMR_NSSP_RX			15
#define DMA_CMR_NSSP_TX			16
#define DMA_CMR_USB_EP1_TX		25
#define DMA_CMR_USB_EP2_RX		26
#define DMA_CMR_USB_EP3_TX		27
#define DMA_CMR_USB_EP4_RX		28
#define DMA_CMR_USB_EP6_TX		30
#define DMA_CMR_USB_EP7_RX		31
#define DMA_CMR_USB_EP8_TX		32
#define DMA_CMR_USB_EP9_RX		33
#define DMA_CMR_USB_EP11_TX		35
#define DMA_CMR_USB_EP12_RX		36
#define DMA_CMR_USB_EP13_TX		37
#define DMA_CMR_USB_EP14_RX		38

'PXA26x
#define DMA_CMR_ASSP_RX			23
#define DMA_CMR_ASSP_TX			24

'PXA27x
#define DMA_CMR_SSP2_RX			15
#define DMA_CMR_SSP2_TX			16
#define DMA_CMR_USB_EP0			24
#define DMA_CMR_USB_EPA			25
#define DMA_CMR_USB_EPB			26
#define DMA_CMR_USB_EPC			27
#define DMA_CMR_USB_EPD			28
#define DMA_CMR_USB_EPE			29
#define DMA_CMR_USB_EPF			30
#define DMA_CMR_USB_EPG			31
#define DMA_CMR_USB_EPH			32
#define DMA_CMR_USB_EPI			33
#define DMA_CMR_USB_EPJ			34
#define DMA_CMR_USB_EPK			35
#define DMA_CMR_USB_EPL			36
#define DMA_CMR_USB_EPM			37
#define DMA_CMR_USB_EPN			38
#define DMA_CMR_USB_EPP			39
#define DMA_CMR_USB_EPQ			40
#define DMA_CMR_USB_EPR			41
#define DMA_CMR_USB_EPS			42
#define DMA_CMR_USB_EPT			43
#define DMA_CMR_USB_EPU			44
#define DMA_CMR_USB_EPV			45
#define DMA_CMR_USB_EPW			46
#define DMA_CMR_USB_EPX			47
#define DMA_CMR_MSL_1_RX		48
#define DMA_CMR_MSL_1_TX		49
#define DMA_CMR_MSL_2_RX		50
#define DMA_CMR_MSL_2_TX		51
#define DMA_CMR_MSL_3_RX		52
#define DMA_CMR_MSL_3_TX		53
#define DMA_CMR_MSL_4_RX		54
#define DMA_CMR_MSL_4_TX		55
#define DMA_CMR_MSL_5_RX		56
#define DMA_CMR_MSL_5_TX		57
#define DMA_CMR_MSL_6_RX		58
#define DMA_CMR_MSL_6_TX		59
#define DMA_CMR_MSL_7_RX		60
#define DMA_CMR_MSL_7_TX		61
#define DMA_CMR_USIM_RX			62
#define DMA_CMR_USIM_TX			63
#define DMA_CMR_MS_RX			64
#define DMA_CMR_MS_TX			65
#define DMA_CMR_SSP3_RX			66
#define DMA_CMR_SSP3_TX			67
#define DMA_CMR_QCIF_RX_0		68
#define DMA_CMR_QCIF_RX_1		69
#define DMA_CMR_QCIF_RX_2		70
#define DMA_CMR_DREQ_2			74





'  ************  _PXA_IC_H_
#define PXA_I_CIF			33	' PXA27x

#define PXA_I_RTC_ALM	31
#define PXA_I_RTC_HZ		30
#define PXA_I_TIMR3		29
#define PXA_I_TIMR2		28
#define PXA_I_TIMR1		27
#define PXA_I_TIMR0		26
#define PXA_I_DMA			25
#define PXA_I_SSP			24
#define PXA_I_MMC			23
#define PXA_I_FFUART		22
#define PXA_I_BTUART		21
#define PXA_I_STUART		20
#define PXA_I_ICP			19
#define PXA_I_I2C			18
#define PXA_I_LCD			17
#define PXA_I_NSSP		16	'PXA25x\PXA26x
#define PXA_I_SSP2		16	'PXA27x
#define PXA_I_ASSP		15	'PXA26x
#define PXA_I_USIM		15	'PXA27x
#define PXA_I_AC97		14
#define PXA_I_I2S			13
#define PXA_I_PMU			12
#define PXA_I_USB			11
#define PXA_I_GPIO_all	10
#define PXA_I_GPIO_1		9
#define PXA_I_GPIO_0		8
#define PXA_I_HWUART		7	'PXA25x\PXA26x
#define PXA_I_TIMR4_11	7	'PXA27x
#define PXA_I_PWR_I2C	6	'PXA27x
#define PXA_I_MS			5	'PXA27x
#define PXA_I_KEYPAD		4	'PXA27x
#define PXA_I_USBH1		3	'PXA27x
#define PXA_I_USBH2		2	'PXA27x
#define PXA_I_MSL			1	'PXA27x
#define PXA_I_SSP3		0	'PXA27x




'  ************  _PXA_LCD_H_
'Type As Any Ptr PxaLcd 
Declare Function pxaLcdInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , hardGrafArea As Bool) As _PxaLcd ptr 
Declare Sub pxaLcdFrame( lcd As _PxaLcd Ptr) 




'  ************  _PXA_MEM_CTRL_H_
'Type As Any Ptr PxaMemCtrlr 
Declare Function pxaMemCtrlrInit( physMem As _ArmMem Ptr , socRev As Ubyte) As _PxaMemCtrlr ptr




'  ************  _PXA_MMC_H_
'Type As Any Ptr PxaMmc 
Declare Function pxaMmcInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _PxaMmc ptr 

Declare Sub pxaMmcInsert( mmc As _PxaMmc Ptr , vsd As _VSD2 Ptr) 	'NULL also acceptable




'  ************  _PXA_PWM_H_
#define PXA_PWM0_BASE	&h40B00000UL
#define PXA_PWM1_BASE	&h40C00000UL
'PXA27x only
#define PXA_PWM2_BASE	&h40B00010UL
#define PXA_PWM3_BASE	&h40C00010UL

'Type As Any Ptr PxaPwm 
Declare Function pxaPwmInit( physMem As _ArmMem Ptr , bases As ULong) As _PxaPwm ptr 




'  ************  _PXA_PWR_CLK_H_
'Type As Any Ptr PxaPwrClk 
Declare Function pxaPwrClkInit( cpu As ArmCpu Ptr ,  physMem As _ArmMem Ptr , isPXA270 As Bool) As _PxaPwrClk ptr 




'  ************  _PXA_RTC_H_
'Type As Any Ptr PxaRtc 
Declare Function pxaRtcInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr) As _PxaRtc ptr 
Declare sub pxaRtcUpdate( rtc As _PxaRtc Ptr)




'  ************  _PXA_SSP_H_
'PXA25x\PXA26x\PXA27x
#define PXA_SSP1_BASE	&h41000000UL

'PXA25x\PXA26x
#define PXA_NSSP_BASE	&h41400000UL

'PXA26x
#define PXA_ASSP_BASE	&h41500000UL

'PXA27x
#define PXA_SSP2_BASE	&h41700000UL
#define PXA_SSP3_BASE	&h41900000UL





'  ************  _PXA_TIMR_H_
'Type As Any Ptr PxaTimr 
Declare Function pxaTimrInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr) As _PxaTimr ptr
Declare Sub pxaTimrTick( timr As _PxaTimr Ptr) 




'  ************  _PXA_UART_H_
'	PXA255 UARTs
'	
'	They are identical, but at diff base addresses. this implements one. instanciate more than one to make all 3 work if needed.
'
'	by default we read nothing and write nowhere (buffer drains fast into nothingness)
'	this can be changed by addidng appropriate callbacks
#define PXA_FFUART_BASE	&h40100000UL
#define PXA_BTUART_BASE	&h40200000UL
#define PXA_STUART_BASE	&h40700000UL
#define PXA_HWUART_BASE	&h41600000UL		'PXA25x\PXA26x only




'  ************  _RAM_H_
'Type As Any Ptr ArmRam 
Declare Function ramInit( mem As _ArmMem Ptr , adr As ULong , sz As ULong , buf As ULong Ptr) As _ArmRam ptr




'  ************  _SOC_H_
#define CHAR_CTL_C	-1L
#define CHAR_NONE	-2L

' repetidas con vSD.BI
Type SdSectorR As Function( secNum As ULong , buf As Any Ptr) As Bool 
Type SdSectorW As Function( secNum As ULong , buf As Any Ptr) As Bool 

Declare Function socInit(romPieces As any Ptr ptr , romPieceSizes As ULong Ptr , romNumPieces As ULong , _
              sdNumSectors As ULong , sdR As SdSectorR , sdW As SdSectorW , nandFile As FILE Ptr , _
					gdbPort As Long , socRev As Ubyte) As _SoC ptr 
Declare Sub socRun( soc As _SoC Ptr) 

Declare Sub socBootload( soc As _SoC Ptr , method As ULong , param As any Ptr) 	'soc-specific

'externally needed
Declare Sub socExtSerialWriteChar(ch As Long) 
Declare Function socExtSerialReadChar() As Long 




'  ************  _SOC_AC97_H_
'Type As Any Ptr SocAC97
enum Ac97Codec 
	Ac97PrimaryAudio,
	Ac97SecondaryAudio,
	Ac97PrimaryModem,
	Ac97SecondaryModem
End enum 

Type Ac97CodecRegR  As Function( userData As Any Ptr , regAddr As ULong , regValP As uShort Ptr) As Bool 
Type Ac97CodecRegW  As Function( userData As Any Ptr , regAddr As ULong , vals As uShort) As Bool
     
Type Ac97CodecFifoR As Function( userData As Any Ptr , regValP As ULong Ptr) As Bool
Type Ac97CodecFifoW As Function( userData As Any Ptr , vals As ULong) As Bool

Declare Function socAC97Init( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _SoCAC97 ptr 
Declare Sub socAC97Periodic( ac97 As _SoCAC97 Ptr) 

'client api
Declare Sub socAC97clientAdd( ac97 As _SoCAC97 Ptr , which As Ac97Codec , regR As Ac97CodecRegR , regW As Ac97CodecRegW , userData As any Ptr) 
Declare Function socAC97clientClientWantData( ac97 As _SoCAC97 Ptr , which As Ac97Codec , dataPtr As ULong Ptr) As Bool 
Declare Sub socAC97clientClientHaveData( ac97 As _SoCAC97 Ptr , which As Ac97Codec , datas As ULong) 




'  ************  _SOC_DMA_H_
'Type As Any Ptr SocDma 
Declare Function socDmaInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr) As _SoCDma ptr 
Declare Sub socDmaPeriodic( dma As _SoCDma Ptr) 
Declare Sub socDmaExternalReq( dma As _SoCDma Ptr , chNum As Ubyte , requested As Bool) 'request a transfer burst





'  ************  _SOC_GPIO_H_
'Type As Any Ptr SocGpio 
Type GpioChangedNotifF As Sub( userData As Any Ptr , gpio As ULong , oldState As Bool , newState As Bool)
Type GpioDirsChangedF  As Sub( userData As Any Ptr)

'these values make it look like all HiZ, AFR, and nonexistent pins have pullups 
' to those who dumbly assume socGpioGetState returns a Bool
Enum SocGpioState 	
	SocGpioStateLow,
	SocGpioStateHigh,
	SocGpioStateHiZ,
	SocGpioStateAFR0,	'AFR values must be in order
	SocGpioStateAFR1,
	SocGpioStateAFR2,
	SocGpioStateAFR3,
	SocGpioStateNoSuchGpio
End Enum 

Declare Function socGpioInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , socRev As Ubyte) As _SoCGpio ptr 

'for external use :)
Declare Function socGpioGetState( gpio As _SoCGpio Ptr , gpioNum As Ubyte) As SoCGpioState 
Declare Sub socGpioSetState( gpio As _SoCGpio Ptr , gpioNum As Ubyte , on As Bool) 	'we can only set value (and only of input pins), not direction

'only for output pins!
Declare Sub socGpioSetNotif( gpio As _SoCGpio Ptr , gpioNum As Ubyte , notifF As GpioChangedNotifF , userData As any Ptr) 	'one per pin. set ot NULL to disable

'for all (but only one notifier)
Declare Sub socGpioSetDirsChangedNotif( gpio As _SoCGpio Ptr , notifF As GpioDirsChangedF , userData As any Ptr) 




'  ************  _SOC_I2C_H_
'Type As Any Ptr SocI2c
Enum ActionI2C 	'As designed so returns can be ORRed together with good results
	i2cStart,		'no params, no returns
	i2cRestart,		'no params, no returns
	i2cStop,		'no params, no returns
	i2cTx,			'param is byte master sent, return is bool "Ack"
	i2cRx			'param is "bool willBeAcked", return is byte slave sent
End Enum 

Type I2cDeviceActionF As Function( userData As Any Ptr , stimulus As ActionI2C , value As Ubyte) As Ubyte

Declare Function socI2cInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr , base As ULong , irqNo As ULong) As _SoCI2c ptr
Declare Function socI2cDeviceAdd( i2c As _SoCI2c Ptr , actF As I2cDeviceActionF, userData As any Ptr) As Bool 




'  ************  _SOC_I2S_H_
'Type As Any Ptr SocI2s 
Declare Function socI2sInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _SoCI2s ptr
Declare Sub socI2sPeriodic( i2s As _SoCI2s Ptr) 



'  ************  _SOC_IC_H_
'Type As Any Ptr SocIc 
'Declare function socIcInit(cpu As ArmCpu ptr , physMem As _ArmMem ptr, socRev as Ubyte) As _SoCIc ptr
Declare Sub socIcInt( ic As _SoCIc Ptr , intNum As Ubyte , raise As Bool) 




'  ************  _SOC_SSP_H_
'Type As Any Ptr SocSsp 
Type SspClientProcF As Function( userData As Any Ptr , nBits As Ubyte , sent As Short) As Short

Declare Function socSspInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr ,  dma As _SoCDma Ptr , bases As ULong , irqNo As Ubyte , dmaReqNoBase As Ubyte) As _SoCSsp ptr 
Declare Sub socSspPeriodic( ssp As _SoCSsp Ptr) 
Declare Function socSspAddClient( ssp As _SoCSsp Ptr , procF As SspClientProcF , userData As any Ptr) As Bool 




'  ************  _SOC_UART_H_
'Type As Any Ptr SocUart 
#define UART_CHAR_BREAK			&h800
#define UART_CHAR_FRAME_ERR	&h400
#define UART_CHAR_PAR_ERR		&h200
#define UART_CHAR_NONE			&h100

Type SocUartReadF As Function( userData As Any Ptr) As UShort
Type SocUartWriteF As Sub( chrs As Ushort , userData As Any Ptr)

Declare Function socUartInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , baseAddr As ULong , irq As uByte) As _SoCUart ptr 
Declare Sub socUartProcess( uart As _SoCUart Ptr) 		'write out data in TX fifo and read data into RX fifo

Declare Sub socUartSetFuncs( uart As _SoCUart Ptr , readF As _SoCUartReadF , writeF As _SoCUartWriteF , userData As any Ptr) 




'  ************  _SOC_UWIRE_H_
'Type As Any Ptr SocUwire 

'uWire is SPI with a higher-level protocol. we use ssp-like callbacks but this is not quite ssp, namely bits in and bits out will differ

'if both bits are negative, sent says nonzero if we were selected, 0 if we were deselected
Type UWireClientProcF As Function( userData As Any Ptr , bitsToDev As Ubyte , bitsFromDev As Ubyte , sent As Ushort) As UShort

Declare Function socUwireInit( physMem As _ArmMem Ptr , ic As _SoCIc Ptr , dma As _SoCDma Ptr) As _SoCUwire ptr 
Declare Sub socUwirePeriodic( uw As _SoCUwire Ptr) 
Declare Function socUwireAddClient( uw As _SoCUwire Ptr , cs As Ubyte , procF As UWireClientProcF , userData As any Ptr) As Bool 




'  ************  _VIRTUAL_SD_H_
'Type As Any Ptr VSD2 
enum SdReplyType 
	SdReplyNone,
	SdReply48bits,				'R1,R6,R7 (have checksum), R3 (no checksum)
	SdReply48bitsAndBusy,		'R1b
	SdReply136bits				'R2
End enum 

Enum SdDataReplyType 
	SdDataOk,
	SdDataErrWrongBlockSize,
	SdDataErrWrongCurrentState,
	SdDataErrBackingStore
End Enum 

' nota: repetidas con SOC.BI
Type SdSectorR As Function( secNum As ULong , buf As Any Ptr) As Bool
Type SdSectorW As Function( secNum As ULong , buf As Any Ptr) As Bool

Declare Function vsdInit(ssec as SdSectorR , sds as SdSectorW , nSec As ULong) As _VSD2 ptr

Declare Function vsdCommand( vsd As _VSD2 Ptr , commands As uByte , param As ULong , replyOut As any Ptr) As SdReplyType  ' replyOut should be big enough for any reply
Declare Function vsdIsCardBusy( vsd As _VSD2 Ptr) As Bool 
Declare Function vsdDataXferBlockToCard( vsd As _VSD2 Ptr , datas As any Ptr , blockSz As ULong) As SdDataReplyType 
Declare Function vsdDataXferBlockFromCard( vsd As _VSD2 Ptr , datas As any Ptr , blockSz As ULong) As SdDataReplyType 

'util
Declare Function vsdCRC7( datas As uByte Ptr , sz As ULong) As uByte 

