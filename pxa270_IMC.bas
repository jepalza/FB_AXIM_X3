'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxaImcPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	Dim as PxaImc Ptr imc = cast(PxaImc ptr,userData)
	Dim As uLong valor = 0 
	
	if (size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 
	EndIf
  
	pa = (pa - PXA270_IMC_BASE) Shr 2 
	
	if (write_) Then 
		valor = *cast(ULong ptr,buf)
	EndIf
  
	Select Case As Const (pa)  
		case &h00 
			if (write_) Then 
				imc->mcr = valor And &h00ff0ffful 
			else
				valor = imc->mcr
			EndIf
		
		case &h08 \ 4 
			if (write_) Then 
				return false 		'forbidden
			else
				valor = 0 'all in run mode, forever
			EndIf
   End Select

	if write_=0 Then *cast(ULong ptr,buf) = valor

	return true 
End Function

Function pxaImcInit( physMem As ArmMem Ptr) As PxaImc ptr
	Dim as PxaImc Ptr imc = cast(PxaImc ptr,Callocate(sizeof(PxaImc)))
	
	if imc=0 Then PERR("cannot alloc IMC")

	memset(imc, 0, sizeof(PxaImc)) 
	
	if memRegionAdd(physMem, PXA270_IMC_BASE, PXA270_IMC_SIZE, cast(ArmMemAccessF ,@pxaImcPrvMemAccessF), imc)=0 Then 
		PERR("cannot add IMC to MEM")
	EndIf
  
	return imc 
End Function


