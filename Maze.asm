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
PLAY_AREA_COLOUR             equ             BLACK * PAPER
BORDER_COLOUR           equ             BLUE * PAPER + BRIGHT 
BLINKY_COLOUR           equ             MAGENTA * PAPER + BRIGHT      

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
; Initialiase the level complete and trapped variables
; -----------------------------------------------------------------------------
init:
                ld      de, RIGHT_CELL
                ld      (dynamicVariables + DYN_VAR_BLINKY_X_VEC), de

; -----------------------------------------------------------------------------
; Initiaise the screen by clearing the bitmap screen and attributes. Everything
; is set to 0 which is why the border colour used in the game is black to save
; some bytes ;o) 
; -----------------------------------------------------------------------------
startGame:
                ld      hl, BITMAP_SCRN_ADDR                        ; Point HL at the start of the bitmap file. This approach saves
                                                                    ; 1 byte over using LDIR
clearLoop:
                ld      (hl), PLAY_AREA_COLOUR                           ; Reset contents of addr in HL to 0
                inc     hl                                          ; Move to the next address
                ld      a, 0x5b                                     ; Have we reached 0x5b00
                cp      h                                           
                jr      nz, clearLoop                               ; It not then loop

; -----------------------------------------------------------------------------
; Draw playing area - NOT OPTIMISED YET
; -----------------------------------------------------------------------------
drawMaze:
                ld      de, MazeDataEnd - 3

                ld      bc, $0216                                   ; B = number of byte columns, 
_drawRow:
                push    bc
_drawLeftColumn:
                inc     de
                ld      a, (de)

                ld      c, 8

_drawForwardByte:
                ; Decrease first as we are going backwards
                dec     hl                                          ; Move HL to the last byte of attribute data

                rla 
                jr      nc, _skipBlock1
                ld      (hl), BORDER_COLOUR

_skipBlock1:
                dec     c                                         
                jr      nz, _drawForwardByte

                djnz    _drawLeftColumn                             ; If there are more bits left to process, loop

                pop     bc
                push    bc
_drawRightColumn:
                ld      a, (de)
                dec     de
                ld      c, 8

_drawBackwardByte:
                dec     hl

                rra
                jr      nc, _skipBlock2
                ld      (hl), BORDER_COLOUR

_skipBlock2:
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
mainLoop:                                                         
            ; -----------------------------------------------------------------------------
            ; Read the keyboard and update the players position. This allows the player to slide
            ; along walls making it easier to make turns
                ld      de, 0x00
                ld      c, 0xfe                                     ; Set up the port for the keyboard as this wont change
            
_checkRightKey:                                                      ; Move player right
                ld      b, 0xdf                                     ; Read keys YUIOP by setting B only as C is already set
                in      a, (c)          
                rra         
                jr      c, _checkLeftKey                            ; If P was not pressed check O
                ld      de,RIGHT_CELL                               ; P pressed so set the player vector to 0x0001
            
_checkLeftKey:                                                       ; Move player left
                rra         
                jr      c, _moveHoriz         
                ld      de, LEFT_CELL

_moveHoriz:                                                                    
                push    bc
                call    movePlayer 
                pop     bc

_checkUpKey:                                                         ; Move player up
                ld      b, 0xfb                                     ; Read keys QWERT
                in      a, (c)          
                rra         
                jr      c, _checkDownKey           
                ld      de, UP_CELL

_checkDownKey:                                                       ; Move player down
                inc     b                                           ; INC B from 0xFB to 0xFD to read ASDFG
                inc     b           
                in      a, (c)          
                rra         
                jr      c, _moveVert          
                ld      de, DOWN_CELL

_moveVert:
                call    movePlayer

            ; -----------------------------------------------------------------------------
            ; Move Blinky
                ld      de, (dynamicVariables + DYN_VAR_BLINKY_Y_VEC)   ; Apply blinky's x and y vector to his position 
                call    moveBlinky
                ld      de, (dynamicVariables + DYN_VAR_BLINKY_X_VEC)
                call    moveBlinky

                ld      hl, (blinkyAddr)                            ; Only check the players position at a junction
                call    isAJunction
                ld      a, 1
                cp      d
                jr      nz, _drawBlinky

            ; -----------------------------------------------------------------------------
            ; Track Player. Use the cell position that is stored for the player and blinky
            ; it works out if the player is above, below to the left or right of blinky
            ; and then sets the appropriate x and y vector to move towards the player
_trackPlayer:
                ld      ix, dynamicVariables + DYN_VAR_PLAYER_POS
                ld      iy, dynamicVariables + DYN_VAR_BLINKY_POS

                ld      a, (ix + 0)
                sub     (iy + 0)
                jp      m, _moveBlinkyUp
                ld      de, DOWN_CELL
                jr      _saveBlinkyYVec

_moveBlinkyUp:    
                ld      de, UP_CELL  

_saveBlinkyYVec:
                ld      (dynamicVariables + DYN_VAR_BLINKY_Y_VEC), de

                ld      a, (ix + 1)
                sub     (iy + 1)
                jp      m, _moveBlinkyLeft
                ld      de, RIGHT_CELL
                jr      _saveBlinkyXVec

_moveBlinkyLeft:    
                ld      de, LEFT_CELL  

_saveBlinkyXVec:
                ld      (dynamicVariables + DYN_VAR_BLINKY_X_VEC), de

            ; -----------------------------------------------------------------------------
            ; Draw blinky
_drawBlinky:
                ld      hl, (blinkyAddr)
                ld      (hl),  BLINKY_COLOUR   

            ; -----------------------------------------------------------------------------
            ; Draw player 
_drawplayer:
                ld      hl, (playerAddr)                            ; Load the players position 
                ld      (hl), PLAYER_COLOUR                         ; and draw the player
          
            ; -----------------------------------------------------------------------------
            ; Sync screen and slow things down to 12 fps
_sync:          
                halt                                    
                halt
                halt
                halt

                ld      (hl), PLAY_AREA_COLOUR                           ; Erase the player
 
                ld      hl, (blinkyAddr)                            ; Erase blinky
                ld      (hl), PLAY_AREA_COLOUR

                jp      mainLoop                                   ; Loop

; -----------------------------------------------------------------------------
; Update the players position based on the value in DE. DE holds the value to
; be added to the players address and then a check is made to see if that is a 
; wall or not. No wall and the new address is saved, otherwise its ignored
; -----------------------------------------------------------------------------
movePlayer:
                ld      hl, (playerAddr)                            ; Get the players location address             
                add     hl, de                                      ; Calculate the new player position address
                ld      de, 0x0000                                  ; Clear DE for the next movement check
                ld      a, BORDER_COLOUR                            ; Need to check against the border colour
                cp      (hl)                                        ; Compare the new location with the border colour...
                ret     z                                           ; ...and if it is a border block then don't save HL
                ld      (playerAddr), hl                            ; New position is not a border block so save it
                
                push    de
                call    getCellPosition                             ; Calculate the new cell position of the player
                ld      a, d                                        
                ld      (dynamicVariables + DYN_VAR_PLAYER_POS), a  ; Save the Y cell position
                ld      a, e
                ld      (dynamicVariables + DYN_VAR_PLAYER_POS + 1), a ; Save the X cell position
                pop     de
                ret 

; -----------------------------------------------------------------------------
; Move blinky
; -----------------------------------------------------------------------------
moveBlinky:
                ld      hl, (blinkyAddr)
                add     hl, de
                ld      a, BORDER_COLOUR
                cp      (hl)
                ret     z
                ld      (blinkyAddr), hl
                call    getCellPosition                             ; Calculate the new cell position of the player
                ld      a, d                                        
                ld      (dynamicVariables + DYN_VAR_BLINKY_POS), a  ; Save the Y cell position
                ld      a, e
                ld      (dynamicVariables + DYN_VAR_BLINKY_POS + 1), a ; Save the X cell position
                ret

; -----------------------------------------------------------------------------
; Get the X and Y cell position from the attribute address passed in
; Entry:
;   HL = Attribute address
; Exit:
;   D = Y cell position 
;   E = X cell position
; -----------------------------------------------------------------------------
getCellPosition:
                ld      de, ATTR_SCRN_ADDR

                or      1                                           ; Calculate how many bytes the player is into attr memory
                sbc     hl, de
                
                push    hl                                          ; Save # bytes from starts of attribute address

                srl     h                                           ; Divide by 32
                rr      l
                srl     h 
                rr      l
                srl     h 
                rr      l
                srl     h 
                rr      l
                srl     h 
                rr      l

                ld      d, l                                        ; Save the Y tile position

                add     hl, hl                                      ; Multiply result by 32
                add     hl, hl
                add     hl, hl
                add     hl, hl
                add     hl, hl

                push    hl
                pop     bc
                pop     hl

                or      1
                sbc     hl, bc                                     ; Calculate the X position

                ld      e, l                                       ; Save the X tile position 

                ret 

; -----------------------------------------------------------------------------
; Checks to see if the address in HL is a junction e.g. the position 3+ possible
; exits
;   HL = Attribute address
; Exit:
;   D = 0 = No junction, 1 =Junction
; -----------------------------------------------------------------------------
isAJunction:
                ld      bc, 0                                       ; Count of X and Y exists held in B and C
                ld      a, BORDER_COLOUR                            ; Going to check exits for border colour

                ld      de, UP_CELL
                add     hl, de
                cp      (hl)
                jr      z, _checkRightExit
                inc     b

_checkRightExit:
                ld      de, DOWN_CELL + RIGHT_CELL
                add     hl, de
                cp      (hl)
                jr      z, _checkDownExit
                inc     c

_checkDownExit:
                ld      de, DOWN_CELL + LEFT_CELL
                add     hl, de
                cp      (hl)
                jr      z, _checkLeftExit
                inc     b

_checkLeftExit:
                ld      de, UP_CELL + LEFT_CELL
                add     hl, de
                cp      (hl)
                jr      z, _checkExitCount
                inc     c

_checkExitCount:
                ld      a, b
                add     a, c
                cp      3
                jr      c, _possibleCorner
                ld      d, 1
                ret

_possibleCorner:
                ld      d, 0                                        ; If there are two exists that's fine as
                cp      2                                           ; ...long as they are on a different axis, hence
                ret     c                                           ; ...counting the exists on each axis seperately i.e. B, C
                ld      a, b
                cp      1
                ret     nz
                ld      a, c
                ret     nz
                ld      d, 1
                ret

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
playerAddr:     dw      ATTR_SCRN_ADDR + (10 * 32) + 16 
blinkyAddr:     dw      ATTR_SCRN_ADDR + (22 * 32) + 16

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
                db      %11111110, %10111111
                db      %11111110, %10111111
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

dynamicVariables:
                ; dw playerPos
                ; dw blinkyPos
                ; dw blinkyXVector
                ; dw blinkyYVector

                END init








