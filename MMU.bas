'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub mmuTlbFlush(mmu As ArmMmu Ptr)
	memset(@mmu->readPos(0), 0, sizeof(mmu->readPos)*(ubound(mmu->readPos)+1)) 
	memset(@mmu->replPos(0), 0, sizeof(mmu->replPos)*(ubound(mmu->replPos)+1)) 
	memset(@mmu->tlb(0,0)  , 0, sizeof(mmu->tlb)    *(ubound(mmu->tlb,1)+1)*(ubound(mmu->tlb,2)+1)) 
End Sub

Sub mmuReset(mmu As ArmMmu Ptr)
	mmu->transTablPA = MMU_DISABLED_TTP 
	mmuTlbFlush(mmu) 
End Sub

Function mmuInit( mem As ArmMem Ptr , xscaleMode As Bool) As ArmMmu ptr
	dim as ArmMmu ptr mmu = cast(ArmMmu ptr,Callocate(sizeof(ArmMmu)) )
	
	if mmu=0 Then PERR("cannot alloc MMU")
	
	memset(mmu, 0, sizeof(ArmMmu))
	mmu->mem = mem 
	mmu->xscale = xscaleMode 
	
	mmuReset(mmu)
	
	return mmu 
End Function

Function mmuIsOn( mmu As ArmMmu Ptr) As Bool
	return iif(mmu->transTablPA <> MMU_DISABLED_TTP, 1,0) 
End Function


Function mmuPrvHashAddr(addr As ULong) As Ushort	'addresses are granular on 1K
	addr Shr = 10 
	
	addr = addr Xor (addr Shr 5) Xor (addr Shr 10) 
	
	return addr mod MMU_TLB_BUCKET_NUM 
End Function

Function mmuTranslate(mmu As ArmMmu Ptr , adr As ULong , priviledged As Bool , write_ As Bool , paP As ULong Ptr , fsrP As Ubyte Ptr , mappingInfoP As UByte Ptr) As Bool
	dim As Bool c = false, b = false, ur = false, uw = false, sr = false, sw = false 
	dim As Bool section = false, coarse = true, pxa_tex_page = false 
	Dim As ULong va, pa = 0, sz, t 
	Dim As Short i, j, bucket 
	Dim As Ubyte dom, ap = 0 
	
	'handle the ´MMU off´ case
	if (mmu->transTablPA = MMU_DISABLED_TTP) Then 
		va = 0
		pa = 0 
		goto calc 
	EndIf
  
	'check the TLB
	if (MMU_TLB_BUCKET_SIZE<>0) AndAlso (MMU_TLB_BUCKET_NUM<>0) Then 
		bucket = mmuPrvHashAddr(adr) 
				
		i = mmu->readPos(bucket)
		for j = 0 To MMU_TLB_BUCKET_SIZE-1         
			va = mmu->tlb(bucket, i).va 
			sz = mmu->tlb(bucket, i).sz 
			
			if (adr >= va) AndAlso (adr - va < sz) Then 
				pa = mmu->tlb(bucket, i).pa 
				ap = mmu->tlb(bucket, i).ap 
				dom = mmu->tlb(bucket, i).domain 
				c = NOT_NOT(mmu->tlb(bucket, i).c)
				b = NOT_NOT(mmu->tlb(bucket, i).b) 
				mmu->readPos(bucket) = i 	
				goto check 
			EndIf
			i = (i + MMU_TLB_BUCKET_SIZE - 1) mod MMU_TLB_BUCKET_SIZE
      Next
	EndIf
  
	'read first level table
	if (mmu->transTablPA And 3) Then 
		if (fsrP) Then *fsrP = &h01 'alignment fault
		return false 
	EndIf
  
	if memAccess(mmu->mem, mmu->transTablPA + ((adr And &hFFF00000ul) Shr 18), 4, MEM_ACCESS_TYPE_READ, @t)=0 Then 
		if (fsrP) Then *fsrP = &h0C 'translation external abort first level
		return false 
	EndIf
  
	dom = (t Shr 5) And &h0F 
	Select Case As Const (t And 3)  
		case 0 	'fault
			if (fsrP) Then *fsrP = &h5 'section translation fault
			return false 
		
		case 1 	'coarse pagetable
			t And= &hFFFFFC00UL 
			t += (adr And &h000FF000UL) Shr 10 
		
		case 2 	'1MB section
			pa = t And &hFFF00000UL 
			va = adr And &hFFF00000UL 
			sz = 1UL Shl 20 
			ap = (t Shr 10) And 3 
			c  = NOT_NOT(t And &h08) 
			b  = NOT_NOT(t And &h04) 
			section = true 
			goto translated 
			
		case 3 	'fine page table
			coarse = false 
			t And= &hFFFFF000UL 
			t += (adr And &h000FFC00UL) Shr 8 
   End Select

	'read second level table
	if memAccess(mmu->mem, t, 4, MEM_ACCESS_TYPE_READ, @t)=0 Then 
		if (fsrP) Then *fsrP = &h0E Or (dom Shl 4) 'translation external abort second level
		return false 
	EndIf
  
	c = NOT_NOT(t And &h08) 
	b = NOT_NOT(t And &h04) 
	
	Select Case As Const (t And 3)  
		case 0 	'fault
			if (fsrP) Then *fsrP = &h07 Or (dom Shl 4) 'page translation fault
			return false 
		
		case 1 	'64K mapping
			pa =   t And &hFFFF0000UL 
			va = adr And &hFFFF0000UL 
			sz = 65536UL 
			ap = (adr Shr 14) And 3 		'in "ap" store which AP we need [of the 4]
		
		case 2 	'4K mapping (1K effective thenks to having 4 AP fields)
			ap = (adr Shr 10) And 3 		'in "ap" store which AP we need [of the 4]
page_size_4k: 
			pa =   t And &hFFFFF000UL 
			va = adr And &hFFFFF000UL 
			sz = 4096 
			
		case 3 	'1K mapping
			if (coarse) Then 
				if (mmu->xscale) Then 
					pxa_tex_page = true 
					ap = 0 
					goto page_size_4k 	
				else
					MiPrint "invalid coarse page table entry"
					if (fsrP) Then *fsrP = 7
				EndIf
			EndIf
			pa =   t And &hFFFFFC00UL 
			va = adr And &hFFFFFC00UL 
			ap = (t Shr 4) And 3 'in "ap" store the actual AP [and skip quarter-page resolution later using the goto]
			sz = 1024 
			goto translated 
		End Select

	'handle 4 AP sections
	i = (t Shr 4) And &hFF 
	if (pxa_tex_page<>0) OrElse ( ((i And &h0F) = (i Shr 4)) AndAlso ((i And &h03) = ((i Shr 2) And &h03)) ) Then 
		'if all domains are the same, add the whole thing
		ap = (t Shr 4) And 3 
	else
      'take the quarter that is the one we need
		sz \= 4 
		pa += CuLng(ap) * sz 
		va += CuLng(ap) * sz 
		ap = (t Shr (4 + 2 * ap)) And 3 
	EndIf

translated: 

	'insert tlb entry
	if (MMU_TLB_BUCKET_NUM<>0) AndAlso (MMU_TLB_BUCKET_SIZE<>0) Then 
		mmu->tlb(bucket, mmu->replPos(bucket)).pa = pa 
		mmu->tlb(bucket, mmu->replPos(bucket)).sz = sz 
		mmu->tlb(bucket, mmu->replPos(bucket)).va = va 
		mmu->tlb(bucket, mmu->replPos(bucket)).ap = ap 
		mmu->tlb(bucket, mmu->replPos(bucket)).domain = dom 
		mmu->tlb(bucket, mmu->replPos(bucket)).c = iif(c , 1 , 0) 
		mmu->tlb(bucket, mmu->replPos(bucket)).b = iif(b , 1 , 0)
		mmu->readPos(bucket) = mmu->replPos(bucket) 
		mmu->replPos(bucket)+=1
		if (mmu->replPos(bucket) = MMU_TLB_BUCKET_SIZE) Then mmu->replPos(bucket) = 0
	EndIf

check:
				
	'check domain permissions
	Select Case As Const  ((mmu->domainCfg Shr (dom * 2)) And 3)  
		case 0,_ 	'NO ACCESS:
		     2   	'RESERVED: unpredictable	(treat as no access)
			if (fsrP) Then *fsrP = iif(section , &h08 , &hB) Or (dom Shl 4) 'section or page domain fault
			return false 
			
		case 1 	'CLIENT: check permissions
		' NADA
			
		case 3 	'MANAGER: allow all access
			ur = true 
			uw = true 
			sr = true 
			sw = true 
			goto calc 
   End Select

	'check permissions
	Select Case As Const (ap)  
		case 0 
			ur = mmu->R 
			sr = iif((mmu->S<>0) OrElse (mmu->R<>0),1,0) ' revisar
			
			if (write_<>0) OrElse ( ((mmu->R=0) AndAlso ((priviledged=0) OrElse (mmu->S=0))) ) Then 
				exit select
			EndIf
			goto calc 
		
		case 1 
			sr = true 
			sw = true 
			if (priviledged=0) Then 
				exit select
			EndIf
			goto calc 

		case 2 
			ur = true 
			sr = true 
			sw = true 
			if (priviledged=0) AndAlso (write_<>0) Then 
				exit select
			EndIf
			goto calc 
		
		case 3 
			ur = true 
			uw = true 
			sr = true 
			sw = true 
			'all is good, allow access!
			goto calc 
   End Select


	if (fsrP) Then *fsrP = iif(section , &h0D , &h0F) Or (dom Shl 4)

  	'section or subpage permission fault
	return false 
	
calc: 
	if (mappingInfoP) Then 
		*mappingInfoP = _
					iif(c  , MMU_MAPPING_CACHEABLE  , 0) Or _
					iif(b  , MMU_MAPPING_BUFFERABLE , 0) Or _
					iif(ur , MMU_MAPPING_UR , 0) Or _
					iif(uw , MMU_MAPPING_UW , 0) Or _
					iif(sr , MMU_MAPPING_SR , 0) Or _
					iif(sw , MMU_MAPPING_SW , 0) 
	EndIf
  
	*paP = adr - va + pa 
	return true 
End Function

Function mmuGetTTP(mmu As ArmMmu Ptr) As ULong
	return mmu->transTablPA 
End Function

Sub mmuSetTTP(mmu As ArmMmu Ptr , ttp As ULong)
	mmuTlbFlush(mmu) 
	mmu->transTablPA = ttp 
End Sub

Sub mmuSetS(mmu As ArmMmu Ptr , on_ As Bool)
	mmu->S = on_ 	
End Sub

Sub mmuSetR(mmu As ArmMmu Ptr , on_ As Bool)
	mmu->R = on_ 	
End Sub

Function mmuGetS(mmu As ArmMmu Ptr) As Bool 
	return iif( mmu->S ,1,0)
End Function

Function mmuGetR(mmu As ArmMmu Ptr) As Bool
	return iif( mmu->R ,1,0)
End Function

Function mmuGetDomainCfg(mmu As ArmMmu Ptr) As ULong
	return mmu->domainCfg 
End Function

Sub mmuSetDomainCfg(mmu As ArmMmu Ptr , valor As ULong)
	mmu->domainCfg = valor 
End Sub

' ----------------  debugging helpers -------------------
Function mmuPrvDebugRead(mmu As ArmMmu Ptr , addr As ULong) As ULong
	Dim As ULong t 
	if memAccess(mmu->mem, addr, 4, MEM_ACCESS_TYPE_READ, @t)=0 Then t = &hFFFFFFF0UL
	return t 
End Function

Sub mmuPrvDumpUpdate(va As ULong , pa As ULong , len_ As ULong , dom As UByte , ap As UByte , c As Bool , b As Bool , valid As Bool)
	Static As Bool wasValid = false 
	Static As ULong expectPa = 0 
	Static As ULong startVa = 0 
	Static As ULong startPa = 0 
	Static As UByte wasDom = 0 
	Static As UByte wasAp = 0 
	Static As Bool wasB = 0 
	Static As Bool wasC = 0 
	Dim As ULong va_end 
	
	va_end = iif((va<>0) OrElse (len_<>0) , va - 1 , &hFFFFFFFFUL )
	
	if (wasValid=0) AndAlso (valid=0) Then return 'no need to bother...
	
	if (valid <> wasValid) OrElse (dom <> wasDom) OrElse (ap <> wasAp) OrElse _
				  (c <> wasC) OrElse (b <> wasB) OrElse (expectPa <> pa) Then 
		'not a continuation of what we´ve been at...
		if (wasValid) Then 
			printf(!"0x%08lx - 0x%08lx -> 0x%08lx - 0x%08lx don%u ap%u %c %c\n",_
				startVa, va_end, startPa, (startPa + (va_end - startVa)),_
				wasDom, wasAp, iif(wasC , "c" , " "), iif(wasB , "b" , " "))
		EndIf
		
		wasValid = valid 
		if (valid) Then  'start of a new range
			wasDom = dom 
			wasAp = ap 
			wasC = c 
			wasB = b 
			startVa = va 
			startPa = pa 
			expectPa = pa + len_
		endif
	else
      'continuation of what we´ve been up to...
		expectPa += len_
	EndIf
  
End Sub

Sub mmuDump(mmu as ArmMmu ptr)
	Dim As ULong i, j, t, sla, va, psz 
	dim As Bool coarse = false 
	Dim As Ubyte dom 
	
	for i = 0 To &h1000 -1        
		t = mmuPrvDebugRead(mmu, mmu->transTablPA + (i Shl 2)) 
		va = i Shl 20 
		dom = (t Shr 5) And &h0F 
		Select Case As Const (t And 3)  
			case 0 		'done
				mmuPrvDumpUpdate(va, 0, 1UL Shl 20, 0, 0, false, false, false) 
				continue for
			
			case 1 		'coarse page table
				coarse = true 
				t And= &hFFFFFC00UL 
			
			case 2 		'section
				mmuPrvDumpUpdate(va, t And &hFFF00000UL, 1UL Shl 20, dom, (t Shr 10) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
				continue for
			
			case 3 		'fine page table
				t And= &hFFFFF000UL 

      End Select

		sla = t 
		psz = iif( coarse , 4096 , 1024 ) 
		for j = 0 To ((1UL Shl 20) \ psz) -1        
			t = mmuPrvDebugRead(mmu, sla + (j Shl 2)) 
			va = (i Shl 20) + (j * psz) 
			Select Case As Const (t And 3)  
				case 0 		'invalid
					mmuPrvDumpUpdate(va, 0, psz, 0, 0, false, false, false) 
				
				case 1 		'large 64k page
					mmuPrvDumpUpdate(va + 0 * 16384UL, (t And &hFFFF0000UL) + 0 * 16384UL, 16384, dom, (t Shr  4) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 1 * 16384UL, (t And &hFFFF0000UL) + 1 * 16384UL, 16384, dom, (t Shr  6) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 2 * 16384UL, (t And &hFFFF0000UL) + 2 * 16384UL, 16384, dom, (t Shr  8) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 3 * 16384UL, (t And &hFFFF0000UL) + 3 * 16384UL, 16384, dom, (t Shr 10) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					j += iif(coarse , 15 , 63) 
				
				case 2 		'small 4k page
					mmuPrvDumpUpdate(va + 0 * 1024, (t And &hFFFFF000UL) + 0 * 1024, 1024, dom, (t Shr  4) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 1 * 1024, (t And &hFFFFF000UL) + 1 * 1024, 1024, dom, (t Shr  6) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 2 * 1024, (t And &hFFFFF000UL) + 2 * 1024, 1024, dom, (t Shr  8) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					mmuPrvDumpUpdate(va + 3 * 1024, (t And &hFFFFF000UL) + 3 * 1024, 1024, dom, (t Shr 10) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					if (coarse=0) Then j += 3
				
				case 3 		'tiny 1k page or TEX page on pxa
					if (coarse) Then 
						mmuPrvDumpUpdate(va, t And &hFFFFF000UL, 4096, dom, (t Shr 4) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true) 
					else
						mmuPrvDumpUpdate(va, t And &hFFFFFC00UL, 1024, dom, (t Shr 4) And 3, NOT_NOT(t And 8), NOT_NOT(t And 4), true)
					EndIf
         End Select
      Next
		
   Next
	mmuPrvDumpUpdate(0, 0, 0, 0, 0, false, false, false) 	'finish things off
End Sub
