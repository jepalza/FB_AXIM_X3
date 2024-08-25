'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socIcPrvHandleChanges( ic As SocIc Ptr)
	dim As Bool nowIrq = false, nowFiq = false 
	Dim As Ubyte i 
	
	for i = 0 To 1         
		Dim as uLong unmasked = ic->ICPR(i) And ic->ICMR(i) 
		nowFiq = iif((nowFiq<>0) OrElse ((unmasked And ic->ICLR(i))<>0) ,1,0)
		nowIrq = iif((nowIrq<>0) OrElse ((unmasked And INV(ic->ICLR(i)) )<>0) ,1,0)
   Next
	
	if (nowFiq <> ic->wasFiq) Then 
		cpuIrq(ic->cpu, true, nowFiq)
	EndIf
  
	if (nowIrq <> ic->wasIrq) Then 
		cpuIrq(ic->cpu, false, nowIrq)
	EndIf
  
	ic->wasFiq = nowFiq 
	ic->wasIrq = nowIrq 
End Sub

Function socIcPrvCalcHighestPrio( ic As SocIc Ptr) As uLong
	Dim As ULong activeIrq(2), activeFiq(2), ret = &h001f001ful 
	Dim As Ubyte i 
	
	for i = 0 To 1      
		activeIrq(i) = ic->ICPR(i) And ic->ICMR(i) And INV(ic->ICLR(i))
		activeFiq(i) = ic->ICPR(i) And ic->ICMR(i) And ic->ICLR(i) 
   Next
	
	for i = 0 To 39         
		if (ic->prio(i) And &h80) Then 
			Dim As Ubyte periph = ic->prio(i) And &h3f 

			if ((ret And &h80000000ul)=0) AndAlso ( ((activeIrq(periph \ 32) Shr (periph mod 32)) And 1)<>0) Then 
				ret Or = &h80000000ul 
				ret And= INV(&h001f0000ul )
				ret Or = CULng(periph) Shl 16 
			EndIf
			
			if ((ret And &h8000)=0) AndAlso ( ((activeFiq(periph \ 32) Shr (periph mod 32)) And 1)<>0) Then 
				ret Or = &h8000 
				ret And= INV(&h001f )
				ret Or = periph 
			EndIf
		EndIf
   Next
	
	return ret 
End Function

Function socIcPrvGetIcip( ic As SocIc Ptr , idx As Ubyte) As uLong
	return ic->ICPR(idx) And ic->ICMR(idx) And INV(ic->ICLR(idx)) 
End Function

Function socIcPrvGetIcfp( ic As SocIc Ptr , idx As Ubyte) As uLong
	return ic->ICPR(idx) And ic->ICMR(idx) And ic->ICLR(idx) 
End Function

Function socIcPrvMemAccessF( userData As any Ptr , pa As uLong , size As Ubyte , write_ As Bool , buf As any Ptr) As Bool
	dim as SocIc ptr ic = cast(SocIc ptr,userData) 
	dim as uLong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_IC_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
	EndIf
  
	Select Case As Const (pa)  
		case &h9C \ 4 
			if ic->gen2=0 Then return false
			pa -= &h9C \ 4 
			'pa += &h00 \ 4 
			pa += 1 
			'Cascada_CASE 00
			if (write_) Then 
				'ignored
			else
				valor = socIcPrvGetIcip(ic, pa) ' - &h00 \ 4)
			EndIf
						
		case &h00 
			if (write_) Then 
				'ignored
			else
				valor = socIcPrvGetIcip(ic, pa) ' - &h00 \ 4)
			EndIf
			
			
		
		case &hA0 \ 4 
			if ic->gen2=0 Then return false
			pa -= &hA0 \ 4 
			pa += &h04 \ 4 
			pa += 1 
			'Cascada_CASE 04
			if (write_) Then 
				ic->ICMR(pa - &h04 \ 4) = valor 
			else
				valor = ic->ICMR(pa - &h04 \ 4)
			EndIf
						
		case &h04 \ 4 
			if (write_) Then 
				ic->ICMR(pa - &h04 \ 4) = valor 
			else
				valor = ic->ICMR(pa - &h04 \ 4)
			EndIf
		
		
		
		case &hA4 \ 4 
			if ic->gen2=0 Then return false
			pa -= &hA4 \ 4 
			pa += &h08 \ 4 
			pa += 1 
			'Cascada_CASE 08
			if (write_) Then 
				ic->ICLR(pa - &h08 \ 4) = valor 
			else
				valor = ic->ICLR(pa - &h08 \ 4)
			EndIf
						
		case &h08 \ 4 
			if (write_) Then 
				ic->ICLR(pa - &h08 \ 4) = valor 
			else
				valor = ic->ICLR(pa - &h08 \ 4)
			EndIf
			
			
		
		case &hA8 \ 4 
			if ic->gen2=0 Then return false
			pa -= &hA8 \ 4 
			pa += &h0C \ 4 
			pa += 1 
			'Cascada_CASE 0c
			if (write_) Then 
				'ignored
			else
				valor = socIcPrvGetIcfp(ic, pa - &h0C \ 4)
			EndIf
						
		case &h0C \ 4 
			if (write_) Then 
				'ignored
			else
				valor = socIcPrvGetIcfp(ic, pa - &h0C \ 4)
			EndIf
			
			
		
		case &hAC \ 4 
			if ic->gen2=0 Then return false
			pa -= &hAC \ 4 
			pa += &h10 \ 4 
			pa += 1 
			'Cascada_CASE 10
			if (write_) Then 
				'ignored
			else
				valor = ic->ICPR(pa - &h10 \ 4)
			EndIf
						
		case &h10 \ 4 
			if (write_) Then 
				'ignored
			else
				valor = ic->ICPR(pa - &h10 \ 4)
			EndIf
			
			
		
		case &h14 \ 4 
			if (write_) Then 
				ic->iccr = valor And 1 
			else
				valor = ic->iccr
			EndIf
		
		case &h18 \ 4 
			if ic->gen2=0 Then return false
			if (write_) Then 
				'ignored
			else
				valor = socIcPrvCalcHighestPrio(ic)
			EndIf
		
		
		
		case (&hb0 \ 4) to (&hcc \ 4) 
			pa -= &hb0 \ 4 
			pa += &h98 \ 4 
			pa += 1 
			'Cascada_CASE 1c
			if (write_) Then 
				ic->prio(pa - &h1c \ 4) = (valor And &h3f) Or ((valor Shr 24) And &h80) 
			else
				valor = (ic->prio(pa - &h1c \ 4) And &h3f) Or iif((ic->prio(pa - &h1c \ 4) And &h80) , &h80000000ul , 0)
			EndIf
			
		case (&h1c \ 4) to (&h98 \ 4)
			if (write_) Then 
				ic->prio(pa - &h1c \ 4) = (valor And &h3f) Or ((valor Shr 24) And &h80) 
			else
				valor = (ic->prio(pa - &h1c \ 4) And &h3f) Or iif((ic->prio(pa - &h1c \ 4) And &h80) , &h80000000ul , 0)
			EndIf
			
			
		
		case else 
			return false 
   End Select

	if (write_) Then 
		socIcPrvHandleChanges(ic) 
	else
		*cast(ULong ptr,buf) = valor
	EndIf
  
	return true 
End Function

Function pxa270icPrvCoprocAccess( cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , MRC As Bool ,_
	        op1 As uByte , Rx As uByte , CRn As uByte , CRm As uByte , op2 As uByte) As Bool

	Dim As SocIc ptr ic = cast(SocIc ptr,userData) 
	Dim As Bool write_  = iif(MRC=0,1,0) 
	Dim As uLong valor  = 0 
	
	if (CRm<>0) OrElse (op1<>0) OrElse (op2<>0) OrElse (two<>0) Then return false

	if (write_) Then valor = cpuGetRegExternal(cpu, Rx)

	Select Case As Const (CRn)  
		case 0,6
			if(CRn)=6 then CRn-=5 
			if (write_) Then 
				return false 
			else
				valor = socIcPrvGetIcip(ic, CRn - 0)
			EndIf
			
		case 1,7
			if(CRn)=7 then CRn-=5  
			if (write_) Then 
				ic->ICMR(CRn - 1) = valor 
			else
				valor = ic->ICMR(CRn - 1)
			EndIf
			
		case 2,8
			if(CRn)=8 then CRn-=5 
			if (write_) Then 
				ic->ICLR(CRn - 2) = valor 
			else
				valor = ic->ICLR(CRn - 2)
			EndIf
	
		case 3,9
			if(CRn)=9 then CRn-=5  
			if (write_) Then 
				return false 
			else
				valor = socIcPrvGetIcfp(ic, CRn - 3)
			EndIf
		
		case 4,10
			if(CRn)=10 then CRn-=5  
			if (write_) Then 
				return false 
			else
				valor = ic->ICPR(CRn - 4)
			EndIf
		
		case 5 
			if (write_) Then 
				return false 
			else
				valor = socIcPrvCalcHighestPrio(ic)
			EndIf
		
		case else 
			return false 
   End Select

	if (write_) Then 
		socIcPrvHandleChanges(ic) 
	else
		cpuSetReg(cpu, Rx, valor)
	EndIf

	return true 
End Function

Function socIcInit( cpu As ArmCpu Ptr , physMem As ArmMem Ptr , socRev As Ubyte) As SocIc Ptr
	 print "MUERTO en SOCICINIT: ";hex(cpu->coproc(15),8),hex(cpu->coproc(15)->regXfer,8),hex(cpu->coproc(15)->userdata,8)
	 Dim As SocIc Ptr ic = cast(SocIc Ptr,Callocate(sizeof(SocIc)) )
	 
	 Dim As ArmCoprocessor cp6 
	 With cp6
		.regXfer  = cast(ArmCoprocRegXferF,@pxa270icPrvCoprocAccess)
		.userData = ic
	 End With 

	
	if (ic=0) Then PERR("cannot alloc IC CP6")

	memset(ic, 0, sizeof(SocIc)) 

	ic->cpu = cpu 
	ic->gen2 = iif(socRev = 2,1,0)
	
	if memRegionAdd(physMem, PXA_IC_BASE, PXA_IC_SIZE, cast(ArmMemAccessF ,@socIcPrvMemAccessF), ic)=0 Then 
		PERR("cannot add IC to MEM")
	EndIf

	if (ic->gen2) Then 
		' solo si GEN2>0, en el caso del AXIM-X3 es "0", no se ejecuta
		cpuCoprocessorRegister(cpu, 6, @cp6)
	EndIf
  
	return ic 
End Function

Sub socIcInt( ic As SocIc Ptr , intNum As Ubyte , raise As Bool) 'interrupt caused by emulated hardware
	Dim As uLong old = ic->ICPR(intNum \ 32) 

	if (raise) Then 
		ic->ICPR(intNum \ 32) Or =      (1UL Shl (intNum mod 32)) 
	else
		ic->ICPR(intNum \ 32) And= INV( (1UL Shl (intNum mod 32)) )
	EndIf
  
	if (ic->ICPR(intNum \ 32) <> old) Then 
		socIcPrvHandleChanges(ic)
	EndIf
End Sub
