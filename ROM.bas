'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function romPrvWrite(rom As ArmRom Ptr , ofst As ULong , valor As Ushort) As Bool
   Dim As ArmRomPiece ptr piece = rom->pieces 

	while (piece<>0) AndAlso (piece->size <= ofst)  
		ofst -= piece->size 
		piece = piece->next_ 
   Wend
	
	if (piece=0) Then return false

	Select Case As Const (rom->chipType)  
		case RomStrataFlash16x 
			*Cast(UShort ptr,cast(byte ptr,piece->buf) + ofst    ) And= valor
		
		case RomStrataflash16x2x 
			*Cast(UShort ptr,cast(byte ptr,piece->buf) + ofst + 0) And= valor
			*Cast(UShort ptr,cast(byte ptr,piece->buf) + ofst + 2) And= valor Shr 16
		
		case else 
			return false 
   End Select

	return true 
End Function

Function romPrvErase(rom As ArmRom Ptr , ofst As ULong) As Bool
   Dim As ArmRomPiece ptr piece = rom->pieces 
	Dim As ULong now_, sz 

	Select Case As Const (rom->chipType)  
		case RomStrataFlash16x 
			sz = STRATAFLASH_BLOCK_SIZE 
		
		case RomStrataflash16x2x 
			sz = STRATAFLASH_BLOCK_SIZE * 2 
		
		case else 
			return false 
   End Select
	
	ofst \= sz 
	ofst *= sz 
	
	printf(!"SF erase at 0x%08x\n", ofst) 
	
	while (piece<>0) AndAlso (piece->size <= ofst)  
		ofst -= piece->size 
		piece = piece->next_ 
   Wend
	
	if (piece=0) Then return false
	
	while (sz)  
		if (piece=0) Then return false
		now_ = piece->size - ofst 
		if (now_ > sz) Then now_ = sz
		memset(cast(byte ptr,piece->buf) + ofst, &hff, now_) 
		sz -= now_ 
		ofst = 0 
		piece = piece->next_
   Wend
	
	return true 
End Function


' 128mbit reply
static shared As UShort qryReplies_from_0x10(...) = { _ 
	asc("Q"), asc("R"), asc("Y"), _
	1, 0, &h31, 0, 0, 0, 0, 0, &h27, &h36, 0, 0, _
	8, 9, 10, 0, 1, 1, 2, 0, &h18, 1, 0, 6, 0, 1, &h7f, 0, 0,   _
	3, _
	asc("P"), asc("R"), asc("I"), asc("1"), asc("1"), _
	&he6, 1, 0, 0, 1, 7, 0, &h33, 0, 2, &h80, _
	0, 3, 3, &h89, 0, 0, 0, 0, 0, 0, &h10, 0, 4, 4, 2, 2, _
	3 }
			
Function romAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , bufP As Any Ptr) As Bool
   Dim As ArmRomPiece ptr piece = Cast(ArmRomPiece ptr,userData) 
	Dim As UByte ptr addr = cast(byte ptr,piece->buf) 
   Dim As ArmRom ptr rom = piece->rom 
	Dim As ULong fromStart 

	fromStart = pa - rom->start 		'flashes care how far we are from start of flash, not of this arbitrary piece of it
	pa -= piece->base_
	if (pa >= piece->size) Then return false

	addr += pa 
	
	Dim As ULong addrBits = fromStart 
	Dim As ULong dataBits 
	dim As Bool diffData = false 	
	
	if (write_) Then 
		Select Case As Const (rom->chipType)  
			case RomWriteIgnore 
				return true 
				
			case RomWriteError 
				return false 
				
			case RomStrataflash16x2x 
				if (size <> 4) Then 
					MiPrint "StrataflashX2 command of improper size!"
					return false 
				EndIf
  
				dataBits = *cast(ulong ptr,bufP)
				
				diffData = iif((dataBits And &hffff) <> (dataBits Shr 16) ,1,0)
				dataBits And= &hffff 
				addrBits \= 4 ' revisar

			case RomStrataFlash16x 
				if (size <> 2) Then 
					MiPrint "Strataflash command of improper size!" 
					return false 
				EndIf
				dataBits = *cast(ushort ptr,bufP) 
				addrBits \= 2 ' revisar

			case else 
				return false 
      End Select

		if (rom->mode = StrataFlashSetSTS) Then   
			if (diffData) Then Return false
			rom->stsReg = dataBits 
			rom->mode = StrataFlashNormal 
			return true 
		ElseIf (rom->mode = StrataFlashSeen0x60) Then   
			if (diffData) Then return false
			if (dataBits = &h03) Then   	'set read config reg
				if (rom->possibleConfigReg <> addrBits) Then
					printf(!"Strataflash READ CONFIG REG SECOND CYCLE SAID 0x%04x, first was 0x%04x!\n", addrBits, rom->possibleConfigReg) 
					return false 
				EndIf
				rom->configReg = addrBits 
				rom->mode = StrataFlashNormal 
				return true 
			ElseIf (dataBits = &h01) OrElse (dataBits = &hd0) OrElse (dataBits = &h2f) Then 
				MiPrint "strataflash block locking not supported" 
				rom->mode = StrataFlashNormal 
				return true 
			else
				'unknown thing
				return false 
			EndIf
		ElseIf (rom->mode = StrataFlashWriCy1) Then  'due to the checks above for dup data, this is unlikely to work for writes to 32-bit-wide dual strata flash
			if (fromStart <> rom->opAddr) Then return false
			if (romPrvWrite(rom, fromStart, dataBits)=0) Then return false
			rom->busyCy = &h0010 
			rom->mode = StrataFlashReadStatus 
			return true 
		ElseIf (diffData) Then 
			printf(!"strataflash: ignoring write of 0x%08x -> [0x%08x]\n", dataBits, fromStart) 
			return true 
		else
        Select Case As Const (dataBits And &hff)  
			case &hb8 	'STS
				rom->mode = StrataFlashSetSTS 
				return true 
			
			case &h50 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then return false
				'clear status register
				rom->mode = StrataFlashNormal 
				return true 
			
			case &h60 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then  return false
				'set read config reg
				rom->possibleConfigReg = addrBits 
				rom->mode = StrataFlashSeen0x60 
				return true 
			
			case &h70 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then return false
				'read status register
				rom->mode = StrataFlashReadStatus 
				return true 
			
			case &h20 
				if (rom->mode <> StrataFlashNormal) Then return false
				rom->mode = StrataFlashErzCy1 
				rom->opAddr = fromStart 
				return true 
			
			case &h40 
				if (rom->mode <> StrataFlashNormal) Then return false
				rom->mode = StrataFlashWriCy1 
				rom->opAddr = fromStart 
				return true 
			
			case &hd0 
				if (rom->mode <> StrataFlashErzCy1) Then return false
				if (fromStart <> rom->opAddr)       Then return false
				if (romPrvErase(rom, fromStart)=0)  Then return false
				rom->busyCy = &h1000 
				rom->mode = StrataFlashReadStatus 
				return true 
			
			case &h90 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then return false
				'read identifier
				rom->mode = StrataFlashReadID 
				return true 
			
			case &h98 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then return false
				'read query CFI
				rom->mode = StrataFlashReadCFI 
				return true 
			
			case &hff 
				if (rom->mode = StrataFlashErzCy1) OrElse (rom->mode = StrataFlashWriCy1) Then return false
				'read
				rom->mode = StrataFlashNormal 
				return true 
			
			case else 
				printf(!"Unknown strataflash command 0x%04x -> [0x%08x]\n", dataBits, addrBits) 
				return false 
        End Select
		EndIf
  
		Select Case As Const (size)  
			case 1 
				*cast(ubyte  ptr,addr) = *cast(ubyte  ptr,bufP) 	'8bits our memory system is little-endian
			
			case 2 
				*cast(ushort ptr,addr) = *cast(ushort ptr,bufP) '16bits our memory system is little-endian
			
			case 4 
				*cast(ulong  ptr,addr) = *cast(ulong  ptr,bufP) '32bits
			
			case else 
				return false 
      End Select

	else

		'128mbit reply
		dim As Bool command_ = false 
		
		Select Case As Const (rom->mode)  	'what modes expect a read of command size? which arent allowed at all
			
			case StrataFlashReadStatus , StrataFlashReadID , StrataFlashReadCFI 
				command_ = true 
				Select Case As Const (rom->chipType)  
					case RomStrataFlash16x 
						if (size <> 2) Then 
							MiPrint "Strataflash read of improper size!"
							return false 
						EndIf
						fromStart \= 2 
					
					case RomStrataflash16x2x 
						if (size <> 4) Then 
							MiPrint "StrataflashX2 read of improper size!" 
							return false 
						EndIf
						fromStart \= 4 
					
					case else 
						return false 
            End Select
			
			case StrataFlashNormal , StrataFlashSeen0x60 	'in this mode we can still fetch
				' nada
			
			case else 
				return false 
      End Select
		
		if (command_) Then 
			dim As Bool skipdup = false 
			Dim As ULong reply 
			
			Select Case As Const (rom->mode)  
				case StrataFlashReadStatus 
					if rom->busyCy Then 
						rom->busyCy-=1  
						reply = 0 		'busy
					else
						rom->mode = StrataFlashNormal 	'only if not busy
						reply = &h0080 	'ready;
					EndIf
				
				case StrataFlashReadID 
					Select Case As Const  (fromStart)  
						case 0 
							reply = &h0089 

						case 1 
							reply = &h8802 

						case 5 
							reply = rom->configReg 

						case &h80 	'protection register lock
							reply = 2 
						
						case &h81 	'protection registers (uniq ID by intel and by manuf) copied from same chip as this rom
							reply = &h001d0017ul 
							skipdup = true 
						
						case &h82 
							reply = &h000a0003ul 
							skipdup = true 
						
						case &h83 
							reply = &h3fb03fa6ul 
							skipdup = true 
						
						case &h84 
							reply = &h48d9c99aul 
							skipdup = true 
						
						case &h85 to &h88 
							reply = &hffff 

						case &h89 	'otp lock - all locked for us
							reply = 0 

						case &h8A to &h109 	'otp data
							reply = 0 

						case else 
							fromStart mod= &h8000 
							
							Select Case As Const (fromStart)  
								case 0 		'id?
									'printf(!"strataflash weird read of 0x%08x in ID mode returns 0x%04x\n", fromStart , reply) 
									reply = &h89 
									
								case 2 		'block lock\lockdown
									reply = 0 

								case else 
									'printf(!"strataflash unknown read of 0x%08x in ID mode returns 0xffff\n", fromStart) 
									reply = &hffff 
                     End Select
               End Select
				
				case StrataFlashReadCFI 
					'printf(!"CFI Read 0x%08x\n", fromStart) 
					Select Case As Const (fromStart)  
						case &h00 
							reply = &h0089 

						case &h01 
							reply = &h8802 

						case &h10 to ((ubound(qryReplies_from_0x10)+1)*sizeof(qryReplies_from_0x10)) + &h10
							reply = qryReplies_from_0x10(fromStart - &h10) 

						case else 
							Select Case As Const (fromStart And &hffff)  
								case 2 'block status register
									reply = 0 

								case else 
									return false 
                     End Select
               End Select

					'printf(!"CFI Read 0x%08x -> 0x%04x\n", fromStart, reply) 
				
				case else 
					return false 
         End Select

			if (skipdup=0) Then reply Or= reply Shl 16

			if (rom->chipType = RomStrataFlash16x) Then
				*cast(uShort ptr,bufP) = reply '16
			else
				*cast(ulong  ptr,bufP) = reply '32
			EndIf

			return true 
		EndIf
  
	
	
		Select Case As Const (size)  
			case 1 
				*cast(UByte  ptr,bufP) = *cast(UByte  ptr,addr)
			
			case 2 
				*cast(UShort ptr,bufP) = *cast(UShort ptr,addr) 
			
			case 4 
				*cast(ULong  ptr,bufP) = *cast(ULong  ptr,addr)
				  
			case 8                   
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))				
				    
			case 16
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))             
				cast(ULong ptr,bufP)[2]  = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[3]  = *cast(ULong ptr,(addr + 12))											 						 
		
			case 32                                        
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))
				cast(ULong ptr,bufP)[2]  = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[3]  = *cast(ULong ptr,(addr + 12))        
				cast(ULong ptr,bufP)[4]  = *cast(ULong ptr,(addr + 16))
				cast(ULong ptr,bufP)[5]  = *cast(ULong ptr,(addr + 20))        
				cast(ULong ptr,bufP)[6]  = *cast(ULong ptr,(addr + 24))
				cast(ULong ptr,bufP)[7]  = *cast(ULong ptr,(addr + 28))
				
			case 64
				cast(ULong ptr,bufP)[ 0] = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[ 1] = *cast(ULong ptr,(addr +  4))
				cast(ULong ptr,bufP)[ 2] = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[ 3] = *cast(ULong ptr,(addr + 12))
				cast(ULong ptr,bufP)[ 4] = *cast(ULong ptr,(addr + 16))
				cast(ULong ptr,bufP)[ 5] = *cast(ULong ptr,(addr + 20))
				cast(ULong ptr,bufP)[ 6] = *cast(ULong ptr,(addr + 24))
				cast(ULong ptr,bufP)[ 7] = *cast(ULong ptr,(addr + 28))        
				cast(ULong ptr,bufP)[ 8] = *cast(ULong ptr,(addr + 32))
				cast(ULong ptr,bufP)[ 9] = *cast(ULong ptr,(addr + 36))
				cast(ULong ptr,bufP)[10] = *cast(ULong ptr,(addr + 40))
				cast(ULong ptr,bufP)[11] = *cast(ULong ptr,(addr + 44))        
				cast(ULong ptr,bufP)[12] = *cast(ULong ptr,(addr + 48))
				cast(ULong ptr,bufP)[13] = *cast(ULong ptr,(addr + 52))       
				cast(ULong ptr,bufP)[14] = *cast(ULong ptr,(addr + 56))
				cast(ULong ptr,bufP)[15] = *cast(ULong ptr,(addr + 60))
			
			case else 
				return false 
      End Select
   EndIf

	return true 
End Function


 
Function romInit( mem As ArmMem Ptr , adr As Ulong , pieces As Any Ptr Ptr, pieceSizes As ULong Ptr , numPieces As ULong , chipType As RomChipType) As ArmRom ptr
	Dim as ArmRom ptr rom = Cast(ArmRom Ptr,Callocate(sizeof(ArmRom)) )
	Dim as ArmRomPiece ptr prev = NULL, t = Null, piece = NULL 
	Dim As Ulong i 

	if (rom=0) Then PERR("cannot alloc ROM at "+hex(adr))

	memset(rom, 0, sizeof(ArmRom)) 
	
	if (numPieces > 1) AndAlso (chipType <> RomWriteIgnore) AndAlso (chipType <> RomWriteError) then
		PERR("piecewise roms cannot be writeable")
	EndIf

	rom->start = adr 
	
	for i = 0 To numPieces-1 ' numPieces=1 segun AXIM-X3   
		piece = cast(ArmRomPiece ptr,Callocate(sizeof(ArmRomPiece))) 
		if (piece=0) Then PERR("cannot alloc ROM piece at "+hex(adr))

		memset(piece, 0, sizeof(ArmRomPiece)) 
		piece->next_ = prev 	'we´ll reverse the list later
		
		if (adr And &h1f) Then PERR("rom piece cannot start at "+hex(adr))

      ' revisar pieceSizes y pieces, no se si son * o sin el
		piece->base_= adr 
		piece->size = *pieceSizes : pieceSizes+=1
		piece->buf  = cast(Ulong ptr,pieces) : pieces+=1  
		piece->rom  = rom 

		adr += piece->size 
	
		if memRegionAdd(mem, piece->base_, piece->size, cast(ArmMemAccessF ,@romAccessF), piece)=0 Then 
			PERR("cannot add ROM piece at to MEM "+hex(adr))
		EndIf
   Next
	
	'we linked the list in reverse. fix this
	while (piece)  
		t = piece->next_
		piece->next_ = rom->pieces 
		rom->pieces  = piece 
		piece = t 
   Wend
	
	rom->chipType  = chipType 
	rom->mode      = StrataFlashNormal 
	rom->configReg = &hc0c2 
	
	return rom 
End Function

