;
; TrafficLights.asm
;
; Created: 12/5/2020 11:48:44 PM
; Author : Gonzalo Menacho
; Purpose: This program simulates a traffic signal with
; a set of auto-sequenced timings of LEDs, pressing button
; speeds-up green to red cycle so person can cross sooner
;

;define labels
.def red_delay = r18
.def green_delay = r19
.def p_delay = r20
.def lc_100ms = r21
.def lc_250 = r22

;define delay
.equ auto_g = 5
.equ auto_r = 5
.equ isr_d = 60

;config interrupt vector table
.org 0x0000                             ;reset
          rjmp      main

.org INT0addr
          rjmp      ext0_isr            ;jump to ext0_isr

.org INT_VECTORS_SIZE                   ;ends of vector table

; Start of main program
main:
          ;initialize stack pointer
          ldi       r16,HIGH(RAMEND)
          out       SPH,r16
          ldi       r16,LOW(RAMEND)
          out       SPL,r16

          ;initialize port registers
          sbi       DDRB,DDB2           ;set directions for output
          sbi       DDRB,DDB3           ;for pin 2, 3 and 4
          sbi       DDRB,DDB4           ;in port-b
          
          cbi       DDRD,DDD2           ;set direction for port-d pin-2 for input
          sbi       PORTD,PD2           ;set port-d pin-2 for pull up

          ;config intterupt for button press
          ldi       r17,(1<<INT0)       ;enables intterupt 0
          out       EIMSK,r17           

          ;configure intterupt sense control bits
          ldi       r17,(1<<ISC01)      ;falling edge
          sts       EICRA,r17           ;intterupt sense control bits

          ;global intterupt enable
          sei

main_proc:         
          call      disp_led            ;call to displaying leds

end_main: rjmp      main_proc           ;endless loop

disp_led:
          sbi       PORTB,PB2           ;set PB2 to high

          ldi       green_delay,auto_g  ;initialize control variable for green delay
delay_green:                            ;loop to get the 600,000 micro sec * 5 = 3s
          call      timer1_600ms        ;call timer1

          dec       green_delay                 
          brne      delay_green         

          cbi       PORTB,PB2           ;set PB2 to low

          sbi       PORTB,PB3           ;set PB3 to high

          call      timer1_600ms        ;call timer1
                    
          cbi       PORTB,PB3           ;set PB3 to low
          sbi       PORTB,PB4           ;set PB4 to high

          ldi       red_delay,auto_r    ;initialize control variable for red delay
delay_red:                              ;loop to get the 600,000 micro sec * 5 = 3s
          call      timer1_600ms        ;call timer1

          dec       red_delay                 
          brne      delay_red           

          cbi       PORTB,PB4           ;set PB4 to low

          ret

timer1_600ms:
          ;1) Set count int TCNT1H/L
          ldi       r20,HIGH(28036)     ;set time clock high byte count 
          sts       TCNT1H,r20          ;copy to temp register
          ldi       r20,LOW(28036)      ;set timer clock low byte count
          sts       TCNT1L,r20          ;write to low byte and copy temp to high

          ;2) Set mode in TCCR1A
          clr       r20
          sts       TCCR1A,r20          ;set normal mode

          ;3) Set clock select in TCCR1B
          ldi       r20,(1<<CS12)
          sts       TCCR1B,r20          ;set clk to 256

          ;4) Watch for T0V1 in TIFR1
tov1_lp:  sbis      TIFR1,TOV1          ;do {
          rjmp      tov1_lp             ;} while (TOV1 == 0)

          ;5) Stop TImer in TCCR1B
          clr       r20
          sts       TCCR1B,r20          ;set no clk select

          ;6) Write 1 T0V1 in TIFR1
          ldi       r20,(1<<TOV1)
          out       TIFR1,r20           ;clear TOV1 flag

          ret       ; end timer1_600ms

;----------------------------------------
ext0_isr:
;----------------------------------------
; interrupt service routine for external
; interrupt 0, from INT0addr, uses PD2
;----------------------------------------
          clr       r16                 ;clear pins in PORTB
          out       PORTB,r16

          sbi       PORTB,PB3           ;set PB3 to high   
          ldi       p_delay,isr_d       ;initialize control variable for delay_ms
delay_ms:                               ;delays for .6 s (same as timer1_600ms)
                                        ;do { isr_d times

          ldi       lc_100ms,80         ;int lc_100ms = 80
lp_100ms:                               ;do {
          ldi       lc_250,250          ;int lc_250 = 250             1 cycle
lp_250:                                 ;do {
          nop                           ;         waste cycle         1 cycle
          nop                           ;         waste cycle         1 cycle
          dec       lc_250              ;         lc_250--            1 cycle
          brne      lp_250              ;} while (lc_250ms > 0)       2 (z=0), 1(z=1)
                                        ;                             5 * 250 = 1250 - 1
                                        
          dec       lc_100ms            ;         lc_100ms--          1 cycle
          brne      lp_100ms            ;while (lc_100ms > 0)         2 (z=0), 1(z=1)
                                        ;                             80 * 1250 = 100 000

          dec       p_delay             ;         p_delay--
          brne      delay_ms

          cbi       PORTB,PB3           ;set PB3 to low
          sbi       PORTB,PB4           ;set PB3 to high


          reti