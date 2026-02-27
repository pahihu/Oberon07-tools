MODULE MicroSTM32H7;

	(*
		Alexander Shiryaev, 2021.12

		RM0433, Reference manual,
			STM32H742, STM32H743/753 and STM32H750 Value line
	*)

	CONST
		(* memory map *)
			(* Code *)
				ITCM* = 0H;
				FlashStart* = 8000000H;
				SystemMemory* = 1FF00000H; (* 128 KiB *)
			(* RAM *)
				DTCM* = 20000000H; (* 128 KiB *)
				AXISRAM* = 24000000H; (* 512 KiB *)
				SRAM1* = 30000000H; (* 128 KiB *)
				SRAM2* = 30020000H; (* 128 KiB *)
				SRAM3* = 30040000H; (* 32 KiB *)
				SRAM4* = 38000000H; (* 64 KiB *)
				BackupSRAM* = 38800000H; (* 4 KiB *)
			(* Peripherals *)
				(* APB1 (D2) *)
					TIM2* = 40000000H;
					TIM3* = 40000400H;
					TIM4 \* = 40000800H;
					TIM5* = 40000C00H;
					TIM6* = 40001000H;
					TIM7* = 40001400H;
					TIM12* = 40001800H;
					TIM13* = 40001C00H;
					TIM14* = 40002000H;
					LPTIM1* = 40002400H;
					SPI2* = 40003800H;
					SPI3* = 40003C00H;
					SPDIFRX1* = 40004000H;
					USART2* = 40004400H;
					USART3* = 40004800H;
					UART4* = 40004C00H;
					UART5* = 40005000H;
					I2C1* = 40005400H;
					I2C2* = 40005800H;
					I2C3* = 40005C00H;
					HDMICEC* = 40006C00H;
					DAC1* = 40007400H;
					UART7* = 40007800H;
					UART8* = 40007C00H;
					CRS* = 40008400H;
					SWPMI* = 40008800H;
					OPAMP* = 40009000H;
					MDIOS* = 40009400H;
					FDCAN1* = 4000A000H;
					FDCAN2* = 4000A400H;
					CANCCU* = 4000A800H;
					CANMessageRAM* = 4000AC00H;
				(* APB2 (D2) *)
					(* ... *)
				(* AHB1 (D2) *)
					(* ... *)
				(* AHB2 (D2) *)
					(* ... *)
				(* APB3 (D1) *)
					LTDC* = 50001000H;
					WWDG1* = 50003000H;
				(* AHB3 (D1) *)
					(* ... *)
				RAMECC1* = 52009000H;
				(* APB4 (D3) *)
					(* ... *)
				(* AHB4 (D3) *)
					GPIOA* = 58020000H;
					GPIOB* = 58020400H;
					GPIOC* = 58020800H;
					GPIOD* = 58020C00H;
					GPIOE* = 58021000H;
					GPIOF* = 58021400H;
					GPIOG* = 58021800H;
					GPIOH* = 58021C00H;
					GPIOI* = 58022000H;
					GPIOJ* = 58022400H;
					GPIOK* = 58022800H;
					RCC* = 58024400H;
						RCCCR* = RCC;
						RCCICSCR* = RCC + 4;
						RCCHSICFGR* = RCC + 4;
						RCCCRRCR* = RCC + 8;
						RCCCSICFGR* = RCC + 0CH;
						RCCCFGR* = RCC + 10H;
						RCCD1CFGR* = RCC + 18H;
						RCCD2CFGR* = RCC + 1CH;
						RCCD3CFGR* = RCC + 20H;
						RCCPLLCKSELR* = RCC + 28H;
						RCCPLLCFGR* = RCC + 2CH;
						RCCPLL1DIVR* = RCC + 30H;
						RCCPLL1FRACR* = RCC + 34H;
						RCCPLL2DIVR* = RCC + 38H;
						RCCPLL2FRACR* = RCC + 3CH;
						RCCPLL3DIVR* = RCC + 40H;
						RCCPLL3FRACR* = RCC + 44H;
						RCCD1CCIPR* = RCC + 4CH;
						RCCD2CCIP1R* = RCC + 50H;
						RCCD2CCIP2R* = RCC + 54H;
						RCCD3CCIPR* = RCC + 58H;
						RCCCIER* = RCC + 60H;
						RCCCIFR* = RCC + 64H;
						RCCCICR* = RCC + 68H;
						RCCBDCR* = RCC + 70H;
						RCCCSR* = RCC + 74H;
						RCCAHB3RSTR* = RCC + 7CH;
						RCCAHB1RSTR* = RCC + 80H;
						RCCAHB2RSTR* = RCC + 84H;
						RCCAHB4RSTR* = RCC + 88H;
						RCCAPB3RSTR* = RCC + 8CH;
						RCCAPB1LRSTR* = RCC + 90H;
						RCCAPB1HRSTR* = RCC + 94H;
						RCCAPB2RSTR* = RCC + 98H;
						RCCAPB4RSTR* = RCC + 9CH;
						RCCGCR* = RCC + 0A0H;
						RCCD3AMR* = RCC + 0A8H;
						RCCRSR* = RCC + 0D0H;
						RCCAHB3ENR* = RCC + 0D4H;
						RCCAHB1ENR* = RCC + 0D8H;
						RCCAHB2ENR* = RCC + 0DCH;
						RCCAHB4ENR* = RCC + 0E0H;
						RCCAPB3ENR* = RCC + 0E4H;
						RCCAPB1LENR* = RCC + 0E8H;
						RCCAPB1HENR* = RCC + 0ECH;
						RCCAPB2ENR* = RCC + 0F0H;
						RCCAPB4ENR* = RCC + 0F4H;
						RCCAHB3LPENR* = RCC + 0FCH;
						RCCAHB1LPENR* = RCC + 100H;
						RCCAHB2LPENR* = RCC + 104H;
						RCCAHB4LPENR* = RCC + 108H;
						RCCAPB3LPENR* = RCC + 10CH;
						RCCAPB1LLPENR* = RCC + 110H;
						RCCAPB1HLPENR* = RCC + 114H;
						RCCAPB2LPENR* = RCC + 118H;
						RCCAPB4LPENR* = RCC + 11CH;
						RCCC1AHB3ENR* = RCC + 134H;
						RCCC1AHB1ENR* = RCC + 138H;
						RCCC1AHB2ENR* = RCC + 13CH;
						RCCC1AHB4ENR* = RCC + 140H;
						RCCC1APB3ENR* = RCC + 144H;
						RCCC1APB1LENR* = RCC + 148H;
						RCCC1APB1HENR* = RCC + 14CH;
						RCCC1APB2ENR* = RCC + 150H;
						RCCC1APB4ENR* = RCC + 154H;
						RCCC1AHB3LPENR* = RCC + 15CH;
						RCCC1AHB1LPENR* = RCC + 160H;
						RCCC1AHB2LPENR* = RCC + 164H;
						RCCC1AHB4LPENR* = RCC + 168H;
						RCCC1APB3LPENR* = RCC + 16CH;
						RCCC1APB1LLPENR* = RCC + 170H;
						RCCC1APB1HLPENR* = RCC + 174H;
						RCCC1APB2LPENR* = RCC + 178H;
						RCCC1APB4LPENR* = RCC + 17CH;
					PWR* = 58024800H;
					CRC* = 58024C00H;
					BDMA* = 58025400H;
					DMAMUX2* = 58025800H;
					ADC3* = 58026000H;
					HSEM* = 58026400H;
				RAMECC3* = 58027000H;
			(* External Memories *)
				(* ... *)
			(* External Devices *)
				(* ... *)
		(* interrupt sources *)
			(* ... *)

END MicroSTM32H7.
