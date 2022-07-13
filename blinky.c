// Lab 1 Blinky C
// Description: Toggle P1.0 (LED) by xor'ing P1.0 inside of a software loop.

#include <msp430fr2433.h>

// Directives
#define LED_PIN     BIT0
#define MAX_COUNT   50000

// Entry Point
void main(void)
{
    // Initialization - Define variables and configure peripherals

    volatile unsigned int i;
/* i is the loop counter. We declare it is volatile to trick the compiler
 * into not optimizing the empty loop away. A volatile variable is one that
 * can change due to hardware action, so compiler optimizations should leave
 * it alone. If you every debug your code and you are missing a variable, the
 * optimizer probably removed it.
 */

	WDTCTL = WDTPW | WDTHOLD;
/* Stop hardware watchdog timer. Watchdog timers exist to restart your program
 * if their counter hits zero. Your program would have to constantly reset the
 * watchdog to prevent this. This is useful if your program gets stuck in a
 * loop and can't reset the watchdog.
 */
	
	PM5CTL0 &= ~LOCKLPM5;
/* Unlock the GPIO pins.
 * &= in conjunction with inverting (~) the bit mask will clear the bit.
 * (PM5CTL0 = PM5CTL0 & ~LOCKLPM5)
 */

	// Unlock the GPIO pins after power-up.

	// Define digital pin as output and turn it on
	P1DIR |= LED_PIN;           // Set GPIO P1.0 to "output" direction
	                            // |= is bitwise OR which is the same as a BIS opcode
	                            // (P1DIR = P1DIR | LED_PIN)
	P1OUT |= LED_PIN;           // Tells P1.0 to output high voltage (LED ON)

	// Enter infinite loop
	for (;;){
	    P1OUT ^= 0x01;          // Toggle P1.0 using exclusive-OR. To "toggle" means to
	                            // change the state from "on" to "off" or vice versa.
	    i = MAX_COUNT;          // Load the Loop Counter's value
	    // Enter loop
	    while (i != 0){
	        i--;                // Decrement i once
	    }
	}
}




