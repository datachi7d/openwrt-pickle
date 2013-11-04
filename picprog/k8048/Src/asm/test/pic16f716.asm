;
; Velleman K8048 PIC16F716 ICSPIO Demo Test (Receive commands, send data).
;
; Copyright (c) 2005-2013 Darron Broad
; All rights reserved.
;
; Licensed under the terms of the BSD license, see file LICENSE for details.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Pinout
; ------
; RA2 AN2          1----18 RA1 AN1
; RA3 AN3 VREF     2    17 RA0 AN0
; RA4 T0CKI        3    16 OSC1 CLKIN
; !MCLR VPP        4    15 OSC2 CLKOUT
; VSS GND          5    14 VDD VCC
; RB0 INT !ECCPAS2 6    13 RB7 P1D
; RB1 T1OSO T1CKI  7    12 RB6 P1C
; RB2 T1ISI        8    11 RB5 P1B
; RB3 CCP P1A      9----10 RB4 !ECCPAS0
;
; K8048 Pin
; ----- ---
; LD1   RB0 (6)
; LD2   RB1 (7)
; LD3   RB2 (8)
; LD4   RB3 (9)
; LD5   RB4 (10)
; LD6   RB5 (11)
; SW1   RA0 (17)
; SW2   RA1 (18)
; SW3   RA2 (1)
; SW4   RA3 (2)
;
; Program
; -------
; k14 program pic16f716.hex
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
                LIST    P=PIC16F716
ERRORLEVEL      -302
#INCLUDE        "p16f716.inc"
#INCLUDE        "device.inc"                ;DEVICE CONFIG
#INCLUDE        "const.inc"                 ;CONSTANTS
#INCLUDE        "macro.inc"                 ;MACROS
;
;******************************************************************************
;
; K8048 PIC16F716 ICSPIO Demo Test (Receive commands, send data).
;
; This demonstrates how we may receive commands from the host computer
; via the ISCP port and execute them. Two commands are implemented.
; The first command takes one argument which sets the six LEDs to that
; value and the second command takes no argument yet demonstrates how
; we may send a value back to the host which, in this case, is the
; current status of the four switches.
;
;******************************************************************************
;
; Config
;
  __CONFIG _CP_OFF & _PWRTE_ON & _WDT_ON & _XT_OSC
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Constants
;
  __IDLOCS 0x1234
;
; XTAL = 4MHz
    CONSTANT CLOCK = 4000000
;   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Variables
;
CBLOCK          0x20                        ;RAM 0x20..0x7F
ENDC
#INCLUDE        "shadow.inc"                ;SHADOW I/O
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Begin
;
                ORG     0x0000
                GOTO    INIT
                ORG     0x0004
                RETFIE
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; ICSP I/O
;
NPINS           SET     .18                 ;18-PIN PDIP
#INCLUDE        "delay.inc"                 ;DELAY COUNTERS
#INCLUDE        "icspio.inc"                ;ICSP I/O
#INCLUDE        "common.inc"                ;COMMON COMMANDS MACRO
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Initialise
;
INIT            BANKSEL BANK0

                BTFSC   STATUS,NOT_TO       ;WATCHDOG TIME-OUT
                GOTO    POWERUP

                MOVLW   0xFF
                XORWF   LATB,F
                MOVF    LATB,W
                MOVWF   PORTB

                GOTO    WATCHDOG            ;CONTINUE

POWERUP         CLRF    LATA                ;INIT PORTA SHADOW
                CLRF    PORTA               ;INIT PORTA

                CLRF    LATB                ;INIT PORTB SHADOW
                DECF    LATB,F
                MOVF    LATB,W              ;INIT PORTB
                MOVWF   PORTB

WATCHDOG        CLRWDT                      ;INIT WATCHDOG

                CLRF    INTCON              ;DISABLE INTERRUPTS

                CLRF    ADCON0              ;SHUTDOWN A/D CONVERTER

                BANKSEL BANK1

                MOVLW   B'00000110'         ;DISABLE A/D CONVERTER
                MOVWF   ADCON1

                MOVLW   B'10001111'         ;DISABLE PULLUPS / WATCHDOG PRESCALE
                MOVWF   OPTION_REG

                MOVLW   B'11111111'         ;PORT A SW1..SW4 I/P
                MOVWF   TRISA               ;INIT TRISA

                MOVLW   B'11000000'         ;PORT B PGD+PDC I/P LD1..LD6 O/P
                MOVWF   TRISB               ;INIT TRISB

                BANKSEL BANK0
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Main loop
;
                CALL    INITIO              ;INITIALISE ICSPIO
;
MAINLOOP        COMMON  MAINLOOP, INIT      ;DO COMMON COMMANDS

                MOVF    BUFFER,W            ;IS LED?
                XORLW   CMD_LED
                BZ      DOLED

                MOVF    BUFFER,W            ;IS SWITCH?
                XORLW   CMD_SWITCH
                BZ      DOSWITCH

                MOVF    BUFFER,W            ;IS TEST?
                XORLW   CMD_TEST
                BZ      DOTEST

                GOTO    UNSUPPORTED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Set LD1..LD6
;
DOLED           CALL    SENDACK             ;COMMAND SUPPORTED
                BC      IOERROR             ;TIME-OUT

                CALL    GETBYTE             ;GET LD ARG
                BC      IOERROR             ;TIME-OUT, PROTOCOL OR PARITY ERROR

                MOVF    BUFFER,W            ;SET LD1..LD6
                ANDLW   0x3F
                MOVWF   LATB                ;UPDATE SHADOW
                MOVWF   PORTB               ;UPDATE PORTB

                GOTO    DOEND               ;COMMAND COMPLETED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Get SW1..SW4
;
DOSWITCH        CALL    SENDACK             ;COMMAND SUPPORTED
                BC      IOERROR             ;TIME-OUT

                MOVF    PORTA,W             ;GET SW1..SW4
                ANDLW   0x0F 
                CALL    SENDBYTE            ;SEND SW1..SW4
                BC      IOERROR             ;TIME-OUT

                GOTO    DOEND               ;COMMAND COMPLETED
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Firmware test
;
DOTEST          CALL    SENDACK             ;COMMAND SUPPORTED
                BC      IOERROR             ;TIME-OUT

                CALL    GETBYTE             ;GET TEST ARG
                BC      IOERROR             ;TIME-OUT, PROTOCOL OR PARITY ERROR

                MOVF    BUFFER,W            ;GET ARG
                MOVWF   ARGUMENT            ;SAVE ARG

                CALL    SENDSUM             ;CLOSE SESSION
                BC      IOERROR             ;TIME-OUT

DOFWTEST        MOVLW   0xFE
                MOVWF   PORTB
                MOVLW   DEL50U
                CALL    DELAYU              ;50us

                CLRWDT

                MOVLW   0xFF
                MOVWF   PORTB
                MOVLW   16
                CALL    DELAYH              ;~1.6ms

                GOTO    DOFWTEST
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                END
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
;