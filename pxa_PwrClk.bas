'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxaPwrClkPrvCoproc7regXferFunc(cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , read_ As Bool , _
	    op1 As UByte , Rx As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
	'PSFS read?
	'real hardware ignores CRm if CRn is 4, so do we
	if (read_<>0) AndAlso (two=0) AndAlso (op1=0) AndAlso (op2=0) AndAlso (CRn = 4) Then 
		cpuSetReg(cpu, Rx, 0) 
		return true 
	EndIf
  
	return false 
End Function

Function pxaPwrClkPrvCoproc14regXferFunc(cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , read_ As Bool , op1 As UByte , _
														Rx As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
   dim As PxaPwrClk ptr pc = cast(PxaPwrClk ptr,userData) 
	Dim As ULong valor = 0 
	
	if (read_=0) Then valor = cpuGetRegExternal(cpu, Rx)
  
	if (CRm = 0) AndAlso (op1 = 0) AndAlso (two=0) Then 
		Select Case As Const (CRn) 
			case 6 
				if (op2 <> 0) Then exit select
				if (read_) Then 
					valor = 0 
				else
					pc->turbo = iif((valor And 1) <> 0 ,1,0)
					if (valor And 2) Then printf(!"Set speed mode (CCCR + cp14 reg6) to 0x%08lx 0x%08lx\n", pc->CCCR, valor)
				EndIf
				goto success 
			
			case 7 
				if (read_) Then 
					valor = 0 
				ElseIf (valor = 1) AndAlso (op2 = 0) Then
					'idle
				ElseIf (valor = 3) AndAlso (op2 = 0) Then
					MiPrint "SLEEPING. PRESS A KEY HERE TO RESUME (we'll pick a reason for you)" 
					Sleep 
					MiPrint "RESUMING"
					'pretend we woke up
					pc->RCSR Or= 4 
					cpuReset(pc->cpu, 0) 
				ElseIf (op2 = 0) Then
					printf(!"Someone tried to set processor power mode (cp14 reg7) to 0x%08lx\n", valor) 
				EndIf
				goto success 
			
			case 10 'notifies debugger about shit. if no debugger we just continue
				if (op2 <> 0) Then exit select
				if (read_) Then valor = 0
				goto success 
      End Select

	EndIf
  
	return false 

success: 
	
	if(read_) Then 
		cpuSetReg(cpu, Rx, valor)
	EndIf
  
	return true 
End Function

Function pxaPwrClkPrvClockMgrMemAccessF( userData As Any Ptr , pa As ULong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
   dim As PxaPwrClk ptr pc = cast(PxaPwrClk ptr,userData)
	Dim As ULong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_CLOCK_MANAGER_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
	EndIf
  
	Select Case As Const (pa) 
		case 0 		'CCCR
			if (write_) Then 
				pc->CCCR = valor 
			else
				valor = pc->CCCR
			EndIf
		
		case 1 		'CKEN
			if (write_) Then 
				pc->CKEN = valor 
			else
				valor = pc->CKEN
			EndIf
		
		case 2 		'OSCR
			if (write_=0) Then 
				valor = pc->OSCR 'no writing to this register
			EndIf
   End Select

	if (write_=0) Then *cast(ULong ptr,buf) = valor
	
	return true 
End Function

Function pxaPwrClkPrvPowerMgrMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   Dim As PxaPwrClk Ptr pc = Cast(PxaPwrClk Ptr,userData )
	Dim As ULong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_POWER_MANAGER_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
	EndIf
  
	Select Case As Const  (pa)  
		case &h00 'PMCR
			if (write_) Then 
				pc->PMCR = valor And iif(pc->isPXA270 , &h3f , &h01) 
			else
				valor = pc->PMCR
			EndIf
		
		case &h04 \ 4 	'PSSR
			if (write_) Then 
				pc->PSSR And= INV( valor )
			else
				valor = pc->PSSR
			EndIf
		
		case &h08 \ 4 	'PSPR
			if (write_) Then 
				pc->PSPR = valor 
			else
				valor = pc->PSPR
			endIf

		case &h0c \ 4 	'PWER
			if (write_) Then 
				pc->PWER = valor And iif(pc->isPXA270 , &hdf9ffe1b , &hf000ffff) 
			else
				valor = pc->PWER
			EndIf

		case &h10 \ 4 	'PRER
			if (write_) Then 
				pc->PRER = valor And iif(pc->isPXA270 , &h0100fe1b , &h0000ffff) 
			else
				valor = pc->PRER
			EndIf
		
		case &h14 \ 4 	'PFER
			if (write_) Then 
				pc->PFER = valor And iif(pc->isPXA270 , &h0100fe1b , &h0000ffff) 
			else
				valor = pc->PFER
			EndIf
		
		case &h18 \ 4 	'PEDR
			if (write_) Then 
				pc->PEDR And= INV( valor )
			else
				valor = pc->PEDR
			EndIf
		
		case &h1c \ 4 	'PCFR
			if (write_) Then 
				pc->PCFR = valor And iif(pc->isPXA270 , &hdcd7 , &h0007) 
			else
				valor = pc->PCFR
			EndIf
		
		
		
		case &h2c \ 4 	'PGSR[3]
			if pc->isPXA270=0 Then return false
			valor And= &h01ffffff 
			'Cascada_CASE 28,24,20
			if (write_) Then 
				pc->PGSR(pa - &h20 \ 4) = valor 
			else
				valor = pc->PGSR(pa - &h20 \ 4)
			EndIf

		case  &h28 \ 4 ,_	'PGSR[2]
				&h24 \ 4 ,_	'PGSR[1]
				&h20 \ 4 	'PGSR[0]
			if (write_) Then 
				pc->PGSR(pa - &h20 \ 4) = valor 
			else
				valor = pc->PGSR(pa - &h20 \ 4)
			EndIf
		
		
		
		
		case &h30 \ 4 	'RCSR
			if (write_) Then 
				pc->RCSR And= INV( valor )
			else
				valor = pc->RCSR
			EndIf
		
		case &h34 \ 4 	'PMFW (pxa255) \ PSLR (pxa270)
			if (write_) Then 
				pc->PMFW = valor And iif(pc->isPXA270 , &hffd00f0c , &h00000002) 
			else
				valor = pc->PMFW
			EndIf
		
		case &h38 \ 4 	'PSTR
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PSTR = valor And &h00000f0c 
			else
				valor = pc->PSTR
			EndIf
		
		case &h40 \ 4 	'PVCR (we do not emulate the actual PM i2c bus)
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PVCR = valor And &h01f04fff 
			else
				valor = pc->PVCR
			EndIf
		
		case &h4c \ 4 	'PUCR
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PUCR = valor And &h0000002d 
			else
				valor = pc->PUCR
			EndIf
		
		case &h50 \ 4 	'PKWR
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PKWR = valor And &h000fffff 
			else
				valor = pc->PKWR
			EndIf
		
		case &h54 \ 4 	'PKSR
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PKWR And= INV( valor )
			else
				valor = pc->PKSR
			EndIf
		
		case (&h80 \ 4) to (&hfc \ 4) 
			if pc->isPXA270=0 Then return false
			if (write_) Then 
				pc->PCMD(pa - &h80 \ 4) = valor And &h00001fff 
			else
				valor = pc->PCMD(pa - &h80 \ 4)
			EndIf
		
		case else 
			return false 
   End Select

	if (write_=0) Then *cast(ULong ptr,buf) = valor

	return true 
End Function

 
Function pxaPwrClkInit( cpu As ArmCpu Ptr , physMem As ArmMem Ptr , isPXA270 As Bool) As PxaPwrClk ptr
	dim as PxaPwrClk ptr pc = cast(PxaPwrClk ptr,Callocate(sizeof(PxaPwrClk)) )
	
	Dim As ArmCoprocessor cp14
	with cp14
		.regXfer  = cast(ArmCoprocRegXferF,@pxaPwrClkPrvCoproc14regXferFunc)
		.userData = pc
	End With
	
	Dim As ArmCoprocessor cp7 
	With cp7 
		.regXfer  = cast(ArmCoprocRegXferF,@pxaPwrClkPrvCoproc7regXferFunc)
		.userData = pc
	End With
	
	if pc=0 Then PERR("cannot alloc PWRCLKMGR CP7\14")

	memset(pc, 0, sizeof(PxaPwrClk)) 
	
	pc->cpu = cpu 
	pc->isPXA270 = isPXA270 
	pc->CCCR = &h00000122UL 	'set CCCR to almost default value (we use mult 32 not 27)
	pc->CKEN = &h000179EFUL 	'set CKEN to default value
	pc->OSCR = &h00000003UL 	'32KHz oscillator on and stable
	pc->PSSR = &h20 
	pc->PWER = &h03 
	pc->PRER = &h03 
	pc->PFER = &h03 
	pc->PMFW = iif(isPXA270 , &hcc000000 , &h00000000 )
	
	'pretend we just power-no-resetted
	pc->RCSR Or= 1 
	
	cpuCoprocessorRegister(cpu, 14, @cp14) 
	cpuCoprocessorRegister(cpu,  7, @cp7 ) 
	
	if memRegionAdd(physMem, PXA_CLOCK_MANAGER_BASE, PXA_CLOCK_MANAGER_SIZE, cast(ArmMemAccessF ,@pxaPwrClkPrvClockMgrMemAccessF), pc)=0 Then 
		PERR("cannot add CLKMGR to MEM")
	EndIf
  
	
	if memRegionAdd(physMem, PXA_POWER_MANAGER_BASE, PXA_POWER_MANAGER_SIZE, cast(ArmMemAccessF ,@pxaPwrClkPrvPowerMgrMemAccessF), pc)=0 Then 
		PERR("cannot add PWRMGR to MEM")
	EndIf
  

	return pc 
End Function
