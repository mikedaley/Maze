; -----------------------------------------------------------------------------
; Name:         JUMP
; Authors:      Mike Daley
; Started:      25th May 2016
; Finished: 
;
; Infinite Jumping Clone
;
; This is an entry for the 256 bytes game competition #6 on the Z80 Assembly programming
; on the ZX Spectrum Facebook Group https://www.facebook.com/groups/z80asm/
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; CONSTANTS
; -----------------------------------------------------------------------------
BITMAP_SCRN_ADDR        equ             0x4000
BITMAP_SCRN_SIZE        equ             0x1800                      ; 6144
ATTR_SCRN_ADDR          equ             0x5800
ATTR_SCRN_SIZE          equ             0x300                       ; 768
ATTR_ROW_SIZE           equ             0x20                        ; 32

BLACK                   equ             0x00
BLUE                    equ             0x01
RED                     equ             0x02
MAGENTA                 equ             0x03
GREEN                   equ             0x04
CYAN                    equ             0x05
YELLOW                  equ             0x06
WHITE                   equ             0x07
PAPER                   equ             0x08                        ; Multiply with inks to get paper colour
BRIGHT                  equ             0x40                        ; 64
FLASH                   equ             0x80                        ; 128

PLAYER_COLOUR           equ             YELLOW * PAPER + BLACK
SCRN_COLOUR             equ             BLACK * PAPER
BORDER_COLOUR           equ             BLUE * PAPER + BRIGHT 
PURPLE_GHOST_COLOUR     equ             MAGENTA * PAPER + BRIGHT      

UP_CELL                 equ             0xffe0                      ; - 32
DOWN_CELL               equ             0x0020                      ; + 32
LEFT_CELL               equ             0xffff                      ; -1 
RIGHT_CELL              equ             0x0001                      ; + 1

DYN_VAR_PLAYER_POS      equ             0x00
DYN_VAR_BLINKY_POS      equ             0x02
DYN_VAR_BLINKY_X_VEC    equ             0x04
DYN_VAR_BLINKY_Y_VEC    equ             0x06

; -----------------------------------------------------------------------------
; MAIN CODE
; -----------------------------------------------------------------------------

                org     0x8000

; -----------------------------------------------------------------------------
; Initialiase
; -----------------------------------------------------------------------------
init

; -----------------------------------------------------------------------------
; Initiaise the screen by clearing the bitmap screen and attributes.
; -----------------------------------------------------------------------------
startGame
                ld      hl, BITMAP_SCRN_ADDR                        ; Point HL at the start of the bitmap file. This approach saves
                                                                    ; 1 byte over using LDIR
clearLoop 
                ld      (hl), SCRN_COLOUR                           ; Reset contents of addr in HL to 0
                inc     hl                                          ; Move to the next address
                ld      a, 0x5b                                     ; Have we reached 0x5b00
                cp      h                                           
                jr      nz, clearLoop                               ; It not then loop

; -----------------------------------------------------------------------------
; Main Loop
; -----------------------------------------------------------------------------
mainLoop

                halt
                halt
                halt
                halt
                halt
                halt
                halt
                halt
                halt

                ld      hl, ATTR_SCRN_ADDR + (23 * 32) + 31
                ld      de, ATTR_SCRN_ADDR + (24 * 32) + 31
                ld      a, 24
scrollLoop                
                ld      bc, 32
                lddr

                dec     a
                jr      nz, scrollLoop

                ld      bc, 31
                ld      hl, ATTR_SCRN_ADDR
                ld      de, ATTR_SCRN_ADDR + 1
                ld      (hl), 0
                ldir
                ld      hl, ATTR_SCRN_ADDR

                ld      b, 32
newLineLoop
                push    hl
                call    genRndmNmbr
                pop     hl
                ld      a, (rndmNmbr1)
                cp      2
                jr      nc, nextCell

                ld      (hl), GREEN * PAPER + BRIGHT
                inc     hl


nextCell
                inc     hl
                djnz    newLineLoop


                jr      mainLoop

genRndmNmbr     ld      hl, rndmNmbr1
                ld      e, (hl)
                inc     l
                ld      d, (hl)
                inc     l
                ld      a, r
                xor     (hl)
                xor     e
                xor     d
                rlca
                rlca
                rlca
                srl     e
                srl     d
                ld      (hl), d
                dec     l
                ld      (hl), e
                dec     l
                ld      (hl), a
                ret

rndmNmbr1       db      0xaa                        ; Holds a random number calculated each frame
rndmNmbr2       db      0x55                        ; Holds a random number calculated each frame
rndmNmbr3       db      0xf0                        ; Holds a random number calculated each frame

; -----------------------------------------------------------------------------
; Platform Data
; -----------------------------------------------------------------------------
platformData
                db %00011100, %00001110, %00000000, %01110000
                db %00000001, %11000000, %00001110, %00000011
                db %00011100, %00000011, %10000001, %11000000
                db %11100000, %11100000, %00000011, %10000000



END init
