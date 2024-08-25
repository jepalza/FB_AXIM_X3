'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function deviceHasGrafArea() As Bool
	return false 
End Function

Function deviceGetRomMemType() As RomChipType
	return RomStrataflash16x2x 
End Function

Function deviceGetRamSize() As uLong
	return 64UL Shl 20 
End Function

Function deviceGetRamTerminationStyle() As RamTermination
	return RamTerminationMirror 
End Function


'-----------------------------
' SOC PXA26x para la AXIM X3
Function deviceGetSocRev() As UByte
	return 1 	'PXA26x
End Function
'-----------------------------


Function deviceSetup( sp As SocPeriphs Ptr , kp As _Keypad Ptr , vsd As _VSD2 Ptr , nandFile As FILE Ptr) As Device ptr
	dim as uLong romPieceSize = 32UL Shl 20 
	dim as any ptr romPiece = Callocate(romPieceSize) 
	dim as Device ptr dev 
	
	dev = cast(Device ptr,Callocate(sizeof(Device)) )
	if (dev=0) Then PERR("cannot alloc device")

	dev->secondFlashChip = romInit(sp->mem, &h04000000UL, @romPiece, @romPieceSize, 1, RomStrataflash16x2x) 
	if dev->secondFlashChip=0 Then PERR("Cannot init axim's second flash chip")
	
	dev->wm9705_ = wm9705_Init(sp->ac97) 
	if dev->wm9705_=0 Then PERR("Cannot init WM9705")
	
	dev->w86L488_ = w86l488init(sp->mem, sp->gpio, W86L488_BASE_AXIM, vsd, 8)
	if dev->w86L488_=0 Then PERR("Cannot init W86L488")

	dev->CPLD = aximX3cpldInit(sp->mem) 
	if dev->CPLD=0 Then PERR("Cannot init AXIM's CPLD")

	if keypadAddGpioKey(kp, SDLK_ESCAPE,   0, false)=0 Then PERR("Cannot init power key")
	if keypadAddGpioKey(kp, SDLK_F1,      13, true)=0  Then PERR("Cannot init mini key L (voice rec)")
	if keypadAddGpioKey(kp, SDLK_F2,       3, true)=0  Then PERR("Cannot init hardkey 1 (calendar)")
	if keypadAddGpioKey(kp, SDLK_F3,       2, true)=0  Then PERR("Cannot init hardkey 2 (contacts)")
	if keypadAddGpioKey(kp, SDLK_F4,       4, true)=0  Then PERR("Cannot init hardkey 3 (inbox)")
	if keypadAddGpioKey(kp, SDLK_F5,      11, true)=0  Then PERR("Cannot init hardkey 4 (home)")
	if keypadAddGpioKey(kp, SDLK_F5,       9, true)=0  Then PERR("Cannot init mini key R (wireless\media)")
	if keypadAddGpioKey(kp, SDLK_PAGEUP,  16, true)=0  Then PERR("Cannot init hardkey jog up")
	if keypadAddGpioKey(kp, SDLK_PAGEDOWN,23, true)=0  Then PERR("Cannot init hardkey jog down")
	if keypadAddGpioKey(kp, SDLK_HOME,    22, true)=0  Then PERR("Cannot init hardkey jog select")
	if keypadAddGpioKey(kp, SDLK_DOWN,    84, true)=0  Then PERR("Cannot init down key")
	if keypadAddGpioKey(kp, SDLK_UP,      82, true)=0  Then PERR("Cannot init up key")
	if keypadAddGpioKey(kp, SDLK_LEFT,    85, true)=0  Then PERR("Cannot init left key")
	if keypadAddGpioKey(kp, SDLK_RIGHT,   81, true)=0  Then PERR("Cannot init right key")
	if keypadAddGpioKey(kp, SDLK_RETURN,  83, true)=0  Then PERR("Cannot init select key")

	socGpioSetState(sp->gpio,  1, true) 	'reset button not active
	
	socGpioSetState(sp->gpio,  5, true) 	'battery door is closed
	
	'high end device with no wireless
	socGpioSetState(sp->gpio, 58, true) 
	socGpioSetState(sp->gpio, 59, true) 
	socGpioSetState(sp->gpio, 60, true) 
	socGpioSetState(sp->gpio, 61, true) 
	socGpioSetState(sp->gpio, 62, true) 
	socGpioSetState(sp->gpio, 63, true) 
	
	wm9705_setAuxVoltage(dev->wm9705_, WM9705auxPinBmon, 4200 \ 3) 	'main battery is 4.2V
	wm9705_setAuxVoltage(dev->wm9705_, WM9705auxPinAux, 1200) 			'secondary battery is 1.2V
	wm9705_setAuxVoltage(dev->wm9705_, WM9705auxPinPhone, 1900) 		'main battery temp is 10 degrees C
	
	sp->dbgUart = sp->uarts(0) 	'FFUART
	
	return dev 
End Function

Sub devicePeriodic( dev As Device Ptr , cycles As uLong)
	if (cycles And &h0000007FUL)=0 Then wm9705_periodic(dev->wm9705_)
End Sub

Sub deviceTouch( dev As Device Ptr , x As long , y As long , press As long)
	wm9705_setPen(dev->wm9705_, iif((x >= 0) AndAlso (y >= 0) , 3930 - 15 * x , -1), _
	                            iif((x >= 0) AndAlso (y >= 0) , 3864 - 11 * y , -1), press)
End Sub

Sub deviceKey( dev As Device Ptr , key As uLong , down As Bool)
	'nothing
End Sub
