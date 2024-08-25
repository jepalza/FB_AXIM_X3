'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socSspPrvIrqsUpdate( ssp As SocSsp Ptr)
	dim As Bool irq = false 
	
	if ((ssp->sr And &h40)<>0) AndAlso ((ssp->cr1 And &h01)<>0) Then irq = true
	if ((ssp->sr And &h20)<>0) AndAlso ((ssp->cr1 And &h02)<>0) Then irq = true

	socIcInt(ssp->ic, ssp->irqNo, irq) 
End Sub

Sub socSspPrvRecalcRxFifoSta( ssp As SocSsp Ptr)
	ssp->sr And= INV( &hf048 )
	
	if (ssp->rxFifoUsed) Then ssp->sr Or= &h08
  
	ssp->sr Or= (((ssp->rxFifoUsed - 1) And &h0f) Shl 12) 
	if (ssp->rxFifoUsed > ((ssp->cr1 Shr 10) And &h0f)) Then ssp->sr Or= &h40

	socDmaExternalReq(ssp->dma, ssp->dmaReqNoBase + DMA_OFST_RX, NOT_NOT(ssp->sr And &h40)) 
	
	socSspPrvIrqsUpdate(ssp) 
End Sub

Sub socSspPrvRecalcTxFifoSta( ssp As SocSsp Ptr)
	ssp->sr And= INV( &h0f24 )

	if (ssp->txFifoUsed <> (1+UBound(ssp->txFifo))) Then ssp->sr Or= &h04

	ssp->sr Or= ((ssp->txFifoUsed And &h0f) Shl 8) 
	if (ssp->txFifoUsed <= ((ssp->cr1 Shr 6) And &h0f)) Then ssp->sr Or= &h20

	socDmaExternalReq(ssp->dma, ssp->dmaReqNoBase + DMA_OFST_RX, NOT_NOT(ssp->sr And &h20)) 
	
	socSspPrvIrqsUpdate(ssp) 
End Sub

Function socSspPrvFifoR( ssp As SocSsp Ptr , valP As uShort Ptr) As Bool
	if ssp->rxFifoUsed=0 Then 
		MiPrint "SSP RX FIFO UNDERFLOW"
		*valP = 0 
		return true 
	EndIf
  
	*valP = ssp->rxFifo(0) 
	ssp->rxFifoUsed-=1
	memmove(@ssp->rxFifo(0) + 0, @ssp->rxFifo(0) + 1, sizeof(uShort) * ssp->rxFifoUsed) 

	socSspPrvRecalcRxFifoSta(ssp) 
	
	return true 
End Function

Function socSspPrvFifoW( ssp As SocSsp Ptr , valor As uShort) As Bool
	if ssp->txFifoUsed = (1+ubound(ssp->txFifo)) then 
		MiPrint "SSP TX FIFO OVERFLOW"
		return true 
	EndIf

	ssp->sr Or= &h10 	'busy
	ssp->txFifo(ssp->txFifoUsed) = valor 
	ssp->txFifoUsed+=1 
	socSspPrvRecalcTxFifoSta(ssp) 
	
	return true 
End Function

Function socSspPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	Dim As SocSsp Ptr ssp = cast(SocSsp Ptr,userData )
	Dim As ULong valor 
	
	if(size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 
	EndIf

	pa = (pa - ssp->base_) Shr 2 
	
	if (write_) Then valor = *cast(ULong ptr,buf)
	
	Select Case As Const (pa)  
		case 0 
			if (write_) Then 
				ssp->cr0 = valor 
			else
				valor = ssp->cr0
			EndIf
		
		case 1 
			if (write_) Then 
				ssp->cr1 = valor 
			else
				valor = ssp->cr1
			EndIf
		
		case 2 
			if (write_) Then 
				ssp->sr = (ssp->sr And INV(&h80)) Or (valor And &h80) 
			else
				valor = ssp->sr
			EndIf
		
		case 4 
			if (write_) Then 
				return socSspPrvFifoW(ssp, valor) 
			else
				return socSspPrvFifoR(ssp, cast(UShort ptr,buf))
			EndIf

		case else 
			return false 
   End Select

	if write_=0 Then *cast(ULong ptr,buf) = valor

	return true 
End Function

Sub socSspPeriodic(ssp As SocSsp Ptr)
	if ssp->txFifoUsed=0 Then 
		ssp->sr And= INV( &h10 )
	else
		dim as uLong valor = ssp->txFifo(0), ret = 0, i 
		
		ssp->txFifoUsed-=1
		memmove(@ssp->txFifo(0) + 0, @ssp->txFifo(0) + 1, sizeof(uShort) * ssp->txFifoUsed) 
		socSspPrvRecalcTxFifoSta(ssp) 
		
		if (ssp->cr1 And 4) Then 'loopback
			ret = valor 
		else
			for i = 0 To ubound(ssp->procF)   
				if ssp->procF(i)=0 Then continue for
				ret Or= ssp->procF(i)(ssp->procD(i), 1 + (ssp->cr0 And 15), valor) 
         Next
		EndIf
  
		if ssp->rxFifoUsed = (1+ubound(ssp->rxFifo)) then 
			MiPrint "SSP RX FIFO OVERFLOW" 
			ssp->sr Or= &h80 
		else
			ssp->rxFifo(ssp->rxFifoUsed) = ret 
			ssp->rxFifoUsed+=1 
			socSspPrvRecalcRxFifoSta(ssp) 
		EndIf
	EndIf
  
End Sub

Function socSspInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr , base_ As uLong , irqNo As UByte , dmaReqNoBase As UByte) As SocSsp ptr
	Dim As SocSsp ptr ssp = cast(SocSsp ptr,Callocate(sizeof(SocSsp)) )
	
	if ssp=0 Then PERR("cannot alloc SSP")

	memset(ssp, 0,sizeof(SocSsp)) 
	
	ssp->ic    = ic 
	ssp->dma   = dma 
	ssp->base_ = base_ 
	ssp->irqNo = irqNo 
	ssp->dmaReqNoBase = dmaReqNoBase 
	socSspPrvRecalcTxFifoSta(ssp) 
	
	if memRegionAdd(physMem, base_, PXA_SSP_SIZE, cast(ArmMemAccessF ,@socSspPrvMemAccessF), ssp)=0 Then 
		PERR("cannot add SSP to MEM")
	EndIf
  
	return ssp 
End Function

Function socSspAddClient( ssp As SocSsp Ptr , procF As SspClientProcF , userData As Any Ptr) As Bool
	dim as uLong i 
	print "revisame socSspAddClient, podrian ser direcciones??":beep:sleep
	for i = 0 To ubound(ssp->procF)    
		
		if (ssp->procF(i)) Then continue for
		
		ssp->procF(i) = procF ' son direcciones o valores a pelo??
		ssp->procD(i) = @userData 
		return true 
	
   Next
	
	return false 
End Function
