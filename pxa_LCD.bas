'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub pxaLcdPrvUpdateInts(lcd As PxaLcd Ptr)
	Dim As Ushort ints = lcd->lcsr And lcd->intMask 
	
	if ((ints<>0) AndAlso (lcd->intWasPending=0)) OrElse ((ints=0) AndAlso (lcd->intWasPending<>0)) Then 
		lcd->intWasPending = NOT_NOT(ints) 
		socIcInt(lcd->ic, PXA_I_LCD, NOT_NOT(ints) ) 
	EndIf
End Sub

Function pxaLcdPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   dim As PxaLcd ptr lcd = cAst(PxaLcd ptr,userData)
	Dim As Ushort v16 
	Dim As ULong valor = 0 
	
	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR",iif(write_ , "write" , "read"), size, pa) 
		return false 		'we do not support non-word accesses
	EndIf
  
	pa = (pa - PXA_LCD_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
		Select Case As Const (pa)  
			case 0 
				if ((lcd->lccr0 Xor valor) And &h0001) Then 
					'something changed about enablement - handle it
					lcd->enbChanged = 1
				EndIf

				lcd->lccr0 = valor 
				'recalc intMask
				v16 = UNMASKABLE_INTS 
				if (valor And &h00200000UL) Then 
					'output fifo underrun
					v16 Or= &h0040
				EndIf
  
				if (valor And &h00100000UL) Then 
					'branch int
					v16 Or= &h0200
				EndIf
  
				if (valor And &h00000800UL) Then 
					'quick disable
					v16 Or= &h0001
				EndIf
  
				if (valor And &h00000040UL) Then 
					'end of frame
					v16 Or= &h0080
				EndIf
  
				if (valor And &h00000020UL) Then 
					'input fifo underrun
					v16 Or= &h0030
				EndIf
  
				if (valor And &h00000010UL) Then 
					'start of frame
					v16 Or= &h0002
				EndIf
  
				lcd->intMask = v16 
				pxaLcdPrvUpdateInts(lcd) 
			
			case 1 
				lcd->lccr1 = valor 
			
			case 2 
				lcd->lccr2 = valor 
			
			case 3 
				lcd->lccr3 = valor 
			
			case 4 
				lcd->lccr4 = valor 
			
			case 5 
				lcd->lccr5 = valor 
			
			case 68 ,69 
				pa -= 69 
				pa += 13 
				pa += 1 
				'Cascada_CASE siguiente
				lcd->fbr(pa - 8) = valor 
				
			case 8 ,9 ,10 ,11 ,13 
				lcd->fbr(pa - 8) = valor 
			
			case 14 
				lcd->lcsr And= INV( valor )
				pxaLcdPrvUpdateInts(lcd) 
			
			case 15 
				lcd->liicr = valor 
			
			case 16 
				lcd->trgbr = valor 
			
			case 17 
				lcd->tcr = valor 
			
			case 128 ,132 , 136 ,140 ,144 ,148 ,152 
				lcd->fdadr((pa - 128) \ 4) = valor 
      End Select
	 
	else
        
		Select Case As Const (pa)  
			case 0 
				valor = lcd->lccr0 
			
			case 1 
				valor = lcd->lccr1 
			
			case 2 
				valor = lcd->lccr2 
			
			case 3 
				valor = lcd->lccr3 
			
			case 4 
				valor = lcd->lccr4 
			
			case 5 
				valor = lcd->lccr5 
			
			case 68 ,69 
				pa -= 69 
				pa += 13 
				pa += 1 
				'Cascada_CASE siguiente
				valor = lcd->fbr(pa - 8)
				
			case 8 ,9 ,10 ,11 ,13 
				valor = lcd->fbr(pa - 8) 
			
			case 14 
				valor = lcd->lcsr 
			
			case 15 
				valor = lcd->liicr 
			
			case 16 
				valor = lcd->trgbr 
			
			case 17 
				valor = lcd->tcr 
			
			case 128 ,132 ,136 ,140 ,144 ,148 ,152 
				valor = lcd->fdadr((pa - 128) \ 4) 
			
			case 129 ,133 ,137 ,141 ,145 ,149 ,153 
				valor = lcd->fsadr((pa - 129) \ 4) 
			
			case 130 ,134 ,138 ,142 ,146 ,150 ,154 
				valor = lcd->fidr((pa - 130) \ 4) 
			
			case 131 ,135, 139 ,143 ,147 ,151 ,155 
				valor = lcd->ldcmd((pa - 131) \ 4) 
				
      End Select

		*cast(ULong ptr,buf) = valor 
	EndIf
  
	return true 
End Function

Function pxaLcdPrvGetWord(lcd As PxaLcd Ptr , addr As ULong) As ULong
	Dim As ULong v 
	if memAccess(lcd->mem, addr, 4, false, @v)=0 Then return 0
	return v 
End Function

Sub pxaLcdPrvDma(lcd As PxaLcd Ptr , dest As Any Ptr , addr As ULong , len_ As Long)
	Dim As UByte ptr d = cast(UByte ptr,dest) 
	Dim As ULong t 

	'we assume aligntment here both on part of dest and of addr
	while (len_ > 0)  ' revisar
		t = pxaLcdPrvGetWord(lcd, addr) 
		if (len_ > 0) Then *d = t        : d+=1 : endif
		len_-=1
		if (len_ > 0) Then *d = t shr 8  : d+=1 : endif
		len_-=1
		if (len_ > 0) Then *d = t shr 16 : d+=1 : endif
		len_-=1
		if (len_ > 0) Then *d = t shr 24 : d+=1 : endif
		len_-=1
		addr += 4 
   Wend

End Sub
	
Sub pxaLcdPrvScreenDataPixel(lcd As PxaLcd Ptr , buf As UByte Ptr)
	static as SDL_Surface ptr mScreen = NULL 
	static as SDL_Window  ptr mWindow = NULL 
	Dim As UShort valor = *(cast(UShort ptr,buf ))
	static As ULong pixCnt = 0 
	static As UShort ptr dst 
	Dim As ULong w, h 

	w = (lcd->lccr1 And &h3ff) + 1 
	h = (lcd->lccr2 And &h3ff) + 1 

	if mWindow=0 Then 
		Dim As ULong winH = h 
		if (lcd->hardGrafArea) Then winH += 3 * w \ 8

		printf(!"SCREEN configured for %u x %u\n", w, h) 
		mWindow = SDL_CreateWindow("uARM", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w, winH, 0) 
		if (mWindow = NULL) Then 
			MiPrint "Couldn't create window SDL"
			beep : sleep : end
		EndIf
  
		mScreen = SDL_CreateRGBSurface(0, w, h, 16, &hf800, &h07e0, &h001f, &h0000) 
		if (mScreen = NULL) Then 
			MiPrint "Couldn't create screen surface SDL"
			beep : sleep : end 
		EndIf
	EndIf
  
	if pixCnt=0 Then 
		SDL_LockSurface(mScreen) 
		dst = cast(UShort ptr,mScreen->pixels)
	EndIf
	
	dst[pixCnt] = valor 
	pixCnt+=1 
	
	if pixCnt = (w * h) Then 
		pixCnt = 0 
		SDL_UnlockSurface(mScreen) 
		dst = NULL 
		SDL_BlitSurface(mScreen, NULL, SDL_GetWindowSurface(mWindow), NULL) 
		SDL_UpdateWindowSurface(mWindow) 
	EndIf
End Sub

Sub pxaLcdPrvScreenDataDma(lcd As PxaLcd Ptr , addr As ULong , len_ As ULong) ' addr=PA
	Dim As UByte datas(3) 
	Dim As ULong i, j 
	dim as any ptr ptr_ 
	
	len_ \= 4 
	while len_ 
		len_-=1
		pxaLcdPrvDma(lcd, @datas(0), addr, 4) 
		addr += 4 
		Select Case As Const ((lcd->lccr3 Shr 24) And 7)  
			case 0 		'1BPP
				for i = 0 To 3         
					for j = 0 To 7         
						ptr_ = cast(UByte ptr,lcd->palete(0) + ((datas(i) Shr j) And 1) * 2 )
						pxaLcdPrvScreenDataPixel(lcd, cast(UByte ptr,ptr_)) 
               Next
            Next
			
			case 1 		'2BPP
				for i = 0 To 3         
					for j = 0 To 7 step 2     
						ptr_ = cast(UByte ptr,lcd->palete(0) + ((datas(i) Shr j) And 3) * 2) 
						pxaLcdPrvScreenDataPixel(lcd, cast(UByte ptr,ptr_)) 
               Next
            Next
			
			case 2 		'4BPP
				for i = 0 To 3         
					for j = 0 To 7 step 4     
						ptr_ = cast(UByte ptr,lcd->palete(0) + ((datas(i) Shr j) And 15) * 2) 
						pxaLcdPrvScreenDataPixel(lcd, cast(UByte ptr,ptr_)) 
               Next
            Next
			
			case 3 		'8BPP
				for i = 0 To 3       
					ptr_ = cast(UByte ptr,lcd->palete(0) + (datas(i) * 2)) 
					pxaLcdPrvScreenDataPixel(lcd, cast(UByte ptr,ptr_)) 
            Next
			
			case 4 		'16BPP
				for i = 0 To 3 step 2   
					pxaLcdPrvScreenDataPixel(lcd, @datas(0) + i)
            Next
			
			case else 
				 'BAD
      End Select
   Wend

End Sub

Sub pxaLcdFrame(lcd As PxaLcd Ptr)
	'every other call starts a frame, the others end one [this generates spacing between interrupts so as to not confuse guest OS]
	
	if (lcd->enbChanged) Then 
		if (lcd->lccr0 And &h0001) Then 
			'just got enabled
			'TODO: perhaps check settings?
		else
        	' we just got quick disabled - kill current frame and do no more
			lcd->lcsr Or= &h0080 	'quick disable happened
			lcd->state = LCD_STATE_IDLE 
		EndIf
		lcd->enbChanged = false 			
	EndIf
  
	if (lcd->lccr0 And &h0001) Then 
  		'enabled - do a frame
		Dim As ULong descrAddr, len_ 
		
		if (lcd->lccr0 And &h400) Then 
			'got disabled
			lcd->lcsr Or= &h0001 'disable happened
			lcd->state = LCD_STATE_IDLE 
			lcd->lccr0 And= INV( 1 )
		else
			Select Case As Const (lcd->state)  
			case LCD_STATE_IDLE 
				if (lcd->fbr(0) And 1) Then  'branch
					lcd->fbr(0) And= INV( 1UL )
					if (lcd->fbr(0) And 2) Then lcd->lcsr Or= &h0200
					descrAddr = lcd->fbr(0) And INV( &hFUL )
				else
					descrAddr = lcd->fdadr(0)
				EndIf
				lcd->fdadr(0) = pxaLcdPrvGetWord(lcd, descrAddr + 0) 
				lcd->fsadr(0) = pxaLcdPrvGetWord(lcd, descrAddr + 4) 
				lcd->fidr(0)  = pxaLcdPrvGetWord(lcd, descrAddr + 8) 
				lcd->ldcmd(0) = pxaLcdPrvGetWord(lcd, descrAddr + 12) 
				
				lcd->state = LCD_STATE_DMA_0_START 
			
			case LCD_STATE_DMA_0_START 
				if (lcd->ldcmd(0) And &h00400000UL) Then lcd->lcsr Or= &h0002 'set SOF is DMA 0 started
				len_ = lcd->ldcmd(0) And &h000FFFFFUL 
				
				if (lcd->ldcmd(0) And &h04000000UL) Then  'Bauteile nicht beschriftet
				print "revisar Bauteile nicht beschriftet sizeof":beep:sleep
					if (len_ > sizeof(lcd->palete)) Then len_ = sizeof(lcd->palete)
					pxaLcdPrvDma(lcd, @lcd->palete(0), lcd->fsadr(0), len_) 	
				else
					lcd->frameNum+=1  
					if (lcd->frameNum And 63)=0 Then 
						pxaLcdPrvScreenDataDma(lcd, lcd->fsadr(0), len_)
					EndIf
				EndIf

				lcd->state = LCD_STATE_DMA_0_END 
				
			case LCD_STATE_DMA_0_END 
				if (lcd->ldcmd(0) And &h00200000UL) Then lcd->lcsr Or= &h0100 'set EOF is DMA 0 finished
				lcd->state = LCD_STATE_IDLE 
			
         End Select

		EndIf

	EndIf
  
	pxaLcdPrvUpdateInts(lcd) 
End Sub


function pxaLcdInit(physMem as ArmMem ptr, ic as SocIc ptr, hardGrafArea As Bool) as PxaLcd ptr
   dim As PxaLcd ptr lcd =cast(PxaLcd ptr,Callocate(sizeof(PxaLcd)) )
	
	if (lcd=0) then PERR("cannot alloc LCD") 
	
	memset(lcd, 0, sizeof(PxaLcd)) 
	lcd->ic = ic 
	lcd->mem = physMem 
	lcd->intMask = UNMASKABLE_INTS 
	lcd->hardGrafArea = hardGrafArea 
	
	if memRegionAdd(physMem, PXA_LCD_BASE, PXA_LCD_SIZE, cast(ArmMemAccessF ,@pxaLcdPrvMemAccessF), lcd)=0 Then 
		PERR("cannot add LCD to MEM")
	EndIf
  
	return lcd 
End Function





