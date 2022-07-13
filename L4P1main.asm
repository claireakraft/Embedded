;*******************************************************************************
;
;

				.cdecls C,LIST,  "msp430FR2433.h"

				.def    RESET                   ; Export program entry-point to
												; make it known to linker.

				.global _initialize            ; export initialize as a global symbol (subroutine)

;*******************************************************************************
; Equate Directives
;*******************************************************************************

OUTPIN			.equ	BIT1
OUTPIN2			.equ	BIT2				; set the outpin to pin 1.0.

BTTNMASK		.equ 	BIT3			; P2.3 for button input
BTTNMASK2		.equ 	BIT7			; P2.7 for button input

maxTAcount      .equ    125		; Max count for the timer to fire a timer tick (period)

POS1			.equ	115
POS2			.equ	110			; lowering this increases the duty
POS3			.equ	100
POS4			.equ	95

POS5			.equ	115
POS6			.equ	110			; lowering this increases the duty
POS7			.equ	105
POS8			.equ	100


;*******************************************************************************
; Relate names to general-purpose registers
;  Note: Although these are 16-bit registers, this application only uses
;  byte-sized data
;*******************************************************************************
State			.equ	R4		; stop light state variable (only byte needed)
State2			.equ	R5		; stop light state variable (only byte needed)
ButtnFlag		.equ	R8		; is the button pressed? (only byte needed)



;*******************************************************************************
; Enter Program
;*******************************************************************************
                .text							; Executable code goes below

; Code entry point
RESET
				mov.w   #__STACK_END, SP        ; Initialize stackpointer
				call	#_initialize			; Execute subroutine to label "_initialize"
				jmp		loop


;*******************************************************************************
; Initialization Subroutine
;*******************************************************************************
_initialize
				mov.w   #WDTPW+WDTHOLD, &WDTCTL ; Stop WDT
				bic.w	#LOCKLPM5, &PM5CTL0		; CLEAR LOCK-LowPowerMode5 bit which unlocks GPIO pins


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
SetupC1     mov.w   #OUTMOD_6, &TA0CCTL1   			; Set CCR1's control register to toggle pin mode
            mov.w   #POS1, &TA0CCR1  			; Set CCR1's value to TOG_LED_VAL
SetupC2     mov.w   #OUTMOD_6, &TA0CCTL2   			; Set CCR1's control register to toggle pin mode
            mov.w   #POS5, &TA0CCR2  			; Set CCR1's value to TOG_LED_VAL
SetupTA     mov.w   #TASSEL_1+MC_3, &TA0CTL 	; Configure the timer tou use the SMCLK and count in updown mode
                          							; Setting MC to anything but zero will START the timer!

; Clear general registers (clr is the same as clr.w which clears all 16 bits!)
SetupCount		clr		State					; clear State counter
				clr		State2
				clr 	ButtnFlag				; clear Button pressed flag


; Enable interrupts and return from subroutine
SetupGIE		nop								; NOP needed before and after GIE
				bis.w   #GIE, SR                ;
				nop
				ret								; Return from the subroutine


;*******************************************************************************
; Main loop - the main loop performs the background task. The background task
;             manages the state machine and polls the button.
;*******************************************************************************
; Main Loop (branches to:)
loop


				jmp		loop
				nop






;*******************************************************************************
;	Button Interrupt Service Routine (ISR) - executes every time buttons are pressed
;*******************************************************************************

BTN_ISR

				bit.b	    #BTTNMASK, &P2IFG
				jnz			DoButton1
				bit.b	    #BTTNMASK2, &P2IFG
				jnz			DoButton2


DoButton1

				bic.b	#BTTNMASK, &P2IFG
				cmp.b	#0, State
				jeq		Turn1
				cmp.b	#1, State
				jeq		Turn2
				cmp.b	#2, State
				jeq		Turn3
				cmp.b	#3, State
				jeq		Turn4


Turn1
				mov.w	#POS1, &TA0CCR1			; set TA0CCR1 to off
				inc		State
				reti

Turn2
				mov.w	#POS2, &TA0CCR1	; set TA0CCR1 to slow
				inc		State
				reti

Turn3
				mov.w	#POS3, &TA0CCR1	; set TA0CCR1 to med
				inc		State
				reti

Turn4
				mov.w	#POS4, &TA0CCR1	; set TA0CCR1 to fast
				mov		#0, State
				reti


DoButton2
				bic.b	#BTTNMASK2, &P2IFG
				cmp.b	#0, State2
				jeq		Turn5
				cmp.b	#1, State2
				jeq		Turn6
				cmp.b	#2, State2
				jeq		Turn7
				cmp.b	#3, State2
				jeq		Turn8


Turn5
				mov.w	#POS5, &TA0CCR2			; set TA0CCR1 to off
				inc		State2
				reti

Turn6
				mov.w	#POS6, &TA0CCR2	; set TA0CCR1 to slow
				inc		State2
				reti

Turn7
				mov.w	#POS7, &TA0CCR2	; set TA0CCR1 to med
				inc		State2
				reti

Turn8
				mov.w	#POS8, &TA0CCR2	; set TA0CCR1 to fast
				mov		#0, State2
				reti

;*******************************************************************************
; Data - Tables of values used by state machine.
;*******************************************************************************
				;.data					; Uncomment .data to store in RAM, otherwise comment to keep in ROM

Half_Step_Table:
 				.byte	115			;
 				.byte	110			;
 				.byte	100			;
 				.byte	95				;
 				.byte				;
 				.byte	A2				;
 				.byte	B2+A2			;
 				.byte	B2				;


POS1			.equ	115
POS2			.equ	110			; lowering this increases the duty
POS3			.equ	100
POS4			.equ	95

POS5			.equ	115
POS6			.equ	110			; lowering this increases the duty
POS7			.equ	105
POS8			.equ	100

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
				.end

            
