'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Sub w86l488PrvRecalcInts(wl As W86L488 Ptr)
	Dim As Bool haveIrq = false 
	
	if (wl->ints And &h0001) Then  'are ints on at all?
		if (wl->ints And (wl->ints Shr 8) And &hf4) Then 'some are in same positions
			haveIrq = true 
		ElseIf ((wl->ints And &h0300)<>0) AndAlso ((wl->ints And &h0002)<>0) Then
 			'BAE and TOE are enabled by the same bit
			haveIrq = true 
		ElseIf (wl->intCdIe<>0) AndAlso (wl->intCdSta<>0) AndAlso ((wl->ctrl And &h10)=0) Then
 			'CD only signalled is SIEN is off
			haveIrq = true 
		ElseIf (wl->intCwrRspIe<>0) AndAlso (wl->intCwrRspSta<>0) AndAlso ((wl->ctrl And &h10)<>0) Then
			'Cwr_RSP_IE only signalled is SIEN is on
			haveIrq = true
		EndIf
	EndIf
  
	socGpioSetState(wl->gpio, wl->intGpio, iif(haveIrq=0,1,0))  'active low
End Sub

Function w86l488PrvGetCurGpioState(wl As W86L488 Ptr) As UByte
	Dim As UByte valor 
	
	'inputs are read inverted!
	valor = (wl->gpioLatches And wl->gpioDirs) Or ( INV(wl->gpiosInput) And INV(wl->gpioDirs) ) 
	valor And= &h1f 
	
	return valor 
End Function

Sub w86l488gpioRecalc(wl As W86L488 Ptr)
	Dim As UByte gpioState = w86l488PrvGetCurGpioState(wl) 
	Dim As UByte gpioDiffs = gpioState Xor wl->gpioPrevStates 
	Dim As UByte gpiosWentLow = gpioDiffs And wl->gpioPrevStates 
	Dim As UByte gpiosCouldIrq = (gpiosWentLow And &h1e) Or (gpioDiffs And &h01) 
	
	wl->gpioPrevStates = gpioState 
	
	wl->gpioIrqSta Or= gpiosCouldIrq And wl->gpioInts 
	
	if (wl->gpioIrqSta) Then wl->ints Or= &h1000 'GIT
	
	w86l488PrvRecalcInts(wl) 
End Sub

Sub w86l488gpioSetVal(wl As W86L488 Ptr , gpioNum As Ulong , hi As Bool)
	if (gpioNum >= 5) Then return
	if (hi) Then 
		wl->gpiosInput Or= (1 Shl gpioNum) 
	else
		wl->gpiosInput And= INV(1 Shl gpioNum)
	EndIf
  
	w86l488gpioRecalc(wl) 
End Sub

static shared As string strIndirect(10) 
		strIndirect(IREG_NO_XTD_STA_AND_SETT) = "STA\SETT"
		strIndirect(IREG_NO_SDIO_CTL) = "SDIO CTRL"
		strIndirect(IREG_NO_MASTER_DATA_FMT) = "M DT FMT"
		strIndirect(IREG_NO_MASTER_BLOCK_CT) = "M BLK CT"
		strIndirect(IREG_NO_SLAVE_DATA_FMT) = "S DT FMT"
		strIndirect(IREG_NO_SLAVE_BLOCK_CT) = "S BLK CT"
		strIndirect(IREG_NO_NAK_TO) = "NAK TO"
		strIndirect(IREG_NO_ERR_STATUS) = "ERR STA"
		strIndirect(IREG_NO_HOST_IFACE) = "HOST IFACE"
		strIndirect(IREG_NO_TEST) = "TEST"
		strIndirect(IREG_NO_ID_CODE) = "ID CODE"
		
Function w86l488PrvIndirectAccess(wl As W86L488 Ptr , write_ As Bool , buf As UShort Ptr) As Bool
	dim As Bool ret = true 
	Dim As ULong valor = 0 

	if (write_) Then valor = *buf

	Select Case As Const (wl->indAddr)  
		case IREG_NO_XTD_STA_AND_SETT 
			if (write_) Then 
				wl->settings = valor And &h0bff 
			else
				valor = wl->settings Or wl->xtdStatus
			EndIf
		
		case IREG_NO_SDIO_CTL 
			if (write_) Then 
				wl->sdio = (wl->sdio And &hffc0) Or (valor And &h003f) 
			else
				valor = wl->sdio
			EndIf
		
		case IREG_NO_MASTER_DATA_FMT 
			if (write_) Then 
				wl->mDataFmt = valor And &hcfff 
			else
				valor = wl->mDataFmt
			EndIf
		
		case IREG_NO_MASTER_BLOCK_CT 
			if (write_) Then 
				wl->mBlockCnt = valor And &h81ff 
			else
				valor = wl->mBlockCnt
			EndIf
		
		case IREG_NO_SLAVE_DATA_FMT 
			if (write_) Then 
				wl->sDataFmt = valor And &h4fff 
			else
				valor = wl->sDataFmt
			EndIf
		
		case IREG_NO_SLAVE_BLOCK_CT 
			if (write_) Then 
				wl->sBlockCnt = valor And &h81ff 
			else
				valor = wl->sBlockCnt
			EndIf
		
		case IREG_NO_NAK_TO 
			if (write_) Then 
				wl->nakTO = valor 
			else
				valor = wl->nakTO
			EndIf
		
		case IREG_NO_ERR_STATUS 
			if (write_) Then 
				ret = false 
			else
				valor = wl->errSta
			EndIf
		
		case IREG_NO_HOST_IFACE 
			if (write_) Then 
				wl->hostIface = valor And &h3f8e 
			else
				valor = (wl->bufSvcLen And &hff00) Or (wl->hostIface And &h008e)
			EndIf
		
		case IREG_NO_TEST 
			if (write_<>0) AndAlso (valor<>0) Then 
				ret = false 
			ElseIf (write_=0) Then
				valor = 0
			EndIf

		case IREG_NO_ID_CODE 
			if (write_) Then 
				ret = false 
			else
				valor = &h488c
			EndIf
		
		case else 
			return false 
   End Select

	printf(!"WL %s i[%02x %10s] == 0x%04lx\n", iif(write_ , "W" , "R"), wl->indAddr, strIndirect(wl->indAddr), culng(valor) )
	
	if (write_=0) Then *buf = valor
	
	return ret 
End Function


Sub w86l488PrvExecCmd(wl As W86L488 Ptr , cmd As UByte , param As ULong)
	dim as SdReplyType ret 
	Dim As UByte reply(16) 
	
	printf(!"cmd %u (0x%08lx)\n", cmd, param) 
	
	wl->sta And= INV( &h3000 )
	
	if (wl->vsd) Then 
		printf(!"sending cmd %u (0x%08lx)\n", cmd And &h3f, param) 
		ret = vsdCommand(wl->vsd, cmd, param, @reply(0)) 
	else
		MiPrint "MMC unit has no SD card - command ignored"
		ret = SdReplyNone 
	EndIf
  
	printf(!"SD says %d\n", ret) 
	wl->xtdStatus And= INV( &h8000 )	'not waiting for reply anymore
	wl->xtdStatus And= INV( &h1000 )	'clock not running (cmd process is over)
	
	Select Case As Const (ret)  
		case SdReplyNone 
			'????
		
		case SdReply48bitsAndBusy , SdReply48bits 
			wl->sta Or= &h1000 
		
		case SdReply136bits 
			wl->sta Or= &h3000 
   End Select

End Sub

Function w86l488PrvCmdW(wl As W86L488 Ptr , valor As UShort) As Bool
	Dim As ULong param 
	Dim As UByte cmd 
	
	wl->cmdBitsCnt+=1
	Select Case As Const (wl->cmdBitsCnt-1) 
		case 0 
			wl->cmdWhi = valor 
		
		case 1 
			wl->cmdWmid = valor 
		
		case 2 
			wl->cmdBitsCnt = 0 
			cmd   = (wl->cmdWhi Shr 8) And &h3f 
			param = wl->cmdWhi And &hff 
			param Shl = 16 
			param Or  = wl->cmdWmid 
			param Shl = 8 
			param Or  = valor Shr 8 
			
			w86l488PrvExecCmd(wl, cmd, param) 
   End Select

	return true 
End Function

Function w86l488PrvFifoW(wl As W86L488 Ptr , valor As UShort) As Bool
	'wl()
	printf(!"FIFO W: 0x%04x\n", valor) 
	
	return false 
End Function

Function w86l488PrvFifoR(wl As W86L488 Ptr , valP As UShort Ptr) As Bool
	'wl()
	MiPrint "FIFO R"
	
	*valP = 0 
	
	return false 
End Function

Function w86l488PrvCtrlW(wl As W86L488 Ptr , valor As UShort) As Bool
	wl->ctrl = valor And &h009f 
	if (valor And &h0100) Then 
  		'S_RST
		wl->cmdBitsCnt = 0
		memset(@wl->resp(0), 0, sizeof(wl->resp)*(ubound(wl->resp)+1)) 
	EndIf
  
	if (valor And &h0040) Then 
  		'DRST_S\DS_RST_S
		'slave logic reset
	EndIf
  
	if (valor And &h0020) Then 
  		'DRST_M
		'master logic reset
	EndIf
  
	'irqs might be affected
	w86l488PrvRecalcInts(wl) 
	return true 
End Function


Static shared As string strDirect(8) 
		strDirect(REG_NO_CMD_RSP) = "CMD\RSP"
		strDirect(REG_NO_STAT_CTRL) = "STAT\CTRL"
		strDirect(REG_NO_RX_TX_FIFO) = "RX\TX FIFO"
		strDirect(REG_NO_INT_STAT_CTRL) = "INT\+CTRL"
		strDirect(REG_NO_GPIO) = "GPIO"
		strDirect(REG_NO_GPIO_IRQ_CTRL) = "GPIO IRQ"
		strDirect(REG_NO_INDIRECT_ADDR) = "IND ADDR"
		strDirect(REG_NO_INDIRECT_DATA) = "IND DATA"
		
Function w86l488PrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   dim as W86L488 ptr wl = cast(W86L488 ptr,userData)
	dim As Bool ret = true 
	Dim As ULong valor = 0 
	
	if(size <> 2) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, pa) 
		return false 
	EndIf
	
	pa = (pa mod W86L488_SIZE) Shr 1 
	
	if (write_) Then 
		valor = *cast(UShort ptr,buf)
	EndIf
  
	Select Case As Const (pa)  
		case REG_NO_CMD_RSP 
			if (write_) Then 
				ret = w86l488PrvCmdW(wl, valor) 
			else
				valor = wl->resp(0)
				memmove(@wl->resp(0) + 0, @wl->resp(0) + 1, (UBound(wl->resp)-0)*sizeof(ushort) ) ' resp=ushort=2bytes
			EndIf
		
		case REG_NO_STAT_CTRL 
			if (write_) Then 
				ret = w86l488PrvCtrlW(wl, valor And &h1ff) 
			else
				valor = (wl->sta And &hff00) Or (wl->ctrl And &h00ff)
			EndIf
		
		case REG_NO_RX_TX_FIFO 
			if (write_) Then 
				ret = w86l488PrvFifoW(wl, valor) 
			else
				ret = w86l488PrvFifoR(wl, cast(ushort ptr,buf) )
			EndIf

		case REG_NO_INT_STAT_CTRL 
			if (write_) Then 
				wl->ints = valor And INV(8)	'CD_IE\Cwr_RSP_IE is special
				if (wl->ctrl And &h10) Then 
					'SIEN set -> Cwr_RSP_IE programmed
					wl->intCwrRspIe = (valor Shr 3) And 1 
				else
       			'SIEN clear -> CD_IE programmed
					wl->intCdIe = (valor Shr 3) And 1
				EndIf
				w86l488PrvRecalcInts(wl) 
			else
				valor = wl->ints And &hfff7 	'CD_IE\Cwr_RSP_IE is special
				if (wl->ctrl And &h10) Then 
					'SIEN set -> Cwr_RSP_IE read
					if (wl->intCwrRspIe ) Then valor Or= &h0008
					if (wl->intCwrRspSta) Then valor Or= &h0800 
				else
         		'SIEN clear -> CD_IE read
					if (wl->intCdIe ) Then valor Or= &h0008
					if (wl->intCdSta) Then valor Or= &h0800
					wl->intCdSta = 0 	'read-clear
				EndIf
			EndIf
		
		case REG_NO_GPIO 
			if (write_) Then 
				wl->gpioDirs = valor And &h1f 
				wl->gpioLatches = (valor Shr 8) And &h1f 
				w86l488gpioRecalc(wl) 
			else
				valor = w86l488PrvGetCurGpioState(wl) 
				valor Or= &h20 	'cause the real chip does this
				valor Shl = 8 
				valor Or= wl->gpioDirs 
			EndIf
		
		case REG_NO_GPIO_IRQ_CTRL 
			if (write_) Then 
				wl->gpioInts = valor And &h1f 
			else
				valor = wl->gpioInts Or (culng(wl->gpioIrqSta) Shl 8) 
				wl->gpioIrqSta = 0 
			EndIf
		
		case REG_NO_INDIRECT_ADDR 
			if (write_) Then 
				wl->indAddr = (valor And &h001e) Shr 1 
			else
				valor = (wl->indAddr Shl 1) And &h001e
			EndIf
		
		case REG_NO_INDIRECT_DATA 
			return iif( w86l488PrvIndirectAccess(wl, write_, cast(UShort ptr,buf)) ,1,0) 

		case else 
			return false 
   End Select

	printf(!"WL %s d[%02lx %10s] == 0x%04lx\n", iif(write_ , "W" , "R"), pa, strDirect(pa), valor) 
	
	if (write_=0) Then 
		*(cast(UShort ptr,buf)) = valor
	EndIf
	
	return ret 
End Function


 
Function w86l488init( physMem As ArmMem Ptr , gpio As SocGpio Ptr , bases As Ulong , vsd As _VSD2 Ptr , intPin As Long) As W86L488 ptr ' intpin:negative for none
	dim as W86L488 ptr wl = cast(W86L488 ptr,Callocate(sizeof(W86L488)) )
	
	if (wl=0) Then PERR("cannot alloc W86L488")

	memset(wl, 0, sizeof(W86L488)) 
	wl->gpio    = gpio 
	wl->vsd     = vsd 
	wl->intGpio = intPin 
	
	wl->ctrl 		= &h0081 
	wl->sta 			= &h0800 
	wl->settings 	= &h0041 
	wl->sdio 		= &hff00 
	wl->mDataFmt 	= &h0200 
	wl->mBlockCnt 	= &h0001 
	wl->sDataFmt 	= &h0200 
	wl->sBlockCnt 	= &h0001 
	wl->nakTO 		= &h7fff 
	wl->gpiosInput = &h19 
	wl->cmdBitsCnt = 0 
	
	if (vsd) Then 
		wl->xtdStatus Or= &h400 
	else
		wl->xtdStatus And= INV( &h400 )
	EndIf
  
	if (vsd) Then 
		'GPIO 0: low when inserted
		wl->gpiosInput And= INV(1 Shl 0) 
	
		'GPIO 1: high when read only
		wl->gpiosInput Or= 1 Shl 1 
		
		'CD bit
		wl->intCdSta = 1 
	EndIf
	
	w86l488PrvRecalcInts(wl) 
	if memRegionAdd(physMem, bases, W86L488_SIZE, cast(ArmMemAccessF ,@w86l488PrvMemAccessF), wl)=0 Then 
		PERR("cannot add W86L488 to MEM")
	EndIf
  
	return wl 
End Function

