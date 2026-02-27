MODULE MicroSTM32L1Pins;

	(*
		Alexander Shiryaev, 2021.09

		RM0038, Reference manual,
			STM32L100xx, STM32L151xx, STM32L152xx, STM32L162xx
	*)

	IMPORT SYSTEM;

	CONST
		(* ports *)
			A* = 0; B* = 1; C* = 2; D* = 3; E* = 4; H* = 5; F* = 6; G* = 7;

		(* modes *)
			input* = 0; output* = 1; alt* = 2; analog* = 3;

		(* output types *)
			pushPull* = FALSE; openDrain* = TRUE;

		(* output speeds *)
			low* = 0; medium* = 1; high* = 2; veryHigh* = 3;

		(* pull resistors *)
			noPull* = 0; pullUp* = 1; pullDown* = 2;

		(* alternative functions *)
			AF0* = 0; AF1* = 1; AF2* = 2; AF3* = 3;
			AF4* = 4; AF5* = 5; AF6* = 6; AF7* = 7;
			AF8* = 8; AF9* = 9; AF10* = 10; AF11* = 11;
			AF12* = 12; AF13* = 13; AF14* = 14; AF15* = 15;

		(* memory map *)
			(* AHB *)
				GPIOA* = 40020000H;
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
				GPIOB* = 40020400H;
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
				GPIOC* = 40020800H;
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
				GPIOD* = 40020C00H;
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
				GPIOE* = 40021000H;
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
				GPIOH* = 40021400H;
					GPIOHMODER* = GPIOH;
					GPIOHOTYPER* = GPIOH + 4;
					GPIOHOSPEEDR* = GPIOH + 8;
					GPIOHPUPDR* = GPIOH + 0CH;
					GPIOHIDR* = GPIOH + 10H;
					GPIOHODR* = GPIOH + 14H;
					GPIOHBSRR* = GPIOH + 18H;
					GPIOHLCKR* = GPIOH + 1CH;
					GPIOHAFRL* = GPIOH + 20H;
					GPIOHAFRH* = GPIOH + 24H;
					GPIOHBRR* = GPIOH + 28H;
				GPIOF* = 40021800H;
					GPIOFMODER*= GPIOF;
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
				GPIOG* = 40021C00H;
					GPIOGMODER* = GPIOG;
					GPIOGOTYPER* = GPIOG + 4;
					GPIOGOSPEEDR* = GPIOG + 8;
					GPIOGPUPDR* = GPIOG + 0CH;
					GPIOGIDR* = GPIOG + 10H;
					GPIOGODR* = GPIOG + 14H;
					GPIOGBSRR* = GPIOG + 18H;
					GPIOGLCKR* = GPIOG + 1CH;
					GPIOGAFRL* = GPIOG + 20H;
					GPIOGAFRH* = GPIOG + 24H;
					GPIOGBRR* = GPIOG + 28H;

				RCC = 40023800H;
					RCCAHBENR = RCC + 1CH;
					RCCAHBLPENR = RCC + 28H;

		portSpacing = GPIOB - GPIOA;

	PROCEDURE Configure* (port, pin, mode: INTEGER; oType: BOOLEAN; oSpeed, pullType, af: INTEGER);
		VAR x: SET;
			r, y: INTEGER;
	BEGIN
		ASSERT(port >= A);
		ASSERT(port <= G);
		ASSERT(pin DIV 16 = 0);
		ASSERT(mode DIV 4 = 0);
		ASSERT(oSpeed DIV 4 = 0);
		ASSERT(pullType >= noPull);
		ASSERT(pullType <= pullDown);
		ASSERT(af DIV 16 = 0);

		y := pin * 2;

		(* enable clock for pin port *)
			SYSTEM.GET(RCCAHBENR, x);
			SYSTEM.PUT(RCCAHBENR, x + {port});

			SYSTEM.GET(RCCAHBLPENR, x);
			SYSTEM.PUT(RCCAHBLPENR, x + {port});

		r := GPIOAMODER + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(mode, y));

		r := GPIOAOTYPER + port * portSpacing;
		SYSTEM.GET(r, x);
		IF oType THEN SYSTEM.PUT(r, x + {pin})
		ELSE SYSTEM.PUT(r, x - {pin})
		END;

		r := GPIOAOSPEEDR + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(oSpeed, y));

		r := GPIOAPUPDR + port * portSpacing;
		SYSTEM.GET(r, x);
		SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y,y+1}) + LSL(pullType, y));

		IF mode = alt THEN y := (pin * 4) MOD 32;
			r := GPIOAAFRL + pin DIV 8 * 4 + port * portSpacing;
			SYSTEM.GET(r, x);
			SYSTEM.PUT(r, SYSTEM.VAL(INTEGER, x - {y..y+3}) + LSL(af, y))
		END
	END Configure;

END MicroSTM32L1Pins.
