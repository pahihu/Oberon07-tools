MODULE MicroSTM32L1Config;

	(*
		Alexander Shiryaev, 2021.09, 2023.06
	*)

	IMPORT SYSTEM,
		Config := MicroConfig,
		Flash := MicroSTM32L1Flash;

	CONST
		configAdr = Flash.EEPROM;

		(* Store result *)
			ok* = Config.ok;
			notModified* = Config.notModified;
			verifyFailed* = Config.verifyFailed;

	PROCEDURE ConfigWrite (from: INTEGER; n: INTEGER; VAR res: INTEGER);
		VAR i, x, y: INTEGER;
	BEGIN
		ASSERT(n > 0);
		(* ASSERT(n <= Config.maxConfigWords) *)

		Flash.DUnLock;
			i := 0;
			REPEAT
				SYSTEM.GET(from + i * 4, x);
				SYSTEM.GET(configAdr + i * 4, y);
				IF x # y THEN
					SYSTEM.PUT(configAdr + i * 4, x)
				END;
				INC(i)
			UNTIL i = n;
		Flash.DLock;

		res := ok
	END ConfigWrite;

	PROCEDURE Init* (configKey: INTEGER);
	BEGIN
		Config.Init(configKey, configAdr, ConfigWrite)
	END Init;

	PROCEDURE Load* (VAR res: SET);
	BEGIN
		Config.Load(res)
	END Load;

	PROCEDURE Store* (VAR res: INTEGER);
	BEGIN
		Config.Store(res)
	END Store;

	PROCEDURE Default*;
	BEGIN
		Config.Default
	END Default;

END MicroSTM32L1Config.
