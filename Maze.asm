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

; -----------------------------------------------------------------------------
; MAIN CODE
; -----------------------------------------------------------------------------

                org     0x8000

; -----------------------------------------------------------------------------
; Initialiase the level complete and trapped variables
; -----------------------------------------------------------------------------
init


; -----------------------------------------------------------------------------
; Initiaise the screen by clearing the bitmap screen and attributes. Everything
; is set to 0 which is why the border colour used in the game is black to save
; some bytes ;o)
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
; Draw playing area
; -----------------------------------------------------------------------------
drawMaze
                ld      hl, ATTR_SCRN_ADDR + (1 * 32)
                ld      de, maze

                ld      c, 0
_drawRow
                push    bc
                ld      c, 2

_drawLeftColumn
                ld      a, (de)
                ld      b, 8

_drawForwardByte
                rla
                jr      nc, _skipBlock1
                ld      (hl), BORDER_COLOUR

_skipBlock1
                inc     hl
                djnz    _drawForwardByte

                inc     de
                dec     c
                xor     a                                           ; Reset A
                or      c                                           ; Compare C with 0
                jr      nz, _drawLeftColumn

                dec     de
                ld      c, 2
_drawRightColumn
                ld      a, (de)
                ld      b, 8

_drawBackwardByte
                rra
                jr      nc, _skipBlock2
                ld      (hl), BORDER_COLOUR

_skipBlock2
                inc     hl
                djnz    _drawBackwardByte

                dec     de
                dec     c
                xor     a                                           ; Reset A
                or      c                                           ; Compare C with 0
                jr      nz, _drawRightColumn
                
                inc     de
                inc     de
                inc     de
                pop     bc
                inc     c
                ld      a, 2 * 22
                cp      c
                jr      nz, _drawRow

; -----------------------------------------------------------------------------
; Main game loop
; -----------------------------------------------------------------------------
mainLoop                                                          
            ; -----------------------------------------------------------------------------
            ; Read the keyboard and update the players direction vector            
                ld      hl, playerVector                            ; We will use HL in a few places so just load it once here
                ld      c, 0xfe                                     ; Set up the port for the keyboard as this wont change
            
_checkRight                                                         ; Move player right
                ld      b, 0xdf                                     ; Read keys YUIOP by setting B only as C is already set
                in      a, (c)          
                rra         
                jr      c, _checkLeft                               ; If P was not pressed check O
                ld      (hl), 0x01                                  ; P pressed so set the player vector to 0x0001
                inc     hl          
                ld      (hl), 0x00          
                dec     hl
            
_checkLeft                                                          ; Move player left
                rra         
                jr      c, _checkUp         
                ld      (hl), 0xff                                  ; O pressed so set the player vector to 0xffff
                inc     hl          
                ld      (hl), 0xff          
                dec     hl
                                                                    ; JR which saves 1 byte
            
_checkUp                                                            ; Move player up
                ld      b, 0xfb                                     ; Read keys QWERT
                in      a, (c)          
                rra         
                jr      c, _checkDown           
                ld      (hl), 0xe0                                  ; Q pressed so set the player vector to 0xfffe
                inc     hl          
                ld      (hl), 0xff          
                dec     hl

_checkDown                                                          ; Move player down
                inc     b                                           ; INC B from 0xFB to 0xFD to read ASDFG
                inc     b           
                in      a, (c)          
                rra         
                jr      c, _movePlayer          
                ld      (hl), 0x20                                  ; A pressed so set the player vectory to 0x0020
                inc     hl          
                ld      (hl), 0x00          

            ; -----------------------------------------------------------------------------
            ; Update the players position based on the current player vector
_movePlayer
                ld      hl, (playerAddr)                            ; Get the players location address             
                ld      de, (playerVector)                          ; Get the players movement vector
                add     hl, de                                      ; Calculate the new player position address
                ld      a, BORDER_COLOUR                            
                cp      (hl)                                        ; Compare the new location with the border colour...
                jr      z, _drawplayer                              ; ...and if it is a border block then don't save HL
                ld      (playerAddr), hl                            ; New position is not a border block so save it
                
            ; -----------------------------------------------------------------------------
            ; Draw player 
_drawplayer
                ld      hl, (playerAddr)                            ; Load the players position 
                ld      (hl), PLAYER_COLOUR                         ; and draw the player
          
            ; -----------------------------------------------------------------------------
            ; Sync screen and slow things down to 25 fps
_sync           halt                                    
                halt
                halt
                ld      (hl), SCRN_COLOUR                           ; Draw the border colour in the current location 

                jp      mainLoop                                   ; Loop

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
playerAddr      dw      ATTR_SCRN_ADDR + (2 * 32) + 1
playerVector    dw      RIGHT_CELL

maze            db      %11111111, %11111111 ;, %11111111, %11111110
                db      %10000000, %00000001 ;, %00000000, %00000010
                db      %10111101, %11111100 ;, %01111111, %01111010
                db      %10111101, %11100001 ;, %00001111, %01111010 
                db      %10111101, %11101111 ;, %11101111, %01111010
                db      %10000000, %00000001 ;, %00000000, %00000010
                db      %10111101, %11111101 ;, %01111111, %01111010
;                 db      %10111101, %111111 ;01, %01111111, %01111010
                db      %10111101, %11111101 ;, %01111111, %01111010
                db      %10000000, %00000000 ;, %00000000, %00000010
                db      %11111110, %10111111 ;, %11111010, %11111110
                db      %00000010, %10100000 ;, %00001010, %10000000
                db      %11111110, %10100000 ;, %00001010, %11111110
                db      %10000000, %00111111 ;, %11111000, %00000010
                db      %10111110, %10000001 ;, %00000010, %11111010
                db      %10111110, %10111101 ;, %01111010, %11111010
                db      %10000000, %10111101 ;, %01111010, %00000010
                db      %10110110, %10111101 ;, %01111010, %11011010
                db      %10110110, %00000000 ;, %00000000, %11011010
                db      %10110110, %10111111 ;, %11111010, %11011010
                db      %10110110, %10111111 ;, %11111010, %11011010
                db      %10000000, %10000000 ;, %00000010, %00000010
                db      %11111111, %11111111 ;, %11111111, %11111110

                END init








