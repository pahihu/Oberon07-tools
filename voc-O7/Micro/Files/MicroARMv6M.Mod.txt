MODULE MicroARMv6M;

	(*
		Alexander Shiryaev, 2014.09, 2017.03

		ARMv6-M Architecture Reference Manual
http://ecee.colorado.edu/ecen3000/labs/lab3/files/DDI0419C_arm_architecture_v6m_reference_manual.pdf
	*)

	IMPORT SYSTEM;

	CONST
		(* B1.5.2. exception numbers *)
			Reset* = 1;
			NMI* = 2;
			HardFault* = 3;
			SVCall* = 11;
			PendSV* = 14;
			SysTick* = 15;
			ExternalInterrupt0* = 16;

		ACTLR* = 0E000E008H; (* auxiliary control register *)
		CPUID* = 0E000ED00H; (* CPUID base register *)
		ICSR* = 0E000ED04H; (* interrupt control state register *)
		VTOR* = 0E000ED08H; (* vector table offset register *)
		AIRCR* = 0E000ED0CH; (* application interrupt and reset control register *)
		SCR* = 0E000ED10H; (* optional system control register *)
		CCR* = 0E000ED14H; (* configuration and control register *)
		SHPR2* = 0E000ED1CH; (* system handler register 2 *)
		SHPR3* = 0E000ED20H; (* system handler register 3 *)
		SHCSR* = 0E000ED24H; (* system handler control and state register *)
		DFSR* = 0E000ED30H; (* debug fault status register *)

		SYSTCSR* = 0E000E010H; (* SysTick control and status register *)
		SYSTRVR* = 0E000E014H; (* SysTick reload value register *)
		SYSTCVR* = 0E000E018H; (* SysTick current value register *)
		SYSTCALIB* = 0E000E01CH; (* SysTick calibration value register *)

		NVICISER* = 0E000E100H; (* interrupt set-enable register *)
		NVICICER* = 0E000E180H; (* interrupt clear enable register *)
		NVICISPR* = 0E000E200H; (* interrupt set-pending register *)
		NVICICPR* = 0E000E280H; (* interrupt clear-pending register *)
		NVICIPR0* = 0E000E400H; (* interrupt priority register 0 *)
		NVICIPR1* = 0E000E404H; (* interrupt priority register 1 *)
		NVICIPR2* = 0E000E408H; (* interrupt priority register 2 *)
		NVICIPR3* = 0E000E40CH; (* interrupt priority register 3 *)
		NVICIPR4* = 0E000E410H; (* interrupt priority register 4 *)
		NVICIPR5* = 0E000E414H; (* interrupt priority register 5 *)
		NVICIPR6* = 0E000E418H; (* interrupt priority register 6 *)
		NVICIPR7* = 0E000E41CH; (* interrupt priority register 7 *)

	TYPE
		Command = PROCEDURE;

	VAR
		WFI*: Command;
		DMB*, DSB*, ISB*: Command;
		CPSIEi*, CPSIDi*, CPSIEf*, CPSIDf*, CPSIEif*, CPSIDif*: Command;

BEGIN
	WFI := SYSTEM.VAL(Command, (* WFI; BX LR *)
		SYSTEM.ADR($30 BF 70 47$) + 1 (* Thumb *));

	DMB := SYSTEM.VAL(Command, (* DMB; BX LR *)
		SYSTEM.ADR($BF F3 5F 8F 70 47$) + 1 (* Thumb *));
	DSB := SYSTEM.VAL(Command, (* DSB; BX LR *)
		SYSTEM.ADR($BF F3 4F 8F 70 47$) + 1 (* Thumb *));
	ISB := SYSTEM.VAL(Command, (* ISB; BX LR *)
		SYSTEM.ADR($BF F3 6F 8F 70 47$) + 1 (* Thumb *));

	CPSIEi := SYSTEM.VAL(Command, (* CPSIE i; BX LR *)
		SYSTEM.ADR($62 B6 70 47$) + 1 (* Thumb *));
	CPSIDi := SYSTEM.VAL(Command, (* CPSID i; BX LR *)
		SYSTEM.ADR($72 B6 70 47$) + 1 (* Thumb *));
	CPSIEf := SYSTEM.VAL(Command, (* CPSIE f; BX LR *)
		SYSTEM.ADR($61 B6 70 47$) + 1 (* Thumb *));
	CPSIDf := SYSTEM.VAL(Command, (* CPSID f; BX LR *)
		SYSTEM.ADR($71 B6 70 47$) + 1 (* Thumb *));
	CPSIEif := SYSTEM.VAL(Command, (* CPSIE if; BX LR *)
		SYSTEM.ADR($63 B6 70 47$) + 1 (* Thumb *));
	CPSIDif := SYSTEM.VAL(Command, (* CPSID if; BX LR *)
		SYSTEM.ADR($73 B6 70 47$) + 1 (* Thumb *))
END MicroARMv6M.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroARMv6M.a6m 


O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroARMv6M.a7m 
