; -----------------------------------------------------------------------------
; Name:     MAZE
; Author:   Mike Daley
; Started:  19th May 2016
; Finished: 
;
;
; This is an entry for the 256 bytes game competition #6 on the Z80 Assembly programming
; on the ZX Spectrum Facebook Group https://www.facebook.com/groups/z80asm/
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; CONSTANTS
; -----------------------------------------------------------------------------
BITMAP_SCRN_ADDR        equ             0x4000
BITMAP_SCRN_SIZE        equ             0x1800
ATTR_SCRN_ADDR          equ             0x5800
ATTR_SCRN_SIZE          equ             0x300
ATTR_ROW_SIZE           equ             0x1f

BLACK                   equ             0x00
BLUE                    equ             0x01
RED                     equ             0x02
MAGENTA                 equ             0x03
GREEN                   equ             0x04
CYAN                    equ             0x05
YELLOW                  equ             0x06
WHITE                   equ             0x07
PAPER                   equ             0x08                        ; Multiply with inks to get paper colour
BRIGHT                  equ             0x40
FLASH                   equ             0x80                        ; e.g. ATTR = BLACK * PAPER + CYAN + BRIGHT

PLAYER_COLOUR           equ             YELLOW * PAPER + BLACK
SCRN_COLOUR             equ             BLACK * PAPER
BORDER_COLOUR           equ             BLUE * PAPER + BRIGHT       

UP_CELL                 equ             0xffe0                      ; - 32
DOWN_CELL               equ             0x0020                      ; + 32
LEFT_CELL               equ             0xffff                      ; -1 
RIGHT_CELL              equ             0x0001                      ; + 1

DYN_VAR_SHIFT_WIDTH     equ             0x01
DYN_VAR_SHIFT_HEIGHT    equ             0x02
DYN_VAR_SPRITE_1        equ             0x03
DYN_VAR_SPRITE_2        equ             DYN_VAR_SPRITE_1 + 8
; -----------------------------------------------------------------------------
; MAIN CODE
; -----------------------------------------------------------------------------

                org     0x8000

; -----------------------------------------------------------------------------
; Initialiase the game
; -----------------------------------------------------------------------------
init


; -----------------------------------------------------------------------------
; Initiaise the screen by clearing the bitmap screen and attributes
; -----------------------------------------------------------------------------
startGame
                ld      hl, BITMAP_SCRN_ADDR                        ; Point HL at the start of the bitmap file. This approach saves
                                                                    ; 1 byte over using LDIR
clearLoop 
                ld      (hl), SCRN_COLOUR                           ; Reset contents of addr in HL to 0
                inc     hl                                          ; Move to the next address
                ld      a, 0x58                                     ; Have we reached 0x5b00
                cp      h                                           
                jr      nz, clearLoop                               ; It not then loop


mainLoop

                ld      de, 0x2000
                call    getPixelAddr
                

                ld      b, 192
loop
                ld      a, 0xff
                xor     (hl)
                ld      (hl), a

                halt

                ld      a, 0xff
                xor     (hl)
                ld      (hl), a

                call    moveLineDown

                djnz    loop



                call mainLoop


;****************************************************************************************************************
; Calculate the screen address of a pixel location
;
; Entry Registers:
;   D = X pixel location
;   E = Y pixel location
; Used Registers:
;   A, D, E, H, L
; Returned Registers:
;   HL = screen address
;****************************************************************************************************************
getPixelAddr
            ld      a,e                                 ; Load A with the Y pixel location
            srl     a                                   ; Rotate A three time to the left
            srl     a
            srl     a
            and     24                                  ; 
            or      64

            ld      h,a
            ld      a,e
            and     7
            or      h
            ld      h,a

            ld      a,e
            add     a,a
            add     a,a
            and     224
            ld      l,a

            ld      a,d
            srl     a
            srl     a
            srl     a
            or      l
            ld      l,a                 
            ret

;****************************************************************************************************************
; Calculate the screen address which is one row lower than the HL address passed in
;
; Entry Registers:
;   HL = screen address
; Used Registers:
;   A, H, L
; Returned Registers:
;   HL = screen address
;****************************************************************************************************************
moveLineDown   
            inc     h
            ld      a,h
            and     7
            ret     nz
            ld      a,l
            add     a,32
            ld      l,a
            ret     c
            ld      a,h
            sub     8
            ld      h,a                 
            ret          

;****************************************************************************************************************
; Preshift sprite data
; Uses source sprite data to create 7 pre-shifted versions
;
; Entry Registers:
;   HL = Sprite source Addr
;   DE = First shift sprite Addr
;   B = Bytes wide
;   C = Pixel high
; Registers Used:
;   A, B, C, D, E, H, L
; Returned Registers:
;   NONE
;****************************************************************************************************************
prShft
                ld      a, 1
                ld      (dynamicVariables + DYN_VAR_SHIFT_WIDTH), a             ; Save width
                ld      a, 8
                ld      (dynamicVariables + DYN_VAR_SHIFT_HEIGHT), a             ; Save height
                ld      c, 7                        ; Load B with the number of shifts to perform

_prNxtShft
                ld      a, (dynamicVariables + DYN_VAR_SHIFT_HEIGHT)             ; Load the height of the sprite to be shifted
                ld      b, a                        ; Save that in B
_prShftY                
                push    bc                          ; Save B onto the stack
                ld      a, (dynamicVariables + DYN_VAR_SHIFT_WIDTH)             ; Load A with the width of the sprite
                ld      b, a                        ; Load A into B
                xor     a                           ; Clear A and flags ready to shift the sprite bytes right
_prShftX
                ld      a, (hl)                     ; Load the first sprite byte into A
                rra                                 ; Rotate right with the carry bit
                ld      (de), a                     ; Save the rotated byte into the shift sprite location
                inc     hl                          ; Move to the next source byte
                inc     de                          ; Move to the next destination byte
                djnz    _prShftX                    ; If there are still width bytes to shift then go shift them

                pop     bc                          ; Restore B which holds the pixel height of the sprite
                djnz    _prShftY                    ; If there is another pixel row to process then go do it

                dec     c                           ; Decrement the number of sprites to generate
                jr      nz, _prNxtShft              ; If we are not yet at zero then process another sprite shift...

                ret                                 ; ...otherwise we are done            

dynamicVariables

            END init      