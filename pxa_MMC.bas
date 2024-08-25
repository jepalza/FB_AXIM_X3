'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub pxaMmcPrvIrqUpdate(mmc As PxaMmc Ptr)
	Dim As ULong irqs = mmc->iReg 
	
	'mask as per mask
	irqs And= INV( mmc->iMask )
	
	'dma masks fifo irqs
	if (mmc->cmdat And &h80) Then irqs And= INV( &h60 )

	socIcInt(mmc->ic, PXA_I_MMC, NOT_NOT(irqs) )
End Sub

Sub pxaMmcPrvRecalcIregAndFifo(mmc As PxaMmc Ptr)
	if (mmc->stat And &h100) Then 
		mmc->iReg And= INV( &h10 )
	else
		mmc->iReg Or= &h10
	EndIf
  
	mmc->iReg And= INV( 7 )
	mmc->iReg Or= (mmc->stat Shr 11) And 7 
	
	if ((mmc->cmdat And 4)<>0) AndAlso ((mmc->cmdat And 8)<>0) AndAlso (mmc->numBlks<>0) Then 
		mmc->stat Or= &h40 
		mmc->iReg Or= &h40 
	EndIf

	if ((mmc->cmdat And 4)<>0) AndAlso ((mmc->cmdat And 8)=0) AndAlso ((mmc->numBlks<>0) OrElse ((mmc->fifoByteS<>0)<>0)) Then 
		mmc->stat Or= &h80 
		mmc->iReg Or= &h20 
	EndIf
 
	if (mmc->cmdat And &h80) Then 
		socDmaExternalReq(mmc->dma, DMA_CMR_MMC_RX, NOT_NOT(mmc->iReg And &h20)) 
		socDmaExternalReq(mmc->dma, DMA_CMR_MMC_TX, NOT_NOT(mmc->iReg And &h40)) 
	EndIf

	pxaMmcPrvIrqUpdate(mmc) 
End Sub

Sub pxaMmcPrvDataXferNextBlockRead(mmc As PxaMmc Ptr)
	Dim As SdDataReplyType ret 
	
	if (mmc->dataXferOngoing=0) Then 
		miprint "Cannot read block if no xfer ongoing"
		return 
	EndIf

	ret = vsdDataXferBlockFromCard(mmc->vsd, @mmc->blockFifo(0), mmc->blkLen) 
	Select Case As Const (ret)  
		case SdDataErrWrongBlockSize 		'would manifest as a crc error
			mmc->stat Or= &h0008 			'crc read error
		case SdDataOk 
			mmc->fifoBytes = mmc->blkLen 
			mmc->fifoOfst = 0 
			mmc->numBlks-=1  
		case SdDataErrWrongCurrentState , _ 	'would manifest as a timeout
		     SdDataErrBackingStore 
			mmc->stat Or= &h0001 
		case else
			mmc->stat Or= &h0001 ' igual al CASE anterior
   End Select
End Sub

Sub pxaMmcPrvDataXferStart(mmc As PxaMmc Ptr)
	mmc->dataXferOngoing = true 
	
	if (mmc->blkLen=0) OrElse (mmc->numBlks=0) Then 
		print "MMC xfer cannot start with zero length (";mmc->blkLen;" B x ";mmc->numBlks;")"
		return 
	EndIf
	
	if (mmc->cmdat And 8) Then  'write
		mmc->fifoBytes = 0 
	else 'read
		pxaMmcPrvDataXferNextBlockRead(mmc) 
	EndIf
End Sub

Function pxaMmcPrvDataFifoW(mmc As PxaMmc Ptr , valor As ULong) As Bool
	if (mmc->fifoBytes >= mmc->blkLen) Then 
		MiPrint "Cannot write over-full fifo" 
		return false 
	EndIf
 
	mmc->blockFifo(mmc->fifoBytes) = valor 
	mmc->fifoBytes+=1
	
	if (mmc->fifoBytes = mmc->blkLen) Then 
		Dim as SdDataReplyType ret 
		if (mmc->dataXferOngoing=0) Then 
			MiPrint "Cannot write block if no xfer ongoing" 
			return false 
		EndIf
  
		ret = vsdDataXferBlockToCard(mmc->vsd, @mmc->blockFifo(0), mmc->blkLen) 
		Select Case As Const (ret)  
			case SdDataOk 
				mmc->fifoBytes = 0 
				mmc->numBlks-=1  
				if (mmc->numBlks=0) Then 
					mmc->stat Or= &h0800 		'data xfer done
					mmc->stat Or= &h1000 		'not busy
					mmc->dataXferOngoing = false 
				EndIf
			case SdDataErrWrongBlockSize ,_ 		'would manifest as a crc error
				SdDataErrWrongCurrentState ,_ 	'would manifest as a timeout but we report all as crc errors
				SdDataErrBackingStore 
				mmc->stat Or= &h0004 			'crc write error
			case else 
				mmc->stat Or= &h0004 			'crc write error
      End Select
	EndIf
  
	pxaMmcPrvRecalcIregAndFifo(mmc) 
	
	return true 
End Function

Function pxaMmcPrvDataFifoR(mmc As PxaMmc Ptr , valP As ULong Ptr) As Bool

	if (mmc->fifoBytes=0) Then 
		MiPrint "MMC unit fifo empty at read"
		return false 
	EndIf
  
	*valP = mmc->blockFifo(mmc->fifoOfst)
	mmc->fifoOfst+=1
	mmc->fifoBytes-=1  
	
	if (mmc->fifoBytes=0) Then 
		if (mmc->numBlks) Then 
			pxaMmcPrvDataXferNextBlockRead(mmc) 
		else
			mmc->stat Or= &h0800 		'data xfer done
			mmc->dataXferOngoing = false 
		EndIf
	EndIf
  
	pxaMmcPrvRecalcIregAndFifo(mmc) 
	return true 
End Function


Function mmcSendCommand(mmc As PxaMmc Ptr) As Bool
	Dim As Bool success = false, doCrcCheck = true, withBusy = false, crcFail = false 
	Dim As SdReplyType ret 
	Dim As UByte reply(16) 
	Dim As ULong i, len_
	
	mmc->cmdQueued = false 
	
	if (mmc->vsd) Then 
		ret = vsdCommand(mmc->vsd, mmc->cmdReg And &h3f, mmc->arg, @reply(0)) 
	else
		ret = SdReplyNone 
	EndIf
  
	Select Case As Const (ret)  
		case SdReplyNone 
			len_ = 0 
			if ((mmc->cmdat And 3) = 0) Then  'no reply as expected
				success = true 
			else
				print "Got no reply, when ";iif((mmc->cmdat And 3) = 2 , 136 , 48);" bits were expected"
			EndIf
		
		case SdReply48bits , SdReply48bitsAndBusy
			if ret=SdReply48bitsAndBusy then withBusy = true ' caso anidado
			len_ = 5 
			if (mmc->cmdat And 1) Then  ' 48-bit reply as expected
				success = true 
				doCrcCheck = iif(mmc->cmdat And 2,1,0)
			else
				print "Got a 48-bit reply with, when ";iif((mmc->cmdat And 3) = 2 , 136 , 0);" bits were expected"
			EndIf
		
		case SdReply136bits 
			len_ = 16 
			if ((mmc->cmdat And 3) = 2) Then  '136-bit reply as expected
				success = true 
			else
				print "Got a 136-bit reply reply, when ";iif((mmc->cmdat And 3) = 2 , 48 , 0);" bits were expected"
			EndIf
   End Select

	'revisar withBusy() 	'our card is never busy
	
	'response to handle?
	if (success<>0) AndAlso (len_<>0) AndAlso (doCrcCheck<>0) Then 
		crcFail = iif(vsdCRC7(@reply(0), len_) <> reply(len_),1,0)
	endif

	mmc->stat Or= &h2000 	'cmd-resp over
	if (crcFail) Then mmc->stat Or= &h20
	if (0=success) Then 
		mmc->stat Or= &h02 	'resp timed out if wrong type
	else
		reply(len_) = 0 
		for i = 0 To len_-1 step 2     
			mmc->respBuf(i \ 2) = ((culng(reply(i))) Shl 8) + reply(i + 1)
      Next
	EndIf
  
	' data to handle?
	if (success<>0) AndAlso ((mmc->cmdat And 4)<>0) Then pxaMmcPrvDataXferStart(mmc)

	'all cases except write, we´re not busy by response time
	if (0=success) OrElse (0=(mmc->cmdat And 4)) OrElse (0=(mmc->cmdat And 8)) Then mmc->stat Or= &h1000 'not busy
	
	pxaMmcPrvRecalcIregAndFifo(mmc) 
	
	return true 
End Function

Function pxaMmcPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   Dim As PxaMmc ptr mmc = cast(PxaMmc ptr,userData) 
	Dim As ULong valor = 0 
	Dim As Bool ret = true 
	
	if(size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 
	EndIf
  
	pa = (pa - PXA_MMC_BASE) Shr 2 

	if (write_) Then valor = *cast(ULong ptr,buf)

	Select Case As Const (pa)  
		case 0 
			if (0=write_) Then return false
			Select Case As Const (valor And 3)  
				case 0 	'do nothing
					'nada
					
				case 1 	'stop clock
					' MiPrint "MMC: clock off"
					mmc->clockOn = false 
					mmc->stat And= INV( &h100 )
					pxaMmcPrvRecalcIregAndFifo(mmc) 

				case 2 	'start clock
					' MiPrint "MMC: clock on"
					mmc->clockOn = true 
					mmc->stat Or= &h100 
					pxaMmcPrvRecalcIregAndFifo(mmc) 
					if (mmc->cmdQueued) Then ret = mmcSendCommand(mmc)

				case else 
					ret = false 
         End Select
			pxaMmcPrvIrqUpdate(mmc) 
		
		case 1 
			if (write_) Then 
				'ignored
			else
				valor = mmc->stat
			EndIf
		
		case 2 
			if (write_) Then 
				valor And= 7 
				if (valor = 7) Then ret = false 
				mmc->clockSpeed = valor 
			else
				valor = mmc->clockSpeed
			EndIf
		
		case 3 
			if (write_) Then 
				mmc->spi = valor And &h0f 
			else
				valor = mmc->spi
			EndIf
		
		case 4 
			if (write_) Then 
				mmc->cmdat = valor 
				mmc->stat And= &h100 
				mmc->stat Or= &h40 
				pxaMmcPrvRecalcIregAndFifo(mmc) 
				if (mmc->clockOn) Then 
					ret = mmcSendCommand(mmc) 
				else
					mmc->cmdQueued = true
				EndIf
			else
				valor = mmc->cmdat
			EndIf
		
		case 5 
			if (write_) Then 
				mmc->resTo = valor And &h7f 
			else
				valor = mmc->resTo
			EndIf
		
		case 6 
			if (write_) Then 
				mmc->readTo = valor 
			else
				valor = mmc->readTo
			EndIf
		
		case 7 
			if (write_) Then 
				mmc->blkLen = valor And &h3ff 
			else
				valor = mmc->blkLen
			EndIf
		
		case 8 
			if (write_) Then 
				mmc->numBlks = valor 
			else
				valor = mmc->numBlks
			EndIf
		
		case 10 
			if (write_) Then 
				mmc->iMask = valor And &h7f 
				pxaMmcPrvIrqUpdate(mmc) 
			else
				valor = mmc->iMask
			EndIf
		
		case 11 
			if (write_) Then 
				'nothing
			else
				valor = mmc->iReg 
				mmc->iReg And= INV( &h60 )
				pxaMmcPrvRecalcIregAndFifo(mmc) 
			EndIf
		
		case 12 
			if (write_) Then 
				mmc->cmdReg = &h40 Or (valor And &h3f) 
			else
				valor = mmc->cmdReg
			EndIf
		
		case 13 
			if (write_) Then 
				mmc->arg = (mmc->arg And &h0000fffful) Or (valor Shl 16) 
			else
				valor = mmc->arg Shr 16
			EndIf
		
		case 14 
			if (write_) Then 
				mmc->arg = (mmc->arg And &hffff0000ul) Or (valor And &hffff) 
			else
				valor = mmc->arg And &hffff
			EndIf
		
		case 15 	'rep buf
			if (write_) Then 
				ret = false 
			else
				valor = mmc->respBuf(0) 
				memmove(@mmc->respBuf(0), @mmc->respBuf(0) + 1, (UBound(mmc->respBuf)-0)*sizeof(ushort) ) ' respbuf=ushort=2bytes
			EndIf
		
		case 16 
			if (write_) Then 
				ret = false 
			else
				ret = pxaMmcPrvDataFifoR(mmc, @valor)
			EndIf
		
		case 17 
			if (write_) Then
				ret = pxaMmcPrvDataFifoW(mmc, valor) 
			else
				ret = false
			EndIf
		
		case else 
			ret = false 
   End Select

	if (ret) Then 
		if (0=write_) Then *cast(ULong ptr,buf) = valor
	EndIf
  
	return ret 
End Function
 
Function pxaMmcInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr) As PxaMmc ptr
	dim as PxaMmc ptr mmc = cast(PxaMmc ptr,Callocate(sizeof(PxaMmc)) )
	
	if (mmc=0) Then PERR("cannot alloc MMC")
	
	memset(mmc, 0, sizeof(PxaMmc)) 
	
	mmc->ic    = ic 
	mmc->dma   = dma 
	mmc->iMask = &h7f 
	mmc->cmdat = &h80 
	mmc->resTo = &h40 
	mmc->cmdReg= &h40 
	mmc->stat  = &h40 
	pxaMmcPrvRecalcIregAndFifo(mmc) 
	
	if memRegionAdd(physMem, PXA_MMC_BASE, PXA_MMC_SIZE, cast(ArmMemAccessF ,@pxaMmcPrvMemAccessF), mmc)=0 Then 
		PERR("cannot add MMC to MEM")
	EndIf
  
	return mmc 
End Function

Sub pxaMmcInsert( mmc As PxaMmc Ptr , vsd As _VSD2 Ptr)
	mmc->vsd = vsd 
End Sub
