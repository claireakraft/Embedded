;*******************************************************************************
; stop_light.asm (Commented Version)
;
; This code implements:
;  A stoplight state machine coordinating two stoplights at an intersection.
;   There is also a pushbutton input that signals an error event to force the
;   state machine into an alternate (blinking red) condition. The state machine
;   receives TimerTicks from the on-chip Timer A which is serviced by an interrupt
;	service routine. The state machine also receives "button press" events
;	initiating an exception condition that times out after a set amount of time.
;  The built-in buttons on the Launchpad for the FR2433 grounds the input pin.
;   Input pins should be configured to pull-up (buttons are active low)
;
;   10/04/2001 RA Scheidt - Initial logic for 68HC912B32 EVB, E = 8 MHz
;	02/07/2011 EA Bock - port code to MSP430
;   02/09/2011 DJ Herzfeld - Interrupt modifications
;   01/12/2012 RA Scheidt - Comment clarifications; Code streamlining
;	02/03/2022 DD Lantagne - Supports FR2433; Generalized pin masks; Comments
;

				.cdecls C,LIST,  "msp430FR2433.h"

				.def    RESET                   ; Export program entry-point to
												; make it known to linker.

				.global _initialize            ; export initialize as a global symbol (subroutine)

;*******************************************************************************
; Equate Directives
;*******************************************************************************
maxValidStates	.equ	6				; When in Normal Mode: Max number of light patterns (States)
maxErrStates	.equ	2				; When in Error Mode: Max number of error light patterns

ErrorDuration	.equ	230				; fifteen seconds of blinky upon error

; Pin Masks - Port 1
DEBUG			.equ	BIT6				; User must define this!! Use an unused P1 pin.
LeftR			.equ	BIT5			; P1.5
LeftY			.equ	BIT4
LeftG			.equ	BIT3
RightR			.equ	BIT2
RightY			.equ	BIT1
RightG			.equ	BIT0			; P1.0
AllLEDs			.equ	LeftR+LeftY+LeftG+RightR+RightY+RightG+DEBUG
; Pin Masks - Port 2
BTTNMASK		.equ 	BIT3			; P2.3 for button input

maxTAcount      .equ    25000			; Max count for the timer to fire a timer tick


;*******************************************************************************
; Relate names to general-purpose registers
;  Note: Although these are 16-bit registers, this application only uses
;  byte-sized data
;*******************************************************************************
State			.equ	R4		; stop light state variable (only byte needed)
Tick			.equ	R5		; tick event flag (only byte needed)
StateTmr		.equ	R6		; time to spend in a given state (only byte needed)
LedStates		.equ	R7		; placeholder for current LED states (only byte needed)
ButtnFlag		.equ	R8		; is the button pressed? (only byte needed)
ErrTimer		.equ	R9		; are we in an error condition. (only byte needed)


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

; Set up Port 1 (LEDs)
SetupLEDS		clr		LedStates				;
				bis.b   #AllLEDs, &P1DIR      	;
				bic.b	#AllLEDs, &P1OUT		;

;SetupDEBUG										;
;				bis.b   #DEBUG, &P1DIR      	;
;				bic.b	#DEBUG, &P1OUT			;

; Set up Port 2 (Button)
SetupBtn		bic.b	#BTTNMASK, &P2DIR 		;
				bis.b	#BTTNMASK, &P2REN		;
				bis.b	#BTTNMASK, &P2OUT		;

; Set up State Machine Timer (TimerA0) to periodically trigger interrupt
SetupC0    		mov.w   #CCIE, &TA0CCTL0        ; Config CCR0 Control Register:
												;
				mov.w   #maxTAcount, &TA0CCR0   ; Load value into CCR0 Register
SetupTA    		mov.w   #TASSEL_2+MC_1, &TA0CTL ; Config Timer Control Register:
												;
												;

; Clear general registers (clr is the same as clr.w which clears all 16 bits!)
SetupCount		clr		State					; clear State counter
				clr 	Tick					; clear Tick counter
				clr		StateTmr				; clear State timer
				clr 	ButtnFlag				; clear Button pressed flag
				clr 	ErrTimer				; start in a non-error condition

; Initialize register values
SetupStates		mov.b	Timer_Table, StateTmr 	; load default state timer value (assume index = 0)
				mov.b	Led_Table, LedStates	; load default LED value start state

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
										;
				mov.b	LedStates, &P1OUT		; move R7 to P1 out
				cmp.b	#0,Tick					; compare  to R5 (tick event flag)
				jne		do_fsm					; jump to do_fsm if not equal
				nop
				cmp.b	#1, ButtnFlag
				jeq		endmain						;
				bit.b	#BTTNMASK, &P2IN 		;
				jz		do_button				; jump to do_bottom if Z=1
				jmp		endmain					; jump to endmain



; Do Button Branch (branches to:      )
do_button
				mov.b	#1, ButtnFlag
							 						;
				mov.b	#ErrorDuration, ErrTimer ;
				mov.b	#1, StateTmr			 ;
				jmp		endtick	  				; jump to endtick

; Do Finite State Machine Branch (branches to:     )
do_fsm											;
				bis.b	#DEBUG, &P1OUT			;
												;
				dec		Tick					;
				cmp.b	#1, ButtnFlag			;
				jeq		error_operation			; jump to error_operation if #1 = ButtnFlag
				jmp		normal_operation		; jump to normal_operation

; Normal Operation Branch (branches to:      )
normal_operation
				dec		StateTmr				;
				jz		next_state				; jump to next state if Z = 1
				jmp		endtick					; jump to endtick
next_state
				inc		State					;
				cmp.b	#maxValidStates, State	;
				jl		skip_state_reset		; jump to skip_state_reset if state< #maxValidStates
				clr.w	State					;
skip_state_reset
				mov.b	Timer_Table(State), StateTmr	;
				mov.b	Led_Table(State), LedStates		;
end_next_state
				jmp		endtick					; jump to end trick

; Error Operation Branch (branches to:      )
error_operation
				dec		ErrTimer				;
				jz		exit_err_state			; jump to exit_err_state if errTimer= 0
				dec		StateTmr				;
				jz		next_err_state			; jump to next_err_state if StateTimer= 0
				jmp		endtick					; jump to end trick
next_err_state
				inc		State					;
				cmp.b	#maxErrStates, State	;
				jl		skip_err_state_reset	; jump to skip_state_reset if state< #maxValidStates
				clr.w	State
skip_err_state_reset
				mov.b	Err_Timer_Table(State), StateTmr	;
				mov.b	Err_Led_Table(State), LedStates		;
end_next_err_state
				jmp		endtick					; jump end trick
exit_err_state
				clr		ButtnFlag				;
				mov.b	Timer_Table, StateTmr	;
				mov.b	Led_Table, LedStates	;
				clr		State					;
				jmp		endtick					;

; Exit branch code, resume main loop
endtick
				bic.b	#DEBUG, &P1OUT			;
endmain

				jmp		loop					; go back to the top of the background task

				nop



;*******************************************************************************
;	Timer A0 Interrupt Service Routine (ISR) - executes every time Timer A0
;	counts up to the value in its CCR0 register.
;*******************************************************************************
TA0_ISR
				inc		Tick
				reti							; Return from interupt							; Return from interupt

;*******************************************************************************
; Data - Tables of values used by state machine.
;*******************************************************************************
				;.data					; Uncomment .data to store in RAM, otherwise comment to keep in ROM

; Timer Table - number of ticks for each light pattern
Timer_Table:
sRGtime			.byte	153				; about 10 seconds
sRYtime			.byte	 31				; about 2 seconds
sRR1time		.byte	 15				; about 1 second
sGRtime			.byte	153
sYRtime			.byte	 31
sRR2time		.byte	 15

; Error Table - number of ticks for each error pattern
Err_Timer_Table:
 				.byte	7				; about 1/2 second
 				.byte	7				; about 1/2 second
; LED Table - each LED pattern
Led_Table:
 				.byte	LeftR+RightG	; 00100001b
 				.byte	LeftR+RightY	; 00100010b
 				.byte	LeftR+RightR	; 00100100b
 				.byte	LeftG+RightR	; 00001100b
 				.byte	LeftY+RightR	; 00010100b
 				.byte	LeftR+RightR	; 00100100b
; Error LED Table - each error LED pattern
Err_Led_Table:
				.byte	LeftR+RightR	; Left R & Right R
 				.byte	00000000b		; Left Off & Right Off


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

				.sect   ".int56"				; MSP430 TimerA0 CCR0 Vector
				.short  TA0_ISR					; Goto this label when interrupt occurs
				.end
