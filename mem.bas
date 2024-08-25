' (c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function memInit() As ArmMem Ptr
	Dim As ArmMem Ptr mem = cast(ArmMem ptr,Callocate(sizeof(ArmMem)) )
	
	if mem=0 Then PERR("cannot alloc MEM")

	memset(mem, 0, sizeof(ArmMem)) 
	
	return mem 
End Function


Sub memDeinit( mem As ArmMem Ptr)
	'revisar mem() 
	print "revisar memDeinit":beep:sleep
End Sub

Function memRegionAdd( mem As ArmMem Ptr , pa As ULong , sz As ULong , aF As ArmMemAccessF , uD As Any Ptr) As Bool
	dim as UByte i 
	
	'check for intersection with another region
	for i = 0 To NUM_MEM_REGIONS-1         
		if mem->regions(i).sz=0 Then continue for
		if (mem->regions(i).pa <= pa) AndAlso ((mem->regions(i).pa + mem->regions(i).sz) > pa) _ 
					OrElse ((pa <= mem->regions(i).pa) AndAlso ((pa + sz) > mem->regions(i).pa)) Then 
			return false ' intersection -> fail
		EndIf
   Next
	
	'find a free region and put it there
	for i = 0 To NUM_MEM_REGIONS-1         
		if mem->regions(i).sz = 0 Then 
			mem->regions(i).pa = pa 
			mem->regions(i).sz = sz 
			mem->regions(i).aF = aF 
			mem->regions(i).uD = uD 
			return true 
		EndIf
   Next
	
	'fail miserably
	return false 	
End Function

Function memAccess( mem As ArmMem Ptr , addr As ULong , size As UByte , accessType As UByte , buf As Any Ptr) As Bool
	dim As Bool ret = false
	dim As Bool wantWrite = NOT_NOT(accessType And INV( MEM_ACCCESS_FLAG_NOERROR) )
	dim as UByte i 

	for i = 0 To NUM_MEM_REGIONS-1         
		if (mem->regions(i).pa <= addr) AndAlso ((mem->regions(i).pa + mem->regions(i).sz) > addr) Then 
			ret = mem->regions(i).aF(mem->regions(i).uD, addr, size, wantWrite, buf)
			'print "BUF leido en memAccess de MEM.BAS : ";size,hex(addr,8),hex(*cast(long ptr,buf),8)
			exit for 
		EndIf
   Next

	if (ret=0) AndAlso ((accessType And MEM_ACCCESS_FLAG_NOERROR)=0) Then 
		Print "Memory ";iif(wantWrite , "WRITE" , "READ");" of ";size;" bytes to PA &h";hex(addr,8);" Fails"
		beep : sleep 'make debugging easier
   EndIf

	return ret 
End Function
