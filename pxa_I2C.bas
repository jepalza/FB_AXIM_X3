'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function socI2cDeviceAdd( i2c As SocI2c Ptr , actF As I2cDeviceActionF , userData As Any Ptr) As Bool
	Dim As UByte i 
	
	for i = 0 To ubound(i2c->devs)       
		if (i2c->devs(i).actF) Then continue for
		i2c->devs(i).actF = actF 
		i2c->devs(i).userData = userData 
		return true 
   Next
	
	return false 
End Function


Sub socI2cPrvRecalcIrq( i2c As SocI2c Ptr)
	dim as uLong effectiveIsr = i2c->isr And &h6f0 
	
	if (i2c->icr And &h2000)=0 Then  'SADIE
		effectiveIsr And= INV(1 Shl 9)
	EndIf
  
	if (i2c->icr And &h1000)=0 Then  'ALDIE
		effectiveIsr And= INV(1 Shl 5)
	EndIf
  
	if (i2c->icr And &h0800)=0 Then  'SSDIE
		effectiveIsr And= INV(1 Shl 4)
	EndIf
  	
	if (i2c->icr And &h0400)=0 Then  'BEIE
		effectiveIsr And= INV(1 Shl 10)
	EndIf
  
	if (i2c->icr And &h0200)=0 Then  'IRFIE
		effectiveIsr And= INV(1 Shl 7)
	EndIf
  
	if (i2c->icr And &h0100)=0 Then  'ITEIE
		effectiveIsr And= INV(1 Shl 6)
	EndIf
  
	socIcInt(i2c->ic, i2c->irqNo, NOT_NOT(effectiveIsr) ) 
End Sub

Function socI2cPrvAction( i2c As SocI2c Ptr , action As ActionI2C , param As uByte) As UByte
	Dim As UByte ret = 0, i 
	
	for i = 0 To UBound(i2c->devs)       
		if i2c->devs(i).actF=0 Then continue for
		ret Or= i2c->devs(i).actF(i2c->devs(i).userData, action, param) 
   Next
	
	return ret 
End Function 

Sub socI2cPrvCrW( i2c As SocI2c Ptr , valor As uLong)
	dim as uLong diffBits = i2c->icr Xor valor 
	
	'irq masking & nonactionable bits update
	i2c->icr = valor 
	
	if (valor And &h40)=0 Then return
	
	if (valor And diffBits And &h01) Then 
		socI2cPrvAction(i2c, iif(i2c->isr And 4 , i2cRestart , i2cStart) , 0)
		i2c->waitForAddr = 1 
		i2c->isr Or= &h4 
	EndIf
  
	if (valor And &h08) Then 
		if (i2c->waitForAddr) Then   
			if (i2c->isr And &h40) Then MiPrint "i2c: sending from empty buffer"
			i2c->isr = (i2c->isr And INV(1) ) Or (i2c->db And 1) 
			i2c->isr = (i2c->isr And INV(2) ) Or iif(socI2cPrvAction(i2c, i2cTx, i2c->db) , 0 , 2) 
			i2c->waitForAddr = 0 
			i2c->isr Or= &h40 
		ElseIf (i2c->isr And 1)=0 Then 'TXing
			if (i2c->isr And &h40) Then MiPrint "i2c: sending from empty buffer"
			i2c->isr = (i2c->isr And INV(2) ) Or iif(socI2cPrvAction(i2c, i2cTx, i2c->db) , 0 , 2) 
			i2c->isr Or= &h40 
		else 'RXing
			if (i2c->isr And &h80) Then MiPrint "i2c: recving into full buffer"
			i2c->db = socI2cPrvAction(i2c, i2cRx, iif((i2c->icr And 4)=0,1,0) ) 
			i2c->isr Or= &h80 
			'record ack \ nak we sent
			i2c->isr And= INV( 2 )
			if (i2c->icr And 4) Then i2c->isr Or= 2
		EndIf
  
		if (valor And 2) Then 
			socI2cPrvAction(i2c, i2cStop, 0) 
			i2c->isr And= INV( &h1 )
			i2c->latentBusy = 1 
		EndIf
  
		i2c->icr And= INV( 8 )
	EndIf
  
	if (valor And &h10) Then 
		socI2cPrvAction(i2c, i2cStop, 0) 
		i2c->isr And= INV( &h1 )
		i2c->latentBusy = 1 
	EndIf
  
	socI2cPrvRecalcIrq(i2c) 
End Sub

Function socI2cPrvMemAccessF( userData As Any Ptr , pa As uLong , size As UByte , write_ As Bool , buf As Any Ptr) As Bool
	dim as SocI2c Ptr i2c = cast(SocI2c Ptr,userData )
	dim as uLong valor 
	
	if (size <> 4) Then 
		Print iif(write_ , "WRITE" , "READ");": Unexpected ERROR of ";size;" bytes to &h";hex(pa,8) 
		return false 
	EndIf
  
	pa = (pa - i2c->base_) Shr 2 
	if (pa And 1) Then return false

	pa Shr = 1 
	
	if (write_) Then valor = *cast(ULong ptr,buf)
	
	if (write_<>0) AndAlso (i2c->latentBusy<>0) Then 
		i2c->isr And= INV( 4 )
		i2c->latentBusy = 0 
	EndIf

	Select Case As Const (pa)  
		case REG_IDX_IBMR 
			if(write_) Then return false
			valor = &h03 	'lines are high;
		
		case REG_IDX_IDBR 
			if (write_) Then 
				i2c->isr And= INV( &h40 ) 
				i2c->db = valor 
			else
				valor = i2c->db
			EndIf
			socI2cPrvRecalcIrq(i2c) 
		
		case REG_IDX_ICR 
			if (write_) Then 
				socI2cPrvCrW(i2c, valor) 
				socI2cPrvRecalcIrq(i2c) 
			else
				valor = i2c->icr
			EndIf
		
		case REG_IDX_ISR 
			if (write_) Then 
				i2c->isr And= INV(valor And &h6f0) 
				socI2cPrvRecalcIrq(i2c) 
			else
				valor = i2c->isr
			EndIf
		
		case REG_IDX_ISAR 
			if (write_) Then 
				i2c->isa = valor And &h7f 
			else
				valor = i2c->isa
			EndIf
		
		case else 
			return false 	
   End Select

	if write_=0 Then *cast(ULong ptr,buf) = valor

	return true 
End Function

Function socI2cInit( physMem As ArmMem Ptr , ic As SocIc Ptr , dma As SocDma Ptr , base_ As uLong , irqNo As uLong) As SocI2c ptr
	Dim As SocI2c ptr i2c = cast(SocI2c ptr,Callocate(sizeof(SocI2c)) )
	
	if i2c=0 Then PERR("cannot alloc I2C")
	
	memset(i2c, 0, sizeof(SocI2c)) 
	i2c->dma   = dma 
	i2c->ic    = ic 
	i2c->base_ = base_ 
	i2c->irqNo = irqNo 
	i2c->isr Or= &h40 	'tx empty
	
	if memRegionAdd(physMem, base_, PXA_I2C_SIZE, cast(ArmMemAccessF ,@socI2cPrvMemAccessF), i2c)=0 Then 
		PERR("cannot add I2C to MEM at "+Str(base_))
	EndIf
  
	return i2c 
End Function
