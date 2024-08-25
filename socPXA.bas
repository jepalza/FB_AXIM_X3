'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function socUartPrvRead( userData As Any Ptr) As Ushort
	Dim As Ushort v 
	Dim As Long r 

	r = socExtSerialReadChar() 
	
	if (r = CHAR_CTL_C) Then 
		v = UART_CHAR_BREAK 
	ElseIf (r = CHAR_NONE) Then
		v = UART_CHAR_NONE 
	ElseIf (r >= &h100) Then
		v = UART_CHAR_NONE 		'we canot send this char!!!
	else
		v = r
	EndIf
  
	return v 
End Function

Sub socUartPrvWrite(Chr_ As Ushort , userData As Any Ptr)
	if (Chr_ = UART_CHAR_NONE) Then return
	socExtSerialWriteChar(Chr_) 
End Sub

static shared As ULong romWriteIgnoreData(63) '= {0} 
Function socInit(romPieces As any ptr Ptr , romPieceSizes As ULong Ptr , romNumPieces As ULong , sdNumSectors As ULong , _ 
					sdR As SdSectorR , sdW As SdSectorW , nandFile As FILE Ptr , gdbPort As Long , socRev As UByte) As _SoC ptr

	Dim As SoC_T ptr soc = cast(SoC_T ptr,Callocate(sizeof(SoC_T))) 
	Dim As ULong romWriteIgnoreDataSz = sizeof(ULong)*(ubound(romWriteIgnoreData)+1)
	dim as any ptr romWriteIgnoreDataPtr = @romWriteIgnoreData(0)
	dim as SocPeriphs sp '= {0}
	Dim As ULong ptr ramBuffer 

	memset(soc, 0, sizeof(SoC_T)) 

	soc->mem = memInit() 
	if (soc->mem=0) Then PERR("Cannot init physical memory manager")


	' inicia el SOC PXA de la CPU
   ' ----------------------------------- XSCALE  OMAP  ------------------------------socRev = 1 = AXIM-X3         --socrev=2     --socrev=0
	soc->cpu = cpuInit(ROM_BASE, soc->mem, TRUE , FALSE , gdbPort, IIf(socRev>0 , iif(socRev = 1 , CPUID_PXA260 , CPUID_PXA270) , CPUID_PXA255) , &h0B16A16A) 
	if (soc->cpu=0) Then PERR("Cannot init CPU")
	print "dir cpu en socinit1: ";hex(soc->cpu->coproc(15),8),hex(soc->cpu->coproc(15)->regXfer,8),hex(soc->cpu->coproc(15)->userdata,8)

	ramBuffer = cast(ULong ptr,Callocate(deviceGetRamSize())) 
	if (ramBuffer=0) Then PERR("cannot alloc RAM space")

	soc->ram = ramInit(soc->mem, RAM_BASE, deviceGetRamSize(), ramBuffer) 
	if (soc->ram=0) Then PERR("Cannot init RAM")

	Select Case As Const  (deviceGetRamTerminationStyle())  
		case RamTerminationMirror
			'ram mirror for ram probe code
			soc->ramMirror = ramInit(soc->mem, RAM_BASE + deviceGetRamSize(), deviceGetRamSize(), ramBuffer) 
			if (soc->ramMirror=0) Then PERR("Cannot init RAM mirror")
		
		case RamTerminationWriteIgnore 
			soc->ramWriteIgnore = romInit(soc->mem, RAM_BASE + deviceGetRamSize(), @romWriteIgnoreDataPtr, @romWriteIgnoreDataSz, 1, RomWriteIgnore) 
			if (soc->ramWriteIgnore=0) Then PERR("Cannot init RAM WI arwa")
		
		case RamTerminationNone 
			' nada
	
		case else 
			'__builtin_unreachable() ' necesario?
   End Select
	
	' ROM ------------------------	
	soc->rom = romInit(soc->mem, ROM_BASE, romPieces, romPieceSizes, romNumPieces, deviceGetRomMemType()) 
	if (soc->rom=0) Then PERR("Cannot init ROM1")
	
	' *************************************
	' desconozco aun el motivo, pero parece un fallo de freebasic:
	' la variable COPROC() se pierde al salir de la anterior llamada ROMINIT
	' como ne he localidado el fallo aun, hago una reparacion manual de urgencia
	print "dir cpu en socinit2: ";hex(soc->cpu->coproc(15),8),hex(soc->cpu->coproc(15)->regXfer,8),hex(soc->cpu->coproc(15)->userdata,8)
	' guardo las variables que "se van a perder" del COPRO 15
	dim as ulong ptr regXfer_copia =cast(ulong ptr,soc->cpu->coproc(15)->regXfer)
	dim as ulong ptr userdata_copia=cast(ulong ptr,soc->cpu->coproc(15)->userdata)
	' *************************************
	
	' IC -------------------------------
	soc->ic = socIcInit(soc->cpu, soc->mem, socRev) 
	dim as byte pp2(32*1024)
	if (0=soc->ic) Then PERR("Cannot init PXA's IC")
  	print "dir cpu en socinit3: ";hex(soc->cpu->coproc(15),8),hex(soc->cpu->coproc(15)->regXfer,8),hex(soc->cpu->coproc(15)->userdata,8)

	' DMA -------------------------------
	soc->dma = socDmaInit(soc->mem, soc->ic) 
	if (0=soc->dma) Then PERR("Cannot init PXA's DMA")
	
	' DSP,WMMX,IMC,KPC ------------------------
	if (socRev = 0) OrElse (socRev = 1) Then   
		soc->dsp = pxa255dspInit(soc->cpu) ' AXIM-X3
		if (soc->dsp=0) Then PERR("Cannot init PXA255's DSP") 
	ElseIf (socRev = 2) Then
		soc->wmmx = pxa270wmmxInit(soc->cpu) 
		if (soc->wmmx=0) Then PERR("Cannot init PXA270's WMMX")
		soc->imc = pxaImcInit(soc->mem) 
		if (soc->imc=0) Then PERR("Cannot init PXA270's IMC")
		soc->kpc = pxaKpcInit(soc->mem, soc->ic) 
		if (soc->kpc=0) Then PERR("Cannot init PXA270's KPC")
		'SRAM
		ramBuffer = Cast(ULong ptr,Callocate(SRAM_SIZE) )
		if (ramBuffer=0) Then PERR("cannot alloc SRAM space")
		soc->sram = ramInit(soc->mem, SRAM_BASE, SRAM_SIZE, ramBuffer) 
		if (soc->sram=0) Then PERR("Cannot init SRAM")
	EndIf

   ' GPIO ----------------------------
	soc->gpio = socGpioInit(soc->mem, soc->ic, socRev) 
	if (soc->gpio=0) Then PERR("Cannot init PXA's GPIO")
	
	' TMR ---------------------------------
	soc->tmr = pxaTimrInit(soc->mem, soc->ic) 
	if (soc->tmr=0) Then PERR("Cannot init PXA's OSTIMER")
	
	' RTC ---------------------------------
	soc->rtc = pxaRtcInit(soc->mem, soc->ic) 
	if (soc->rtc=0) Then PERR("Cannot init PXA's RTC")
	
	' UART ---------------------------------
	soc->ffUart = socUartInit(soc->mem, soc->ic, PXA_FFUART_BASE, PXA_I_FFUART) 
	if (soc->ffUart=0) Then PERR("Cannot init PXA's FFUART")
	if (socRev <> 2) Then 
		soc->hwUart = socUartInit(soc->mem, soc->ic, PXA_HWUART_BASE, PXA_I_HWUART) 
		if (soc->hwUart=0) Then PERR("Cannot init PXA's HWUART")
	EndIf
	'
	soc->stUart = socUartInit(soc->mem, soc->ic, PXA_STUART_BASE, PXA_I_STUART) 
	if (soc->stUart=0) Then PERR("Cannot init PXA's STUART")
	soc->btUart = socUartInit(soc->mem, soc->ic, PXA_BTUART_BASE, PXA_I_BTUART) 
	if (soc->btUart=0) Then PERR("Cannot init PXA's BTUART")
	
	' PWR-CLK --------------------------	
	soc->pwrClk = pxaPwrClkInit(soc->cpu, soc->mem, iif(socRev = 2,1,0)) 
	if (soc->pwrClk=0) Then PERR("Cannot init PXA's PWRCLKMGR")
	
	if (socRev = 2) Then 
		soc->pwrI2c = socI2cInit(soc->mem, soc->ic, soc->dma, PXA_PWR_I2C_BASE, PXA_I_PWR_I2C) 
		if (soc->pwrI2c=0) Then PERR("Cannot init PXA Pwr's I2C")
	EndIf
	
	' I2C -------------------------------
	soc->i2c = socI2cInit(soc->mem, soc->ic, soc->dma, PXA_I2C_BASE, PXA_I_I2C) 
	if (soc->i2c=0) Then PERR("Cannot init PXA's I2C")
	soc->memCtrl = pxaMemCtrlrInit(soc->mem, socRev) 
	if (soc->memCtrl=0) Then PERR("Cannot init PXA's MEMC")
	soc->ac97 = socAC97Init(soc->mem, soc->ic, soc->dma) 
	if (soc->ac97=0) Then PERR("Cannot init PXA's AC97")

	' SSP\SSP1 ------------------------------
	soc->ssp(0) = socSspInit(soc->mem, soc->ic, soc->dma, PXA_SSP1_BASE, PXA_I_SSP, DMA_CMR_SSP_RX) 
	if (soc->ssp(0)=0) Then PERR("Cannot init PXA's SSP1")
	if (socRev = 0) OrElse (socRev = 1) Then 
		'NSSP
		soc->ssp(1) = socSspInit(soc->mem, soc->ic, soc->dma, PXA_NSSP_BASE, PXA_I_NSSP, DMA_CMR_NSSP_RX) 
		if (soc->ssp(1)=0) Then PERR("Cannot init PXA's NSSP")
		soc->udc1 = pxa255UdcInit(soc->mem, soc->ic, soc->dma) 
		if (soc->udc1=0) Then PERR("Cannot init PXA255's UDC")
	EndIf
  
	' ASSP  ------------------------------
	if (socRev = 1) Then 
		soc->ssp(2) = socSspInit(soc->mem, soc->ic, soc->dma, PXA_ASSP_BASE, PXA_I_ASSP, DMA_CMR_ASSP_RX) 
		if (soc->ssp(2)=0) Then PERR("Cannot init PXA26x's ASSP")
	EndIf
  
	' SSP -----------------------------
	if (socRev = 2) Then 
		'SSP2
		soc->ssp(1) = socSspInit(soc->mem, soc->ic, soc->dma, PXA_SSP2_BASE, PXA_I_SSP2, DMA_CMR_SSP2_RX) 
		if (soc->ssp(1)=0) Then PERR("Cannot init PXA27x's SSP2")
		'SSP3
		soc->ssp(2) = socSspInit(soc->mem, soc->ic, soc->dma, PXA_SSP3_BASE, PXA_I_SSP3, DMA_CMR_SSP3_RX) 
		if (soc->ssp(2)=0) Then PERR("Cannot init PXA27x's SSP3")
		soc->udc2 = pxa270UdcInit(soc->mem, soc->ic, soc->dma) 
		if (soc->udc2=0) Then PERR("Cannot init PXA270's UDC")
	EndIf

	' IS2 ------------------------
	soc->i2s = socI2sInit(soc->mem, soc->ic, soc->dma)
	if (soc->i2s=0) Then PERR("Cannot init PXA's I2S")
	
	' PWM -------------------------------
	soc->pwm(0) = pxaPwmInit(soc->mem, PXA_PWM0_BASE) 
	if (soc->pwm(0)=0) Then PERR("Cannot init PXA's PWM0")
	'
	soc->pwm(1) = pxaPwmInit(soc->mem, PXA_PWM1_BASE) 
	if (soc->pwm(1)=0) Then PERR("Cannot init PXA's PWM1")
	'
	if (socRev = 2) Then 
		soc->pwm(2) = pxaPwmInit(soc->mem, PXA_PWM2_BASE) 
		if (soc->pwm(2)=0) Then PERR("Cannot init PXA's PWM2")
		soc->pwm(3) = pxaPwmInit(soc->mem, PXA_PWM3_BASE) 
		if (soc->pwm(3)=0) Then PERR("Cannot init PXA's PWM3")
	EndIf
  
	' MMC ---------------------------
	soc->mmc = pxaMmcInit(soc->mem, soc->ic, soc->dma) 
	if (soc->mmc=0) Then PERR("Cannot init PXA's MMC")
	
	' LCD --------------------------
	soc->lcd = pxaLcdInit(soc->mem, soc->ic, deviceHasGrafArea()) 
	if (soc->lcd=0) Then PERR("Cannot init PXA's LCD")
	
	' KEYPAD -----------------------
	soc->kp = keypadInit(soc->gpio, true) 
	if (soc->kp=0) Then PERR("Cannot init keypad controller")
	
	' SDCARD -----------------------
	if (sdNumSectors) Then 
		soc->vSD = vsdInit(sdR, sdW, sdNumSectors) 
		if (soc->vSD=0) Then PERR("Cannot init vSD")
		pxaMmcInsert(soc->mmc, soc->vSD) 
	EndIf

	sp.mem  = soc->mem 
	sp.gpio = soc->gpio 
	sp.i2c  = soc->i2c 
	sp.i2s  = soc->i2s 
	sp.ac97 = soc->ac97 
	sp.ssp  = soc->ssp(0) 
	sp.ssp2 = soc->ssp(1) 
	sp.ssp3 = soc->ssp(2) 
	
	if (socRev = 2) Then sp.kpc = soc->kpc
	
	sp.uarts(0) = soc->ffUart 
	sp.uarts(1) = soc->hwUart 
	sp.uarts(2) = soc->stUart 
	sp.uarts(3) = soc->btUart 
	
	soc->dev = deviceSetup(@sp, soc->kp, soc->vSD, nandFile)
	if (soc->dev=0) Then PERR("Cannot init device")
	
	if (sp.dbgUart) Then socUartSetFuncs(sp.dbgUart, @socUartPrvRead, @socUartPrvWrite, soc->hwUart)
	
	if (SDL_Init(SDL_INIT_EVERYTHING) < 0) Then 
		MiPrint "Couldn't initialize SDL"
		Beep:Sleep:End
	EndIf
	
	' revisar atexit(SDL_Quit) 
	
	' recupero las variables perdidas del COPRO 15
	soc->cpu->coproc(15)->regXfer =cast(any ptr,regXfer_copia)
	soc->cpu->coproc(15)->userdata=userdata_copia
	
	return soc 
End Function


' ************** Bucle Principal ***************
Dim Shared As Long press=0 
Sub socRun(soc As SoC_T Ptr)
	Dim As ULong cycles = 0 
	Dim As ubyte i 

print "dir cpu en socRun  : ";hex(soc->cpu->coproc(15),8),hex(soc->cpu->coproc(15)->regXfer,8),hex(soc->cpu->coproc(15)->userdata,8)
	
	'bucle de ejecucion de instrucciones
	while (1)  	
		cycles+=1  
		
		if (cycles And &h00000007UL)=0 Then pxaTimrTick(soc->tmr)
		if (cycles And &h000000FFUL)=0 Then 
			for i = 0 To 2        
				if (soc->ssp(i)) Then socSspPeriodic(soc->ssp(i))
         Next
		EndIf
  
		if (cycles And &h000000FFUL)=0 Then socDmaPeriodic (soc->dma)
		if (cycles And &h000007FFUL)=0 Then socAC97Periodic(soc->ac97)
		if (cycles And &h000007FFUL)=0 Then socI2sPeriodic (soc->i2s)
		if (cycles And &h000000FFUL)=0 Then 
			socUartProcess(soc->ffUart) 
			if (soc->hwUart) Then socUartProcess(soc->hwUart)
			socUartProcess(soc->stUart) 
			socUartProcess(soc->btUart) 
		EndIf
  
		devicePeriodic(soc->dev, cycles) 
	
		if (cycles And &h00001FFFUL)=0 Then pxaLcdFrame (soc->lcd)
		if (cycles And &h03FFFFFFUL)=0 Then pxaRtcUpdate(soc->rtc)
		if (cycles And &h0000FFFFUL)=0 Then 
			Dim As SDL_Event events 
			if (SDL_PollEvent(@events)) Then 
				Select Case As Const (events.type)
					case SDL_QUIT_
						Print "FIN...":sleep:end
					
					case SDL_MOUSEBUTTONDOWN 
						if (events.button.button <> SDL_BUTTON_LEFT) Then Exit select
						soc->mouseDown = true 
						deviceTouch(soc->dev, events.button.x, events.button.y,&h0c0) 
						'jepalza
						'print "MOUSE push: ";events.button.x;events.button.y;press
					
					case SDL_MOUSEBUTTONUP 
						if (events.button.button <> SDL_BUTTON_LEFT) Then Exit select
						soc->mouseDown = false 
						deviceTouch(soc->dev, -1, -1, -1) 
						press=-1 
					
					case SDL_MOUSEMOTION 
						press+=100 
						if (press>32700) Then press=32700 
						if (soc->mouseDown=0) Then exit select
						deviceTouch(soc->dev, events.motion.x, events.motion.y,&hc0) 
						'print "MOUSE move: ";events.button.x;events.button.y;press) 
					
					case SDL_KEYDOWN 
						deviceKey(soc->dev, events.key.keysym.sym, true) 
						keypadSdlKeyEvt(soc->kp, events.key.keysym.sym, true) 
					
					case SDL_KEYUP 
						deviceKey(soc->dev, events.key.keysym.sym, false) 
						keypadSdlKeyEvt(soc->kp, events.key.keysym.sym, false) 
            End Select
			EndIf
		EndIf
'print "USERDATA antes de saltar a cpuPrvExecInstr:";hex(soc->cpu->coproc(15)->userData,8)
'dim as byte ptr pp=soc->cpu->coproc(15)->userData
'for f as ubyte=0 to 15
'	print hex(pp[f],2);" ";
'next
'print

		cpuCycle(soc->cpu) ' salta al modulo "CPU.BAS"

'		locate 1,1
'		print "ADDR:";hex(soc->cpu->regs(REG_NO_PC),8);"  INS:";HEX(ins_,8);"  "
'		print "N:";soc->cpu->N;"    "
'		print "Z:";soc->cpu->Z;"    "
'		print "C:";soc->cpu->C;"    "
'		print "V:";soc->cpu->V;"    "
'		print "Q:";soc->cpu->Q;"    "
'		print "T:";soc->cpu->T;"    "
'		print "I:";soc->cpu->I;"    "
'		print "F:";soc->cpu->F;"    "

'		if multikey(fb.SC_N) then soc->cpu->N=Iif(soc->cpu->N =1,0,1):sleep 100:endif
'		if multikey(fb.SC_Z) then soc->cpu->Z=Iif(soc->cpu->Z =1,0,1):sleep 100:endif
'		if multikey(fb.SC_C) then soc->cpu->C=Iif(soc->cpu->C =1,0,1):sleep 100:endif
'		if multikey(fb.SC_V) then soc->cpu->V=Iif(soc->cpu->V =1,0,1):sleep 100:endif
'		if multikey(fb.SC_Q) then soc->cpu->Q=Iif(soc->cpu->Q =1,0,1):sleep 100:endif
'		if multikey(fb.SC_T) then soc->cpu->T=Iif(soc->cpu->T =1,0,1):sleep 100:endif
'		if multikey(fb.SC_I) then soc->cpu->I=Iif(soc->cpu->I =1,0,1):sleep 100:endif
'		if multikey(fb.SC_F) then soc->cpu->F=Iif(soc->cpu->F =1,0,1):sleep 100:endif
   Wend
   
End Sub


