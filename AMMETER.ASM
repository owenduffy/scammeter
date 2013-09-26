; File AMMETER.ASM
; Uses assembly code for PIC16F84 microcontroller
; 
; Processor pin allocations are as follows:
; RA0 Output disp3 driving transistor for common anode display
; RA1 Output disp2
; RA2 Output disp1
; RA3 Output for PWM to comparator 
; RA4 Output 7-seg bar disp4

; RB0 Input from comparator
; RB1 c segment drive LED7
; RB2 d segment drive LED6
; RB3 e segment drive LED5
; RB4 f segment drive LED3
; RB5 a segment drive LED2	
; RB6 b segment drive LED1
; RB7 g segment drive LED4

; CPU configuration
; 	
	list P=16F84
	#include "p16f84.inc"
	__config _XT_OSC & _WDT_OFF & _PWRTE_ON

; Define variables at memory locations

EEPROM1		equ	H'00'	; non-volatile storage for Vout0 
EEPROM2		equ	H'01'	; non-volatile storage for cal value (amps)
EEPROM3		equ	H'02'	; non-volatile storage for V @ calval
EEPROM4		equ	H'03'	; non-volatile storage for V @ calval-Vout0 (calculated)
				
; RAM

DISP1		equ	H'0C'	; working storage for Display1 
DISP2		equ	H'0D'	; working storage for Display2 
DISP3		equ	H'0E'	; working storage for Display3 
DISP4		equ	H'0F'	; working storage for Display4
STATUS_TMP 	equ 	H'10'	; temp storage for status during interrupt
W_TMP		equ	H'11'	; temporary storage for w during interrupt
FLAG_1		equ	H'12'	; bit 0 is multiplex or PWM flag, bit1 is for interrupt count
PWM_CNT		equ	H'13'	; counter for PWM output
LOW_TME		equ	H'14'	; PWM low time
BIN_0		equ	H'15'	; binary value
BCD_1		equ	H'16'	; display value MS
BCD_2		equ	H'17'	; display value LS
TEMP		equ	H'18'	; temporary register
CNT_8		equ	H'19'	; counter for BCD conversion
TEMP_2		equ	H'1A'	; temporary register
TEMP_3		equ	H'1B'	; temporary storage of BIN_0
EXTN		equ	H'1C'	; delay extension value
CALFLG		equ	H'1D'	; calibration flags
TEMP_1		equ	H'1E'	; temporary store of w
COUNT		equ	H'1F'	; delay counter
TEMP_4		equ     H'20'	; temp register
V_OUT0		equ	H'21'	; output at zero current value
CAL_AMP		equ	H'22'	; amperage at calibration
V_CALA		equ	H'23'	; output at calibration amperage
CALFACT		equ	H'24'	; calibration factor V_CALA - V_OUT0
SIGN		equ	H'25'	; minus sign flag
TEMPD		equ	H'26'	; arithmetic routine temp files
TEMPB0		equ	H'27'
TEMPB1		equ	H'28'

AARGB3		equ	0x34
AARGB2          equ     0x35
AARGB1          equ     0x36
AARGB0          equ     0x37
AARG            equ     0x37    ; most significant byte of argument A
BARGB1          equ     0x38
BARGB0          equ     0x39
BARG            equ     0x39    ; most significant byte of argument B
REMB1           equ     0x3A
REMB0           equ     0x3B    ; most significant byte of remainder
LOOPCOUNT       equ     0x3C    ; loop counter

CALI0		equ	0x80
CALI30		equ	CALI0+D'40'

; preprogram EEPROM DATA (00-3F from 2100-213F)
	
	ORG     2100		; start at 00
	DE	CALI0 
	DE	D'30' 
	DE	CALI30 
	DE	CALI30-CALI0 

; define reset and interrupt vector start addresses

	org	0	  	; start at address 0000h
	goto	MAIN		; normal service routines from Reset vector
	org     4		; interrupt vector 0004h, start interrupt routine here
	goto	INTRUPT		; go to start of interrupt routine, bypass subroutines

;***************************************************************************************
; led bargraph lookup table (DOT display)
; +/- 30A for full display

; plus 0 to +30A on display
LEDOTP  movwf	TEMP_1	; temporary store
	movlw	D'30'	; 
	subwf	TEMP_1,w
	btfsc	STATUS,C; if c is zero then negative
	retlw	B'10111110'	; 30 bit 6 LED1 on, return as greater than table
	movf	TEMP_1,w
	addwf	PCL,f		; add value to program counter

	retlw	B'01111110'	; 0 bit 7 LED4 on
	retlw	B'01111110'	; 1 bit 7 LED4 on
	retlw	B'01111110'	; 2 bit 7 LED4 on
	retlw	B'01111110'	; 3 bit 7 LED4 on
	retlw	B'01111110'	; 4 bit 7 LED4 on

	retlw	B'01101110'	; 5 bit 4,7 LED3,4 on
	retlw	B'01101110'	; 6 bit 4,7 LED3,4 on
	retlw	B'01101110'	; 7 bit 4,7 LED3,4 on
	retlw	B'01101110'	; 8 bit 4,7 LED3,4 on
	retlw	B'01101110'	; 9 bit 4,7 LED3,4 on

	retlw	B'11101110'	; 10 bit 4 LED3 on
	retlw	B'11101110'	; 11 bit 4 LED3 on
	retlw	B'11101110'	; 12 bit 4 LED3 on
	retlw	B'11101110'	; 13 bit 4 LED3 on
	retlw	B'11101110'	; 14 bit 4 LED3 on

	retlw	B'11001110'	; 15 bit 5,4 LED2&3 on
	retlw	B'11001110'	; 16 bit 5,4 LED2&3 on
	retlw	B'11001110'	; 17 bit 5,4 LED2&3 on
	retlw	B'11001110'	; 18 bit 5,4 LED2&3 on
	retlw	B'11001110'	; 19 bit 5,4 LED2&3 on

	retlw	B'11011110'	; 20 bit 5 LED2 on
	retlw	B'11011110'	; 21 bit 5 LED2 on
	retlw	B'11011110'	; 22 bit 5 LED2 on
	retlw	B'11011110'	; 23 bit 5 LED2 on
	retlw	B'11011110'	; 24 bit 5 LED2 on

	retlw	B'10011110'	; 25 bit 6,5 LED1&2 on
	retlw	B'10011110'	; 26 bit 6,5 LED1&2 on
	retlw	B'10011110'	; 27 bit 6,5 LED1&2 on
	retlw	B'10011110'	; 28 bit 6,5 LED1&2 on
	retlw	B'10011110'	; 29 bit 6,5 LED1&2 on

	retlw	B'10111110'	; 30 bit 6 LED1 on

; minus 0 to -30A on display
LEDOTM	movwf	TEMP_1	; temporary store
	movlw	D'30'	; 
	subwf	TEMP_1,w
	btfsc	STATUS,C; if c is zero then negative

	retlw	B'11111100'	; 30 bit 1 LED7 on, return as greater than table
	movf	TEMP_1,w
	addwf	PCL,f		; add value to program counter
	
	retlw	B'01111110'	; 0 bit 7 LED4 on
	retlw	B'01111110'	; 1 bit 7 LED4 on
	retlw	B'01111110'	; 2 bit 7 LED4 on
	retlw	B'01111110'	; 3 bit 7 LED4 on
	retlw	B'01111110'	; 4 bit 7 LED4 on

	retlw	B'01110110'	; 5 bit 3,7 LED4,5 on
	retlw	B'01110110'	; 6 bit 3,7 LED4,5 on
	retlw	B'01110110'	; 7 bit 3,7 LED4,5 on
	retlw	B'01110110'	; 8 bit 3,7 LED4,5 on
	retlw	B'01110110'	; 9 bit 3,7 LED4,5 on

	retlw	B'11110110'	; 10 bit 3 LED5 on
	retlw	B'11110110'	; 11 bit 3 LED5 on
	retlw	B'11110110'	; 12 bit 3 LED5 on
	retlw	B'11110110'	; 13 bit 3 LED5 on
	retlw	B'11110110'	; 14 bit 3 LED5 on

	retlw	B'11110010'	; 15 bit3,2, LED5,6 on
	retlw	B'11110010'	; 16 bit3,2, LED5,6 on
	retlw	B'11110010'	; 17 bit3,2, LED5,6 on
	retlw	B'11110010'	; 18 bit3,2, LED5,6 on
	retlw	B'11110010'	; 19 bit3,2, LED5,6 on
	
	retlw	B'11111010'	; 20 bit 2 LED6 on
	retlw	B'11111010'	; 21 bit 2 LED6 on
	retlw	B'11111010'	; 22 bit 2 LED6 on
	retlw	B'11111010'	; 23 bit 2 LED6 on
	retlw	B'11111010'	; 24 bit 2 LED6 on
	
	retlw	B'11111000'	; 25 bit 2,1 LED6&7 on
	retlw	B'11111000'	; 26 bit 2,1 LED6&7 on
	retlw	B'11111000'	; 27 bit 2,1 LED6&7 on
	retlw	B'11111000'	; 28 bit 2,1 LED6&7 on
	retlw	B'11111000'	; 29 bit 2,1 LED6&7 on
	
	retlw	B'11111100'	; 30 bit 1 LED7 on
	
; **************************************************************************
; subroutine to get seven segment display data. 

SVNSEG	andlw	0x0F		; remove most significant bits if present prevents value >16h
	addwf	PCL,f		; add value of display to program counter
	retlw 	B'10000000'	; 7-segment code 0 
	retlw 	B'10111100'	; 7-segment code 1
	retlw 	B'00010010'	; 7-segment code 2
	retlw 	B'00011000'	; 7-segment code 3
	retlw 	B'00101100'	; 7-segment code 4
	retlw 	B'01001000'	; 7-segment code 5
	retlw 	B'01000000'	; 7-segment code 6
	retlw 	B'10011100'	; 7-segment code 7
	retlw 	B'00000000'	; 7-segment code 8
	retlw 	B'00001000'	; 7-segment code 9

; ******************************************************************************
; Subroutines

; delay period 

DELMOR	movlw 	D'255'		; delay period
	movwf	TEMP_2
SMALER	decfsz	TEMP_2,f	; reduce temp_2
	goto	SMALER		; temp_2 smaller by 1
	return			; end delay

; Subroutine for PWM cycle period for successive approximation A-D converter
	
SAR	movlw	0x38		; number of interrupts between PWM changes
	movwf	PWM_CNT
CNT_AGN	bcf	FLAG_1,1	; bit set in interrupt at multiplex rate
CNT_NOW	btfss	FLAG_1,1	; look at flag
	goto	CNT_NOW		; wait till flag set at multiplex interrupt 
	decfsz 	PWM_CNT,f	; reduce this value 
	goto	CNT_AGN		; cycle 
	return

; Subroutine to convert from 8-bit binary to 2-digit BCD (packed)
; Binary value is in BIN0  
; Result in BCD is in BCD1 & BCD2.  
; BCD1 is MSB, BCD2 is LSB

BCD	bcf	STATUS,C	; clear carry bit
	movlw	D'8'
	movwf	CNT_8		; 8 in count
	clrf	BCD_1
	clrf	BCD_2		; set BCD registers to 0 
LOOPBCD	rlf	BIN_0,f		; shift left binary registers
	rlf	BCD_2,f		; MSB shift left
	rlf	BCD_1,f		; LSB shift left BCD registers
	decfsz	CNT_8,f		; reduce count value return when 0
	goto	DECADJ		; continue decimal adjust
	return			; completed decimal to BCD operation

; subroutine decimal adjust

DECADJ	movlw	BCD_2		; BCD LSB address
	movwf	FSR		; pointer for BCD2
	call	ADJBCD		; subroutine to adjust BCD
	movlw	BCD_1		; BCD MS address
	movwf	FSR		; pointer for BCD1
	call	ADJBCD
	goto	LOOPBCD

; subroutine adjust BCD

ADJBCD	movlw	0x03		; w has 03 
	addwf	INDF,w		; add 03 to BCDx register (x is 0-1)
	movwf	TEMP		; store w
	btfsc	TEMP,3		; test if >7
	movwf	INDF		; save as LS digit
	movlw	0x30		; 3 for MSbyte
	addwf	INDF,w		; add 30 to BCDx register
	movwf	TEMP		; store w in temp
	btfsc	TEMP,7		; test if >7
	movwf	INDF		; save as MS digit
	return			; end subroutine

; subroutine to read EEPROM memory

EEREAD	movwf 	EEADR		; indirect special function register
	bsf 	STATUS,RP0	; select memory bank 1
	bsf	EECON1,RD	; read EEPROM
	bcf	STATUS,RP0	; select bank 0
	movf	EEDATA,w	; EEPROM value in w
	return

; subroutine to write to EEPROM

EWRITE	movwf	EEDATA		; data register
	bcf	INTCON,GIE	; disable interrupts
	bsf	STATUS,RP0	; select bank 1
	bsf	EECON1,WREN	; enable write
	movlw	0x55		; place 55H in w for write sequence
	movwf 	EECON2 		; write 55H to EECON2
	movlw 	0xAA		; AAH to w
	movwf	EECON2		; write AA to EECON2
	bsf	EECON1,WR	; set WR bit and begin write sequence
	
	bcf	EECON1,WREN	; clear WREN bit
WRITE	btfsc	EECON1,WR	; skip if write complete WR=0 when write complete
	goto 	WRITE		; not written yet
	bcf	EECON1,EEIF	; clear write interrupt flag 
	bcf	STATUS,RP0	; select bank 0
	bsf	INTCON,GIE	; enable interrupts
	return

;****************************************************************************


; INTERRUPT
; interrupt from counter used to multiplex display
; this sucessively switches on Disp1, Disp2, Disp3, Disp4 in sequence plus 
; uses internal timer to initiate display update
; produces PWM output with duty set by LOW_TME register
; start interrupt by saving w and status registers before altered by interrupt routine

INTRUPT	movwf	W_TMP		; w to w_tmp storage
	swapf	STATUS,w	; status to w
	movwf	STATUS_TMP	; status in status_tmp  
	bcf	STATUS,RP0	; select memory bank 0

; PWM output routine

PWM_MPX	movf	LOW_TME,w	; PWM low time to w
	btfsc	FLAG_1,0	; check bit 0
	goto	LOW_OUT
	bsf	FLAG_1,0	; clear if set
	nop			; output cycle time adjust
	bcf	PORTA,3		; RA3 low
	sublw	0x02		; PWM low time
	nop			; align timer with cycles of instruction
	addwf	TMR0,f		; 4MHz so low time is inverse of 4MHz/4/2/256  
	bcf	INTCON,T0IF	; clear TMRO interrupt flag
	goto	LITCHK		; multiplex
LOW_OUT	nop			; set equal time between high out and low out
	bsf	PORTA,3		; RA3 high
	addlw	0x02		; align timer
	addwf	TMR0,f		; 4MHz so high time is inverse of 4MHz/4/2/256  
	bcf	FLAG_1,0	; set if clear
	bcf	INTCON,T0IF
	goto	RECLAIM

; multiplex display routine

LITCHK	bsf	FLAG_1,1	; set flag for interrupt count
	btfss	PORTA,2		; skip if display 1 not lit
	goto	LIT1		; display 1 lit
	btfss	PORTA,1		; skip if display 2 not lit
	goto	LIT2		; display 2 lit
	btfss	PORTA,0		; skip if display 3 not lit				
	goto	LIT3		; display 3 lit
	bsf	PORTA,4		; disp4 off
	nop

	movf	DISP1,w		; disp1	to w
	movwf	PORTB
	bcf	PORTA,2		; disp1 powered
	goto 	RECLAIM
LIT1	bsf	PORTA,2		; disp1 off
	nop			; blanking

	movf	DISP2,w		; disp2 to w
	movwf	PORTB		; seven segment value to portB
	bcf	PORTA,1		; disp2 powered
	goto	RECLAIM		; end of multiplex
LIT2	bsf	PORTA,1		; disp2 off
	nop

	movf	DISP3,w		; disp3 to w
	movwf	PORTB		; portB has seven-segment code 
	bcf	PORTA,0		; disp3 powered
	goto	RECLAIM		; end of multiplex
LIT3	bsf	PORTA,0		; disp3 off
	nop

	
; check calibration inputs at RB7, RB3, RB2 and RB1 = zero value, 17A, 25A and 30A 
; respectively

	bsf	STATUS,RP0	; select memory bank 1
	movlw	B'11111111'	; (RB0 input, RB1-RB7 temporary inputs)
	movwf	TRISB		; port B data direction register
	bcf	STATUS,RP0	; memory bank 0

	movlw 	D'20'		; delay period
	movwf	TEMP_2
REDUCE	decfsz	TEMP_2,f	; reduce temp_2
	goto	REDUCE		; temp_2 smaller by 1

	movf	PORTB,w		; load port B values
	movwf	CALFLG		; place in calibration flag
	bsf	STATUS,RP0	; select memory bank 1
	movlw	B'00000001'	; (RB0 input, RB1-RB7 oututs)
	movwf	TRISB		; port B data direction register
	bcf	STATUS,RP0	; select memory bank 0

; continue to drive displays

	movf	DISP4,w		; disp4 to w
	movwf 	PORTB
	bcf	PORTA,4		; disp4 powered

; end of interrupt reclaim w and status 

RECLAIM	swapf	STATUS_TMP,w	; status temp storage to w
	movwf	STATUS		; w to status register
	swapf	W_TMP,f		; swap upper and lower 4-bits in w_tmp
	swapf   W_TMP,w		; swap bits and into w register
	retfie			; return from interrupt

;********************************************************************************************** 
  
; RESET		
; Set ports A & B

MAIN	movlw	B'11111110'	; code for 7-segment display off
	movwf 	DISP1		; display values
	movwf	DISP2		; initial display value
	movwf	DISP3		; initial display value
	movwf	DISP4		; bar graph initial value
	movwf	CALFLG		; set cal flag inputs high
	bsf	STATUS,RP0	; select memory bank 1
	movlw	B'00000001'	; (RB0 input, RB1-RB7 outputs)
	movwf	TRISB		; port B data direction register
	movlw	B'00000000'	; w = 10000000 binary
	movwf	OPTION_REG	; TMRO prescaler, PORTB pullups enabled
	movlw   B'00000000'	; w = 10000 binary (RA0-RA4 outputs)
	movwf   TRISA		; A port data direction register
	bcf	STATUS,RP0	; select memory bank 0
	movlw	B'00010111'
	movwf	PORTA		; portA RA0,RA1,RA2,RA4 outputs high, RA3 low
	movlw	B'11111111'	; w is all 1's for RB7-RB1, 0 for RB0
	movwf	PORTB		; portB outputs high	

; interrupt enable and program now runs

NO_OPEN	bsf	INTCON,T0IE	; set interrupt enable for TMR0 
	bsf	INTCON,GIE	; set global interrupt enable for above

	movlw	B'01111110'	; (-) display
	movwf	DISP2
	movwf	DISP1

; delay for input voltage to settle
	
	movlw	D'15'		; delay counter
	movwf	COUNT

DEL_X	movlw	0xFF		; delay extension
	movwf	EXTN
WAIT	call	DELMOR		; delay
	decfsz	EXTN,f		; out from delay when zero
	goto	WAIT
	
	decfsz	COUNT,f		
	goto	DEL_X		; continue delay until Count is 0


	movlw	EEPROM1		; storage of output with no current
	call	EEREAD
	movwf	V_OUT0		; voltage output at 0 current
	movlw	EEPROM2		; storage of calibration amperage value (A)
	call	EEREAD
	movwf	CAL_AMP		; calibration amperage value
	movlw	EEPROM3		; storage of voltage at calibration amperage value 
	call	EEREAD
	movwf	V_CALA		; voltage at calibration amperage value
	movlw	EEPROM4		; storage of calibration factor (V_CALA - V_OUT0)
	call	EEREAD
	movwf	CALFACT		; calibration factor
 
; Successive Approximation for A-D converter
	
NEWVAL	movlw	0xA0		; delay extension
	movwf	EXTN
MOR_DEL	call	DELMOR		; delay
	decfsz	EXTN,f		; out from delay when zero
	goto	MOR_DEL

	clrf	LOW_TME
	bsf	LOW_TME,7	; bit 7 set
	call	SAR
	btfss 	PORTB,0		; comparator out. if RB0 high then value below 128 (high bit 7)
	bcf	LOW_TME,7	; bit 7 cleared
	bsf	LOW_TME,6	; next LS bit test
	call 	SAR
	btfss 	PORTB,0		; if RB0 high then value below (high bit 6)
	bcf	LOW_TME,6
	bsf	LOW_TME,5
	call 	SAR
	btfss 	PORTB,0		; if RB0 high then value below (high bit 5)
	bcf	LOW_TME,5
	bsf	LOW_TME,4
	call 	SAR
	btfss 	PORTB,0		; if RB0 high then value below (high bit 4)
	bcf	LOW_TME,4
	bsf	LOW_TME,3
	call 	SAR
	btfss 	PORTB,0		; if RB0 high then value below (high bit 3)
	bcf	LOW_TME,3
	bsf	LOW_TME,2
	call 	SAR
	btfss	PORTB,0		; if RB0 high then value below (high bit 2)
	bcf	LOW_TME,2
	bsf	LOW_TME,1
	call 	SAR
	btfss 	PORTB,0		; if RB0 high then value below (high bit 1)
	bcf	LOW_TME,1
	bsf	LOW_TME,0
	call 	SAR
	btfss	PORTB,0		; bit 0 test
	bcf	LOW_TME,0


	movf	LOW_TME,w	; store 255 minus lowtime value into binary0 register
	sublw	D'255'		; get reverse value ie high output time
	movwf	TEMP_3		; temporary storage for pwm value

; check calibration flag CALFLG 7, 3, 2 and 1 = zero value, 17A, 25A and 30A

	btfss	CALFLG,7	; zero current output voltage calibration
	goto	CAL0		; goto calibration 0 value
	btfss	CALFLG,3	; calibration at 17A
	goto	CAL17
	btfss	CALFLG,2	; calibration at 25A
	goto	CAL25
	btfss	CALFLG,1	; calibration at 30A
	goto	CAL30

; Calibration off so continue with current values

	movf	TEMP_3,w
	sublw	D'230'		; check if more than 230
	btfsc	STATUS,C	; more than so load OL into disp	
	goto	AMP		; value is within range	
	movlw	B'10000000'	; "O" as in Overload
	movwf	DISP2	
	movlw	B'11100010'	; "L" as overLoad
	movwf	DISP1
	movlw	B'11111110'	; blank display
	movwf	DISP3
	movlw	B'10111110'	; high 
	movwf	DISP4
	goto	NEWVAL	
MIN_AMP	movlw	B'10000000'	; "O" as in Overload
	movwf	DISP2	
	movlw	B'11100010'	; "L" as overLoad
	movwf	DISP1
	movlw	B'11111100'	; lowest. LED7
	movwf	DISP4
	movlw	B'01111110'	; (-) display
	movwf	DISP3
	goto	NEWVAL
AMP	movlw	D'19'		; minimum value of 19 to w register 
	subwf	TEMP_3,w	; reduce by 19	
	btfss	STATUS,C	; if 0 or positive continue
	goto 	MIN_AMP		; if negative clear value add - sign
	
	movf	TEMP_3,w	; temp storage
	movwf	AARGB2		; Vout value
	movf	V_OUT0,w	; zero amp value
	movwf	BARGB1
	clrf	BARGB0 
	clrf	AARGB1 
	call	D_SUB		; subtract (A-B)	

	btfss	AARGB1,7	; if bit 7 set then redo subtraction and add (-) minus sign
	goto	CONV
	movf	TEMP_3,w	
	movwf	BARGB1		; Vout value
	movf	V_OUT0,w	; zero amp value
	movwf	AARGB2
	clrf	BARGB0 
	clrf	AARGB1 
	call	D_SUB		; subtract in reverse set minus sign
	bsf	SIGN,0 
	goto	CONVM

CONV	bcf	SIGN,0
CONVM	clrf	BARGB0 
 	movf	AARGB2,w	; subtraction result
	movwf	AARGB1		; ls byte
	clrf	AARGB0		; ms byte
	movf	CAL_AMP,w	; calibration amperage value
	movwf	BARGB1
	call	FXM1616U	; call 16 x 16 unsigned multiply
	clrf	AARGB0		; 
	clrf	AARGB1
	movf	AARGB2,w	; ms multiply value
	movwf	AARGB1		; numerator
	movf	AARGB3,w	; ls multiply value
	movwf	AARGB2		; numerator
	clrf	BARGB0		; ms denominator
		
	movf	CALFACT,w	; calibration factor
	movwf	BARGB1
	call	FXD2416U	; divide
	movf	AARGB2,w	; division result
	
	movwf	BIN_0		; register value for bcd conversion 
	call	BCD		; convert binary number to BCD
	movlw	B'11111110'	; 7-segment display off
	btfsc	SIGN,0		; if sign is set show -
	movlw	B'01111110'	; - sign	
	movwf	DISP3		; transfer to DISPlay 3
	
	movf	BCD_1,w		; contains packed BCD value
	btfss	STATUS,Z	; if zero continue (if clear then 100 or more) then load "OL"
	goto 	OVER
	movf	BCD_2,w		; BCD value
	andlw	0x0F		; extract LS bits
	call	SVNSEG
	movwf	DISP1		; place in display 1
	swapf	BCD_2,w		; swap upper and lower 4-bits
	andlw	0x0F		; extract bits
	btfsc	STATUS,Z	; if zero then blank
	goto	BLANK		; blank zero on display
	call	SVNSEG
	movwf	DISP2		; place in middle digit register
	
; bar graph display 
	
BARDSP	movf	AARGB2,w	; binary value to w
	btfsc	SIGN,0		; if clear then positive bar direction
	goto	NEGTVE
	call 	LEDOTP		; get bargraph code for led dot positive
SETBAR	movwf	DISP4 
	goto	NEWVAL
NEGTVE	call	LEDOTM		; LED dot display minus
	goto	SETBAR

BLANK	movlw	B'11111110'	; code for 7-segment display off
	movwf	DISP2
	goto	BARDSP		; load bargraph display

; over in value

OVER	movlw	B'10000000'	; "O" as in Overload
	movwf	DISP2	
	movlw	B'11100010'	; "L" as overLoad
	movwf	DISP1
	goto	BARDSP

; calibration

CAL0	movlw	EEPROM1		; storage of V_OUT0 (value at 0A)
	movwf	EEADR
	movf	TEMP_3,w	; value at 0 Amperes
	movwf	V_OUT0		; place in register
	call	EWRITE		; store in EEPROM
	
	movlw	B'11000010'	; for a C as in CAL in display
	movwf	DISP3
	movlw	B'00000100'	; for an  as in cAl in DISP2
	movwf	DISP2
	movlw	B'11100010'	; for an L as in caL
	movwf	DISP1	
	movlw	B'01111110'	; 0 bit 7 LED4 on
	movwf	DISP4

	movlw	CALI30-CALI0 
	addwf	TEMP_3,f
	goto	CAL30

WAIT1	movlw	0xFF		; delay extension
	movwf	EXTN
WAIT3	call	DELMOR		; delay
	decfsz	EXTN,f		; out from delay when zero
	goto	WAIT3
	goto	NEWVAL
		
CAL30	movlw	B'11111100'	; LED7 discharge on bargraph (30A)
	movwf	DISP4
	movlw	EEPROM2		; store for CAL_AMP value (30A)
	movwf	EEADR
	movlw	D'30'		; 30A (decimal value)
	goto	CAL_X		; calculation with (X) amps

CAL25	movlw	B'11111000'	; LEDs 6 and 7 on 25A
	movwf	DISP4
	movlw	EEPROM2		; store for CAL_AMP value (25A)
	movwf	EEADR
	movlw	D'25'		; 25A (decimal value)
	goto	CAL_X		; calculation with (X) amps

CAL17	movlw	B'11110010'	; LED5 & 6 on 17A
	movwf	DISP4
	movlw	EEPROM2		; store for CAL_AMP value (17A)
	movwf	EEADR
	movlw	D'17'		; 17A (decimal value)
	
CAL_X	movwf	CAL_AMP		; into register
	call	EWRITE		; store in EEPROM
	movlw	EEPROM3		; storage of value at calibration amperage (V_CALA)
	movwf	EEADR
	movf	TEMP_3,w	; measured value
	movwf	V_CALA		; into register
	call	EWRITE		; to EEPROM

	movlw	B'11000010'	; for a C as in Cal in display
	movwf	DISP3
	movlw	B'00000100'	; for an A in DISP2 (as in cAl)
	movwf	DISP2
	movlw	B'11100010'	; for an L (as in caL)
	movwf	DISP1	

; calculate new CALFACT (calibration factor V_CALA - V_OUT0)

	movf	V_CALA,w	; V_CALA is value at calibation Amperage
	movwf	AARGB2		; Vout value
	movf	V_OUT0,w	; zero amp value
	movwf	BARGB1
	clrf	BARGB0 
	clrf	AARGB1 
	call	D_SUB		; subtract
	btfss	AARGB1,7	; if bit 7 set then redo subtraction and add (-) minus sign
	goto	CONV_E		; conversion ended
	movf	V_CALA,w	
	movwf	BARGB1		; Vout value
	movf	V_OUT0,w	; zero amp value
	movwf	AARGB2
	clrf	BARGB0 
	clrf	AARGB1 
	call	D_SUB		; subtract in reverse

CONV_E	movlw	EEPROM4		; storage of CALFACT
	movwf	EEADR
	movf	AARGB2,w	; calculated value
	movwf	CALFACT		; into register
	call	EWRITE		; to EEPROM
	goto	WAIT1		; delay
 
; ****************************************************************************

; Arithmetic routines

      

; 24/16 Bit Unsigned Fixed Point Divide 

;       Input:  24 bit unsigned fixed point dividend in AARGB0, AARGB1,AARGB2
;               16 bit unsigned fixed point divisor in BARGB0, BARGB1

;       Use:    CALL    FXD2416U

;       Output: 24 bit unsigned fixed point quotient in AARGB0, AARGB1,AARGB2
;               16 bit unsigned fixed point remainder in REMB0, REMB1

;       Result: AARG, REM  <--  AARG / BARG


FXD2416U        CLRF            REMB0
                CLRF            REMB1
                CLRF            TEMPD
                RLF             AARGB0,W
                RLF             REMB1, F
                MOVF            BARGB1,W
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                RLF             AARGB0, F
                MOVLW           7
                MOVWF           LOOPCOUNT
LOOPU2416A      RLF             AARGB0,W
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMPD, F
                MOVF            BARGB1,W
                BTFSS           AARGB0,0
                GOTO            UADD46LA
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                GOTO            UOK46LA
UADD46LA        ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           STATUS,C
                MOVLW           1
                ADDWF           TEMPD, F
UOK46LA 	RLF             AARGB0, F
                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU2416A
                RLF             AARGB1,W
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMPD, F
                MOVF            BARGB1,W
                BTFSS           AARGB0,0
                GOTO            UADD46L8
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                GOTO            UOK46L8
UADD46L8        ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           STATUS,C
                MOVLW           1
                ADDWF           TEMPD, F
UOK46L8         RLF             AARGB1, F
                MOVLW           7
                MOVWF           LOOPCOUNT
LOOPU2416B      RLF             AARGB1,W
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMPD, F
                MOVF            BARGB1,W
                BTFSS           AARGB1,0
                GOTO            UADD46LB
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                GOTO            UOK46LB
UADD46LB        ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           STATUS,C
                MOVLW           1
                ADDWF           TEMPD, F
UOK46LB         RLF             AARGB1, F
                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU2416B
                RLF             AARGB2,W
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMPD, F
                MOVF            BARGB1,W
                BTFSS           AARGB1,0
                GOTO            UADD46L16
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                GOTO            UOK46L16
UADD46L16       ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           STATUS,C
                MOVLW           1
                ADDWF           TEMPD, F
UOK46L16        RLF             AARGB2, F
                MOVLW           7
                MOVWF           LOOPCOUNT
LOOPU2416C      RLF             AARGB2,W
                RLF             REMB1, F
                RLF             REMB0, F
                RLF             TEMPD, F
                MOVF            BARGB1,W
                BTFSS           AARGB2,0
                GOTO            UADD46LC
                SUBWF           REMB1, F
                MOVF            BARGB0,W
                BTFSS           STATUS,C
                INCFSZ          BARGB0,W
                SUBWF           REMB0, F
                CLRW
                BTFSS           STATUS,C
                MOVLW           1
                SUBWF           TEMPD, F
                GOTO            UOK46LC
UADD46LC        ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
                CLRW
                BTFSC           STATUS,C
                MOVLW           1
                ADDWF           TEMPD, F
UOK46LC 	RLF             AARGB2, F
                DECFSZ          LOOPCOUNT, F
                GOTO            LOOPU2416C
                BTFSC           AARGB2,0
                GOTO            UOK46L
                MOVF            BARGB1,W
	        ADDWF           REMB1, F
                MOVF            BARGB0,W
                BTFSC           STATUS,C
                INCFSZ          BARGB0,W
                ADDWF           REMB0, F
UOK46L		RETURN
	
; multiply
;
;       Input:  fixed point arguments in AARG and BARG
;
;       Output: product AARGxBARG in AARG
;

;       16x16 Bit Unsigned Fixed Point Multiply 

;       Input:  16 bit unsigned fixed point multiplicand in AARGB0
;               16 bit unsigned fixed point multiplier in BARGB0

;       Use:    CALL    FXM1616U

;       Output: 32 bit unsigned fixed point product in AARGB0



FXM1616U    
		CLRF    AARGB2          ; clear partial product
                CLRF    AARGB3
                MOVF    AARGB0,W
                MOVWF   TEMPB0
                MOVF    AARGB1,W
                MOVWF   TEMPB1
                MOVLW   0x08
                MOVWF   LOOPCOUNT
LOOPUM1616A     RRF     BARGB1, F
                BTFSC   STATUS,C
                GOTO    ALUM1616NAP
                DECFSZ  LOOPCOUNT, F
                GOTO    LOOPUM1616A
                MOVWF   LOOPCOUNT
LOOPUM1616B     RRF     BARGB0, F
                BTFSC   STATUS,C
                GOTO    BLUM1616NAP
                DECFSZ  LOOPCOUNT, F
                GOTO    LOOPUM1616B
                CLRF    AARGB0
                CLRF    AARGB1
                RETLW   0x00
BLUM1616NAP     BCF     STATUS,C
                GOTO    BLUM1616NA
ALUM1616NAP     BCF     STATUS,C
                GOTO    ALUM1616NA
ALOOPUM1616     RRF     BARGB1, F
                BTFSS   STATUS,C
                GOTO    ALUM1616NA
                MOVF    TEMPB1,W
                ADDWF   AARGB1, F
                MOVF    TEMPB0,W
                BTFSC   STATUS,C
                INCFSZ  TEMPB0,W
                ADDWF   AARGB0, F
ALUM1616NA      RRF    AARGB0, F
                RRF    AARGB1, F
                RRF    AARGB2, F
                DECFSZ LOOPCOUNT, F
                GOTO   ALOOPUM1616
                MOVLW  0x08
                MOVWF  LOOPCOUNT
BLOOPUM1616     RRF    BARGB0, F
                BTFSS  STATUS,C
                GOTO   BLUM1616NA
                MOVF   TEMPB1,W
                ADDWF  AARGB1, F
                MOVF   TEMPB0,W
                BTFSC  STATUS,C
                INCFSZ TEMPB0,W
                ADDWF  AARGB0, F
BLUM1616NA      RRF    AARGB0, F
                RRF    AARGB1, F
                RRF    AARGB2, F
                RRF    AARGB3, F
                DECFSZ LOOPCOUNT, F
                GOTO   BLOOPUM1616
                RETURN

; subroutine subtract AARGB1 AARGB2 - BARGB0 BARGB1 = AARGB
	
D_SUB	call	NEG_A		; complement of A

	movf	BARGB1,w 
	addwf	AARGB2,f 	; add lsb
	btfsc	STATUS,C	; add carry
	incf	AARGB1,f 
	movf	BARGB0,w 
	addwf	AARGB1,f 
	return

NEG_A	comf	BARGB1,f 
	incf	BARGB1,f 
	btfsc	STATUS,Z
	decf	BARGB0,f 
	comf	BARGB0,f 
	return	

	
	

	end

	
	
