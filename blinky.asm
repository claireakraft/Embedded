;-------------------------------------------------------------------------------
; Lab 1 Blinky ASM
; Description: Toggle P1.0 (LED) by xor'ing P1.0 inside of a software loop.
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430fr2433.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

;-------------------------------------------------------------------------------
; Constants and Directives (preprocessor)
;
; Here is where you can define any constants for your algos, FOR loops, and bit
; masks for pin assignments or groups.
;-------------------------------------------------------------------------------
LED_PIN		.equ	BIT0					; Pin 0 on Port 1 (00000001b)
											; "BIT0" is defined in MSP430FR2433.h
MAX_COUNT 	.equ	5 					; Set a maximum loop count value

;-------------------------------------------------------------------------------
; Entry and Initialization
;
; This program defines RESET as the entry label (because it is linked to the
; .reset interrupt vector). This is where your code will start executing. This
; section is ideal for setting up your peripherals (GPIO, timers, ADC,
; initializing registers).
;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer
UnlockGPIO  bic.w	#LOCKLPM5, &PM5CTL0		; CLEAR LOCK-LowPowerMode5 bit which unlocks GPIO pins

InitP1 		bis.b   #LED_PIN, &P1DIR   		; SET only P1.0 as output
            bis.b   #LED_PIN, &P1OUT      	; SET only P1.0 = 1 (LED ON)

;-------------------------------------------------------------------------------
; Main loop here
;-------------------------------------------------------------------------------
ToggleLED   xor.b   #LED_PIN, &P1OUT      	; Toggle LED by exclusive OR on the LED bit
DelayLoop   mov.w   #MAX_COUNT, R4          ; load a value into general-purpose register
Decrement   dec     R4                      ; decrement the value in temp storage
            jnz     Decrement               ; Jump to "Decrement" label IF the previous
            								; operation resulted in non-zero result.
            jmp     ToggleLED               ; If the previous jump operation did not execute,
            								; jump unconditionally to "ToggleLED" label.
			nop								; "nop" is "no operation" and the CPU does nothing.
											; Granted, we should never get to this line anyway!

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END				; This just tells the MCU where to start
            .sect   .stack					; addressing RAM (we don't want to overwrite
            								; RAM addresses that configure the peripherals!)
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            
