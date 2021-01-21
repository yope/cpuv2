
# Monitor program
#
# Register usage:
# r0: 0, zero, null, zip, nada
# r1...r4: Scratch registers. Clobbered by subroutine
# r5...r8: Working registers. Never clobbered
# r9...r12: Arguments passed to subroutine, return values from subroutine
#
# Subroutines:
# No need to push/pop lr if it doesn't call any other subroutine within.
#

reset:
	ldi r0, 0
	ldi sp, 0xffc
	ldi r1, bss_end
	subi r2, r1, bss
	shri r2, r2, 0
	shri r2, r2, 0
	subi r2, r2, 1
bss_copy_loop:
	subi r1, r1, 4
	stw r1, r0, 0
	bdec r2, bss_copy_loop
	ldi r1, 0x4c	# Default color code
	stw r0, r1, v_color
	b main

# Global variables
bss:
v_cursor_x:
	.WORD 0
v_cursor_y:
	.WORD 0
v_blink_count:
	.WORD 0
v_blink_flag:
	.WORD 0
v_color:
	.WORD 0
stdout:
	.WORD 0

bss_end:

ascii_conv:
	andi r1, r9, 0xe0
	andi r9, r9, 0x1f
	sr4i r1, r1, 0
	shli r1, r1, 0
	ldw r1, r1, conv_map
	or r9, r1, r9
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

putc_uart:
	ldiu r1, 0x03000
	ldw r2, r1, 8	# Read status register
	andi r2, r2, 1	# TX busy?
	bne putc_uart
	stw r1, r9, 0
	rts

getc_uart:
	ldiu r1, 0x03000
	ldw r9, r1, 8 # Status register
	andi r9, r9, 2 # Check RX full flag
	ldiseq r9, 0xfff00 # No RX, return -256
	rtseq
	ldw r9, r1, 4 # RXD register
	rts

get_cursor_address:
	# Return r9 = x, r10 = y and r11 = address in screen RAM
	ldw r10, r0, v_cursor_y	# r10 = cursor_y
	sl4i r11, r10, 0
	ori r9, r11, 0
	shli r11, r11, 0
	shli r11, r11, 0
	add r11, r11, r9		# r11 = cursor_y * 80
	ldw r9, r0, v_cursor_x	# r9 = cursor_x
	add r1, r11, r9			# Add to r11
	ldiu r11, 0x02000
	add r11, r11, r1		# Add screen RAM offset
	rts

putc_screen:
	push lr
	push r9
	jsr r0, cursor_blink_off # Turn off cursor
	pop r9
	andi r1, r9, 0x80	# Higher than ASCII?
	beq putc_screen_0	# not? continue
	subi r1, r9, 0x9f	# Last hight control char
	bgt putc_screen_0	# higher? continue
	subi r1, r9, 0x80	# Get color code
	ldw r3, r0, v_color	# load current colors (bg/fg)
	andi r2, r1, 0x10	# Check for BG color
	bne putc_bg_color
	andi r3, r3, 0xf0	# Keep old bg color
	or r3, r3, r1		# Or them together
	stw r0, r3, v_color	# And store
	pop lr
	rts
putc_bg_color:
	andi r3, r3, 0x0f	# Keep old fg color
	sl4i r1, r1, 0		# Shift to bg color pos.
	andi r1, r1, 0xf0	# Isolate new bg color
	or r3, r3, r1		# Or them together
	stw r0, r3, v_color	# And store
	pop lr
	rts
putc_screen_0:
	subi r1, r9, 10		# Check for '\n'
	subine r1, r9, 13	# Check for '\r'
	bne putc_screen_1
	ldi r1, 0			# Set new cursor_x = 0
	stw r0, r1, v_cursor_x
	ldw r10, r0, v_cursor_y
	ori r0, r0, 0		# Set Z flag
	b putc_screen_nl	# Goto next line
putc_screen_1:
	subi r1, r9, 8		# Check back-space
	subine r1, r9, 0x7f	# Check DEL
	bne putc_screen_2
	ldw r1, r0, v_cursor_x
	ori r1, r1, 0		# Check if zero
	subine r1, r1, 1	# Go back one position if not
	stw r0, r1, v_cursor_x
	pop lr				# And we are done.
	rts
putc_screen_2:
	subi r1, r9, 12		# Check for FF (clear screen)
	bne putc_screen_3
	stw r0, r0, v_cursor_x # If equal, home the cursor,...
	stw r0, r0, v_cursor_y
	pop lr				# ..., pop lr and
	b clear				# jump to clear routine
putc_screen_3:
	jsr r0, ascii_conv
	push r9				# Save r9 on stack
	jsr r0, get_cursor_address
	pop r1				# pop character in r1 (former r9)
	stb r11, r1, 0		# Store character to screen
	ldw r1, r0, v_color	# Get bg/fg colors
	stb r11, r1, 0x2000	# Store in color RAM
	addi r9, r9, 1
	subi r3, r9, 80		# Is cursor past end of line
	stwge r0, r3, v_cursor_x # Sore new position
	stwlt r0, r9, v_cursor_x # Or stor old position + 1
putc_screen_nl:
	addige r10, r10, 1	# Goto next line if needed
	subi r2, r10, 60	# Is cursor past end of screen
	ldige r10, 59		# then place cursor on last line...
	stw r0, r10, v_cursor_y
	jsrge r0, scroll	# and scroll up.
	pop lr
	rts

putc: # r9: character, r10: device: 0=screen, 1=serial
	ldw r1, r0, stdout
	ori r1, r1, 0
	beq putc_screen
	ldw r1, r0, stdout
	subi r1, r1, 1
	beq putc_uart
	rts					# Not reached unless unsupported device number

puts:
	push lr
	push r8
	ori r8, r9, 0		# Store pointer in r8
puts_loop:
	ldb r9, r8, 0		# Load next char from string
	ori r9, r9, 0		# Set flags
	beq puts_end 		# If it is 0, finish
	jsr r0, putc		# Otherwise print it
	addi r8, r8, 1		# Increment pointer
	b puts_loop
puts_end:
	addi r9, r8, 1		# return address after \0
	pop r8
	pop lr
	rts

printsi: # Print screen immediate
	ori r9, lr, 0		# Get lr, which points to the string
	jsr r0, puts		# puts returns address after \0 in r9
	andi r1, r9, 3		# Align r9 to 32 bits
	beq printsi_end		# Already aligned? Exit...
	xorine r1, r1, 3	# Do alignment
	add r9, r9, r1
	addine r9, r9, 1
printsi_end:
	ori lr, r9, 0		# save new lr as return address
	rts					# Return there

printhex4:
	push lr
	andi r9, r9, 0x0f
	ldb r9, r9, printhex4_table
	jsr r0, putc
	pop lr
	rts
printhex4_table:
	.STR "0123456789abcdef"

printhex8:
	push lr
	push r9
	sr4i r9, r9, 0
	andi r9, r9, 0x0f
	ldb r9, r9, printhex4_table
	jsr r0, putc
	pop r9
	andi r9, r9, 0x0f
	ldb r9, r9, printhex4_table
	jsr r0, putc
	pop lr
	rts

printhex16:
	push lr
	push r9
	sr4i r9, r9, 0
	sr4i r9, r9, 0
	jsr r0, printhex8
	pop r9
	jsr r0, printhex8
	pop lr
	rts

printhex32:
	push lr
	push r9
	sr16i r9, r9, 0
	jsr r0, printhex16
	pop r9
	jsr r0, printhex16
	pop lr
	rts

scroll:
	push r4
	ldiu r1, 0x02000
	ldi r2, 4720
scroll_loop:
	ldb r3, r1, 80
	stb r1, r3, 0
	ldb r3, r1, 0x2050
	stb r1, r3, 0x2000
	addi r1, r1, 1
	bdec r2, scroll_loop
	ldi r2, 80
	ldi r3, 0x20
	ldw r4, r0, v_color
scroll_loop2:
	stb r1, r3, 0
	stb r1, r4, 0x2000
	addi r1, r1, 1
	bdec r2, scroll_loop2
	pop r4
	rts

cursor_blink:
	ldw r1, r0, v_blink_count
	addi r1, r1, 1
	ldi r2, 0x20000
	sub r2, r1, r2
	stwge r0, r0, v_blink_count
	stwlt r0, r1, v_blink_count
	ldi r2, 0x10000
	and r2, r1, r2
	beq cursor_blink_off
cursor_blink_on:
	ldw r1, r0, v_blink_flag
	ori r1, r1, 0			# Check if set
	rtsne					# Already set? -> return
	ldi r5, 1				# New flag value 1
cursor_blink_invert:
	push lr
	jsr r0, get_cursor_address
	pop lr
	ldb r1, r11, 0			# Get character at cursor
	xori r1, r1, 0x80		# Invert MSB
	stb r11, r1, 0			# And store it back
	stw r0, r5, v_blink_flag # Store new flag value
	rts
cursor_blink_off:
	ldw r1, r0, v_blink_flag
	ori r1, r1, 0			# Check if set
	ldine r5, 0				# New flag value 0
	bne cursor_blink_invert	# Set, then invert character and clear
	rts

clear:
	ldi r1, 0x20 # Space character
	ldw r2, r0, v_color
	ldi r3, 0x12bf
	ldiu r4, 0x02000
clear_loop:
	stb r4, r1, 0
	stb r4, r2, 0x2000
	addi r4, r4, 1
	bdec r3, clear_loop
	rts

main:
	jsr r0, clear
	ldi r9, 10 # cr
	jsr r0, putc_screen
	ldi r1, 1
	stw r0, r1, stdout	# Send text to UART
	jsr r0, printsi
	.STR "MyCPU v2 command interface\r\n\0"
	stw r0, r0, stdout	# Back to screen
	b main_status_line
main_loop:
	jsr r0, cursor_blink
	jsr r0, getc_uart
	ori r9, r9, 0	# Check sign
	blt main_loop   # No char? Try again
main_read_loop:
	ldiu r1, 0x01000
	stb r1, r9, 0	# Debug uart RX reg
	jsr r0, putc_screen
	jsr r0, getc_uart		# Are there more chars in fifo?
	ori r9, r9, 0			# Check
	bge main_read_loop		# Read them all
main_status_line:
	ldw r5, r0, v_cursor_x
	ldw r6, r0, v_cursor_y
	ldw r7, r0, v_color
	stw r0, r0, v_cursor_x
	stw r0, r0, v_cursor_y
	jsr r0, printsi
	.STR "\x81\x98    Terminal screen line: \0"
	ori r9, r6, 0
	jsr r0, printhex8
	jsr r0, printsi
	.STR " column: \0"
	ori r9, r5, 0
	jsr r0, printhex8
	ldw r8, r0, v_cursor_x
	subi r8, r8, 80
	noti r8, r8, 0
main_fill_line:
	ldi r9, 0x20
	jsr r0, putc_screen
	bdec r8, main_fill_line
	stw r0, r5, v_cursor_x
	stw r0, r6, v_cursor_y
	stw r0, r7, v_color
	b main_loop
