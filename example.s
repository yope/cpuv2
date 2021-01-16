
reset:
	ldi r0, 0
	b start
msg:
	.STRW "Hello World!!\0"

ascii_conv:
	andi r7, r6, 0xe0
	andi r8, r6, 0x1f
	sr4i r7, r7, 0
	shli r7, r7, 0
	ldw r7, r7, conv_map
	or r6, r7, r8
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
	ldi r11, 0x80000
delay_loop:
	subi r11, r11, 1
	bne delay_loop
	rts

delay2:
	ldi r11, 0x80000
	bdec r11, 0
	rts

start:
	ldiu r3, 0x02000
	ldi r4, 0x12bf
	ldi r5, 0x20
clear:
	addi r3, r3, 1
	subi r4, r4, 1
	stb r3, r5, 0
	bne clear
	ldiu r2, 0x01000

start2:
	ldiu r3, 0x02000
	ldi r4, msg
	ldi r5, 11
msgloop:
	ldw r6, r4, 0
	addi r6, r6, 0
	beq msgend
	jsr r0, ascii_conv
	stb r3, r6, 0
	addi r3, r3, 1
	addi r4, r4, 4
	b msgloop
msgend:

loop:
	ldi r1, 0xaa
	stw r2, r1, 0
	jsr r0, delay
	ldi r1, 0x55
	stw r2, r1, 0
	jsr r0, delay2
	ldiu r3, 0x02000
	addi r3, r3, 415
	ldi r4, 0xff
loop2:
	stb r3, r4, 0
	subi r3, r3, 1
	subi r4, r4, 1
	bne loop2
	b loop
