MODULE MicroSTM32F4Pins;

	(*
		Alexander Shiryaev, 2016.04

		RM0090, Reference manual,
			STM32F4{0,1}{5,7}xx, STM32F4{2,3}{7,9}xx (PA..PK)

		RM0368, Reference manual,
			STM32F401x{B,C,D,E} (PA..PE, PH)

		RM0383, Reference manual,
			STM32F411x{C,E} (PA..PE, PH)

		RM0386, Reference manual,
			STM32F4{6,7}9xx (PA..PK)

		RM0390, Reference manual,
			STM32F446xx (PA..PH)

		RM0401, Reference manual,
			STM32F410 (PA..PC, PH)
	*)

	IMPORT SYSTEM;

	CONST
		(* ports *)
			A* = 0; B* = 1; C* = 2; D* = 3; E* = 4; F* = 5; G* = 6; H* = 7;
			I* = 8; J* = 9; K* = 10;

		(* modes *)
			input* = 0; output* = 1; alt* = 2; analog* = 3;

		(* output types *)
			pushPull* = FALSE; openDrain* = TRUE;

		(* output speeds *)
			low* = 0; medium* = 1; fast* = 2; veryHigh* = 3;
				(* STM32F4{0,1}1, STM32F446: low, medium, fast, high *)
				(* STM32F4{0,1}{5,7}, STM32F4{2,3}{7,9},
					STM32F410, STM32F4{6,7}9: low, medium, high, very high *)

		(* pull resistors *)
			noPull* = 0; pullUp* = 1; pullDown* = 2;

		(* alternative functions *)
			AF0* = 0; AF1* = 1; AF2* = 2; AF3* = 3;
			AF4* = 4; AF5* = 5; AF6* = 6; AF7* = 7;
			AF8* = 8; AF9* = 9; AF10* = 10; AF11* = 11;
			AF12* = 12; AF13* = 13; AF14* = 14; AF15* = 15;

		(* AHB1 *)
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
			GPIOF* = 40021400H;
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
			GPIOG* = 40021800H;
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
			GPIOH* = 40021C00H;
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
			GPIOI* = 40022000H;
				GPIOIMODER* = GPIOI;
				GPIOIOTYPER* = GPIOI + 4;
				GPIOIOSPEEDR* = GPIOI + 8;
				GPIOIPUPDR* = GPIOI + 0CH;
				GPIOIIDR* = GPIOI + 10H;
				GPIOIODR* = GPIOI + 14H;
				GPIOIBSRR* = GPIOI + 18H;
				GPIOILCKR* = GPIOI + 1CH;
				GPIOIAFRL* = GPIOI + 20H;
				GPIOIAFRH* = GPIOI + 24H;
			GPIOJ* = 40022400H;
				GPIOJMODER* = GPIOJ;
				GPIOJOTYPER* = GPIOJ + 4;
				GPIOJOSPEEDR* = GPIOJ + 8;
				GPIOJPUPDR* = GPIOJ + 0CH;
				GPIOJIDR* = GPIOJ + 10H;
				GPIOJODR* = GPIOJ + 14H;
				GPIOJBSRR* = GPIOJ + 18H;
				GPIOJLCKR* = GPIOJ + 1CH;
				GPIOJAFRL* = GPIOJ + 20H;
				GPIOJAFRH* = GPIOJ + 24H;
			GPIOK* = 40022800H;
				GPIOKMODER* = GPIOK;
				GPIOKOTYPER* = GPIOK + 4;
				GPIOKOSPEEDR* = GPIOK + 8;
				GPIOKPUPDR* = GPIOK + 0CH;
				GPIOKIDR* = GPIOK + 10H;
				GPIOKODR* = GPIOK + 14H;
				GPIOKBSRR* = GPIOK + 18H;
				GPIOKLCKR* = GPIOK + 1CH;
				GPIOKAFRL* = GPIOK + 20H;
				GPIOKAFRH* = GPIOK + 24H;

		portSpacing = GPIOB - GPIOA;

		RCC = 40023800H;
		RCCAHB1ENR = RCC + 30H;
		RCCAHB1LPENR = RCC + 50H;

	PROCEDURE Configure* (port, pin, mode: INTEGER; oType: BOOLEAN; oSpeed, pullType, af: INTEGER);
		VAR x: SET;
			r, y: INTEGER;
	BEGIN
		ASSERT(port >= A);
		ASSERT(port <= K);
		ASSERT(pin DIV 16 = 0);
		ASSERT(mode DIV 4 = 0);
		ASSERT(oSpeed DIV 4 = 0);
		ASSERT(pullType >= noPull);
		ASSERT(pullType <= pullDown);
		ASSERT(af DIV 16 = 0);

		y := pin * 2;

		(* enable clock for pin port *)
			SYSTEM.GET(RCCAHB1ENR, x);
			SYSTEM.PUT(RCCAHB1ENR, x + {port});

			SYSTEM.GET(RCCAHB1LPENR, x);
			SYSTEM.PUT(RCCAHB1LPENR, x + {port});

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

END MicroSTM32F4Pins.

O7ARMv7MP.Compile @/s

O7ARMv7MTool.DecObj MicroSTM32F4Pins.a7m 
