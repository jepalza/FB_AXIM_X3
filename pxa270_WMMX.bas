'(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>


' revisar, parecen bucles de los que nunca sale, debido a multitareas
'#Define pxa270wmmxPrvDataRegsChanged(_wmmx)			do{ _wmmx->wCon Or= 2; } while(0)
'#Define pxa270wmmxPrvControlRegsChanged(_wmmx)		do{ _wmmx->wCon Or= 1; } while(0)
#Define pxa270wmmxPrvDataRegsChanged(_wmmx)			print"revisar pxa270wmmxPrvDataRegsChanged":sleep:(_wmmx)->wCon Or= 2
#Define pxa270wmmxPrvControlRegsChanged(_wmmx)		print"revisar pxa270wmmxPrvControlRegsChanged":sleep:(_wmmx)->wCon Or= 1

' LITTLE_ENDIAN = PC
#define ACCESS_REG_8(_idx)	 (_idx)
#define ACCESS_REG_16(_idx) (_idx)
#define ACCESS_REG_32(_idx) (_idx)

Sub pxa270wmmxPrvSetFlagsForLogical64(wmmx As Pxa270wmmx Ptr , valor As ULongint)
	wmmx->wCASF = IIf(valor Shr 63, &h80000000ul , 0) Or (iif(valor , 0 , &h40000000ul))
	pxa270wmmxPrvControlRegsChanged(wmmx) 
End Sub

Sub pxa270wmmxPrvAlign(wmmx As Pxa270wmmx  Ptr , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte , by As Ubyte)
	Dim as REG64 ret 
	Dim As Ubyte i 
	
	For i= 0 To (8 - by) -1 ' revisar       
		ret.v8(ACCESS_REG_8(i)) = wmmx->wR(CRn).v8(ACCESS_REG_8(i + by))
   Next
	for i = i To 7  ' sigue al anterior I    
		ret.v8(ACCESS_REG_8(i)) = wmmx->wR(CRn).v8(ACCESS_REG_8(i - 8 + by))
   Next
	wmmx->wR(CRd).v64 = ret.v64 
	pxa270wmmxPrvDataRegsChanged(wmmx) 
End Sub

Function pxa270wmmxPrvDataProcessingMisc( wmmx As Pxa270wmmx Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, tf8 
	Dim As Ushort tf16 
	Dim As ULongint tmp 
	
	Select Case As Const  (op1)  
		case &b0000 		'WOR
			tmp = wmmx->wR(CRn).v64 Or wmmx->wR(CRm).v64 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
		
		case &b0001 		'WXOR
			tmp = wmmx->wR(CRn).v64 Xor wmmx->wR(CRm).v64 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
		
		case &b0010 		'WAND
			tmp = wmmx->wR(CRn).v64 And wmmx->wR(CRm).v64 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
		
		case &b0011 		'WANDN
			tmp = wmmx->wR(CRn).v64 And INV( wmmx->wR(CRm).v64 )
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
		
		case &b1000, &b1001  		'WAVG2 (byte size)
			wmmx->wCASF = 0 
			tmp = &h04
			for i = 0 To 7        
				tf8 = (wmmx->wR(CRn).v8(ACCESS_REG_8(i)) + wmmx->wR(CRm).v8(ACCESS_REG_8(i)) + (op1 And 1)) \ 2 
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = tf8
				if (tf8=0) Then  wmmx->wCASF Or= tmp
				tmp shl=4
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1100, &b1101 		'WAVG2 (halfword size)
			wmmx->wCASF = 0 
			tmp = &h40
			for i = 0 To 3         
				tf16 = (wmmx->wR(CRn).v16(ACCESS_REG_16(i)) + wmmx->wR(CRm).v16(ACCESS_REG_16(i)) + (op1 And 1)) \ 2 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16=0) Then wmmx->wCASF Or= tmp	
				tmp shl=8
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingAlign(wmmx As Pxa270wmmx Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool

	Select Case As Const  (op1)  
		case  &b0000 ,_ 	'WALIGNI
				&b0001 ,_
				&b0010 ,_
				&b0011 ,_
				&b0100 ,_
				&b0101 ,_
				&b0110 ,_	
				&b0111 
			pxa270wmmxPrvAlign(wmmx, CRd, CRn, CRm, (op1 And 7)) 
		
		case  &b1000 ,_		'WALIGNR
				&b1001 ,_
				&b1010 ,_
				&b1011 
			pxa270wmmxPrvAlign(wmmx, CRd, CRn, CRm, wmmx->wCGR(op1 And 3) And 7) 
		
		case else 
			return false 
	
  End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingShift(wmmx As Pxa270wmmx Ptr , cp1 As Bool , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, by '8
	Dim As Ushort tf16 '16
	Dim As ULong tf32  '32
	Dim As ULongint tmp'64

	Select Case As Const (op1)  
		case &b0100 		'WSRA.h
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			for i = 0 To 3         
				tf16 = wmmx->wR(CRn).s16(ACCESS_REG_16(i)) Shr by 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1000 		'WSRA.w
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 1         
				tf32 = wmmx->wR(CRn).s32(ACCESS_REG_32(i)) Shr by 
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if (tf32=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (tf32 And &h80000000ul) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1100 		'WSRA.d
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			tmp = wmmx->wR(CRn).s64 Shr by 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0101 		'WSLL.h
			if ( cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 3         
				tf16 = wmmx->wR(CRn).v16(ACCESS_REG_16(i)) Shl by 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1001 		'WSLL.w
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 1        
				tf32 = wmmx->wR(CRn).v32(ACCESS_REG_32(i)) Shl by 
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if (tf32=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (tf32 And &h80000000ul) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1101 		'WSLL.d
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			tmp = wmmx->wR(CRn).v64 Shl by 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0110 		'WSRL.h
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf  (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 3         
				tf16 = wmmx->wR(CRn).v16(ACCESS_REG_16(i)) Shr by 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1010 		'WSRL.w
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 1         
				tf32 = wmmx->wR(CRn).v32(ACCESS_REG_32(i)) Shr by 
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if ( tf32=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (tf32 And &h80000000ul) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1110 		'WSRL.d
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			tmp = wmmx->wR(CRn).v64 Shr by 
			wmmx->wR(CRd).v64 = tmp
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0111 		'WROR.h
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			for i = 0 To 3      
				if (by) Then 
					tf16 = (wmmx->wR(CRn).v16(ACCESS_REG_16(i)) Shr by) Or (wmmx->wR(CRn).v16(ACCESS_REG_16(i)) Shl (16 - by)) 
				else
					tf16 = wmmx->wR(CRn).v16(ACCESS_REG_16(i))
				EndIf
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16 
				if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1011 		'WROR.w
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			wmmx->wCASF = 0 
			For i= 0 To 1        
				if (by) Then 
					tf32 = (wmmx->wR(CRn).v32(ACCESS_REG_32(i)) Shr by) Or (wmmx->wR(CRn).v32(ACCESS_REG_32(i)) Shl (32 - by)) 
				else
					tf32 = wmmx->wR(CRn).v32(ACCESS_REG_32(i))
				EndIf
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32 
				if (tf32=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (tf32 And &h80000000ul) Then  wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1111 		'WROR.d
			if (cp1=0) Then 
				by = wmmx->wR(CRm).v8(ACCESS_REG_8(0)) 
			ElseIf (CRm >= 4) Then
				return false 
			else
				by = wmmx->wCGR(CRm)
			EndIf
			if (by) Then 
				tmp = (wmmx->wR(CRn).v64 Shr by) Or (wmmx->wR(CRn).v64 Shl (64 - by)) 
			else
				tmp = wmmx->wR(CRn).v64
			EndIf
			wmmx->wR(CRd).v64 = tmp 
			pxa270wmmxPrvSetFlagsForLogical64(wmmx, tmp) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingCompare(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, tf8 
	Dim As Ushort tf16 
	Dim As ULong  tf32 
	
	Select Case As Const (op1)  
		case &b0000 	'WCMPEQ.b
			wmmx->wCASF = 0 
			For i= 0 To 7
				tf8 = iif( wmmx->wR(CRn).v8(ACCESS_REG_8(i))=wmmx->wR(CRm).v8(ACCESS_REG_8(i)) , &hFF , &h00)
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = tf8
				if (tf8) Then 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
				else
					wmmx->wCASF Or= &h4ul Shl (i * 4)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx)  
		
		case &b0100 	'WCMPEQ.h
			wmmx->wCASF = 0 
			For i= 0 To 3         
				tf16 = iif ( wmmx->wR(CRn).v16(ACCESS_REG_16(i)) = wmmx->wR(CRm).v16(ACCESS_REG_16(i)) , &hFFFF , &h00) 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16) Then 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
				else
					wmmx->wCASF Or= &h40ul Shl (i * 8)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1000 	'WCMPEQ.w
			wmmx->wCASF = 0 
			For i= 0 To 1         
				tf32 = iif ( wmmx->wR(CRn).v32(ACCESS_REG_32(i)) = wmmx->wR(CRm).v32(ACCESS_REG_32(i)) , &hFFFFFFFFUL , &h00 ) 
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if (tf32) Then 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
				else
					wmmx->wCASF Or= &h4000ul Shl (i * 16)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0001 	'WCMPGTU.b
			wmmx->wCASF = 0 
			For i= 0 To 7         
				tf8 = iif( wmmx->wR(CRn).v8(ACCESS_REG_8(i)) > wmmx->wR(CRm).v8(ACCESS_REG_8(i)) , &hFF , &h00) 
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = tf8
				if (tf8) Then 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
				else
					wmmx->wCASF Or= &h4ul Shl (i * 4)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0101 	'WCMPGTU.h
			wmmx->wCASF = 0 
			for i = 0 To 3         
				tf16 = iif( wmmx->wR(CRn).v16(ACCESS_REG_16(i)) > wmmx->wR(CRm).v16(ACCESS_REG_16(i)) , &hFFFF , &h00) 
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16) Then 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
				else
					wmmx->wCASF Or= &h40ul Shl (i * 8)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1001 	'WCMPGTU.w
			wmmx->wCASF = 0 
			for i = 0 To 1         
				tf32 = iif( wmmx->wR(CRn).v32(ACCESS_REG_32(i)) > wmmx->wR(CRm).v32(ACCESS_REG_32(i)) , &hFFFFFFFFUL , &h00 )
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if (tf32) Then 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
				else
					wmmx->wCASF Or= &h4000ul Shl (i * 16)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0011 	'WCMPGTS.b
			wmmx->wCASF = 0 
			For i= 0 to 7
				tf8 = iif( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) > wmmx->wR(CRm).s8(ACCESS_REG_8(i)) , &hFF , &h00 )
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = tf8
				if (tf8) Then 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
				else
					wmmx->wCASF Or= &h4ul Shl (i * 4)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0111 	'WCMPGTS.h
			wmmx->wCASF = 0 
			For i= 0 To 3         
				tf16 = iif( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) > wmmx->wR(CRm).s16(ACCESS_REG_16(i)) , &hFFFF , &h00 )
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = tf16
				if (tf16) Then 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
				else
					wmmx->wCASF Or= &h40ul Shl (i * 8)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1011 	'WCMPGTS.w
			wmmx->wCASF = 0 
			For i= 0 To 1         
				tf32 = iif( wmmx->wR(CRn).s32(ACCESS_REG_32(i)) > wmmx->wR(CRm).s32(ACCESS_REG_32(i)) , &hFFFFFFFFUL , &h00 )
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = tf32
				if (tf32) Then
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
				else
					wmmx->wCASF Or= &h4000ul Shl (i * 16)
				EndIf
         Next
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingPack(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, j, from 
	Dim As Short ts16 
	Dim As Long ts32 
	Dim As LongInt ts64 
	Dim as REG64 ret ' union
	
	Select Case As Const  (op1)  
		case &b0101 			'WPACKUS.h
			wmmx->wCASF = 0 
			For i= 0 To 7       
				from = iif(i < 4 , CRn , CRm) 
				j = i mod 4 
				ts16 = wmmx->wR(from).s16(ACCESS_REG_16(j)) 
				if (ts16 < 0) Then   
					ts16 = 0 
					wmmx->wCSSF Or= 1 Shl i 
					wmmx->wCASF Or= &h4ul Shl (i * 4) 
				ElseIf  (ts16 > &hff) Then
					ts16 = &hff 
					wmmx->wCSSF Or= 1 Shl i 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
				else
					if (ts16=0)        Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (ts16 And &h80) Then wmmx->wCASF Or= &h8ul Shl (i * 4)
				EndIf
				ret.v8(ACCESS_REG_8(i)) = ts16 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			
		case &b1001 			'WPACKUS.w
			wmmx->wCASF = 0 
			For i= 0 To 3         
				from = iif(i < 2 , CRn , CRm )
				j = i mod 2 
				ts32 = wmmx->wR(from).s32(ACCESS_REG_32(j)) 
				if ts32 < 0 Then   
					ts32 = 0 
					wmmx->wCSSF Or= 1 Shl (i * 2) 
					wmmx->wCASF Or= &h40ul Shl (i * 8) 
				ElseIf  (ts32 > &hffffl) Then
					ts32 = &hffff 
					wmmx->wCSSF Or= 1 Shl (i * 2) 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
				else
					if (ts32=0)           Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (ts32 And &h8000u) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
				EndIf
				ret.v16(ACCESS_REG_16(i)) = ts32 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1101 			'WPACKUS.d
			wmmx->wCASF = 0 
			For i= 0 To 1         
				ts64 = wmmx->wR(iif(i , CRm , CRn)).s64 
				if ts64 < 0 Then   
					ts64 = 0 
					wmmx->wCSSF Or= 1 Shl (i * 4) 
					wmmx->wCASF Or= &h4000ul Shl (i * 16) 
				ElseIf  (ts64 > &hffffffffll) Then
					ts64 = &hffffffffll 
					wmmx->wCSSF Or= 1 Shl (i * 4) 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
				else
					if (ts64=0)              Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (ts64 And &h800000ul) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
				EndIf
				ret.v32(ACCESS_REG_32(i)) = ts64 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0111 			'WPACKSS.h
			wmmx->wCASF = 0 
			For i= 0 To 7        
				from = iif(i < 4 , CRn , CRm)
				j = i mod 4 
				ts16 = wmmx->wR(from).s16(ACCESS_REG_16(j)) 
				if ts16 < -&h80 Then   
					ts16 = -&h80 
					wmmx->wCSSF Or= 1 Shl i 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
				ElseIf  (ts16 > &h7f) Then
					ts16 = &h7f 
					wmmx->wCSSF Or= 1 Shl i 
				else
					if ( ts16=0)  Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (ts16 < 0) Then wmmx->wCASF Or= &h8ul Shl (i * 4)
				EndIf
				ret.v8(ACCESS_REG_8(i)) = ts16 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			
		case &b1011 			'WPACKSS.w
			wmmx->wCASF = 0 
			For i= 0 To 3         
				from = Iif(i < 2 , CRn , CRm) 
				j = i mod 2 
				ts32 = wmmx->wR(from).s32(ACCESS_REG_32(j)) 
				if ts32 < -&h8000 Then   
					ts32 = -&h8000 
					wmmx->wCSSF Or= 1 Shl (i * 2) 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
				ElseIf (ts32 > &h7fff) Then
					ts32 = &h7fff 
					wmmx->wCSSF Or= 1 Shl (i * 2) 
				else
					if (ts32=0)   Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (ts32 < 0) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
				EndIf
				ret.v16(ACCESS_REG_16(i)) = ts32 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1111 			'WPACKSS.d
			wmmx->wCASF = 0 
			For i= 0 To 1        
				ts64 = wmmx->wR(iif(i , CRm , CRn)).s64 
				if ts64 < -&h80000000ll Then   
					ts64 = -&h80000000ll 
					wmmx->wCSSF Or= 1 Shl (i * 4) 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
				ElseIf (ts64 > &h7fffffffll) Then
					ts64 = &h7fffffffll 
					wmmx->wCSSF Or= 1 Shl (i * 4) 
				else
					if (ts64=0  ) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (ts64 < 0) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
				EndIf
				ret.v32(ACCESS_REG_32(i)) = ts64 
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 

		case else 
			return false 
	
  End Select

	return true 
End Function


Function pxa270wmmxPrvDataProcessingUnpack(wmmx As Pxa270wmmx  Ptr , hi As Bool , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, tf8 
	Dim As ULong tf32 
	Dim As Ushort tf16 
	Dim As LongInt ts64 
	Dim As Long ts32 
	Dim As Short ts16 
	Dim as REG64 ret 'union
	
	Select Case As Const  (op1)  
		case &b0010 	'WUNPACKESx.b
			wmmx->wCASF = 0 
			For i= 0 To 3         
				ts16 = wmmx->wR(CRn).s8(ACCESS_REG_8(i + iif(hi , 4 , 0))) 
				ret.s16(ACCESS_REG_16(i)) = ts16
				if (ts16=0)   Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (ts16 < 0) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0110 	'WUNPACKESx.h
			wmmx->wCASF = 0 
			For i= 0 To 1         
				ts32 = wmmx->wR(CRn).s16(ACCESS_REG_16(i + iif(hi , 2 , 0))) 
				ret.s32(ACCESS_REG_32(i)) = ts32
				if (ts32=0)   Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (ts32 < 0) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1010 	'WUNPACKESx.w
			wmmx->wCASF = 0 
			ts64 = wmmx->wR(CRn).s32(ACCESS_REG_32(iif(hi , 1 , 0))) 
			wmmx->wR(CRd).s64 = ts64
			if (ts64=0)   Then wmmx->wCASF Or= &h40000000ul
			if (ts64 < 0) Then wmmx->wCASF Or= &h80000000ul
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0000 	'WUNPACKEUx.b
			wmmx->wCASF = 0 
			for i = 0 To 3       
				tf8 = wmmx->wR(CRn).v8(ACCESS_REG_8(i + iif(hi , 4 , 0))) 
				ret.v16(ACCESS_REG_16(i)) = tf8
				if (tf8=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0100 	'WUNPACKEUx.h
			wmmx->wCASF = 0 
			For i= 0 To 1         
				tf16 = wmmx->wR(CRn).v16(ACCESS_REG_16(i + iif(hi , 2 , 0))) 
				ret.v32(ACCESS_REG_32(i)) = tf16
				if (tf16=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1000 	'WUNPACKEUx.w
			wmmx->wCASF = 0 
			tf32 = wmmx->wR(CRn).v32(ACCESS_REG_32(iif(hi , 1 , 0))) 
			wmmx->wR(CRd).v64 = tf32
			if (tf32=0) Then wmmx->wCASF Or= &h40000000ul
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0001 	'WUNPACKIx.b
			wmmx->wCASF = 0 
			For i= 0 To 7         
				tf8 = wmmx->wR(IIf(i And 1 , CRm , CRn)).v8(ACCESS_REG_8(i \ 2 + iif(hi , 4 , 0))) 
				ret.v8(ACCESS_REG_8(i)) = tf8
				if (tf8=0) Then wmmx->wCASF Or= &h4ul Shl (i * 4)
				if (tf8 And &h80) Then wmmx->wCASF Or= &h8ul Shl (i * 4)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			
		case &b0101 	'WUNPACKIx.h
			wmmx->wCASF = 0 
			For i= 0 To 3         
				tf16 = wmmx->wR(IIf(i And 1 , CRm , CRn)).v16(ACCESS_REG_16(i \ 2 + iif(hi , 2 , 0)))
				ret.v16(ACCESS_REG_16(i)) = tf16 
				if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1001 	'WUNPACKIx.w
			wmmx->wCASF = 0 
			For i= 0 To 1       
				tf32 = wmmx->wR(IIf(i And 1 , CRm , CRn)).v32(ACCESS_REG_32(iif(hi , 1 , 0)))
				ret.v32(ACCESS_REG_32(i)) = tf32 
				if (tf32=0) Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (tf32 And &h80000000ul) Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
         Next
			wmmx->wR(CRd).v64 = ret.v64 
			pxa270wmmxPrvControlRegsChanged(wmmx) 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
   End Select

	return true 
End Function


Function pxa270wmmxPrvDataProcessingMultiply(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As ULongint sum = wmmx->wR(CRd).v64 
	Dim As Ubyte i 
	
	Select Case As Const  (op1)  
		case &b0000,_ 	'WMULUL		\\When L is specified the U and S qualifiers produce the same result
		     &b0010 	'WMULSL
			For i= 0 To 3       
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = wmmx->wR(CRn).v16(ACCESS_REG_16(i)) * wmmx->wR(CRm).v16(ACCESS_REG_16(i))
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0001 	'WMULUM
			For i= 0 To 3       
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = (culng( wmmx->wR(CRn).v16(ACCESS_REG_16(i))) * culng( wmmx->wR(CRm).v16(ACCESS_REG_16(i)))) Shr 16
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0011 	'WMULSM
			For i= 0 To 3       
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = (clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i))) * clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)))) Shr 16
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		
		
		'suma de CASES
		case  &b0101 ,_	'WMACUZ
				&b0100      'WMACU
			if (op1=&b0101) then sum=0
			For i= 0 To 3         
				sum += culng( wmmx->wR(CRn).v16(ACCESS_REG_16(i))) * culng( wmmx->wR(CRm).v16(ACCESS_REG_16(i))) 
         Next
			wmmx->wR(CRd).v64 = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		
		
		'suma de CASES
		case  &b0111 ,_ 	'WMACSZ
				&b0110      'WMACS
			if (op1=&b0111) then sum=0
			For i= 0 To 3         
				sum += clngint( (clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i))) * clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)))) )
         Next
			wmmx->wR(CRd).v64 = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		
		
		
		case &b1000 	'WMADDU
			For i= 0 To 1         
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = culng( wmmx->wR(CRn).v16(ACCESS_REG_16(i * 2 + 0))) * culng( wmmx->wR(CRm).v16(ACCESS_REG_16(i * 2 + 0))) + _
														        culng( wmmx->wR(CRn).v16(ACCESS_REG_16(i * 2 + 1))) * culng( wmmx->wR(CRm).v16(ACCESS_REG_16(i * 2 + 1))) 
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1010 	'WMADDS
			For i= 0 To 1         
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i * 2 + 0))) * clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i * 2 + 0))) + _
														        clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i * 2 + 1))) * clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i * 2 + 1))) 
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
  End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingDifference(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As ULong sum = wmmx->wR(CRd).v32(ACCESS_REG_32(0)) 
	Dim As Ubyte i, t 
	
	Select Case As Const  (op1)  
		'suma de CASES
		case  &b0001,_ 		'WSADBZ
				&b0000         'WSADB
			if (op1=&b0001) then sum=0
			For i= 0 To 7         
				t = wmmx->wR(CRn).v8(ACCESS_REG_8(i)) - wmmx->wR(CRm).v8(ACCESS_REG_8(i)) 
				if (t And &h80) Then t = -t
				sum += cubyte( t )
         Next
			wmmx->wR(CRd).v32(ACCESS_REG_32(1)) = 0 
			wmmx->wR(CRd).v32(ACCESS_REG_32(0)) = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		
		' suma de CASES
		case  &b0101,_ 		'WSADHZ
				&b0100 	  	   'WSADH
			if (op1=&b0101) then sum=0
			For i= 0 To 3         
				t = wmmx->wR(CRn).v16(ACCESS_REG_16(i)) - wmmx->wR(CRm).v16(ACCESS_REG_16(i)) 
				if (t And &h8000) Then t = -t
				sum += CuShort( t ) 
         Next
			wmmx->wR(CRd).v32(ACCESS_REG_32(1)) = 0 
			wmmx->wR(CRd).v32(ACCESS_REG_32(0)) = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
  End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingMinMax(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i 
	
	Select Case As Const (op1)  
		case &b0000 	'WMAXUB
			For i= 0 To 7       
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = IIf( wmmx->wR(CRn).v8(ACCESS_REG_8(i)) > wmmx->wR(CRm).v8(ACCESS_REG_8(i)) , wmmx->wR(CRn).v8(ACCESS_REG_8(i)) , wmmx->wR(CRm).v8(ACCESS_REG_8(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0100 	'WMAXUH
			For i= 0 To 3       
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = IIf( wmmx->wR(CRn).v16(ACCESS_REG_16(i)) > wmmx->wR(CRm).v16(ACCESS_REG_16(i)) , wmmx->wR(CRn).v16(ACCESS_REG_16(i)) , wmmx->wR(CRm).v16(ACCESS_REG_16(i)) )
         Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1000 	'WMAXUW
			For i= 0 To 1       
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = IIf( wmmx->wR(CRn).v32(ACCESS_REG_32(i)) > wmmx->wR(CRm).v32(ACCESS_REG_32(i)) , wmmx->wR(CRn).v32(ACCESS_REG_32(i)) , wmmx->wR(CRm).v32(ACCESS_REG_32(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0010 	'WMAXSB
			For i= 0 To 7       
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = IIf( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) > wmmx->wR(CRm).s8(ACCESS_REG_8(i)) , wmmx->wR(CRn).s8(ACCESS_REG_8(i)) , wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0110 	'WMAXSH
			For i= 0 To 3       
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = IIf( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) > wmmx->wR(CRm).s16(ACCESS_REG_16(i)) , wmmx->wR(CRn).s16(ACCESS_REG_16(i)) , wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1010 	'WMAXSW
			For i= 0 To 1       
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = IIf( wmmx->wR(CRn).s32(ACCESS_REG_32(i)) > wmmx->wR(CRm).s32(ACCESS_REG_32(i)) , wmmx->wR(CRn).s32(ACCESS_REG_32(i)) , wmmx->wR(CRm).s32(ACCESS_REG_32(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
			
		case &b0001 	'WMINUB
			For i= 0 To 7       
				wmmx->wR(CRd).v8(ACCESS_REG_8(i)) = IIf( wmmx->wR(CRn).v8(ACCESS_REG_8(i)) < wmmx->wR(CRm).v8(ACCESS_REG_8(i)) , wmmx->wR(CRn).v8(ACCESS_REG_8(i)) , wmmx->wR(CRm).v8(ACCESS_REG_8(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0101 	'WMINUH
			For i= 0 To 3       
				wmmx->wR(CRd).v16(ACCESS_REG_16(i)) = IIf( wmmx->wR(CRn).v16(ACCESS_REG_16(i)) < wmmx->wR(CRm).v16(ACCESS_REG_16(i)) , wmmx->wR(CRn).v16(ACCESS_REG_16(i)) , wmmx->wR(CRm).v16(ACCESS_REG_16(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 

		case &b1001 	'WMINUW
			For i= 0 To 1       
				wmmx->wR(CRd).v32(ACCESS_REG_32(i)) = IIf( wmmx->wR(CRn).v32(ACCESS_REG_32(i)) < wmmx->wR(CRm).v32(ACCESS_REG_32(i)) , wmmx->wR(CRn).v32(ACCESS_REG_32(i)) , wmmx->wR(CRm).v32(ACCESS_REG_32(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx)  
		
		case &b0011 	'WMINSB
			For i= 0 To 7       
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = IIf( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) < wmmx->wR(CRm).s8(ACCESS_REG_8(i)) , wmmx->wR(CRn).s8(ACCESS_REG_8(i)) , wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx)  
		
		case &b0111 	'WMINSH
			For i= 0 To 3       
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = IIf( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) < wmmx->wR(CRm).s16(ACCESS_REG_16(i)) , wmmx->wR(CRn).s16(ACCESS_REG_16(i)) , wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1011 	'WMINSW
			For i= 0 To 1       
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = IIf( wmmx->wR(CRn).s32(ACCESS_REG_32(i)) < wmmx->wR(CRm).s32(ACCESS_REG_32(i)) , wmmx->wR(CRn).s32(ACCESS_REG_32(i)) , wmmx->wR(CRm).s32(ACCESS_REG_32(i)) )
			Next
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingAccumulate(wmmx As Pxa270wmmx Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As ULongint sum = 0 
	Dim As Ubyte i 
	
	Select Case As Const (op1)  
		
		case &b0000 	'WACC.b
			For i= 0 To 7       
				sum += wmmx->wR(CRn).v8(ACCESS_REG_8(i))
         Next
			wmmx->wR(CRd).v64 = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b0100 	'WACC.h
			For i= 0 To 3       
				sum += wmmx->wR(CRn).v16(ACCESS_REG_16(i))
         Next
			wmmx->wR(CRd).v64 = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case &b1000 	'WACC.w
			For i= 0 To 1       
				sum += wmmx->wR(CRn).v32(ACCESS_REG_32(i))
         Next
			wmmx->wR(CRd).v64 = sum 
			pxa270wmmxPrvDataRegsChanged(wmmx) 
		
		case else 
			return false 
	
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessingShuffle(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i, which = (op1 Shl 4) + CRm 
	Dim As Ushort tf16 
	Dim as REG64 ret 'union
	
	wmmx->wCASF = 0 
	For i= 0 To 3         
		tf16 = wmmx->wR(CRn).v16(ACCESS_REG_16(which And 3)) 
		ret.v16(ACCESS_REG_16(i)) = tf16
		if (tf16=0) Then wmmx->wCASF Or= &h40ul Shl (i * 8)
		if (tf16 And &h8000) Then wmmx->wCASF Or= &h80ul Shl (i * 8)
		which shr=2
   Next
	wmmx->wR(CRd).v64 = ret.v64 
	pxa270wmmxPrvControlRegsChanged(wmmx) 
	pxa270wmmxPrvDataRegsChanged(wmmx) 
	return true 
End Function

Function pxa270wmmxPrvDataProcessingAddition(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte i 
	Dim As Short sf16 
	Dim As Long sf32 
	Dim As LongInt sf64 
	
	wmmx->wCASF = 0 
	Select Case As Const (op1)  
		
		case &b0000 	'WADD.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i))) + CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i))) 
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if cbyte( sf16) < 0  Then wmmx->wCASF Or= &h8ul Shl (i * 4)
				if cbyte( sf16) = 0  Then wmmx->wCASF Or= &h4ul Shl (i * 4)
				if (sf16 And &h0100) Then wmmx->wCASF Or= &h2ul Shl (i * 4)
				sf16 Shr = 7 
				sf16 And= 3 
				if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
         Next

		case &b0100 	'WADD.h
			for i = 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i))) + clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i))) 
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32
				if   CShort( sf32) < 0  Then wmmx->wCASF Or= &h80ul Shl (i * 8)
				if   CShort( sf32)=0    Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (sf32 And &h010000l) Then wmmx->wCASF Or= &h20ul Shl (i * 8)
				sf32 Shr = 15 
				sf32 And= 3 
				if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
         Next
		
		case &b1000 	'WADD.w
			for i = 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i))) + Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i))) 
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if   clng( sf64) < 0         Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
				if   clng( sf64) = 0         Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (sf64 And &h0100000000ll) Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
				sf64 Shr = 31 
				sf64 And= 3 
				if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
         Next
		
		case &b0001 	'WADDUS.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) ) + CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if (sf16 Shr 8) Then 
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = &hff 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
					wmmx->wCSSF Or= 1 Shl i 
				else
					if   cbyte( sf16) < 0  Then wmmx->wCASF Or= &h8ul Shl (i * 4)
					if   Cbyte( sf16) = 0  Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (sf16 And &h0100)   Then wmmx->wCASF Or= &h2ul Shl (i * 4)
					sf16 Shr = 7 
					sf16 And= 3 
					if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
				EndIf
         Next
		
		case &b0101 	'WADDUS.h
			For i= 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) ) + clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32 
				if (sf32 Shr 16) Then 
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = &hffff 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				else
					if   CShort( sf32) < 0  Then wmmx->wCASF Or= &h80ul Shl (i * 8)
					if   CShort( sf32) = 0  Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (sf32 And &h010000l) Then wmmx->wCASF Or= &h20ul Shl (i * 8)
					sf32 Shr = 15 
					sf32 And= 3 
					if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
				EndIf
         Next
		
		case &b1001 	'WADDUS.w
			For i= 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i))) + Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i))) 
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if (sf64 Shr 32) Then 
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = &hffffffl 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				else
					if   clng( sf64) < 0         Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
					if   clng( sf64) = 0         Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (sf64 And &h0100000000ll) Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
					sf64 Shr = 31 
					sf64 And= 3 
					if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
				EndIf
         Next
		
		case &b0011 	'WADDSS.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) ) + CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if (sf16 > &h7f) Then   
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = &h7f 
					wmmx->wCSSF Or= 1 Shl i 
				ElseIf (sf16 < -&h80) Then
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = -&h80 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
					wmmx->wCSSF Or= 1 Shl i 
				else
					if   cbyte( sf16) < 0  Then wmmx->wCASF Or= &h8ul Shl (i * 4)
					if   cbyte( sf16) = 0  Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (sf16 And &h0100)   Then wmmx->wCASF Or= &h2ul Shl (i * 4)
					sf16 Shr = 7 
					sf16 And= 3 
					if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
				EndIf
         Next
		
		case &b0111 	'WADDSS.h
			For i= 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) ) + clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32
				if (sf32 > &h7fff) Then   
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = &h7fff 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				ElseIf  (sf32 < -&h8000) Then
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = -&h8000 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				else
					if   CShort( sf32) < 0  Then wmmx->wCASF Or= &h80ul Shl (i * 8)
					if   CShort( sf32) = 0  Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (sf32 And &h010000l) Then wmmx->wCASF Or= &h20ul Shl (i * 8)
					sf32 Shr = 15 
					sf32 And= 3 
					if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
				EndIf
         Next
		
		case &b1011 	'WADDSS.w
			For i= 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i)) ) + Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i)) )
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if (sf64 > &h7fffffffl) Then   
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = &h7fffffffl 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				ElseIf  (sf64 < -&h80000000l) Then
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = -&h80000000l 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				else
					if clng( sf64) < 0           Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
					if clng( sf64) = 0           Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (sf64 And &h0100000000ll) Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
					sf64 Shr = 31 
					sf64 And= 3 
					if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
				EndIf
         Next
		
		case else 
			return false 
   End Select

	pxa270wmmxPrvControlRegsChanged(wmmx) 
	pxa270wmmxPrvDataRegsChanged(wmmx) 
	return true 
End Function



Function pxa270wmmxPrvDataProcessingSubtraction(wmmx As Pxa270wmmx  Ptr , op1 As Ubyte , CRd As Ubyte , CRn As Ubyte , CRm As Ubyte) As Bool
	Dim As Ubyte   i 
	Dim As Short   sf16 
	Dim As Long    sf32 
	Dim As LongInt sf64 
	
	wmmx->wCASF = 0 
	Select Case As Const  (op1)  
		
		case &b0000 	'WSUB.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) ) - CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if cbyte( sf16) < 0    Then wmmx->wCASF Or= &h8ul Shl (i * 4)
				if cbyte( sf16) = 0    Then wmmx->wCASF Or= &h4ul Shl (i * 4)
				if (sf16 And &h0100)=0 Then wmmx->wCASF Or= &h2ul Shl (i * 4)
				sf16 Shr = 7 
				sf16 And= 3 
				if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
         Next
		
		case &b0100 	'WSUB.h
			For i= 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) ) - clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32
				if CShort( sf32) < 0      Then wmmx->wCASF Or= &h80ul Shl (i * 8)
				if CShort( sf32) = 0      Then wmmx->wCASF Or= &h40ul Shl (i * 8)
				if (sf32 And &h010000l)=0 Then wmmx->wCASF Or= &h20ul Shl (i * 8)
				sf32 Shr = 15 
				sf32 And= 3 
				if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
         Next
		
		case &b1000 	'WSUB.w
			For i= 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i)) ) - Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i)) ) 
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if clng( sf64) < 0             Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
				if clng( sf64) = 0             Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
				if (sf64 And &h0100000000ll)=0 Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
				sf64 Shr = 31 
				sf64 And= 3 
				if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
         Next
		
		case &b0001 	'WSUBUS.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) ) - CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if (sf16 Shr 8) Then 
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = &hff 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
					wmmx->wCSSF Or= 1 Shl i 
				else
					if  cbyte( sf16) < 0   Then wmmx->wCASF Or= &h8ul Shl (i * 4)
					if  Cbyte( sf16) = 0   Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (sf16 And &h0100)=0 Then wmmx->wCASF Or= &h2ul Shl (i * 4)
					sf16 Shr = 7 
					sf16 And= 3 
					if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
				EndIf
         Next
		
		case &b0101 	'WSUBUS.h
			For i= 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) ) - clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32
				if (sf32 Shr 16) Then 
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = &hffff 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				else
					if  CShort( sf32) < 0     Then wmmx->wCASF Or= &h80ul Shl (i * 8)
					if  CShort( sf32) = 0     Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (sf32 And &h010000l)=0 Then wmmx->wCASF Or= &h20ul Shl (i * 8)
					sf32 Shr = 15 
					sf32 And= 3 
					if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
				EndIf
         Next
		
		case &b1001 	'WSUBUS.w
			For i= 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i)) ) - Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i)) )
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if (sf64 Shr 32) Then 
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = &hffffffl 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				else
					if clng( sf64) < 0             Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
					if clng( sf64) = 0             Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (sf64 And &h0100000000ll)=0 Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
					sf64 Shr = 31 
					sf64 And= 3 
					if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
				EndIf
         Next 
		
		case &b0011 	'WSUBSS.b
			For i= 0 To 7         
				sf16 = CShort( wmmx->wR(CRn).s8(ACCESS_REG_8(i)) ) - CShort( wmmx->wR(CRm).s8(ACCESS_REG_8(i)) )
				wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = sf16
				if (sf16 > &h7f) Then   
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = &h7f 
					wmmx->wCSSF Or= 1 Shl i 
				ElseIf  (sf16 < -&h80) Then
					wmmx->wR(CRd).s8(ACCESS_REG_8(i)) = -&h80 
					wmmx->wCASF Or= &h8ul Shl (i * 4) 
					wmmx->wCSSF Or= 1 Shl i 
				else
					if cbyte( sf16) < 0    Then wmmx->wCASF Or= &h8ul Shl (i * 4)
					if cbyte( sf16) = 0    Then wmmx->wCASF Or= &h4ul Shl (i * 4)
					if (sf16 And &h0100)=0 Then wmmx->wCASF Or= &h2ul Shl (i * 4)
					sf16 Shr = 7 
					sf16 And= 3 
					if (sf16 <> 0) AndAlso (sf16 <> 3) Then wmmx->wCASF Or= &h1ul Shl (i * 4)
				EndIf
         Next
		
		case &b0111 	'WSUBSS.h
			For i= 0 To 3         
				sf32 = clng( wmmx->wR(CRn).s16(ACCESS_REG_16(i)) ) - clng( wmmx->wR(CRm).s16(ACCESS_REG_16(i)) )
				wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = sf32
				if (sf32 > &h7fff) Then   
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = &h7fff 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				ElseIf  (sf32 < -&h8000) Then
					wmmx->wR(CRd).s16(ACCESS_REG_16(i)) = -&h8000 
					wmmx->wCASF Or= &h80ul Shl (i * 8) 
					wmmx->wCSSF Or= 1 Shl (2 * i) 
				else
					if CShort( sf32) < 0      Then wmmx->wCASF Or= &h80ul Shl (i * 8)
					if CShort( sf32) = 0      Then wmmx->wCASF Or= &h40ul Shl (i * 8)
					if (sf32 And &h010000l)=0 Then wmmx->wCASF Or= &h20ul Shl (i * 8)
					sf32 Shr = 15 
					sf32 And= 3 
					if (sf32 <> 0) AndAlso (sf32 <> 3) Then wmmx->wCASF Or= &h10ul Shl (i * 8)
				EndIf
         Next
		
		case &b1011 	'WSUBSS.w
			For i= 0 To 1         
				sf64 = Clngint(wmmx->wR(CRn).s32(ACCESS_REG_32(i)) ) - Clngint(wmmx->wR(CRm).s32(ACCESS_REG_32(i)) )
				wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = sf64
				if (sf64 > &h7fffffffl) Then   
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = &h7fffffffl 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				ElseIf  (sf64 < -&h80000000l) Then
					wmmx->wR(CRd).s32(ACCESS_REG_32(i)) = -&h80000000l 
					wmmx->wCASF Or= &h8000ul Shl (i * 16) 
					wmmx->wCSSF Or= 1 Shl (4 * i) 
				else
					if clng( sf64) < 0             Then wmmx->wCASF Or= &h8000ul Shl (i * 16)
					if clng( sf64) = 0             Then wmmx->wCASF Or= &h4000ul Shl (i * 16)
					if (sf64 And &h0100000000ll)=0 Then wmmx->wCASF Or= &h2000ul Shl (i * 16)
					sf64 Shr = 31 
					sf64 And= 3 
					if (sf64 <> 0) AndAlso (sf64 <> 3) Then wmmx->wCASF Or= &h1000ul Shl (i * 16)
				EndIf
         Next
		
		case else 
			return false 
   End Select

	pxa270wmmxPrvControlRegsChanged(wmmx) 
	pxa270wmmxPrvDataRegsChanged(wmmx) 
	return true 
End Function

Function pxa270wmmxPrvDataProcessing0(cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , op1 As UByte , CRd As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
   Dim As Pxa270wmmx ptr wmmx = cast(Pxa270wmmx ptr , userData )
	
	if (two) Then return false

	Select Case As Const  (op2)  
		case &b000 
			return pxa270wmmxPrvDataProcessingMisc(wmmx, op1, CRd, CRn, CRm) 
		
		case &b001 
			return pxa270wmmxPrvDataProcessingAlign(wmmx, op1, CRd, CRn, CRm) 
			
		case &b010 
			return pxa270wmmxPrvDataProcessingShift(wmmx, false, op1, CRd, CRn, CRm) 
		
		case &b011 
			return pxa270wmmxPrvDataProcessingCompare(wmmx, op1, CRd, CRn, CRm) 
		
		case &b100 
			return pxa270wmmxPrvDataProcessingPack(wmmx, op1, CRd, CRn, CRm) 
		
		case &b110 
			return pxa270wmmxPrvDataProcessingUnpack(wmmx, false, op1, CRd, CRn, CRm) 
		
		case &b111 
			return pxa270wmmxPrvDataProcessingUnpack(wmmx, true, op1, CRd, CRn, CRm) 
		
		case else 
			return false 
	
   End Select

	return true 
End Function

Function pxa270wmmxPrvDataProcessing1(cpu As ArmCpu Ptr , userData As Any Ptr , two As Bool , op1 As UByte , CRd As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
   Dim As Pxa270wmmx ptr wmmx = cast(Pxa270wmmx ptr , userData )
	
	if (two) Then return false

	Select Case As Const  (op2)  
		case &b000 
			return pxa270wmmxPrvDataProcessingMultiply(wmmx, op1, CRd, CRn, CRm) 
		
		case &b001 
			return pxa270wmmxPrvDataProcessingDifference(wmmx, op1, CRd, CRn, CRm) 
		
		case &b010 
			return pxa270wmmxPrvDataProcessingShift(wmmx, true, op1, CRd, CRn, CRm) 
		
		case &b011 
			return pxa270wmmxPrvDataProcessingMinMax(wmmx, op1, CRd, CRn, CRm) 
		
		case &b100 
			return pxa270wmmxPrvDataProcessingAddition(wmmx, op1, CRd, CRn, CRm) 
		
		case &b101 
			return pxa270wmmxPrvDataProcessingSubtraction(wmmx, op1, CRd, CRn, CRm) 
		
		case &b110 
			return pxa270wmmxPrvDataProcessingAccumulate(wmmx, op1, CRd, CRn, CRm) 
		
		case &b111 
			return pxa270wmmxPrvDataProcessingShuffle(wmmx, op1, CRd, CRn, CRm) 
		
		case else 
			return false 
	
  End Select

End Function


Sub pxa270wmmxPrvSetCoreReg(cpu As ArmCpu Ptr , reg As Ubyte , valor As ULong)
	if (reg = 15) Then 
		valor And= &hf0000000ul 
		valor Or= cpuGetRegExternal(cpu, ARM_REG_NUM_CPSR) And  INV( &hf0000000ul )
		reg = ARM_REG_NUM_CPSR 
	EndIf
	cpuSetReg(cpu, reg, valor) 
End Sub


Function pxa270wmmxPrvRegXferTmcrTmrc(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , reads As Bool , op1 As Ubyte , Rx As Ubyte , CRn As Ubyte) As Bool
	Dim As ULong valor = 0 
	
	Select Case As Const (CRn)  
		case &b0000 	'wCID
			if (reads) Then 
				valor = &h69051000ul 
			else
				return false
			EndIf
		
		case &b0001 	'wCON
			if (reads) Then 
				valor = wmmx->wCon 
			else
				wmmx->wCon = valor And 3
			EndIf
		
		case &b0010 	'wCSSF
			if (reads) Then 
				valor = wmmx->wCSSF 
			else
				wmmx->wCSSF = valor And &hff
			EndIf
		
		case &b0011 	'wCASF:
			if (reads) Then 
				valor = wmmx->wCASF 
			else
				wmmx->wCASF = valor
			EndIf
		
		case &b1000 ,_	'wCGR[0..3]
			  &b1001 ,_
			  &b1010 ,_
			  &b1011 
			if (reads) Then 
				valor = wmmx->wCGR(CRn - 8) 
			else
				wmmx->wCGR(CRn - 8) = valor
			EndIf
		
		case else 
			return false 
	
   End Select

	if (reads) Then pxa270wmmxPrvSetCoreReg(cpu, Rx, valor)
	
	return true 
End Function

Function pxa270wmmxPrvRegXferTmia(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op2 As Ubyte , wRd As Ubyte , Rs As Ubyte , Rm As Ubyte) As Bool
	Dim As ULong vM = cpuGetRegExternal(cpu, Rm) 
	Dim As ULong vS = cpuGetRegExternal(cpu, Rs) 
	
	Select Case As Const (op2)  
		case &b0000 	'TMIA
			wmmx->wR(wRd).s64 += clngint( clng  ( vM )) * clngint( clng  ( vS ))
		
		case &b1000 	'TMIAPH
			wmmx->wR(wRd).s64 += clngint( CShort( vM )) * clngint( CShort( vS )) + clngint( CShort( (vM Shr 16) )) * clngint( CShort( (vS Shr 16) ))
		
		case &b1100,_ 	'TMIABB
			  &b1101,_ 	'TMIABT
			  &b1110,_ 	'TMIATB
			  &b1111 	'TMIATT
			if (op2 And 1) Then vS Shr = 16
			if (op2 And 2) Then vM Shr = 16
			wmmx->wR(wRd).s64 += clngint( CShort( vM )) * clngint( CShort( vS ))
		
		case else 
			return false 
	
   End Select

	return true 
End Function

Function pxa270wmmxPrvRegXferTorc(wmmx As Pxa270wmmx  Ptr , cpu As ArmCpu  Ptr , op1 As Ubyte , Rd As Ubyte) As Bool
	Dim As ULong valor = wmmx->wCASF 
	
	Select Case As Const (op1)  
		
		' suma de los tres CASES
		case  &b000 ,_		'TORCB
				&b010 ,_    'TORCH
				&b100       'TORCW
			if (op1=&b000)                    then valor Or= valor Shl 4 ' caso 000 
			if (op1=&b000) orelse (op1=&b010) then valor Or= valor Shl 8  'caso 010 y ademas de nuevo si es 000
			valor Or = valor Shl 16  ' caso 100 y ademas 000 o 010 si salen
			valor And= &hf0000000ul 
			pxa270wmmxPrvSetCoreReg(cpu, Rd, valor) 
			return true 
		
		case else 
			return false 
	
   End Select

End Function

Function pxa270wmmxPrvRegXferTandc(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , Rd As Ubyte) As Bool
	Dim As ULong valor = wmmx->wCASF 
	
	Select Case As Const  (op1)  
		
		' suma de los tres CASES
		case  &b000 ,_		'TORCB
				&b010 ,_    'TORCH
				&b100       'TORCW
			if (op1=&b000)                    then valor and= valor Shl 4 ' caso 000 
			if (op1=&b000) orelse (op1=&b010) then valor and= valor Shl 8  'caso 010 y ademas de nuevo si es 000
			valor And= valor Shl 16 ' este en todos los casos se hace
			valor And= &hf0000000ul 
			pxa270wmmxPrvSetCoreReg(cpu, Rd, valor) 
			return true 
		
		case else 
			return false 
	
   End Select

End Function

Function pxa270wmmxPrvRegXferTextrc(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , Rd As Ubyte , imm3 As Ubyte) As Bool
	Dim As ULong valor = wmmx->wCASF 
	
	Select Case As Const  (op1)  
		case &b000 		'TEXTRCB
			valor Shr = imm3 * 4 
		
		case &b010 		'TEXTRCH
			valor Shr = (imm3 And 3) * 8 + 4 
			
		case &b100 		'TEXTRCW
			valor Shr = (imm3 And 1) * 16 + 12 
		
		case else 
			return false 
	
   End Select

	valor Shl = 28 
	pxa270wmmxPrvSetCoreReg(cpu, Rd, valor) 
	return true 
End Function

Function pxa270wmmxPrvRegXferTextrm(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , Rd As Ubyte , wRn As Ubyte , sext As Bool , imm3 As Ubyte) As Bool
	Dim As ULong valor 
	
	Select Case As Const  (op1)  
		case &b000 		'TEXTRMB
			if (sext) Then 
				valor = clng( wmmx->wR(wRn).s8(ACCESS_REG_8(imm3)) )
			else
				valor = wmmx->wR(wRn).v8(ACCESS_REG_8(imm3))
			EndIf
		
		case &b010 		'TEXTRMH
			imm3 And= 3 
			if (sext) Then 
				valor = clng( wmmx->wR(wRn).s16(ACCESS_REG_16(imm3)) )
			else
				valor = wmmx->wR(wRn).v16(ACCESS_REG_16(imm3))
			EndIf
			
		case &b100 		'TEXTRMW
			valor = wmmx->wR(wRn).v32(ACCESS_REG_32(imm3 And 1)) 
		
		case else 
			return false 
	
  End Select

	pxa270wmmxPrvSetCoreReg(cpu, Rd, valor) 
	return true 
End Function

Function pxa270wmmxPrvRegXferTbcst(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , wRd As Ubyte , Rn As Ubyte) As Bool
	Dim As ULong v = cpuGetRegExternal(cpu, Rn) 
	Dim As Ubyte i 
	
	Select Case As Const (op1)  
		case &b000 		'TBCSTB
			For i= 0 To 7       
				wmmx->wR(wRd).v8(ACCESS_REG_8(i)) = v
         Next
		
		case &b010 		'TBCSTH
			For i= 0 To 3       
				wmmx->wR(wRd).v16(ACCESS_REG_16(i)) = v
         Next
			
		case &b100 		'TBCSTW
			For i= 0 To 1       
				wmmx->wR(wRd).v32(ACCESS_REG_32(i)) = v
         Next
		
		case else 
			return false 
	
  End Select

	pxa270wmmxPrvDataRegsChanged(wmmx) 
	return true 
End Function

Function pxa270wmmxPrvRegXferTinsr(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , wRd As Ubyte , Rn As Ubyte , at As Ubyte) As Bool
	Dim As ULong v = cpuGetRegExternal(cpu, Rn) 
	
	Select Case As Const  (op1)  
		case &b000 		'TBCSTB
			wmmx->wR(wRd).v8(ACCESS_REG_8(at And 7)) = v 
		
		case &b010 		'TBCSTH
			wmmx->wR(wRd).v16(ACCESS_REG_16(at And 3)) = v 
			
		case &b100 		'TBCSTW
			wmmx->wR(wRd).v32(ACCESS_REG_32(at And 1)) = v 
		
		case else 
			return false 
	
   End Select

	pxa270wmmxPrvDataRegsChanged(wmmx) 
	return true 
End Function

Function pxa270wmmxPrvRegXferTmovmsk(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , op1 As Ubyte , Rd As Ubyte , wRn As Ubyte) As Bool
	Dim As Ubyte valor = 0, i 
	
	Select Case As Const  (op1)  
		case &b000 		'TMOVMSKB
			For i= 0 To 7         
				if (wmmx->wR(wRn).s8(ACCESS_REG_8(i)) < 0)   Then valor Or= 1 Shl i
         Next
		
		case &b010 		'TMOVMSKH
			For i= 0 To 3         
				if (wmmx->wR(wRn).s16(ACCESS_REG_16(i)) < 0) Then valor Or= 1 Shl i
         Next
			
		case &b100 		'TMOVMSKW
			For i= 0 To 1         
				if (wmmx->wR(wRn).s32(ACCESS_REG_32(i)) < 0) Then valor Or= 1 Shl i
         Next
		
		case else 
			return false 
	
   End Select

	pxa270wmmxPrvSetCoreReg(cpu, Rd, valor) 
	return true 
End Function

Function pxa270wmmxPrvRegXfer(wmmx As Pxa270wmmx Ptr , cp1 As Bool , cpu As ArmCpu  Ptr , two As Bool , reads As Bool , op1 As UByte , Rx As UByte , CRn As UByte , CRm As UByte , op2 As UByte) As Bool
	if (two) Then return false

	Select Case As Const (op1)  
		case &b000 				'TMCR \ TMRC
			if (op2<>0) OrElse (cp1=0) OrElse (CRm<>0) OrElse ((CRn And 4)<>0) Then return false
			return pxa270wmmxPrvRegXferTmcrTmrc(wmmx, cpu, reads, op1, Rx, CRn) 
		
		case &b001 				'TMIA...
			if (reads) Then return false
			return pxa270wmmxPrvRegXferTmia(wmmx, cpu, CRn, op2 + iif(cp1 , 8 , 0), Rx, CRm) 
		
		case else 
			return false 
   End Select

	if (reads) Then  
		Select Case As Const (op2)  			'dispatch MRC
			case &b001 
				if CRm Then return false
				if cp1 Then return pxa270wmmxPrvRegXferTandc(wmmx, cpu, op1, Rx)
				return pxa270wmmxPrvRegXferTmovmsk(wmmx, cpu, op1, Rx, CRn) 
			
			case &b010 
				if (cp1=0) OrElse (CRm<>0) Then return false
				return pxa270wmmxPrvRegXferTorc(wmmx, cpu, op1, Rx) 
			
			case &b011 
				if (op1 And 1) Then return false
				if (cp1=0)     Then return pxa270wmmxPrvRegXferTextrm(wmmx, cpu, op1, Rx, CRn, NOT_NOT(CRm And 8), CRm And 7)
				if (CRm And 8) Then return false
				return pxa270wmmxPrvRegXferTextrc(wmmx, cpu, op1, Rx, CRm) 
			
			case else
				return false 
	   end select
	ElseIf (cp1) Then 
		return false 
	else
      Select Case As Const (op1)  					'dispatch MCR
			case &b010 
				if (CRm) Then return false
				return pxa270wmmxPrvRegXferTbcst(wmmx, cpu, op1, CRn, Rx) 
			
			case &b011 
				if (CRm And 8) Then return false
				return pxa270wmmxPrvRegXferTinsr(wmmx, cpu, op1, CRn, Rx, CRm) 
			
			case else 
				return false
		end select
	EndIf
  
End Function

Function pxa270wmmxPrvTwoReg(wmmx As Pxa270wmmx Ptr , cp1 As Bool , cpu As ArmCpu Ptr , reads As Bool , op As UByte , RdLo As UByte , RdHi As UByte , wR As UByte) As Bool
	if (cp1<>0) OrElse (op<>0) Then return false

	if (reads) Then 
		pxa270wmmxPrvSetCoreReg(cpu, RdLo, wmmx->wR(wR).v32(ACCESS_REG_32(0))) 
		pxa270wmmxPrvSetCoreReg(cpu, RdHi, wmmx->wR(wR).v32(ACCESS_REG_32(1))) 
	else
		wmmx->wR(wR).v32(ACCESS_REG_32(0)) = cpuGetRegExternal(cpu, RdLo) 
		wmmx->wR(wR).v32(ACCESS_REG_32(1)) = cpuGetRegExternal(cpu, RdHi) 
		pxa270wmmxPrvDataRegsChanged(wmmx) 
	EndIf
 
	return false 
End Function

Function pxa270wmmxPrvMemAccessControl(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , store As Bool , addr As ULong , reg As Ubyte) As Bool
	Dim As ULong valor = 0 
	
	if (store=0) AndAlso (cpuMemOpExternal(cpu, @valor, addr, 4, false)=0) Then return false

	Select Case As Const (reg)  
		case &b0000 	'wCID
			if (store) Then 
				valor = &h69051000ul 
			else
				return false
			EndIf
		
		case &b0001 	'wCON
			if (store) Then 
				valor = wmmx->wCon 
			else
				wmmx->wCon = valor And 3
			EndIf
		
		case &b0010 	'wCSSF
			if (store) Then 
				valor = wmmx->wCSSF 
			else
				wmmx->wCSSF = valor And &hff
			EndIf 
		
		case &b0011 	'wCASF:
			if (store) Then 
				valor = wmmx->wCASF 
			else
				wmmx->wCASF = valor
			EndIf
		
		case &b1000 ,_	'wCGR[0..3]
			  &b1001 ,_
			  &b1010 ,_
			  &b1011 
			if (store) Then 
				valor = wmmx->wCGR(reg - 8) 
			else
				wmmx->wCGR(reg - 8) = valor
			EndIf
		
		case else 
			return false 
	
   End Select

	if (store) Then pxa270wmmxPrvControlRegsChanged(wmmx)

	return iif((store=0) OrElse (cpuMemOpExternal(cpu, @valor, addr, 4, true) <>0),1,0)
End Function

Function pxa270wmmxPrvMemAccessDataD(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , store As Bool , ea As ULong , wR As Ubyte) As Bool
	if ( cpuMemOpExternal(cpu, @wmmx->wR(wR).v32(ACCESS_REG_32(0)), ea + 0, 4, store)=0) Then return false
	if ( cpuMemOpExternal(cpu, @wmmx->wR(wR).v32(ACCESS_REG_32(1)), ea + 4, 4, store)=0) Then return false
	if ( store=0) Then pxa270wmmxPrvDataRegsChanged(wmmx)

	return true 
End Function

Function pxa270wmmxPrvMemAccessDataW(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , store As Bool , ea As ULong , wR As Ubyte) As Bool
	if ( cpuMemOpExternal(cpu, @wmmx->wR(wR).v32(ACCESS_REG_32(0)), ea, 4, store)=0) Then return false
	if ( store=0) Then 
		wmmx->wR(wR).v32(ACCESS_REG_32(1)) = 0 
		pxa270wmmxPrvDataRegsChanged(wmmx) 
	EndIf

	return true 
End Function

Function pxa270wmmxPrvMemAccessDataH(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , store As Bool , ea As ULong , wR As Ubyte) As Bool
	if ( cpuMemOpExternal(cpu, @wmmx->wR(wR).v16(ACCESS_REG_16(0)), ea, 2, store)=0) Then return false
	if ( store=0) Then 
		Dim As Ubyte i 
		For i= 1 To 3       
			wmmx->wR(wR).v16(ACCESS_REG_16(i)) = 0
      Next
		pxa270wmmxPrvDataRegsChanged(wmmx) 
	EndIf

	return true 
End Function

Function pxa270wmmxPrvMemAccessDataB(wmmx As Pxa270wmmx Ptr , cpu As ArmCpu Ptr , store As Bool , ea As ULong , wR As Ubyte) As Bool
	if ( cpuMemOpExternal(cpu, @wmmx->wR(wR).v8(ACCESS_REG_8(0)), ea, 1, store)=0) Then return false
	if ( store=0) Then 
		Dim As Ubyte i 
		For i= 1 To 7       
			wmmx->wR(wR).v8(ACCESS_REG_8(i)) = 0
      Next
		pxa270wmmxPrvDataRegsChanged(wmmx) 
	EndIf
	
	return true 
End Function

Function pxa270wmmxPrvMemAccess(wmmx As Pxa270wmmx Ptr , cp1 As Bool , cpu As ArmCpu Ptr , two As Bool , N As Bool , store As Bool , wR As UByte , addrReg As Ubyte , addBefore As ULong , addAfter As ULong , options As UByte Ptr) As Bool
	Dim As ULong ea = cpuGetRegExternal(cpu, addrReg) 
	
	if (two=0) Then 
  		'access to data regs
		if (cp1) Then 
			ea += addBefore * 4 
			if (N) Then 
				if pxa270wmmxPrvMemAccessDataD(wmmx, cpu, store, ea, wR)=0 Then return false 
			else
				if pxa270wmmxPrvMemAccessDataW(wmmx, cpu, store, ea, wR)=0 Then return false
			EndIf
			if (addAfter) Then pxa270wmmxPrvSetCoreReg(cpu, addrReg, ea - addBefore * 4 + addAfter * 4) 
		else
			ea += addBefore
			if (N) Then 
				if pxa270wmmxPrvMemAccessDataH(wmmx, cpu, store, ea, wR)=0 Then return false 
			else
				if pxa270wmmxPrvMemAccessDataB(wmmx, cpu, store, ea, wR)=0 Then return false
			EndIf
			if (addAfter) Then pxa270wmmxPrvSetCoreReg(cpu, addrReg, ea - addBefore + addAfter)
		EndIf
		pxa270wmmxPrvDataRegsChanged(wmmx) 
		return true 
	EndIf
  
	if (cp1<>0) OrElse (N<>0) Then return false

	'access to control regs
	if pxa270wmmxPrvMemAccessControl(wmmx, cpu, store, ea + addBefore * 4, wR)=0 Then return false

	if (addAfter) Then pxa270wmmxPrvSetCoreReg(cpu, addrReg, ea + addAfter * 4)

	return true 
End Function


Function pxa270wmmxPrvRegXfer0(cpu As ArmCpu Ptr, userData As Any Ptr, two As Bool, MRC As Bool, op1 As UByte, Rx As UByte, CRn As UByte, CRm As UByte, op2 As UByte) As Bool
	return pxa270wmmxPrvRegXfer(cast(Pxa270wmmx ptr, userData), false, cpu, two, MRC, op1, Rx, CRn, CRm, op2) 
End Function

Function pxa270wmmxPrvRegXfer1(cpu As ArmCpu  Ptr, userData As Any Ptr, two As Bool, MRC As Bool, op1 As UByte, Rx As UByte, CRn As UByte, CRm As UByte, op2 As UByte) As Bool
	return pxa270wmmxPrvRegXfer(cast(Pxa270wmmx ptr, userData), true, cpu, two, MRC, op1, Rx, CRn, CRm, op2) 
End Function

Function pxa270wmmxPrvMemAccess0(cpu As ArmCpu  Ptr, userData As Any Ptr, two As Bool, N As Bool, store As Bool, CRd As UByte, addrReg As Ubyte, addBefore As ULong, addAfter As ULong, options As UByte Ptr) As Bool
	return pxa270wmmxPrvMemAccess(cast(Pxa270wmmx ptr, userData), false, cpu, two, N, store, CRd, addrReg, addBefore, addAfter, options) 
End Function

Function pxa270wmmxPrvMemAccess1(cpu As ArmCpu  Ptr, userData As Any Ptr, two As Bool, N As Bool, store As Bool, CRd As UByte, addrReg As Ubyte, addBefore As ULong, addAfter As ULong, options As UByte Ptr) As Bool
	return pxa270wmmxPrvMemAccess(cast(Pxa270wmmx ptr, userData), true, cpu, two, N, store, CRd, addrReg, addBefore, addAfter, options) 
End Function

Function pxa270wmmxPrvTwoReg0(cpu As ArmCpu  Ptr, userData As Any Ptr, MRRC As Bool, op As UByte, Rd As UByte, Rn As UByte, CRm As UByte) As Bool
	return pxa270wmmxPrvTwoReg(cast(Pxa270wmmx ptr, userData), false, cpu, MRRC, op, Rd, Rn, CRm) 
End Function

Function pxa270wmmxPrvTwoReg1(cpu As ArmCpu  Ptr, userData As Any Ptr, MRRC As Bool, op As UByte, Rd As UByte, Rn As UByte, CRm As UByte) As Bool
	return pxa270wmmxPrvTwoReg(cast(Pxa270wmmx ptr, userData), true, cpu, MRRC, op, Rd, Rn, CRm) 
End Function


Function pxa270wmmxInit( cpu as ArmCpu ptr) as Pxa270wmmx ptr
	dim as Pxa270wmmx ptr wmmx = cast(Pxa270wmmx ptr,Callocate(sizeof(Pxa270wmmx)))
	
	Dim as ArmCoprocessor cp0 
	with cp0
		.regXfer        = cast(ArmCoprocRegXferF ,@pxa270wmmxPrvRegXfer0)
		.dataProcessing = cast(ArmCoprocDatProcF ,@pxa270wmmxPrvDataProcessing0)
		.memAccess      = cast(ArmCoprocMemAccsF ,@pxa270wmmxPrvMemAccess0)
		.twoRegF        = cast(ArmCoprocTwoRegF  ,@pxa270wmmxPrvTwoReg0)
		.userData 		 = wmmx
		'.userData 		 = cast(any ptr,@wmmx)
   End With
		
	Dim as ArmCoprocessor cp1
	with cp1
		.regXfer        = cast(ArmCoprocRegXferF ,@pxa270wmmxPrvRegXfer1)
		.dataProcessing = cast(ArmCoprocDatProcF ,@pxa270wmmxPrvDataProcessing1)
		.memAccess      = cast(ArmCoprocMemAccsF ,@pxa270wmmxPrvMemAccess1)
		.twoRegF        = cast(ArmCoprocTwoRegF  ,@pxa270wmmxPrvTwoReg1)
		.userData 		 = wmmx
		'.userData 		 = cast(any ptr,@wmmx)
   End With
	
	if wmmx=0 then PERR("cannot alloc WMMX CP0\1") 
	
	memset(wmmx, 0, sizeof(Pxa270wmmx)) 
	
	cpuCoprocessorRegister(cpu, 0, @cp0) 
	cpuCoprocessorRegister(cpu, 1, @cp1) 
	
	return wmmx 
End function
