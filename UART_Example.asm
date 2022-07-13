;-------------------------------------------------------------------------------
; Serial Communication Example
;	UART 0
;
; By Devon Lantagne 2022
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430fr2433.h"       ; Include device header file
            
; RAM variables defined as global for debugging
			.global	TXptr
			.global RX_ind
			.global	RX_buf_st
			.global Dum1, Dum2, Dum3, Dum4

;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

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
; 16000000	19200		1		52		1		0x49
U0_UCOS16	.equ	1
U0_UCBR		.equ	52
U0_UCBRF	.equ	0x10	; either 0x00 or 0x10
U0_UCBRS	.equ	0x49

; RX Data Buffer Variables
RX_BUF_SIZE	.equ	10
TXptr 		.word	0						; Pointer to next address of data to send.
											; TX continues until null byte is detected.
RX_ind		.byte	0						; Byte Index of RX_BUF characters (buffer must be < 255 bytes in size)
			.bss	RX_buf_st, RX_BUF_SIZE	; Reserve an array in RAM (BSS will ALWAYS be saved in RAM)

; Special Text Characters
CR			.equ	0x0A		; Carriage Return
LF			.equ	0x0D		; Line Feed (New Line)


;-------------------------------------------------------------------------------
; Entry
;-------------------------------------------------------------------------------
			.text							; The following are saved to ROM (executable)

RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer
			bic.w	#LOCKLPM5, &PM5CTL0		; Unlock GPIO (although not actually needed for UART)


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


; Clock Speed set to 16MHz using FLL
SetupCLK	call	#InitClock

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

; Enable interrupts
			nop
			bis.w	#GIE, SR
			nop

; Send first message
			mov.w	#HelloMSG, TXptr		; Load starting address of the message to TXptr
			call	#StartTX				; Call subroutine to send first character


;-------------------------------------------------------------------------------
; Main Loop
;-------------------------------------------------------------------------------
MainLoop	jmp		MainLoop


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
RX_buf_full	mov.b	RX_ind, R15						; We already pused R15 to stack, now load data from RAM to R15
			mov.b	&UCA0RXBUF, RX_buf_st(R15)		; move data from rx buffer and save it in data buffer
			inc		R15								; Increment R15 to the next buffer address
			cmp.b	#RX_BUF_SIZE, R15				; Check if we exceeded our buffer (this prevents a Buffer Overflow cyber attack!)
			jl		skip_RX_ind_reset
			clr		R15
skip_RX_ind_reset
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


;-------------------------------------------------------------------------------
; Subroutine: InitClock
; Initializes frequency locked loop to generate 16MHz MCLK.
; No general purpose registers are used in this subroutine.
;-------------------------------------------------------------------------------
; Initializes FLL DCO clock and waits for signal to lock
InitClock	bis.w	#SCG0, SR				; Disable FLL
			mov.w	#SELREF__REFOCLK, &CSCTL3	; FLL reference CLK = REFOCLK
			clr		&CSCTL0					; Clear tap and mod settings for FFL fresh start
			bis.w	#DCORSEL_5, &CSCTL1		; 16 MHz Range
			mov.w	#FLLD__1+486, &CSCTL2	; FLLD = 1 (using 32768 Hz FLLREFCLK) and FLLN 'divider' 486
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
            
            .sect	USCI_A0_VECTOR				; USART
            .short	UART_ISR







