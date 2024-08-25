
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>

' __builtin_XXXX
' https:\\gcc.gnu.org\onlinedocs\gcc\Other-Builtins.html

' __builtin_XXXX_overflow
' https:\\gcc.gnu.org\onlinedocs\gcc\Integer-Overflow-Builtins.html

Extern "C"
  'Declare Sub __builtin_unreachable() ' este es necesario? diria que no, es para compilar solo....
	
  'Declare Function __builtin_expect(Byval n As Long) As Long ' idem a la anterior
	
  Declare Function __builtin_ctzll(Byval n As ulongint) As Long
  Declare Function __builtin_clzl (Byval n As ulong) As Long
  Declare Function __builtin_clz  (Byval n As ulong) As Long
  Declare Function __builtin_ctz  (Byval n As ulong) As Long
	
  Declare Function __builtin_saddl_overflow(Byval a As long,Byval b As long,r As long ptr) As Boolean
  Declare Function __builtin_ssubl_overflow(Byval a As long,Byval b As long,r As long ptr) As Boolean
  Declare Function __builtin_uaddl_overflow(Byval a As ulong,Byval b As ulong,r As ulong ptr) As Boolean
  Declare Function __builtin_usubl_overflow(Byval a As ulong,Byval b As ulong,r As ulong ptr) As Boolean
End Extern

'#define unlikely(x)	__builtin_expect((x))

' num. 0's al principio del numero x en 32bits
'function __builtin_clz(x as ulong) as ulong
'	if (x=0) then return 0
'	if (x and &h80000000) then return 0
'	'dim as string xx=bin(x,32)
'	'return instr(xx,"1")-1
'	for f as byte=31 to 0 step -1
'		if bit(x,f) then return 31-f
'	next
'end function

' num. 0's al final del numero x en 32 bits
'function __builtin_ctz(x as ulong) as ulong
'	if (x=0) then return 0
'	if (x and &h00000001) then return 0
'	'dim as string xx=bin(x,32)
'	'return 32-instrrev(xx,"1")
'	for f as byte=0 to 31
'		if bit(x,f) then return f
'	next
'end function

' pruebas
'print bin(&b10000,32)
'print __builtin_clz(&b10000) ' sale 27 ceros
'print __builtin_ctz(&b10000) ' sale 4 ceros
'sleep

'function __builtin_clzl(x as ulong) as ulong
'	if (x=0) then return 0
'	dim as string xx=bin(x,32)
'	print "analizar __builtin_clzl":beep:sleep
'	return instr(xx,"1")-1
'end function

'function __builtin_clzll(x as ulongint) as ulong
'	if (x=0) then return 0
'	dim as string xx=bin(x,64)
'	print "analizar __builtin_clzll":beep:sleep
'	return instr(xx,"1")-1
'end function




function __builtin_add_overflow_i32(a as long,b as long,c as long ptr) As Bool
	return iif(__builtin_saddl_overflow(a,b,c),1,0)
'	dim as longint x=clngint(a)+b
'	*c=clng(x)
'	if (x > 4294967295) then return 1
'	return 0
end function

function __builtin_sub_overflow_i32(a as long,b as long,c as long ptr) As Bool
	return iif(__builtin_ssubl_overflow(a,b,c),1,0)
'	dim as longint x=clngint(a)-b
'	*c=clng(x)
'	if (x < -4294967296) then return 1
'	return 0
end function  

function __builtin_add_overflow_u32(a as ulong,b as ulong,c as ulong ptr) As Bool
	return iif(__builtin_uaddl_overflow(a,b,c),1,0)
'	dim as ulongint x=culngint(a)+b
'	*c=culng(x)
'	if (x and &hffffffff00000000ull) then return 1
'	return 0
end function

function __builtin_sub_overflow_u32(a as ulong,b as ulong,c as ulong ptr) As Bool
	return iif(__builtin_usubl_overflow(a,b,c),1,0)
'	dim as ulongint x=culngint(a)-b
'	*c=culng(x)
'	if (x and &h8000000000000000ull) then return 1
'	return 0
end function  

' pruebas
'dim as long ccc
'print __builtin_add_overflow_i32(&h7f7678f6,&h01000000,@ccc),hex(ccc,8)
'print __builtin_sub_overflow_i32(&hc3f60000,&h7e000000,@ccc),hex(ccc,8)
'print __builtin_sub_overflow_i32(&ha41b815c,&ha6000000,@ccc),hex(ccc,8)
'print &hc3f60000,&h7e000000,ccc
'sleep

'#define __builtin_unreachable() rem ' print "__builtin_unreachable estudiame":beep
'#define __builtin_expect(x,y) iif((x)=0,0,1)
'#define unlikely(x)	__builtin_expect((x),0)


sub MiPrint(cad as string)
	color 13
	print cad
	color 7
end sub

sub PERR(cad as string)
	beep
	color 11
	print cad
	color 7
	sleep
end sub

function INV(aa as Longint) as Longint
	return not(aa)
end function

function NOT_NOT(aa as Longint) as long
	'print aa,not(aa):sleep
	' segun internet y mis pruebas, NOT-NOT es "1" si el valor no es cero
	return iif(aa,1,0)
end function
' ejemplo de prueba de NOT_NOT (comprobado en C)
'print "1 0 1 ->";NOT_NOT(10);NOT_NOT(0);NOT_NOT(-1):sleep

