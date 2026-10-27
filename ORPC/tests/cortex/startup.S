.syntax unified
.thumb
.section .isr_vector,"a",%progbits
.global vectors
vectors:
.word _estack
.word Reset_Handler
.rept 13
.word Default_Handler
.endr
.word OCG_Exception_15_Handler
.rept 5
.word Default_Handler
.endr
.word OCG_IRQ_5_Handler
.section .text.Reset_Handler,"ax",%progbits
.global Reset_Handler
.type Reset_Handler,%function
.thumb_func
Reset_Handler:
ldr r0, =_sidata
ldr r1, =_sdata
ldr r2, =_edata
1:
cmp r1, r2
bcs 2f
ldr r3, [r0]
str r3, [r1]
adds r0, #4
adds r1, #4
b 1b
2:
ldr r1, =_sbss
ldr r2, =_ebss
movs r3, #0
3:
cmp r1, r2
bcs 4f
str r3, [r1]
adds r1, #4
b 3b
4:
bl main
movs r0, #0
bl board_exit
b .
.size Reset_Handler, .-Reset_Handler
.thumb_func
.type Default_Handler,%function
Default_Handler:
movs r0, #2
bl board_exit
b .
