'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxaMemCtrlrPrvClockMgrMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	dim as PxaMemCtrlr ptr mc = cast(PxaMemCtrlr ptr,userData)
	dim as uLong valor = 0 
	
	if (size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 		'we do not support non-word accesses
	EndIf
  
	pa = (pa - PXA_MEM_CONTROLLER_BASE) Shr 2 

	if (write_) Then 
		valor = *cast(uLong ptr,buf)
		print " MEM: 0x";hex(valor,8);" -> [0x";hex(pa * 4 + PXA_MEM_CONTROLLER_BASE,8);"]"
	EndIf
  
	Select Case As Const (pa)  
		case 0 		'MDCNFG
			if (write_) Then 
				mc->mdcnfg = valor 
			else
				valor = mc->mdcnfg
			EndIf
		
		case 1 		'MDREFR
			if (write_) Then 
				mc->mdrefr = valor 
			else
				valor = mc->mdrefr
		EndIf
		
		case 2,3,4 		'MSCx
			if (write_) Then 
				mc->msc(pa - 2) = valor 
			else
				valor = mc->msc(pa - 2)
			EndIf
		
		case 5 		'MECR
			if (write_) Then 
				mc->mecr = valor 
			else
				valor = mc->mecr
			EndIf
		
		case 7 		'SXCNFG
			if (write_) Then 
				mc->sxcnfg = valor 
			else
				valor = mc->sxcnfg
			EndIf
		
		case 8 		'unknonw reg
			if mc->g2=0 Then return false
			if (write_) Then 
				mc->reg_0x20 = valor 
			else
				valor = mc->reg_0x20
			EndIf
		
		case 9 		'SXMRS
			if (mc->g2) Then return false
			if (write_) Then 
				mc->sxmrs = valor 
			else
				valor = mc->sxmrs
			EndIf
		
		case 10,11 	'MCMEMx
			if (write_) Then 
				mc->mcmem(pa - 10) = valor 
			else
				valor = mc->mcmem(pa - 10)
			EndIf
		
		case 12,13 	'MCATTx
			if (write_) Then 
				mc->mcatt(pa - 12) = valor 
			else
				valor = mc->mcatt(pa - 12)
			EndIf
		
		case 14,15 	'MCIOx
			if (write_) Then 
				mc->mcio(pa - 14) = valor 
			else
				valor = mc->mcio(pa - 14)
			EndIf
		
		case 16 	'MDMRS
			if (write_) Then 
				mc->mdmrs = valor 
			else
				valor = mc->mdmrs
			EndIf
		
		case 17 	'BOOT_DEF
			if (write_) Then return false
			valor = 9 	'boot from 16 bit memory

		case 18 	'ARB_CNTRL
			if mc->g2=0 Then return false
			if (write_) Then 
				mc->arbCntrl = valor And &hff800ffful 
			else
				valor = mc->arbCntrl
			EndIf
		
		case 19,_	'BSCNTR0
		     20 	   'BSCNTR1
			if mc->g2=0 Then return false
			if (write_) Then 
				mc->bscntr(pa - 19) = valor 
			else
				valor = mc->bscntr(pa - 19)
			EndIf
		
		case 21 	'LCDBSCNTR
			if mc->g2=0 Then return false
			if (write_) Then 
				mc->lcdbscntr = valor And &h0f 
			else
				valor = mc->lcdbscntr
			EndIf
		
		case 22 	'MDMRSLP
			if (write_) Then 
				mc->mdmrslp = valor 
			else
				valor = mc->mdmrslp
			EndIf
		
		case 23 ,_	'BSCNTR2
		     24   	'BSCNTR3
			if mc->g2=0 Then return false
			if (write_) Then 
				mc->bscntr(pa - 23 + 2) = valor 
			else
				valor = mc->bscntr(pa  - 23 + 2)
			EndIf
		
		case 25 	'SA1110
			if (write_) Then 
				mc->sa1110 = valor And &h313f 
			else
				valor = mc->sa1110
			EndIf
		
		case else 
			return false 
   End Select

	if write_=0 Then *cast(ULong ptr,buf) = valor

	return true 
End Function

Function pxaMemCtrlrInit( physMem As ArmMem Ptr , socRev As UByte) As PxaMemCtrlr ptr
	Dim as PxaMemCtrlr ptr mc = cast(PxaMemCtrlr ptr,Callocate(sizeof(PxaMemCtrlr)))
	Dim As UByte i 
	
	if mc=0 Then PERR("cannot alloc MEMC")

	memset(mc, 0, sizeof(PxaMemCtrlr)) 
	mc->g2 = iif(socRev = 2,1,0)
	
	mc->mdcnfg = &h0b000b00ul 
	mc->mdmrs  = &h00220022ul 
	mc->mdrefr = &h23ca4ffful 
	mc->sxcnfg = &h40044004ul 
	
	for i = 0 To 2       
		mc->msc(i) = &h7ff07ff0ul
   Next
	
	mc->arbCntrl = &h00800234ul 
	for  i = 0 To 3      
		mc->bscntr(i) = &h55555555ul
   Next
	mc->lcdbscntr = &h05 
	
	if memRegionAdd(physMem, PXA_MEM_CONTROLLER_BASE, PXA_MEM_CONTROLLER_SIZE, cast(ArmMemAccessF ,@pxaMemCtrlrPrvClockMgrMemAccessF), mc)=0 Then 
		PERR("cannot add MEMC to MEM")
	EndIf
  
	return mc 
End Function

