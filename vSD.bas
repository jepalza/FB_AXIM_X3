'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


'this is not and will never be a full SD card emulator, deal with it!

Function vsdIsCardBusy(vsd As _VSD2 Ptr) As Bool
	if (vsd->busyCount=0) Then return FALSE
	vsd->busyCount-=1  
	return true 
End Function

Sub vsdCardReset(vsd As _VSD2 Ptr)
	vsd->expectedBlockSz = 0 
	vsd->expectDataToUs = 0 
	vsd->acmdShift = 0 
	vsd->rca = 0 
	vsd->reportAcmdNext = 0 
	vsd->state = StateIdle 
	vsd->prevAcmd41Param = 0 
	vsd->initWaitLeft = 20 
End Sub

Function vsdCalcR1resp(vsd As _VSD2 Ptr , r1bicBits As ULong , r1orrBits As ULong) As ULong
	Dim As ULong r1 = &h0100 	'ready for data...
	
	r1 Or= culng(vsd->state) Shl 9 
	if (vsd->acmdShift<>0) OrElse (vsd->reportAcmdNext<>0) Then r1 Or= 1 Shl 5
	vsd->reportAcmdNext = 0 
	
	'XXX: "ready for data" bit 8?
	
	r1 And= INV( r1bicBits ) 
	r1 Or = r1orrBits 
	
	return r1 
End Function

Function vsdPrepareR6resp(vsd As _VSD2 Ptr , cmd As UByte , reply As UByte Ptr) As SdReplyType
	Dim As ULong r1 = vsdCalcR1resp(vsd, 0, 0) 
	
	reply[0] = cmd 
	reply[1] = vsd->rca Shr 8 
	reply[2] = vsd->rca 
	reply[3] = (((r1 Shr 22) And 3) Shl 6) Or (((r1 Shr 19) And 1) Shl 5) Or ((r1 Shr 8) And &h1f) 
	reply[4] = r1 
	
	return SdReply48bits 
End Function

Function vsdPrepareR1resp(vsd As _VSD2 Ptr , cmd As UByte , reply As UByte Ptr , r1bicBits As ULong , r1orrBits As ULong) As SdReplyType
	Dim As ULong r1 = vsdCalcR1resp(vsd, r1bicBits, r1orrBits) 
	
	reply[0] = cmd 
	reply[1] = r1 Shr 24 
	reply[2] = r1 Shr 16 
	reply[3] = r1 Shr 8 
	reply[4] = r1 
	
	return SdReply48bits 
End Function

Function vsdRejectCmd(vsd As _VSD2 Ptr , cmd As UByte , param As ULong ,  reply As UByte Ptr , why As RejectReason_enum , wasAcmd As Bool) As SdReplyType
	Dim As ULong r1orr = 1UL Shl 19 	'generic error
	
	printf(!"Rejecting %sCMD%u(0x%08lx)\n", iif(wasAcmd , "A" , ""), cmd, culng(param) ) 
	
	Select Case As Const (why)  
		case InvalidInCurrentState 
			printf(!" -> invalid in current state %u\n", vsd->state) 
			r1orr = 1UL Shl 22 
		
		case UnacceptableParam 
			MiPrint " -> parameter is unacceptable"
			r1orr = 1UL Shl 31 
		
		case UnknownCommand 
			MiPrint " -> unknown command" 
			return SdReplyNone 
		
		case else 
			MiPrint " -> some other reason" 
   End Select

	return vsdPrepareR1resp(vsd, cmd, reply, 0, r1orr) 
End Function

Sub vsdGetCsdV1(vsd As _VSD2 Ptr , reply As UByte Ptr)
	Dim As ULong cSizeMult, cSize, blLen, nSec = vsd->nSec, nShift = 0, sectorSize = 31 	'why not?;
	
	'we need to sort out how to represent the card size. first fit in C_SIZE and get minimum needed shift amount, round up as needed
	while (nSec > &h1000) OrElse (nShift < 2)  
		if (nSec And 1) Then 'round up
			nSec+=1 
		EndIf
		
		nSec Shr = 1 
		nShift+=1  
   Wend
   
	cSize = nSec - 1 
	'then locate the shift bits as needed
	nShift -= 2 	'part of formula
	cSizeMult = iif(nShift > 7 , 7 , nShift )
	nShift -= cSizeMult 
	if (nShift > 1) Then 
		MiPrint "card too big to be a CSD v1 card"
		cSize = 0 
	EndIf
  
	nShift += 9 	'512B is the base unit
	blLen = nShift 
	
	'now we can produce a CSD reg
	reply[ 0] = &h00 
	reply[ 1] = &h0e 					'TAAC
	reply[ 2] = &h00 					'NSAC
	reply[ 3] = &h5A 					'TRAN_SPEED
	reply[ 4] = &h5B 												'CCC[4..11]
	reply[ 5] = blLen Or &h50 									'CCC[0..3], READ_BL_LEN
	reply[ 6] = (cSize Shr 10) Or &h80 						'READ_BL_PARTIAL(1), WRITE_BLK_MISALIGN, READ_BLK_MISALIGN, DSR_IMP, RESERVED, C_SIZE[10..11]
	reply[ 7] = cSize Shr 2 									'C_SIZE[2..9]
	reply[ 8] = (cSize Shl 6) Or &h2D 						'C_SIZE[0..1], VDD_R_CURR_MIN (35mA), VDD_R_CURR_MAX(45mA)
	reply[ 9] = (cSizeMult Shr 1) Or &hD8 					'VDD_W_CURR_MIN (60mA), VDD_W_CURR_MAX(80mA), C_SIZE_MULT[1..2]
	reply[10] = (sectorSize Shr 1) + (cSizeMult Shl 7) 'C_SIZE_MULT[0], ERASE_BLK_EN, SECTOR_SIZE[1..7]
	reply[11] = sectorSize Shl 7 								'SECTOR_SIZE[0], WP_GRP_SIZE
	reply[12] = (blLen Shr 2) Or 8 							'WP_GRP_ENABLE, RESERVED, R2W_FACTOR(2), WRITE_BL_LEN[2..3]
	reply[13] = blLen Shl 6 									'WRITE_BL_LEN[0..1], WRITE_BL_PARTIAL, RESERVED
	reply[14] = &h00 												'FILE_FORMAT_GRP, COPY, PERM_WRITE_PROTECT, TMP_WRITE_PROTECT, FILE_FORMAT, RESERVED
End Sub

Sub vsdGetCsdV2(vsd As _VSD2 Ptr ,  reply As UByte Ptr)
	Dim As ULong cSize = (vsd->nSec + 1023) \ 1024 - 1 	'convert to unit of 512K, sub 1 as per spec
	Dim As ULong writeBlLen = 9  ' hardwired in SDHC
	Dim As ULong sectorSize = 31 ' why not?
	
	reply[ 0] = &h40 					'CSD v2
	reply[ 1] = &h0e 					'TAAC
	reply[ 2] = &h00 					'NSAC
	reply[ 3] = &h5A 					'TRAN_SPEED
	reply[ 4] = &h5B 					'CCC[4..11]
	reply[ 5] = &h59 					'CCC[0..3], READ_BL_LEN
	reply[ 6] = &h00 					'READ_BL_PARTIAL, WRITE_BLK_MISALIGN, READ_BLK_MISALIGN, DSR_IMP, RESERVED[2..5]
	reply[ 7] = cSize Shr 16 		'RESERVED[0..1], C_SIZE[16..21]
	reply[ 8] = cSize Shr 8 		'C_SIZE[8..15]
	reply[ 9] = cSize 						'C_SIZE[0..7]
	reply[10] = sectorSize Shr 1 			'RESERVED, ERASE_BLK_EN, SECTOR_SIZE[1..7]
	reply[11] = sectorSize Shl 7 			'SECTOR_SIZE[0], WP_GRP_SIZE
	reply[12] = (writeBlLen Shr 2) Or 8 'WP_GRP_ENABLE, RESERVED, R2W_FACTOR(2), WRITE_BL_LEN[2..3]
	reply[13] = writeBlLen Shl 6 			'WRITE_BL_LEN[0..1], WRITE_BL_PARTIAL, RESERVED
	reply[14] = &h00 							'FILE_FORMAT_GRP, COPY, PERM_WRITE_PROTECT, TMP_WRITE_PROTECT, FILE_FORMAT, RESERVED
End Sub

Sub vsdGetCsd(vsd As _VSD2 Ptr , reply As UByte Ptr)
	if (vsd->hcCard) Then 
		vsdGetCsdV2(vsd, reply) 
	else
		vsdGetCsdV1(vsd, reply)
	EndIf
End Sub

Function vsdCommand(vsd As _VSD2 Ptr , cmd As UByte , param As ULong , replyOut As Any Ptr) As SdReplyType ' "*replyOut" should be big enough for any reply
	Dim As Bool replNeedsCrc = true, wasAcmd = vsd->acmdShift 
	Dim As UByte ptr reply = cast(UByte ptr,replyOut) 
	dim as SdReplyType replTyp 
	
	vsd->acmdShift = 0 
	reply[0] = cmd 
	
	Select Case As Const  (cmd)  
		case 0 
			vsdCardReset(vsd) 
			replTyp = SdReplyNone 
		
		case 2 
			if (vsd->state <> StateReady) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD2 
			EndIf
			vsd->state = StateIdent 
			goto send_cid 
		
		case 10 
			if (vsd->state <> StateStby) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD10 
			EndIf
			
send_cid: 
			reply[ 0] = cmd 
			reply[ 1] = asc("D") 	'MID
			reply[ 2] = asc("G") 	'OID
			reply[ 3] = asc("r") 
			reply[ 4] = asc(" ") 	'PNM
			reply[ 5] = asc("v") 
			reply[ 6] = asc("S") 
			reply[ 7] = asc("D") 
			reply[ 8] = asc(" ") 
			reply[ 9] = 32 	'PRV
			reply[10] = &h00 	'PSN
			reply[11] = &h00 
			reply[12] = &h4A 
			reply[13] = &hEC 
			reply[14] = 3 		'MDT.month = march
			reply[15] = 20 	'MDT.year = 2020
			replTyp = SdReply136bits 
		
		case 3 
			if (vsd->state <> StateIdent) AndAlso (vsd->state <> StateStby) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD3
			EndIf
			vsd->state = StateStby 
			vsd->rca = 3 
			replTyp = vsdPrepareR6resp(vsd, cmd, reply) 
		
		case 6 
			if (wasAcmd) Then 
				if (vsd->state <> StateTran) Then 
					replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
				else
					replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 'success
				EndIf
			else
				if (vsd->state <> StateTran) Then 
					replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
				else
					vsd->state = StateData 
					'exists, required, but we do not support it in vSD yet
					PERR("CMD6 not implemented") 
				EndIf
			EndIf
		
		case 7 
			if (vsd->state = StateStby) AndAlso (vsd->rca = (param Shr 16)) Then  'were we addressed
				vsd->state = StateTran 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
				if (replTyp = SdReply48bits) Then replTyp = SdReply48bitsAndBusy 
			ElseIf ((vsd->state = StateStby) OrElse (vsd->state = StateTran) _
					  OrElse (vsd->state = StateData) OrElse (vsd->state = StatePrg)) _
					  AndAlso (vsd->rca <> (param Shr 16)) Then
						'we were not addressed
				vsd->state = StateStby 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			else
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD7
			EndIf
		
		case 8 	
			if (vsd->state <> StateIdle) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD8
			EndIf
			if ((param And &hffffff00ul) <> &h100) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, false) ' there is no ACMD8 
			EndIf
			reply[0] = cmd 
			reply[1] = 0 
			reply[2] = 0 
			reply[3] = 1 
			reply[4] = param And &hff 
			replTyp  = SdReply48bits 

		case 9 
			if (vsd->state <> StateStby) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD9 
			EndIf
  
			reply[0] = cmd 
			vsdGetCsd(vsd, reply + 1) 
			replTyp = SdReply136bits 
		
		case 12 
			if (vsd->state <> StateData) AndAlso (vsd->state <> StateRcv) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) 
			else
         	'we do not go busy ever in here
				vsd->state = StateTran 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
		
		case 13 
			if (wasAcmd) Then 
				'XXX: ACMD13 exists
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf         (vsd->state <> StateStby) AndAlso (vsd->state <> StateTran) _
				    AndAlso (vsd->state <> StateData) AndAlso (vsd->state <> StateRcv ) _
					 AndAlso (vsd->state <> StatePrg ) AndAlso (vsd->state <> StateDis ) Then
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			else
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0)
			EndIf
		
		case 16 
			if (wasAcmd) Then   
				' ACMD16 exists but we do not know what it does
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (vsd->state <> StateTran) Then
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (param <> 512) Then
				MiPrint "WE ONLY SUPPORT 512-byte xfers for vSD" 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, wasAcmd) 
			else
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
		
		case 17,18
			if cmd=17 then vsd->haveExpectedNumBlocks = false  'solo case 17
			if (wasAcmd) Then   
				' ACMD17\AMCD18 exist but we do not know what it does
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (vsd->state <> StateTran) Then
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (vsd->hcCard=0) AndAlso ((param mod 512)<>0) Then
   	     'param must be a multiple of 512b for non-HC card
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, wasAcmd) 
			else
				if (vsd->hcCard=0) Then param \= 512
				vsd->curSec = param 
				vsd->state = StateData
				vsd->bufIsData = true 
				vsd->bufContinuous = iif(cmd = 18,1,0) 
				vsd->curBufLen = 512 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
		
		case 23 		'set block count
			if (vsd->state <> StateTran) Then  'CMD23 and ACMD23 both require TRAN state
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf (wasAcmd) Then
   			'ACMD23
				'we do not do any erasing as this is permitted. but we accept the command
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			else 'CMD23
				vsd->haveExpectedNumBlocks = NOT_NOT(param)
				vsd->numBlocksExpected = param 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
		
		case 24,25
			if cmd=24 then vsd->haveExpectedNumBlocks = false 'solo case 24
			if (wasAcmd) Then   
				' ACMD24\AMCD25 exist but we do not know what it does
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (vsd->state <> StateTran) Then
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
			ElseIf  (vsd->hcCard=0) AndAlso ((param mod 512)<>0) Then
				'param must be a multiple of 512b for non-HC card
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, wasAcmd) 
			else
				if (vsd->hcCard=0) Then param \= 512
				vsd->curSec = param 
				vsd->state = StateRcv 
				vsd->bufIsData = true 
				vsd->bufContinuous = iif(cmd = 25,1,0) 
				vsd->curBufLen = 512 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
		
		case 41 
			if (wasAcmd=0) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnknownCommand, wasAcmd) 
				exit select
			endif
  
			if (vsd->state <> StateIdle) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
				exit select
			EndIf
  
			reply[0] = &h3f 
			reply[1] = &h00 	'ocr reg: 0
			reply[2] = &hff 	'ocr reg: 2.8 - 3.6V
			reply[3] = &h80 	'ocr reg: 2.7 - 2.8V
			reply[4] = &h00 	'ocr reg: 0
			reply[5] = &hff 
			replNeedsCrc = false 
			
			replTyp = SdReply48bits 
			vsd->reportAcmdNext = 1 
			if (param And &h00FFFFFFul)=0 Then  'inquiry command
				if (vsd->prevAcmd41Param) Then 'inqury not first ??
					replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, wasAcmd) 
					exit select
				else 'repy to inquiry
					'data already properly in reply[]
				EndIf
			else
				if vsd->prevAcmd41Param=0 Then 
					vsd->prevAcmd41Param = param 
				ElseIf  (vsd->prevAcmd41Param <> param) Then 'param shall be constant
					replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, wasAcmd) 
					exit select
				EndIf

				if (vsd->initWaitLeft) Then 
					vsd->initWaitLeft-=1  
				ElseIf ((param And &h40000000ul)=0) AndAlso (vsd->hcCard<>0) Then
					MiPrint "HC card refusing to init without host-signalled support"
				else
					if (vsd->hcCard) Then reply[1] Or= &h40
					reply[1] Or= &h80 	'inited
					vsd->state = StateReady 
				EndIf
			EndIf
		
		case 51 
			if (wasAcmd=0) Then   
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnknownCommand, wasAcmd) 
				exit select
			ElseIf  (vsd->state <> StateTran) Then
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, wasAcmd) 
				exit select
			else
				'SCR reg
				vsd->curBuf(0) = iif(vsd->hcCard , &h02 , &h01) 		'SCR_STRUCTURE, SD_SPEC
				vsd->curBuf(1) = &h05 							'DATA_STAT_AFTER_ERASE, SD_SECURITY, SD_BUS_WIDTHS
				vsd->curBuf(2) = &h00 							'SD_SPEC3, EX_ SECURITY, SD_SPEC4, SD_SPECX[2..3]
				vsd->curBuf(3) = &h03 							'SD_SPECX[0..1], RESERVED, CMD_SUPPORT (CMD23, CMD20)
				vsd->curBuf(4) = 0 								'rserved for manufacturer
				vsd->curBuf(5) = 0 								'rserved for manufacturer
				vsd->curBuf(6) = 0 								'rserved for manufacturer
				vsd->curBuf(7) = 0 								'rserved for manufacturer
				
				vsd->bufIsData = false 
				vsd->curBufLen = 8 
				
				vsd->state = StateData 
				replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
			EndIf
			
		case 55 
			if (vsd->state = StateReady) OrElse (vsd->state = StateIdent) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, InvalidInCurrentState, false) ' there is no ACMD55 
				exit select
			EndIf

			if ((param Shr 16) <> vsd->rca) Then 
				replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnacceptableParam, false) ' there is no ACMD55
				exit select
			EndIf

			vsd->acmdShift = 1 
			replTyp = vsdPrepareR1resp(vsd, cmd, reply, 0, 0) 
		
		case else 	'send R1 response indicating invalid command
			replTyp = vsdRejectCmd(vsd, cmd, param, reply, UnknownCommand, wasAcmd) 
	
   End Select

	if (replNeedsCrc) Then 
		Select Case As Const  (replTyp)  
			case SdReply48bits , SdReply48bitsAndBusy 
				reply[5] = vsdCRC7(reply, 5) 
			
			case SdReply136bits 
				reply[16] = vsdCRC7(reply, 16) 
			
			case SdReplyNone 
				'nothing
		End Select
	endif
  
	return replTyp 
End Function

Function vsdDataXferBlockToCard(vsd As _VSD2 Ptr , datas As Any Ptr , blockSz As ULong) As SdDataReplyType
	if (vsd->state <> StateRcv) Then 
		MiPrint "transfer to card impossible not in rcv stage"
		return SdDataErrWrongCurrentState 
	EndIf
  
	if (blockSz <> vsd->curBufLen) Then 
		MiPrint "transfer to card impossible with wrong block size"
		return SdDataErrWrongBlockSize 
	EndIf
  
	if (vsd->bufIsData) Then 
		if (vsd->secW(vsd->curSec, datas)=0) Then 
			printf(!"failed to write SD backing store sec %lu\n", vsd->curSec )
			return SdDataErrBackingStore 
		EndIf
  
		vsd->numBlocksExpected-=1 ' debe ir aqui, antes de la comparacion que sigue
		if (vsd->haveExpectedNumBlocks<>0) AndAlso (vsd->numBlocksExpected=0) Then 
			vsd->bufContinuous = false 'end it here
		EndIf

		if (vsd->bufContinuous) Then 
			vsd->curSec+=1  
		else
			vsd->state = StateTran
		EndIf
	else
		'data to be handled here
		MiPrint "unexpected data write"
		return SdDataErrWrongCurrentState 
	EndIf
  
	return SdDataOk 
End Function

Function vsdDataXferBlockFromCard(vsd As _VSD2 Ptr , datas As Any Ptr , blockSz As ULong) As SdDataReplyType
	if (vsd->state <> StateData) Then 
		MiPrint "transfer from card impossible not in data stage"
		return SdDataErrWrongCurrentState 
	EndIf
  
	if (blockSz <> vsd->curBufLen) Then 
		MiPrint "transfer from card impossible with wrong block size" 
		return SdDataErrWrongBlockSize 
	EndIf
	
	if (vsd->bufIsData) Then 
		if (vsd->secR(vsd->curSec, datas)=0) Then 
			printf(!"failed to read SD backing store sec %lu\n", culng(vsd->curSec) )
			return SdDataErrBackingStore 
		EndIf
		vsd->numBlocksExpected-=1 ' debe ir aqui, antes de la comparacion que sigue
		if (vsd->haveExpectedNumBlocks<>0) AndAlso (vsd->numBlocksExpected=0) Then 
			vsd->bufContinuous = false
		EndIf
		
		if (vsd->bufContinuous) Then 
			vsd->curSec+=1  
		else
			vsd->state = StateTran
		EndIf
	else
		memcpy(@datas, @vsd->curBuf(0), blockSz) 
		vsd->state = StateTran 
	EndIf

	return SdDataOk 
End Function



Function vsdInit(sR As SdSectorR , sW As SdSectorW , nSec As Ulong) As _VSD2 ptr
	Dim As _VSD2 ptr vsd = cast(_VSD2 ptr,Callocate(sizeof(_VSD2)) )
	
	if (vsd) Then 
		memset(vsd, 0, sizeof(_VSD2)) 
		
		vsd->secR = sR 
		vsd->secW = sW 
		vsd->nSec = nSec 
		
		vsd->hcCard = nSec > 4194304 	' >2GB cards or more are reported as SDHC
		
		vsdCardReset(vsd) 
	EndIf
  
	return vsd 
End Function

Static Shared As UByte crc7tab(...) = { _
		&h00, &h12, &h24, &h36, &h48, &h5a, &h6c, &h7e, &h90, &h82, &hb4, &ha6, &hd8, &hca, &hfc, &hee, _
		&h32, &h20, &h16, &h04, &h7a, &h68, &h5e, &h4c, &ha2, &hb0, &h86, &h94, &hea, &hf8, &hce, &hdc, _
		&h64, &h76, &h40, &h52, &h2c, &h3e, &h08, &h1a, &hf4, &he6, &hd0, &hc2, &hbc, &hae, &h98, &h8a, _
		&h56, &h44, &h72, &h60, &h1e, &h0c, &h3a, &h28, &hc6, &hd4, &he2, &hf0, &h8e, &h9c, &haa, &hb8, _
		&hc8, &hda, &hec, &hfe, &h80, &h92, &ha4, &hb6, &h58, &h4a, &h7c, &h6e, &h10, &h02, &h34, &h26, _
		&hfa, &he8, &hde, &hcc, &hb2, &ha0, &h96, &h84, &h6a, &h78, &h4e, &h5c, &h22, &h30, &h06, &h14, _
		&hac, &hbe, &h88, &h9a, &he4, &hf6, &hc0, &hd2, &h3c, &h2e, &h18, &h0a, &h74, &h66, &h50, &h42, _
		&h9e, &h8c, &hba, &ha8, &hd6, &hc4, &hf2, &he0, &h0e, &h1c, &h2a, &h38, &h46, &h54, &h62, &h70, _
		&h82, &h90, &ha6, &hb4, &hca, &hd8, &hee, &hfc, &h12, &h00, &h36, &h24, &h5a, &h48, &h7e, &h6c, _
		&hb0, &ha2, &h94, &h86, &hf8, &hea, &hdc, &hce, &h20, &h32, &h04, &h16, &h68, &h7a, &h4c, &h5e, _
		&he6, &hf4, &hc2, &hd0, &hae, &hbc, &h8a, &h98, &h76, &h64, &h52, &h40, &h3e, &h2c, &h1a, &h08, _
		&hd4, &hc6, &hf0, &he2, &h9c, &h8e, &hb8, &haa, &h44, &h56, &h60, &h72, &h0c, &h1e, &h28, &h3a, _
		&h4a, &h58, &h6e, &h7c, &h02, &h10, &h26, &h34, &hda, &hc8, &hfe, &hec, &h92, &h80, &hb6, &ha4, _
		&h78, &h6a, &h5c, &h4e, &h30, &h22, &h14, &h06, &he8, &hfa, &hcc, &hde, &ha0, &hb2, &h84, &h96, _
		&h2e, &h3c, &h0a, &h18, &h66, &h74, &h42, &h50, &hbe, &hac, &h9a, &h88, &hf6, &he4, &hd2, &hc0, _
		&h1c, &h0e, &h38, &h2a, &h54, &h46, &h70, &h62, &h8c, &h9e, &ha8, &hba, &hc4, &hd6, &he0, &hf2  _
	} 
Function vsdCRC7( datas As UByte Ptr , sz As ULong) As UByte
	Dim As UByte crc = 0 

	while sz
		sz-=1
		crc = crc7tab(crc Xor (*datas) )
		datas+=1
   Wend
     
	return crc + 1 
End Function
