 '(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


static shared As UByte volmap(&h1C)
		volmap(VOLMASTER)     = &h80 + 0
		volmap(VOLHPHONE)     = &h80 + 1
		volmap(VOLMASTERMONO) = &h80 + 2
		volmap(VOLPCBEEP) 	 = &h80 + 3
		volmap(VOLPHONE) 		 = &h80 + 4
		volmap(VOLMIC) 		 = &h80 + 5
		volmap(VOLLINEIN) 	 = &h80 + 6
		volmap(VOLCD) 			 = &h80 + 7
		volmap(VOLVIDEO) 		 = &h80 + 8
		volmap(VOLAUX) 		 = &h80 + 9
		volmap(VOLPCMOUT) 	 = &h80 + 10
		volmap(VOLRECGAIN) 	 = &h80 + 11
		
Function wm9705_prvGetVolReg(wm As WM9705 Ptr , regAddr As ULong) As UShort ptr
	if (regAddr > UBound(volmap)) OrElse (volmap(regAddr)=0) Then 
		return NULL
   EndIf

	return @wm->volumes(volmap(regAddr) - &h80) 
End Function

Function wm9705_prvCodecRegR(userData As Any Ptr , regAddr As ULong , regValP As UShort Ptr) As Bool
	Dim as WM9705REG which = cast(WM9705REG,regAddr)
   dim As WM9705 ptr wm = cast(WM9705 ptr,userData) 
	Dim As UShort valor 
	
	' ojo , salen muchos textos y se llena la pantalla
	print "codec read [0x";hex(regAddr,4);"]"
	
	Select Case As Const  (which)  
		case RESET_
			valor = &h6150 
		
		case VOLMASTER ,_
		   VOLHPHONE ,_
		   VOLMASTERMONO ,_
		   VOLPCBEEP ,_
		   VOLPHONE ,_
		   VOLMIC ,_
		   VOLLINEIN ,_
		   VOLCD ,_
		   VOLVIDEO ,_
		   VOLAUX ,_
		   VOLPCMOUT ,_
		   VOLRECGAIN 
			valor = *wm9705_prvGetVolReg(wm, which) 
		
		case RECSELECT 
			valor = wm->recSelect 
		
		case GENERALPURPOSE 
			valor = wm->generalPurpose 
		
		case POWERDOWN 
			valor = wm->powerdownReg 
		
		case EXTDAUDIO 
			valor = wm->extdAudio 
		
		case DACRATE 
			valor = wm->dacrate 
		
		case ADCRATE 
			valor = wm->adcrate 
		
		case MIXERPATHMUTE 
			valor = wm->mixerPathMute  
		
		case ADDFUNCCTL 
			valor = wm->addtlFuncCtl 
		
		case ADDFUNC 
			valor = wm->addFunc 
		
		case DIGI1 
			valor = wm->digiRegs(0) 
		
		case DIGI2 
			valor = wm->digiRegs(1) 
		
		case DIGI_RES 
			valor = wm->digiRegs(2) 
			wm->haveUnreadPenData = false 
		
		case VID1 
			valor = &h574D 
			
		case VID2 
			valor = &h4C05 
		
		case else 
			MiPrint "unknown reg"
			return false 
   End Select

	*regValP = valor 
	return true 
End Function


Function wm9705_prvCodecRegW(userData As Any Ptr , regAddr As ULong , valor As UShort) As Bool
	Dim as WM9705REG which = cast(WM9705REG,regAddr) ' no se usa aun, al no estar implementado
	dim As WM9705 ptr wm = cast(WM9705 ptr,userData)
	
	' ojo , salen muchos textos y se llena la pantalla
	print "codec write 0x";hex(valor,4);" -> [0x";hex(regAddr,4);"]"
		
	Select Case As Const (regAddr)  
		case VOLMASTER ,_
		   VOLHPHONE ,_
		   VOLMASTERMONO ,_
		   VOLPCBEEP ,_
		   VOLPHONE ,_
		   VOLMIC ,_
		   VOLLINEIN ,_
		   VOLCD ,_
		   VOLVIDEO ,_
		   VOLAUX ,_
		   VOLPCMOUT ,_
		   VOLRECGAIN 
			*wm9705_prvGetVolReg(wm, which) = valor 
		
		case RECSELECT 
			wm->recSelect = valor 
		
		case GENERALPURPOSE 
			wm->generalPurpose = valor 
		
		case POWERDOWN 
			wm->powerdownReg = valor 
		
		case EXTDAUDIO 
			wm->extdAudio = valor 
			
		case DACRATE 
			wm->dacrate = valor 
		
		case ADCRATE 
			wm->adcrate = valor 
			
		case MIXERPATHMUTE 
			wm->mixerPathMute = valor 
		
		case ADDFUNCCTL 
			wm->addtlFuncCtl = valor 
		
		case ADDFUNC 
			wm->addFunc = valor 
		
		case DIGI1 
			wm->digiRegs(0) = valor 
		
		case DIGI2 
			wm->digiRegs(1) = valor 
		
		case else 
			MiPrint "unknown reg" 
			return false 
   End Select

	return true 
End Function

Function wm9705_prvCodecUnusedRegW(userData As Any Ptr , regAddr As ULong , valor As UShort) As Bool 'no regs in modem part of this codec - only uses modem slot for touch data
	return false 
End Function

Function wm9705_prvCodecUnusedRegR(userData As Any Ptr , regAddr As ULong , regValP As UShort Ptr) As Bool 'no regs in modem part of this codec - only uses modem slot for touch data
	return false 
End Function

Function wm9705_Init( ac97 As SocAC97 Ptr) As WM9705 ptr
	dim as WM9705 ptr wm = cast(WM9705 ptr,Callocate(sizeof(WM9705)) )
	dim as long i 
	
	if (wm=0) Then PERR("cannot alloc WM9705")

	memset(wm, 0, sizeof(WM9705)) 
	
	wm->ac97 = ac97 
	wm->powerdownReg = &h000f 
	
	for i=0 To 3      
		wm->volumes(i) = &h8000 
   Next
		
	for i=4 To 5      
		wm->volumes(i) = &h8008 
   Next
		
	for i=6 To 10       
		wm->volumes(i) = &h8808 
   Next
	wm->volumes(11) = &h8000 
	
	wm->dacrate = &hbb80 
	wm->adcrate = &hbb80 
	
	socAC97clientAdd(ac97, Ac97PrimaryAudio  , cast(Ac97CodecRegR,@wm9705_prvCodecRegR)      , cast(Ac97CodecRegW,@wm9705_prvCodecRegW)      , wm) 
	socAC97clientAdd(ac97, Ac97SecondaryAudio, cast(Ac97CodecRegR,@wm9705_prvCodecUnusedRegR), cast(Ac97CodecRegW,@wm9705_prvCodecUnusedRegW), wm) 
	socAC97clientAdd(ac97, Ac97PrimaryModem  , cast(Ac97CodecRegR,@wm9705_prvCodecUnusedRegR), cast(Ac97CodecRegW,@wm9705_prvCodecUnusedRegW), wm) 
	
	return wm 
End Function

Sub wm9705_prvNewAudioPlaybackSample(wm As WM9705 Ptr , samp As ULong)
	'nothing for now
End Sub

Function wm9705_prvHaveAudioOutSample(wm As WM9705 Ptr , sampP As ULong Ptr) As Bool
	*sampP = 0 
	return true 
End Function

Function wm9705_prvHaveMicOutSample(wm As WM9705 Ptr , sampP As ULong Ptr) As Bool
	*sampP = 0 
	return true 
End Function

Function wm9705_prvGetSample(wm As WM9705 Ptr , which As WM9705sampleIdx) As Ushort
	Dim As UShort ret 

	Select Case As Const (which)  
		case WM9705sampleIdxNone 
			ret = 0 
		
		case WM9705sampleIdxX 
			ret = wm->penX 
		
		case WM9705sampleIdxY 
			ret = wm->penY 
		
		case WM9705sampleIdxPressure 
			ret = wm->penZ 
		
		case WM9705sampleIdxBmon 
			ret = wm->vAux(WM9705auxPinBmon) 
		
		case WM9705sampleIdxAuxAdc 
			ret = wm->vAux(WM9705auxPinAux) 
		
		case WM9705sampleIdxPhone 
			ret = wm->vAux(WM9705auxPinPhone) 
		
		case WM9705sampleIdxPcBeep 
			ret = wm->vAux(WM9705auxPinPcBeep) 
		
		case else 
			ret = 0 
	
   End Select

	ret And= &h0fff 
	if (wm->penDown) Then ret Or= &h8000

	ret Or= cUShort(which) Shl 12 
	
	'print which;" -> 0x";hex(ret,4)
	
	return ret 
End Function

Function wm9705_prvHaveModemOutSample(wm As WM9705 Ptr , sampP As ULong Ptr) As Bool
	Dim As short retvalor 
	'if we are not in slot mode, and we have unread data, we cannot proceed and bail out early
	if ((wm->digiRegs(0) And &h08)=0) AndAlso (wm->haveUnreadPenData<>0) AndAlso ((wm->digiRegs(1) And &h0100)<>0) Then 
		return false
	EndIf
  
	'if we are in slot mode but any slot except 5 is selected, provide no data - pxa255 cnanot get it anyways, plus this is callback for modem data (slot5)
	if ((wm->digiRegs(0) And &h08)<>0) AndAlso ((wm->digiRegs(0) And &h07)<>0) Then 
		return false
	EndIf
  
	'if we have unread data, send it and do nothing else
	if (wm->numUnreadDatas) Then 
		retvalor = wm->otherTwo(2 - wm->numUnreadDatas )
		wm->numUnreadDatas-=1
	'else, if needed do a sampling (poll is set or continuous is set and pdet is off or pen is down
	ElseIf ((wm->digiRegs(0) And &h8000)<>0) OrElse (wm->penDown<>0) OrElse ((wm->digiRegs(1) And &h1000)=0) Then
		dim as WM9705sampleIdx addrIdx = cast(WM9705sampleIdx,((wm->digiRegs(0) Shr 12) And 7)) 
		
		'clear poll immediately
		wm->digiRegs(0) And= INV( &h8000 )
		
		'see if we need a set
		if (wm->digiRegs(0) And &h0800) Then 
			Dim As Ushort y 
			
			'get x
			retvalor = wm9705_prvGetSample(wm, WM9705sampleIdxX) 
			
			'get y
			y = wm9705_prvGetSample(wm, WM9705sampleIdxY) 
			
			'get third if needed
			if (addrIdx <> WM9705sampleIdxNone) Then 
				wm->otherTwo(0) = y 
				wm->otherTwo(1) = wm9705_prvGetSample(wm, addrIdx) 
				wm->numUnreadDatas = 2 
			else
				wm->otherTwo(1) = y 
				wm->numUnreadDatas = 1 
			EndIf

		'else read one thing (even if "none")
		else
			retvalor = wm9705_prvGetSample(wm, addrIdx) 
		EndIf
	'else no data
	else
		return false
	EndIf
	
	'provide ret valor (not necessarily in the slot)
	if (wm->digiRegs(0) And &h08) Then 
		'print "touch reply 0x";hex(retvalor,4);" (slot)"
		*sampP = retvalor 
		return true 
	EndIf

	wm->digiRegs(2) = retvalor 
	return false 
End Function

Sub wm9705_periodic(wm As WM9705 Ptr)
	Dim As ULong valor 
	
	if (socAC97clientClientWantData(wm->ac97, Ac97PrimaryAudio, @valor)) Then 
		wm9705_prvNewAudioPlaybackSample(wm, valor)
	EndIf
  
	if (wm9705_prvHaveAudioOutSample(wm, @valor)) Then 
		socAC97clientClientHaveData(wm->ac97, Ac97PrimaryAudio, valor)
	EndIf
  
	if (wm9705_prvHaveMicOutSample(wm, @valor)) Then 
		socAC97clientClientHaveData(wm->ac97, Ac97SecondaryAudio, valor)
	EndIf
  
	if (wm9705_prvHaveModemOutSample(wm, @valor)) Then 
		socAC97clientClientHaveData(wm->ac97, Ac97PrimaryModem, valor)
	EndIf
  
End Sub

Sub wm9705_setAuxVoltage(wm As WM9705 Ptr , which As WM9705auxPin , mV As ULong)
	'vref is 3.3V
	if (mV > 3300) Then 
		mV = &hfff 
	else
		mV = (mV * 4095 + 3300 \ 2) \ 3300
	EndIf
  
	wm->vAux(which) = mV 
End Sub

Sub wm9705_setPen(wm As WM9705 ptr, x as Short, y as Short, press as Short)		'raw ADC values, negative for pen up
	wm->penDown = iif( (x >= 0) AndAlso (y >= 0) AndAlso (press >= 0),1,0) 
	if (wm->penDown) then
		wm->penX = x 
		wm->penY = y 
		wm->penZ = press 
	end if
End Sub
