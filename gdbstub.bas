 '(c) uARM project    https://github.com/uARM-Palm/uARM    uARM@dmitry.gr
' Conversion FREEBASIC (www.freebasic.net) por Joseba Epalza, 2024 <jepalza arroba gmail.com>



' #Include"gdbstub.bi"
' #Include"util.bi"

#define MAX_BREAKPOINTS		16
#define MAX_WATCHPOINTS		16

Type bp 
	As ULong addr 
End Type 

Type wp 
	As ULong addr 
	As UByte size	 	:6 
	As UByte read_ 	:1 
	As UByte write_	:1 
End Type 

enum RunState
	RunStateStopped = 0,
	RunStateSingleStep,
	RunstateRunning,
End Enum

Type stub_t 
   As ArmCpu ptr cpu 
	As Long sock 
End Type 


Sub gdbStubDebugBreakRequested(stub As stub_t Ptr)
	if (stub->sock < 0) Then return
End Sub

Sub gdbStubReportPc(stub As stub_t Ptr , pc As ULong , thumb As Bool)
	if (stub->sock < 0) Then return
End Sub

Sub gdbStubReportMemAccess(stub As stub_t Ptr , addr As ULong , sz As Ubyte , write_ As Bool)
	if (stub->sock < 0) Then return
End Sub

Function gdbStubInit(cpu as ArmCpu ptr, port as long) as stub_t ptr
   dim As stub_t ptr stub = cast(stub_t ptr,Callocate(sizeof(stub_t)) )

	if (stub=0) then PERR("cannot alloc GDBSTUB") 
	
	memset(stub, 0, sizeof(stub_t)) 
	stub->cpu = cpu 
	
	if (port < 0) Then 
		stub->sock = -1 
	'else  
		' nada
	EndIf
  
	return stub 
End function

