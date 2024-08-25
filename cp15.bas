'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub cp15Cycle(cp15 As ArmCP15 Ptr)	'mmu on\off lags by a cycle
	if (cp15->mmuSwitchCy) Then 
		cp15->mmuSwitchCy-=1
		if (cp15->mmuSwitchCy=0) Then 
			mmuSetTTP(cp15->mmu, iif(cp15->control_ And &h00000001UL , cp15->ttb , MMU_DISABLED_TTP) )
		EndIf
	EndIf
End Sub

Function cp15prvCoprocRegXferFunc(cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , read_ As Bool , _ 
	           op1 As UByte , Rx As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
   dim As ArmCP15 ptr cp15 = cast(ArmCP15 ptr,userData) 
	Dim As ULong valor = 0, tmp 
	
	if (read_=0) Then valor = cpuGetRegExternal(cpu, Rx)

	if (op1<>0) OrElse (two<>0) Then goto fail 'CP15 only accessed with MCR\MRC with op1 == 0
	
	Select Case As Const (CRn)  
		case 0 		'ID codes
			if (read_ = 0) Then goto fail 'cannot write to ID codes register
			if (CRm <> 0)  Then goto fail 'CRm must be zero for this read
			if (op2 = 0) Then 'main ID register
				valor = cp15->cpuid 
				goto success 
			ElseIf (op2 = 1) Then
   			'cache type register - we lie here
				valor = cp15->cacheId 
				goto success 	
			EndIf
			
		case 1 		'control register
			if (op2 = 0) AndAlso (CRm = 0) Then   
				if (read_) Then
					valor = cp15->control_ 
				else
					Dim As ULong origvalor = valor 
				
					'some bits ignore writes. pretend they were wirtten as proper
					valor Or= &h0070 
					valor And= INV( &h0080 ) 
				
					tmp = valor Xor cp15->control_ 		'see what changed and mask off then chack for what we support changing of
					if (tmp And &h84F0UL) Then 
						printf(!"cp15: unknown bits changed (0x%08lx) 0x%08lx -> 0x%08lx, halting\n", (tmp And &h84F0UL), cp15->control_, origvalor) 
						beep : sleep
					EndIf

					if (tmp And &h00002000UL) Then ' V bit
						cpuSetVectorAddr(cp15->cpu, iif(valor And &h00002000UL , &hFFFF0000UL , &h00000000UL) )
						cp15->control_ Xor= &h00002000UL 
					EndIf
  
					if (tmp And &h00000200UL) Then ' R bit
						mmuSetR(cp15->mmu, iif((valor And &h00000200UL) <> 0,1,0) ) 
						cp15->control_ Xor= &h00000200UL 
					EndIf
  
					if (tmp And &h00000100UL) Then  ' S bit
						mmuSetS(cp15->mmu, iif((valor And &h00000100UL) <> 0,1,0) )
						cp15->control_ Xor= &h00000100UL 
					EndIf
  
					if (tmp And &h00000001UL) Then  ' M bit
						cp15->mmuSwitchCy = 2 
						cp15->control_ Xor= &h00000001UL 
					EndIf
				EndIf
			ElseIf (CRm = 1) Then   
				MiPrint "sony cr1 bug?"
				if (read_) Then valor = 0 
			ElseIf (cp15->xscale<>0) AndAlso (op2 = 1) Then
				'PXA-specific thing
				if (read_) Then 
					valor = cp15->ACP 
				else
					cp15->ACP = valor
				EndIf
			else
				exit select
			EndIf
			goto success 
			
		case 2 		'translation tabler base
			if (read_) Then 
				valor = cp15->ttb 
			else
				if (cp15->control_ And &h00000001UL) Then  'mmu is on
					mmuSetTTP(cp15->mmu, valor) 
				EndIf
				cp15->ttb = valor 
			EndIf
			goto success 
		
		case 3 		'domain access control
			if (read_) Then 
				valor = mmuGetDomainCfg(cp15->mmu) 
			else
				mmuSetDomainCfg(cp15->mmu, valor)
			EndIf
			goto success 
		
		case 5 		'FSR
			if (read_) Then 
				valor = cp15->FSR 
			else
				cp15->FSR = valor
			EndIf
			goto success 
			
		case 6 		'FAR
			if (read_) Then 
				valor = cp15->FAR 
			else
				cp15->FAR = valor
			EndIf
			goto success 
		
		case 7 		'cache ops
			if ((CRm = 5) OrElse (CRm = 7)) AndAlso (op2 = 0) Then   
				icacheInval(cp15->ic) 		'invalidate entire {icache(5) or both i and dcache(7)}
				if (CRm = 7) Then
					'dcacheInval(cp15->dc)
				endif
			ElseIf ((CRm = 5) OrElse (CRm = 7)) AndAlso (op2 = 1) Then
				icacheInvalAddr(cp15->ic, valor) 	'invalidate {icache(5) or both i and dcache(7)} line, given VA
				if (CRm = 7) Then
					'dcacheInvalAddr(cp15->dc, valor)
				endif
			ElseIf ((CRm = 5) OrElse (CRm = 7)) AndAlso (op2 = 2) Then
				icacheInval(cp15->ic) 		'invalidate {icache(5) or both i and dcache(7)} line, given set\index. 
													'             i dont know how to do this, so flush the whole thing
				if (CRm = 7) Then
					'dcacheInvalSetWayRaw(cp15->dc, valor)
				endif
			ElseIf  (CRm = 10) AndAlso (op2 = 4) Then
				'drain write buffer = nothing
			ElseIf  (CRm = 10) AndAlso (op2 = 1) Then
				'dcacheCleanSetWayRaw(cp15->dc, valor)
			ElseIf  (CRm =  6) AndAlso (op2 = 0) Then
				'dcacheInval(cp15->dc)
			ElseIf  (CRm =  6) AndAlso (op2 = 1) Then
				'dcacheInvalAddr(cp15->dc, valor)
			ElseIf  (CRm =  6) AndAlso (op2 = 2) Then
				'dcacheInvalSetWayRaw(cp15->dc, valor)
			ElseIf  (CRm =  2) AndAlso (op2 = 5) Then
				'dcacheAllocAddr(cp15->dc, valor)
			ElseIf  (CRm =  5) AndAlso (op2 = 6) Then
				 'flush btb = nothing
			ElseIf  (CRm =  0) AndAlso (op2 = 4) Then
				 'idle = nothing
			ElseIf  (CRm = 14) AndAlso (op2 = 2) Then
				 ' clean and inval d-cache line
			ElseIf  (CRm = 10) AndAlso (op2 = 0) Then
				 ' clean entire d-cache - omap can do this
			ElseIf  (CRm = 10) AndAlso (op2 = 2) Then
				 ' clean d-cache line
			else
				exit select
			EndIf
			goto success 
		
		case 8 		'TLB ops
			mmuTlbFlush(cp15->mmu) 
			goto success 
		
		case 9 		'cache lockdown
			if (CRm = 1) AndAlso (op2 = 0) Then 
				printf(!"Attempt to lock 0x%08lx+32 in icache\n", valor) 
			ElseIf (CRm = 2) AndAlso (op2 = 0) Then
				printf(!"Dcache now %s lock mode\n", iif(valor , "in" , "out of") ) 
			else
				exit select
			EndIf
			goto success 
		
		case 10 	'TLB lockdown
			if (read_=0) AndAlso (CRm = 0) AndAlso ((op2 = 0) OrElse (op2 = 1)) Then goto success 
		
		case 13 	'FCSE
			if (read_) Then 
				valor = cpuGetPid(cp15->cpu) 
			else
				cpuSetPid(cp15->cpu, valor And &hfe000000ul)
			EndIf
			goto success 
		
		case 14 	'xscale debug
			if (cp15->xscale) Then 
				if (CRm = 8) AndAlso (op2 = 0) Then 'ICBR0
					valor = 0 
					goto success 
				EndIf
				if (CRm = 9) AndAlso (op2 = 0) Then 'ICBR1
					valor = 0 
					goto success 
				EndIf
				if (CRm = 0) AndAlso (op2 = 0) Then 'DBR0
					valor = 0 
					goto success 
				EndIf
				if (CRm = 3) AndAlso (op2 = 0) Then 'DBR1
					valor = 0 
					goto success 
				EndIf
				if (CRm = 4) AndAlso (op2 = 0) Then 'DBCON
					valor = 0 
					goto success 
				EndIf
			EndIf
		
		case 15 
			if (cp15->xscale<>0) AndAlso (op2 = 0) AndAlso (CRm = 1) Then  	'CPAR on xscale
				if (read_) Then
					valor = cpuGetCPAR(cp15->cpu) 
				else
					cpuSetCPAR(cp15->cpu, valor And &h3FFF)
				EndIf
				goto success 
			ElseIf (cp15->omap) Then 'omap shit
				if (CRm = 1) AndAlso (op2 = 0) Then   
					if (read_) Then
						valor = cp15->cfg 
					else
						cp15->cfg = valor And &h87
					EndIf
					goto success 
				ElseIf (CRm = 2) AndAlso (op2 = 0) Then   
					if (read_) Then
						valor = cp15->iMax 
					else
						cp15->iMax = valor
					EndIf
					goto success 
				ElseIf (CRm = 3) AndAlso (op2 = 0) Then   
					if (read_) Then
						valor = cp15->iMin 
					else
						cp15->iMin = valor
					EndIf
					goto success 
				ElseIf (CRm = 4) AndAlso (op2 = 0) Then   
					if (read_) Then
						valor = cp15->tid 
					else
						cp15->tid = valor
					EndIf
					goto success 
				ElseIf (CRm = 8) AndAlso (op2 = 0) AndAlso (read_<>0) Then   
					valor = 0 
					goto success 
				ElseIf (CRm = 8) AndAlso (op2 = 2) AndAlso (read_=0) Then
					'WFI
					goto success 
				EndIf
			EndIf
   End Select
	
fail:
	return false 

success: 
	if(read_) Then cpuSetReg(cpu, Rx, valor)

	return true 
End Function
sub pepe()
end sub
Function cp15Init(cpu As ArmCpu Ptr , mmu As ArmMmu Ptr , ic As icache Ptr , cpuid As ULong , _
	          cacheId As ULong , xscale As Bool , omap As Bool) As ArmCP15 ptr
	dim as ArmCP15 ptr cpr15 = cast(ArmCP15 ptr,Callocate(sizeof(ArmCP15))) 

	Dim as ArmCoprocessor cp15
	with cp15
		.regXfer  = cast(ArmCoprocRegXferF,@cp15prvCoprocRegXferFunc) ' funcion
		.userData = cpr15
		'.dataProcessing = NUll
		'.memAccess = NUll
		'.twoRegF = NUll
	End With
	
	if (cpr15=0) Then PERR("cannot alloc CP15")

	memset(cpr15, 0, sizeof(ArmCP15)) 

	cpr15->cpu 		= cpu 
	cpr15->mmu 		= mmu 
	cpr15->ic 		= ic 
	cpr15->control_= &h00004072UL 
	cpr15->cpuid 	= cpuid 
	cpr15->cacheId = cacheId 
	cpr15->xscale 	= xscale 
	cpr15->omap 	= omap 

	if (omap) Then cpr15->iMax = &hff

	cpuCoprocessorRegister(cpu, 15, @cp15)

	return cpr15 
End Function

Sub cp15SetFaultStatus(cp15 As ArmCP15 Ptr , addr As ULong , faultStatus As UByte)
	cp15->FAR = addr 
	cp15->FSR = faultStatus 
End Sub
