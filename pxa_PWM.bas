'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxaPwmPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	Dim As PxaPwm Ptr pwm = Cast(PxaPwm Ptr,userData) 
	Dim As uLong valor = 0 
	
	if (size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 
	EndIf
  
	pa mod = PXA_PWM_SIZE 
	pa Shr = 2 
	
	if (write_) Then valor = *cast(ULong ptr,buf)

	Select Case As Const (pa)  
		case 0 
			if (write_) Then 
				pwm->ctrl = valor 
			else
				valor = pwm->ctrl
			EndIf
		
		case 1 
			if (write_) Then 
				pwm->duty = valor 
			else
				valor = pwm->duty
			EndIf
		
		case 2 
			if (write_) Then 
				pwm->per = valor 
			else
				valor = pwm->per
			EndIf
   End Select

	if write_=0 Then *cast(ULong ptr,buf) = valor

	return true 
End Function


Function pxaPwmInit( physMem As ArmMem Ptr , base_ As uLong) As PxaPwm ptr
	Dim As PxaPwm Ptr pwm = Cast(PxaPwm Ptr,Callocate(sizeof(PxaPwm)) ) 
	
	if pwm=0 Then 
		PERR("cannot alloc PWM at "+Str(base_))
	EndIf
  
	memset(pwm, 0, sizeof(PxaPwm)) 
	
	if memRegionAdd(physMem, base_, PXA_PWM_SIZE, cast(ArmMemAccessF ,@pxaPwmPrvMemAccessF), pwm)=0 Then 
		PERR("cannot add PWM at to MEM"+Str(base_))
	EndIf

	return pwm 
End Function


