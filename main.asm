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

OUTPIN			.equ	BIT1			; set the outpin to pin 1.0.

BTTNMASK		.equ 	BIT3			; P2.3 for button input

maxTAcount      .equ    300		; Max count for the timer to fire a timer tick (period)

OFF				.equ	250
DutyCycle1		.equ	150			; lowering this increases the duty
DutyCycle2		.equ	100
DutyCycle3		.equ	50




;*******************************************************************************
; Relate names to general-purpose registers
;  Note: Although these are 16-bit registers, this application only uses
;  byte-sized data
;*******************************************************************************
State			.equ	R4		; stop light state variable (only byte needed)
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


; Set up Port 2 (Button)
SetupBtn		bic.b	#BTTNMASK, &P2DIR 		;	P2.3 as input
				bis.b	#BTTNMASK, &P2REN		;	P2.3 pullup
				bis.b	#BTTNMASK, &P2OUT		;	P2.3 pullup
				bis.b	#BTTNMASK, &P2IES		;	P2.3 hi/low edge
				bic.b	#BTTNMASK, &P2IFG		;	P2.3 IFG Cleared
				bis.b	#BTTNMASK, &P2IE		;	P2.3 interupt enabled


; Setup Timer
SetupC0		clr		&TA0CCTL0						; Set CCR0's control register (CTL) to default
			mov.w   #maxTAcount, &TA0CCR0  			; Set CCR0's value to HALF_PERIOD (controls period of timer)
SetupC1     mov.w   #OUTMOD_6, &TA0CCTL1   			; Set CCR1's control register to toggle pin mode
            mov.w   #DutyCycle1, &TA0CCR1  			; Set CCR1's value to TOG_LED_VAL
SetupTA     mov.w   #TASSEL_1+MC_3, &TA0CTL 	; Configure the timer tou use the SMCLK and count in updown mode
                          							; Setting MC to anything but zero will START the timer!

; Clear general registers (clr is the same as clr.w which clears all 16 bits!)
SetupCount		clr		State					; clear State counter

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
				cmp.b	#0, State
				jeq		off
				cmp.b	#1, State
				jeq		do_slow
				cmp.b	#2, State
				jeq		do_med
				cmp.b	#3, State
				jeq		do_fast

				bic.b	#OUTPIN, &P1OUT

				jmp		loop
				nop								; jump to endmain


off
				mov.w	#TASSEL_1+MC_0, &TA0CTL
				mov.w	#OFF, &TA0CCR1			; set TA0CCR1 to off
				mov.w	#TASSEL_1+MC_3, &TA0CTL
				;bic.b	#OUTPIN, &P1OUT

				jmp 	loop

do_slow
				mov.w	#TASSEL_1+MC_0, &TA0CTL
				mov.w	#DutyCycle1, &TA0CCR1	; set TA0CCR1 to slow
				mov.w	#TASSEL_1+MC_3, &TA0CTL
				jmp 	loop

do_med
				mov.w	#TASSEL_1+MC_0, &TA0CTL
				mov.w	#DutyCycle2, &TA0CCR1	; set TA0CCR1 to med
				mov.w	#TASSEL_1+MC_3, &TA0CTL
				jmp 	loop

do_fast
				mov.w	#TASSEL_1+MC_0, &TA0CTL
				mov.w	#DutyCycle3, &TA0CCR1	; set TA0CCR1 to fast
				mov.w	#TASSEL_1+MC_3, &TA0CTL
				jmp 	loop



;*******************************************************************************
;	Timer A0 Interrupt Service Routine (ISR) - executes every time Timer A0
;	counts up to the value in its CCR0 register.
;*******************************************************************************

BTN_ISR
				bic.b	#BTTNMASK, &P2IFG
				cmp.b		#3, State
				jeq			Turnoff
				inc			State
				;mov.w 		#1, State
				reti

Turnoff			mov.w		#0,State
				reti



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
