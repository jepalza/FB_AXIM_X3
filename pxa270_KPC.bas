'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub pxaKpcPrvDoAutoScan(kpc As PxaKpc Ptr , causeIrq As Bool)
	Dim As ULongint nowKeys = 0 
	Dim As Ubyte i, c, nrows, nkeys = 0 
	
	for i = 0 To 3       
		kpc->kpasmkp(i) = 0
   Next
	
	nrows = ((kpc->kpc Shr 26) And 7) + 1 
	kpc->kpas And= INV( &h7c0000fful )
	
	for c = 0 To ((kpc->kpc Shr 23) And 7)         
		Dim As Ubyte cvalor = kpc->matrixKeys(c) 							'get all rows for this column
		
		cvalor And= (1 Shl nrows) - 1 										'mask off noexistent rows
		
		nowKeys Shl = 8 
		nowKeys += cvalor 
		
		kpc->kpasmkp(c \ 2) Or= cULng(cvalor) Shl (16 * (c mod 2)) 		'record the values
		
		if (cvalor=0) Then 
			continue for
		ElseIf (cvalor And (cvalor - 1)) Then
			nkeys += 2 
		ElseIf (nkeys=0) Then ' revisar nkeys+=1 no se como hacerlo
			kpc->kpas Or= c 
			kpc->kpas Or= __builtin_ctz(cvalor) Shl 4 
		EndIf
   Next
	
	if (nkeys = 1) Then 
		kpc->kpas Or= &h04000000ul 
	ElseIf (nkeys) Then
		kpc->kpas Or= &h100000fful
	EndIf

	if (causeIrq<>0) AndAlso (nowKeys <> kpc->prevKeys) Then 
		kpc->kpc Or= &h00400000ul
	EndIf

	kpc->prevKeys = nowKeys 
End Sub

Sub pxaKpcPrvIrqRecals(kpc As PxaKpc Ptr)
	dim As Bool irq = false 
	
	irq = iif( (irq<>0) OrElse ((kpc->kpc And &h00401800ul) = &h00401800ul) ,1,0) 
	irq = iif( (irq<>0) OrElse ((kpc->kpc And &h00000023ul) = &h00000023ul) ,1,0)
	
	socIcInt(kpc->ic, PXA_I_KEYPAD, irq) 
End Sub

Sub pxaKpcPrvMatrixRecalc(kpc As PxaKpc Ptr , lastKeyChangeWasDown As Bool)
	Dim As Ubyte c, valor = 0 
	
	'ignore due to lack of matrix keypad enable?
	if (kpc->kpc And &h1000)=0 Then return

	'auto scan?
	if (kpc->kpc And &h20000000ul) Then 
		'ignore due to multiple?
		if ((kpc->kpc And &h00200000ul)<>0) AndAlso _
		   (  ( (lastKeyChangeWasDown<>0) AndAlso (kpc->numMatrixKeysPressed<>1) ) _
			OrElse _
			   ( (lastKeyChangeWasDown =0) AndAlso (kpc->numMatrixKeysPressed<>0) ) ) Then 
			return
		EndIf 

		'do a scan
		pxaKpcPrvDoAutoScan(kpc, true) 
	 
	else 'manual mode?
		
		'calculate
		for c = 0 To ((kpc->kpc Shr 23) And 7) -1       
			if (kpc->kpc And (1 Shl (12 + c)))=0 Then continue for
			valor Or= kpc->matrixKeys(c) 
      Next
		
		'mask off unused row
		valor And= INV( ((1 Shl (((kpc->kpc Shr 26) And 7) + 1)) - 1) )
		
		'irq if nonzero
		if (valor) Then kpc->kpc Or= &h00400000ul
		
		kpc->kpmk = valor 

   EndIf
  
	'recalc irqs
	pxaKpcPrvIrqRecals(kpc) 
End Sub

Sub pxaKpcPrvDirectKeysRecalc(kpc As PxaKpc Ptr)
	kpc->kpc Or= &h00000020ul 
	
	'recalc irqs
	pxaKpcPrvIrqRecals(kpc) 
End Sub

Sub pxaKpcPrvJogRecalcRecalc(kpc As PxaKpc Ptr)
	kpc->kpc Or= &h00000020ul 
	
	'recalc irqs
	pxaKpcPrvIrqRecals(kpc) 
End Sub

Function pxaKpcPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   dim as PxaKpc ptr kpc = cast(PxaKpc ptr,userData)
	Dim As ULong valor = 0 
	
	if (size <> 4) OrElse ((pa And 7)<>0) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 
	EndIf
  
	pa = (pa - PXA270_KPC_BASE) Shr 3 
	
	if (write_) Then valor = *cast(ULong ptr,buf)
  
	Select Case As Const (pa)  
		case &h00 \ 8 
			if (write_) Then 
				kpc->kpc = (kpc->kpc And &h00400020ul) Or (valor And &h7fbffbdful) 
				if (valor And &h80000000ul) Then 
					pxaKpcPrvDoAutoScan(kpc, false) 
				else
					pxaKpcPrvMatrixRecalc(kpc, false) 'manual mode?
				EndIf
			else
				valor = kpc->kpc 
				kpc->kpc And= INV( &h00400020ul ) 'reset when read
				pxaKpcPrvIrqRecals(kpc) 
			EndIf
		
		case &h08 \ 8 
			if (write_) Then 
				 	'ignored
			else
				valor = iif(kpc->kpdkChanged , &h80000000ul , 0) Or (INV(kpc->directKeys) And &hff) 
				if (kpc->kpc And 4) Then 
					valor And= INV( &h03 )
					valor Or= (kpc->jogSta(0) Shr 12) And &h03 
				EndIf
  
				if (kpc->kpc And 8) Then 
					valor And= INV( &h0c )
					valor Or= (kpc->jogSta(0) Shr 10) And &h0c 
				EndIf
  
				kpc->kpdkChanged = 0 
			EndIf
		
		case &h10 \ 8 
			if (write_) Then 
				kpc->jogSta(0) = (kpc->jogSta(0) And &h0300) Or (valor And &hc0ff) 
				kpc->jogSta(1) = (kpc->jogSta(1) And &h0300) Or ((valor Shr 16) And &hc0ff) 
			else
				valor = kpc->jogSta(1) And &hc0ff 
				valor Shl = 16 
				valor += kpc->jogSta(0) And &hc0ff 
				
				kpc->jogSta(0) And= INV( &hc000 )
				kpc->jogSta(1) And= INV( &hc000 )
			EndIf
		
		case &h18 \ 8 
			if (write_) Then 
				 	'ignored
			else
				valor = kpc->kpmk 
				kpc->kpmk And= INV( &h80000000ul )
			EndIf
		
		case &h20 \ 8 
			if (write_) Then 
				 	'ignored
			else
				valor = kpc->kpas
			EndIf

		case  &h28 \ 8 ,_
				&h30 \ 8 ,_
				&h38 \ 8 ,_
				&h40 \ 8 
			if (write_) Then 
				 	'ignored
			else
				valor = kpc->kpasmkp(pa - &h28 \ 8)
			EndIf
		
		case &h48 \ 8 
			if (write_) Then 
				kpc->kpkdi = valor 
			else
				valor = kpc->kpkdi
			EndIf
		
		case else 
			return false 
   End Select

	if (write_=0) Then *Cast(ULong ptr,buf) = valor

	return true 
End Function

 
Function pxaKpcInit( physMem As ArmMem Ptr , ic As SocIc Ptr) As PxaKpc ptr
	dim as PxaKpc ptr kpc = cast(PxaKpc ptr,Callocate(sizeof(PxaKpc))) 
	
	if (kpc=0) Then PERR("cannot alloc KPC")

	memset(kpc, 0, sizeof(PxaKpc)) 
	kpc->kpkdi = &h0064 
	kpc->kpas  = &hff 
	kpc->ic    = ic 
	
	if memRegionAdd(physMem, PXA270_KPC_BASE, PXA270_KPC_SIZE, cast(ArmMemAccessF ,@pxaKpcPrvMemAccessF), kpc)=0 Then 
		PERR("cannot add KPC to MEM")
	EndIf
	
	return kpc 
End Function

Sub pxaKpcMatrixKeyChange( kpc As PxaKpc Ptr , row As ubyte , col As ubyte , isDown As Bool)
	dim As Bool cur = NOT_NOT((kpc->matrixKeys(col) Shr row) And 1) 
	
	if (row >= 8) Then PERR("only eight matrix key rows exist")
	if (col >= 8) Then PERR("only eight matrix key cols exist")

	' revisar
	if (cur=0) <> (isDown=0) Then 'change
		
		kpc->matrixKeys(col) Xor= 1 Shl row 
		if (isDown) Then 
			kpc->numMatrixKeysPressed+=1  
		else
			kpc->numMatrixKeysPressed-=1 
		EndIf
 
		kpc->kpmk Or= &h80000000ul 
		
		pxaKpcPrvMatrixRecalc(kpc, isDown) 
	
	EndIf
  
End Sub


Sub pxaKpcDirectKeyChange(kpc As PxaKpc Ptr , keyIdx As Ubyte , isDown As Bool)
	dim As Bool cur = NOT_NOT((kpc->directKeys Shr keyIdx) And 1) 
	
	if (keyIdx >= 8) Then PERR("only eight direct keys exist")

	if (kpc->kpc And 2)=0 Then 
		Miprint "setting direct keys when direct keypad is disabled"
	EndIf
	
	' revisar
	if (cur=0) <> (isDown=0) Then 
  		'change
		kpc->directKeys Xor= 1 Shl keyIdx 
		pxaKpcPrvDirectKeysRecalc(kpc) 
	EndIf
  
End Sub

static shared As UByte jogNext_A(3) = {2, 0, 3, 1}
static shared As UByte jogNext_B(3) = {1, 3, 2, 0}
Sub pxaKpcJogInput( kpc As PxaKpc Ptr , jogIdx As ubyte , up As Bool)
	Dim As UByte cur = kpc->jogSta(jogIdx) And &hff 
	
	if (jogIdx >= 2) Then PERR("only two jog dials exist")

	if (kpc->kpc And (1 Shl (2 + jogIdx)))=0 Then 
		MiPrint "setting jog value for something that configured as a jog dial"
	EndIf
  
	if (up) Then 
		if (cur = &hff) Then 
			kpc->jogSta(jogIdx) = (kpc->jogSta(jogIdx) And &h4300) Or &h8000 
		else
			kpc->jogSta(jogIdx)+=1 
		EndIf

		' rotate it
		kpc->jogSta(jogIdx) = (kpc->jogSta(jogIdx) And &hc0ff) Or ( culng(jogNext_A( (kpc->jogSta(jogIdx) Shr 12) And 3) ) ) Shl 12 
	else
		if (cur = &h00) Then 
			kpc->jogSta(jogIdx) = (kpc->jogSta(jogIdx) And &h8300) Or &h40ff 
		else
			kpc->jogSta(jogIdx)-=1 
		EndIf

		' rotate it
		kpc->jogSta(jogIdx) = (kpc->jogSta(jogIdx) And &hc0ff) Or ( culng(jogNext_B( (kpc->jogSta(jogIdx) Shr 12) And 3) ) ) Shl 12 
	EndIf
  
	pxaKpcPrvJogRecalcRecalc(kpc) 
End Sub

