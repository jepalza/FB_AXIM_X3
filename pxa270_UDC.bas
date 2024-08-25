'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxa270UdcPrvMemAccessF( userData As Any Ptr , pa As ULong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	Dim As Pxa270Udc ptr udc = cast(Pxa270Udc ptr,userData) 
	Dim As ULong valor = 0 

	if (size <> 4) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_, "write" , "read"), size, pa) 
		return false 
	EndIf
  
	pa = (pa - PXA_UDC_BASE) Shr 2 
	
	if (write_) Then valor = *cast(ULong ptr,buf)
  
	if (pa >= &h100 \ 4) AndAlso (pa < &h160 \ 4) Then   
		Dim As UByte epNo = pa - &h100 \ 4 
		if write_=0 Then
			valor = udc->ep(epNo).csr 
		ElseIf epNo=0 Then
			udc->ep(epNo).csr = ((udc->ep(epNo).csr And &h1ff) Or (valor And &h20e)) And INV(valor And &h191) 
		else
			udc->ep(epNo).csr = ((udc->ep(epNo).csr And &h3d7) Or (valor And &h1a8)) And INV(valor And &h016)
		EndIf
	ElseIf (pa >= &h200 \ 4) AndAlso (pa < &h260 \ 4) Then   
		Dim As UByte epNo = pa - &h200 \ 4 
		if (write_) Then
			 	'ignored
		else
			valor = udc->ep(epNo).bcr
		EndIf
	ElseIf (pa >= &h300 \ 4) AndAlso (pa < &h360 \ 4) Then   
		Dim As UByte epNo = pa - &h300 \ 4 
		PERR("FIFO for USB EP -> "+iif(write_ , "W:" , "R:")+hex(epNo)) 
	ElseIf (pa >= &h404 \ 4) AndAlso (pa < &h460 \ 4) Then
		Dim As UByte epNo = pa - &h400 \ 4 
		if write_ Then 
			udc->ep(epNo).ccra = valor And &h07fffffful 
		else
			valor = udc->ep(epNo).ccra
		EndIf
	else
		Select Case As Const (pa)  
			case &h000  		'UDCCR
				if(write_) Then 
					udc->udccr = ((udc->udccr And &h70011ffeul) Or (valor And &h80000001ul)) And INV(valor And &h0000001cul) 
				else
					valor = udc->udccr
				EndIf
			
			case &h04 \ 4 		'UDICICR0
				if (write_) Then 
					udc->udcicr(0) = valor 
				else
					valor = udc->udcicr(0)
				EndIf
			
			case &h08 \ 4 		'UDICICR1
				if (write_) Then 
					udc->udcicr(1) = valor And &hf800fffful 
				else
					valor = udc->udcicr(1)
				EndIf
			
			case &h0c \ 4 		'UDICISR0
				if (write_) Then 
					udc->udcisr(0) = valor 
				else
					valor = udc->udcisr(0)
				EndIf
			
			case &h10 \ 4 		'UDICISR1
				if (write_) Then 
					udc->udcisr(1) = valor And &hf800fffful 
				else
					valor = udc->udcisr(1)
				EndIf
			
			case &h14 \ 4 		'UDCFNR
				if (write_) Then 
						'ignored
				else
					valor = udc->udcfnr
				EndIf
			
			case &h18 \ 4 		'UDCOTGICR
				if (write_) Then 
					udc->udcotgicr = valor And &h010303fful 
				else
					valor = udc->udcotgicr
				EndIf
			
			case &h1c \ 4 		'UDCOTGISR
				if (write_) Then 
					udc->udcotgisr And= INV(valor And &h010303fful) 
				else
					valor = udc->udcotgisr
				EndIf
			
			case &h20 \ 4 		'UP2OCR
				if (write_) Then 
					udc->up2ocr = valor And &h070307fful 
				else
					valor = udc->up2ocr
				EndIf
			
			case &h24 \ 4 		'UP3OCR
				if (write_) Then 
					udc->up3ocr = valor And 3 
				else
					valor = udc->up3ocr
				EndIf
			
			case else 
				return false 
      End Select

	EndIf
  
	if (write_=0) Then *cast(ULong ptr,buf) = valor
  
	return true 
End Function


Function pxa270UdcInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr) As Pxa270Udc ptr
	dim as Pxa270Udc ptr udc = cast(Pxa270Udc ptr,Callocate(sizeof(Pxa270Udc)) )
	
	if udc=0 Then PERR("cannot alloc UDC")

	memset(udc, 0, sizeof(Pxa270Udc)) 
	
	udc->ic     = ic 
	udc->dma    = dma 
	udc->up2ocr = &h00030000ul 
	
	if memRegionAdd(physMem, PXA_UDC_BASE, PXA_UDC_SIZE, cast(ArmMemAccessF ,@pxa270UdcPrvMemAccessF), udc)=0 Then 
		PERR("cannot add UDC to MEM")
	EndIf
  
	return udc 
End Function
