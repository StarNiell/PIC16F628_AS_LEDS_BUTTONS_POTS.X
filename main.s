;**************************************************************************
; FILE:      main.s                                                       *
; CONTENTS:  Simple training using a PIC 16F628 with leds, buttons, pots  *
; AUTHOR:    Aniello Di Nardo (StarNiell) (IU8NQI)                        *
; REVISIONS: (latest entry first)                                         *
; 2022-11-30 - Start project in MPLAB X v.6 (pic-as)                      *
;**************************************************************************

PROCESSOR   16F628
RADIX	DEC
#include <xc.inc>

; PIC configuration
CONFIG FOSC = INTOSCIO		; internal oscillator
CONFIG WDTE = OFF		; watchdog disabled
CONFIG PWRTE = OFF		; Power on disabled
CONFIG MCLRE = ON		; Manual Reset Enabled
CONFIG BOREN = OFF      
CONFIG LVP = OFF       
CONFIG CPD = OFF       
CONFIG CP = OFF          

;EEPROM memory Alias
;-----------------------------------------------------
LED		EQU 32		;LED value (8 leds B7...B0))
H_CONT		EQU 35          ;counter high part
L_CONT		EQU 36          ;Counter low part
FLAG_STATUS	EQU 37		;Multipurpose control bits 
				;0x-------R
				;R = RESET ON
;-----------------------------------------------------
    ; Start Program (entry point) resetVec (reset vector) in 0x00
    ; ex ORG 0x00
    ; Remember to set "-Wl,-PresetVec=0x0" in the pic-as global options 
    ; (Additional Options) of Project Properties
    PSECT resetVec,class=CODE,delta=2
    
    ; resetVec label
    resetVec:
	GOTO INIT        ; go to beginning of program
;-----------------------------------------------------
				
;-----------------------------------------------------
;define button PORTA,0 (not needed if you will use aby PORTA,x)
#define     BUTTON PORTA,7
;define pot PORTA,2 
#define     POT    PORTA,2
;bit R = RESET ON di FLAG_STATUS				
#define	    R	    0
;bit A = POT ACTION ON di FLAG_STATUS				
#define	    PA	    1
;bit mask for LEDP1 (is the pins linked to LED for the POT action)
#define	    LEDP1   0b00000001
;extra OPCODE definition
#define	    BANK0   BCF STATUS,STATUS_RP0_POSITION
#define	    BANK1   BSF STATUS,STATUS_RP0_POSITION
#define	    CLEARC  BCF STATUS,STATUS_C_POSITION	
#define	    CLEARZ  BCF STATUS,STATUS_Z_POSITION	
;-----------------------------------------------------

;-----------------------------------------------------
;Initialize components
INIT:
    ;Comparator setup
    MOVLW   0b00001010	    ;write 5 in W
    MOVWF   CMCON	    ;write W in CMCON (2 = enable RA0...RA3)
    
    BANK1                   ;Bank 1 is active
    ;ports setup
    CLRF    TRISB           ;PORTB is output
    MOVLW   0b11111111      ;write in W (0xFF all bits input)    
    MOVWF   TRISA           ;PORTA is input
    ;vref setup
    MOVLW   0b10001000	    ;write 88 in W (VREF bit 7 - voltage bit 0...3)
    MOVWF   VRCON	    ;scrive W in VRCON
    BANK0                   ;Bank 0 is active
    CLRF    PORTA           ;init PORTA
    CLRF    PORTB           ;init PORTB
    CLRF    FLAG_STATUS     ;init FLAG_STATUS
    ; start
    GOTO    START	    ;goto start program

;-----------------------------------------------------
;start the program    
START:
    ;light the first led of PORTB (RB0)
    CLRW                    ;clear W
    MOVLW   0b00000001      ;write in W the bit 0 active
    MOVWF   LED             ;write W in LED
    MOVWF   PORTB           ;Write LED on PORTB
    CLEARC                  ;clear flag C
    BSF	    FLAG_STATUS,PA  ;set PA flag ON (because the bit 0 of PORTB is ON!)
                            ;but if at start, POT put C2OUT in OFF, bit 0 wil be OFF!
    GOTO    LOOP            ;jump to LOOP
    
LOOP:
    ;Use any button on PORTA
    ;--------------------------------------------------------------------
    ;CALL    DELAY           ;little delay
    ;CLRW                    ;clear W
    ;SUBWF   PORTA, W        ;subtract PORTA con 0 (for compare)
                            ;0 - 0 = 0, if PORTA != 0 Z Flag is actri
    ;BTFSC   STATUS,STATUS_Z_POSITION	;Check Z Flag
    ;GOTO    LOOP            ;If Z == 0 repeat the LOOP
    ;CALL    GEST_BUTTON     ;else call GEST_BUTTON (flag Z on!)

    ;Use declared BUTTON on PORTA
    ;--------------------------------------------------------------------
    CALL READ_BUTTON         ;read button
    ;--------------------------------------------------------------------
    CALL READ_POT            ;read pot
    GOTO LOOP

READ_BUTTON:    
    BTFSC   BUTTON          ;skip if BUTTON is OFF
    CALL    GEST_BUTTON     ;else call GEST_BUTTON
    RETURN
    
GEST_BUTTON: 
    CLEARC                  ;clear flag C
    CLEARZ                  ;clear flag Z
    ;CALL    INCR
    CALL    SHIFT
    MOVF    LED,W           ;Scrive LED in W
    MOVWF   PORTB           ;Scrive W sulla PORTB
    CLEARC                  ;clear flag C
    CALL    DELAY           ;small delay
    GOTO    LOOP

READ_POT:
    BTFSC   C2OUT           ;skip if (C2OUT is OFF)
    CALL    LEDP1_ON        ;LEDP1_ON (C2OUT is ON)
    BTFSS   C2OUT           ;sskip if (C2OUT is ON)
    CALL    LEDP1_OFF       ;LEDP1_OFF (C2OUT is OFF)
    RETURN
    
LEDP1_ON:
    BTFSC   FLAG_STATUS,PA  ;skip if STATUS_FLAG,PA is OFF
    RETURN
    CALL    MASK_LED
    BSF	    FLAG_STATUS,PA  ;set PA flag ON
    RETURN		    

LEDP1_OFF:
    BTFSS   FLAG_STATUS,PA  ;skip if STATUS_FLAG,PA is ON
    RETURN
    CALL    MASK_LED
    BCF	    FLAG_STATUS,PA  ;set PA flag OFF
    RETURN		    

MASK_LED:
    MOVLW   LEDP1	    ;write LEPD1 bit mask in W
    XORWF   LED,W           ;combine LEDP1_OFF XOR LED
    MOVWF   LED		    ;invert LEPD1 bits of LED register!
    MOVWF   PORTB           ;write W on PORTB
    CLEARC                  ;clear flag C
    RETURN
SHIFT:
    BTFSC   LED,7           ;if bit 7 of LED == 0 skip
    CALL    RESET_LED
    BTFSS   FLAG_STATUS,R   ;if R of FLAG_STATUS == 1 skip
    ; shift bit to left
    RLF	    LED,F           ;execute SHIFT 
    BCF	    FLAG_STATUS,R   ;clear bit R of FLAG_STATUS
    RETURN
    
INCR:
    ; increase the LED byte
    MOVLW   0b00000001      ;write 1 in W
    ADDWF   LED,W	    ;add 1 to LED e take the sum in W
    MOVWF   LED             ;write W in LED
    RETURN
    
RESET_LED:
    BSF	    FLAG_STATUS,R   ;set bit R of FLAG_STATUS to ON
    MOVLW   0b00000001      ;write the bit 0 in W
    MOVWF   LED             ;write W in LED
    RETURN

;Delay routine at 16 bit (High and Low byte)
;-----------------------------------------------------
DELAY:
    ;init 2 bytes counter
    ;8 cycles
    MOVLW     0x56	    ;Load 0x2B66 in H_CONT e L_CONT
    MOVWF     H_CONT	    
    MOVLW     0xCC	    
    MOVWF     L_CONT	    
    GOTO      DELAY2	    
    
DELAY2:
    ;Execute small delay
    ;With XTAL_FREQ = 4Mhz the 16 bit: delay = val * ~9
    ;for some small difference use NOP
    DECF      L_CONT,F	    ;decrease counter low part
    COMF      L_CONT,W	    ;Invert bit
    BTFSC     STATUS,STATUS_Z_POSITION	;if 0 the rollover
    DECF      H_CONT,F	    ;then decrease counter high part
    MOVF      L_CONT,W	    ;load W in the low part
    IORWF     H_CONT,W	    ;and do an OR with the high part
    BTFSS     STATUS,STATUS_Z_POSITION	;if 0 then skip (cycle end)
    GOTO      DELAY2	    ;then goto to DELAY2
    NOP
    RETURN		    
END    

