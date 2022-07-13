;-------------------------------------------------------------------------------
;	BIEN4220/5220	Midterm	Exam	MSP430	Assembler	Code	Template
;
;	Student	Name: Claire Kraft
;	Number	of	characters	in	First	Name	(M): 6
;	Sum	of	characters	in	First	AND	Last	Name	(N): 11
;
;-------------------------------------------------------------------------------
			.cdecls	C,LIST,"msp430.h"			;	Include	device	header	file

;-------------------------------------------------------------------------------
						.def	RESET			;	Export	program	entry-point	to
																																												;	make	it	known	to	linker.
;-------------------------------------------------------------------------------
						.text					;	Assemble	into	program	memory.
						.retain					;	Override	ELF	conditional	linking
																																												;	and	retain	current	section.
						.retainrefs				;	And	retain	any	sections	that	have
																																												;	references	to	current	section.
;-------------------------------------------------------------------------------
RESET					mov.w			#__STACK_END,SP				;	Initialize	stackpointer
StopWDT					mov.w			#WDTPW|WDTHOLD,&WDTCTL		;	Stop	watchdog	timer
;-------------------------------------------------------------------------------
;	Main:Enter your	assigned code here
;-------------------------------------------------------------------------------


		mov.w 	#2400h, R4
		mov.w	@R4, R5
		mov.w 	#2408h, R6
		mov.w	#0000h, R7
		mov.w	R5, R8

MyTable
		cmp.b	#0, R8			;
		jeq		bye				; leave the loop if R8 is 0

		mov.w	R7, 0(R6)		; move the value in R7 to 2408 in memory
		add.w	#6, R7			; add m to the number in R7
		add.w	#2, R6			; increment the memory loaction by 2
		dec		R8				; decrement the register 8
		jmp 	MyTable			; jump to loop



bye


;-------------------------------------------------------------------------------
;	END	of	code - let your	code get "caught" here in this infinite	loop
;-------------------------------------------------------------------------------
BLOCK 					jmp 	BLOCK
						nop



;-------------------------------------------------------------------------------
;	Stack	Pointer	definition
;-------------------------------------------------------------------------------
				.global	__STACK_END
				.sect			.stack

;-------------------------------------------------------------------------------
;	Interrupt	Vectors
;-------------------------------------------------------------------------------
				.sect			".reset"		;	MSP430	RESET	Vector
				.short		RESET

