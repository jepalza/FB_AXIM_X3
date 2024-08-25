'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socI2sPrvIrqUpdate(i2s As SocI2s Ptr)
	socIcInt(i2s->ic, PXA_I_I2S, NOT_NOT(i2s->sasr0 And i2s->saimr And &h78)) 
End Sub

Sub socI2sPrvTxFifoRecalc( i2s As SocI2s Ptr)
	i2s->sasr0 And= INV( &h0f09 )
	
	i2s->sasr0 Or= (i2s->txFifoEnts And &h0f) Shl 8 
	if i2s->txFifoEnts <> (1+ubound(i2s->txFifo)) then 
		i2s->sasr0 Or= &h01
	EndIf
	
	if (i2s->txFifoEnts < ((i2s->sacr0 Shr 8) And &h0f)) Then 
		i2s->sasr0 Or= &h08
	EndIf
  
	socI2sPrvIrqUpdate(i2s) 
	socDmaExternalReq(i2s->dma, DMA_CMR_I2S_TX, NOT_NOT(i2s->sasr0 And &h08)) 
End Sub

Sub socI2sPrvRxFifoRecalc( i2s As SocI2s Ptr)
	i2s->sasr0 And= INV( &hf012 ) 
	
	i2s->sasr0 Or= (i2s->rxFifoEnts And &h0f) Shl 12 
	if i2s->rxFifoEnts=0 Then 
		i2s->sasr0 Or= &h02
	EndIf
  
	if i2s->rxFifoEnts >= (((i2s->sacr0 Shr 12) And &h0f) + 1) Then 
		i2s->sasr0 Or= &h10
	EndIf
  
	socI2sPrvIrqUpdate(i2s) 
	
	socDmaExternalReq(i2s->dma, DMA_CMR_I2S_RX, NOT_NOT(i2s->sasr0 And &h10)) 
End Sub

Function socI2sPrvFifoW( i2s As SocI2s Ptr , valor As uLong) As Bool
	if i2s->txFifoEnts = (1+ubound(i2s->txFifo)) then
		MiPrint "TX fifo overrun" 
		return true 
	EndIf
  
	i2s->txFifo(i2s->txFifoEnts ) = valor 
	i2s->txFifoEnts+=1 
	socI2sPrvTxFifoRecalc(i2s) 
	
	return true 
End Function

Function socI2sPrvFifoR( i2s As SocI2s Ptr , valP As uLong Ptr) As Bool
	if i2s->rxFifoEnts=0 Then 
		MiPrint "RX fifo underrun"
		return false 
	EndIf
  
	*valP = i2s->rxFifo(0) 
	i2s->rxFifoEnts-=1
	memmove(@i2s->rxFifo(0) + 0, @i2s->rxFifo(0) + 1, sizeof(ulong)*i2s->rxFifoEnts ) ' rxFifo=ulong=4bytes
	socI2sPrvRxFifoRecalc(i2s) 
	
	return true 
End Function

Function socI2sPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	dim as SocI2s ptr i2s = cast(SocI2s ptr,userData)
	dim as uLong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write_" , "read_"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_I2S_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
	EndIf
	
	Select Case As Const (pa)  
		case 0 
			if (write_) Then 
				i2s->sacr0 = valor And &hff3d 
			else
				valor = i2s->sacr0
			EndIf
		
		case 1 
			if (write_) Then 
				i2s->sacr1 = valor And &h39 
			else
				valor = i2s->sacr1
			EndIf
		
		case 3 
			if (write_) Then 
				return false 
			else
				valor = i2s->sasr0
			EndIf
		
		case 5 
			if (write_) Then 
				i2s->saimr = valor And &h78 
			else
				valor = i2s->saimr
			EndIf
		
		case 6 
			if (write_) Then 
				i2s->sasr0 And= INV(valor And &h60) 
			else
				return false
			EndIf
		
		case 24 
			if (write_) Then 
				i2s->sadiv = valor And &h7f 
			else
				valor = i2s->sadiv
			EndIf
		
		case 32 
			if (write_) Then 
				return socI2sPrvFifoW(i2s, valor) 
			else
				print "revisame puntero socI2sPrvMemAccessF":beep:sleep
				return socI2sPrvFifoR(i2s, cast(ULong ptr,buf) )
			EndIf
		
		case else 
			return false 
   End Select

	if write_=0 Then 
		*cast(ULong ptr,buf) = valor
	EndIf

	return true 
End Function

Function socI2sInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr) As SocI2s ptr
	dim as SocI2s ptr i2s = cast(SocI2s ptr,Callocate(sizeof(SocI2s)) )
	if i2s=0 Then PERR("cannot alloc I2C")

	memset(i2s, 0, sizeof(SocI2s)) 
	i2s->ic    = ic 
	i2s->dma   = dma 
	i2s->sacr0 = &h7700 
	i2s->sasr0 = &h0001 
	i2s->sadiv = &h001a 
	
	if memRegionAdd(physMem, PXA_I2S_BASE, PXA_I2S_SIZE, cast(ArmMemAccessF ,@socI2sPrvMemAccessF), i2s)=0 Then 
		PERR("cannot add I2S to MEM")
	endif
	
	return i2s 
End Function

Sub socI2sPeriodic( i2s As SocI2s Ptr)
	dim as uLong valor = 0 
	
	'consume a sample if tx is allowed
	if (i2s->sacr1 And &h10)=0 Then 
		if (i2s->txFifoEnts) Then 
			valor = i2s->txFifo(0) 
			i2s->txFifoEnts-=1
			memmove(@i2s->txFifo(0) + 0, @i2s->txFifo(0) + 1, sizeof(ulong)*i2s->txFifoEnts ) ' txFifo=ulong=4bytes
		else
			i2s->sasr0 Or= &h20
		EndIf
	EndIf
  
	'get a sample if RX is allowed
	if (i2s->sacr1 And &h08)=0 Then 
		if i2s->rxFifoEnts <> (1+UBound(i2s->rxFifo)) then
			i2s->rxFifo(i2s->rxFifoEnts) = valor 
			i2s->rxFifoEnts+=1
		else
			i2s->sasr0 Or= &h40
		EndIf
	EndIf
  
	socI2sPrvTxFifoRecalc(i2s) 
	socI2sPrvRxFifoRecalc(i2s) 
End Sub
