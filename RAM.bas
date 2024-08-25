'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function ramAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , bufP As Any Ptr) As Bool
	Dim AS ArmRam ptr ram = cast(ArmRam ptr,userData )
	Dim AS uByte ptr addr = cast(UByte  ptr,ram->buf )
	
	pa -= ram->adr 
	if (pa >= ram->sz) Then Return false

	addr += pa 
	
	if (write_) Then 
		Select Case As Const (size)  
			case 1 
				*cast(UByte ptr, addr) = *cast(UByte  ptr,bufP) 	'our memory system is little-endian
			
			case 2 
				*cast(UShort ptr,addr) = *cast(UShort ptr,bufP) 	'our memory system is little-endian
			
			case 4 
				*cast(ULong ptr, addr) = *cast(ULong  ptr,bufP) 
			
			case 8 
				*cast(ULong ptr,(addr + 0))  = cast(ULong ptr,bufP)[0]
				*cast(ULong ptr,(addr + 4))  = cast(ULong ptr,bufP)[1]
			
			case 32 
				*cast(ULong ptr,(addr + 0))  = cast(ULong ptr,bufP)[0]
				*cast(ULong ptr,(addr + 4))  = cast(ULong ptr,bufP)[1]
				*cast(ULong ptr,(addr + 8))  = cast(ULong ptr,bufP)[2]
				*cast(ULong ptr,(addr + 12)) = cast(ULong ptr,bufP)[3]
				*cast(ULong ptr,(addr + 16)) = cast(ULong ptr,bufP)[4]
				*cast(ULong ptr,(addr + 20)) = cast(ULong ptr,bufP)[5]
				*cast(ULong ptr,(addr + 24)) = cast(ULong ptr,bufP)[6]
				*cast(ULong ptr,(addr + 28)) = cast(ULong ptr,bufP)[7]
			
			case else 
				return false 
      End Select

	else
         
		Select Case As Const (size)  
			case 1 
				*cast(UByte  ptr,bufP) = *cast(UByte  ptr,addr)
			
			case 2 
				*cast(UShort ptr,bufP) = *cast(UShort ptr,addr) 
			
			case 4 
				*cast(ULong  ptr,bufP) = *cast(ULong  ptr,addr)
				  
			case 8                   
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))				
				    
			case 16
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))             
				cast(ULong ptr,bufP)[2]  = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[3]  = *cast(ULong ptr,(addr + 12))											 						 
		
			case 32                                        
				cast(ULong ptr,bufP)[0]  = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[1]  = *cast(ULong ptr,(addr +  4))
				cast(ULong ptr,bufP)[2]  = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[3]  = *cast(ULong ptr,(addr + 12))        
				cast(ULong ptr,bufP)[4]  = *cast(ULong ptr,(addr + 16))
				cast(ULong ptr,bufP)[5]  = *cast(ULong ptr,(addr + 20))        
				cast(ULong ptr,bufP)[6]  = *cast(ULong ptr,(addr + 24))
				cast(ULong ptr,bufP)[7]  = *cast(ULong ptr,(addr + 28))
				
			case 64 
				cast(ULong ptr,bufP)[ 0] = *cast(ULong ptr,(addr +  0))
				cast(ULong ptr,bufP)[ 1] = *cast(ULong ptr,(addr +  4))
				cast(ULong ptr,bufP)[ 2] = *cast(ULong ptr,(addr +  8))
				cast(ULong ptr,bufP)[ 3] = *cast(ULong ptr,(addr + 12))
				cast(ULong ptr,bufP)[ 4] = *cast(ULong ptr,(addr + 16))
				cast(ULong ptr,bufP)[ 5] = *cast(ULong ptr,(addr + 20))
				cast(ULong ptr,bufP)[ 6] = *cast(ULong ptr,(addr + 24))
				cast(ULong ptr,bufP)[ 7] = *cast(ULong ptr,(addr + 28))        
				cast(ULong ptr,bufP)[ 8] = *cast(ULong ptr,(addr + 32))
				cast(ULong ptr,bufP)[ 9] = *cast(ULong ptr,(addr + 36))
				cast(ULong ptr,bufP)[10] = *cast(ULong ptr,(addr + 40))
				cast(ULong ptr,bufP)[11] = *cast(ULong ptr,(addr + 44))        
				cast(ULong ptr,bufP)[12] = *cast(ULong ptr,(addr + 48))
				cast(ULong ptr,bufP)[13] = *cast(ULong ptr,(addr + 52))       
				cast(ULong ptr,bufP)[14] = *cast(ULong ptr,(addr + 56))
				cast(ULong ptr,bufP)[15] = *cast(ULong ptr,(addr + 60))
			
			case else 
				return false 
      End Select
	EndIf
  
	return true 
End Function

Function ramInit( mem As ArmMem Ptr , adr As uLong , sz As uLong , buf As uLong Ptr) As ArmRam ptr
	Dim AS ArmRam ptr ram = cast(ArmRam ptr,Callocate(sizeof(ArmRam)) )
	
	if (ram=0) Then PERR("cannot alloc RAM at "+Str(adr))

	memset(ram, 0, sizeof(ArmRam)) 
	
	ram->adr = adr 
	ram->sz  = sz 
	ram->buf = buf 
	
	if memRegionAdd(mem, adr, sz, cast(ArmMemAccessF ,@ramAccessF), ram)=0 Then 
		PERR("cannot add RAM at to MEM "+hex(adr))
	endif

	return ram 
End Function
