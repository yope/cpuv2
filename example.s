
reset:
	ldi r0, 0
	b start

delay:
	ldi r11, 0x80000
delay_loop:
	subi r11, r11, 1
	bne delay_loop
	rts

start:
	ldiu r2, 0x01000
loop:
	ldi r1, 0xaa
	stw r2, r1, 0
	jsr r0, delay
	ldi r1, 0x55
	stw r2, r1, 0
	jsr r0, delay
	b loop
