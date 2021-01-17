
reset:
	ldi r0, 0
	ldi sp, 2047 # Stack at end of 2kB growing downwards
	b start
msg:
	.STR "Hello World!!\0"

ascii_conv:
	andi r7, r12, 0xe0
	andi r12, r12, 0x1f
	sr4i r7, r7, 0
	shli r7, r7, 0
	ldw r7, r7, conv_map
	or r12, r7, r12
	rts
conv_map:
	.WORD 0x00000080
	.WORD 0x00000020
	.WORD 0x00000040
	.WORD 0x00000000
	.WORD 0x000000C0
	.WORD 0x00000060
	.WORD 0x00000040
	.WORD 0x00000060

delay:
	ldi r11, 0xa0000
	bdec r11, 0
	rts

clear:
	ldi r10, 0x20
	ldi r12, 0x12bf
	ldiu r11, 0x02000
clear_loop:
	stb r11, r10, 0
	addi r11, r11, 1
	bdec r12, clear_loop
	rts

print: # R8: x, R9: y, R10: pointer
	sl4i r12, r9, 0
	shli r11, r12, 0
	shli r11, r11, 0
	add r12, r12, r11
	ldiu r11, 0x02000
	add r11, r11, r12
	add r11, r11, r8
print_loop:
	ldb r12, r10, 0
	addi r12, r12, 0
	rtseq
	stw sp, lr, 0 # push lr
	jsr r0, ascii_conv
	ldw lr, sp, 0 # pop lr
	stb r11, r12, 0
	addi r10, r10, 1
	addi r11, r11, 1
	b print_loop

start:
	jsr r0, clear
	ldi r8, 1
	ldi r9, 1
	ldi r10, msg
	jsr r0, print
	ldi r8, 0
loop:
	ldiu r2, 0x01000
	stw r2, r8, 0
	jsr r0, delay
	ldiu r3, 0x02000
	addi r3, r3, 415
	ldi r4, 0xff
loop2:
	stb r3, r4, 0
	subi r3, r3, 1
	subi r4, r4, 1
	bge loop2
	jsr r0, scroll
	ldi r9, 59
	ldi r10, msg
	jsr r0, print
	addi r8, r8, 1
	subi r1, r8, 40
	ldieq r8, 0
	b loop

scroll:
	ldiu r3, 0x02000
	ldi r4, 4720
scroll_loop:
	ldb r5, r3, 80
	stb r3, r5, 0
	addi r3, r3, 1
	bdec r4, scroll_loop
	ldi r4, 80
	ldi r5, 0x20
scroll_loop2:
	stb r3, r5, 0
	addi r3, r3, 1
	bdec r4, scroll_loop2
	rts
