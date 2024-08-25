'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socDmaPrvChannelIrqRecalc(dma As SocDma Ptr , channel As Ubyte)
	dma->DINT And= INV(1 Shl channel) 
	
	if (dma->channels(channel).CSR And &h20000000ul) Then  'stop irq enabled?
		if (dma->channels(channel).CSR And &h8) Then  'channel in stoped state
			dma->DINT Or= 1 Shl channel 
		EndIf
	EndIf
  
	if (dma->channels(channel).CSR And 4) Then  'endintr requested and on?
		dma->DINT Or= 1 Shl channel 
	EndIf
  
	if (dma->channels(channel).CSR And 2) Then  'startintr requested and on?
		dma->DINT Or= 1 Shl channel 
	EndIf
  
	if (dma->channels(channel).CSR And 1) Then  'busints on?
		dma->DINT Or= 1 Shl channel 
	EndIf
  
	socIcInt(dma->ic, PXA_I_DMA, NOT_NOT(dma->DINT) )
End Sub

Sub socDmaPrvChannelStop(dma As SocDma Ptr , ch As PxaDmaChannel Ptr)
	ch->dsAddrWriten = 0 
	ch->dtAddrWriten = 0 
	ch->dcmdAddrWritten = 0 
	ch->CSR And= INV( &h80000000ul )
	ch->CSR Or= &h08 
End Sub

Function socDmaPrvChannelRunningByCsrVal(csr As ULong) As Bool
	'previously was !(ch->CSR & 8)
	return iif((csr And &h80000008ul) = &h80000000ul,1,0)
End Function

Function socDmaPrvChannelRunning(dma As SocDma Ptr , ch As PxaDmaChannel Ptr) As Bool
	return socDmaPrvChannelRunningByCsrVal(ch->CSR) 
End Function

Sub socDmaPrvChannelDescrFetch( dma As SocDma Ptr , ch As PxaDmaChannel Ptr)	'you must call socDmaPrvChannelIrqRecalc() after this func
	Dim As ULong nextD, nextS, nextT, nextC
	dim as ulong dar = ch->DAR And INV( &h0f )
	dim As Bool d,s,t,c
	
	if ((ch->DAR And 2)<>0) AndAlso ((ch->CSR And &h0400)<>0) Then 
		'branch mode
		dar += 32
	EndIf

	' jepalza, cambio el orden por que en FB "quizas" no funcione como en C
	' y las variable next no se actualizan a tiempo antes del else
	d=memAccess(dma->mem, dar +  0, 4, false, @nextD)
	s=memAccess(dma->mem, dar +  4, 4, false, @nextS)
	t=memAccess(dma->mem, dar +  8, 4, false, @nextT)
	c=memAccess(dma->mem, dar + 12, 4, false, @nextC)
	if (d=0) OrElse (s=0) OrElse (t=0) OrElse (c=0) Then 
		'ERROR
		MiPrint "DMA descriptor fetch error"
		ch->CSR Or= 1  ' signal bus error, not running
		socDmaPrvChannelStop(dma, ch) 
	else
		ch->DAR = nextD 
		ch->SAR = nextS 
		ch->TAR = nextT 
		ch->CR  = nextC 
		if (nextC And &h00400000ul) Then 
		   'start irq requested?
			ch->CSR Or= 2
		EndIf
	EndIf
End Sub


Function socDmaPrvChannelCheckForEnd(dma As SocDma Ptr , channel As Ubyte) As Bool	'return true if irq need updating after what we did
   Dim As PxaDmaChannel ptr ch = @dma->channels(channel) 
	Dim As Bool irqUpdate = false 
	
	if socDmaPrvChannelRunning(dma, ch)=0 Then 
	   'stopped? not much to do...
		return false
	EndIf
  
	if (ch->CR And &h1fff)=0 Then 
		if (ch->CR And &h00200000ul) Then 'end irq requested?
			ch->CSR Or= 4 
			irqUpdate = true 
		EndIf
		if (ch->CSR And &h40000000ul) Then  'no descr fetch mode?	same as no descriptors
			socDmaPrvChannelStop(dma, ch) 
			irqUpdate = true 
		ElseIf (ch->DAR And 1) Then 'no more descriptors?
			socDmaPrvChannelStop(dma, ch) 
			irqUpdate = true 
		else 'fetch next descriptor
			socDmaPrvChannelDescrFetch(dma, ch) 
			irqUpdate = true 
		EndIf
	EndIf
  
	return irqUpdate 
End Function

Function socDmaPrvChannelDoBurst(dma As SocDma Ptr , channel As Ubyte) As Bool		'return true if irq need updating after what we did
   Dim As PxaDmaChannel ptr ch = @dma->channels(channel) 
	Dim As ULong each = 1 Shl (((ch->CR Shr 14) And 3) - 1) 
	Dim As ULong num  = 4 Shl ( (ch->CR Shr 16) And 3) 
	
	if ((ch->CR Shr 14) And 3)=0 Then 
		MiPrint "DMA is on but WIDTH is misprogrammed"
		'this should never happen and is unpredictable on real HW. halt to allow debug
		beep: Sleep
	EndIf
	
	'we never transfer more than there is left
	if (num > (ch->CR And &h1fff)) Then num = ch->CR And &h1fff

	if ((num mod each)<>0) Then 
  	   'xfer size not multiple of xfer item sz?
		print "cannot xfer ";num;" bytes using ";each;" byte piece. Halting"
		'this should never happen and is unpredictable on real HW. halt to allow debug
		beep: Sleep
	EndIf
  
	num \= each 	'convert from bytes to transfers

	while (num<>0)  
		Dim As ULong src = ch->SAR 
		Dim As ULong dst = ch->TAR 
		Dim As ULong t 
		
		if (memAccess(dma->mem, src, each, false, @t)=0) OrElse (memAccess(dma->mem, dst, each, true, @t)=0) Then 
			MiPrint "DMA xfer bus error"
			dma->channels(channel).CSR Or= 1  ' signl bus error, not running
			socDmaPrvChannelStop(dma, ch) 
			return true 
		EndIf

		if (ch->CR And &h80000000ul) Then ch->SAR += each
		if (ch->CR And &h40000000ul) Then ch->TAR += each
		ch->CR -= each 
		num-=1 
   Wend
	
	'check for end
	return socDmaPrvChannelCheckForEnd(dma, channel) 
End Function

Sub socDmaPrvChannelActIfNeeded(dma As SocDma Ptr , channel As Ubyte)

	dim As Bool irqUpdate = false, doWork = false, justOne = true 
   Dim As PxaDmaChannel ptr ch = @dma->channels(channel) 
	
	'stopped? not much to do...
	if socDmaPrvChannelRunning(dma, ch)=0 Then Exit Sub

	'check for end
	if socDmaPrvChannelCheckForEnd(dma, channel) Then irqUpdate = true
  
	'CSR.8 might change from above call, so this cannot be removed despite the earlier check
	
	if (socDmaPrvChannelRunning(dma, ch)) Then 
  		'if we are running, get working...
		'check for work
		if (ch->CSR And &h100) Then 
			'request?
			doWork = true
		EndIf
 
		if (ch->CR And &h30000000ul)=0 Then 
		   'no flow control?	
			doWork  = true 
			justOne = false 'do it all
		EndIf
  
		if (doWork) Then 
			do
				if (socDmaPrvChannelDoBurst(dma, channel)) Then irqUpdate = true
         loop while ((ch->CR And &h1fff)<>0) AndAlso (justOne=0)
		EndIf
	EndIf
  
	if (irqUpdate) Then socDmaPrvChannelIrqRecalc(dma, channel)
  
End Sub

Sub socDmaPrvChannelMaybeStart(dma As SocDma Ptr , ch As PxaDmaChannel Ptr , prevCsrvalor As ULong)
	if (socDmaPrvChannelRunning(dma, ch)<>0) AndAlso (socDmaPrvChannelRunningByCsrVal(prevCsrvalor)=0) Then 
		ch->CSR And= INV( &h100 )
				
		if (ch->CSR And &h40000000ul)=0 Then  'not no-fetch mode
			ch->CR And= INV(&h1fff )	'so we fatch descr on first request
			socDmaPrvChannelDescrFetch(dma, ch) 
		EndIf
	EndIf
End Sub

Function socDmaPrvChannelRegWrite(dma As SocDma Ptr , channel As Ubyte , reg As Ubyte , valor As ULong) As Bool
   Dim As PxaDmaChannel ptr ch = @dma->channels(channel) 
	dim As Bool checkForStart = false, maybeStart = false 
	Dim As ULong prevCsr = ch->CSR 
	
	if (reg = REG_DAR) Then   
		ch->DAR = valor 
		'only in descr fetch mode
		if (valor<>0) AndAlso ((ch->CSR And &h40000000ul)=0) Then maybeStart = true 
	ElseIf (reg = REG_SAR) Then
		if (ch->CSR And &h40000000ul) Then checkForStart = true
		ch->dsAddrWriten = 1 
		ch->SAR = valor 
	ElseIf (reg = REG_TAR) Then
		if (ch->CSR And &h40000000ul) Then checkForStart = true
		ch->dtAddrWriten = 1 
		ch->TAR = valor 
	ElseIf (reg = REG_CR) Then 
		if (ch->CSR And &h40000000ul) Then checkForStart = true
		ch->dcmdAddrWritten = 1 
		ch->CR = valor 
	else 'CSR
		Dim As ULong newvalor = ((prevCsr And &h0000031ful) Or (valor And &hfcc00400ul)) And INV(valor And &h00000217ul) 
		
		if (valor And &h02000000ul) Then 
			newvalor Or= &h0400 
		ElseIf (valor And &h01000000ul) Then
			newvalor And= INV( &h0400 )
		EndIf
  
		if (newvalor And &h00400000ul) Then 'MaskRun
			newvalor = (newvalor And INV(&h80000000ul)) Or (prevCsr And &h80000000ul)
		EndIf

		ch->CSR = newvalor 
		
		socDmaPrvChannelMaybeStart(dma, @dma->channels(channel), prevCsr) 
		
		if ((newvalor And &h80000000ul)=0) AndAlso ((prevCsr And &h80000000ul)<>0) Then 
			'just stopped
			socDmaPrvChannelStop(dma, ch) 
		EndIf
		
		socDmaPrvChannelIrqRecalc(dma, channel) 
	EndIf
	
	'if (checkForStart<>0) AndAlso (ch->dsAddrWriten<>0) AndAlso (ch->dtAddrWriten<>0) AndAlso (ch->dcmdAddrWritten<>0) Then 
	if (checkForStart+ch->dsAddrWriten+ch->dtAddrWriten+ch->dcmdAddrWritten)<>0 Then 
		maybeStart = true
	EndIf
  
	if (maybeStart) Then 
		ch->CSR And= INV( &h08 )
		socDmaPrvChannelMaybeStart(dma, ch, prevCsr) 
	EndIf
  
	return true 
End Function

Function socDmaPrvChannelRegRead(dma As SocDma Ptr , channel As Ubyte , reg As Ubyte , retP As ULong Ptr) As Bool

	Select Case As Const (reg)  
		case REG_DAR 
			*retP = dma->channels(channel).DAR 
		
		case REG_SAR 
			*retP = dma->channels(channel).SAR 
		
		case REG_TAR 
			*retP = dma->channels(channel).TAR 

		case REG_CR 
			*retP = dma->channels(channel).CR 
		
		case REG_CSR 
			*retP = dma->channels(channel).CSR 
		
		case else 
			return false 
   End Select

	return true 
End Function

Sub socDmaExternalReq(dma As SocDma Ptr , chNum As Ubyte , requested As Bool)
	Dim As ULong cfg = dma->CMR(chNum) 
	
	if (cfg And &h80) Then 
		'is it mapped to a channel at all?
		Dim As ULong ch = cfg And &h1f 
		
		if (requested=0) Then 
			dma->channels(ch).CSR And= INV(&h100 )
		ElseIf ((dma->channels(ch).CSR And &h100)=0) Then
			'already pending? do nothing
			dma->channels(ch).CSR Or= &h100 'req pend
		EndIf
	EndIf
End Sub

Sub socDmaPeriodic(dma As SocDma Ptr)
	Dim As ULong i 
	for i = 0 To 31       
		socDmaPrvChannelActIfNeeded(dma, i)
   Next
End Sub

Function socDmaPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   Dim as SocDma ptr dma = cast(SocDma ptr,userData )
	Dim As Ubyte reg, set 
	Dim As ULong valor = 0 
	
	if (size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8)
		return false 
	EndIf
  
	pa = (pa - PXA_DMA_BASE) Shr 2 
	
	if (write_) Then 
		valor = *Cast(ulong ptr,buf )
		'print "revisar CASE 0x28 en socDmaPrvMemAccessF repetido 2 veces!!!!"':beep:sleep
		Select Case As Const (pa Shr 6)  		'weird, but quick way to avoid repeated if-then-elses. this is faster
			case 0 
				if (pa = &h28) Then   
					dma->dalgn = valor 
					exit select
				ElseIf (pa = &h32) Then  'aqui hay un problema de codigo original, dos veces pa=0x28
					dma->dpcsr = valor 
					exit select
				ElseIf (pa = &h3c) Then
					'no part of DINT is writeable but it MUST accept writes
					exit select
				EndIf

				if (pa >= 32) Then return false

				reg = REG_CSR 
				set = pa 
				if (socDmaPrvChannelRegWrite(dma, set, reg, valor)=0) Then return false
				
			case 17 
				pa -= 1088 
				'pa += 64 ' evito esta operacion ...
				'en Cascada con CASE 1
				'pa -= 64 ' ...ya que resulta en cero 
				if (pa >= 75) Then return false
				dma->CMR(pa) = valor 
				
			case 1 
				pa -= 64 
				if (pa >= 75) Then return false
				dma->CMR(pa) = valor 
			
			case 2 , 3 
				pa -= 128 
				set = pa Shr 2 
				reg = pa And 3 
				if (set >= 32) Then return false
				if (socDmaPrvChannelRegWrite(dma, set, reg, valor)=0) Then return false
				
			case else 
				return false 
      End Select

	else
					
      'print "revisar CASE 0x28 en socDmaPrvMemAccessF repetido 2 veces!!!!"':beep:sleep
		Select Case As Const (pa Shr 6)  		'weird, but quick way to avoide repeated if-then-elses. this is faster
			case 0 
				if (pa = &h28) Then   
					valor = dma->dalgn 
					exit select
				ElseIf (pa = &h32) Then 'aqui hay un problema de codigo original, dos veces pa=0x28
					valor = dma->dpcsr 
					exit select
				ElseIf (pa = &h3c) Then
					valor = dma->DINT 
					exit select
				EndIf

				if (pa >= 32) Then return false

				reg = REG_CSR 
				set = pa 
				if (socDmaPrvChannelRegRead(dma, set, reg, @valor)=0) Then return false
				
			case 17 
				pa -= 1088 
				'pa += 64 ' evito esta operacion ...
				'en Cascada con CASE 1
				'pa -= 64 ' ...ya que resulta en cero 
				if (pa >= 75) Then return false
				valor = dma->CMR(pa) 
				
			case 1 
				pa -= 64 
				if (pa >= 75) Then return false
				valor = dma->CMR(pa) 
			
			case 2 ,3 
				pa -= 128 
				set = pa Shr 2 
				reg = pa And 3 
				if (set >= 32) Then return false
				if (socDmaPrvChannelRegRead(dma, set, reg, @valor)=0) Then return false
			
			case else 
				return false 
      End Select

		*Cast(ulong ptr,buf) = valor 
	EndIf
	
	return true 
End Function


Function socDmaInit( physMem as ArmMem ptr, ic as SocIc ptr) As SocDma Ptr
   Dim as SocDma ptr dma = cast(SocDma ptr,Callocate(sizeof(SocDma))) 
	Dim as ubyte i   
	
	if (dma=0) then PERR("cannot alloc DMA") 
	
	memset(dma, 0, sizeof(SocDma)) 
	dma->ic = ic 
	dma->mem = physMem 
	
	for i = 0 To 31       
		dma->channels(i).CSR = 8 'stopped or uninitialized
   Next

	if memRegionAdd(physMem, PXA_DMA_BASE, PXA_DMA_SIZE, cast(ArmMemAccessF ,@socDmaPrvMemAccessF), dma)=0 Then 
		PERR("cannot add DMA to MEM")
	EndIf
  
	return dma 
End Function
