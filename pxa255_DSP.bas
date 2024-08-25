'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


Function pxa255dspPrvAccess( cpu As ArmCpu Ptr , userData As Any Ptr , MRRC As Bool , op As uByte , RdLo As uByte , RdHi As uByte , acc As uByte) As Bool
	Dim As Pxa255dsp ptr dsp = cast(Pxa255dsp ptr,userData) 
	
	if(acc <> 0) OrElse (op <> 0) Then return false 'bad encoding
	
	if (MRRC) Then 'MRA: read_ acc0
		cpuSetReg(cpu, RdLo,  dsp->acc0) 
		cpuSetReg(cpu, RdHi, (dsp->acc0 Shr 32) And &hff) 
	else 'MAR: write_ acc0
		dsp->acc0 = ((CuLngInt(cpuGetRegExternal(cpu, RdHi) And &hff)) Shl 32) Or cpuGetRegExternal(cpu, RdLo) 
	EndIf
	
	return true 	
End Function

Function pxa255dspPrvOp( cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , MRC As Bool , op1 As uByte , Rs As uByte , opcode_3 As uByte , Rm As uByte , acc As uByte) As Bool
	Dim As Pxa255dsp ptr dsp = cast(Pxa255dsp ptr,userData) 
	dim as ULongInt addend = dsp->acc0 
	dim as uLong Vs, Vm 
	
	if (op1<>1) OrElse (two<>0) OrElse (MRC<>0) OrElse (acc<>0) Then return false 'bad encoding
	
	Vs = cpuGetRegExternal(cpu, Rs) 
	Vm = cpuGetRegExternal(cpu, Rm) 
	
	Select Case As Const (opcode_3 Shr 2)  
		case 0 	'MIA
			addend += CLngInt(CLng(Vm)) * CLngInt(CLng(Vs)) 
		
		case 1 	'invalid
			return false 
		
		case 2 	'MIAPH
			addend += CLngInt(CShort(Vm)) * CLngInt(CShort(Vs)) 
			addend += CLngInt(CShort(Vm Shr 16)) * CLngInt(CShort(Vs Shr 16)) 

		case 3 	'MIAxy
			if (opcode_3 And 2) Then Vm Shr = 16 'X set
			if (opcode_3 And 1) Then Vs Shr = 16 'Y set
			addend += CLngInt(CShort(Vm)) * CLngInt(CShort(Vs)) 
   End Select

	addend And= &hFFFFFFFFFFULL 
	
	dsp->acc0 = addend 
	
	return true 
End Function

Function pxa255dspInit( cpu As ArmCpu Ptr) As Pxa255dsp ptr
	 Dim As Pxa255dsp ptr dsp = cast(Pxa255dsp ptr,Callocate(sizeof(Pxa255dsp)) )
	 
	 dim as ArmCoprocessor cp0 
	 With cp0
		.regXfer        = cast(ArmCoprocRegXferF,@pxa255dspPrvOp)
		.dataProcessing = NULL
		.memAccess      = NULL
		.twoRegF        =cast(ArmCoprocTwoRegF,@pxa255dspPrvAccess)
		.userData       = dsp
	 End With
	 
	if dsp=0 Then PERR("cannot alloc DSP CP0")
	
	memset(dsp, 0, sizeof(Pxa255dsp)) 
	
	cpuCoprocessorRegister(cpu, 0, @cp0) 
	
	return dsp 
End Function
