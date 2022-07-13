;*******************************************************************************
;
;

				.cdecls C,LIST,  "msp430FR2433.h"



				; RAM variables defined as global for debugging
				.global	TXptr
				.global RX_ind
				.global	RX_buf_st
				.global Dum1, Dum2, Dum3, Dum4
				.global	MyTable

				.def    RESET                   ; Export program entry-point to
												; make it known to linker.


				.global _initialize            ; export initialize as a global symbol (subroutine)


				;-------------------------------------------------------------------------------
           		 .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
           		 .retainrefs                     ; And retain any sections that have
                                            ; references to current section.


;*******************************************************************************
; Equate Directives
;*******************************************************************************
minValidpos		.equ	89
maxValidpos		.equ	117
maxValidStates	.equ 	8

OUTPIN			.equ	BIT1
OUTPIN2			.equ	BIT2				; set the outpin to pin 1.0.

BTTNMASK		.equ 	BIT3			; P2.3 for button input
BTTNMASK2		.equ 	BIT7			; P2.7 for button input

maxTAcount      .equ    125		; Max count for the timer to fire a timer tick (period)

POS1			.equ	115

		.data

; Dummy memory addresses to demonstrate aligning bytes for word operations.
; The goal is to build the 16-bit value 0x439C
Dum1		.byte	0
Dum2		.byte	0x9C
Dum3		.byte	0x43
Dum4		.byte	0xAA

; Define UART Pins
TX_PIN		.equ	BIT4	; P1.4: USART TX
RX_PIN		.equ	BIT5	; P1.5: USART RX

; Communication (USART)
; USART 0 (BackDoor - TX: P1.4, RX: P1.5)
; Assumes MCLK is running at 16 MHz. BRCLK = SMCLK = MCLK.
; BRCLK 	Baud Rate 	UCOS16 	UCBRx 	UCBRFx 	UCBRSx (p 590 user guide)
; 16000000	9600		1		52		1		0x49
U0_UCOS16	.equ	1
U0_UCBR		.equ	52
U0_UCBRF	.equ	0x10	; either 0x00 or 0x10
U0_UCBRS	.equ	0x49

; RX Data Buffer Variables
RX_BUF_SIZE	.equ	30
TXptr 		.word	0						; Pointer to next address of data to send.
											; TX continues until null byte is detected.
RX_ind		.byte	0						; Byte Index of RX_BUF characters (buffer must be < 255 bytes in size)
			.bss	RX_buf_st, RX_BUF_SIZE	; Reserve an array in RAM (BSS will ALWAYS be saved in RAM)

; Special Text Characters
LF			.equ	0x0A		; Carriage Return
CR 			.equ	0x0D		; Line Feed (New Line)




;*******************************************************************************
; Relate names to general-purpose registers
;  Note: Although these are 16-bit registers, this application only uses
;  byte-sized data
;*******************************************************************************
Index			.equ	R4		; stop light state variable (only byte needed)
State2			.equ	R5		; stop light state variable (only byte needed)
ButtnFlag		.equ	R8		; is the button pressed? (only byte needed)
;Position 		.equ	R6
;Position2		.equ	R7

; R9 is used
rCurrent		.equ	R10
rFinalNum		.equ	R11
rMultFactor		.equ 	R12
rFinalNum2		.equ	R13
Tmp				.equ	R14
MessageReceived .equ	R7
Motor			.equ	R6
;*******************************************************************************
; Enter Program
;*******************************************************************************
                .text							; Executable code goes below

; Code entry point
RESET
				mov.w   #__STACK_END, SP        ; Initialize stackpointer
				call	#_initialize			; Execute subroutine to label "_initialize"
				jmp		loop

				clr		R10
				clr		R11
				mov.b	Dum3, R10
				mov.b	Dum2, R11
				rla		R10
				rla		R10
				rla		R10
				rla		R10
				rla		R10
				rla		R10
				rla		R10
				rla		R10
				add.w	R11, R10

;*******************************************************************************
; Initialization Subroutine
;*******************************************************************************
_initialize
				mov.w   #WDTPW+WDTHOLD, &WDTCTL ; Stop WDT
				bic.w	#LOCKLPM5, &PM5CTL0		; CLEAR LOCK-LowPowerMode5 bit which unlocks GPIO pins

				bis.b	#BIT3, &P1DIR
				bic.b	#BIT3, &P1SEL0
				bis.b	#BIT3, &P1SEL1


; Clock Speed set to 16MHz using FLL
SetupCLK		call	#InitClock

SetupMOTOR										;
				bis.b   #OUTPIN, &P1DIR      	;
				bic.b	#OUTPIN, &P1OUT			;
				bis.b   #OUTPIN, &P1SEL1       ; LED pin set to secondary function (let the timer control this pin)

SetupMOTOR2										;
				bis.b   #OUTPIN2, &P1DIR      	;
				bic.b	#OUTPIN2, &P1OUT			;
				bis.b   #OUTPIN2, &P1SEL1       ; LED pin set to secondary function (let the timer control this pin)



; Set up Port 2 (Button)
SetupBtn		bic.b	#BTTNMASK, &P2DIR 		;	P2.3 as input
				bis.b	#BTTNMASK, &P2REN		;	P2.3 pullup
				bis.b	#BTTNMASK, &P2OUT		;	P2.3 pullup
				bis.b	#BTTNMASK, &P2IES		;	P2.3 hi/low edge
				bic.b	#BTTNMASK, &P2IFG		;	P2.3 IFG Cleared
				bis.b	#BTTNMASK, &P2IE		;	P2.3 interupt enabled

; Set up Port 2 (Button)
SetupBtn2		bic.b	#BTTNMASK2, &P2DIR 		;	P2.7 as input
				bis.b	#BTTNMASK2, &P2REN		;	P2.7 pullup
				bis.b	#BTTNMASK2, &P2OUT		;	P2.7 pullup
				bis.b	#BTTNMASK2, &P2IES		;	P2.7 hi/low edge
				bic.b	#BTTNMASK2, &P2IFG		;	P2.7 IFG Cleared
				bis.b	#BTTNMASK2, &P2IE		;	P2.7 interupt enabled


; Setup Timer
SetupC0		clr		&TA0CCTL0						; Set CCR0's control register (CTL) to default
			mov.w   #maxTAcount, &TA0CCR0  			; Set CCR0's value to HALF_PERIOD (controls period of timer)
SetupC1     mov.w   #OUTMOD_6, &TA0CCTL1   			; Set CCR1's control register to
            mov.w   #POS1, &TA0CCR1  				; Set CCR1's value to
SetupC2     mov.w   #OUTMOD_6, &TA0CCTL2   			; Set CCR1's control register to
            mov.w   #POS1, &TA0CCR2  				; Set CCR1's value to
SetupTA     mov.w   #TASSEL_1+MC_3, &TA0CTL 		; Configure the timer tou use the SMCLK and count in updown mode
                          							; Setting MC to anything but zero will START the timer!

; Clear general registers (clr is the same as clr.w which clears all 16 bits!)
SetupCount		clr		Index					; clear State counter
				clr		State2
				clr 	ButtnFlag				; clear Button pressed flag
				clr 	MessageReceived
				clr 	Motor

; Enable USART on port 1 pins
			bis.b	#RX_PIN+TX_PIN, &P1SEL0
			bic.b	#RX_PIN+TX_PIN, &P1SEL1

; USART 0 (TX: P1.4, RX: P1.5)
; Generates TX Complete and RX Full interrupts
SetupUSART	bis.w 	#UCSWRST, &UCA0CTLW0		; Reset USART
			bis.w	#UCSSEL__SMCLK, &UCA0CTLW0	; 8-bit char length, no parity, UART mode, one stop bit, async, BRCLK = SMCLK
			mov.w	#U0_UCBR, &UCA0BRW			; Baud Rate Control Word Register
			mov.b	#U0_UCBRS, &UCA0MCTLW_H		; Upper byte of Modulation Control Reg
			mov.b	#U0_UCBRF+U0_UCOS16, &UCA0MCTLW_L	; Lower byte of Mod Control Reg
			bic.b 	#UCSWRST, &UCA0CTL1			; Release USART for operation
			mov.w	#UCRXIE, &UCA0IE			; Enable RX interrupt (Only enable TX interrupt (UCTXCPTIE) when needed)



; Enable interrupts and return from subroutine
SetupGIE		nop								; NOP needed before and after GIE
				bis.w   #GIE, SR                ;
				nop
											; Return from the subroutine

; Send first message
			mov.w	#HelloMSG, TXptr		; Load starting address of the message to TXptr
			call	#StartTX				; Call subroutine to send first character
			ret

; Send AOK message
AOK
			mov.w	#aok, TXptr		; Load starting address of the message to TXptr
			call	#StartTX		; Call subroutine to send first character
			dec		R9
			cmp.b	#0x0D, 0(R9)
			jeq		loop
			jmp		ReadInput1

; Send Invalid Range message
InvalidRange
			mov.b	RX_ind, R15
			mov.w	#INVALIDR, TXptr		; Load starting address of the message to TXptr
			call	#StartTX				; Call subroutine to send first character
			jmp		loop

; Send Invalid Index message
InvalidIndex
			mov.b	RX_ind, R15
			mov.w	#INVALIDI, TXptr		; Load starting address of the message to TXptr
			call	#StartTX				; Call subroutine to send first character
			jmp		loop

; Send Invalid Index message
Error
			mov.w	#NO, TXptr				; Load starting address of the message to TXptr
			call	#StartTX				; Call subroutine to send first character
			jmp		loop

;*******************************************************************************
; Main loop - the main loop performs the background task. The background task
;             manages the state machine and polls the button.
;*******************************************************************************
; Main Loop (branches to:)
loop

				cmp.b	#1, MessageReceived
				jeq		ReadInput
				jmp		loop
				nop

****************************
;Read Input
****************************
;converting the input

ReadInput
			mov.b	#0,R15
			mov.b	#0, MessageReceived
			mov.w	#RX_buf_st, R9

ReadInput1	cmp.b	#'M', 0(R9)
			jeq		MotorField
			jmp		Error

MotorField
			inc		R9
			cmp.b	#'1', 0(R9)
			jeq		DoMotor1
			cmp.b	#'2', 0(R9)
			jeq		DoMotor2
			jmp 	Error

;WHAT DO I PUT HERE




***********************************
;String to num
***********************************
Str2Num

				clr		rFinalNum
				clr		rCurrent
				clr		rMultFactor

DoAgain			mov.b	0(R9), rCurrent
				inc 	R9
				cmp.b	#'0', rCurrent
				jl 		done

				cmp.b	#'9'+1, rCurrent
				jge 	done


IsDigit			sub.b	#'0', rCurrent			; Subtracts 0x30 from rCurrentDat and saves result in rCurrentDat
												; C: Digits[idx] -= '0'

												; Software Multiplication (Or you can investigate using the Hardware Multiplier peripheral (MPY) to reduce this to 2-3 lines of code!)
												; A FOR loop would save code space and sacrifice speed.
												; Multiply FinalNum accumulator (R4) by 10. Same as summing the number 10 times! x*5 = x+x+x+x+x
												; C: FinalNum *= 10
				mov.w	rFinalNum, rMultFactor	; Copy FinalNum to the multiplication factor.
												; Now add MultFactor to FinalNum 9 times to emulate multiplying FinalNum by 10
				add.w	rMultFactor, rFinalNum	; (x2) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x3) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x4) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x5) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x6) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x7) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x8) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x9) Add factor to existing FinalNum
				add.w	rMultFactor, rFinalNum	; (x10) Add factor to existing FinalNum

												; At this point, the FinalNum, has been multiplied by 10
												; Now we can add the new digit to the final number (we are adding an 8-bit number to a 16-bit number, we need word ops)
												; C: FinalNum += Digits[idx]
				add.w	rCurrent, rFinalNum
				jmp		DoAgain					; Do it again for the next character

done
				cmp.b 	#1, Motor
				jeq		DoMotor1R
				cmp.b 	#2, Motor
				jeq		DoMotor2R




***********************************
;MOTOR 1
***********************************

DoMotor1
				inc 	R9
				mov.b	#1, Motor
				jmp		Str2Num


DoMotor1R
				cmp.w	#maxValidpos, rFinalNum		; make sure the state is still in bounds
				jl		skip_error1						; jump to skip_state_reset if rfinalnum< #maxValidStates
				jge 	InvalidRange
				cmp.w	#minValidpos, rFinalNum
				jl		InvalidRange
				jge		skip_error1
				jmp 	loop

skip_error1
				mov.w	rFinalNum, &TA0CCR1
				jmp		AOK
				jmp		loop

***********************************
;MOTOR 2
***********************************

DoMotor2
				inc 	R9
				mov.b	#2, Motor
				mov.b	0(R9), Tmp
				inc 	R9
				mov.w	Tmp, Index
				sub.b	#'0', Index
				add.w	Index, Index
				jmp		Str2Num

DoMotor2R

				;inc		R9
				cmp.b	#maxValidStates, Index
				jge		InvalidIndex

				cmp.w	#maxValidpos, rFinalNum
				jge		InvalidRange
				cmp.w	#minValidpos, rFinalNum
				jl		InvalidRange
				mov.w   rFinalNum, MyTable(Index)
				jmp		AOK
				jmp 	loop



;*******************************************************************************
;	Button Interrupt Service Routine (ISR) - executes every time buttons are pressed
;*******************************************************************************

BTN_ISR
				bit.b	    #BTTNMASK2, &P2IFG
				jnz			change_states2




change_states2
				bic.b	#BTTNMASK2, &P2IFG
				add.b		#2, State2					;
				cmp.b	#maxValidStates, State2		; make sure the state is still in bounds
				jl		skip_state_reset2			; jump to skip_state_reset if state< #maxValidStates
				mov.b	#0, State2

skip_state_reset2
				mov.w	MyTable(State2), &TA0CCR2
				reti



;-------------------------------------------------------------------------------
; UART 0 ISR Handler
; Use UCA IV to determine if RX or TX event.
; RX ISR saves RX data to data buffer.
; R15 is used by the ISR but is pushed to the stack and popped when completed.
;-------------------------------------------------------------------------------
UART_ISR	push	R15						; Push R15 to the stack so we can use R15
			add.w	&UCA0IV, PC				; Add interrupt vector to PC (clears that flag)
			reti
			jmp		RX_buf_full				; RX buffer full (RXIFG) (Get data out of buffer ASAP)
			jmp		UART_DONE				; [UNUSED] TX buffer empty (TXIFG) (Outgoing data has been loaded into shift reg)
			jmp		UART_DONE				; [UNUSED] Start bit received (STTIFG)
			jmp		TX_comp					; TX complete (TXCPTIFG) (Shift register is now empty)
			jmp		UART_DONE

UART_DONE	pop		R15						; Exit code for all UART vectors
			reti

; RX buffer --------------------------------------------------------------------
RX_buf_full	mov.b	RX_ind, R15						; We already pushed R15 to stack, now load data from RAM to R15
			mov.b	&UCA0RXBUF, RX_buf_st(R15)		; move data from rx buffer and save it in data buffer
			cmp.b	#0x0D, RX_buf_st(R15)
			jne		RXskip
			mov.b	#1, MessageReceived
			mov.w	#0x00, RX_ind

RXskip		inc		R15								; Increment R15 to the next buffer address
			cmp.b	#RX_BUF_SIZE, R15				; Check if we exceeded our buffer (this prevents a Buffer Overflow cyber attack!)
			jl		skip_RX_ind_reset
			clr		R15
skip_RX_ind_reset
			cmp.b	#1, MessageReceived
			jeq		UART_DONE
			mov.b	R15, RX_ind					; Our buffer index (in R15 still) is valid, move it back to RAM for storage.
			jmp		UART_DONE					; Jump to exit code to pop R15 back to the way we found it!




; Transmission ------------------------------------------------------------------
TX_comp		mov.w	TXptr, R15					; Load TX pointer from memory
			tst.b	0(R15)						; Is the next requested char a NULL?
			jz		MSG_Done
			mov.b	@R15+, &UCA0TXBUF			; Load char into buffer (triggers transmission)
			mov.w	R15, TXptr					; Return updated pointer to memory
			jmp		UART_DONE
MSG_Done	bic.w	#UCTXCPTIE, &UCA0IE			; Disable TX interrupt
			jmp		UART_DONE
			nop






;*******************************************************************************
; Data - Tables of values used by state machine.
;*******************************************************************************
				.data					; Uncomment .data to store in RAM, otherwise comment to keep in ROM

MyTable:
 				.word	115			;
 				.word	110			;
 				.word	100			;
 				.word	95			;


				.text

;-------------------------------------------------------------------------------
; Subroutine: InitClock
; Initializes frequency locked loop to generate 16MHz MCLK.
; No general purpose registers are used in this subroutine.
;-------------------------------------------------------------------------------
; Initializes FLL DCO clock and waits for signal to lock
InitClock	bis.w	#SCG0, SR				; Disable FLL
			mov.w	#SELREF__REFOCLK, &CSCTL3	; FLL reference CLK = REFOCLK
			clr		&CSCTL0					; Clear tap and mod settings for FFL fresh start
			bis.w	#DCORSEL_3, &CSCTL1		; 16 MHz Range
			mov.w	#FLLD__1+243, &CSCTL2	; FLLD = 1 (using 32768 Hz FLLREFCLK) and FLLN 'divider' 486
			nop								; f_DCOCLKDIV = (FLLN + 1) * (f_FLLREFCLK / FLLD)
			nop								; 16 MHz = (FLLN + 1) * (32768 / 1)
			nop
			bic.w	#SCG0, SR				; Enable FLL
FLL_wait	bit.w	#FLLUNLOCK0+FLLUNLOCK1, &CSCTL7	; Wait until FLL locks (both bits must be cleared)
			jnz		FLL_wait
			bic.w	#DCOFFG, &CSCTL7		; Clear fault flag
			ret

;-------------------------------------------------------------------------------
; Subroutine: StartTX
; This subroutine starts a serial transmission by loading the first byte of a message
; and enabling the TX Complete interrupt.
; User must load start address of message into the TXptr RAM address.
; The TX Complete ISR will handle all subsequent bytes in the message.
; The TX Complete interrupt will be dissabled when the null byte of the message is detected.
; R15 is used by the ISR but is pushed to the stack and popped when completed.
;-------------------------------------------------------------------------------
StartTX		push	R15
			mov.w	TXptr, R15					; Load TX pointer from memory
			mov.b	@R15+, &UCA0TXBUF			; Load char into buffer (triggers transmission)
			mov.w	R15, TXptr					; Return updated pointer to RAM
			pop		R15
			bis.w	#UCTXCPTIE, &UCA0IE			; Enable TX Complete interrupt
			ret									; TX ISR will handle remaining chars

;-------------------------------------------------------------------------------
; ROM Data
;-------------------------------------------------------------------------------
HelloMSG	.byte	"Hello!", CR, LF, 0x00

aok			.byte	"AOK", CR, LF, 0x00

INVALIDR	.byte	"INVALID RANGE", CR, LF, 0x00

INVALIDI	.byte	"INVALID INDEX", CR, LF, 0x00

NO			.byte	"NO", CR, LF, 0x00


;*******************************************************************************
; Stack Pointer definition
;*******************************************************************************
            	.global __STACK_END
            	.sect   .stack


;*******************************************************************************
; Interrupt Vectors
;*******************************************************************************
				.sect   ".reset"                ; MSP430 RESET Vector
				.short  RESET                   ;



				.sect   ".int41"				; MSP430 button Vector
				.short  BTN_ISR					; Goto this label when interrupt occurs

				.sect	USCI_A0_VECTOR				; USART
            	.short	UART_ISR
				.end
