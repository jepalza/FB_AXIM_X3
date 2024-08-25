 '(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>



' #Include"util.bi"
' #Include"keys.bi"


#define MAX_GPIO_KEYS	64
#define MAX_KP_ROWS		12
#define MAX_KP_COLS		8


Type KeyGpio 
	As uLong sdlKey 	'0 for inval
	As Byte gpioNum 
	As Bool activeHigh 
End Type 

Type KeyMatrix 
	As uLong sdlKey 	'0 for inval
	As Bool isDown 
End Type 

Type Keypad 
	As SocGpio ptr gpio 
	
	As KeyGpio gpios(MAX_GPIO_KEYS-1) 
	As Byte kpGpioRow(MAX_KP_ROWS-1) 		'<0 for inval
	As Byte kpGpioCol(MAX_KP_COLS-1) 		'<0 for inval
	As KeyMatrix km(MAX_KP_ROWS-1, MAX_KP_COLS-1) 
	
	As Bool recalcing, matrixHasPullUps 
End Type 



Sub keypadPrvMatrixRecalc( kp As Keypad Ptr)
	Dim As long i, j 
	kp->recalcing = true 
	
	'calc input rows
	for i = 0 To MAX_KP_ROWS -1        
		Dim As Bool rowState = kp->matrixHasPullUps 
		Dim As Bool haveStrong = false 
		
		if kp->kpGpioRow(i) < 0 Then continue for
		
		if socGpioGetState(kp->gpio, kp->kpGpioRow(i)) <> SocGpioStateHiZ Then continue for

		for j = 0 To MAX_KP_COLS -1        
			Dim as uByte colSta 
			
			if kp->kpGpioCol(j) < 0  Then continue for
			if kp->km(i, j).isDown=0 Then continue for

			colSta = socGpioGetState(kp->gpio, kp->kpGpioCol(j)) 
		
			if (colSta = SocGpioStateLow) OrElse (colSta = SocGpioStateHigh) Then 
				Dim As Bool colHi  = iif(colSta = SocGpioStateHigh,1,0) 
				
				if (haveStrong<>0) AndAlso (iif(rowState=0,1,0) <> iif(colHi=0,1,0)) Then
					print "row ";i;" (";kp->kpGpioRow(i);") being pulled in different directions"
				EndIf
  
				haveStrong = true 
				rowState = iif( (rowState<>0) AndAlso (colHi<>0) ,1,0)
			EndIf
      Next
		socGpioSetState(kp->gpio, kp->kpGpioRow(i), rowState) 
   Next
			
	'calc input cols
	for j = 0 To MAX_KP_COLS-1         
		Dim As Bool colState = kp->matrixHasPullUps 
		Dim As Bool haveStrong = false 
		
		if kp->kpGpioCol(j) < 0 Then continue for
		if socGpioGetState(kp->gpio, kp->kpGpioCol(j)) <> SocGpioStateHiZ Then continue for

		for i = 0 To MAX_KP_ROWS -1        
			Dim as uByte rowSta 
			
			if kp->kpGpioRow(i) < 0  Then continue for
			if kp->km(i, j).isDown=0 Then continue for

			rowSta = socGpioGetState(kp->gpio, kp->kpGpioRow(i)) 
			
			if (rowSta = SocGpioStateLow OrElse rowSta = SocGpioStateHigh) Then 
				Dim As Bool rowHi = iif( rowSta = SocGpioStateHigh,1,0) 

				if (haveStrong<>0) AndAlso (iif(rowHi<>0,1,0) <> iif(colState=0,1,0)) Then ' revisar
					print "col ";i;" (";kp->kpGpioCol(i);") being pulled in different directions"
				EndIf
  
				haveStrong = true 
				
				colState = Iif((rowHi<>0) AndAlso (colState<>0),1,0) 
			EndIf
      Next
		socGpioSetState(kp->gpio, kp->kpGpioCol(j), colState) 
   Next
	
	kp->recalcing = false 
End Sub

Sub keypadPrvGpioDirsChanged( userData As Any Ptr)
	Dim as Keypad ptr kp = cast(Keypad ptr,userData)
	if kp->recalcing=0 Then keypadPrvMatrixRecalc(kp)
End Sub

Function keypadInit( gpio As SocGpio Ptr , matrixHasPullUps As Bool) As Keypad ptr
	Dim as Keypad ptr kp = cast(Keypad ptr,Callocate(sizeof(Keypad)) )
	Dim as long i 
	
	if kp=0 Then PERR("cannot alloc Keypad")

	memset(kp, 0, sizeof(Keypad)) 
	
	kp->gpio = gpio 
	kp->matrixHasPullUps = matrixHasPullUps 
	
	for i = 0 To MAX_KP_ROWS-1       
		kp->kpGpioRow(i) = -1
   Next
	
	for i = 0 To MAX_KP_COLS-1       
		kp->kpGpioCol(i) = -1
   Next
	
	socGpioSetDirsChangedNotif(kp->gpio, @keypadPrvGpioDirsChanged, kp) 

	return kp 
End Function

Sub keypadSdlKeyEvt( kp As Keypad Ptr , sdlKey As uLong , wentDown As Bool)
	Dim As long i, j 
	
	for i = 0 To MAX_GPIO_KEYS-1         
		if (kp->gpios(i).sdlKey = sdlKey) AndAlso (kp->gpios(i).gpioNum >= 0) Then 
			dim as bool stat=iif( ((wentDown<>0) AndAlso ((kp->gpios(i).activeHigh)<>0)) OrElse _
										(((wentDown =0) AndAlso  (kp->gpios(i).activeHigh) =0)) ,1,0)
			socGpioSetState(kp->gpio, kp->gpios(i).gpioNum, stat ) 
		EndIf
   Next
	
	for i = 0 To MAX_KP_ROWS-1         
		if (kp->kpGpioRow(i) < 0) Then continue for
		for j = 0 To MAX_KP_COLS         
			if (kp->kpGpioCol(j) < 0) Then continue for
			if (kp->km(i, j).sdlKey <> sdlKey) Then continue for
			kp->km(i, j).isDown = wentDown 
      Next
   Next
	
	keypadPrvMatrixRecalc(kp) 
End Sub

Sub keypadPrvGpioChanged( userData As Any Ptr , gpio As uLong , oldState As Bool , newState As Bool)
	Dim as Keypad ptr kp = cast(Keypad ptr,userData) 
	
	' parametros no empleados
	' gpio
	' oldState
	' newState
	
	if kp->recalcing=0 Then keypadPrvMatrixRecalc(kp)
End Sub

Function keypadDefineRowOrCol( kp As Keypad Ptr , idx As uLong , arr As Byte Ptr , maxs As uLong , gpioNum As Byte) As Bool
	if idx >= maxs Then return false
	if arr[idx] >= 0 Then return false

	arr[idx] = gpioNum 
	
	socGpioSetNotif(kp->gpio, gpioNum, @keypadPrvGpioChanged, kp)
	socGpioSetState(kp->gpio, gpioNum, kp->matrixHasPullUps) 
	keypadPrvMatrixRecalc(kp) 
	
	return true 
End Function

Function keypadDefineRow( kp As Keypad Ptr , rowIdx As uLong , gpio As Byte) As Bool
	return keypadDefineRowOrCol(kp, rowIdx, @kp->kpGpioRow(0), MAX_KP_ROWS, gpio) 
End Function

Function keypadDefineCol( kp As Keypad Ptr , colIdx As uLong , gpio As Byte) As Bool
	return keypadDefineRowOrCol(kp, colIdx, @kp->kpGpioCol(0), MAX_KP_COLS, gpio) 
End Function

Function keypadAddGpioKey( kp As Keypad Ptr , sdlKey As uLong , gpioNum As Byte , activeHigh As Bool) As Bool
	Dim as long i 
	
	for i = 0 To MAX_GPIO_KEYS-1         
		if kp->gpios(i).sdlKey = 0 Then 
			kp->gpios(i).sdlKey  = sdlKey 
			kp->gpios(i).gpioNum = gpioNum 
			kp->gpios(i).activeHigh = activeHigh 
			
			socGpioSetState(kp->gpio, gpioNum, iif(activeHigh=0,1,0) ) 
			return true 
		EndIf
   Next
	
	return false 
End Function

Function keypadAddMatrixKey( kp As Keypad Ptr , sdlKey As uLong , row As uLong , col As uLong) As Bool
	'coords must be valid
	if (row >= MAX_KP_ROWS) OrElse (col >= MAX_KP_COLS) Then return false

	'and rows and cols must be hooked up
	if (kp->kpGpioRow(row) < 0) OrElse (kp->kpGpioCol(col) < 0) Then return false
	
	'must be unused
	if (kp->km(row, col).sdlKey) Then return false

	kp->km(row, col).sdlKey = sdlKey 
	kp->km(row, col).isDown = false 
	
	return true 
End Function
