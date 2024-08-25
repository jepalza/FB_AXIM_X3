'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub icacheInval( ic As icache Ptr)
	Dim As UShort i, j 
	
	' NOTA: la "dimension" J es solo 1, por lo tanto, no merece la pena gestionarla
	for i = 0 To ICACHE_BUCKET_NUM -1        
		'for j = 0 To ICACHE_BUCKET_SZ -1      
			'ic->lines(i, j).info = 0 ' original con I,J
			ic->lines(i).info = 0 ' dejo solo la "i", la "j" no vale
      'Next
		ic->ptr_(i) = 0 
   Next
End Sub

Function icacheInit( mem As ArmMem Ptr ,  mmu As ArmMmu Ptr) As icache Ptr
	Dim As icache ptr ic = cast(icache ptr,Callocate(sizeof(icache)) )
	if ic=0 Then PERR("cannot alloc icache")

	memset(ic, 0, sizeof(icache)) 
	
	ic->mem = mem 
	ic->mmu = mmu 
	
	icacheInval(ic) 
	
	return ic 	
End Function

Function icachePrvHash(addr As uLong) As UShort
	addr Shr = ICACHE_L 
	addr And= (1UL Shl ICACHE_S) - 1UL

	return addr 
End Function

Sub icacheInvalAddr( ic As icache Ptr , va As uLong)
	Dim as uLong offs = va mod ICACHE_LINE_SZ 
	Dim As Short i, j, bucket 
	dim as icacheLine ptr lines 
	
	va -= offs 

	bucket = icachePrvHash(va) 
	lines = @ic->lines(bucket) 
	
	j = ic->ptr_(bucket)
	for i = 0 To ICACHE_BUCKET_SZ-1         
		j-=1
		if (j = -1) Then j = ICACHE_BUCKET_SZ - 1
		if (lines[j].info And (ICACHE_ADDR_MASK Or ICACHE_USED_MASK)) = (va Or ICACHE_USED_MASK) Then 
			'found it!
			lines[j].info = 0
		EndIf
   Next
End Sub

' recoge instrucciones desde RAM\ROM
Function icacheFetch( ic As icache Ptr , va As uLong , sz As UByte , priviledged As Bool , fsrP As UByte Ptr , buf As Any Ptr) As Bool
	Dim As icacheLine ptr lines, mline = NULL 
	dim as uLong offs = va mod ICACHE_LINE_SZ 
	Dim As short i, j, bucket 
	dim As Bool needRead = false 

	va -= offs
	
	if (va And (sz - 1)) Then 'alignment issue
		if (fsrP) Then *fsrP = 3
		return false 
	EndIf
  
	bucket = icachePrvHash(va) 
	lines = @ic->lines(bucket) 
	
	j = ic->ptr_(bucket)
	for i = 0 To ICACHE_BUCKET_SZ-1         
		j-=1
		if (j = -1) Then j = ICACHE_BUCKET_SZ - 1
		if ((lines[j].info And (ICACHE_ADDR_MASK Or ICACHE_USED_MASK)) = (va Or ICACHE_USED_MASK)) Then 
			'found it!
			if (priviledged=0) AndAlso ((lines[j].info And ICACHE_PRIV_MASK)<>0) Then 
				'we found a line but it was cached as priviledged and we are not sure if unpriv can access it
				'attempt a re-read_. if it passes, remove priv flag
				needRead = true 
			EndIf
			mline = @lines[j]
			exit for 
		EndIf
   Next
	
	if mline=0 Then 
		needRead = true 
		
		j = ic->ptr_(bucket)
		ic->ptr_(bucket)+=1
		if (ic->ptr_(bucket) = ICACHE_BUCKET_SZ) Then 
			ic->ptr_(bucket) = 0
		EndIf
  
		mline = lines + j 
	EndIf

	if (needRead) Then 
		Dim AS uByte datas(ICACHE_LINE_SZ), mappingInfo 
		Dim AS uLong pa 
	
		'if we´re here, we found nothing - maybe time to populate the cache
		if mmuTranslate(ic->mmu, va, priviledged, false, @pa, fsrP, @mappingInfo)=0 Then 
			return false
		EndIf

		if (mmuIsOn(ic->mmu)=0) OrElse ((mappingInfo And MMU_MAPPING_CACHEABLE)=0) Then 
			'uncacheable mapping or mmu is off - just do the read_ we were asked to and do not fill the line
			if memAccess(ic->mem, pa + offs, sz, MEM_ACCESS_TYPE_READ, buf)=0 Then 
				if (fsrP) Then *fsrP = &h0d 'perm error
				return false 
			EndIf
			return true 
		EndIf

		if memAccess(ic->mem, pa, ICACHE_LINE_SZ, MEM_ACCESS_TYPE_READ, @datas(0))=0 Then 
			if (fsrP) Then *fsrP = &h0d 'perm error
			return false 
		EndIf

		memcpy(@mline->datas(0), @datas(0), ICACHE_LINE_SZ) 
		mline->info = va Or iif(priviledged , ICACHE_PRIV_MASK , 0) Or ICACHE_USED_MASK 
	EndIf

	if (sz = 4) Then 
		*cast(ULong ptr,buf)  = *cast(ULong  ptr,(@mline->datas(0) + offs)) 
	ElseIf  (sz = 2) Then
		'icache reads in words, but code requests may come in halfwords
		'on BE hosts this means we need to swap the order of halfwords
		' (to unswap what he had already swapped)
		' __LITTLE_ENDIAN=PC
		*cast(UShort ptr,buf) = *cast(UShort ptr,(@mline->datas(0) + offs))
	else
		memcpy(@buf, @mline->datas(0) + offs, sz)
	EndIf
  
	return iif( (priviledged<>0) OrElse ((mline->info And ICACHE_PRIV_MASK)=0) ,1,0)
End Function
