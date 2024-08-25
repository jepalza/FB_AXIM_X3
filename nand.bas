'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub nandSecondReadyCbkSet(nand As NAND_T Ptr , readyCbk As NandReadyCbk , readyCbkData As Any Ptr)
	nand->readyCbk(1) = readyCbk 
	nand->readyCbkData(1) = readyCbkData 
End Sub

Sub nandPrvCallReadyCbks(nand As NAND_T Ptr , ready As Bool)
	Dim As Ubyte i 
	for i = 0 To Ubound(nand->readyCbk)       
		if nand->readyCbk(i) Then nand->readyCbk(i)(nand->readyCbkData(i), ready)
   Next
End Sub

Sub nandPrvBusy(nand As NAND_T Ptr , count As ULong)
	if (nand->busyCt) Then 
		PERR("NAND was already busy") 
	else
		nand->busyCt = count 
		nandPrvCallReadyCbks(nand, false) 
	EndIf
End Sub

Function nandPrvGetAddrValLE(nand As NAND_T Ptr , startByte As Ubyte , numBytes As Ubyte) As ULong
	Dim As ULong ret = 0 
	Dim As Ubyte i 
	for i = 0 To numBytes-1         
		ret Shl = 8 
		ret += nand->addrBytes(startByte + numBytes - 1 - i) 
   Next
	
	return ret 
End Function

Function nandPrvGetPageAddr(nand As NAND_T Ptr , addrOfst As Ubyte) As ULong
	return nandPrvGetAddrValLE(nand, addrOfst, nand->pageAddrBytes) 
End Function

Function nandPrvGetByteAddr(nand As NAND_T Ptr) As ULong
	return nandPrvGetAddrValLE(nand, 0, nand->byteAddrBytes) 
End Function

Function nandPrvBlockErase(nand As NAND_T Ptr) As Bool
	Dim As ULong addr = nandPrvGetPageAddr(nand, 0) 
	if (addr And ((1UL Shl nand->pagesPerBlockLg2) - 1)) Then return false

	memset(nand->datas + addr * nand->bytesPerPage, &hff, nand->bytesPerPage Shl nand->pagesPerBlockLg2) 
	
	return true 
End Function

Function nandPrvPageProgram(nand As NAND_T Ptr) As Bool
	Dim As ULong i 

	for i = 0 To nand->bytesPerPage -1        
		nand->datas[nand->pageNo * nand->bytesPerPage + i] And= nand->pageBuf[i]
	Next
	
	return true 
End Function

Function nandPrvAcceptProgramData(nand As NAND_T Ptr , valor As UByte) As Bool
	if (nand->pageOfst >= nand->bytesPerPage) Then 
		'real hardware ignored extra bytes being written, and so do we
		return true 
	EndIf
  
	nand->pageBuf[nand->pageOfst] = valor 
	nand->pageOfst+=1
	
	return true 
End Function

Function nandWrite(nand As NAND_T Ptr , cle As Bool , ale As Bool , valor As UByte) As Bool
	if (cle<>0) AndAlso (ale=0) Then   	'command
		
		Select Case As Const (valor)  
			case &h00 
				nand->area  = K9nandAreaA 
				nand->state = K9nandStateReading 
				nand->addrBytesRxed = 0 
			
			case &h01 
				if (nand->flags And NAND_FLAG_SAMSUNG_ADDRESSED_VIA_AREAS) Then
					nand->area = K9nandAreaB 
					nand->state = K9nandStateReading 
					nand->addrBytesRxed = 0 
				else
					return false
				EndIf
			
			case &h30 
				if ((nand->flags And NAND_HAS_SECOND_READ_CMD)<>0) AndAlso (nand->addrBytesRxed = (nand->byteAddrBytes + nand->pageAddrBytes)) Then 
					nand->addrBytesRxed = &hfe 	'special value
				else
					return false
				EndIf
			
			case &h50 
				if (nand->flags And NAND_FLAG_SAMSUNG_ADDRESSED_VIA_AREAS) Then 
					nand->area = K9nandAreaC 
					nand->state = K9nandStateReading 
					nand->addrBytesRxed = 0 
				else
					return false
				EndIf
			
			case &h60 
				if (nand->state <> K9nandStateReset  ) AndAlso _
				   (nand->state <> K9nandStateReading) AndAlso _
					(nand->state <> K9nandStateReadId ) AndAlso _
					(nand->state <> K9nandStateStatusReading) Then 
					return false
				EndIf
  
				nand->state = K9nandStateEraseAddrRxing 
				nand->addrBytesRxed = 0 
			
			case &hd0 
				if (nand->area = K9nandAreaB) Then nand->area = K9nandAreaA
				if (nand->state <> K9nandStateEraseAddrRxing) OrElse (nand->addrBytesRxed <> 2) Then 
					return false
				EndIf

				if (nandPrvBlockErase(nand)=0) Then 
					return false
				EndIf
  
				nandPrvBusy(nand, 100) 
				nand->state = K9nandStateReset 
				nand->addrBytesRxed = 0 
			
			case &h80 
				if (nand->state <> K9nandStateReset  ) AndAlso _
				   (nand->state <> K9nandStateReading) AndAlso _
					(nand->state <> K9nandStateReadId ) AndAlso _
					(nand->state <> K9nandStateStatusReading) Then 
					return false
				EndIf
  
				nand->state = K9nandStateProgramAddrRxing 
				nand->addrBytesRxed = 0 
			
			case &h10 
				if (nand->area = K9nandAreaB) Then nand->area = K9nandAreaA
				if (nand->state <> K9nandStateProgramDataRxing) Then return false

				if (nandPrvPageProgram(nand)=0) Then return false

				nandPrvBusy(nand, 10) 
				nand->state = K9nandStateReset 
				nand->addrBytesRxed = 0 
			
			case &h90 
				if (nand->state <> K9nandStateReset   ) AndAlso _
				   (nand->state <> K9nandStateReading ) AndAlso _
					(nand->state <> K9nandStateReadId  ) AndAlso _
					(nand->state <> K9nandStateStatusReading) Then 
					return false
				EndIf
  
				nand->state = K9nandStateReadId 
				nand->addrBytesRxed = 0 
			
			case &h70 
				nand->state = K9nandStateStatusReading 
				nand->addrBytesRxed = 0 
			
			case &hff 
				nand->area  = K9nandAreaA 
				nand->state = K9nandStateReset 
				nand->addrBytesRxed = 0 
			
			case else 
				printf(!"unknown command 0x%02x. halt.\n", valor) 
				beep : sleep

      End Select

	ElseIf (cle=0) AndAlso (ale<>0) Then   	'addr
		
		Select Case As Const (nand->state)  
			case K9nandStateReadId 
				if (nand->addrBytesRxed >= 1) Then return false

			case K9nandStateProgramAddrRxing 
				if (nand->addrBytesRxed >= (nand->byteAddrBytes + nand->pageAddrBytes)) Then return true

			case K9nandStateEraseAddrRxing 
				if (nand->addrBytesRxed >= nand->pageAddrBytes) Then return true

			case K9nandStateReading 
				if (nand->addrBytesRxed >= (nand->byteAddrBytes + nand->pageAddrBytes)) Then return true
				if (nand->addrBytesRxed  = (nand->byteAddrBytes + nand->pageAddrBytes - 1)) Then 
					'about to become enough
					nandPrvBusy(nand, 1)
				EndIf

			case else 
				return false 
      End Select

		nand->addrBytes(nand->addrBytesRxed) = valor 
		nand->addrBytesRxed+=1 
	 
	ElseIf (cle=0) AndAlso (ale=0) Then  'data
		
		Select Case As Const (nand->state)  
			case K9nandStateProgramAddrRxing 
				if nand->addrBytesRxed <> (nand->byteAddrBytes + nand->pageAddrBytes) Then return false

				nand->state  = K9nandStateProgramDataRxing 
				nand->pageNo = nandPrvGetPageAddr(nand, nand->byteAddrBytes) 
				
				if nand->pageNo >= (nand->blocksPerDevice Shl nand->pagesPerBlockLg2) Then return false
				
				memset(nand->pageBuf, &hff, nand->bytesPerPage) 
				
				Select Case As Const (nand->area)  
					case K9nandAreaA 
						nand->pageOfst = 0 

					case K9nandAreaB 
						nand->area = K9nandAreaA 
						nand->pageOfst = nand->areaSize 

					case K9nandAreaC 
						nand->pageOfst = 2 * nand->areaSize 

					case else 
						return false 
            End Select

				nand->pageOfst += nandPrvGetByteAddr(nand) 
				'Cascada_CASE con "K9nandStateProgramDataRxing"
				if (nandPrvAcceptProgramData(nand, valor)=0) Then return false
			
			case K9nandStateProgramDataRxing 
				if (nandPrvAcceptProgramData(nand, valor)=0) Then return false
			
			case else 
				return false 
      End Select
	else
		return false
	EndIf
	
	return true 
End Function

Function nandRead(nand As NAND_T Ptr , cle As Bool , ale As Bool , valP As UByte Ptr) As Bool
	if (cle<>0) OrElse (ale<>0) Then return false

	Select Case As Const (nand->state)  
		case K9nandStateReadId 
			if (nand->addrBytesRxed <> 1) Then return false
			if (nand->addrBytes(0) >= nand->deviceIdLen) Then return false
			*valP = nand->deviceId(nand->addrBytes(0)) 
			nand->addrBytes(0)+=1
			return true 
		
		case K9nandStateStatusReading 
			*valP = iif(nand->busyCt , &h00 , &h40 )
			return true 
		
		case K9nandStateReading 
			if ((nand->flags And NAND_HAS_SECOND_READ_CMD)=0) AndAlso _
			      (nand->addrBytesRxed = (nand->byteAddrBytes + nand->pageAddrBytes)) Then 
				nand->addrBytesRxed = &hfe 'special marker
				EndIf
		
			if (nand->addrBytesRxed = &hfe) Then 
				nand->pageNo = nandPrvGetPageAddr(nand, nand->byteAddrBytes) 
				nand->addrBytesRxed = &hff 	'special marker
					
				if (nand->pageNo >= (nand->blocksPerDevice Shl nand->pagesPerBlockLg2)) Then 	
					MiPrint "page number ouf of bounds"
					return false 
				EndIf

				memcpy(nand->pageBuf, @nand->datas[nand->pageNo * nand->bytesPerPage], nand->bytesPerPage) 
				
				Select Case As Const (nand->area)  
					case K9nandAreaA 
						nand->pageOfst = 0 

					case K9nandAreaB 
						nand->pageOfst = nand->areaSize 
						nand->area = K9nandAreaA 

					case K9nandAreaC 
						nand->pageOfst = 2 * nand->areaSize 
            End Select

				nand->pageOfst += nandPrvGetByteAddr(nand) 
			EndIf
			
			if (nand->addrBytesRxed <> &hff) Then return false
			if (nand->pageOfst = nand->bytesPerPage) Then 
				'read next page
				nand->pageNo+=1  
				nand->pageOfst = iif(nand->area = K9nandAreaC , 2 * nand->areaSize , 0 )
				memcpy(@nand->pageBuf, @nand->datas[nand->pageNo * nand->bytesPerPage], nand->bytesPerPage) 
			EndIf
  
			*valP = nand->pageBuf[nand->pageOfst]
			nand->pageOfst+=1
			return true 
		
		case else 
			return false 
	
   End Select

End Function

Sub nandPeriodic(nand As NAND_T Ptr)
	' complicada comparacion: primero si NO es cero, y luego, resta y SI es cero....
	' a ver si acierto con esto
	'if (nand->busyCt<>0) AndAlso (nand->busyCt=0) Then 
	if (nand->busyCt<>0) then ' primero si NO es cero
		nand->busyCt-=1 ' ahora, resta 1
		if (nand->busyCt=0) Then ' y ahora SI es cero
			nandPrvCallReadyCbks(nand, true)
		endif
	EndIf
End Sub

Function nandIsReady(nand As NAND_T Ptr) As Bool
	return iif(nand->busyCt=0,1,0) ' si no me equivoco, un valor 0 devuelve 1, el resto 0
End Function

Function nandInit( nandFile As FILE Ptr , specs As NandSpecs Ptr , readyCbk As NandReadyCbk , readyCbkData As Any Ptr) As NAND_T ptr
   Dim As NAND_T ptr nand = cast(NAND_t ptr,Callocate(sizeof(NAND_T)) )
	Dim As ULong nandSz, nandPages, t 
	
	if (nand=0) Then PERR("cannot alloc NAND")
	print "NAND podria fallar con los SIZEOF, revisar":beep:sleep
	memset(nand, 0, sizeof(NAND_T)) 
	nand->readyCbk(0)     = readyCbk 
	nand->readyCbkData(0) = readyCbkData 
	
	nand->flags            = specs->flags 
	nand->bytesPerPage     = specs->bytesPerPage 
	nand->pagesPerBlockLg2 = specs->pagesPerBlockLg2 
	nand->blocksPerDevice  = specs->blocksPerDevice 
	if (specs->devIdLen > sizeof(nand->deviceId)) Then ' revisar
		PERR("Device ID too long") 
	else
		nand->deviceIdLen = specs->devIdLen
	EndIf
  
	memcpy(@nand->deviceId(0), @specs->devId(0), nand->deviceIdLen) 
	
	nandPages = nand->blocksPerDevice Shl nand->pagesPerBlockLg2 
	nandSz = nand->bytesPerPage * nandPages 
	
	t = 31 - __builtin_clz(specs->bytesPerPage - 1) 
	if (specs->flags And NAND_FLAG_SAMSUNG_ADDRESSED_VIA_AREAS) Then 
		'one bit of address goes away via "area" commands
		t-=1 
	EndIf
  
	nand->byteAddrBytes = (t + 7) \ 8 
	nand->areaSize = 1 Shl t 
	nand->pageAddrBytes = (31 - __builtin_clz(nandPages - 1) + 7) \ 8 
	
	nand->pageBuf = cast(ubyte ptr,Callocate(nand->bytesPerPage))
	if (nand->pageBuf=0) Then 
		PERR("No se puede localizar espacio para la NAND")
	EndIf

	nand->datas = cast(ubyte ptr,Callocate(nandSz) )
	if (nand->datas=0) Then 
		PERR("No se puede localizar espacio para la NAND")
	EndIf
	
	if (nandFile) Then   
		t = fread(nand->datas, 1, nandSz, nandFile) 
		if (nandSz <> t) Then
			printf(!"Cannot read nand. got %lu, wanted %lu\n", t, nandSz) 
			free(nand) 
			return NULL 
		else
			printf(!"read %u bytes of nand\n", nandSz)
		EndIf
	ElseIf (nandFile=0) Then 
		memset(nand->datas, &hff, nandSz)
	EndIf
  
	nandPrvBusy(nand, 1) 'we start busy for a little bit
	
	return nand 
End Function

