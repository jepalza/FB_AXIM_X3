'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function aximX3cpldPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   dim As AximX3cpld ptr cpld = cast(AximX3cpld ptr,userData )
	Dim As ULong valor 
	
	pa -= AXIM_X3_CPLD_BASE 
	
	if(size <> 4) OrElse (write_=0) OrElse (pa<>0) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, pa) 
		return false 
	EndIf
	
	valor = *cast(ULong ptr,buf)
	
	if (cpld->valor <> valor) Then 
		printf(!" * CPLD 0x%08lx -> 0x%08lx\n", cpld->valor, valor)
	EndIf
  
	cpld->valor = valor 
	return true 
End Function
	
	
Function aximX3cpldInit(physMem as ArmMem ptr) As AximX3cpld ptr
	Dim AS AximX3cpld ptr cpld = cast(AximX3cpld ptr,Callocate(sizeof(AximX3cpld)))
	
	if (cpld=0) then PERR("cannot alloc AXIM's CPLD") 
	
	memset(cpld, 0, sizeof(AximX3cpld)) 
	
	if memRegionAdd(physMem, AXIM_X3_CPLD_BASE, AXIM_X3_CPLD_SIZE, cast(ArmMemAccessF ,@aximX3cpldPrvMemAccessF), cpld)=0 Then 
		PERR("cannot add AXIM's CPLD to MEM")
	EndIf
  
	return cpld 
End Function
