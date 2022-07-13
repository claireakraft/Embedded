;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;   Description: Toggle P1.1 using hardware TA0.1 output.
;	TimerA0 is configured in UpDown mode so the TAR (the counter that the timer
;   increments) will start at zero, count up to the value in CCR0, then back
;	down to zero and it will repeat. Meanwhile, a Capture/Compare Register (CCR)
;	CCR1 has been configured to trigger a hardware interrupt (by toggling a
;	digital pin) when the TAR hits the value in CCR1.
;   No CPU or software resources required once initialized.
;
;	LED:			  ON    OFF   ON	...
;	TAR=CCR0=CCR1_____||	||    ||
;	  			  	  /\    /\	  /\
;				 	 /  \  /  \  /  \
;	TAR=0___________/    \/    \/    \
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430FR2433.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

SLEEP_CPU	.equ	0						; DIRECTIVE: 1 = compiles with code to put the CPU to sleep
											; You can view registers when CPU asleep but Timer will keep
											; running. Set to 0 to keep CPU awake and execute an infinite
											; loop. The timer will only increment when stepping through code.

LED_PIN 	.equ	BIT1 					; On Port 1
HALF_PERIOD	.equ	65000					; Number of timer counts to toggle LED.
											; Full period of LED signal is twice this value.
TOG_LED_VAL	.equ	65000					; Value of TAR that will toggle the LED state.
											; Set to HALF_PERIOD for 50% DC

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer
			bic.w	#LOCKLPM5, &PM5CTL0		; CLEAR LOCK-LowPowerMode5 bit which unlocks GPIO pins

; Setup digital pin
SetupP1     bis.b   #LED_PIN, &P1DIR        ; LED pin set to output
			bic.b   #LED_PIN, &P1SEL0		; FR2433 Data Sheet page 55 Table 6-17: PSEL = 10
            bis.b   #LED_PIN, &P1SEL1       ; LED pin set to secondary function (let the timer control this pin)

; Setup Timer
SetupC0		clr		&TA0CCTL0				; Set CCR0's control register (CTL) to default
			mov.w   #HALF_PERIOD, &TA0CCR0  ; Set CCR0's value to HALF_PERIOD (controls period of timer)
SetupC1     mov.w   #OUTMOD_4, &TA0CCTL1    ; Set CCR1's control register to toggle pin mode
            mov.w   #TOG_LED_VAL, &TA0CCR1  ; Set CCR1's value to TOG_LED_VAL
SetupTA     mov.w   #TASSEL_1+MC_3+ID_1, &TA0CTL ; Configure the timer tou use the SMCLK and count in updown mode
                          					; Setting MC to anything but zero will START the timer!

; Should we put the CPU to sleep or use infinite loop?
			.if 	SLEEP_CPU				; IF SLEEP_CPU == 1
		    bis.w   #CPUOFF, SR             ; CPU off (but peripherals still have power)
            nop                             ; Required only for debugger
            								; Since CPU is asleep, you never increment PC!

			.else							; IF SLEEP_CPU == 0
MainLoop	nop								; Execute this infinite loop
			jmp		MainLoop
			nop
			.endif
                                            

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
            
