MODULE MicroLPC1343;

	(* Alexander Shiryaev, Ivan Denisov, 2014.10 *)

	(* UM10375.pdf *)

	CONST
		(* memory map *)
			flashStart* = 0;
			SRAMStart* = 10000000H;

			(* APB peripherals *)

				(* I2C *)
					I2C0* = 40000000H;
					I2C0CONSET* = I2C0;
					I2C0STAT* = I2C0 + 4;
					I2C0DAT* = I2C0 + 8;
					I2C0ADR0* = I2C0 + 0CH;
					I2C0SCLH* = I2C0 + 10H;
					I2C0SCLL* = I2C0 + 14H;
					I2C0CONCLR* = I2C0 + 18H;
					I2C0MMCTRL* = I2C0 + 1CH;
					I2C0ADR1* = I2C0 + 20H;
					I2C0ADR2* = I2C0 + 24H;
					I2C0ADR3* = I2C0 + 28H;
					I2C0DATABUFFER* = I2C0 + 2CH;
					I2C0MASK0* = I2C0 + 30H;
					I2C0MASK1* = I2C0 + 34H;
					I2C0MASK2* = I2C0 + 38H;
					I2C0MASK3* = I2C0 + 3CH;

				(* WDT, WWDT *)
					WDT* = 40004000H;
					WDMOD* = WDT;
					WDTC* = WDT + 4;
					WDFEED* = WDT + 8;
					WDTV* = WDT + 0CH;
					WDWARNINT* = WDT + 14H;
					WDWINDOW* = WDT + 18H;

				(* UART *)
					UART* = 40008000H;
					U0RBR* = UART;
					U0THR* = UART;
					U0DLL* = UART;
					U0DLM* = UART + 4;
					U0IER* = UART + 4;
					U0IIR* = UART + 8;
					U0FCR* = UART + 8;
					U0LCR* = UART + 0CH;
					U0MCR* = UART + 10H;
					U0LSR* = UART + 14H;
					U0MSR* = UART + 18H;
					U0SCR* = UART + 1CH;
					U0ACR* = UART + 20H;
					U0FDR* = UART + 28H;
					U0TER* = UART + 30H;
					U0RS485CTRL* = UART + 4CH;
					U0RS485ADRMATCH* = UART + 50H;
					U0RS485DLY* = UART + 54H;

				(* 16-bit counter/timer 0 *)
					TMR16B0* = 4000C000H;
					TMR16B0IR* = TMR16B0;
					TMR16B0TCR* = TMR16B0 + 4;
					TMR16B0TC* = TMR16B0 + 8;
					TMR16B0PR* = TMR16B0 + 0CH;
					TMR16B0PC* = TMR16B0 + 10H;
					TMR16B0MCR* = TMR16B0 + 14H;
					TMR16B0MR0* = TMR16B0 + 18H;
					TMR16B0MR1* = TMR16B0 + 1CH;
					TMR16B0MR2* = TMR16B0 + 20H;
					TMR16B0MR3* = TMR16B0 + 24H;
					TMR16B0CCR* = TMR16B0 + 28H;
					TMR16B0CR0* = TMR16B0 + 2CH;
					TMR16B0EMR* = TMR16B0 + 3CH;
					TMR16B0CTCR* = TMR16B0 + 70H;
					TMR16B0PWMC* = TMR16B0 + 74H;

				(* 16-bit counter/timer 1 *)
					TMR16B1* = 40010000H;
					TMR16B1IR* = TMR16B1;
					TMR16B1TCR* = TMR16B1 + 4;
					TMR16B1TC* = TMR16B1 + 8;
					TMR16B1PR* = TMR16B1 + 0CH;
					TMR16B1PC* = TMR16B1 + 10H;
					TMR16B1MCR* = TMR16B1 + 14H;
					TMR16B1MR0* = TMR16B1 + 18H;
					TMR16B1MR1* = TMR16B1 + 1CH;
					TMR16B1MR2* = TMR16B1 + 20H;
					TMR16B1MR3* = TMR16B1 + 24H;
					TMR16B1CCR* = TMR16B1 + 28H;
					TMR16B1CR0* = TMR16B1 + 2CH;
					TMR16B1EMR* = TMR16B1 + 3CH;
					TMR16B1CTCR* = TMR16B1 + 70H;
					TMR16B1PWMC* = TMR16B1 + 74H;

				(* 32-bit counter/timer 0 *)
					TMR32B0* = 40014000H;
					TMR32B0IR* = TMR32B0;
					TMR32B0TCR* = TMR32B0 + 4;
					TMR32B0TC* = TMR32B0 + 8;
					TMR32B0PR* = TMR32B0 + 0CH;
					TMR32B0PC* = TMR32B0 + 10H;
					TMR32B0MCR* = TMR32B0 + 14H;
					TMR32B0MR0* = TMR32B0 + 18H;
					TMR32B0MR1* = TMR32B0 + 1CH;
					TMR32B0MR2* = TMR32B0 + 20H;
					TMR32B0MR3* = TMR32B0 + 24H;
					TMR32B0CCR* = TMR32B0 + 28H;
					TMR32B0CR0* = TMR32B0 + 2CH;
					TMR32B0EMR* = TMR32B0 + 3CH;
					TMR32B0CTCR* = TMR32B0 + 70H;
					TMR32B0PWMC* = TMR32B0 + 74H;

				(* 32-bit counter/timer 1 *)
					TMR32B1* = 40018000H;
					TMR32B1IR* = TMR32B1;
					TMR32B1TCR* = TMR32B1 + 4;
					TMR32B1TC* = TMR32B1 + 8;
					TMR32B1PR* = TMR32B1 + 0CH;
					TMR32B1PC* = TMR32B1 + 10H;
					TMR32B1MCR* = TMR32B1 + 14H;
					TMR32B1MR0* = TMR32B1 + 18H;
					TMR32B1MR1* = TMR32B1 + 1CH;
					TMR32B1MR2* = TMR32B1 + 20H;
					TMR32B1MR3* = TMR32B1 + 24H;
					TMR32B1CCR* = TMR32B1 + 28H;
					TMR32B1CR0* = TMR32B1 + 2CH;
					TMR32B1EMR* = TMR32B1 + 3CH;
					TMR32B1CTCR* = TMR32B1 + 70H;
					TMR32B1PWMC* = TMR32B1 + 74H; 

				(* ADC *)
					AD0* = 4001C000H;
					AD0CR* = AD0;
					AD0GDR* = AD0 + 4;
					AD0INTEN* = AD0 + 0CH;
					AD0DR0* = AD0 + 10H;
					AD0DR1* = AD0 + 14H;
					AD0DR2* = AD0 + 18H;
					AD0DR3* = AD0 + 1CH;
					AD0DR4* = AD0 + 20H;
					AD0DR5* = AD0 + 24H;
					AD0DR6* = AD0 + 28H;
					AD0DR7* = AD0 + 2CH;
					AD0STAT* = AD0 + 30H;

				USB* = 40020000H;

				(* PMU *)
					PMU* = 40038000H;
					PCON* = PMU;
					GPREG0* = PMU + 4;
					GPREG1* = PMU + 8;
					GPREG2* = PMU + 0CH;
					GPREG3* = PMU + 10H;
					GPREG4* = PMU + 14H;

				FlashController* = 4003C000H;
					FLASHCFG* = FlashController + 10H;

				(* SSP0 *)
					SSP0* = 40040000H;
					SSP0CR0* = SSP0;
					SSP0CR1* = SSP0 + 4;
					SSP0DR* = SSP0 + 8;
					SSP0SR* = SSP0 + 0CH;
					SSP0CPSR* = SSP0 + 10H;
					SSP0IMSC* = SSP0 + 14H;
					SSP0RIS* = SSP0 + 18H;
					SSP0MIS* = SSP0 + 1CH;
					SSP0ICR* = SSP0 + 20H;

				(* IOCONFIG *)
					IOCONFIG* = 40044000H;
					IOCONPIO26* = IOCONFIG;
					IOCONPIO20* = IOCONFIG + 8;
					IOCONRESETPIO00* = IOCONFIG + 0CH;
					IOCONPIO01* = IOCONFIG + 10H;
					IOCONPIO18* = IOCONFIG + 14H;
					IOCONPIO02* = IOCONFIG + 1CH;
					IOCONPIO27* = IOCONFIG + 20H;
					IOCONPIO28* = IOCONFIG + 24H;
					IOCONPIO21* = IOCONFIG + 28H;
					IOCONPIO03* = IOCONFIG + 2CH;
					IOCONPIO04* = IOCONFIG + 30H;
					IOCONPIO05* = IOCONFIG + 34H;
					IOCONPIO19* = IOCONFIG + 38H;
					IOCONPIO34* = IOCONFIG + 3CH;
					IOCONPIO24* = IOCONFIG + 40H;
					IOCONPIO25* = IOCONFIG + 44H;
					IOCONPIO35* = IOCONFIG + 48H;
					IOCONPIO06* = IOCONFIG + 4CH;
					IOCONPIO07* = IOCONFIG + 50H;
					IOCONPIO29* = IOCONFIG + 54H;
					IOCONPIO210* = IOCONFIG + 58H;
					IOCONPIO22* = IOCONFIG + 5CH;
					IOCONPIO08* = IOCONFIG + 60H;
					IOCONPIO09* = IOCONFIG + 64H;
					IOCONSWCLKPIO010* = IOCONFIG + 68H;
					IOCONPIO110* = IOCONFIG + 6CH;
					IOCONPIO211* = IOCONFIG + 70H;
					IOCONRPIO011* = IOCONFIG + 74H;
					IOCONRPIO10* = IOCONFIG + 78H;
					IOCONRPIO11* = IOCONFIG + 7CH;
					IOCONRPIO12* = IOCONFIG + 80H;
					IOCONPIO30* = IOCONFIG + 84H;
					IOCONPIO31* = IOCONFIG + 88H;
					IOCONPIO23* = IOCONFIG + 8CH;
					IOCONSWDIOPIO13* = IOCONFIG + 90H;
					IOCONPIO14* = IOCONFIG + 94H;
					IOCONPIO111* = IOCONFIG + 98H;
					IOCONPIO32* = IOCONFIG + 9CH;
					IOCONPIO15* = IOCONFIG + 0A0H;
					IOCONPIO16* = IOCONFIG + 0A4H;
					IOCONPIO17* = IOCONFIG + 0A8H;
					IOCONPIO33* = IOCONFIG + 0ACH;
					IOCONSCK0LOC* = IOCONFIG + 0B0H;
					IOCONDSRLOC* = IOCONFIG + 0B4H;
					IOCONDCDLOC* = IOCONFIG + 0B8H;
					IOCONRILOC* = IOCONFIG + 0BCH;

				SystemControl* = 40048000H;
					SYSMEMREMAP* = SystemControl; (* system memory remap *)
					PRESETCTRL* = SystemControl + 4; (* peripheral reset control *)
					SYSPLLCTRL* = SystemControl + 8; (* system PLL control *)
					SYSPLLSTAT* = SystemControl + 0CH; (* system PLL status *)
					USBPLLCTRL* = SystemControl + 10H; (* USB PLL control *)
					USBPLLSTAT* = SystemControl + 14H; (* USB PLL status *)
					SYSOSCCTRL* = SystemControl + 20H; (* system oscillator control *)
					WDTOSCCTRL* = SystemControl + 24H; (* watchdog oscillator control *)
					IRCCTRL* = SystemControl + 28H; (* IRC control *)
					SYSRESSTAT* = SystemControl + 30H; (* system reset status register *)
					SYSPLLCLKSEL* = SystemControl + 40H; (* system PLL clock source select *)
					SYSPLLCLKUEN* = SystemControl + 44H; (* system PLL clock source update enable *)
					USBPLLCLKSEL* = SystemControl + 48H; (* USB PLL clock source select *)
					USBPLLCLKUEN* = SystemControl + 4CH; (* USB PLL clock source update enable *)
					MAINCLKSEL* = SystemControl + 70H; (* main clock source select *)
					MAINCLKUEN* = SystemControl + 74H; (* main clock source update enable *)
					SYSAHBCLKDIV* = SystemControl + 78H; (* system AHB clock divider *)
					SYSAHBCLKCTRL* = SystemControl + 80H; (* system AHB clock control *)
					SSP0CLKDIV* = SystemControl + 94H; (* SSP0 clock divider *)
					UARTCLKDIV* = SystemControl + 98H; (* UART clock divider *)
					SSP1CLKDIV* = SystemControl + 9CH; (* SSP1 clock divider *)
					TRACECLKDIV* = SystemControl + 0ACH; (* ARM trace clock divider *)
					SYSTICKCLKDIV* = SystemControl + 0B0H; (* SYSTICK clock divider *)
					USBCLKSEL* = SystemControl + 0C0H; (* USB clock source select *)
					USBCLKUEN* = SystemControl + 0C4H; (* USB clock source update enable *)
					USBCLKDIV* = SystemControl + 0C8H; (* USB clock source divider *)
					WDTCLKSEL* = SystemControl + 0D0H; (* WDT clock source select *)
					WDTCLKUEN* = SystemControl + 0D4H; (* WDT clock source update enable *)
					WDTCLKDIV* = SystemControl + 0D8H; (* WDT clock divider *)
					CLKOUTCLKSEL* = SystemControl + 0E0H; (* CLKOUT clock source select *)
					CLKOUTUEN* = SystemControl + 0E4H; (* CLKOUT clock source update enable *)
					CLKOUTDIV* = SystemControl + 0E8H; (* CLKOUT clock divider *)
					PIOPORCAP0* = SystemControl + 100H; (* POR captured PIO status 0 *)
					PIOPORCAP1* = SystemControl + 104H; (* POR captured PIO status 1 *)
					BODCTRL* = SystemControl + 150H; (* BOD control *)
					SYSTCKCAL* = SystemControl + 154H; (* system tick counter calibration *)
					STARTAPRP0* = SystemControl + 200H; (* start logic edge control register 0; bottom 32 interrupts *)
					STARTERP0* = SystemControl + 204H; (* start logic signal enable register 0; bottom 32 interrupts *)
					STARTRSRP0CLR* = SystemControl + 208H; (* start logic reset register 0; bottom 32 interrupts *)
					STARTSRP0* = SystemControl + 20CH; (* start logic status register 0; bottom 32 interrupts *)
					STARTAPRP1* = SystemControl + 210H; (* start logic edge control register 1; top 8 interrupts *)
					STARTERP1* = SystemControl + 214H; (* start logic signal enable register 1; top 8 interrupts *)
					STARTRSRP1CLR* = SystemControl + 218H; (* start logic reset register 1; top 8 interrupts *)
					STARTSRP1* = SystemControl + 21CH; (* start logic status register 1; top 8 interrupts *)
					PDSLEEPCFG* = SystemControl + 230H; (* power-down states in deep-sleep mode *)
					PDAWAKECFG* = SystemControl + 234H; (* power-down states after wake-up from deep-sleep mode *)
					PDRUNCFG* = SystemControl + 238H; (* power-down configuration register *)
					DEVICEID* = SystemControl + 3F4H; (* device ID *)

				(* SSP1 *)
					SSP1* = 40058000H;
					SSP1CR0* = SSP1;
					SSP1CR1* = SSP1 + 4;
					SSP1DR* = SSP1 + 8;
					SSP1SR* = SSP1 + 0CH;
					SSP1CPSR* = SSP1 + 10H;
					SSP1IMSC* = SSP1 + 14H;
					SSP1RIS* = SSP1 + 18H;
					SSP1MIS* = SSP1 + 1CH;
					SSP1ICR* = SSP1 + 20H;		

			(* AHB peripherals *)

				GPIO0* = 50000000H;
					GPIO0DATAMASK* = GPIO0;
					GPIO0DATA* = GPIO0 + 3FFCH;
					GPIO0DIR* = GPIO0 + 8000H;
					GPIO0IS* = GPIO0 + 8004H;
					GPIO0IBE* = GPIO0 + 8008H;
					GPIO0IEV* = GPIO0 + 800CH;
					GPIO0IE* = GPIO0 + 8010H;
					GPIO0RIS* = GPIO0 + 8014H;
					GPIO0MIS* = GPIO0 + 8018H;
					GPIO0IC* = GPIO0 + 801CH;
				GPIO1* = 50010000H;
					GPIO1DATAMASK* = GPIO1;
					GPIO1DATA* = GPIO1 + 3FFCH;
					GPIO1DIR* = GPIO1 + 8000H;
					GPIO1IS* = GPIO1 + 8004H;
					GPIO1IBE* = GPIO1 + 8008H;
					GPIO1IEV* = GPIO1 + 800CH;
					GPIO1IE* = GPIO1 + 8010H;
					GPIO1RIS* = GPIO1 + 8014H;
					GPIO1MIS* = GPIO1 + 8018H;
					GPIO1IC* = GPIO1 + 801CH;
				GPIO2* = 50020000H;
					GPIO2DATAMASK* = GPIO2;
					GPIO2DATA* = GPIO2 + 3FFCH;
					GPIO2DIR* = GPIO2 + 8000H;
					GPIO2IS* = GPIO2 + 8004H;
					GPIO2IBE* = GPIO2 + 8008H;
					GPIO2IEV* = GPIO2 + 800CH;
					GPIO2IE* = GPIO2 + 8010H;
					GPIO2RIS* = GPIO2 + 8014H;
					GPIO2MIS* = GPIO2 + 8018H;
					GPIO2IC* = GPIO2 + 801CH;
				GPIO3* = 50030000H;
					GPIO3DATAMASK* = GPIO3;
					GPIO3DATA* = GPIO3 + 3FFCH;
					GPIO3DIR* = GPIO3 + 8000H;
					GPIO3IS* = GPIO3 + 8004H;
					GPIO3IBE* = GPIO3 + 8008H;
					GPIO3IEV* = GPIO3 + 800CH;
					GPIO3IE* = GPIO3 + 8010H;
					GPIO3RIS* = GPIO3 + 8014H;
					GPIO3MIS* = GPIO3 + 8018H;
					GPIO3IC* = GPIO3 + 801CH;

		(* NVIC *)
			(* interrupt sources *)
				StartLogicWakeUpPIO00Int* = 0;
				StartLogicWakeUpPIO01Int* = 1;
				StartLogicWakeUpPIO02Int* = 2;
				StartLogicWakeUpPIO03Int* = 3;
				StartLogicWakeUpPIO04Int* = 4;
				StartLogicWakeUpPIO05Int* = 5;
				StartLogicWakeUpPIO06Int* = 6;
				StartLogicWakeUpPIO07Int* = 7;
				StartLogicWakeUpPIO08Int* = 8;
				StartLogicWakeUpPIO09Int* = 9;
				StartLogicWakeUpPIO010Int* = 10;
				StartLogicWakeUpPIO011Int* = 11;

				StartLogicWakeUpPIO10Int* = 12;
				StartLogicWakeUpPIO11Int* = 13;
				StartLogicWakeUpPIO12Int* = 14;
				StartLogicWakeUpPIO13Int* = 15;
				StartLogicWakeUpPIO14Int* = 16;
				StartLogicWakeUpPIO15Int* = 17;
				StartLogicWakeUpPIO16Int* = 18;
				StartLogicWakeUpPIO17Int* = 19;
				StartLogicWakeUpPIO18Int* = 20;
				StartLogicWakeUpPIO19Int* = 21;
				StartLogicWakeUpPIO110Int* = 22;
				StartLogicWakeUpPIO111Int* = 23;

				StartLogicWakeUpPIO20Int* = 24;
				StartLogicWakeUpPIO21Int* = 25;
				StartLogicWakeUpPIO22Int* = 26;
				StartLogicWakeUpPIO23Int* = 27;
				StartLogicWakeUpPIO24Int* = 28;
				StartLogicWakeUpPIO25Int* = 29;
				StartLogicWakeUpPIO26Int* = 30;
				StartLogicWakeUpPIO27Int* = 31;
				StartLogicWakeUpPIO28Int* = 32;
				StartLogicWakeUpPIO29Int* = 33;
				StartLogicWakeUpPIO210Int* = 34;
				StartLogicWakeUpPIO211Int* = 35;

				StartLogicWakeUpPIO30Int* = 36;
				StartLogicWakeUpPIO31Int* = 37;
				StartLogicWakeUpPIO32Int* = 38;
				StartLogicWakeUpPIO33Int* = 39;

				I2C0Int* = 40;
				CT16B0Int* = 41;
				CT16B1Int* = 42;
				CT32B0Int* = 43;
				CT32B1Int* = 44;
				SSP0Int* = 45;
				UARTInt* = 46;
				USBIRQInt* = 47;
				USBFIQInt* = 48;
				ADCInt* = 49;
				WDTInt* = 50;
				BODInt* = 51;
				PIO3Int* = 53;
				PIO2Int* = 54;
				PIO1Int* = 55;
				PIO0Int* = 56;
				SSP1Int* = 57;

END MicroLPC1343.

O7ARMv6MP.Compile @/s

O7ARMv7MP.Compile @/s
