;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------

;*******************************************************************************
; Equate Directives
;*******************************************************************************

maxValidStates	.equ	8
minValidStates	.equ	8
maxValidtime	.equ	3



BTTNMASK		.equ 	BIT3			; P2.3 for button input
BTTNMASK2		.equ 	BIT7			; P2.7 for button input

maxTAcount      .equ    2500		; Max count for the timer to fire a timer tick (period)
POS1			.equ	115

Speed1			.equ	2500
Speed2			.equ	2000
Speed3			.equ	1500


B2				.equ	BIT4
A2				.equ	BIT3
B1				.equ	BIT2
A1				.equ	BIT1
AllStates		.equ	B2+A2+B1+A1



;*******************************************************************************
; Relate names to general-purpose registers
;  Note: Although these are 16-bit registers, this application only uses
;  byte-sized data
;*******************************************************************************
State			.equ	R4		; stop light state variable (only byte needed)
HState			.equ	R5		;
Direction		.equ	R6		;
Statetmr		.equ	R8


;*******************************************************************************
; Enter Program
;*******************************************************************************
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.
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


SetupState		clr		HState					;
				bis.b   #AllStates, &P1DIR      ;
				bic.b	#AllStates, &P1OUT		;



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
SetupC0			clr		&TA0CCTL0						; Set CCR0's control register (CTL) to default
				mov.w   #CCIE, &TA0CCTL0
				mov.w   #maxTAcount, &TA0CCR0  			; Set CCR0's value to HALF_PERIOD (controls period of timer)
SetupC1   		mov.w   #OUTMOD_6, &TA0CCTL1   			; Set CCR1's control register to toggle pin mode
         	    mov.w   #POS1, &TA0CCR1  				; Set CCR1's value to pos1
SetupC2  	    mov.w   #OUTMOD_6, &TA0CCTL2   			; Set CCR2's control register to toggle pin mode
         	    mov.w   #POS1, &TA0CCR2  				; Set CCR2's value to Pos1
SetupTA  	    mov.w   #TASSEL_2+MC_3, &TA0CTL 		; Configure the timer tou use the SMCLK and count in updown mode
                          							; Setting MC to anything but zero will START the timer!

; Clear general registers (clr is the same as clr.w which clears all 16 bits!)
SetupCount		clr		State					; clear State counter
				clr		HState
				clr		Statetmr
				clr		Direction

SetupStates		;mov.b	Timer_Table, StateTmr 	; load default state timer value (assume index = 0)
				mov.b	Half_Step_Table(State), HState	; load default step value start state

; Enable interrupts and return from subroutine
SetupGIE		nop								; NOP needed before and after GIE
				bis.w   #GIE, SR                ;
				nop
				ret								; Return from the subroutine





;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
loop
				jmp		loop
				nop

;*******************************************************************************
;	Button Interrupt Service Routine (ISR) - executes every time buttons are pressed
;*******************************************************************************



TA0_ISR
				cmp.b	#1, Direction
				jeq 	change_states_down

												; Return from interupt

change_states_up
				inc		State					;
				cmp.b	#maxValidStates, State	; make sure the state is still in bounds
				jl		skip_state_reset_up		; jump to skip_state_reset if state< #maxValidStates
				clr.w	State

skip_state_reset_up
				mov.b	Half_Step_Table(State), HState
				mov.b	HState, &P1OUT
				reti

change_states_down
				cmp		#0, State
				jeq		Reset
				dec		State					;
				cmp.b	#minValidStates, State	; make sure the state is still in bounds
				jl		skip_state_reset_down		; jump to skip_state_reset if state< #maxValidStates
				reti
Reset
				mov		#7, State

skip_state_reset_down
				mov.b	Half_Step_Table(State), HState
				mov.b	HState, &P1OUT
				reti

BTN_ISR

				bit.b		#BTTNMASK, &P2IFG
				jnz			DoButton1
				bit.b	    #BTTNMASK2, &P2IFG
				jnz			DoButton2

DoButton1
				bic.b	#BTTNMASK, &P2IFG
				cmp 	#0, Direction
				jeq		Back
				mov		#0, Direction
				reti

Back
				mov		#1, Direction
				reti


DoButton2
				bic.b	#BTTNMASK2, &P2IFG
				inc		Statetmr					;
				cmp.b	#maxValidtime, Statetmr		; make sure the state is still in bounds
				jl		skip_time_reset				; jump to skip_state_reset if state< #maxValidStates
				clr.w	Statetmr


skip_time_reset
				;mov.w	Time_Table(Statetmr), &TA0CCR0
				cmp.b	#0, Statetmr
				jeq		Speeds1
				cmp.b	#1, Statetmr
				jeq		Speeds2
				cmp.b	#2, Statetmr
				jeq		Speeds3
				reti

Speeds1
				mov.w	#Speed1, &TA0CCR0
				reti
Speeds2
				mov.w	#Speed2, &TA0CCR0
				reti
Speeds3
				mov.w	#Speed3, &TA0CCR0
				reti

;*******************************************************************************
; Data - Tables of values used by state machine.
;*******************************************************************************
				;.data					; Uncomment .data to store in RAM, otherwise comment to keep in ROM

;Time_Table:
;				.word	 2500			;
;				.word	 2000
;				.word	 1500

Half_Step_Table:
 				.byte	B2+A1			;
 				.byte	A1				;
 				.byte	B1+A1			;
 				.byte	B1				;
 				.byte	B1+A2			;
 				.byte	A2				;
 				.byte	B2+A2			;
 				.byte	B2				;

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
           		.global __STACK_END
           		.sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            	.sect   ".reset"                ; MSP430 RESET Vector
            	.short  RESET
            
            	.sect   ".int56"				; MSP430 TimerA0 CCR0 Vector
				.short  TA0_ISR					; Goto this label when interrupt occurs

            	.sect   ".int41"				; MSP430 button Vector
				.short  BTN_ISR					; Goto this label when interrupt occurs
				.end
