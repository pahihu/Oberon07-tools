MODULE MicroSTM32F4Config;

	(*
		Alexander Shiryaev, 2015.01, 2018.06, 2021.08

		STM32F4
	*)

	IMPORT SYSTEM,
		ARMv7M := MicroARMv7M,
		Config := MicroConfig,
		Flash := MicroSTM32F4Flash;

	CONST
		(* Store result *)
			ok* = Config.ok;
			notModified* = Config.notModified;
			verifyFailed* = Config.verifyFailed;

	VAR
		configSector: INTEGER;
		configAdr: INTEGER;

	PROCEDURE ConfigWrite (from: INTEGER; n: INTEGER; VAR res: INTEGER);
		VAR i, x: INTEGER;
	BEGIN
		ASSERT(n > 0);
		ARMv7M.CPSIDif; Flash.UnLock;
			Flash.EraseSector(configSector, res);
			IF res = Flash.complete THEN
				i := 0;
				REPEAT
					SYSTEM.GET(from + i * 4, x);
					Flash.Write(configAdr + i * 4, x, res);
					INC(i)
				UNTIL (i = n) OR (res # Flash.complete)
			END;
		Flash.Lock; ARMv7M.CPSIEif
	END ConfigWrite;

	PROCEDURE Init* (configKey: INTEGER);
		VAR x: INTEGER;
	BEGIN
		x := Flash.SizeKiB();
		IF x >= 1024 THEN (* G/I *) configSector := 11; configAdr := Flash.Sector11
		ELSIF x = 768 THEN (* F *) configSector := 9; configAdr := Flash.Sector9
		ELSIF x = 512 THEN (* E *) configSector := 7; configAdr := Flash.Sector7
		ELSIF x = 384 THEN (* D *) configSector := 6; configAdr := Flash.Sector6
		ELSIF x = 256 THEN (* C *) configSector := 5; configAdr := Flash.Sector5
		ELSIF x = 128 THEN (* B *) configSector := 4; configAdr := Flash.Sector4
		ELSE ASSERT(FALSE)
		END;

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

END MicroSTM32F4Config.
