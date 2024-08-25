'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


#define PXA_UART_SIZE	&h00010000UL

#define UART_FIFO_EMPTY	&hFF

#define UART_IER_DMAE		&h80	'DMA enable
#define UART_IER_UUE			&h40	'Uart unit enable
#define UART_IER_NRZE		&h20	'NRZI enable
#define UART_IER_RTOIE		&h10	'transmit timeout interrupt enable
#define UART_IER_MIE			&h08	'modem interrupt enable
#define UART_IER_RLSE		&h04	'receiver line status interrupt enable
#define UART_IER_TIE			&h02	'transmit data request interrupt enable
#define UART_IER_RAVIE		&h01	'receiver data available interrupt enable

#define UART_IIR_FIFOES		&hC0	'fifo enable status
#define UART_IIR_TOD			&h08	'character timout interrupt pending
#define UART_IIR_RECV_ERR	&h06	'receive error(overrun, parity, framing, break)
#define UART_IIR_RECV_DATA	&h04	'receive data available

#define UART_IIR_RCV_TIMEOUT	&h0C	'receive data in buffer and been a while since we´ve seen more
#define UART_IIR_SEND_DATA		&h02	'transmit fifo requests data
#define UART_IIR_MODEM_STAT	&h00	'modem lines changed state(CTS, DSR, DI, DCD)
#define UART_IIR_NOINT			&h01	'no interrupt pending


#define UART_FCR_ITL_MASK	&hC0	'mask for ITL part of FCR
#define UART_FCR_ITL_1		&h00	'interrupt when >=1 byte in recv fifo
#define UART_FCR_ITL_8		&h40	'interrupt when >=8 byte in recv fifo
#define UART_FCR_ITL_16		&h80	'interrupt when >=16 byte in recv fifo
#define UART_FCR_ITL_32		&hC0	'interrupt when >=32 byte in recv fifo
#define UART_FCR_RESETTF	&h04	'reset tranmitter fifo
#define UART_FCR_RESETRF	&h02	'reset receiver fifo
#define UART_FCR_TRFIFOE	&h01	'transmit and receive fifo enable

#define UART_LCR_DLAB		&h80	'divisor latch access bit
#define UART_LCR_SB			&h40	'send break
#define UART_LCR_STKYP		&h20	'sticky parity (send parity bit but dont care what value)
#define UART_LCR_EPS			&h10	'even parity select
#define UART_LCR_PEN			&h08	'parity enable
#define UART_LCR_STB			&h04	'stop bits (1 = 2, 0 = 1)
#define UART_LCR_WLS_MASK	&h03	'mask for WLS values
#define UART_LCR_WLS_8		&h03	'8 bit words
#define UART_LCR_WLS_7		&h02	'7 bit words
#define UART_LCR_WLS_6		&h01	'6 bit words
#define UART_LCR_WLS_5		&h00	'5 bit words

#define UART_LSR_FIFOE		&h80	'fifo contails an error (framing, parity, or break)
#define UART_LSR_TEMT		&h40	'tranmitter empty (shift reg is empty and no more byte sin fifo\no byte in holding reg)
#define UART_LSR_TDRQ		&h20	'transmitter data request (see docs)
#define UART_LSR_BI			&h10	'send when char at front of fifo (or in holding reg) was a break char (chr reads as zero by itself)
#define UART_LSR_FE			&h08	'same as above, but for framing errors
#define UART_LSR_PE			&h04	'dame as above, but for parity errors
#define UART_LSR_OE			&h02	'recv fifo overran
#define UART_LSR_DR			&h01	'byte received

#define UART_MCR_LOOP		&h10	'loop modem control lines (not full loopback)
#define UART_MCR_OUT2		&h08	'when loop is 0 enables or disables UART interrupts
#define UART_MCR_OUT1		&h04	'force RI to 1
#define UART_MCR_RTS			&h02	'1 -> nRTS is 0
#define UART_MCR_DTR			&h01	'0 -> nDTR is 0

#define UART_MSR_DCD			&h80
#define UART_MSR_RI			&h40
#define UART_MSR_DSR			&h20
#define UART_MSR_CTS			&h10
#define UART_MSR_DDCD		&h08	'dcd changed since last read
#define UART_MSR_TERI		&h04	'ri has changed from 0 to 1 since last read
#define UART_MSR_DDSR		&h02	'dsr changed since last read
#define UART_MSR_DCTS		&h01	'cts changed since last read


Declare Sub socUartPrvRecalc( uart As SocUart Ptr)

Sub socUartPrvIrq(uart As SocUart Ptr , raise As Bool)
	socIcInt(uart->ic, uart->irq, iif ( ((uart->MCR And UART_MCR_LOOP)=0) AndAlso ((uart->MCR And UART_MCR_OUT2)<>0) AndAlso (raise<>0) ,1,0) ) ' only raise if ints are enabled
End Sub

Function socUartPrvDefaultRead( userData As Any Ptr) As Ushort	'these are special funcs since they always get their own userData - the uart pointer :)
	'parametro "userData" no se emplea
	return UART_CHAR_NONE 	'we read nothing..as always
End Function

Sub socUartPrvDefaultWrite(chr_ As Ushort , userData As Any Ptr)	'these are special funcs since they always get their own userData - the uart pointer :)
	' parametros no usados
	'	chr_() 
	'	userData() 
	'nothing to do here
End Sub

Function socUartPrvGetchar(uart As SocUart Ptr) As UShort
	dim as SocUartReadF func = uart->readF 
	'revisar
	Dim As Any Ptr datas = iif(func = @socUartPrvDefaultRead , cast(Any ptr,uart) , uart->accessFuncsData )
	return func(datas) 
End Function

Sub socUartPrvPutchar(uart As SocUart Ptr , chr_ As Ushort)
	dim as SocUartWriteF func = uart->writeF 
	'revisar
	Dim As Any Ptr datas = iif(func = @socUartPrvDefaultWrite , cast(Any ptr,uart) , uart->accessFuncsData )
	func(chr_, datas) 
End Sub

Function socUartPrvFifoUsed(fifo As UartFifo Ptr) As Ubyte	'return num spots used
	Dim As Ubyte v 
	
	if (fifo->read_ = UART_FIFO_EMPTY) Then return 0

	v = fifo->write_ + UART_FIFO_DEPTH - fifo->read_ 
	
	if (v > UART_FIFO_DEPTH) Then v -= UART_FIFO_DEPTH

	return v 
End Function

Sub socUartPrvFifoFlush(fifo As UartFifo Ptr)
	fifo->read_  = UART_FIFO_EMPTY 
	fifo->write_ = UART_FIFO_EMPTY 
End Sub

Function socUartPrvFifoPut(fifo As UartFifo Ptr , valor As Ushort) As Bool	'return success
	if fifo->read_ = UART_FIFO_EMPTY Then   
		fifo->read_  = 0 
		fifo->write_ = 1 
		fifo->buf(0) = valor 	
	ElseIf fifo->read_ <> fifo->write_ Then 'only if not full
		fifo->buf(fifo->write_) = valor 
		fifo->write_+=1
		if (fifo->write_ = UART_FIFO_DEPTH) Then fifo->write_ = 0 
	else
		return false
	EndIf

	return true 
End Function

Function socUartPrvFifoGet(fifo As UartFifo Ptr) As Ushort
	Dim As Ushort ret 
	
	if (fifo->read_ = UART_FIFO_EMPTY) Then 
		ret = &hFFFF 	'why not?
	else
		ret = fifo->buf(fifo->read_) 
		fifo->read_+=1
		if fifo->read_ = UART_FIFO_DEPTH Then fifo->read_ = 0

		if fifo->read_ = fifo->write_ Then 'it is now empty
			fifo->read_ = UART_FIFO_EMPTY 
			fifo->write_= UART_FIFO_EMPTY 
		EndIf
	EndIf
  
	return ret 
End Function

Function socUartPrvFifoPeekNth(fifo As UartFifo Ptr , n As Ubyte) As Ushort
	Dim As Ushort ret 
	
	if (fifo->read_ = UART_FIFO_EMPTY) Then 
		ret = &hFFFF 	'why not?
	else
		n += fifo->read_ 
		if (n >= UART_FIFO_DEPTH) Then n-= UART_FIFO_DEPTH
		ret = fifo->buf(n) 
	EndIf
  
	return ret 
End Function

Function socUartPrvFifoPeek(fifo As UartFifo Ptr) As Ushort
	return socUartPrvFifoPeekNth(fifo, 0) 
End Function

Sub socUartPrvSendChar(uart As SocUart Ptr , v As Ushort)
	if (uart->LSR And UART_LSR_TEMT) Then   			'if transmit, put in shift register immediately if it´s idle
		uart->transmitShift = v 
		uart->LSR And= INV( UART_LSR_TEMT )	
	ElseIf (uart->FCR And UART_FCR_TRFIFOE) Then
   	'put in tx fifo if in fifo mode
		socUartPrvFifoPut(@uart->TX, v) 
		if (socUartPrvFifoUsed(@uart->TX) > UART_FIFO_DEPTH \ 2) Then
			'we go went below half-full buffer - set appropriate bit...
			uart->LSR And= INV( UART_LSR_TDRQ )
		endif
	ElseIf (uart->LSR And UART_LSR_TDRQ) Then
   	'sending without fifo if in polled mode
		uart->transmitHolding = v
		uart->LSR And= INV( UART_LSR_TDRQ )
	else
		'nothing to do - buffer is full so we ignore this request
	EndIf
End Sub

Function socUartPrvMemAccessF( userData As Any Ptr , pa As ULong , size As Ubyte , write_ As Bool , buf As Any Ptr) As Bool
   Dim As SocUart ptr uart = Cast(SocUart ptr,userData )
	dim As Bool DLAB = iif( (uart->LCR And UART_LCR_DLAB) <> 0 ,1 ,0)
	dim As Bool recalcValues = false 
	Dim As Ubyte t, valor = 0 

	if (size <> 4) AndAlso (size <> 1) Then 
		printf(!"%s: Unexpected %s of %u bytes to 0x%08lx\n", "ERROR", iif(write_ , "write" , "read"), size, culng(pa) ) 
		return true 
	EndIf
	
	pa = (pa - uart->baseAddr) Shr 2 
	
	if (write_) Then 
		recalcValues = true 
		valor = iif( size = 1 , *cast(UByte ptr,buf) , *cast(ULong ptr,buf) )

		Select Case As Const (pa)  
			case 0 
				if (DLAB) Then  'if DLAB - set "baudrate"...
					uart->DLL = valor 
					recalcValues = false 
				else
					socUartPrvSendChar(uart, valor) 
				EndIf
			
			case 1 
				if (DLAB) Then 
					uart->DLH = valor 
					recalcValues = false 
				else
					t = uart->IER Xor valor 
					if (t And UART_IER_DMAE) Then 
						'we could support this...later
						PERR("pxaUART: DMA mode cannot be enabled") 
						t And= INV( UART_IER_DMAE )	'undo the change
					EndIf

					if (t And UART_IER_UUE) Then 
						if (valor And UART_IER_UUE) Then 
							uart->LSR = UART_LSR_TEMT Or UART_LSR_TDRQ 
							uart->MSR = UART_MSR_CTS 
						EndIf
					EndIf
					uart->IER Xor= t 
				EndIf
			
			case 2 
				t = uart->FCR Xor valor 
				if (t And UART_FCR_TRFIFOE) Then 
					if (valor And UART_FCR_TRFIFOE) Then 
						'fifos are now on - perform other actions as requested
						if (valor And UART_FCR_RESETRF) Then 
							socUartPrvFifoFlush(@uart->RX) 	'clear the RX fifo now
						EndIf
						if (valor And UART_FCR_RESETTF) Then 
							socUartPrvFifoFlush(@uart->TX) 	'clear the TX fifo now
							uart->LSR = UART_LSR_TEMT Or UART_LSR_TDRQ 
						EndIf
						uart->IIR = UART_IIR_FIFOES Or UART_IIR_NOINT 
					else
						socUartPrvFifoFlush(@uart->TX) 
						socUartPrvFifoFlush(@uart->RX) 
						uart->LSR = UART_LSR_TEMT Or UART_LSR_TDRQ 
						uart->IIR = UART_IIR_NOINT 
					EndIf
				EndIf
				uart->FCR = valor 
			
			case 3 
				t = uart->LCR Xor valor 
				if (t And UART_LCR_SB) Then 
					if (valor And UART_LCR_SB) Then 
						'break set (tx line pulled low)
						'nothing
					else
         			'break cleared (tx line released)
						socUartPrvSendChar(uart, UART_CHAR_BREAK) 
					EndIf
				EndIf
				uart->LCR = valor 
			
			case 4 
				uart->MCR = valor 
			
			case 7 
				uart->SPR = valor 
			
			case 8 
				uart->ISR = valor 
				if (valor And 3) Then 
					MiPrint "UART: IrDA mode set on UART"
				EndIf
     End Select

	else
         
		Select Case As Const (pa)  
			case 0 
				if (DLAB) Then 
					valor = uart->DLL 
				ElseIf (uart->LSR And UART_LSR_DR)=0 Then
					'no data-> too bad
					valor = 0 	
				ElseIf (uart->FCR And UART_FCR_TRFIFOE) Then
					'fifo mode -> read fifo
					valor = socUartPrvFifoGet(@uart->RX) 
					if socUartPrvFifoUsed(@uart->RX)=0 Then 
						uart->LSR And= INV( UART_LSR_DR )
					EndIf
					recalcValues = true 		'error bits might have changed
				else
         		'polled mode -> read rx polled reg
					valor = uart->receiveHolding 
					uart->LSR And= INV( UART_LSR_DR )
				EndIf
			
			case 1 
				if (DLAB) Then 
					valor = uart->DLH 
				else
					valor = uart->IER
				EndIf
			
			case 2 
				valor = uart->IIR 
			
			case 3 
				valor = uart->LCR 
			
			case 4 
				valor = uart->MCR 
			
			case 5 
				valor = uart->LSR 
			
			case 6 
				valor = uart->MSR 
			
			case 7 
				valor = uart->SPR 
			
			case 8 
				valor = uart->ISR 
      End Select

		if (size = 1) Then 
			*cast(UByte ptr,buf) = valor 
		else
			*cast(ULong ptr,buf) = valor
		EndIf
	EndIf

	if (recalcValues) Then socUartPrvRecalc(uart)

	return true 
End Function

Sub socUartSetFuncs(uart As SocUart Ptr , readF As SocUartReadF , writeF As SocUartWriteF , userData As Any Ptr)
	'these are special funcs since they get their own private data - the uart :)
	If (readF =0) Then readF  = cast(SocUartReadF  ,@socUartPrvDefaultRead)
	If (writeF=0) Then writeF = cast(SocUartWriteF ,@socUartPrvDefaultWrite)

	uart->readF  = readF 
	uart->writeF = writeF 
	uart->accessFuncsData = userData 
End Sub

Function socUartInit( physMem As ArmMem Ptr , ic As SocIc Ptr , baseAddr As ULong , irq As UByte) As SocUart ptr
	Dim as SocUart ptr uart = cast(SocUart ptr,Callocate(sizeof(SocUart)) )
	
	if uart=0 Then 
		PERR("cannot alloc UART at "+hex(baseAddr))
	EndIf
  
	memset(uart, 0, sizeof(SocUart)) 
	uart->ic  = ic 
	uart->irq = irq 
	uart->baseAddr = baseAddr 
	uart->IIR = UART_IIR_NOINT 
	uart->IER = UART_IER_UUE  Or UART_IER_NRZE 'uart on
	uart->LSR = UART_LSR_TEMT Or UART_LSR_TDRQ 
	uart->MSR = UART_MSR_CTS 
	socUartPrvFifoFlush(@uart->TX) 
	socUartPrvFifoFlush(@uart->RX) 
	
	socUartSetFuncs(uart, NULL, NULL, NULL) 
	
	if memRegionAdd(physMem, baseAddr, PXA_UART_SIZE, cast(ArmMemAccessF ,@socUartPrvMemAccessF), uart)=0 Then 
		PERR("cannot add UART at to MEM "+hex(baseAddr))
	EndIf
  
	return uart 
End Function


Sub socUartProcess( uart As SocUart Ptr)	'send and rceive up to one character
	Dim as UShort v 
	Dim As UByte t 
	
	'first process sending (if any)
	if (uart->LSR And UART_LSR_TEMT)=0 Then 
		socUartPrvPutchar(uart, uart->transmitShift) 
		if (uart->FCR And UART_FCR_TRFIFOE) Then   	'fifo mode
			t = socUartPrvFifoUsed(@uart->TX) 
			if t Then
				t-=1
				uart->transmitShift = socUartPrvFifoGet(@uart->TX) 
				if t <= (UART_FIFO_DEPTH \ 2) Then uart->LSR Or= UART_LSR_TDRQ 	'above half full - clear TDRQ bit
			else
				uart->LSR Or= UART_LSR_TEMT
			EndIf
		ElseIf (uart->LSR And UART_LSR_TDRQ) Then 
			uart->LSR Or= UART_LSR_TEMT 
		else
			uart->transmitShift = uart->transmitHolding 
			uart->LSR Or= UART_LSR_TDRQ 
		EndIf
	EndIf
  
	'now process receiving
	v = socUartPrvGetchar(uart) 
	if (v <> UART_CHAR_NONE) Then   
		uart->cyclesSinceRecv = 0 
		uart->LSR Or= UART_LSR_DR 
		if (uart->FCR And UART_FCR_TRFIFOE) Then 'fifo mode
			if socUartPrvFifoPut(@uart->RX, v)=0 Then uart->LSR Or= UART_LSR_OE 	
		else
			if (uart->LSR And UART_LSR_DR) Then 
				uart->LSR Or= UART_LSR_OE
			else
				uart->receiveHolding = v
			EndIf
		EndIf
	ElseIf (uart->cyclesSinceRecv <= 4) Then 
		uart->cyclesSinceRecv+=1  
	EndIf
  
	socUartPrvRecalc(uart) 
End Sub

Sub socUartPrvRecalcCharBits( uart As SocUart Ptr , c As UShort)
	if (c And UART_CHAR_BREAK)     Then uart->LSR Or= UART_LSR_BI
	if (c And UART_CHAR_FRAME_ERR) Then uart->LSR Or= UART_LSR_FE
	if (c And UART_CHAR_PAR_ERR)   Then uart->LSR Or= UART_LSR_PE
End Sub

Sub socUartPrvRecalc( uart As SocUart Ptr)
	Dim As Bool errorSet = false 
	dim as UByte v 
	
	uart->LSR And= INV( UART_LSR_FIFOE )
	uart->IIR And= UART_IIR_FIFOES 	'clear all other bits...
	uart->LSR And= INV( UART_LSR_BI Or UART_LSR_FE Or UART_LSR_PE )
	
	if (uart->FCR And UART_FCR_TRFIFOE) Then 'fifo mode
		'check rx fifo for errors
		v=socUartPrvFifoUsed(@uart->RX)
		if v then ' jepalza, el original en C crea un bucle infinito si v=0
			for v = 0 To v-1 
				if ((socUartPrvFifoPeekNth(@uart->RX, v) Shr 8)<>0) AndAlso ((uart->IER And UART_IER_RLSE)<>0) Then 
					uart->LSR Or= UART_LSR_FIFOE 
					uart->IIR Or= UART_IIR_RECV_ERR 
					errorSet = true 
					exit for 
				EndIf
			Next
		endif

		v = socUartPrvFifoUsed(@uart->RX) ' vuelvo a recoger V
		if (v) Then socUartPrvRecalcCharBits(uart, socUartPrvFifoPeek(@uart->RX))

		Select Case As Const (uart->FCR And UART_FCR_ITL_MASK)  
			case UART_FCR_ITL_1 
				v = iif(v >= 1,1,0)
			
			case UART_FCR_ITL_8 
				v = iif(v >= 8,1,0)
			
			case UART_FCR_ITL_16 
				v = iif(v >= 16,1,0) 
			
			case UART_FCR_ITL_32 
				v = iif(v >= 32,1,0) 
      End Select

		if (v<>0) AndAlso ((uart->IER And UART_IER_RAVIE)<>0) AndAlso (errorSet=0) Then 
			errorSet = true 
			uart->IIR Or= UART_IIR_RECV_DATA 
		EndIf
  
		if (socUartPrvFifoUsed(@uart->RX)<>0) AndAlso (uart->cyclesSinceRecv >= 4) AndAlso ((uart->IER And UART_IER_RAVIE)<>0) AndAlso (errorSet=0) Then 
			errorSet = true 
			uart->IIR Or= UART_IIR_RCV_TIMEOUT 	
		endif
		
	else 'polling mode
		
		dim as UShort c = uart->receiveHolding
		if (uart->LSR And UART_LSR_DR) Then 
			socUartPrvRecalcCharBits(uart, c) 
			if ((c Shr 8)<>0) AndAlso (errorSet=0) AndAlso ((uart->IER And UART_IER_RLSE)<>0) Then   
				uart->IIR Or= UART_IIR_RECV_ERR 
				errorSet = true 
			ElseIf (errorSet=0) AndAlso ((uart->IER And UART_IER_RAVIE)<>0) Then
				uart->IIR Or= UART_IIR_RECV_DATA 
				errorSet = true 
			EndIf
		EndIf
	EndIf
	
	if ((uart->LSR And UART_LSR_TDRQ)<>0) AndAlso (errorSet=0) AndAlso ((uart->IER And UART_IER_TIE)<>0) Then 
		errorSet = true 
		uart->IIR Or= UART_IIR_SEND_DATA 
	EndIf
  
	if (errorSet=0) Then uart->IIR Or= UART_IIR_NOINT

	socUartPrvIrq(uart, errorSet) 
End Sub
