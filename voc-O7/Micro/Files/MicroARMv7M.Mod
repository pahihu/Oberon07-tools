MODULE MicroARMv7M;

	(*
		Alexander Shiryaev, 2014.09, 2017.03

		ARMv7-M Architecture Reference Manual
			https://web.eecs.umich.edu/~prabal/teaching/eecs373-f10/readings/ARMv7-M_ARM.pdf
	*)

	IMPORT SYSTEM;

	CONST
		(* B1.5.2: exception numbers *)
			Reset* = 1;
			NMI* = 2;
			HardFault* = 3;
			MemManage* = 4;
			BusFault* = 5;
			UsageFault* = 6;
			SVCall* = 11;
			DebugMonitor* = 12;
			PendSV* = 14;
			SysTick* = 15;
			ExternalInterrupt0* = 16;

		(* B3.2.2 *)
			(* SCB registers *)
				CPUID* = 0E000ED00H; (* CPUID Base Register *)
				ICSR* = 0E000ED04H; (* Interrupt Control and State Register *)
				VTOR* = 0E000ED08H; (* Vector Table Offset Register *)
				AIRCR* = 0E000ED0CH; (* Application Interrupt and Reset Control Register *)
				SCR* = 0E000ED10H; (* System Control Register *)
				CCR* = 0E000ED14H; (* Configuration and Control Register *)
				SHPR1* = 0E000ED18H; (* System Handler Priority Register 1 *)
				SHPR2* = 0E000ED1CH; (* System Handler Priority Register 2 *)
				SHPR3* = 0E000ED20H; (* System Handler Priority Register 3 *)
				SHCSR* = 0E000ED24H; (* System Handler Control and State Register *)
				CFSR* = 0E000ED28H; (* Configurable Fault Status Register *)
				HFSR* = 0E000ED2CH; (* HardFault Status Register *)
				DFSR* = 0E000ED30H; (* Debug Fault Status Register *)
				MMFAR* = 0E000ED34H; (* MemManage Fault Address Register *)
				BFAR* = 0E000ED38H; (* BusFault Address Register *)
				AFSR* = 0E000ED3CH; (* Auxiliary Fault Status Register *)
				CPACR* = 0E000ED88H; (* Coprocessor Access Control Register *)

			(* Additional SCB registers for the FP extension *)			
				FPCCR* = 0E000EF34H; (* Floating-Point Context Control Register *)
				FPCAR* = 0E000EF38H; (* Floating-Point Context Address Register *)
				FPDSCR* = 0E000EF3CH; (* Floating-Point Default Status Control Register *)
				MVFR0* = 0E000EF40H; (* Media and FP Feature Register 0 *)
				MVFR1* = 0E000EF44H; (* Media and FP Feature Register 1 *)

			(* System control and ID registers not in the SCB *)
				ICTR* = 0E000E004H; (* Interrupt Controller Type Register *)
				ACTLR* = 0E000E008H; (* Auxiliary Control Register *)
				STIR* = 0E000EF00H; (* Software Triggered Interrupt Register *)
				(* Peripherial Identification Registers *)
					PID4* = 0E000EFD0H;
					PID5* = 0E000EFD4H;
					PID6* = 0E000EFD8H;
					PID7* = 0E000EFDCH;
					PID0* = 0E000EFE0H;
					PID1* = 0E000EFE4H;
					PID2* = 0E000EFE8H;
					PID3* = 0E000EFECH;
				(* Component Identification Registers *)
					CID0* = 0E000EFF0H;
					CID1* = 0E000EFF4H;
					CID2* = 0E000EFF5H;
					CID3* = 0E000EFFCH;

		(* B3.3.2 *)
			(* SysTick registers *)
				SYSTCSR* = 0E000E010H; (* SysTick Control and Status Register *)
				SYSTRVR* = 0E000E014H; (* SysTick Reload Value Register *)
				SYSTCVR* = 0E000E018H; (* SysTick Current Value Register *)
				SYSTCALIB* = 0E000E01CH; (* SysTick Calibration Value Register *)

		(* B3.4: Nested Vectored Interrupt Controller, NVIC *)
			(* Interrupt Set-Enable Registers *)
				NVICISER0* = 0E000E100H;
				NVICISER1* = 0E000E104H;
				NVICISER2* = 0E000E108H;
				NVICISER3* = 0E000E10CH;
				NVICISER4* = 0E000E110H;
				NVICISER5* = 0E000E114H;
				NVICISER6* = 0E000E118H;
				NVICISER7* = 0E000E11CH;
				NVICISER8* = 0E000E120H;
				NVICISER9* = 0E000E124H;
				NVICISER10* = 0E000E128H;
				NVICISER11* = 0E000E12CH;
				NVICISER12* = 0E000E130H;
				NVICISER13* = 0E000E134H;
				NVICISER14* = 0E000E138H;
				NVICISER15* = 0E000E13CH;
			(* Interrupt Clear-Enable Registers *)
				NVICICER0* = 0E000E180H;
				NVICICER1* = 0E000E184H;
				NVICICER2* = 0E000E188H;
				NVICICER3* = 0E000E18CH;
				NVICICER4* = 0E000E190H;
				NVICICER5* = 0E000E194H;
				NVICICER6* = 0E000E198H;
				NVICICER7* = 0E000E19CH;
				NVICICER8* = 0E000E1A0H;
				NVICICER9* = 0E000E1A4H;
				NVICICER10* = 0E000E1A8H;
				NVICICER11* = 0E000E1ACH;
				NVICICER12* = 0E000E1B0H;
				NVICICER13* = 0E000E1B4H;
				NVICICER14* = 0E000E1B8H;
				NVICICER15* = 0E000E1BCH;
			(* Interrupt Set-Pending Registers *)
				NVICISPR0* = 0E000E200H;
				NVICISPR1* = 0E000E204H;
				NVICISPR2* = 0E000E208H;
				NVICISPR3* = 0E000E20CH;
				NVICISPR4* = 0E000E210H;
				NVICISPR5* = 0E000E214H;
				NVICISPR6* = 0E000E218H;
				NVICISPR7* = 0E000E21CH;
				NVICISPR8* = 0E000E220H;
				NVICISPR9* = 0E000E224H;
				NVICISPR10* = 0E000E228H;
				NVICISPR11* = 0E000E22CH;
				NVICISPR12* = 0E000E230H;
				NVICISPR13* = 0E000E234H;
				NVICISPR14* = 0E000E238H;
				NVICISPR15* = 0E000E23CH;
			(* Interrupt Clear-Pending Registers *)
				NVICICPR0* = 0E000E280H;
				NVICICPR1* = 0E000E284H;
				NVICICPR2* = 0E000E288H;
				NVICICPR3* = 0E000E28CH;
				NVICICPR4* = 0E000E290H;
				NVICICPR5* = 0E000E294H;
				NVICICPR6* = 0E000E298H;
				NVICICPR7* = 0E000E29CH;
				NVICICPR8* = 0E000E2A0H;
				NVICICPR9* = 0E000E2A4H;
				NVICICPR10* = 0E000E2A8H;
				NVICICPR11* = 0E000E2ACH;
				NVICICPR12* = 0E000E2B0H;
				NVICICPR13* = 0E000E2B4H;
				NVICICPR14* = 0E000E2B8H;
				NVICICPR15* = 0E000E2BCH;
			(* Interrupt Active Bit Registers *)
				NVICIABR0* = 0E000E300H;
				NVICIABR1* = 0E000E304H;
				NVICIABR2* = 0E000E308H;
				NVICIABR3* = 0E000E30CH;
				NVICIABR4* = 0E000E310H;
				NVICIABR5* = 0E000E314H;
				NVICIABR6* = 0E000E318H;
				NVICIABR7* = 0E000E31CH;
				(*
				NVICIABR8* = 0E000E320H;
				NVICIABR9* = 0E000E324H;
				NVICIABR10* = 0E000E328H;
				NVICIABR11* = 0E000E32CH;
				NVICIABR12* = 0E000E330H;
				NVICIABR13* = 0E000E334H;
				NVICIABR14* = 0E000E338H;
				NVICIABR15* = 0E000E33CH;
				*)
			(* Interrupt Priority Registers *)
				NVICIPR0* = 0E000E400H;
				NVICIPR1* = 0E000E404H;
				NVICIPR2* = 0E000E408H;
				NVICIPR3* = 0E000E40CH;
				NVICIPR4* = 0E000E410H;
				NVICIPR5* = 0E000E414H;
				NVICIPR6* = 0E000E418H;
				NVICIPR7* = 0E000E41CH;
				NVICIPR8* = 0E000E420H;
				NVICIPR9* = 0E000E424H;
				NVICIPR10* = 0E000E428H;
				NVICIPR11* = 0E000E42CH;
				NVICIPR12* = 0E000E430H;
				NVICIPR13* = 0E000E434H;
				NVICIPR14* = 0E000E438H;
				NVICIPR15* = 0E000E43CH;
				NVICIPR16* = 0E000E440H;
				NVICIPR17* = 0E000E444H;
				NVICIPR18* = 0E000E448H;
				NVICIPR19* = 0E000E44CH;
				NVICIPR20* = 0E000E450H;
				NVICIPR21* = 0E000E454H;
				NVICIPR22* = 0E000E458H;
				NVICIPR23* = 0E000E45CH;
				NVICIPR24* = 0E000E460H;
				NVICIPR25* = 0E000E464H;
				NVICIPR26* = 0E000E468H;
				NVICIPR27* = 0E000E46CH;
				NVICIPR28* = 0E000E470H;
				NVICIPR29* = 0E000E474H;
				NVICIPR30* = 0E000E478H;
				NVICIPR31* = 0E000E47CH;
				NVICIPR32* = 0E000E480H;
				NVICIPR33* = 0E000E484H;
				NVICIPR34* = 0E000E488H;
				NVICIPR35* = 0E000E48CH;
				NVICIPR36* = 0E000E490H;
				NVICIPR37* = 0E000E494H;
				NVICIPR38* = 0E000E498H;
				NVICIPR39* = 0E000E49CH;
				NVICIPR40* = 0E000E4A0H;
				NVICIPR41* = 0E000E4A4H;
				NVICIPR42* = 0E000E4A8H;
				NVICIPR43* = 0E000E4ACH;
				NVICIPR44* = 0E000E4B0H;
				NVICIPR45* = 0E000E4B4H;
				NVICIPR46* = 0E000E4B8H;
				NVICIPR47* = 0E000E4BCH;
				NVICIPR48* = 0E000E4C0H;
				NVICIPR49* = 0E000E4C4H;
				NVICIPR50* = 0E000E4C8H;
				NVICIPR51* = 0E000E4CCH;
				NVICIPR52* = 0E000E4D0H;
				NVICIPR53* = 0E000E4D4H;
				NVICIPR54* = 0E000E4D8H;
				NVICIPR55* = 0E000E4DCH;
				NVICIPR56* = 0E000E4E0H;
				NVICIPR57* = 0E000E4E4H;
				NVICIPR58* = 0E000E4E8H;
				NVICIPR59* = 0E000E4ECH;
				(*
				NVICIPR60* = 0E000E4F0H;
				NVICIPR61* = 0E000E4F4H;
				NVICIPR62* = 0E000E4F8H;
				NVICIPR63* = 0E000E4FCH;
				NVICIPR64* = 0E000E500H;
				NVICIPR65* = 0E000E504H;
				NVICIPR66* = 0E000E508H;
				NVICIPR67* = 0E000E50CH;
				NVICIPR68* = 0E000E510H;
				NVICIPR69* = 0E000E514H;
				NVICIPR70* = 0E000E518H;
				NVICIPR71* = 0E000E51CH;
				NVICIPR72* = 0E000E520H;
				NVICIPR73* = 0E000E524H;
				NVICIPR74* = 0E000E528H;
				NVICIPR75* = 0E000E52CH;
				NVICIPR76* = 0E000E530H;
				NVICIPR77* = 0E000E534H;
				NVICIPR78* = 0E000E538H;
				NVICIPR79* = 0E000E53CH;
				NVICIPR80* = 0E000E540H;
				NVICIPR81* = 0E000E544H;
				NVICIPR82* = 0E000E548H;
				NVICIPR83* = 0E000E54CH;
				NVICIPR84* = 0E000E550H;
				NVICIPR85* = 0E000E554H;
				NVICIPR86* = 0E000E558H;
				NVICIPR87* = 0E000E55CH;
				NVICIPR88* = 0E000E560H;
				NVICIPR89* = 0E000E564H;
				NVICIPR90* = 0E000E568H;
				NVICIPR91* = 0E000E56CH;
				NVICIPR92* = 0E000E570H;
				NVICIPR93* = 0E000E574H;
				NVICIPR94* = 0E000E578H;
				NVICIPR95* = 0E000E57CH;
				NVICIPR96* = 0E000E580H;
				NVICIPR97* = 0E000E584H;
				NVICIPR98* = 0E000E588H;
				NVICIPR99* = 0E000E58CH;
				NVICIPR100* = 0E000E590H;
				NVICIPR101* = 0E000E594H;
				NVICIPR102* = 0E000E598H;
				NVICIPR103* = 0E000E59CH;
				NVICIPR104* = 0E000E5A0H;
				NVICIPR105* = 0E000E5A4H;
				NVICIPR106* = 0E000E5A8H;
				NVICIPR107* = 0E000E5ACH;
				NVICIPR108* = 0E000E5B0H;
				NVICIPR109* = 0E000E5B4H;
				NVICIPR110* = 0E000E5B8H;
				NVICIPR111* = 0E000E5BCH;
				NVICIPR112* = 0E000E5C0H;
				NVICIPR113* = 0E000E5C4H;
				NVICIPR114* = 0E000E5C8H;
				NVICIPR115* = 0E000E5CCH;
				NVICIPR116* = 0E000E5D0H;
				NVICIPR117* = 0E000E5D4H;
				NVICIPR118* = 0E000E5D8H;
				NVICIPR119* = 0E000E5DCH;
				NVICIPR120* = 0E000E5E0H;
				NVICIPR121* = 0E000E5E4H;
				NVICIPR122* = 0E000E5E8H;
				NVICIPR123* = 0E000E5ECH;
				*)

		(* B4.1.2 *)
			(* Processor Feature ID register support in SCS *)
				IDPFR0* = 0E000ED40H; (* Processor Feature Register 0 *)
				IDPFR1* = 0E000ED44H; (* Processor Feature Register 1 *)
				IDDFR0* = 0E000ED48H; (* Debug Feature Register 0 *)
				IDAFR0* = 0E000ED4CH; (* Auxiliary Feature Register 0 *)
				IDMMFR0* = 0E000ED50H; (* Memory Model Feature Register 0 *)
				IDMMFR1* = 0E000ED54H; (* Memory Model Feature Register 1 *)
				IDMMFR2* = 0E000ED58H; (* Memory Model Feature Register 2 *)
				IDMMFR3* = 0E000ED5CH; (* Memory Model Feature Register 3 *)
				IDISAR0* = 0E000ED60H; (* Instruction Set Attribute Register 0 *)
				IDISAR1* = 0E000ED64H; (* Instruction Set Attribute Register 1 *)
				IDISAR2* = 0E000ED68H; (* Instruction Set Attribute Register 2 *)
				IDISAR3* = 0E000ED6CH; (* Instruction Set Attribute Register 3 *)
				IDISAR4* = 0E000ED70H; (* Instruction Set Attribute Register 4 *)
				IDISAR5* = 0E000ED74H;

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
END MicroARMv7M.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroARMv6M.a6m 


O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroARMv6M.a7m 
