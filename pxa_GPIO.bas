'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub socGpioPrvRecalcValues(gpio As SocGpio Ptr , which As Ubyte)
	Dim As ULong valor, newValor, oldvalor = gpio->levels(which), t 
	
	if (which >= 4) Then 
		MiPrint "gpio overflow. halt" 
		beep : sleep
	EndIf
	
	valor = gpio->dirs(which) 
	newvalor = (gpio->latches(which) And valor) Or (gpio->inputs(which) And INV(valor)) 
	
	'process change notifs
	t = newvalor Xor oldvalor 
	while (t)  
		Dim As ULong bits = 31 - __builtin_clz(t)
		dim as ulong  num = 32 * which + bits 
		
		t And= INV(1 Shl bits) 
		
		if (gpio->notifF(num)) Then 
			gpio->notifF(num)(gpio->notifD(num), num, NOT_NOT(oldvalor And (1 Shl bits)), NOT_NOT(newvalor And (1 Shl bits)))
		EndIf
    Wend

	gpio->levels(which) = newvalor 
	
	if (newvalor <> oldvalor) Then 
		Dim As ULong wentHi = newvalor And INV( oldvalor )
		Dim As ULong wentLo = oldvalor And INV( newvalor )
		gpio->detStatus(which) Or= (wentHi And gpio->riseDet(which)) Or (wentLo And gpio->fallDet(which)) 
	EndIf
  
End Sub

Sub socGpioPrvRecalcIntrs(gpio As SocGpio Ptr)
	socIcInt(gpio->ic, PXA_I_GPIO_all, _
	       iif(  (gpio->detStatus(3)<>0) OrElse _
	             (gpio->detStatus(2)<>0) OrElse _
					 (gpio->detStatus(1)<>0) OrElse _
					((gpio->detStatus(0) And INV(3))<>0) , 1, 0)  ) 
	socIcInt(gpio->ic, PXA_I_GPIO_1, iif((gpio->detStatus(0) And 2) <> 0,1,0) ) 
	socIcInt(gpio->ic, PXA_I_GPIO_0, iif((gpio->detStatus(0) And 1) <> 0,1,0) ) 
End Sub

Function socGpioPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   dim as SocGpio ptr gpio = cast(SocGpio ptr,userData)
	Dim As ULong valor = 0, paOfst = pa And 3 
	dim As Bool dirsChanged = false 
	
	pa = (pa - PXA_GPIO_BASE) Shr 2 
	
	if (write_) Then 
		if (size <> 4) Then 
			Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
			return false 		'we do not support non-word accesses
		EndIf
  
		valor = *cast(ULong ptr,buf) 
		
		Select Case As Const (pa)  
			case 64 
				pa -= 61 	'make the math work
				'Cascada_CASE 0,1,2
				'nada (el CASE 0,1,2 no hace nada)
				
			case 0 ,1, 2
				'nada
			
			case 67 
				pa -= 61 	'make the math work
				'Cascada_CASE 3,4,5
				pa -= 3 
				gpio->dirs(pa) = valor 
				dirsChanged = true 
				goto recalc 
				
			case 3 ,4 ,5
				pa -= 3 
				gpio->dirs(pa) = valor 
				dirsChanged = true 
				goto recalc 
			
			case 70 
				pa -= 61 	'make the math work
				'Cascada_CASE 6,7,8
				pa -= 6 
				gpio->latches(pa) Or= valor 
				goto recalc 
				
			case 6, 7, 8 
				pa -= 6 
				gpio->latches(pa) Or= valor 
				goto recalc 
			
			case 73 
				pa -= 61 	'make the math work
				'Cascada_CASE 9,10,11
				pa -= 9 
				gpio->latches(pa) And= INV( valor )
				goto recalc 
				
			case 9 ,10, 11 
				pa -= 9 
				gpio->latches(pa) And= INV( valor )
				goto recalc 
			
			case 76 
				pa -= 61 	'make the math work
				'Cascada_CASE 12,13,14
				pa -= 12 
				gpio->riseDet(pa) = valor 
				
			case 12 ,13 ,14 
				pa -= 12 
				gpio->riseDet(pa) = valor 
			
			case 79 
				pa -= 61 	'make the math work
				'Cascada_CASE 15,16,17
				pa -= 15 
				gpio->fallDet(pa) = valor 
				
			case 15 ,16 ,17 
				pa -= 15 
				gpio->fallDet(pa) = valor 
			
			case 82 
				pa -= 61 	'make the math work
				'Cascada_CASE 18,19,20
				pa -= 18 
				gpio->detStatus(pa) And= INV( valor )
				goto trigger_intrs 
				
			case 18 ,19 ,20 
				pa -= 18 
				gpio->detStatus(pa) And= INV( valor )
				goto trigger_intrs 
			
			case 21,22,23,24,25,26,27,29 'no hay 28?
				pa -= 21 
				gpio->AFRs(pa) = valor 
				pa \= 2 
				goto recalc 
      End Select
		goto done 
		
recalc:
		socGpioPrvRecalcValues(gpio, pa) 
		if (dirsChanged<>0) AndAlso (gpio->dirNotifF<>0) Then 
			gpio->dirNotifF(gpio->dirNotifD)
		EndIf
 
trigger_intrs:
		socGpioPrvRecalcIntrs(gpio) 
		
	else

		Select Case As Const (pa)  
			case 64 
				pa -= 61 	'make the math work
				'Cascada_CASE 0,1,2
				valor = gpio->levels(pa - 0)
				
			case 0,1,2
				valor = gpio->levels(pa - 0) 
			
			case 67 
				pa -= 61 	'make the math work
				'Cascada_CASE 3,4,5
				valor = gpio->dirs(pa - 3) 
				
			case 3,4,5
				valor = gpio->dirs(pa - 3) 
			
			case 70 ,73
				pa -= 61 	'make the math work
				'Cascada_CASE 6,7,8,9,10,11
				valor = 0
				
			case 6,7,8,9,10,11
				valor = 0 
			
			case 76 
				pa -= 61 	'make the math work
				'Cascada_CASE 12,13,14
				valor = gpio->riseDet(pa - 12) 
				
			case 12,13,14
				valor = gpio->riseDet(pa - 12) 

			case 79 
				pa -= 61 	'make the math work
				'Cascada_CASE 15,16,17
				valor = gpio->fallDet(pa - 15) 
				
			case 15,16,17
				valor = gpio->fallDet(pa - 15) 
			
			case 82 
				pa -= 61 	'make the math work
				'Cascada_CASE 18,19,20
				valor = gpio->detStatus(pa - 18)
				
			case 18,19,20
				valor = gpio->detStatus(pa - 18) 

			case 21,22,23,24,25,26,27,28 ' no hay 29, como arriba?
				valor = gpio->AFRs(pa - 21) 
      End Select

		'handle weird reads
		valor Shr = (8 * (paOfst And 3)) 
		
		if (size = 4) Then 
			*(cast(ULong  ptr,buf)) = valor '32
		ElseIf (size = 2) Then
			*(cast(UShort ptr,buf)) = valor '16
		ElseIf (size = 1) Then
			*(cast(UByte  ptr,buf)) = valor '8
		EndIf
	EndIf
  	
done:
	return true 
End Function


 
Function socGpioInit( physMem As ArmMem Ptr , ic As SocIc Ptr , socRev As UByte) As SocGpio ptr
	dim as SocGpio ptr gpio = cast(SocGpio ptr,Callocate(sizeof(SocGpio)) )
	if (gpio=0) Then PERR("cannot alloc GPIO")

	memset(gpio, 0, sizeof(SocGpio)) 
	gpio->ic = ic 
	
	gpio->socRev = socRev
	Select Case As Const (gpio->socRev)  
		case 0 
			gpio->nGpios = 85 

		case 1 
			gpio->nGpios = 90 

		case 2 
			gpio->nGpios = 121 
   End Select

	if memRegionAdd(physMem, PXA_GPIO_BASE, PXA_GPIO_SIZE, cast(ArmMemAccessF ,@socGpioPrvMemAccessF), gpio)=0 Then 
		PERR("cannot add GPIO to MEM")
	EndIf
  
	return gpio 
End Function

Sub socGpioSetState( gpio As SocGpio Ptr , gpioNum As UByte , on_ As Bool)
	Dim As ULong set = gpioNum Shr 5 
	Dim As ULong v = 1UL Shl (gpioNum And &h1F) 
	Dim As ULong Ptr p 
	
	if (gpioNum >= gpio->nGpios) Then return
	
	p = @gpio->inputs(set)
	if (on_) Then 
		*p Or= v 
	else
		*p And= INV( v )
	EndIf

	socGpioPrvRecalcValues(gpio, set) 
	socGpioPrvRecalcIntrs(gpio) 
End Sub

Function socGpioGetState( gpio As SocGpio Ptr , gpioNum As UByte) As SocGpioState
	Dim As ULong sSet = gpioNum Shr 5 
	Dim As ULong bSet = gpioNum Shr 4 
	Dim As ULong bShift = ((gpioNum And &h0F) * 2) 
	Dim As ULong sV = 1UL Shl (gpioNum And &h1F) 
	Dim As ULong bV = 3UL Shl bShift 
	Dim As UByte afr 
	
	if (gpioNum >= gpio->nGpios) Then 
		return SocGpioStateNoSuchGpio
	EndIf
  
	afr = (gpio->AFRs(bSet) And bV) Shr bShift 

	if (gpio->socRev = 1) AndAlso (gpioNum > 85) Then 
  		'AFRS work a bit different here
		if (afr <> 1) Then return Cast(SocGpioState,afr + SocGpioStateAFR0) 
	else
		if (afr <> 0) Then return cast(SocGpioState,afr + SocGpioStateAFR0)
	EndIf
  
	if (gpio->dirs(sSet) And sV) Then 
		return iif(gpio->latches(sSet) And sV , SocGpioStateHigh , SocGpioStateLow )
	EndIf
  
	return SocGpioStateHiZ 
End Function

Sub socGpioSetNotif( gpio As SocGpio Ptr , gpioNum As UByte , notifF As GpioChangedNotifF , userData As any Ptr)
	if (gpioNum >= gpio->nGpios) Then return

	gpio->notifF(gpioNum) = notifF 
	gpio->notifD(gpioNum) = userData 
End Sub

Sub socGpioSetDirsChangedNotif( gpio As SocGpio Ptr , notifF As GpioDirsChangedF , userData As any Ptr)
	gpio->dirNotifF = notifF 
	gpio->dirNotifD = userData 
End Sub
