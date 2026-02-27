MODULE MicroCRC16CCITT1021;

	(* Alexander Shiryaev, 2014.11 *)

	CONST init* = 0FFFFH;

	(*
		http://www.ccsinfo.com/forum/viewtopic.php?t=24977
		unsigned short crc_1021 (unsigned short crc, unsigned char data)
		{
			unhsigned short x;
			x = ((crc >> 8) ^ data) & 0xff;
			x ^= x >> 4;
			crc = (crc << 8) ^ (x << 12) ^ (x << 5) ^ x;
			return crc; /* & 0xffff */
		}
	*)
	PROCEDURE Update* (cs: INTEGER; x: SHORTCHAR): INTEGER;
		VAR y: INTEGER;
	BEGIN
		(* ASSERT 0 <= cs <= 0FFFFH *)
		x := SHORT(CHR(ORD(BITS(cs DIV 100H) / BITS(ORD(x)))));
		y := ORD(BITS(ORD(x)) / BITS(ORD(x) DIV 10H));
		RETURN
			ORD(BITS(cs * 100H) / BITS(y * 1000H) / BITS(y * 20H) / BITS(y))
				MOD 10000H
	END Update;

END MicroCRC16CCITT1021.
