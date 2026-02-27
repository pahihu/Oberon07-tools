MODULE MicroSTM32L1;

	(*
		Alexander Shiryaev, 2021.10

		RM0038, Reference manual,
			STM32L100xx, STM32L151xx, STM32L152xx, STM32L162xx
	*)

	CONST
		(* memory map *)
			BootStart* = 0H;
			FlashStart* = 8000000H;
			SRAMStart* = 20000000H;
			(* APB1 *)
				TIM2* = 40000000H;
				TIM3* = 40000400H;
				TIM4* = 40000800H;
				TIM5* = 40000C00H;
				TIM6* = 40001000H;
				TIM7* = 40001400H;
				LCD* = 40002400H;
				RTC* = 40002800H;
				WWDG* = 40002C00H;
				IWDG* = 40003000H;
					IWDGKR* = IWDG;
					IWDGPR* = IWDG + 4;
					IWDGRLR* = IWDG + 8;
					IWDGSR* = IWDG + 0CH;
				SPI2* = 40003800H;
				SPI3* = 40003C00H;
				USART2* = 40004400H;
				USART3* = 40004800H;
				USART4* = 40004C00H;
				USART5* = 40005000H;
				I2C1* = 40005400H;
					I2C1CR1* = I2C1;
					I2C1CR2* = I2C1 + 4;
					I2C1OAR1* = I2C1 + 8;
					I2C1OAR2* = I2C1 + 0CH;
					I2C1DR* = I2C1 + 10H;
					I2C1SR1* = I2C1 + 14H;
					I2C1SR2* = I2C1 + 18H;
					I2C1CCR* = I2C1 + 1CH;
					I2C1TRISE* = I2C1 + 20H;
				I2C2* = 40005800H;
					I2C2CR1* = I2C2;
					I2C2CR2* = I2C2 + 4;
					I2C2OAR1* = I2C2 + 8;
					I2C2OAR2* = I2C2 + 0CH;
					I2C2DR* = I2C2 + 10H;
					I2C2SR1* = I2C2 + 14H;
					I2C2SR2* = I2C2 + 18H;
					I2C2CCR* = I2C2 + 1CH;
					I2C2TRISE* = I2C2 + 20H;
				USBDeviceFS* = 40005C00H;
				USBDeviceFSSRAM* = 40006000H;
				PWR* = 40007000H;
					PWRCR* = PWR;
					PWRCSR* = PWR + 4;
				DAC* = 40007400H;
				COMP* = 40007C00H;
				RI* = 40007C04H;
				OPAMP* = 40007C5CH;
			(* APB2 *)
				SYSCFG* = 40010000H;
				EXTI* = 40010400H;
				TIM9* = 40010800H;
				TIM10* = 40010C00H;
				TIM11* = 40011000H;
				ADC* = 40012400H;
				SDIO* = 40012C00H;
				SPI1* = 40013000H;
				USART1* = 40013800H;
			(* AHB *)
				GPIOA* = 40020000H;
				GPIOB* = 40020400H;
				GPIOC* = 40020800H;
				GPIOD* = 40020C00H;
				GPIOE* = 40021000H;
				GPIOH* = 40021400H;
				GPIOF* = 40021800H;
				GPIOG* = 40021C00H;
				CRC* = 40023000H;
				RCC* = 40023800H;
					RCCCR* = RCC;
					RCCICSCR* = RCC + 4;
					RCCCFGR* = RCC + 8;
					RCCCIR* = RCC + 0CH;
					RCCAHBRSTR* = RCC + 10H;
					RCCAPB2RSTR* = RCC + 14H;
					RCCAPB1RSTR* = RCC + 18H;
					RCCAHBENR* = RCC + 1CH;
					RCCAPB2ENR* = RCC + 20H;
					RCCAPB1ENR* = RCC + 24H;
					RCCAHBLPENR* = RCC + 28H;
					RCCAPB2LPENR* = RCC + 2CH;
					RCCAPB1LPENR* = RCC + 30H;
					RCCCSR* = RCC + 34H;
				FLASH* = 40023C00H;
					FLASHACR* = FLASH;
					FLASHPECR* = FLASH + 4;
					FLASHPDKEYR* = FLASH + 8;
					FLASHPEKEYR* = FLASH + 0CH;
					FLASHPRGKEYR* = FLASH + 10H;
					FLASHOPTKEYR* = FLASH + 14H;
					FLASHSR* = FLASH + 18H;
					FLASHOBR* = FLASH + 1CH;
					(*
					FLASHWRPR1* = FLASH + 20H;
					FLASHWRPR2* = FLASH + 80H;
					FLASHWRPR3* = FLASH + 84H;
					FLASHWRPR4* = FLASH + 88H;
					*)
				DMA1* = 40026000H;
				DMA2* = 40026400H;
				AES* = 50060000H;
				FSMC* = 0A0000000H;
			DBGMCU* = 0E0042000H;
				DBGMCUIDCODE* = DBGMCU;
				DBGMCUCR* = DBGMCU + 4;
				DBGMCUAPB1FZ* = DBGMCU + 8;
				DBGMCUAPB2FZ* = DBGMCU + 0CH;
		(* interrupt sources *)
			WWDGInt* = 0;
			PVDInt* = 1;
			TAMPERSTAMPInt* = 2;
			RTCWKUPInt* = 3;
			FLASHInt* = 4;
			RCCInt* = 5;
			EXTI0Int* = 6;
			EXTI1Int* = 7;
			EXTI2Int* = 8;
			EXTI3Int* = 9;
			EXTI4Int* = 10;
			DMA1Channel1Int* = 11;
			DMA1Channel2Int* = 12;
			DMA1Channel3Int* = 13;
			DMA1Channel4Int* = 14;
			DMA1Channel5Int* = 15;
			DMA1Channel6Int* = 16;
			DMA1Channel7Int* = 17;
			ADC1Int* = 18;
			USBHPInt* = 19;
			USBLPInt* = 20;
			DACInt* = 21;
			COMPInt* = 22;
			EXTI95Int* = 23;
			LCDInt* = 24;
			TIM9Int* = 25;
			TIM10Int* = 26;
			TIM11Int* = 27;
			TIM2Int* = 28;
			TIM3Int* = 29;
			TIM4Int* = 30;
			I2C1EVInt* = 31;
			I2C1ERInt* = 32;
			I2C2EVInt* = 33;
			I2C2ERInt* = 34;
			SPI1Int* = 35;
			SPI2Int* = 36;
			USART1Int* = 37;
			USART2Int* = 38;
			USART3Int* = 39;
			EXTI1510Int* = 40;
			RTCAlarmInt* = 41;
			USBFSWKUPInt* = 42;
			TIM6Int* = 43;
			TIM7Int* = 44;

			SDIOInt* = 45;
			TIM5Int* = 46;
			SPI3Int* = 47;
			UART4Int* = 48;
			UART5Int* = 49;
			DMA2CH1Int* = 50;
			DMA2CH2Int* = 51;
			DMA2CH3Int* = 52;
			DMA2CH4Int* = 53;
			DMA2CH5Int* = 54;
			AESInt* = 55;
			COMPACQInt* = 56;

END MicroSTM32L1.
