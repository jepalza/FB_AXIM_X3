'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


#define ARM_MODE_2_REG	&h0F
#define ARM_MODE_2_WORD	&h10
#define ARM_MODE_2_LOAD	&h20
#define ARM_MODE_2_T		&h40
#define ARM_MODE_2_INV	&h80

#define ARM_MODE_3_REG	&h0F	'flag for actual reg number used
#define ARM_MODE_3_TYPE	&h30	'flag for the below 4 types
#define ARM_MODE_3_H		&h00
#define ARM_MODE_3_SH	&h10
#define ARM_MODE_3_SB	&h20
#define ARM_MODE_3_D		&h30
#define ARM_MODE_3_LOAD	&h40
#define ARM_MODE_3_INV	&h80

#define ARM_MODE_4_REG	&h0F
#define ARM_MODE_4_INC	&h10	'incr or decr
#define ARM_MODE_4_BFR	&h20	'before or after
#define ARM_MODE_4_WBK	&h40	'writeback?
#define ARM_MODE_4_S		&h80	'S bit set?

#define ARM_MODE_5_REG			&h0F
#define ARM_MODE_5_IS_OPTION	&h10	'is value option (as opposed to offset)
#define ARM_MODE_5_RR			&h20	'MCRR or MRCC instrs



#define REG_NO_SP		13
#define REG_NO_LR		14
#define REG_NO_PC		15




'	coprocessors:
'				
'				0    - DSP (pxa only)
'				0, 1 - WMMX (pxa only)
'				11   - VFP (arm standard)
'				15   - system control (arm standard)

Function cpuPrvClz(valor As ULong) As ULong
	beep : print "cpuPrvClz sin revisar":sleep
	return 32 ' revisar
	'if (valor=0) Then return 32
	'if sizeof(Short)    = sizeof(ULong) Then return __builtin_clz(valor)
	'if sizeof(long)     = sizeof(ULong) Then return __builtin_clzl(valor)
	'if sizeof(ULOngInt) = sizeof(ULong) Then return __builtin_clzll(valor)
	'PERR("CLZ undefined") 
End Function

Function cpuPrvROR(valor As ULong , rors As Ubyte) As ULong
	if (rors) Then 
		valor = (valor Shr rors) Or (valor Shl (32 - rors))
	EndIf
  
	return valor 
End Function

Sub cpuPrvSetPC(cpu As ArmCpu Ptr , pc As ULong)	'with interworking
	cpu->regs(REG_NO_PC) = pc And INV( 1UL )
	cpu->T = (pc And 1) 

	if (cpu->T=0) AndAlso ((pc And 2)<>0) Then 
		PERR("Attempt to branch to non-word-aligned ARM address")
	EndIf
End Sub

Function cpuPrvGetRegNotPC(cpu As ArmCpu Ptr , reg As Ubyte , wasT As Bool , specialPC As Bool) As ULong
	return cpu->regs(reg) 
End Function

Function cpuPrvGetReg(cpu As ArmCpu Ptr , reg As Ubyte , wasT As Bool , specialPC As Bool) As ULong
	Dim As ULong ret 

	ret = cpu->regs(reg) 
	if (reg = REG_NO_PC) Then 
  
		ret += iif(wasT , 2 , 4) 
		if (wasT<>0) AndAlso (specialPC<>0) Then 
			ret And= INV(3UL)
		EndIf
	
	EndIf
  
	return ret 
End Function

Sub cpuPrvSetRegNotPC(cpu As ArmCpu Ptr , reg As Ubyte , valor As ULong)
	cpu->regs(reg) = valor 
End Sub

Sub cpuPrvSetReg(cpu As ArmCpu Ptr , reg As Ubyte , valor As ULong)
	if (reg = REG_NO_PC) Then 
		cpuPrvSetPC(cpu, valor) 
	else
		cpuPrvSetRegNotPC(cpu, reg, valor)
	EndIf
End Sub

Function cpuPrvModeToBankedRegsPtr( cpu As ArmCpu Ptr , mode As ubyte) As ArmBankedRegs ptr
	Select Case As Const  (mode)  
		case ARM_SR_MODE_USR , ARM_SR_MODE_SYS 
			return @cpu->bank_usr 
		
		case ARM_SR_MODE_FIQ 
			return @cpu->bank_fiq 
		
		case ARM_SR_MODE_IRQ 
			return @cpu->bank_irq 
		
		case ARM_SR_MODE_SVC 
			return @cpu->bank_svc 
		
		case ARM_SR_MODE_ABT 
			return @cpu->bank_abt 
			
		case ARM_SR_MODE_UND 
			return @cpu->bank_und 
		
		case else 
			PERR("Invalid mode passed to cpuPrvModeToBankedRegsPtr()") 
			return NULL 
   End Select
End Function

Sub cpuPrvSwitchToMode(cpu As ArmCpu Ptr , newMode As ubyte)
	dim as ArmBankedRegs ptr saveTo, getFrom 
	dim as ubyte i, curMode 
	Dim As ULong tmp 
	
	curMode = cpu->M 
	if (curMode = newMode) Then exit sub
	
	if (curMode = ARM_SR_MODE_FIQ) OrElse (newMode = ARM_SR_MODE_FIQ) Then 
  	  'bank\unbank the fiq regs
		for i = 0 To 4         
			tmp = cpu->extra_regs(i) 
			cpu->extra_regs(i) = cpu->regs(i + 8) 
			cpu->regs(i + 8) = tmp 
      Next
	EndIf
	
	saveTo  = cpuPrvModeToBankedRegsPtr(cpu, curMode) 
	getFrom = cpuPrvModeToBankedRegsPtr(cpu, newMode) 

  	'we´re done if no regs to switch [this happens if we switch user<->system]
	if (saveTo = getFrom) Then exit sub
	
	saveTo->R13 = cpu->regs(REG_NO_SP) 
	saveTo->R14 = cpu->regs(REG_NO_LR) 
	saveTo->SPSR = cpu->SPSR 
	
	cpu->regs(REG_NO_SP) = getFrom->R13 
	cpu->regs(REG_NO_LR) = getFrom->R14 
	cpu->SPSR = getFrom->SPSR 
	
	cpu->M = newMode 
End Sub

Sub cpuPrvSetPSRlo8(cpu As ArmCpu Ptr , valor As Ubyte)
	cpuPrvSwitchToMode(cpu, valor And ARM_SR_M) 
	cpu->T = NOT_NOT(valor And ARM_SR_T) 
	cpu->F = NOT_NOT(valor And ARM_SR_F) 
	cpu->I = NOT_NOT(valor And ARM_SR_I) 
End Sub

Sub cpuPrvSetPSRhi8(cpu As ArmCpu Ptr , valor As ULong)
	cpu->N = NOT_NOT(valor And ARM_SR_N) 
	cpu->Z = NOT_NOT(valor And ARM_SR_Z) 
	cpu->C = NOT_NOT(valor And ARM_SR_C) 
	cpu->V = NOT_NOT(valor And ARM_SR_V) 
	cpu->Q = NOT_NOT(valor And ARM_SR_Q) 
End Sub

Function cpuPrvMaterializeCPSR(cpu As ArmCpu Ptr) As ULong
	Dim As ULong ret = 0 
	
	if cpu->N Then ret Or= ARM_SR_N
	if cpu->Z Then ret Or= ARM_SR_Z
	if cpu->C Then ret Or= ARM_SR_C
	if cpu->V Then ret Or= ARM_SR_V
	if cpu->Q Then ret Or= ARM_SR_Q
	if cpu->T Then ret Or= ARM_SR_T
	if cpu->I Then ret Or= ARM_SR_I
	if cpu->F Then ret Or= ARM_SR_F
  
	ret Or= cpu->M 

	return ret 
End Function

Function cpuGetRegExternal(cpu As ArmCpu Ptr , reg As Ubyte) As ULong
	if (reg < 16) Then 	' real reg
		return iif(reg = REG_NO_PC , (cpu->curInstrPC + iif(cpu->T , 1 , 0)) , cpu->regs(reg) )
	ElseIf (reg = ARM_REG_NUM_CPSR) Then
		return cpuPrvMaterializeCPSR(cpu) 
	ElseIf (reg = ARM_REG_NUM_SPSR) Then
		return cpu->SPSR 	
	else
		return 0
	EndIf
End Function

Sub cpuSetReg(cpu As ArmCpu Ptr , reg As Ubyte , valor As ULong)
	if (reg = ARM_REG_NUM_CPSR) Then   
		cpuPrvSetPSRlo8(cpu, valor) 
		cpuPrvSetPSRhi8(cpu, valor) 
	ElseIf (reg < 16) Then
		cpuPrvSetReg(cpu, reg, valor)
	EndIf
End Sub

Sub cpuPrvException(cpu As ArmCpu Ptr , vector_pc As ULong , lr As ULong , newLowBits As Ubyte)	'enters arm mode
	Dim As ULong spsr = cpuPrvMaterializeCPSR(cpu) 
	
	cpuPrvSetPSRlo8(cpu, newLowBits) 
	cpu->SPSR = spsr 
	cpu->regs(REG_NO_LR) = lr 
	cpu->regs(REG_NO_PC) = vector_pc 
End Sub

'input addr is VA not MVA
Sub cpuPrvHandleMemErr(cpu As ArmCpu Ptr , addr As ULong , sz As Ubyte , write_ As Bool , instrFetch As Bool , fsr As Ubyte)
	'FCSE
	if (addr < &h02000000UL) Then 
		'report addr is MVA
		addr Or= cpu->pid
	EndIf
	
	cp15SetFaultStatus(cpu->cp15, addr, fsr) 

	if (instrFetch) Then 
		'handle prefetch abort (LR is addr of aborted instr_ + 4)
		cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_P_ABT, cpu->curInstrPC + 4, ARM_SR_MODE_ABT Or ARM_SR_I) 
	else
		'handle data abort (LR is addr of aborted instr_ + 8)
		cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_D_ABT, cpu->curInstrPC + 8, ARM_SR_MODE_ABT Or ARM_SR_I) 
	EndIf
  
End Sub

Function cpuPrvArmAdrMode_1(cpu As ArmCpu Ptr , instr_ As ULong , carryOutP As Bool Ptr , wasT As Bool , specialPC As Bool) As ULong
	Dim As Ubyte v, a 
	dim As Bool co = iif(cpu->C,1,0)	'be default carry out = C flag
	Dim As ULong ret 

	if (instr_ And &h02000000UL) Then  'immed
		v = (instr_ Shr 7) And &h1E 
		ret = cpuPrvROR(instr_ And &hFF, v) 
		if v Then co = NOT_NOT(ret And &h80000000UL) 
	else  
		v = (instr_ Shr 5) And 3 'get shift type
		ret = cpuPrvGetReg(cpu, instr_ And &h0F, wasT, specialPC) 	'get Rm
	
		if (instr_ And &h00000010UL) Then 'reg with reg shift
			a = cpuPrvGetRegNotPC(cpu, (instr_ Shr 8) And &h0F, wasT, specialPC) 	'get the relevant part of Rs, we only care for lower 8 bits (note we use uint8 for this)
			
			if (a <> 0) Then  'else all is already good
				Select Case As Const (v)  'perform shifts
					case 0 	'LSL
						if (a < 32) Then   
							co = (ret Shr (32 - a)) And 1 
							ret = ret Shl a 
						ElseIf (a = 32) Then ' >32
							co = ret And 1 
							ret = 0
						else
							co = 0 
							ret = 0 
						EndIf
					
					case 1 	'LSR
						if (a < 32) Then   
							co = (ret Shr (a - 1)) And 1 
							ret = ret Shr a 
						ElseIf (a = 32) Then
							co = ret Shr 31 
							ret = 0 
						else ' >32
							co = 0 
							ret = 0 
						EndIf
						
					case 2 	'ASR
						if (a < 32) Then 
							co = (ret Shr (a - 1)) And 1 
							ret = (clng(ret) Shr a)
						else ' >=32
							if (ret And &h80000000UL) Then 
								co = 1 
								ret = &hFFFFFFFFUL 
							else
								co = 0 
								ret = 0 
							EndIf
						EndIf
						
					case 3 	'ROR
						if (a = 0) Then 
							'nothing...
						else
							a And= &h1F 
							if (a = 0) Then 
								co = ret Shr 31 
							else
								co = (ret Shr (a - 1)) And 1 
								ret = cpuPrvROR(ret, a) 
							EndIf
						EndIf
            End Select
			end if

		else ' reg with immed shift

			a = (instr_ Shr 7) And &h1F 'get imm
			Select Case As Const (v)  
				case 0 	'LSL
					if (a = 0) Then 
						'nothing
					else
						co = (ret Shr (32 - a)) And 1 
						ret = ret Shl a 
					EndIf
				
				case 1 	'LSR
					if (a = 0) Then 
						co = ret Shr 31 
						ret = 0 
					else
						co = (ret Shr (a - 1)) And 1 
						ret = ret Shr a 
					EndIf
				
				case 2 	'ASR
					if (a = 0) Then 
						if (ret And &h80000000UL) Then 
							co = 1 
							ret = &hFFFFFFFFUL 
						else
							co = 0 
							ret = 0 
						EndIf
					else
						co = (ret Shr (a - 1)) And 1 
						if (ret And &h80000000UL) Then 
							ret = (ret Shr a) Or (&hFFFFFFFFUL Shl (32 - a)) 
						else
							ret = ret Shr a
						EndIf
					EndIf
  
				case 3 	'ROR or RRX
					if (a = 0) Then  'RRX
						a = co 
						co = ret And 1 
						ret = ret Shr 1 
						if (a) Then 
							ret Or= &h80000000UL 
						endif
					else
						co = (ret Shr (a - 1)) And 1
						ret = cpuPrvROR(ret, a) 
					EndIf
         End Select

		EndIf
 
	EndIf
  
	*carryOutP = co 
	return ret 
End Function


'idea:
'
'addbefore is what to add to add to base reg before addressing, 
'addafter is what to add after. we ALWAYS do writeback, 
'but if not requested by instr_, it will be zero
'
'for [Rx, 5]   baseReg = x addbefore = 5 addafter = -5
'for [Rx, 5]!  baseReg = x addBefore = 0 addafter = 0
'for [Rx], 5   baseReg = x addBefore = 0 addAfter = 5
'
't = T bit (LDR vs LDRT)
'
'baseReg is returned in return valor along with flags:
'
'ARM_MODE_2_REG	is mask for reg
'ARM_MODE_2_WORD	is flag for word access
'ARM_MODE_2_LOAD	is flag for load
'ARM_MODE_2_INV	is flag for invalid instructions
'ARM_MODE_2_T	is flag for T

Function cpuPrvArmAdrMode_2(cpu As ArmCpu Ptr , instr_ As ULong , addBeforeP As ULong Ptr , addWritebackP As ULong Ptr , wasT As Bool , specialPC As Bool) As Ubyte
	Dim As Ubyte reg, shifts 
	Dim As ULong valor 

	reg = (instr_ Shr 16) And &h0F 

	if (instr_ And &h02000000UL)=0 Then  'immediate
		valor = instr_ And &hFFFUL '[scaled] register
	else
		if (instr_ And &h00000010UL) Then reg Or= ARM_MODE_2_INV 'invalid instructions need to be reported
		
		valor = cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 
		shifts = (instr_ Shr 7) And &h1F 
		Select Case As Const ((instr_ Shr 5) And 3)  
			case 0 		'LSL
				valor Shl = shifts 
			
			case 1 		'LSR
				valor = iif(shifts , (valor Shr shifts) , 0 )
			
			case 2 		'ASR
				valor = iif(shifts , culng(clng(valor) Shr shifts) , iif(valor And &h80000000UL , &hFFFFFFFFUL , &h00000000UL) )
			
			case 3 		'ROR\RRX
				if (shifts) Then 
					valor = cpuPrvROR(valor, shifts) 'RRX
				else
					valor = valor Shr 1 
					if (cpu->C) Then valor Or= &h80000000UL
				EndIf
      End Select

	EndIf
  
	if (instr_ And &h00400000UL)=0 Then reg Or= ARM_MODE_2_WORD
	if (instr_ And &h00100000UL)   Then reg Or= ARM_MODE_2_LOAD
	if (instr_ And &h00800000UL)=0 Then valor = -valor
	
	if (instr_ And &h01000000UL)=0 Then   
		*addBeforeP = 0 
		*addWritebackP = valor 
		 if (instr_ And &h00200000UL) Then reg Or= ARM_MODE_2_T 
	ElseIf (instr_ And &h00200000UL) Then
		*addBeforeP = valor 
		*addWritebackP = valor 
	else
		*addBeforeP = valor 
		*addWritebackP = 0 
	EndIf
	
	return reg 
End Function



'same comments as for addr mode 2 apply
'#define ARM_MODE_3_REG	0x0F	\\flag for actual reg number used
'#define ARM_MODE_3_TYPE	0x30	\\flag for the below 4 types
'#define ARM_MODE_3_H	0x00
'#define ARM_MODE_3_SH	0x10
'#define ARM_MODE_3_SB	0x20
'#define ARM_MODE_3_D	0x30
'#define ARM_MODE_3_LOAD	0x40
'#define ARM_MODE_3_INV	0x80
Function cpuPrvArmAdrMode_3(cpu As ArmCpu Ptr , instr_ As ULong , addBeforeP As ULong Ptr , addWritebackP As ULong Ptr , wasT As Bool , specialPC As Bool) As Ubyte
	Dim As Ubyte reg 
	Dim As ULong valor 
	dim As Bool S, H, L 

	reg = (instr_ Shr 16) And &h0F 
	
	if (instr_ And &h00400000UL) Then  'immediate
		valor = ((instr_ Shr 4) And &hF0) Or (instr_ And &h0F) 
	else
		if (instr_ And &h00000F00UL) Then reg Or= ARM_MODE_3_INV 'bits 8-11 must be 1 always
		valor = cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 
	EndIf
  
	L = NOT_NOT(instr_ And &h00100000UL) 
	H = NOT_NOT(instr_ And &h00000020UL) 
	S = NOT_NOT(instr_ And &h00000040UL) 
	
	if (S<>0) AndAlso (H<>0) Then 
		reg Or= ARM_MODE_3_SH 
	ElseIf (S) Then
		reg Or= ARM_MODE_3_SB 
	ElseIf (H) Then
		reg Or= ARM_MODE_3_H 
	else
		reg Or= ARM_MODE_3_INV 'S = 0 andalso H = 0 is invalid mode 3 operation
	EndIf
  	
	if ((instr_ And &h00000090UL) <> &h00000090UL) Then reg Or= ARM_MODE_3_INV 'bits 4 and 7 must be 1 always
	
	if (S<>0) AndAlso (L=0) Then  'LDRD\STRD is encoded thusly
		reg = (reg And INV(ARM_MODE_3_TYPE)) Or ARM_MODE_3_D 
		L = iif(H=0,1,0) 
	EndIf
  
	if L Then reg Or= ARM_MODE_3_LOAD
  
	if (instr_ And &h00800000UL)=0 Then valor = -valor
  
	if (instr_ And &h01000000UL)=0 Then   
		*addBeforeP = 0 
		*addWritebackP = valor 
		if  (instr_ And &h00200000UL) Then reg Or= ARM_MODE_3_INV 	'W must be 0 in this case, else unpredictable (in this case - invalid instr)
	ElseIf (instr_ And &h00200000UL) Then
		*addBeforeP = valor 
		*addWritebackP = valor 
	else
		*addBeforeP = valor 
		*addWritebackP = 0 
	EndIf
  
	return reg 
End Function


'#define ARM_MODE_4_REG	0x0F
'#define ARM_MODE_4_INC	0x10	\\incr or decr
'#define ARM_MODE_4_BFR	0x20	\\after or before
'#define ARM_MODE_4_WBK	0x40	\\writeback?
'#define ARM_MODE_4_S	0x80	\\S bit set?
Function cpuPrvArmAdrMode_4(cpu As ArmCpu Ptr , instr_ As ULong , usesUsrRegs As Bool , regs As Ushort Ptr) As Ubyte
	Dim As Ubyte reg 
	
	*regs = instr_ And &hffff 
	
	reg = (instr_ Shr 16) And &h0F 
	if (instr_ And &h00400000UL) AndAlso (usesUsrRegs=0) Then 
		'real hw ignores "S" in modes that use user mode regs
		reg Or= ARM_MODE_4_S
	EndIf
  
	if (instr_ And &h00200000UL) Then reg Or= ARM_MODE_4_WBK
	if (instr_ And &h00800000UL) Then reg Or= ARM_MODE_4_INC
	if (instr_ And &h01000000UL) Then reg Or= ARM_MODE_4_BFR
	
	return reg 
End Function


'#define ARM_MODE_5_REG			0x0F
'#define ARM_MODE_5_IS_OPTION	0x10	\\is value option (as opposed to offset)
'#define ARM_MODE_5_RR			0x20	\\MCRR or MRCC instrs
Function cpuPrvArmAdrMode_5(cpu As ArmCpu Ptr , instr_ As ULong , addBeforeP As ULong Ptr , addAfterP As ULong Ptr , optionValP As UByte Ptr) As Ubyte
	Dim As Ubyte reg 
	Dim As ULong valor 
	
	valor = instr_ And &hFF 
	reg  = (instr_ Shr 16) And &h0F 
	
	*addBeforeP = 0 
	*addAfterP  = 0 
	*optionValP = 0 
	
	if (instr_ And &h01000000UL)=0 Then  'unindexed or postindexed
		if (instr_ And &h00200000UL) Then  'postindexed
			*addAfterP = valor 'unindexed
		else
			if (instr_ And &h00800000UL)=0 Then 
				reg Or= ARM_MODE_5_RR 'U must be 1 for unindexed, else it is MCRR\MRCC
			EndIf
			*optionValP = valor 
		EndIf
  
	else 'offset or preindexed
	
		*addBeforeP = valor 
		if (instr_ And &h00200000UL) Then  'preindexed
			*addAfterP = valor
		EndIf
  
	EndIf
  
	if (reg And ARM_MODE_5_IS_OPTION)=0 Then 
		if (instr_ And &h00800000UL)=0 Then 
			*addBeforeP = -*addBeforeP 
			*addAfterP  = -*addAfterP 
		EndIf
	EndIf
  
	return reg 
End Function

Sub cpuPrvSetPSR(cpu As ArmCpu Ptr , mask As Ubyte , privileged As Bool , R As Bool , valor As ULong)
	if (R) Then 
		'setting SPSR in sys or usr mode is no harm since they arent used, so just do it without any checks
		cpu->SPSR = valor 
	else
		if (privileged<>0) AndAlso ((mask And 1)<>0) Then cpuPrvSetPSRlo8(cpu, valor)
		if (mask And 8) Then cpuPrvSetPSRhi8(cpu, valor)
	EndIf
  
End Sub

Function cpuPrvSignedAdditionOverflows(a As Long , b As Long , sum As Long) As Bool
	Dim As Long c 
	return __builtin_add_overflow_i32(a, b, @c) 
End Function

Function cpuPrvSignedSubtractionOverflows(a As Long , b As Long , diff As Long) As Bool 'diff = a - b
	Dim As Long c 
	return __builtin_sub_overflow_i32(a, b, @c) 
End Function

Function cpuPrvMedia_signedSaturate32(sign As Long) As Long
	return iif(sign < 0 , -&h80000000UL , &h7ffffffful )
End Function

Function cpuPrvMemOpEx(cpu As ArmCpu Ptr , buf As Any Ptr , vaddr As ULong , size As Ubyte , write_ As Bool , priviledged As Bool , fsrP As Ubyte Ptr , memAccessFlags As Ubyte) As Bool
	Dim As ULong pa 
	
	'gdbStubReportMemAccess(cpu->debugStub, vaddr, size, write_) 
	
	if (size And (size - 1)) Then 
		'size is not a power of two
		if (fsrP) Then *fsrP = 1 'alignment fault
		return false 
	EndIf

	if (vaddr And (size - 1)) Then  'bad alignment
		if (fsrP) Then *fsrP = 1 'alignment fault
		return false 
	EndIf
  
	'FCSE
	if (vaddr < &h02000000UL) Then 
		vaddr Or= cpu->pid
	EndIf
  
	if mmuTranslate(cpu->mmu, vaddr, priviledged, write_, @pa, fsrP, NULL)=0 Then 
		return false
	EndIf
	
	if memAccess(cpu->mem, pa, size, memAccessFlags Or iif(write_ , MEM_ACCESS_TYPE_WRITE , MEM_ACCESS_TYPE_READ), buf)=0 Then 
		if (fsrP) Then *fsrP = 10 'external abort on non-linefetch
		return false 
	EndIf
  
	return true 
End Function

'for internal use
Function cpuPrvMemOp(cpu As ArmCpu Ptr , buf As Any Ptr , vaddr As ULong , size As Ubyte , write_ As Bool , priviledged As Bool , fsrP As Ubyte Ptr) As Bool
	if cpuPrvMemOpEx(cpu, buf, vaddr, size, write_, priviledged, fsrP, 0) Then 
		return true
	EndIf

	return false 
End Function

'for external use
Function cpuMemOpExternal(cpu As ArmCpu Ptr , buf As Any Ptr , vaddr As ULong , size As Ubyte , write_ As Bool) As Bool	'for external use
	return cpuPrvMemOpEx(cpu, buf, vaddr, size, write_, true, NULL, MEM_ACCCESS_FLAG_NOERROR) 
End Function


Function cpuPrv64FromHalves(hi As ULongInt , lo As ULong) As ULongInt
	'better than shifting in almost all compilers
		union t
			' LITTLE_ENDIAN PC
			type
				As ULong lo 
				As ULong hi 
			end type
			as ulongint valor 
		end union
		
		dim t_ as t
		t_.hi = hi
		t_.lo = lo
		
		return t_.valor
End Function

Function cpuPrvSignedSubtractionWithPossibleCarryOverflows(a As ULong , b As ULong , diff As ULong) As Bool	'diff = a - b
	return IIF( (((a Xor b) And (a Xor diff)) Shr 31)<>0 ,1,0)
End Function


Function cpuPrvSignedAdditionWithPossibleCarryOverflows(a As ULong , b As ULong , sum As ULong) As Bool
	return IIF( (((a Xor b Xor &h80000000UL) And (a Xor sum)) Shr 31)<>0 ,1,0)
End Function




' variable temporal mia, borrar tras depurar
DIM SHARED  as long ins_
Sub cpuPrvExecInstr(cpu As ArmCpu Ptr , instr_ As ULong , wasT As Bool , privileged As Bool , specialPC As Bool)
	Dim As ULong op1, op2, res, sr, ea, memVal32, addBefore, addAfter
	Dim As Bool specialInstr = false, ok
	Dim As UByte mode, cpNo, fsr
	Dim As ushort regsList
	Dim As ushort memVal16
	Dim As ubyte memVal8
	Dim As ulongint res64

ins_=instr_ ' PARA MIS TRAMPAS, BORRAR AL ACABAR JUNTO A SU DIM ARRIBA

	Select Case As Const (instr_ Shr 28)  
		case 0 		'EQ
			if (cpu->Z=0) Then Exit Sub
		
		case 1 		'NE
			if (cpu->Z) Then Exit Sub
		
		case 2 		'CS
			if (cpu->C=0) Then Exit Sub
		
		case 3 		'CC
			if (cpu->C) Then Exit Sub
		
		case 4 		'MI
			if (cpu->N=0) Then Exit Sub
		
		case 5 		'PL
			if (cpu->N) Then Exit Sub
		
		case 6 		'VS
			if (cpu->V=0) Then Exit Sub
		
		case 7 		'VC
			if (cpu->V) Then Exit Sub
		
		case 8 		'HI
			if (cpu->C=0) OrElse (cpu->Z<>0) Then Exit Sub
		
		case 9 		'LS
			if (cpu->C<>0) AndAlso (cpu->Z=0) Then Exit Sub
		
		case 10 	'GE
			if (cpu->N <> cpu->V) Then Exit Sub
		
		case 11 	'LT
			if (cpu->N = cpu->V) Then Exit Sub
		
		case 12 	'GT
			if (cpu->Z<>0) OrElse (cpu->N <> cpu->V) Then Exit Sub
		
		case 13 	'LE
			if (cpu->Z=0) AndAlso (cpu->N = cpu->V) Then Exit Sub
		
		case 14 	'AL
			' nada por aqui 
		
		case 15 	'NV
			specialinstr = true 

			Select Case As Const ((instr_ Shr 24) And &h0f)  
				case 5,7 
					'PLD
					if ((instr_ And &h0D70F000UL) = &h0550F000UL) Then Exit Sub ' instruccion OK, salimos
					print "GOTO invalid_instr 1 " : goto invalid_instr
				
				case 10,11 
					goto b_bl_blx 
				
				case 12,13 
					goto coproc_mem_2reg 
				
				case 14 
					goto coproc_dp 
				
				case else 
					print "GOTO invalid_instr 2 " : goto invalid_instr
			
			End Select
   End Select

	Select Case As Const ((instr_ Shr 24) And &h0F)  
		case 0 , 1 'data processing immediate shift, register shift and misc instrs and mults
			if ((instr_ And &h00000090UL) = &h00000090) Then 'multiplies, extra load\stores (table 3.2)
				if ((instr_ And &h00000060UL) = &h00000000) Then 'swp[b], mult(acc), mult(acc) long
					if (instr_ And &h01000000UL) Then 'SWB\SWPB
						Select Case As Const ((instr_ Shr 20) And &h0F)  
							case 0 		'SWP
								ea = cpuPrvGetRegNotPC(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @memVal32, ea, 4, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 4, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								op1 = memVal32 
								memVal32 = cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @memVal32, ea, 4, true, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 4, true, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, op1) 
							
							case 4 		'SWPB
								ea = cpuPrvGetRegNotPC(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @memVal8, ea, 1, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 1, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								op1 = memVal8 
								memVal8 = cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @memVal8, ea, 1, true, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 1, true, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, op1) 

							case else 
								print "GOTO invalid_instr 3" : goto invalid_instr 
						End Select

					else
									
						Select Case As Const ((instr_ Shr 20) And &h0F) 'multiplies
							case 0,1 'MUL
								res = 0 
								if (instr_ And &h0000F000UL) Then print "GOTO invalid_instr 4" : goto invalid_instr
								goto mul32 
							
							case 2,3 'MLA
								res  = cpuPrvGetRegNotPC(cpu, (instr_ Shr 12 ) And &h0F, wasT, specialPC) 
mul32:
								res += cpuPrvGetRegNotPC(cpu, (instr_ Shr 8  ) And &h0F, wasT, specialPC) * _
										 cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res) 
								if (instr_ And &h00100000UL) Then 'S
									cpu->Z = iif(res=0,1,0) ' revisar res=0->1, resto casos=0 
									cpu->N =(res Shr 31) and 1
								EndIf
								Exit Sub ' instruccion OK, salimos 

							case 	8,_ 		'UMULL
									9,_ 
									12,_ 		'SMULL
									13 
								res64 = 0 
								goto mul64 
								
							case 	10,_ 		'UMLAL
									11,_ 
									14,_ 		'SMLAL
									15
								res64  = cpuPrv64FromHalves(cpuPrvGetRegNotPC(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC), _
																	 cpuPrvGetRegNotPC(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC)) 
mul64: 				
								op1 = cpuPrvGetRegNotPC(cpu, (instr_ Shr 8) And &h0F, wasT, specialPC) 
								op2 = cpuPrvGetRegNotPC(cpu,  instr_        And &h0F, wasT, specialPC) 
								
								if (instr_ And &h00400000UL) Then 
									res64 += clngint(clng(op1)) * clngint(clng(op2)) 
								else
									res64 += culngint(culng(op1)) * culngint(culng(op2))
								EndIf
								
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, res64) 
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res64 Shr 32) 
								
								if (instr_ And &h00100000UL) Then 'S
									cpu->Z = iif(res64=0,1,0) 'revisar res64=0->1, resto de casos=0
									cpu->N = (res64 Shr 63) and 1
								EndIf
							
							case else 
								print "GOTO invalid_instr 5" : goto invalid_instr 

					   End Select
					endif
				 
				else ' load\store signed\unsigned byte\halfword\two_words
				
					Dim As ULong doubleMem(1) ' 0 y 1
					
					mode = cpuPrvArmAdrMode_3(cpu, instr_, @addBefore, @addAfter, wasT, specialPC) 
					ea = cpuPrvGetReg(cpu, mode And ARM_MODE_3_REG, wasT, specialPC) 
					ea += addBefore 
					
					if (mode And ARM_MODE_3_LOAD) Then 
						Select Case As Const  (mode And ARM_MODE_3_TYPE)  
							case ARM_MODE_3_H 
								ok = cpuPrvMemOp(cpu, @memVal16, ea, 2, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 2, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, memVal16) 
								
							case ARM_MODE_3_SH 
								ok = cpuPrvMemOp(cpu, @memVal16, ea, 2, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 2, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, clng(cshort(memVal16)) ) 
							
							case ARM_MODE_3_SB 
								ok = cpuPrvMemOp(cpu, @memVal8, ea, 1, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 1, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, clng(cbyte(memVal8)) ) 
							case ARM_MODE_3_D 
								ok = cpuPrvMemOp(cpu, @doubleMem(0), ea, 8, false, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 8, false, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								cpuPrvSetRegNotPC(cpu, ((instr_ Shr 12) And &h0F) + 0, doubleMem(0)) 
								cpuPrvSetRegNotPC(cpu, ((instr_ Shr 12) And &h0F) + 1, doubleMem(1)) 
                  End Select

					else
         
						Select Case As Const (mode And ARM_MODE_3_TYPE)  
							case ARM_MODE_3_H 
								memVal16 = cpuPrvGetReg(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @memVal16, ea, 2, true, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 2, true, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
								
							case ARM_MODE_3_SH , ARM_MODE_3_SB 
								print "GOTO invalid_instr 6" : goto invalid_instr 
								
							case ARM_MODE_3_D 
								doubleMem(0) = cpuPrvGetRegNotPC(cpu, ((instr_ Shr 12) And &h0F) + 0, wasT, specialPC) 
								doubleMem(1) = cpuPrvGetRegNotPC(cpu, ((instr_ Shr 12) And &h0F) + 1, wasT, specialPC) 
								ok = cpuPrvMemOp(cpu, @doubleMem(0), ea, 8, true, privileged, @fsr) 
								if (ok=0) Then 
									cpuPrvHandleMemErr(cpu, ea, 8, true, false, fsr) 
									Exit Sub ' instruccion OK, salimos 
								EndIf
						End Select
						
					EndIf
  
					if (addAfter) Then 
						cpuPrvSetRegNotPC(cpu, mode And ARM_MODE_3_REG, ea - addBefore + addAfter)
					EndIf

				EndIf
  
				Exit Sub ' instruccion OK, salimos 
			 
			ElseIf ((instr_ And &h01900000UL) = &h01000000UL) Then  'misc instrs (table 3.3)
					
				Select Case As Const ((instr_ Shr 4) And &h0F)  
					case 0 		'move reg to PSR or move PSR to reg
						if ((instr_ And &h00BF0FFFUL) = &h000F0000UL) Then   		'move PSR to reg
							'access in user and sys mode is undefined. for us that means returning garbage that is currently in "cpu->SPSR"
							cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, iif(instr_ And &h00400000UL , cpu->SPSR , cpuPrvMaterializeCPSR(cpu)) ) 
						ElseIf ((instr_ And &h00B0FFF0UL) = &h0020F000UL) Then 'move reg to PSR
							cpuPrvSetPSR(cpu, (instr_ Shr 16) And &h0F, privileged, NOT_NOT(instr_ And &h00400000UL), cpuPrvGetReg(cpu, instr_ And &h0F, wasT, specialPC)) 
						else
							print "GOTO invalid_instr 7" : goto invalid_instr
						EndIf
						Exit Sub ' instruccion OK, salimos 
				
					case 1,_ 	'BLX\BX\BXJ or CLZ
					     3 
						if (instr_ And &h00400000UL) Then  'CLZ
							cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, cpuPrvClz(cpuPrvGetRegNotPC(cpu, instr_ And &hF, wasT, specialPC))) 
						else 'BL \ BLX \ BXJ
							if ((instr_ And &h0FFFFF00UL) <> &h012FFF00UL) Then  print "GOTO invalid_instr 8" : goto invalid_instr
							if ((instr_ And &h00000030UL) =  &h00000030UL) Then 
								cpuPrvSetRegNotPC(cpu, REG_NO_LR, cpu->curInstrPC + iif(wasT , 3 , 4)) 'save return value for BLX
							EndIf
							cpuPrvSetPC(cpu, cpuPrvGetReg(cpu, instr_ And &h0F, wasT, specialPC)) 
						EndIf
						Exit Sub ' instruccion OK, salimos 
					
					case 5 'enhanced DSP adds\subtracts
						if (instr_ And &h00000F00UL) Then print "GOTO invalid_instr 9" : goto invalid_instr
  
						op1 = cpuPrvGetRegNotPC(cpu, instr_ And &h0F, wasT, specialPC) 'Rm
						op2 = cpuPrvGetRegNotPC(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 'Rn
						Select Case As Const ((instr_ Shr 21) And 3)  		'what op?
							case 0 			'QADD
								res = op1 + op2 
								if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op1) 
								EndIf
							
							case 1 			'QSUB
								res = op1 - op2 
								if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op1) 
								EndIf
  
							case 2 			'QDADD
								res = op2 + op2 
								if (cpuPrvSignedAdditionOverflows(op2, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op2) 
								EndIf
								op2 = res 
								res = op1 + op2 
								if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op1) 
								EndIf
							
							case 3 			'QDSUB
								res = op2 + op2 
								if (cpuPrvSignedAdditionOverflows(op2, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op2) 
								EndIf
								op2 = res 
								
								res = op1 - op2 
								if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then 
									cpu->Q = 1 
									res = cpuPrvMedia_signedSaturate32(op1) 
								EndIf
							
							case else 
								'__builtin_unreachable() 
								res = 0 
						
                  End Select

						cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, res) 
						Exit Sub ' instruccion OK, salimos 
						
					case 7 'soft breakpoint
						cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_P_ABT, cpu->curInstrPC + 4, ARM_SR_MODE_ABT Or ARM_SR_I) 
						Exit Sub ' instruccion OK, salimos 
					
					case 8 to 15 'enhanced DSP multiplies 					
						if ((instr_ And &h00000090UL) <> &h00000080UL) Then print "GOTO invalid_instr 10" : goto invalid_instr

						op1 = cpuPrvGetRegNotPC(cpu,  instr_        And &h0F, wasT, specialPC) 			'Rm
						op2 = cpuPrvGetRegNotPC(cpu, (instr_ Shr 8) And &h0F, wasT, specialPC) 	'Rs
						Select Case As Const ((instr_ Shr 21) And 3)  		'what op?
							case 0 			'SMLAxy
								if (instr_ And &h00000020UL) Then
									op1 Shr = 16 
								else
									op1 = cushort(op1)
								EndIf

								if (instr_ And &h00000040UL) Then 
									op2 Shr = 16 
								else
									op2 = cushort(op2)
								EndIf
								
								res = clng(cshort(op1)) * clng(cshort(op2)) 
								op1 = res 
								op2 = cpuPrvGetRegNotPC(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC) 	'Rn
								res = op1 + op2 
								if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then 
									cpu->Q = 1
								EndIf
  
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res) 
							
							case 1 			'SMLAWy\SMULWy
								if (instr_ And &h00000040UL) Then 
									op2 Shr = 16 
								else
									op2 = cushort(op2)
								EndIf

								res = ( clngint(clng(op1)) * clngint(cshort(op2)) ) Shr 16 
								
								if (instr_ And &h00000020UL) Then  'SMULWy
									if (instr_ And &h0000F000UL) Then print "GOTO invalid_instr 11" : goto invalid_instr 
								else 'SMLAWy
									op1 = res
									op2 = cpuPrvGetRegNotPC(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC) 	'Rn
									res = op1 + op2 
									if (cpuPrvSignedAdditionOverflows(op1, op2, res)) Then cpu->Q = 1
								EndIf
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res) 
								
							case 2 			'SMLALxy
								if (instr_ And &h00000020UL) Then
									op1 Shr = 16 
								else
									op1 = cushort(op1)
								EndIf

								if (instr_ And &h00000040UL) Then 
									op2 Shr = 16 
								else
									op2 = cushort(op2)
								EndIf
								
								res64 = cpuPrv64FromHalves(cpuPrvGetRegNotPC(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC), _
								                           cpuPrvGetRegNotPC(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC)) 
								res64 += clng(cshort(op1)) * clng(cshort(op2)) 
								
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, res64) 
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res64 Shr 32) 
								
							case 3 			'SMULxy
								if (instr_ And &h0000F000UL) Then  print "GOTO invalid_instr 12" : goto invalid_instr
								if (instr_ And &h00000020UL) Then 
									op1 Shr = 16 
								else
									op1 = cushort(op1)
								EndIf

								if (instr_ And &h00000040UL) Then 
									op2 Shr = 16 
								else
									op2 = cushort(op2)
								EndIf
								
								res = clng(cshort(op1)) * clng(cshort(op2)) 
								cpuPrvSetRegNotPC(cpu, (instr_ Shr 16) And &h0F, res) 
						End Select
						Exit Sub ' instruccion OK, salimos 
						
					case else 
						print "GOTO invalid_instr 13" : goto invalid_instr 
            End Select
			EndIf

			goto data_processing 
			
		case 2,3 		'data process immediate val, move imm to SR
			
data_processing:
		 
			dim As Bool cOut, setFlags = NOT_NOT(instr_ And &h00100000UL) 
			
			op2 = cpuPrvArmAdrMode_1(cpu, instr_, @cOut, wasT, specialPC) 

			Select Case As Const  ((instr_ Shr 21) And &h0F)  
				case 0 			'AND
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 And op2 
				
				case 1 			'EOR
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 Xor op2 
				
				case 2 			'SUB
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 - op2
					if (setFlags) Then 
						cpu->V = cpuPrvSignedSubtractionOverflows(op1, op2, res) 
						cOut = iif(__builtin_sub_overflow_u32(op1, op2, @res)=0,1,0)
					EndIf
				
				case 3 			'RSB
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op2 - op1
					if (setFlags) Then 
						cpu->V = cpuPrvSignedSubtractionOverflows(op2, op1, res) 
						cOut = iif(__builtin_sub_overflow_u32(op2, op1, @res)=0,1,0) 
					EndIf
				
				case 4 			'ADD
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 + op2 
					if (setFlags) Then 
						cpu->V = cpuPrvSignedAdditionOverflows(op1, op2, res) 
						cOut = iif(__builtin_add_overflow_u32(op1, op2, @res),1,0)
					EndIf
			
				case 5 			'ADC
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res64 = Culngint(op1) + op2 + iif(cpu->C , 1 , 0) 
					res = res64
					if (setFlags) Then  'hard to get this right in C in 32 bits so go to 64...
						cOut = iif(res64 Shr 32,1,0) 
						cpu->V = cpuPrvSignedAdditionWithPossibleCarryOverflows(op1, op2, res) 
						cpu->V = iif( ((res64 Shr 31) = 1) OrElse ((res64 Shr 31) = 2) ,1,0) 
					EndIf
				
				case 6 			'SBC
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res64 = Culngint(op1) - op2 - iif(cpu->C , 0 , 1) 
					res = res64
					if (setFlags) Then  'hard to get this right in C in 32 bits so go to 64...
						cOut = iif((res64 Shr 32)=0,1,0)
						cpu->V = cpuPrvSignedSubtractionWithPossibleCarryOverflows(op1, op2, res) 
					EndIf
			
				case 7 			'RSC
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res64 = Culngint(op2) - op1 - iif(cpu->C , 0 , 1) 
					res = res64
					if (setFlags) Then  'hard to get this right in C in 32 bits so go to 64...
						cOut = iif((res64 Shr 32)=0,1,0)
						cpu->V = cpuPrvSignedSubtractionWithPossibleCarryOverflows(op2, op1, res) 
					EndIf
				
				case 8 			'TST
					if (setFlags=0) Then print "GOTO invalid_instr 14" : goto invalid_instr
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 And op2 
					goto dp_flag_set 
				
				case 9 			'TEQ
					if (setFlags=0) Then  'MSR CPSR, imm
						cpuPrvSetPSR(cpu, (instr_ Shr 16) And &h0F, privileged, false, cpuPrvROR(instr_ And &hFF, ((instr_ Shr 8) And &h0F) * 2)) 
						Exit Sub ' instruccion OK, salimos 
					EndIf
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 Xor op2 
					goto dp_flag_set 
				
				case 10 		'CMP
					if (setFlags=0) Then  print "GOTO invalid_instr 15" : goto invalid_instr
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 - op2 
					cpu->V = cpuPrvSignedSubtractionOverflows(op1, op2, res) 
					cOut = iif(__builtin_sub_overflow_u32(op1, op2, @res)=0,1,0) 
					goto dp_flag_set 
				
				case 11 		'CMN
					if (setFlags=0) Then  'MSR SPSR, imm
						cpuPrvSetPSR(cpu, (instr_ Shr 16) And &h0F, privileged, true, cpuPrvROR(instr_ And &hFF, ((instr_ Shr 8) And &h0F) * 2)) 
						Exit Sub ' instruccion OK, salimos 
					EndIf
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 + op2 
					cpu->V = cpuPrvSignedAdditionOverflows(op1, op2, res) 
					cOut = iif(__builtin_add_overflow_u32(op1, op2, @res),1,0) 
					goto dp_flag_set 
				
				case 12 		'ORR
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 or op2
				
				case 13 		'MOV
					res = op2 
				
				case 14 		'BIC
					op1 = cpuPrvGetReg(cpu, (instr_ Shr 16) And &h0F, wasT, specialPC) 
					res = op1 And INV( op2 )
				
				case 15 		'MVN
					res = INV( op2 )
				
				case else 
					'__builtin_unreachable() 
					res = 0 
		
			End Select
			
			if (setFlags=0) Then 										'simple store
				cpuPrvSetReg(cpu, (instr_ Shr 12) And &h0F, res) 
			ElseIf (((instr_ Shr 12) And &h0F) = REG_NO_PC) Then
				'copy SPSR to CPSR. we allow in user mode too - allowed and faster
				sr = cpu->SPSR 
				cpuPrvSetPSRlo8(cpu, sr) 
				cpuPrvSetPSRhi8(cpu, sr) 
				cpu->regs(REG_NO_PC) = res 	'do it right here - if we let it use cpuPrvSetReg, it will check lower bit...
			else 'store and set flags
				cpuPrvSetReg(cpu, (instr_ Shr 12) And &h0F, res) 
dp_flag_set: 
				cpu->C = iif(cOut,1,0) 
				cpu->N = iif(res Shr 31,1,0) 
				cpu->Z = iif(res=0,1,0)
			EndIf
  
			Exit Sub ' instruccion OK, salimos 

		case 4 , 5 		'load\store imm offset
			goto load_store_mode_2 
		
		case 6 , 7 		'load\store reg offset
			if (instr_ And &h00000010UL) Then  'media and undefined instrs
				print "GOTO invalid_instr 16" : goto invalid_instr
			EndIf
  
load_store_mode_2:
	 
			mode = cpuPrvArmAdrMode_2(cpu, instr_, @addBefore, @addAfter, wasT, specialPC) 
			if (mode And ARM_MODE_2_INV) Then print "GOTO invalid_instr 17" : goto invalid_instr
			if (mode And ARM_MODE_2_T)   Then privileged = false

			ea = cpuPrvGetReg(cpu, mode And ARM_MODE_2_REG, wasT, specialPC) 
			ea += addBefore 
			
			if (mode And ARM_MODE_2_LOAD) Then 
				if (mode And ARM_MODE_2_WORD) Then 
					ok = cpuPrvMemOp(cpu, @memVal32, ea, 4, false, privileged, @fsr) 
					if (ok=0) Then 
						cpuPrvHandleMemErr(cpu, ea, 4, false, false, fsr) 
						Exit Sub ' instruccion OK, salimos 
					EndIf
					cpuPrvSetReg(cpu, (instr_ Shr 12) And &h0F, memVal32) 
				else
					ok = cpuPrvMemOp(cpu, @memVal8, ea, 1, false, privileged, @fsr) 
					if (ok=0) Then 
						cpuPrvHandleMemErr(cpu, ea, 1, false, false, fsr) 
						Exit Sub ' instruccion OK, salimos 
					EndIf
					cpuPrvSetRegNotPC(cpu, (instr_ Shr 12) And &h0F, memVal8) 
				EndIf

			else
				
				op1 = cpuPrvGetReg(cpu, (instr_ Shr 12) And &h0F, wasT, specialPC) 
				if (mode And ARM_MODE_2_WORD) Then 
					memVal32 = op1 
					ok = cpuPrvMemOp(cpu, @memVal32, ea, 4, true, privileged, @fsr) 
					if (ok=0) Then 
						cpuPrvHandleMemErr(cpu, ea, 4, true, false, fsr) 
						Exit Sub ' instruccion OK, salimos 
					endif
				else
					memVal8 = op1
					ok = cpuPrvMemOp(cpu, @memVal8, ea, 1, true, privileged, @fsr) 
					if (ok=0) Then 
						cpuPrvHandleMemErr(cpu, ea, 1, true, false, fsr) 
						Exit Sub ' instruccion OK, salimos 
					EndIf
				EndIf
				
			EndIf
	  
			if (addAfter) Then 
				cpuPrvSetRegNotPC(cpu, mode And ARM_MODE_2_REG, ea - addBefore + addAfter)
			EndIf
	  
			Exit Sub ' instruccion OK, salimos 

		case 8 , 9 		'load\store multiple
			dim As Bool  userModeRegs = false, copySPSR = false, isLoad = NOT_NOT(instr_ And &h00100000UL) 
			Dim As ULong loadedPc = &hfffffffful, origBaseRegvalor 	'so we can restore on load failure, even if we loaded into it
			Dim As Ubyte idx, regNo 
			
			mode = cpuPrvArmAdrMode_4(cpu, instr_, iif((cpu->M = ARM_SR_MODE_USR) OrElse (cpu->M = ARM_SR_MODE_SYS),1,0), @regsList) 
			ea = cpuPrvGetRegNotPC(cpu, mode And ARM_MODE_4_REG, wasT, specialPC) 
			origBaseRegvalor = ea
			if (mode And ARM_MODE_4_S) Then  'sort out what "S" means
				if (isLoad<>0) AndAlso ((regsList And (1 Shl REG_NO_PC))<>0) Then 
					copySPSR = true 
				else
					userModeRegs = true
				EndIf
			EndIf

			for idx = 0 To 15         
				regNo = iif(mode And ARM_MODE_4_INC , idx , 15 - idx) 
				if (regsList And (1 Shl regNo))=0 Then continue for

				'if this is a store, get the value to store
				if (isLoad=0) Then 
					memVal32 =  cpuPrvGetReg(cpu, regNo, wasT, specialPC) 
					if (userModeRegs) Then 
						if (regNo >= 8) AndAlso (regNo <= 12) AndAlso (cpu->M = ARM_SR_MODE_FIQ) Then 	'handle fiq\usr banked regs
							memVal32 = cpu->extra_regs(regNo - 8) 
						ElseIf (regNo = REG_NO_SP) Then
							memVal32 = cpu->bank_usr.R13 
						ElseIf (regNo = REG_NO_LR) Then
							memVal32 = cpu->bank_usr.R14
						EndIf
					EndIf
				EndIf
				'perform mem op
				if (mode And ARM_MODE_4_BFR) Then 
					ea += iif(mode And ARM_MODE_4_INC , 4 , -4)
				EndIf

				ok = cpuPrvMemOp(cpu, @memVal32, ea, 4, iif(isLoad=0,1,0), privileged, @fsr) 
				if (ok=0) Then 
					cpuPrvHandleMemErr(cpu, ea, 4, iif(isLoad=0,1,0), false, fsr) 
					if (regsList And (1 Shl (mode And ARM_MODE_4_REG))) Then 
						'restore base if we had already overwritten it
						cpuPrvSetReg(cpu, mode And ARM_MODE_4_REG, origBaseRegvalor)
					EndIf
					Exit Sub ' instruccion OK, salimos 
				EndIf

				if (mode And ARM_MODE_4_BFR)=0 Then 
					ea += iif(mode And ARM_MODE_4_INC , 4 , -4)
				EndIf
				
				'if this is a load, store the value we just loaded
				if (isLoad) Then 
					if (userModeRegs) Then 
						if (regNo >= 8) AndAlso (regNo <= 12) AndAlso (cpu->M = ARM_SR_MODE_FIQ) Then   	'handle fiq\usr banked regs
							cpu->extra_regs(regNo - 8) = memVal32 
							continue for
						ElseIf (regNo = REG_NO_SP) Then
							cpu->bank_usr.R13 = memVal32 
							continue for
						ElseIf (regNo = REG_NO_LR) Then
							cpu->bank_usr.R14 = memVal32 
							continue for
						EndIf
					EndIf

					if (regNo = REG_NO_PC) AndAlso (copySPSR<>0) Then
						loadedPc = memVal32 
					else
						cpuPrvSetReg(cpu, regNo, memVal32)
					EndIf
				EndIf
			Next
			
			if (mode And ARM_MODE_4_WBK) Then 
				cpuPrvSetRegNotPC(cpu, mode And ARM_MODE_4_REG, ea)
			EndIf

			if (copySPSR) Then 
				sr = cpu->SPSR 
				cpuPrvSetPSRlo8(cpu, sr) 
				cpuPrvSetPSRhi8(cpu, sr) 
				cpu->regs(REG_NO_PC) = loadedPc 	'direct write - yes
				if (cpu->T) Then 
					cpu->regs(REG_NO_PC) And= INV(1) 
				else
					cpu->regs(REG_NO_PC) And= INV(3)
				EndIf
			EndIf
			Exit Sub ' instruccion OK, salimos 

		case 10 ,11 	'B\BL\BLX(if cond=0b1111)
b_bl_blx: 
			ea = instr_ Shl 8 
			ea = clng(ea) Shr 7 
			ea += 4 
			if (wasT=0) Then ea Shl = 1
			ea += cpu->curInstrPC
			if (specialInstr) Then 'handle BLX
				if (instr_ And &h01000000UL) Then ea += 2
				cpu->regs(REG_NO_LR) = cpu->curInstrPC + iif(wasT , 2 , 4) 
				if (cpu->T=0) Then ea Or= 1UL 	'set T flag if needed
			else 'not BLX -> differentiate between BL and B
				if (instr_ And &h01000000UL) Then 
					cpu->regs(REG_NO_LR) = cpu->curInstrPC + iif(wasT , 2 , 4)
				EndIf
				if (cpu->T) Then ea Or= 1UL 'keep T flag as needed
			EndIf
			cpuPrvSetPC(cpu, ea) 
			Exit Sub ' instruccion OK, salimos 




' --------------- coprocesador -----------------------
		case 12 ,13 	'coprocessor load\store and double register transfers
coproc_mem_2reg: 
			cpNo = (instr_ Shr 8) And &h0F 
			mode = cpuPrvArmAdrMode_5(cpu, instr_, @addBefore, @addAfter, @memVal8) 
			if (cpNo >= 14) Then 'cp14 and cp15 are for priviledged users only
				if (privileged=0) Then 
					print "GOTO invalid_instr 18" : goto invalid_instr
				endif
			ElseIf (cpu->CPAR And (1UL Shl cpNo))=0 Then
				'others are access-controlled by CPAR
				print "GOTO invalid_instr 19" : goto invalid_instr
			EndIf



			if (mode And ARM_MODE_5_RR) Then  
				'handle MCRR, MRCC
				if (cpu->coproc(cpNo)->twoRegF=0) OrElse _
					(cpu->coproc(cpNo)->twoRegF(cpu, cpu->coproc(cpNo)->userData, _
					NOT_NOT(instr_ And &h00100000UL), (instr_ Shr 4) And &h0F, _
					(instr_ Shr 12) And &h0F, (instr_ Shr 16) And &h0F, instr_ And &h0F) =0) Then
							print "GOTO invalid_instr 20 " : goto invalid_instr
				endif
			else
				'handle LDC\STC
				if (cpu->coproc(cpNo)->memAccess=0) OrElse _
				   (cpu->coproc(cpNo)->memAccess(cpu, cpu->coproc(cpNo)->userData, specialinstr , _
				   NOT_NOT(instr_ And &h00400000UL), iif((instr_ And &h00100000UL)=0,1,0),_
				   (instr_ Shr 12) And &h0F, mode And ARM_MODE_5_REG, addBefore, addAfter,_
				   iif(mode And ARM_MODE_5_IS_OPTION , @memVal8 , NULL)) =0) Then
							print "GOTO invalid_instr 21" : goto invalid_instr
				EndIf
			EndIf
			Exit Sub ' instruccion OK, salimos 





		case 14 	'coprocessor data processing and register transfers
coproc_dp:
			cpNo = (instr_ Shr 8) And &h0F 
			if (cpNo >= 14) Then 'cp14 and cp15 are for priviledged users only
				if (privileged=0) Then print "GOTO invalid_instr 22" : goto invalid_instr
			ElseIf (cpu->CPAR And (1UL Shl cpNo))=0 Then
				'others are access-controlled by CPAR
				print "GOTO invalid_instr 23" : goto invalid_instr
			EndIf
			
			if (instr_ And &h00000010UL) Then  
				'MCR[2]\MRC[2]
				if (cpu->coproc(cpNo)->regXfer=0) OrElse _
					(cpu->coproc(cpNo)->regXfer(cpu, cpu->coproc(cpNo)->userData, specialinstr, _
					 NOT_NOT(instr_ And &h00100000UL), (instr_ Shr 21) And &h07, _
					(instr_ Shr 12) And &h0F, (instr_ Shr 16) And &h0F, _
					 instr_ And &h0F, (instr_ Shr 5) And &h07) =0) Then 
							print "GOTO invalid_instr 24" : goto invalid_instr
				endif
			else
				'CDP
				if (cpu->coproc(cpNo)->dataProcessing=0) OrElse _ 
					(cpu->coproc(cpNo)->dataProcessing(cpu, cpu->coproc(cpNo)->userData, specialinstr, _
					(instr_ Shr 20) And &h0F, (instr_ Shr 12) And &h0F, (instr_ Shr 16) And &h0F, _
					 instr_ And &h0F, (instr_ Shr 5) And &h07) =0) Then 
							print "GOTO invalid_instr 25" : goto invalid_instr
				endif
			EndIf
			Exit Sub ' instruccion OK, salimos 
' ----------------------------------------------




		case 15 	'SWI
			'some semihosting support
			if ( (wasT<>0) AndAlso ((instr_ And &h00fffffful) = &hAB) ) OrElse ( (wasT=0) AndAlso ((instr_ And &h00fffffful) = &h123456ul) ) Then 
				if (cpu->regs(0) = 4) Then   
					Dim As ULong addr = cpu->regs(1) 
					Dim As UByte ch 
					while (cpuPrvMemOp(cpu, @ch, addr , 1, false, true, @fsr)<>0) AndAlso (ch<>0)
						addr+=1
						print chr(ch);
               Wend
				ElseIf (cpu->regs(0) = 3) Then
					Dim As UByte ch 
					if (cpuPrvMemOp(cpu, @ch, cpu->regs(1), 1, false, true, @fsr)<>0) AndAlso (ch<>0) Then
						print chr(ch); 
					endif
				ElseIf (cpu->regs(0) = &h132) Then
					MiPrint "debug break requested" 
					'gdbStubDebugBreakRequested(cpu->debugStub) 
				EndIf
				Exit Sub ' instruccion OK, salimos 
			EndIf
			
			cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_SWI, cpu->curInstrPC + iif(wasT , 2 , 4), ARM_SR_MODE_SVC Or ARM_SR_I) 
			Exit Sub ' instruccion OK, salimos 
	
   End Select

invalid_instr:

	print "Invalid instr_ 0x";hex(instr_,8);" seen at 0x";hex(cpu->curInstrPC,8);" with CPSR 0x";hex(cpuPrvMaterializeCPSR(cpu),8)
	cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_UND, cpu->curInstrPC + iif(wasT , 2 , 4), ARM_SR_MODE_UND Or ARM_SR_I) 
   'print "esperando tu respuesta.....":sleep

End Sub


' ejecuta instruccion e incrementa PC (modo NORMAL)
Sub cpuPrvCycleArm(cpu As ArmCpu Ptr)
	Dim As ULong instr_, pc, fetchPc 
	dim As Bool privileged, ok 
	Dim As Ubyte fsr 

	privileged = iif(cpu->M <> ARM_SR_MODE_USR,1,0) 
	
	cpu->curInstrPC = cpu->regs(REG_NO_PC) 								'needed for stub to get proper pc
	'gdbStubReportPc(cpu->debugStub, cpu->regs(REG_NO_PC), true) 		'early in case it changes PC
	
	'fetch instruction
	pc = cpu->regs(REG_NO_PC) 
	fetchPc = pc
	cpu->curInstrPC = pc 
	
	'FCSE
	if (fetchPc < &h02000000UL) Then fetchPc Or= cpu->pid

	' aqui se recogen las instrucciones desde la ROM
	ok = icacheFetch(cpu->ic, fetchPc, 4, privileged, @fsr, @instr_) 

	if (ok=0) Then 
		cpuPrvHandleMemErr(cpu, pc, 4, false, true, fsr) 
	else
		cpu->regs(REG_NO_PC) += 4 
		cpuPrvExecInstr(cpu, instr_, false, privileged, false) 
	EndIf
  
End Sub






' ===============================================================
' constantes
' AND EOR LSL(2) LSR(2) ASR(2) ADC SBC ROR TST NEG CMP(2) CMN ORR MUL BIC MVN (in val_tabl order)
static shared As ULong val_tabl_A(15) = { _
		&h00100000UL, _
		&h00300000UL, _
		&h01B00010UL, _
		&h01B00030UL, _
		&h01B00050UL, _
		&h00B00000UL, _
		&h00D00000UL, _
		&h01B00070UL, _
		&h01100000UL, _
		&h02700000UL, _
		&h01500000UL, _
		&h01700000UL, _
		&h01900000UL, _
		&h00100090UL, _
		&h01D00000UL, _
		&h01F00000UL} 
		
' STR(2)  STRH(2) STRB(2) LDRSB LDR(2) LDRH(2) LDRB(2) LDRSH (in val_tabl order)
static shared As ULong val_tabl_B(7) = {_
		&h07800000UL, _
		&h018000B0UL, _
		&h07C00000UL, _
		&h019000D0UL, _
		&h07900000UL, _
		&h019000B0UL, _
		&h07D00000UL, _
		&h019000F0UL} 		
						
static shared As ULong use16 = &h2AAE280AUL  '0010 1010 1010 1110 0010 1000 0000 1010
static shared As ULong use12 = &hA208AAAAUL  '1010 0010 0000 1000 1010 1010 1010 1010
static shared As ULong use8  = &h0800C3F0UL  '0000 1000 0000 0000 1100 0011 1111 0000
static shared As ULong use0  = &hFFF3BEAFUL  '1111 1111 1111 0011 1011 1110 1010 1111
Dim shared As UByte vals(3) = {0,0,0,0}

		
											
' ejecuta instruccion e incrementa PC (modo THUMB)
Sub cpuPrvCycleThumb(cpu As ArmCpu Ptr) 
	Dim As Bool privileged, vB, specialPC = false, ok 
	Dim As ULong t, pc, fetchPc , instr_ = &hE0000000UL 'most likely thing
	Dim As UShort instrT, v16 
	Dim As Ubyte v8, fsr 
	
	privileged = iif(cpu->M <> ARM_SR_MODE_USR ,1,0)
	
	cpu->curInstrPC = cpu->regs(REG_NO_PC) 								'needed for stub to get proper pc
	'gdbStubReportPc(cpu->debugStub, cpu->regs(REG_NO_PC), true) 		'early in case it changes PC
	
	pc = cpu->regs(REG_NO_PC) 
	fetchPc = pc
	cpu->curInstrPC = pc 
	
	'FCSE
	if (fetchPc < &h02000000UL) Then fetchPc Or= cpu->pid
	
	ok = icacheFetch(cpu->ic, fetchPc, 2, privileged, @fsr, @instrT) 
	if (ok=0) Then 
		cpuPrvHandleMemErr(cpu, pc, 2, false, true, fsr) 
		Exit Sub 	'exit here so that debugger can see us execute first instr_ of execption handler
	EndIf
  
	cpu->regs(REG_NO_PC) += 2 

	Select Case As Const (instrT Shr 12)  
		case 0,1 		' LSL(1) LSR(1) ASR(1) ADD(1) SUB(1) ADD(3) SUB(3)
			if ((instrT And &h1800) <> &h1800) Then  ' LSL(1) LSR(1) ASR(1)
				instr_ Or= &h01B00000UL Or ((instrT And &h7) Shl 12) Or ((instrT Shr 3) And 7) Or ((instrT Shr 6) And &h60) Or ((instrT Shl 1) And &hF80) 
			else
				vB = NOT_NOT(instrT And &h0200) 	' SUB or ADD ?
				instr_ Or= (iif(vB , 5UL , 9UL) Shl 20) Or ((Culng(instrT And &h38)) Shl 13) Or ((instrT And &h07) Shl 12) Or ((instrT Shr 6) And &h07) 
				if (instrT And &h0400) Then ' ADD(1) SUB(1)
					instr_ Or= &h02000000UL 
				else ' ADD(3) SUB(3)
					' nothing to do here
				EndIf
			EndIf
		
		case 2,3 		' MOV(1) CMP(1) ADD(2) SUB(2)
			instr_ Or= instrT And &h00FF 
			Select Case As Const  ((instrT Shr 11) And 3)  
				case 0 				' MOV(1)
					instr_ Or= &h03B00000UL Or ((instrT And &h0700) Shl 4) 

				case 1 				' CMP(1)
					instr_ Or= &h03500000UL Or ((Culng(instrT And &h0700)) Shl 8) 

				case 2 				' ADD(2)
					instr_ Or= &h02900000UL Or ((instrT And &h0700) Shl 4) Or ((Culng(instrT And &h0700)) Shl 8) 

				case 3 ' SUB(2)
					instr_ Or= &h02500000UL Or ((instrT And &h0700) Shl 4) Or ((Culng(instrT And &h0700)) Shl 8) 
         End Select
		
		case 4 ' LDR(3) ADD(4) CMP(3) MOV(3) BX MVN CMP(2) CMN TST ADC SBC NEG MUL LSL(2) LSR(2) ASR(2) ROR AND EOR ORR BIC
			if (instrT And &h0800) Then   			' LDR(3)
				instr_ Or= &h059F0000UL Or ((instrT And &hFF) Shl 2) Or ((instrT And &h700) Shl 4) 
				specialPC = true 
			ElseIf (instrT And &h0400) Then ' ADD(4) CMP(3) MOV(3) BX
				Dim As UByte vD 
				vD = (instrT And 7) Or ((instrT Shr 4) And &h08) 
				v8 = (instrT Shr 3) And &hF 
				Select Case As Const ((instrT Shr 8) And 3)  
					case 0 	' ADD(4)
						'special handling required for PC destination
						t = cpuPrvGetReg(cpu, vD, true, false) + cpuPrvGetReg(cpu, v8, true, false) 
						if (vD = 15) Then t Or= 1 
						cpuPrvSetReg(cpu, vD, t) 
						Exit Sub ' instruccion OK, salimos 

					case 1 			' CMP(3)
						instr_ Or= &h01500000UL Or ( Culng(vD) Shl 16) Or v8 

					case 2 			' MOV(3)
						'special handling required for PC destination
						t = cpuPrvGetReg(cpu, v8, true, false) 
						if (vD = 15) Then t Or= 1 
						cpuPrvSetReg(cpu, vD, t) 
						Exit Sub ' instruccion OK, salimos 
					
					case 3 			' BX
						'this will not handle "BLX LR"
						if (instrT = &h47f0) Then 
							MiPrint "very unlikely" 
							beep:Sleep
						EndIf

						if (instrT And &h80) Then 'BLX
							cpu->regs(REG_NO_LR) = cpu->regs(REG_NO_PC) + 1
						EndIf

						if (instrT = &h4778) Then 
							'special handing for thumb´s "BX PC" as aparently docs are wrong on it
							cpuPrvSetPC(cpu, (cpu->regs(REG_NO_PC) + 2) And INV( 3UL) )
							Exit Sub ' instruccion OK, salimos 
						EndIf
						instr_ Or= &h012FFF10UL Or ((instrT Shr 3) And &h0F) 
					
					case else 
						goto undefined 
            End Select

			else

         	' AND EOR LSL(2) LSR(2) ASR(2) ADC SBC ROR TST NEG CMP(2) CMN ORR MUL BIC MVN (in val_tabl order)
				
				'00 = none
				'10 = bit0 val
				'11 = bit3 val
				'MVN BIC MUL ORR CMN CMP(2) NEG TST ROR SBC ADC ASR(2) LSR(2) LSL(2) EOR AND 
				
				vals(2) = (instrT And 7) 
				vals(3) = (instrT Shr 3) And 7 
				v8 = (instrT Shr 6) And 15 
				instr_ Or= val_tabl_A(v8) 
				v8 Shl = 1 
				instr_ Or= (Culng(vals((use16 Shr v8) And 3UL))) Shl 16 
				instr_ Or= (Culng(vals((use12 Shr v8) And 3UL))) Shl 12 
				instr_ Or= (Culng(vals((use8  Shr v8) And 3UL))) Shl  8 
				instr_ Or= (Culng(vals((use0  Shr v8) And 3UL))) Shl  0 
			
			EndIf
		
		case 5 		' STR(2)  STRH(2) STRB(2) LDRSB LDR(2) LDRH(2) LDRB(2) LDRSH		(in val_tbl orver)
			instr_ Or= ((instrT Shr 6) And 7) Or ((instrT And 7) Shl 12) Or ((Culng(instrT And &h38)) Shl 13) Or val_tabl_B((instrT Shr 9) And 7) 
		
		case 6 		' LDR(1) STR(1)	(bit11 set = ldr)
			instr_ Or= ((instrT And 7) Shl 12) Or ((Culng(instrT And &h38)) Shl 13) Or ((instrT Shr 4) And &h7C) Or &h05800000UL 
			if (instrT And &h0800) Then instr_ Or= &h00100000UL 
			
		case 7 		' LDRB(1) STRB(1)	(bit11 set = ldrb)
			instr_ Or= ((instrT And 7) Shl 12) Or ((Culng(instrT And &h38)) Shl 13) Or ((instrT Shr 6) And &h1F) Or &h05C00000UL 
			if (instrT And &h0800) Then instr_ Or= &h00100000UL  
		
		case 8 		' LDRH(1) STRH(1)	(bit11 set = ldrh)
			instr_ Or= ((instrT And 7) Shl 12) Or ((Culng(instrT And &h38)) Shl 13) Or ((instrT Shr 5) And &h0E) Or ((instrT Shr 1) And &h300) Or &h01C000B0UL 
			if (instrT And &h0800) Then instr_ Or= &h00100000UL 
		
		case 9 		' LDR(4) STR(3)	(bit11 set = ldr)
			instr_ Or= ((instrT And &h700) Shl 4) Or ((instrT And &hFF) Shl 2) Or &h058D0000UL 
			if (instrT And &h0800) Then instr_ Or= &h00100000UL 
		
		case 10 	' ADD(5) ADD(6)	(bit11 set = add(6))
			instr_ Or= ((instrT And &h700) Shl 4) Or (instrT And &hFF) Or &h028D0F00UL 	'encode add to SP, line below sets the bit needed to reference PC instead when needed)
			if ((instrT And &h0800)=0) Then 
				instr_ Or= &h00020000UL 
				specialPC = true 
			EndIf
		
		case 11 	' ADD(7) SUB(4) PUSH POP BKPT
			if ((instrT And &h0600) = &h0400) Then   		'PUSH POP
				instr_ Or= (instrT And &hFF) Or &h000D0000UL 
				if (instrT And &h0800) Then 'POP
					if (instrT And &h0100) Then instr_ Or= &h00008000UL 
					instr_ Or= &h08B00000UL 
				else 'PUSH
					if (instrT And &h0100) Then instr_ Or= &h00004000UL 
					instr_ Or= &h09200000UL 
				EndIf
			ElseIf (instrT And &h0100) Then 
				goto undefined 
			else
				Select Case As Const ((instrT Shr 9) And 7)  
				  case 0 			' ADD(7) SUB(4)
					  instr_ Or= &h020DDF00UL Or (instrT And &h7F) Or iif(instrT And &h0080 , &h00400000UL , &h00800000UL) 

				  case 7 	'BKPT
					  instr_ Or= &h01200070UL Or (instrT And &h0F) Or ((instrT And &hF0) Shl 4) 
				
				  case else 
					  goto undefined 
            End Select
			EndIf
		
		case 12 	' LDMIA STMIA		(bit11 set = ldmia)
			instr_ Or= &h08800000UL Or ((Culng(instrT And &h700)) Shl 8) Or (instrT And &hFF) 
			if (instrT And &h0800) Then instr_ Or= &h00100000UL 
			if ((1UL Shl ((instrT Shr 8) And &h07)) And instrT)=0 Then instr_ Or= &h00200000UL 	'set W bit if needed
		
		case 13 	' B(1), SWI, undefined instr_ space
			v8 = ((instrT Shr 8) And &h0F) 
			if (v8 = 14) Then   			' undefined instr
				goto undefined 
			ElseIf (v8 = 15) Then ' SWI
				instr_ Or= &h0F000000UL Or (instrT And &hFF) 
			else ' B(1)
				instr_ = ((Culng(v8)) Shl 28) Or &h0A000000UL Or (instrT And &hFF) 
				if (instrT And &h80) Then instr_ Or= &h00FFFF00UL 
			EndIf
		
		case 14,15 	' B(2) BL BLX(1) undefined instr_ space
			v16 = (instrT And &h7FF) 
			Select Case As Const ((instrT Shr 11) And 3)  
				case 0 		'B(2)
					instr_ Or= &h0A000000UL Or v16 
					if (instrT And &h0400) Then instr_ Or= &h00FFF800UL 

				case 1 		'BLX(1)_suffix
					instr_ = cpu->regs(REG_NO_PC) 
					cpu->regs(REG_NO_PC) = (cpu->regs(REG_NO_LR) + 2 + (Culng(v16) Shl 1)) And INV(3) 
					cpu->regs(REG_NO_LR) = instr_ Or 1UL 
					cpu->T = 0 
					Exit Sub ' instruccion OK, salimos 
				
				case 2 		'BLX(1)_prefix BL_prefix
					instr_ = v16 
					if (instrT And &h0400) Then instr_ Or= &h000FF800UL 
					cpu->regs(REG_NO_LR) = cpu->regs(REG_NO_PC) + (instr_ Shl 12) 
					Exit Sub ' instruccion OK, salimos 
				
				case 3 		'BL_suffix
					instr_ = cpu->regs(REG_NO_PC) 
					cpu->regs(REG_NO_PC) = cpu->regs(REG_NO_LR) + 2 + (Culng(v16) Shl 1) 
					cpu->regs(REG_NO_LR) = instr_ Or 1UL 
					Exit Sub ' instruccion OK, salimos 
         End Select
			
			if (instrT And &h0800) Then goto undefined 	'avoid BLX_suffix and undefined instr_ space in there
			instr_ Or= &h0A000000UL Or (instrT And &h7FF) 
			if (instrT And &h0400) Then instr_ Or= &h00FFF800UL 
   End Select

instr_execute: 
	cpuPrvExecInstr(cpu, instr_, true, privileged, specialPC) 
	
' ya no es necesaria esta etiqueta -> instr_done: 
	Exit Sub 
	
undefined: 
	instr_ = &hE7F000F0UL Or (instrT And &h0F) Or ((instrT And &hFFF0) Shl 4) 	'guranteed undefined instr_, inside it we store the original thumb instr_ :)=-)
	goto instr_execute 
End Sub


Sub cpuReset(cpu As ArmCpu Ptr , pc As ULong)
	cpu->I = true 	'start w\o interrupts in supervisor mode
	cpu->F = true 
	cpu->M = ARM_SR_MODE_SVC 

	cpuPrvSetPC(cpu, pc) 
	mmuReset(cpu->mmu) 
End Sub


Function cpuInit(pc As ULong , mem As ArmMem Ptr , xscale As Bool , omap As Bool , debugPort As Long , cpuid As ULong , cacheId As ULong) As ArmCpu ptr
	Dim as ArmCpu ptr cpu = cast(ArmCpu ptr,Callocate(sizeof(ArmCpu)) ) 
	
	if (cpu=0) Then PERR("cannot alloc CPU")

	memset(cpu, 0, sizeof(ArmCpu)) 
	
	'cpu->debugStub = gdbStubInit(cpu, debugPort) 
	'if (cpu->debugStub=0) Then PERR("Cannot init debug stub")

	cpu->mem = mem 

	cpu->mmu = mmuInit(mem, xscale) 
	if (cpu->mmu=0) Then PERR("Cannot init MMU")

	cpu->ic = icacheInit(mem, cpu->mmu) 
	if (cpu->ic=0) Then PERR("Cannot init ICACHE")


   ' FUNCION -> cp15Init
	'    cpu ArmCpu*, mmu ArmMmu*, ic icache*, cpuid ULong, cacheId ULong, xscale bool, omap bool
	' SALIDA -> ArmCP15*
	cpu->cp15 = cp15Init(cpu, cpu->mmu, cpu->ic, cpuid, cacheId, xscale, omap)
	if (cpu->cp15=0) Then PERR("Cannot init CP15")

	cpuReset(cpu, pc) 

	return cpu 
End Function


Sub cpuCycle( cpu As ArmCpu Ptr) 
	if (cpu->waitingFiqs<>0) AndAlso (cpu->F=0) Then 
		cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_FIQ, cpu->regs(REG_NO_PC) + 4, ARM_SR_MODE_FIQ Or ARM_SR_I Or ARM_SR_F) 
	ElseIf (cpu->waitingIrqs<>0) AndAlso (cpu->I=0) Then
		cpuPrvException(cpu, cpu->vectorBase + ARM_VECTOR_OFFT_IRQ, cpu->regs(REG_NO_PC) + 4, ARM_SR_MODE_IRQ Or ARM_SR_I)
	EndIf
	
	cp15Cycle(cpu->cp15) 

	if (cpu->T) Then 
		cpuPrvCycleThumb(cpu) 
	else
		cpuPrvCycleArm(cpu)
	EndIf
End Sub


Sub cpuIrq( cpu As ArmCpu Ptr , fiq As Bool , raise As Bool) 	'unraise when acknowledged
	if (fiq) Then 
		if (raise) Then   
			cpu->waitingFiqs+=1  
		ElseIf (cpu->waitingFiqs) Then
			cpu->waitingFiqs-=1  
		else
			Miprint "Cannot unraise FIQ when none raised" 
		EndIf
	else
		if (raise) Then   
			cpu->waitingIrqs+=1  
		ElseIf (cpu->waitingIrqs) Then
			cpu->waitingIrqs-=1  
		else
			Miprint "Cannot unraise IRQ when none raised"
		EndIf
	EndIf
End Sub

Sub cpuCoprocessorRegister( cpu As ArmCpu Ptr , cpNum As UByte , coproc As ArmCoprocessor ptr )
	cpu->coproc(cpNum) = coproc
End Sub

Sub cpuSetVectorAddr( cpu As ArmCpu Ptr , adr As ULong)
	cpu->vectorBase = adr 	
End Sub

Function cpuGetCPAR( cpu As ArmCpu Ptr) As UShort
	return cpu->CPAR 	
End Function

Sub cpuSetCPAR( cpu As ArmCpu Ptr , cpar As UShort)
	cpu->CPAR = cpar 	
End Sub

Sub cpuSetPid( cpu As ArmCpu Ptr , pid As ULong)
	cpu->pid = pid 
End Sub

Function cpuGetPid( cpu As ArmCpu Ptr) As ULong
	return cpu->pid 
End Function
