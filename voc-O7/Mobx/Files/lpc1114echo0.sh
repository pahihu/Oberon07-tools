rm -f sym/* obj/*
rm -f *.hex *.bin
rm -f *.out Oberon.Log

O7ARMv6MP Compile MobxLPC1114Echo0.Mod/s

O7ARMv6MLinker Link LPC1114FBD48302 MobxLPC1114FBD48302Echo0 

O7ARMv7MTool DecHex MobxLPC1114FBD48302Echo0.hex > dechex.out

O7ARMv7MTool DecBin MobxLPC1114FBD48302Echo0.bin > decbin.out
