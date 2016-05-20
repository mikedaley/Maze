; -----------------------------------------------------------------------------
; Name:         MAZE
; Authors:      Mike Daley & Adrian Brown
; Started:      19th May 2016
; Finished: 
;
; PacMan, in 256 bytes, you gotta be kidding me :o)
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
; Draw playing area - NOT OPTIMISED YET
; -----------------------------------------------------------------------------
drawMaze
                ld      de, MazeDataEnd - 3

                ld      bc, $0216                                   ; B = number of byte columns, 
_drawRow
                push    bc
_drawLeftColumn
                inc     de
                ld      a, (de)

                ld      c, 8

_drawForwardByte
                ; Decrease first as we are going backwards
                dec     hl                                          ; Move HL to the last byte of attribute data

                rla 
                jr      nc, _skipBlock1
                ld      (hl), BORDER_COLOUR

_skipBlock1
                dec     c                                         
                jr      nz, _drawForwardByte

                djnz    _drawLeftColumn                             ; If there are more bits left to process, loop

                pop     bc
                push    bc
_drawRightColumn
                ld      a, (de)
                dec     de
                ld      c, 8

_drawBackwardByte
                dec     hl

                rra
                jr      nc, _skipBlock2
                ld      (hl), BORDER_COLOUR

_skipBlock2
                dec     c
                jr      nz, _drawBackwardByte

                djnz    _drawRightColumn

                dec     de
                dec     de
                pop     bc
                dec     c
                jr      nz, _drawRow

; -----------------------------------------------------------------------------
; Main game loop
; -----------------------------------------------------------------------------
mainLoop                                                          
            ; -----------------------------------------------------------------------------
            ; Read the keyboard and update the players position. This allows the player to slide
            ; along walls making it easier to make turns
                ld      de, 0x00
                ld      c, 0xfe                                     ; Set up the port for the keyboard as this wont change
            
_checkRight                                                         ; Move player right
                ld      b, 0xdf                                     ; Read keys YUIOP by setting B only as C is already set
                in      a, (c)          
                rra         
                jr      c, _checkLeft                               ; If P was not pressed check O
                ld      de,RIGHT_CELL                               ; P pressed so set the player vector to 0x0001
            
_checkLeft                                                          ; Move player left
                rra         
                jr      c, _moveHoriz         
                ld      de, LEFT_CELL

_moveHoriz                                                                    
                call    movePlayer

_checkUp                                                            ; Move player up
                ld      b, 0xfb                                     ; Read keys QWERT
                in      a, (c)          
                rra         
                jr      c, _checkDown           
                ld      de, UP_CELL

_checkDown                                                          ; Move player down
                inc     b                                           ; INC B from 0xFB to 0xFD to read ASDFG
                inc     b           
                in      a, (c)          
                rra         
                jr      c, _moveVert          
                ld      de, DOWN_CELL

_moveVert
                call    movePlayer

            ; -----------------------------------------------------------------------------
            ; Draw player 
_drawplayer
                ld      hl, (playerAddr)                            ; Load the players position 
                ld      (hl), PLAYER_COLOUR                         ; and draw the player
          
            ; -----------------------------------------------------------------------------
            ; Sync screen and slow things down to 12 fps
_sync           halt                                    
                halt
                halt

                ld      (hl), SCRN_COLOUR                           ; Draw the border colour in the current location 

                jp      mainLoop                                   ; Loop

; -----------------------------------------------------------------------------
; Update the players position based on the current player vector
; -----------------------------------------------------------------------------
movePlayer
                ld      hl, (playerAddr)                            ; Get the players location address             
                add     hl, de                                      ; Calculate the new player position address
                ld      de, 0x0000                                  ; Clear DE for the next movement check
                ld      a, BORDER_COLOUR                            ; Need to check against the border colour
                cp      (hl)                                        ; Compare the new location with the border colour...
                ret     z                                           ; ...and if it is a border block then don't save HL
                ld      (playerAddr), hl                            ; New position is not a border block so save it
                ret 

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
playerAddr      dw      ATTR_SCRN_ADDR + (3 * 32) + 1
; playerXVector   dw      RIGHT_CELL

MazeData:       db      %11111111, %11111111
                db      %10000000, %00000001
                db      %10111101, %11111100
                db      %10111101, %11100001
                db      %10111101, %11101111
                db      %10000000, %00000001
                db      %10111101, %11111101
                db      %10111101, %11111101
                db      %10000000, %00000000
                db      %11111110, %10111111
                db      %00000010, %10100000
                db      %11111110, %10100000
                db      %10000000, %00111111
                db      %10111110, %10000001
                db      %10111110, %10111101
                db      %10000000, %10111101
                db      %10110110, %10111101
                db      %10110110, %00000000
                db      %10110110, %10111111
                db      %10110110, %10111111
                db      %10000000, %10000000
                db      %11111111, %11111111
MazeDataEnd:
                END init








