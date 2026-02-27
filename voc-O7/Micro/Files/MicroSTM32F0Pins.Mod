MODULE MicroSTM32F0Pins;

	(*
		Alexander Shiryaev, 2016.04

		RM0360, Reference manual,
			STM32F030x{4,6,8,C}, STM32F070x{6,B}

		RM0091, Reference manual,
			STM32F0x{1,2,8}
	*)

	IMPORT SYSTEM;

	CONST
		(* ports *)
			A* = 0; B* = 1; C* = 2; D* = 3; E* = 4; F* = 5;

		(* modes *)
			input = 0; output = 1; alt = 2; analog = 3;

		(* pull resistors *)
			noPull* = 0; pullUp* = 1; pullDown* = 2;

		(* oConf *)
			pushPullLow* = 0;
			pushPullMedium* = 1;
			pushPullHigh* = 3;
			openDrainLow* = 4;
			openDrainMedium = 5;
			openDrainHigh = 7;

		(* alternate functions *)
			AF0* = 0; AF1* = 1; AF2* = 2; AF3* = 3;
			AF4* = 4; AF5* = 5; AF6* = 6; AF7* = 7;
			AF8* = 8; AF9* = 9; AF10* = 10; AF11* = 11;
			AF12* = 12; AF13* = 13; AF14* = 14; AF15* = 15;

		(* AHB2 *)
			GPIOA* = 48000000H;
				GPIOAMODER* = GPIOA;
				GPIOAOTYPER* = GPIOA + 4;
				GPIOAOSPEEDR* = GPIOA + 8;
				GPIOAPUPDR* = GPIOA + 0CH;
				GPIOAIDR* = GPIOA + 10H;
				GPIOAODR* = GPIOA + 14H;
				GPIOABSRR* = GPIOA + 18H;
				GPIOALCKR* = GPIOA + 1CH;
				GPIOAAFRL* = GPIOA + 20H;
				GPIOAAFRH* = GPIOA + 24H;
				GPIOABRR* = GPIOA + 28H;
			GPIOB* = 48000400H;
				GPIOBMODER* = GPIOB;
				GPIOBOTYPER* = GPIOB + 4;
				GPIOBOSPEEDR* = GPIOB + 8;
				GPIOBPUPDR* = GPIOB + 0CH;
				GPIOBIDR* = GPIOB + 10H;
				GPIOBODR* = GPIOB + 14H;
				GPIOBBSRR* = GPIOB + 18H;
				GPIOBLCKR* = GPIOB + 1CH;
				GPIOBAFRL* = GPIOB + 20H;
				GPIOBAFRH* = GPIOB + 24H;
				GPIOBBRR* = GPIOB + 28H;
			GPIOC* = 48000800H;
				GPIOCMODER* = GPIOC;
				GPIOCOTYPER* = GPIOC + 4;
				GPIOCOSPEEDR* = GPIOC + 8;
				GPIOCPUPDR* = GPIOC + 0CH;
				GPIOCIDR* = GPIOC + 10H;
				GPIOCODR* = GPIOC + 14H;
				GPIOCBSRR* = GPIOC + 18H;
				GPIOCLCKR* = GPIOC + 1CH;
				GPIOCAFRL* = GPIOC + 20H;
				GPIOCAFRH* = GPIOC + 24H;
				GPIOCBRR* = GPIOC + 28H;
			GPIOD* = 48000C00H;
				GPIODMODER* = GPIOD;
				GPIODOTYPER* = GPIOD + 4;
				GPIODOSPEEDR* = GPIOD + 8;
				GPIODPUPDR* = GPIOD + 0CH;
				GPIODIDR* = GPIOD + 10H;
				GPIODODR* = GPIOD + 14H;
				GPIODBSRR* = GPIOD + 18H;
				GPIODLCKR* = GPIOD + 1CH;
				GPIODAFRL* = GPIOD + 20H;
				GPIODAFRH* = GPIOD + 24H;
				GPIODBRR* = GPIOD + 28H;
			(* STM32F0x{1,2,8} *)
				GPIOE* = 48001000H;
					GPIOEMODER* = GPIOE;
					GPIOEOTYPER* = GPIOE + 4;
					GPIOEOSPEEDR* = GPIOE + 8;
					GPIOEPUPDR* = GPIOE + 0CH;
					GPIOEIDR* = GPIOE + 10H;
					GPIOEODR* = GPIOE + 14H;
					GPIOEBSRR* = GPIOE + 18H;
					GPIOELCKR* = GPIOE + 1CH;
					GPIOEAFRL* = GPIOE + 20H;
					GPIOEAFRH* = GPIOE + 24H;
					GPIOEBRR* = GPIOE + 28H;
			GPIOF* = 48001400H;
				GPIOFMODER* = GPIOF;
				GPIOFOTYPER* = GPIOF + 4;
				GPIOFOSPEEDR* = GPIOF + 8;
				GPIOFPUPDR* = GPIOF + 0CH;
				GPIOFIDR* = GPIOF + 10H;
				GPIOFODR* = GPIOF + 14H;
				GPIOFBSRR* = GPIOF + 18H;
				GPIOFLCKR* = GPIOF + 1CH;
				GPIOFAFRL* = GPIOF + 20H;
				GPIOFAFRH* = GPIOF + 24H;
				GPIOFBRR* = GPIOF + 28H;

		portSpacing = GPIOB - GPIOA;

		RCC = 40021000H;
		RCCAHBENR = RCC + 14H;
			IOPAEN = 17;

	PROCEDURE Configure0 (port, pin, mode, oConf, pullType: INTEGER);
		VAR x: SET;
			r, y: INTEGER;
	BEGIN
		ASSERT(port >= A);
		ASSERT(port <= F);
		ASSERT(pin DIV 16 = 0);
		(* ASSERT(mode DIV 4 = 0); *)
		ASSERT(oConf DIV 8 = 0);
		ASSERT(pullType >= noPull);
		ASSERT(pullType <= pullDown);

		y := pin * 2;

		(* enable clock for port pin *)
			SYSTEM.GET(RCCAHBENR, x);
			SYSTEM.PUT(RCCAHBENR, x + {port + IOPAEN});

		r := GPIOAMODER + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(mode, y));

		r := GPIOAOTYPER + port * portSpacing;
		SYSTEM.GET(r, x);
		IF ODD(oConf DIV 4) THEN SYSTEM.PUT(r, x + {pin})
		ELSE SYSTEM.PUT(r, x - {pin})
		END;

		r := GPIOAOSPEEDR + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(oConf MOD 4, y));

		r := GPIOAPUPDR + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(pullType, y))
	END Configure0;

	PROCEDURE ConfigureAnalog* (port, pin: INTEGER);
	BEGIN
		Configure0(port, pin, analog, 0, noPull)
	END ConfigureAnalog;

	PROCEDURE ConfigureInput* (port, pin, pullType: INTEGER);
	BEGIN
		Configure0(port, pin, input, 0, pullType)
	END ConfigureInput;

	PROCEDURE ConfigureOutput* (port, pin, pullType, oConf: INTEGER);
	BEGIN
		Configure0(port, pin, output, oConf, pullType)
	END ConfigureOutput;

	PROCEDURE ConfigureAlt* (port, pin, pullType, oConf, af: INTEGER);
		VAR x: SET;
			y, r: INTEGER;
	BEGIN
		ASSERT(af DIV 16 = 0);

		Configure0(port, pin, alt, oConf, pullType);

		y := (pin * 4) MOD 32;
		r := GPIOAAFRL + pin DIV 8 * 4 + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y..y+3}) + LSL(af, y))
	END ConfigureAlt;

END MicroSTM32F0Pins.

O7ARMv6MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F0Pins.a6m 
