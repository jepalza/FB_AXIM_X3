' (c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socAC97prvIrqUpdate( ac97 As SocAC97 Ptr)
	dim As Bool irq = false 
	
	irq = iif( (irq<>0) OrElse NOT_NOT(ac97->posr And (ac97->pocr Shl 1) And &h14) ,1,0)
	irq = iif( (irq<>0) OrElse NOT_NOT(ac97->pisr And (ac97->picr Shl 1) And &h14) ,1,0) 
	irq = iif( (irq<>0) OrElse NOT_NOT(ac97->mccr And (ac97->mcsr Shl 1) And &h14) ,1,0) 
	irq = iif( (irq<>0) OrElse NOT_NOT(ac97->mocr And (ac97->mosr Shl 1) And &h14) ,1,0) 
	irq = iif( (irq<>0) OrElse NOT_NOT(ac97->micr And (ac97->misr Shl 1) And &h14) ,1,0) 
	
	irq = iif( (irq<>0) OrElse ((ac97->gcr And ac97->gsr And &h300)<>0) ,1,0) 
	irq = iif( (irq<>0) OrElse ((ac97->gsr And &h000c0000ul)<>0) ,1,0) 
	
	socIcInt(ac97->ic, PXA_I_AC97, irq) 
End Sub

Sub socAC97PrvFifoDmaUpdate( ac97 As SocAC97 Ptr , fifo As AC97Fifo Ptr)
	dim As Bool fifoReadyForRead = iif(fifo->isRxFifo , iif(fifo->numItems >= 8,1,0) , iif(fifo->numItems < 8,1,0) ) 

	if (fifoReadyForRead) Then 
		*fifo->isr Or= 4 
	else
		*fifo->isr And= INV( 4 )
	EndIf
  
	if (fifo->dmaChannelNum) Then 
		socDmaExternalReq(ac97->dma, fifo->dmaChannelNum, fifoReadyForRead)
	EndIf
End Sub

Function socAC97PrvFifoAdd( ac97 As SocAC97 Ptr , fifo As AC97Fifo Ptr , valor As ULong) As Bool
	Dim As ULong ptr_, cap = 1+UBound(fifo->datas) ' 16
	dim As Bool ret = false 
	
	if (fifo->numItems = cap) Then 
		*fifo->isr Or= &h10 	' full
	else
		ret = true 
		ptr_ = (fifo->readPtr + fifo->numItems ) mod cap
		fifo->numItems+=1 
		fifo->datas(ptr_) = valor 
	EndIf
  
	socAC97PrvFifoDmaUpdate(ac97, fifo) 
	
	return ret 
End Function

Function socAC97PrvFifoGet( ac97 As SocAC97 Ptr , fifo As AC97Fifo Ptr , valP As ULong Ptr) As Bool
	Dim As ULong cap = 1+UBound(fifo->datas) ' 16
	dim As Bool ret = false 
	
	if (fifo->numItems=0) Then 
		if (valP) Then 
			*valP = fifo->lastReadSample
		EndIf

		*fifo->isr Or= &h10 		' empty
	else
		fifo->lastReadSample = fifo->datas(fifo->readPtr) 

		if (valP) Then 
			*valP = fifo->lastReadSample
		EndIf

		fifo->readPtr+=1
		if (fifo->readPtr = cap) Then 
			fifo->readPtr = 0
		EndIf

		fifo->numItems-=1  
		
		ret = true 
	EndIf
  
	socAC97PrvFifoDmaUpdate(ac97, fifo) 
	
	return ret 
End Function

Function socAC97PrvFifoW( ac97 As SocAC97 Ptr , codec As Ac97CodecStruct Ptr , valor As ULong) As Bool
	return socAC97PrvFifoAdd(ac97, @codec->txFifo, valor) 
End Function

Function socAC97PrvFifoR( ac97 As SocAC97 Ptr , codec As Ac97CodecStruct Ptr , valP As ULong Ptr) As Bool
	return  socAC97PrvFifoGet(ac97, @codec->rxFifo, valP) 
End Function

Function socAC97PrvPcmFifoW( ac97 As SocAC97 Ptr , valor As ULong) As Bool
	return socAC97PrvFifoW(ac97, @ac97->primaryAudio, valor) 
End Function

Function socAC97PrvPcmFifoR( ac97 As SocAC97 Ptr , valP As ULong Ptr) As Bool
	return socAC97PrvFifoR(ac97, @ac97->primaryAudio, valP) 
End Function

Function socAC97PrvMicFifoR( ac97 As SocAC97 Ptr , valP As ULong Ptr) As Bool
	return socAC97PrvFifoR(ac97, @ac97->secondaryAudio, valP) 
End Function

Function socAC97PrvModemFifoW( ac97 As SocAC97 Ptr , valor As ULong) As Bool
	return socAC97PrvFifoW(ac97, @ac97->primaryModem, valor) 
End Function

Function socAC97PrvModemFifoR( ac97 As SocAC97 Ptr , valP As ULong Ptr) As Bool
	return socAC97PrvFifoR(ac97, @ac97->primaryModem, valP) 
End Function

Function socAC97PrvMemAccessF( userData As any Ptr , pa As ULong , size As UByte , write_ As Bool , buf As any Ptr) As Bool
	dim as SocAC97 ptr ac97 = cast(SocAC97 ptr,userData )
	dim as Ac97CodecStruct ptr cd = NULL 
	Dim As ULong valor = 0 
	
	pa -= PXA_AC97_BASE 
	
	if (size <> 4) AndAlso (size <> 2) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, pa) 
		return false 
	EndIf
  
	pa Shr = 2 
	
	if (write_) Then 
		valor = iif( size = 2 , *cast(UShort ptr,buf) , *cast(Ulong ptr,buf) )
	EndIf
  
	Select Case As Const (pa)  
		case 0 
			if (write_) Then 
				ac97->pocr = valor And &h0e 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->pocr
			EndIf
		
		case 1 
			if (write_) Then 
				ac97->picr = valor And &h0a 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->picr
			EndIf
		
		case 2 
			if (write_) Then 
				ac97->mccr = valor And &h0a 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->mccr
			EndIf
		
		case 3 
			if (write_) Then 
				ac97->gcr = valor And &h000c033ful 
				ac97->gsr = ( ac97->gsr And INV(8ul) ) Or (valor And 8) 	' set shut off status
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->gcr
			EndIf
		
		case 4 
			if (write_) Then 
				ac97->posr And= INV(valor And &h10) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->posr
			EndIf
		
		case 5 
			if (write_) Then 
				ac97->pisr And= INV(valor And &h18) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->pisr
			EndIf
		
		case 6 
			if (write_) Then 
				ac97->mcsr And= INV(valor And &h18) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->mcsr
			EndIf
		
		case 7 
			if (write_) Then 
				ac97->gsr And= INV(valor And &h000c8c01ul) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->gsr
			EndIf
		
		case 8 
			if (write_) Then 
				ac97->car And= &hfffffffeul Or (valor And 1) 
			ElseIf (ac97->car) Then
				valor = 1 
			else
				valor = 0 
				ac97->car = 1 
			EndIf
		
		case 16 
			if (write_) Then 
				return socAC97PrvPcmFifoW(ac97, valor) 
			else
				return socAC97PrvPcmFifoR(ac97, cast(ULong ptr,buf) )
			EndIf
		
		case 24 
			if (write_) Then 
				return false 
			else
				return socAC97PrvMicFifoR(ac97, cast(ULong ptr,buf) )
			EndIf
		
		case 64 
			if (write_) Then 
				ac97->mocr = valor And &h0a 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->mocr
			EndIf
		
		case 66 
			if (write_) Then 
				ac97->micr = valor And &h0a 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->micr
			EndIf
		
		case 68 
			if (write_) Then 
				ac97->mosr And= INV(valor And &h10) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->mosr
			EndIf
		
		case 70 
			if (write_) Then 
				ac97->misr And= INV(valor And &h18) 
				socAC97prvIrqUpdate(ac97) 
			else
				valor = ac97->misr
			EndIf
		
		case 80 
			if (write_) Then
				return socAC97PrvModemFifoW(ac97, valor) 
			else
				return socAC97PrvModemFifoR(ac97, cast(ULong ptr,buf) )
			EndIf
   End Select

	if     (pa >= &h080)  AndAlso (pa < &h0c0) Then 
		cd = @ac97->primaryAudio 
	ElseIf (pa >= &h0c0)  AndAlso (pa < &h100) Then
		cd = @ac97->secondaryAudio 
	ElseIf (pa >= &h0100) AndAlso (pa < &h140) Then
		cd = @ac97->primaryModem 
	ElseIf (pa >= &h0140) AndAlso (pa < &h180) Then
		cd = @ac97->secondaryModem
	EndIf
  
	if (cd) Then 
		Dim As UShort readVal = cd->prevReadVal 
		
		pa And= &h3f 
		pa *= 2 
		
		if (write_<>0) AndAlso (cd->regW<>0) AndAlso (cd->regW(cd->userData, pa, valor)<>0) Then 
			ac97->gsr Or= &h00080000ul 
		ElseIf (write_=0) AndAlso (cd->regR<>0) AndAlso (cd->regR(cd->userData, pa, @cd->prevReadVal)<>0) Then
			ac97->gsr Or= &h00040000ul
		EndIf
  
		ac97->car = 0 
		valor = readVal 
		
		socAC97prvIrqUpdate(ac97) 
	EndIf
  
	if (write_=0) Then 
		if (size = 2) Then 
			*(cast(UShort ptr,buf)) = valor 
		else
			*(cast(ULong  ptr,buf)) = valor
		EndIf
	EndIf
  
	return true 
End Function

Function socAC97Init( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr) As SocAC97 ptr
	Dim as SocAC97 ptr ac97 = cast(SocAC97 ptr,Callocate(sizeof(SocAC97))) 
	
	if (ac97=0) Then PERR("cannot alloc AC97")
	
	memset(ac97, 0, sizeof(SocAC97)) 
	
	ac97->ic  = ic 
	ac97->dma = dma 
	ac97->gsr = &h100 	' primary codec is ready
	
	ac97->primaryAudio.txFifo.dmaChannelNum = DMA_CMR_AC97_AUDIO_TX 
	ac97->primaryAudio.txFifo.icr = @ac97->pocr 
	ac97->primaryAudio.txFifo.isr = @ac97->posr 
	
	ac97->primaryAudio.rxFifo.dmaChannelNum = DMA_CMR_AC97_AUDIO_RX 
	ac97->primaryAudio.rxFifo.isRxFifo = true 
	ac97->primaryAudio.rxFifo.icr = @ac97->picr 
	ac97->primaryAudio.rxFifo.isr = @ac97->pisr 
	
	' for easiness we treat mic as a secondary codec in our data structures
	ac97->secondaryAudio.rxFifo.dmaChannelNum = DMA_CMR_AC97_MIC 
	ac97->secondaryAudio.rxFifo.isRxFifo = true 
	ac97->secondaryAudio.rxFifo.icr = @ac97->mccr 
	ac97->secondaryAudio.rxFifo.isr = @ac97->mcsr 
	
	ac97->primaryModem.txFifo.dmaChannelNum = DMA_CMR_AC97_MODEM_TX 
	ac97->primaryModem.txFifo.icr = @ac97->mocr 
	ac97->primaryModem.txFifo.isr = @ac97->mosr 
	
	ac97->primaryModem.rxFifo.dmaChannelNum = DMA_CMR_AC97_MODEM_RX 
	ac97->primaryModem.rxFifo.isRxFifo = true 
	ac97->primaryModem.rxFifo.icr = @ac97->micr 
	ac97->primaryModem.rxFifo.isr = @ac97->misr 
		
	if memRegionAdd(physMem, PXA_AC97_BASE, PXA_AC97_SIZE, cast(ArmMemAccessF ,@socAC97PrvMemAccessF), ac97)=0 Then 
		PERR("cannot add AC97 to MEM")
	EndIf
  
	return ac97 
End Function

Sub socAC97Periodic( ac97 As SocAC97 Ptr)
	' nothing - codecs do their own work getting data to and from us :)
End Sub

Function socAC97prvCodecPtrGet( ac97 As SocAC97 Ptr , which As Ac97Codec) As Ac97CodecStruct ptr
	Select Case As Const (which)  
		case Ac97PrimaryAudio 
			return @ac97->primaryAudio 
		
		case Ac97SecondaryAudio 
			return @ac97->secondaryAudio 
		
		case Ac97PrimaryModem 
			return @ac97->primaryModem 
		
		case Ac97SecondaryModem 
			return @ac97->secondaryModem 
		
		case else 
			return NULL 
   End Select
End Function

Sub socAC97clientAdd( ac97 As SocAC97 Ptr , which As Ac97Codec , regR As Ac97CodecRegR , regW As Ac97CodecRegW , userData As any Ptr)
	Dim As Ac97CodecStruct ptr cd = socAC97prvCodecPtrGet(ac97, which) 
	cd->regR = regR 
	cd->regW = regW 
	cd->userData = userData 
End Sub

Function socAC97clientClientWantData( ac97 As SocAC97 Ptr , which As Ac97Codec , dataPtr As ULong Ptr) As Bool
	Dim As Ac97CodecStruct Ptr cd = socAC97prvCodecPtrGet(ac97, which) 
	
	socAC97PrvFifoGet(ac97, @cd->txFifo, dataPtr) 
	
	' they still get data, just last valid data. not fresh new data
	return true 
End Function

Sub socAC97clientClientHaveData( ac97 As SocAC97 Ptr , which As Ac97Codec , datas As ULong)
	dim as Ac97CodecStruct ptr cd = socAC97prvCodecPtrGet(ac97, which) 
	
	socAC97PrvFifoAdd(ac97, @cd->rxFifo, datas) 
End Sub
