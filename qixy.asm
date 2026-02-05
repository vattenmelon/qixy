; ============================================================================
; QIXY - A Modern Qix Clone for Commodore 64
; ============================================================================
; Assembler: ACME Cross-Assembler
; Build: acme -f cbm -o qixy.prg qixy.asm
; Run: LOAD"QIXY",8,1 then RUN or SYS 2064
; ============================================================================

!cpu 6510

; ============================================================================
; MEMORY MAP
; ============================================================================
; $0801-$080F  BASIC stub
; $0810-$1FFF  Game code
; $2000-$27FF  Custom charset (gameplay)
; $2800-$2BFF  Sprite data
; $0400-$07E7  Screen RAM (gameplay)
; $D800-$DBE7  Color RAM
; $C000-$C0FF  Trail buffer (safe location!)
; $C100-$C1FF  Game field state buffer
;
; Title Screen (VIC Bank 1):
; $5C00-$5FE7  Screen RAM for title (1000 bytes)
; $6000-$7F3F  Bitmap data (8000 bytes)
; Title color data stored at TITLE_COLORS label, copied to $D800

; ============================================================================
; ZERO PAGE VARIABLES
; ============================================================================

; Player state
PLAYER_X        = $02       ; Player X position (1-38)
PLAYER_Y        = $03       ; Player Y position (2-23)
PLAYER_DIR      = $04       ; Current direction (0=none, 1=up, 2=down, 3=left, 4=right)
PLAYER_DRAWING  = $05       ; 1 if currently drawing
PLAYER_SPEED    = $06       ; Movement delay counter
PLAYER_ON_EDGE  = $07       ; 1 if player is on border/claimed edge
FIRE_HELD       = $08       ; 1 if fire button is held
PREV_FIRE       = $09       ; Previous fire state (for edge detection)

; Qix enemy state
QIX_X           = $0A       ; Qix X position
QIX_Y           = $0B       ; Qix Y position
QIX_DX          = $0C       ; Qix X velocity (-1, 0, 1)
QIX_DY          = $0D       ; Qix Y velocity
QIX_TIMER       = $0E       ; Direction change timer

; Sparx enemies
SPARX1_X        = $0F
SPARX1_Y        = $10
SPARX1_DIR      = $11       ; Current movement direction
SPARX2_X        = $12
SPARX2_Y        = $13
SPARX2_DIR      = $14

; Game state
SCORE_LO        = $15
SCORE_MID       = $16
SCORE_HI        = $17
LIVES           = $18
LEVEL           = $19
PERCENT_CLAIMED = $1A
TARGET_PERCENT  = $1B
GAME_STATE      = $1C       ; 0=title, 1=playing, 2=dying, 3=level_complete, 4=game_over
FRAME_COUNT     = $1D
DEATH_TIMER     = $1E
PREV_DRAW_DIR   = $1F       ; Previous drawing direction (for corners)

; Temporary variables
TEMP1           = $20
TEMP2           = $21
TEMP3           = $22
TEMP4           = $23
SCREEN_LO       = $24
SCREEN_HI       = $25
COLOR_LO        = $26
COLOR_HI        = $27
RNG_SEED        = $28
SAVE_X          = $29
SAVE_Y          = $2A

; Trail management
TRAIL_COUNT     = $2B       ; Number of trail segments (x2 for x,y pairs)
TRAIL_START_X   = $2C       ; Where trail started
TRAIL_START_Y   = $2D

; Flood fill variables
FILL_STACK_PTR  = $2E
CLAIMED_COUNT   = $2F       ; For percentage calculation (low byte)
CLAIMED_COUNT_HI = $41      ; For percentage calculation (high byte) - dedicated to avoid TEMP3 corruption
TOTAL_COUNT_LO  = $30
TOTAL_COUNT_HI  = $31
FLOOD_X         = $32       ; Current flood fill X coordinate (preserved across PUSH_IF_EMPTY)
FLOOD_Y         = $33       ; Current flood fill Y coordinate (preserved across PUSH_IF_EMPTY)

; Incremental fill state machine (to avoid freezing)
FILL_STATE      = $34       ; 0=inactive, 1=trail, 2=flood, 3=claim, 4=restore, 5=calc
FILL_ROW        = $35       ; Current row for scan phases
FILL_COL        = $36       ; Current column for scan phases
FILL_INDEX      = $37       ; Index for trail conversion phase

; Music variables
MUSIC_TIMER     = $38       ; Frame counter for music tempo
MUSIC_POS       = $39       ; Position in pattern (0-31)
BASS_NOTE       = $3A       ; Current bass note index
LEAD_NOTE       = $3B       ; Current lead note index
ARP_NOTE        = $3C       ; Current arpeggio note
ARP_POS         = $3D       ; Arpeggio position (0-2)
MUSIC_ENABLED   = $3E       ; 1 = music playing, 0 = stopped
MUSIC_MODE      = $41       ; 0 = normal, 1 = sad (game over)
PAUSED          = $42       ; 1 = game paused, 0 = running
FILL_COLOR_IDX  = $43       ; Current fill color index (cycles through colors)

; Saved Qix position for fill operation (captures position at claim start)
FILL_QIX_X      = $3F       ; Qix X when fill started
FILL_QIX_Y      = $40       ; Qix Y when fill started

; Number of operations per frame (tune for performance)
; Fill runs alongside normal gameplay, so keep ops low
; C64 has ~20000 cycles per frame, these values keep it smooth
FLOOD_OPS_PER_FRAME = 8     ; Stack operations for flood fill
SCAN_OPS_PER_FRAME = 32     ; Tiles for scan phases

; ============================================================================
; MEMORY BUFFERS (Safe locations above BASIC)
; ============================================================================

TRAIL_BUFFER_X  = $C000     ; Trail X coordinates (max 128 segments)
TRAIL_BUFFER_Y  = $C080     ; Trail Y coordinates
FILL_STACK_X    = $C100     ; Flood fill stack X (256 entries)
FILL_STACK_Y    = $C200     ; Flood fill stack Y (256 entries)
FIELD_STATE     = $C180     ; Copy of field for fill algorithm (40x25=1000 bytes)
                            ; Actually we'll just use screen RAM directly

; ============================================================================
; HARDWARE REGISTERS
; ============================================================================

VIC_SPRITE_X0   = $D000
VIC_SPRITE_Y0   = $D001
VIC_SPRITE_X1   = $D002
VIC_SPRITE_Y1   = $D003
VIC_SPRITE_X2   = $D004
VIC_SPRITE_Y2   = $D005
VIC_SPRITE_X3   = $D006
VIC_SPRITE_Y3   = $D007
VIC_SPRITE_MSB  = $D010
VIC_CTRL1       = $D011
VIC_RASTER      = $D012
VIC_SPRITE_EN   = $D015
VIC_CTRL2       = $D016
VIC_MEMSETUP    = $D018
VIC_IRQ         = $D019
VIC_SPRITE_PRI  = $D01B
VIC_BORDER      = $D020
VIC_BGCOLOR     = $D021
VIC_SPRITE_COL  = $D027

SID_FREQ_LO1    = $D400
SID_FREQ_HI1    = $D401
SID_PW_LO1      = $D402
SID_PW_HI1      = $D403
SID_CTRL1       = $D404
SID_AD1         = $D405
SID_SR1         = $D406
SID_FREQ_LO2    = $D407
SID_FREQ_HI2    = $D408
SID_PW_LO2      = $D409
SID_PW_HI2      = $D40A
SID_CTRL2       = $D40B
SID_AD2         = $D40C
SID_SR2         = $D40D
SID_FREQ_LO3    = $D40E
SID_FREQ_HI3    = $D40F
SID_PW_LO3      = $D410
SID_PW_HI3      = $D411
SID_CTRL3       = $D412
SID_AD3         = $D413
SID_SR3         = $D414
SID_FILT_LO     = $D415
SID_FILT_HI     = $D416
SID_FILT_CTRL   = $D417
SID_VOLUME      = $D418

CIA1_PORTA      = $DC00
CIA1_PORTB      = $DC01
CIA2_PORTA      = $DD00     ; VIC bank selection

; ============================================================================
; CONSTANTS
; ============================================================================

SCREEN_RAM      = $0400
COLOR_RAM       = $D800
CHARSET_RAM     = $2000
SPRITE_RAM      = $2800

; Playfield boundaries
FIELD_LEFT      = 1
FIELD_TOP       = 3
FIELD_RIGHT     = 38
FIELD_BOTTOM    = 23

; Tile characters
CHAR_EMPTY      = 128       ; Unclaimed area (dark)
CHAR_CLAIMED    = 129       ; Claimed area (filled)
CHAR_BORDER     = 130       ; Border
CHAR_TRAIL_H    = 131       ; Horizontal trail
CHAR_TRAIL_V    = 132       ; Vertical trail
CHAR_CORNER_LB  = 133       ; Corner: left + bottom (╭)
CHAR_CORNER_RB  = 134       ; Corner: right + bottom (╮)
CHAR_CORNER_LT  = 135       ; Corner: left + top (╰)
CHAR_CORNER_RT  = 136       ; Corner: right + top (╯)

; Colors
COL_BLACK       = 0
COL_WHITE       = 1
COL_RED         = 2
COL_CYAN        = 3
COL_PURPLE      = 4
COL_GREEN       = 5
COL_BLUE        = 6
COL_YELLOW      = 7
COL_ORANGE      = 8
COL_BROWN       = 9
COL_PINK        = 10
COL_DGREY       = 11
COL_GREY        = 12
COL_LGREEN      = 13
COL_LBLUE       = 14
COL_LGREY       = 15

; ============================================================================
; BASIC STUB
; ============================================================================

* = $0801
        !byte $0C, $08              ; Next line pointer
        !byte $0A, $00              ; Line 10
        !byte $9E                   ; SYS token
        !text "2064"                ; Address
        !byte $00                   ; End of line
        !byte $00, $00              ; End of program

; ============================================================================
; MAIN ENTRY POINT
; ============================================================================

* = $0810

START:
        sei

        ; Initialize
        jsr INIT_MEMORY
        jsr INIT_VIC
        jsr INIT_CHARSET
        jsr INIT_SPRITES
        jsr INIT_SID
        jsr INIT_MUSIC          ; Start the Miami Vice beat!

        ; Start at title
        lda #0
        sta GAME_STATE
        jsr SHOW_TITLE

        cli

; ============================================================================
; MAIN LOOP
; ============================================================================

MAIN_LOOP:
        jsr WAIT_FRAME
        inc FRAME_COUNT
        jsr UPDATE_MUSIC        ; Keep the beat going!

        lda GAME_STATE
        beq @title
        cmp #1
        beq @playing
        cmp #2
        beq @dying
        cmp #3
        beq @level_done
        cmp #4
        beq @game_over
        jmp MAIN_LOOP

@title:
        jsr UPDATE_TITLE
        jmp MAIN_LOOP

@playing:
        ; Check for pause toggle (P key)
        jsr CHECK_PAUSE_KEY

        ; If paused, check for resume input
        lda PAUSED
        beq @not_paused
        jsr CHECK_RESUME
        jmp MAIN_LOOP

@not_paused:
        ; Process fill incrementally if active (small work per frame)
        lda FILL_STATE
        beq @no_fill
        jsr UPDATE_FILL
@no_fill:
        ; Normal gameplay continues regardless of fill state
        jsr READ_JOYSTICK
        jsr UPDATE_PLAYER
        jsr UPDATE_QIX
        jsr UPDATE_SPARX
        jsr CHECK_COLLISIONS
        jsr UPDATE_SPRITES
        jsr ANIMATE_COLORS
        jmp MAIN_LOOP

@dying:
        jsr UPDATE_DYING
        jmp MAIN_LOOP

@level_done:
        jsr UPDATE_LEVEL_DONE
        jmp MAIN_LOOP

@game_over:
        jsr UPDATE_GAME_OVER
        jmp MAIN_LOOP

; ============================================================================
; WAIT FOR FRAME (Vertical blank sync)
; ============================================================================

WAIT_FRAME:
        lda #250
@wait1: cmp VIC_RASTER
        bne @wait1
@wait2: cmp VIC_RASTER
        beq @wait2
        rts

; ============================================================================
; PAUSE HANDLING
; ============================================================================

; Previous P key state for edge detection
PREV_P_KEY      !byte 0

CHECK_PAUSE_KEY:
        ; Read keyboard row for P key
        ; P is at row 5 (select with $DF), column 1
        lda #$DF                ; Select keyboard row 5
        sta CIA1_PORTA
        lda CIA1_PORTB          ; Read columns
        and #$02                ; Check column 1 (P key)
        bne @p_not_pressed

        ; P is pressed - check if it was already pressed (edge detection)
        lda PREV_P_KEY
        bne @done               ; Already pressed, ignore
        lda #1
        sta PREV_P_KEY

        ; Toggle pause state
        lda PAUSED
        beq @pause_game

        ; Unpause (P pressed while paused)
        jsr UNPAUSE_GAME
        jmp @done

@pause_game:
        jsr PAUSE_GAME
        jmp @done

@p_not_pressed:
        lda #0
        sta PREV_P_KEY

@done:
        ; Restore joystick reading (CIA port setting)
        lda #$FF
        sta CIA1_PORTA
        rts

PAUSE_GAME:
        lda #1
        sta PAUSED

        ; Stop music
        lda #0
        sta MUSIC_ENABLED
        sta SID_CTRL1
        sta SID_CTRL2
        sta SID_CTRL3

        ; Show "PAUSED" message (center of screen, row 12)
        ldx #0
@show:  lda PAUSED_TXT, x
        beq @done
        sta SCREEN_RAM + 497, x ; Row 12, centered
        lda #COL_YELLOW
        sta COLOR_RAM + 497, x
        inx
        bne @show
@done:  rts

UNPAUSE_GAME:
        lda #0
        sta PAUSED

        ; Restart music
        jsr INIT_MUSIC

        ; Clear "PAUSED" message
        ldx #5
@clear: lda #CHAR_EMPTY
        sta SCREEN_RAM + 497, x
        lda #COL_DGREY
        sta COLOR_RAM + 497, x
        dex
        bpl @clear
        rts

CHECK_RESUME:
        ; Check joystick for any input
        lda CIA1_PORTA
        and #$1F                ; Check all directions + fire
        cmp #$1F                ; All released = $1F
        bne @resume

        ; Check keyboard for any key press (scan all rows)
        lda #$00                ; Select all rows
        sta CIA1_PORTA
        lda CIA1_PORTB
        cmp #$FF                ; No key = $FF
        beq @done

@resume:
        ; But not if P is still held (wait for release first)
        lda #$DF
        sta CIA1_PORTA
        lda CIA1_PORTB
        and #$02
        beq @done               ; P still held, don't resume yet

        jsr UNPAUSE_GAME
@done:
        ; Restore joystick reading
        lda #$FF
        sta CIA1_PORTA
        rts

; ============================================================================
; INITIALIZATION
; ============================================================================

INIT_MEMORY:
        ; Clear zero page variables
        lda #0
        ldx #$3F
@clr:   sta $02, x
        dex
        bpl @clr

        ; Initialize RNG
        lda $D012
        ora #$01
        sta RNG_SEED
        rts

INIT_VIC:
        lda #COL_BLACK
        sta VIC_BGCOLOR
        lda #COL_BLACK
        sta VIC_BORDER

        ; Screen at $0400, charset at $2000
        lda #$18
        sta VIC_MEMSETUP
        rts

INIT_CHARSET:
        ; Copy ROM charset to RAM
        sei
        lda $01
        pha
        lda #$33            ; Char ROM visible
        sta $01

        ldx #0
@copy:  lda $D000, x
        sta CHARSET_RAM, x
        lda $D100, x
        sta CHARSET_RAM + $100, x
        lda $D200, x
        sta CHARSET_RAM + $200, x
        lda $D300, x
        sta CHARSET_RAM + $300, x
        dex
        bne @copy

        pla
        sta $01
        cli

        ; Create custom chars (128-131)
        ; Char 128: Empty area (subtle dot pattern)
        ldx #7
        lda #$00
@emp:   sta CHARSET_RAM + 1024, x
        dex
        bpl @emp
        lda #$10
        sta CHARSET_RAM + 1024 + 3

        ; Char 129: Claimed (solid)
        ldx #7
        lda #$FF
@clm:   sta CHARSET_RAM + 1032, x
        dex
        bpl @clm

        ; Char 130: Border (solid)
        ldx #7
        lda #$FF
@brd:   sta CHARSET_RAM + 1040, x
        dex
        bpl @brd

        ; Char 131: Horizontal trail (thin band for left/right movement)
        lda #%00000000          ; empty top
        sta CHARSET_RAM + 1048 + 0
        sta CHARSET_RAM + 1048 + 1
        sta CHARSET_RAM + 1048 + 2
        lda #%11111111          ; solid center band
        sta CHARSET_RAM + 1048 + 3
        sta CHARSET_RAM + 1048 + 4
        lda #%00000000          ; empty bottom
        sta CHARSET_RAM + 1048 + 5
        sta CHARSET_RAM + 1048 + 6
        sta CHARSET_RAM + 1048 + 7

        ; Char 132: Vertical trail (thin stripe for up/down movement)
        lda #%00011000          ; center 2 columns, all rows
        sta CHARSET_RAM + 1056 + 0
        sta CHARSET_RAM + 1056 + 1
        sta CHARSET_RAM + 1056 + 2
        sta CHARSET_RAM + 1056 + 3
        sta CHARSET_RAM + 1056 + 4
        sta CHARSET_RAM + 1056 + 5
        sta CHARSET_RAM + 1056 + 6
        sta CHARSET_RAM + 1056 + 7

        ; Char 133: Corner left+bottom (╭)
        lda #%00000000
        sta CHARSET_RAM + 1064 + 0
        sta CHARSET_RAM + 1064 + 1
        sta CHARSET_RAM + 1064 + 2
        lda #%11111000          ; left half + center
        sta CHARSET_RAM + 1064 + 3
        sta CHARSET_RAM + 1064 + 4
        lda #%00011000          ; center stripe down
        sta CHARSET_RAM + 1064 + 5
        sta CHARSET_RAM + 1064 + 6
        sta CHARSET_RAM + 1064 + 7

        ; Char 134: Corner right+bottom (╮)
        lda #%00000000
        sta CHARSET_RAM + 1072 + 0
        sta CHARSET_RAM + 1072 + 1
        sta CHARSET_RAM + 1072 + 2
        lda #%00011111          ; center + right half
        sta CHARSET_RAM + 1072 + 3
        sta CHARSET_RAM + 1072 + 4
        lda #%00011000          ; center stripe down
        sta CHARSET_RAM + 1072 + 5
        sta CHARSET_RAM + 1072 + 6
        sta CHARSET_RAM + 1072 + 7

        ; Char 135: Corner left+top (╰)
        lda #%00011000          ; center stripe up
        sta CHARSET_RAM + 1080 + 0
        sta CHARSET_RAM + 1080 + 1
        sta CHARSET_RAM + 1080 + 2
        lda #%11111000          ; left half + center
        sta CHARSET_RAM + 1080 + 3
        sta CHARSET_RAM + 1080 + 4
        lda #%00000000
        sta CHARSET_RAM + 1080 + 5
        sta CHARSET_RAM + 1080 + 6
        sta CHARSET_RAM + 1080 + 7

        ; Char 136: Corner right+top (╯)
        lda #%00011000          ; center stripe up
        sta CHARSET_RAM + 1088 + 0
        sta CHARSET_RAM + 1088 + 1
        sta CHARSET_RAM + 1088 + 2
        lda #%00011111          ; center + right half
        sta CHARSET_RAM + 1088 + 3
        sta CHARSET_RAM + 1088 + 4
        lda #%00000000
        sta CHARSET_RAM + 1088 + 5
        sta CHARSET_RAM + 1088 + 6
        sta CHARSET_RAM + 1088 + 7

        rts

INIT_SPRITES:
        ; Clear sprite area
        ldx #0
        lda #0
@clr:   sta SPRITE_RAM, x
        sta SPRITE_RAM + 64, x
        sta SPRITE_RAM + 128, x
        sta SPRITE_RAM + 192, x
        inx
        cpx #64
        bne @clr

        ; Sprite 0: Player (small diamond)
        lda #%00011000
        sta SPRITE_RAM + 0
        lda #%00111100
        sta SPRITE_RAM + 3
        lda #%01111110
        sta SPRITE_RAM + 6
        lda #%11111111
        sta SPRITE_RAM + 9
        lda #%11111111
        sta SPRITE_RAM + 12
        lda #%01111110
        sta SPRITE_RAM + 15
        lda #%00111100
        sta SPRITE_RAM + 18
        lda #%00011000
        sta SPRITE_RAM + 21

        ; Sprite 1: Qix (larger, animated looking)
        lda #%00111100
        sta SPRITE_RAM + 64 + 0
        lda #%01111110
        sta SPRITE_RAM + 64 + 3
        lda #%11111111
        sta SPRITE_RAM + 64 + 6
        lda #%11100111
        sta SPRITE_RAM + 64 + 9
        lda #%11100111
        sta SPRITE_RAM + 64 + 12
        lda #%11111111
        sta SPRITE_RAM + 64 + 15
        lda #%01111110
        sta SPRITE_RAM + 64 + 18
        lda #%00111100
        sta SPRITE_RAM + 64 + 21

        ; Sprite 2-3: Sparx (small square)
        lda #%01111110
        sta SPRITE_RAM + 128 + 0
        sta SPRITE_RAM + 128 + 3
        sta SPRITE_RAM + 128 + 6
        sta SPRITE_RAM + 128 + 9
        sta SPRITE_RAM + 128 + 12
        sta SPRITE_RAM + 128 + 15

        lda #%01111110
        sta SPRITE_RAM + 192 + 0
        sta SPRITE_RAM + 192 + 3
        sta SPRITE_RAM + 192 + 6
        sta SPRITE_RAM + 192 + 9
        sta SPRITE_RAM + 192 + 12
        sta SPRITE_RAM + 192 + 15

        ; Set sprite pointers
        lda #(SPRITE_RAM / 64)
        sta SCREEN_RAM + 1016
        lda #(SPRITE_RAM / 64) + 1
        sta SCREEN_RAM + 1017
        lda #(SPRITE_RAM / 64) + 2
        sta SCREEN_RAM + 1018
        lda #(SPRITE_RAM / 64) + 3
        sta SCREEN_RAM + 1019

        ; Colors
        lda #COL_CYAN
        sta VIC_SPRITE_COL + 0
        lda #COL_RED
        sta VIC_SPRITE_COL + 1
        lda #COL_YELLOW
        sta VIC_SPRITE_COL + 2
        lda #COL_ORANGE
        sta VIC_SPRITE_COL + 3

        ; Enable sprites
        lda #%00001111
        sta VIC_SPRITE_EN

        ; Clear MSB
        lda #0
        sta VIC_SPRITE_MSB
        sta VIC_SPRITE_PRI

        rts

INIT_SID:
        ; Clear all SID registers first
        ldx #$18
@clr:   lda #0
        sta SID_FREQ_LO1, x
        dex
        bpl @clr

        lda #$0F
        sta SID_VOLUME
        rts

; ============================================================================
; VIC MODE SWITCHING (for bitmap title screen)
; ============================================================================

; Enable bitmap mode for title screen
; VIC Bank 1 ($4000-$7FFF), multicolor bitmap mode
; Screen at $5C00, Bitmap at $4000
ENABLE_BITMAP_MODE:
        ; Disable sprites during switch
        lda #0
        sta VIC_SPRITE_EN

        ; Switch to VIC Bank 1 ($4000-$7FFF)
        ; CIA2 $DD00 bits 0-1: 11=bank0, 10=bank1, 01=bank2, 00=bank3
        lda CIA2_PORTA
        and #%11111100          ; Clear bank bits
        ora #%00000010          ; Bank 1 (bits = 10)
        sta CIA2_PORTA

        ; Enable bitmap mode
        ; $D011 bit 5 = 1 for bitmap mode
        lda VIC_CTRL1
        ora #%00100000          ; Set bitmap mode bit
        sta VIC_CTRL1

        ; Enable multicolor mode
        ; $D016 bit 4 = 1 for multicolor
        lda VIC_CTRL2
        ora #%00010000          ; Set multicolor bit
        sta VIC_CTRL2

        ; Set memory pointers
        ; $D018: bits 4-7 = screen offset, bit 3 = bitmap offset
        ; Screen at $5C00 (offset $1C00 in bank = %0111 xxxx)
        ; Bitmap at $6000 (offset $2000 in bank = %xxxx 1xxx)
        ; Value: %01111000 = $78
        lda #$78
        sta VIC_MEMSETUP
        rts

; Disable bitmap mode, return to character mode for gameplay
; VIC Bank 0 ($0000-$3FFF), character mode
; Screen at $0400, Charset at $2000
DISABLE_BITMAP_MODE:
        ; Switch to VIC Bank 0 ($0000-$3FFF)
        lda CIA2_PORTA
        ora #%00000011          ; Bank 0 (bits = 11)
        sta CIA2_PORTA

        ; Disable bitmap mode
        lda VIC_CTRL1
        and #%11011111          ; Clear bitmap mode bit
        sta VIC_CTRL1

        ; Disable multicolor mode (for characters)
        lda VIC_CTRL2
        and #%11101111          ; Clear multicolor bit
        sta VIC_CTRL2

        ; Set memory pointers for gameplay
        ; Screen at $0400, charset at $2000
        ; $D018: %0001 1000 = $18
        lda #$18
        sta VIC_MEMSETUP

        ; Re-enable sprites
        lda #%00001111
        sta VIC_SPRITE_EN
        rts

; Copy color RAM data for title screen
COPY_TITLE_COLORS:
        ldx #0
@loop1: lda TITLE_COLORS, x
        sta COLOR_RAM, x
        lda TITLE_COLORS + $100, x
        sta COLOR_RAM + $100, x
        lda TITLE_COLORS + $200, x
        sta COLOR_RAM + $200, x
        inx
        bne @loop1

        ; Copy remaining bytes (1000 - 768 = 232 bytes)
        ldx #0
@loop2: lda TITLE_COLORS + $300, x
        sta COLOR_RAM + $300, x
        inx
        cpx #232
        bne @loop2
        rts

; ============================================================================
; TITLE SCREEN
; ============================================================================

SHOW_TITLE:
        ; Copy color RAM data for bitmap title
        jsr COPY_TITLE_COLORS

        ; Enable bitmap mode
        jsr ENABLE_BITMAP_MODE

        ; Set border and background colors
        lda #TITLE_BG_COLOR
        sta VIC_BGCOLOR
        lda #COL_BLACK
        sta VIC_BORDER
        rts

UPDATE_TITLE:
        ; Keep border black
        lda #COL_BLACK
        sta VIC_BORDER

        ; Check fire button
        lda CIA1_PORTA
        and #$10
        bne @no

        ; Start game
        jsr START_NEW_GAME
@no:    rts

; ============================================================================
; START NEW GAME
; ============================================================================

START_NEW_GAME:
        ; Switch back to character mode from bitmap title
        jsr DISABLE_BITMAP_MODE

        lda #0
        sta SCORE_LO
        sta SCORE_MID
        sta SCORE_HI
        sta PERCENT_CLAIMED
        sta TRAIL_COUNT
        sta PLAYER_DRAWING
        sta PREV_FIRE
        sta FILL_STATE
        sta FILL_COLOR_IDX

        lda #3
        sta LIVES
        lda #1
        sta LEVEL
        lda #75
        sta TARGET_PERCENT

        jsr INIT_LEVEL

        ; Start the Miami Vice beat fresh
        jsr INIT_MUSIC

        lda #1
        sta GAME_STATE
        rts

INIT_LEVEL:
        ; Draw playfield
        jsr DRAW_PLAYFIELD

        ; Player starts on left border, middle
        lda #FIELD_LEFT
        sta PLAYER_X
        lda #13
        sta PLAYER_Y
        lda #1
        sta PLAYER_ON_EDGE

        ; Qix starts in center
        lda #20
        sta QIX_X
        lda #13
        sta QIX_Y
        lda #1
        sta QIX_DX
        lda #1
        sta QIX_DY
        lda #60
        sta QIX_TIMER

        ; Sparx on borders
        lda #FIELD_LEFT
        sta SPARX1_X
        lda #FIELD_TOP
        sta SPARX1_Y
        lda #4              ; Moving right
        sta SPARX1_DIR

        lda #FIELD_RIGHT
        sta SPARX2_X
        lda #FIELD_BOTTOM
        sta SPARX2_Y
        lda #3              ; Moving left
        sta SPARX2_DIR

        lda #0
        sta TRAIL_COUNT
        sta PLAYER_DRAWING
        sta PERCENT_CLAIMED
        sta FILL_STATE

        jsr DRAW_HUD
        rts

; ============================================================================
; DRAW PLAYFIELD
; ============================================================================

DRAW_PLAYFIELD:
        jsr CLEAR_SCREEN

        ; Draw top border
        ldx #FIELD_LEFT
        ldy #FIELD_TOP
@top:   jsr DRAW_BORDER_TILE
        inx
        cpx #FIELD_RIGHT + 1
        bne @top

        ; Draw bottom border
        ldx #FIELD_LEFT
        ldy #FIELD_BOTTOM
@bot:   jsr DRAW_BORDER_TILE
        inx
        cpx #FIELD_RIGHT + 1
        bne @bot

        ; Draw left border
        ldx #FIELD_LEFT
        ldy #FIELD_TOP
@lft:   jsr DRAW_BORDER_TILE
        iny
        cpy #FIELD_BOTTOM + 1
        bne @lft

        ; Draw right border
        ldx #FIELD_RIGHT
        ldy #FIELD_TOP
@rgt:   jsr DRAW_BORDER_TILE
        iny
        cpy #FIELD_BOTTOM + 1
        bne @rgt

        ; Fill interior with empty
        ldy #FIELD_TOP + 1
@row:   ldx #FIELD_LEFT + 1
@col:   jsr DRAW_EMPTY_TILE
        inx
        cpx #FIELD_RIGHT
        bne @col
        iny
        cpy #FIELD_BOTTOM
        bne @row

        rts

; Draw tile at X, Y (preserves X, Y)
DRAW_BORDER_TILE:
        stx SAVE_X
        sty SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_BORDER
        sta (SCREEN_LO), y
        lda #COL_LBLUE
        sta (COLOR_LO), y
        ldx SAVE_X
        ldy SAVE_Y
        rts

DRAW_EMPTY_TILE:
        stx SAVE_X
        sty SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_EMPTY
        sta (SCREEN_LO), y
        lda #COL_DGREY
        sta (COLOR_LO), y
        ldx SAVE_X
        ldy SAVE_Y
        rts

DRAW_TRAIL_TILE:
        stx SAVE_X
        sty SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        ; Check if direction changed (corner needed)
        lda PREV_DRAW_DIR
        beq @no_corner          ; First tile, no corner
        cmp PLAYER_DIR
        beq @no_corner          ; Same direction, no corner
        ; Direction changed - select correct corner
        ; PREV_DRAW_DIR: 1=up, 2=down, 3=left, 4=right
        ; PLAYER_DIR: 1=up, 2=down, 3=left, 4=right
        lda PREV_DRAW_DIR
        cmp #3
        bcs @prev_horiz         ; prev was left(3) or right(4)
        ; Prev was vertical (up or down)
        lda PREV_DRAW_DIR
        cmp #1
        beq @prev_up
        ; Prev was down(2) = entered from TOP, now going left or right
        lda PLAYER_DIR
        cmp #3
        beq @corner_lt          ; down->left: TOP+LEFT corner
        lda #CHAR_CORNER_RT     ; down->right: TOP+RIGHT corner
        jmp @draw
@prev_up:
        ; Prev was up(1) = entered from BOTTOM, now going left or right
        lda PLAYER_DIR
        cmp #3
        beq @corner_lb          ; up->left: BOTTOM+LEFT corner
        lda #CHAR_CORNER_RB     ; up->right: BOTTOM+RIGHT corner
        jmp @draw
@prev_horiz:
        ; Prev was horizontal (left or right)
        lda PREV_DRAW_DIR
        cmp #3
        beq @prev_left
        ; Prev was right(4), now must be up(1) or down(2)
        lda PLAYER_DIR
        cmp #1
        beq @corner_lt          ; right->up = ╰
        jmp @corner_lb          ; right->down = ╭
@prev_left:
        ; Prev was left(3), now must be up(1) or down(2)
        lda PLAYER_DIR
        cmp #1
        beq @corner_rt          ; left->up = ╯
        lda #CHAR_CORNER_RB     ; left->down = ╮
        jmp @draw
@corner_lb:
        lda #CHAR_CORNER_LB
        jmp @draw
@corner_lt:
        lda #CHAR_CORNER_LT
        jmp @draw
@corner_rt:
        lda #CHAR_CORNER_RT
        jmp @draw
@no_corner:
        ; Choose character based on movement direction
        lda PLAYER_DIR
        cmp #3                  ; left or right = horizontal
        bcs @horiz
        lda #CHAR_TRAIL_V       ; up/down = vertical stripe
        jmp @draw
@horiz: lda #CHAR_TRAIL_H       ; left/right = horizontal band
@draw:  sta (SCREEN_LO), y
        lda #COL_GREY
        sta (COLOR_LO), y
        ; Update previous direction
        lda PLAYER_DIR
        sta PREV_DRAW_DIR
        ldx SAVE_X
        ldy SAVE_Y
        rts

DRAW_CLAIMED_TILE:
        stx SAVE_X
        sty SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_CLAIMED
        sta (SCREEN_LO), y
        ; Color based on fill index (different color per area)
        ldx FILL_COLOR_IDX
        lda CLAIM_COLORS, x
        ldy #0
        sta (COLOR_LO), y
        ldx SAVE_X
        ldy SAVE_Y
        rts

; Calculate screen address from X (column), Y (row)
; Result in SCREEN_LO/HI and COLOR_LO/HI
; Uses lookup table for reliability
CALC_SCREEN_ADDR:
        ; Save X (column)
        stx TEMP1

        ; Get row base address from table (Y = row number, direct index)
        lda ROW_ADDR_LO, y
        sta SCREEN_LO
        lda ROW_ADDR_HI, y
        sta SCREEN_HI

        ; Add column X
        lda TEMP1
        clc
        adc SCREEN_LO
        sta SCREEN_LO
        bcc @nc
        inc SCREEN_HI
@nc:
        ; Color address = screen + $D400
        lda SCREEN_LO
        sta COLOR_LO
        lda SCREEN_HI
        clc
        adc #>(COLOR_RAM - SCREEN_RAM)
        sta COLOR_HI

        ; Restore X
        ldx TEMP1
        rts

; Row address lookup table (SCREEN_RAM + row * 40)
ROW_ADDR_LO:
        !byte <(SCREEN_RAM + 0)
        !byte <(SCREEN_RAM + 40)
        !byte <(SCREEN_RAM + 80)
        !byte <(SCREEN_RAM + 120)
        !byte <(SCREEN_RAM + 160)
        !byte <(SCREEN_RAM + 200)
        !byte <(SCREEN_RAM + 240)
        !byte <(SCREEN_RAM + 280)
        !byte <(SCREEN_RAM + 320)
        !byte <(SCREEN_RAM + 360)
        !byte <(SCREEN_RAM + 400)
        !byte <(SCREEN_RAM + 440)
        !byte <(SCREEN_RAM + 480)
        !byte <(SCREEN_RAM + 520)
        !byte <(SCREEN_RAM + 560)
        !byte <(SCREEN_RAM + 600)
        !byte <(SCREEN_RAM + 640)
        !byte <(SCREEN_RAM + 680)
        !byte <(SCREEN_RAM + 720)
        !byte <(SCREEN_RAM + 760)
        !byte <(SCREEN_RAM + 800)
        !byte <(SCREEN_RAM + 840)
        !byte <(SCREEN_RAM + 880)
        !byte <(SCREEN_RAM + 920)
        !byte <(SCREEN_RAM + 960)

ROW_ADDR_HI:
        !byte >(SCREEN_RAM + 0)
        !byte >(SCREEN_RAM + 40)
        !byte >(SCREEN_RAM + 80)
        !byte >(SCREEN_RAM + 120)
        !byte >(SCREEN_RAM + 160)
        !byte >(SCREEN_RAM + 200)
        !byte >(SCREEN_RAM + 240)
        !byte >(SCREEN_RAM + 280)
        !byte >(SCREEN_RAM + 320)
        !byte >(SCREEN_RAM + 360)
        !byte >(SCREEN_RAM + 400)
        !byte >(SCREEN_RAM + 440)
        !byte >(SCREEN_RAM + 480)
        !byte >(SCREEN_RAM + 520)
        !byte >(SCREEN_RAM + 560)
        !byte >(SCREEN_RAM + 600)
        !byte >(SCREEN_RAM + 640)
        !byte >(SCREEN_RAM + 680)
        !byte >(SCREEN_RAM + 720)
        !byte >(SCREEN_RAM + 760)
        !byte >(SCREEN_RAM + 800)
        !byte >(SCREEN_RAM + 840)
        !byte >(SCREEN_RAM + 880)
        !byte >(SCREEN_RAM + 920)
        !byte >(SCREEN_RAM + 960)

; Get tile at X, Y -> returns char in A (preserves X, Y)
GET_TILE:
        sty TEMP4           ; Use TEMP4 to avoid conflict with SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda (SCREEN_LO), y
        ldy TEMP4
        rts

; ============================================================================
; DRAW HUD
; ============================================================================

DRAW_HUD:
        ; Score label
        ldx #0
@s1:    lda SCORE_TXT, x
        beq @s2
        sta SCREEN_RAM + 1, x
        lda #COL_WHITE
        sta COLOR_RAM + 1, x
        inx
        bne @s1

@s2:    ; Lives label
        ldx #0
@s3:    lda LIVES_TXT, x
        beq @s4
        sta SCREEN_RAM + 16, x
        lda #COL_WHITE
        sta COLOR_RAM + 16, x
        inx
        bne @s3

@s4:    ; Level label
        ldx #0
@s5:    lda LEVEL_TXT, x
        beq @s6
        sta SCREEN_RAM + 26, x
        lda #COL_WHITE
        sta COLOR_RAM + 26, x
        inx
        bne @s5

@s6:    ; Percent label
        ldx #0
@s7:    lda PCT_TXT, x
        beq @s8
        sta SCREEN_RAM + 34, x
        lda #COL_WHITE
        sta COLOR_RAM + 34, x
        inx
        bne @s7

@s8:    jsr UPDATE_HUD
        rts

UPDATE_HUD:
        ; Score (6 digits at position 7)
        lda SCORE_HI
        jsr BYTE_TO_DEC
        stx SCREEN_RAM + 7
        sty SCREEN_RAM + 8
        lda SCORE_MID
        jsr BYTE_TO_DEC
        stx SCREEN_RAM + 9
        sty SCREEN_RAM + 10
        lda SCORE_LO
        jsr BYTE_TO_DEC
        stx SCREEN_RAM + 11
        sty SCREEN_RAM + 12

        ; Color score
        lda #COL_CYAN
        ldx #5
@cs:    sta COLOR_RAM + 7, x
        dex
        bpl @cs

        ; Lives at position 23
        lda LIVES
        clc
        adc #$30
        sta SCREEN_RAM + 23
        lda #COL_LGREEN
        sta COLOR_RAM + 23

        ; Level at position 30
        lda LEVEL
        clc
        adc #$30
        sta SCREEN_RAM + 31
        lda #COL_YELLOW
        sta COLOR_RAM + 31

        ; Percent at position 34
        lda PERCENT_CLAIMED
        jsr BYTE_TO_DEC
        stx SCREEN_RAM + 35
        sty SCREEN_RAM + 36
        lda #'%'
        sta SCREEN_RAM + 37
        lda #COL_LGREEN
        sta COLOR_RAM + 35
        sta COLOR_RAM + 36
        sta COLOR_RAM + 37
        rts

; Byte in A -> X=tens digit, Y=ones digit (screen codes)
BYTE_TO_DEC:
        ldx #$30
        sec
@tens:  sbc #10
        bcc @done
        inx
        bne @tens
@done:  adc #10
        clc
        adc #$30
        tay
        rts

; ============================================================================
; CLEAR SCREEN
; ============================================================================

CLEAR_SCREEN:
        lda #$20
        ldx #0
@loop:  sta SCREEN_RAM, x
        sta SCREEN_RAM + $100, x
        sta SCREEN_RAM + $200, x
        sta SCREEN_RAM + $2E8, x
        dex
        bne @loop

        lda #COL_LBLUE
        ldx #0
@col:   sta COLOR_RAM, x
        sta COLOR_RAM + $100, x
        sta COLOR_RAM + $200, x
        sta COLOR_RAM + $2E8, x
        dex
        bne @col
        rts

; ============================================================================
; READ JOYSTICK (Port 2)
; ============================================================================

READ_JOYSTICK:
        lda CIA1_PORTA
        sta TEMP1

        ; Save previous fire state
        lda FIRE_HELD
        sta PREV_FIRE

        ; Check fire
        lda TEMP1
        and #$10
        bne @fire_up
        lda #1
        sta FIRE_HELD
        jmp @check_dir
@fire_up:
        lda #0
        sta FIRE_HELD

@check_dir:
        ; Default no direction
        lda #0
        sta PLAYER_DIR

        ; Up
        lda TEMP1
        and #$01
        bne @not_up
        lda #1
        sta PLAYER_DIR
        rts
@not_up:
        ; Down
        lda TEMP1
        and #$02
        bne @not_down
        lda #2
        sta PLAYER_DIR
        rts
@not_down:
        ; Left
        lda TEMP1
        and #$04
        bne @not_left
        lda #3
        sta PLAYER_DIR
        rts
@not_left:
        ; Right
        lda TEMP1
        and #$08
        bne @done
        lda #4
        sta PLAYER_DIR
@done:  rts

; ============================================================================
; UPDATE PLAYER - Core Qix Mechanics
; ============================================================================

UPDATE_PLAYER:
        ; Speed control - move every N frames
        inc PLAYER_SPEED
        lda PLAYER_SPEED
        cmp #3
        bcs @speed_ok
        jmp @no_move
@speed_ok:
        lda #0
        sta PLAYER_SPEED

        ; Need a direction to move
        lda PLAYER_DIR
        bne @has_dir
        jmp @no_move
@has_dir:

        ; Calculate target position
        lda PLAYER_X
        sta TEMP1           ; Target X
        lda PLAYER_Y
        sta TEMP2           ; Target Y

        lda PLAYER_DIR
        cmp #1
        bne @not_up
        dec TEMP2
        jmp @check_move
@not_up:
        cmp #2
        bne @not_down
        inc TEMP2
        jmp @check_move
@not_down:
        cmp #3
        bne @not_left
        dec TEMP1
        jmp @check_move
@not_left:
        cmp #4
        bne @skip_move
        inc TEMP1
        jmp @check_move
@skip_move:
        jmp @no_move

@check_move:
        ; Bounds check
        lda TEMP1
        cmp #FIELD_LEFT
        bcs @bound1_ok
        jmp @no_move
@bound1_ok:
        cmp #FIELD_RIGHT + 1
        bcc @bound2_ok
        jmp @no_move
@bound2_ok:
        lda TEMP2
        cmp #FIELD_TOP
        bcs @bound3_ok
        jmp @no_move
@bound3_ok:
        cmp #FIELD_BOTTOM + 1
        bcc @bounds_ok
        jmp @no_move
@bounds_ok:

        ; Get tile type at target
        ldx TEMP1
        ldy TEMP2
        jsr GET_TILE
        sta TEMP3           ; Target tile type

        ; Are we currently drawing?
        lda PLAYER_DRAWING
        bne @drawing_mode

        ; === NOT DRAWING MODE ===
        ; Can only move on border or previously drawn trail lines
        lda TEMP3
        cmp #CHAR_BORDER
        beq @can_move_edge
        cmp #CHAR_TRAIL_H
        beq @can_move_edge
        cmp #CHAR_TRAIL_V
        beq @can_move_edge
        cmp #CHAR_CORNER_LB
        beq @can_move_edge
        cmp #CHAR_CORNER_RB
        beq @can_move_edge
        cmp #CHAR_CORNER_LT
        beq @can_move_edge
        cmp #CHAR_CORNER_RT
        beq @can_move_edge

        ; Target is empty - can we start drawing?
        cmp #CHAR_EMPTY
        beq +
        jmp @no_move
+
        ; Can only enter empty if fire is held
        lda FIRE_HELD
        bne +
        jmp @no_move
+
        ; Start drawing!
        lda #1
        sta PLAYER_DRAWING
        lda PLAYER_X
        sta TRAIL_START_X
        lda PLAYER_Y
        sta TRAIL_START_Y
        lda #0
        sta TRAIL_COUNT
        sta PREV_DRAW_DIR       ; Reset previous direction for corners

        ; Play sound
        jsr SFX_START_DRAW

        ; Move into empty space WITHOUT drawing trail at border
        ; (don't overwrite the border tile with trail)
        lda TEMP1
        sta PLAYER_X
        lda TEMP2
        sta PLAYER_Y
        jmp @no_move

@can_move_edge:
        ; Moving along edge (not drawing)
        lda TEMP1
        sta PLAYER_X
        lda TEMP2
        sta PLAYER_Y
        jmp @no_move

        ; === DRAWING MODE ===
@drawing_mode:
        ; Check what we're moving into
        lda TEMP3
        cmp #CHAR_EMPTY
        beq @do_move_draw

        ; Check if moving into own trail (death!)
        cmp #CHAR_TRAIL_H
        beq @hit_own_trail
        cmp #CHAR_TRAIL_V
        beq @hit_own_trail
        cmp #CHAR_CORNER_LB
        beq @hit_own_trail
        cmp #CHAR_CORNER_RB
        beq @hit_own_trail
        cmp #CHAR_CORNER_LT
        beq @hit_own_trail
        cmp #CHAR_CORNER_RT
        beq @hit_own_trail

        ; Moving into border or claimed = complete the shape!
        cmp #CHAR_BORDER
        beq @complete_draw
        cmp #CHAR_CLAIMED
        beq @complete_draw

        ; Unknown tile, don't move
        jmp @no_move

@hit_own_trail:
        ; Check if this trail position is in current trail buffer
        ; If yes = death (hit current trail), if no = complete (hit old trail)
        ldx #0
@check_trail_loop:
        cpx TRAIL_COUNT
        bcs @hit_old_trail      ; Not in current buffer = old trail
        lda TRAIL_BUFFER_X, x
        cmp TEMP1
        bne @check_next
        lda TRAIL_BUFFER_Y, x
        cmp TEMP2
        beq @hit_current_trail  ; Found in current buffer = death
@check_next:
        inx
        jmp @check_trail_loop
@hit_current_trail:
        jsr PLAYER_DEATH
        jmp @no_move
@hit_old_trail:
        ; Old trail acts like border - complete the shape
        jmp @complete_draw

@do_move_draw:
        ; Move into empty space while drawing
        ; First, add current position to trail
        ldx TRAIL_COUNT
        cpx #250            ; Max trail length
        bcs @no_move        ; Trail too long!

        lda PLAYER_X
        sta TRAIL_BUFFER_X, x
        lda PLAYER_Y
        sta TRAIL_BUFFER_Y, x
        inc TRAIL_COUNT

        ; Save target position before drawing (CALC_SCREEN_ADDR corrupts TEMP1)
        lda TEMP1
        pha
        lda TEMP2
        pha

        ; Draw trail at current position
        ldx PLAYER_X
        ldy PLAYER_Y
        jsr DRAW_TRAIL_TILE

        ; Restore target position
        pla
        sta TEMP2
        pla
        sta TEMP1

        ; Move to new position
        lda TEMP1
        sta PLAYER_X
        lda TEMP2
        sta PLAYER_Y

        ; Play trail sound
        jsr SFX_TRAIL
        jmp @no_move

@complete_draw:
        ; First, add current position to trail (the tile BEFORE the border)
        ldx TRAIL_COUNT
        cpx #250
        bcs @skip_last_trail

        lda PLAYER_X
        sta TRAIL_BUFFER_X, x
        lda PLAYER_Y
        sta TRAIL_BUFFER_Y, x
        inc TRAIL_COUNT

        ; Draw trail at current position before moving
        ldx PLAYER_X
        ldy PLAYER_Y
        jsr DRAW_TRAIL_TILE

@skip_last_trail:
        ; Move to the edge
        lda TEMP1
        sta PLAYER_X
        lda TEMP2
        sta PLAYER_Y

        ; Complete the drawing - claim area!
        jsr COMPLETE_CLAIM

        ; No longer drawing
        lda #0
        sta PLAYER_DRAWING

        ; Play claim sound
        jsr SFX_CLAIM

@no_move:
        ; If fire released while drawing in empty area = death (classic Qix)
        lda PLAYER_DRAWING
        beq @done
        lda FIRE_HELD
        bne @done

        ; Check if we're on safe ground
        ldx PLAYER_X
        ldy PLAYER_Y
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @done
        cmp #CHAR_TRAIL_H
        beq @in_trail
        cmp #CHAR_TRAIL_V
        beq @in_trail
        cmp #CHAR_CORNER_LB
        beq @in_trail
        cmp #CHAR_CORNER_RB
        beq @in_trail
        cmp #CHAR_CORNER_LT
        beq @in_trail
        cmp #CHAR_CORNER_RT
        bne @done
@in_trail:

        ; Released fire in danger zone! (optional - remove for easier game)
        ; jsr PLAYER_DEATH

@done:  rts

; ============================================================================
; COMPLETE CLAIM - Flood fill to claim area
; ============================================================================

COMPLETE_CLAIM:
        ; Save Qix position NOW before it can move during fill phases
        ; This prevents race condition where Qix moves out of its area
        lda QIX_X
        sta FILL_QIX_X
        lda QIX_Y
        sta FILL_QIX_Y

        ; Start incremental fill state machine
        ; Phase 1 = trail conversion (done incrementally)
        lda #0
        sta FILL_INDEX      ; Start at first trail tile
        lda #1
        sta FILL_STATE      ; Phase 1 = trail conversion
        rts

; ============================================================================
; UPDATE_FILL - Incremental fill processing (called each frame during fill)
; ============================================================================

UPDATE_FILL:
        lda FILL_STATE
        cmp #1
        beq @do_trail
        cmp #2
        beq @do_flood
        cmp #3
        beq @do_claim
        cmp #4
        beq @do_restore
        cmp #5
        beq @do_calc
        ; Unknown state, reset
        lda #0
        sta FILL_STATE
        rts

@do_trail:
        jsr UPDATE_TRAIL_CONVERT
        rts
@do_flood:
        jsr UPDATE_FLOOD_FILL
        rts
@do_claim:
        jsr UPDATE_CLAIM_UNMARKED
        rts
@do_restore:
        jsr UPDATE_RESTORE_MARKED
        rts
@do_calc:
        jsr UPDATE_CALC_PERCENTAGE
        rts

; Incremental trail conversion - convert trail tiles to claimed
UPDATE_TRAIL_CONVERT:
        ldx #SCAN_OPS_PER_FRAME
@loop:
        ; Check if done with trail
        lda FILL_INDEX
        cmp TRAIL_COUNT
        bcs @trail_done

        ; Save iteration counter
        stx TEMP4

        ; Keep trail tile visible (don't convert to claimed)
        ldx FILL_INDEX
        ; Trail remains as trail character with gray color

        ; Next trail tile
        inc FILL_INDEX

        ; Restore and decrement iteration counter
        ldx TEMP4
        dex
        bne @loop
        rts

@trail_done:
        ; Clear trail count
        lda #0
        sta TRAIL_COUNT

        ; Initialize flood fill and move to phase 2
        jsr INIT_FLOOD_FROM_QIX
        lda #2
        sta FILL_STATE
        rts

; ============================================================================
; FINISH_FILL - Called when fill is complete
; ============================================================================

FINISH_FILL:
        ; Clear fill state
        lda #0
        sta FILL_STATE

        ; Advance fill color for next area
        inc FILL_COLOR_IDX
        lda FILL_COLOR_IDX
        and #$07            ; Wrap at 8 colors
        sta FILL_COLOR_IDX

        ; Only trigger level complete if still playing
        lda GAME_STATE
        cmp #1
        bne @not_done

        ; Check for level complete
        lda PERCENT_CLAIMED
        cmp TARGET_PERCENT
        bcc @not_done

        ; Level complete!
        lda #3
        sta GAME_STATE
        lda #120
        sta DEATH_TIMER

@not_done:
        rts

; Initialize flood fill from SAVED Qix position - sets up stack for incremental fill
; Uses FILL_QIX_X/Y (captured at claim start) to avoid race condition with moving Qix
INIT_FLOOD_FROM_QIX:
        lda #0
        sta FILL_STACK_PTR

        ; First check if saved Qix position is on empty tile
        ldx FILL_QIX_X
        ldy FILL_QIX_Y
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @qix_ok

        ; Saved position not on empty - search nearby for empty tile
        ; Check all 4 neighbors
        ldx FILL_QIX_X
        dex
        ldy FILL_QIX_Y
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @try_right
        ldx FILL_QIX_X
        dex
        ldy FILL_QIX_Y
        jmp @found_start

@try_right:
        ldx FILL_QIX_X
        inx
        ldy FILL_QIX_Y
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @try_up
        ldx FILL_QIX_X
        inx
        ldy FILL_QIX_Y
        jmp @found_start

@try_up:
        ldx FILL_QIX_X
        ldy FILL_QIX_Y
        dey
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @try_down
        ldx FILL_QIX_X
        ldy FILL_QIX_Y
        dey
        jmp @found_start

@try_down:
        ldx FILL_QIX_X
        ldy FILL_QIX_Y
        iny
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @done           ; No empty tile near saved Qix pos, claim all!
        ldx FILL_QIX_X
        ldy FILL_QIX_Y
        iny
        jmp @found_start

@qix_ok:
        ldx FILL_QIX_X
        ldy FILL_QIX_Y

@found_start:
        ; Save starting position
        stx SAVE_X
        sty SAVE_Y

        ; Mark starting position first (consistency with PUSH_IF_EMPTY)
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #$20
        sta (SCREEN_LO), y

        ; Push starting position
        ldx SAVE_X
        ldy SAVE_Y
        jsr PUSH_FILL

@done:  rts

; Incremental flood fill - process FILL_OPS_PER_FRAME stack operations per frame
UPDATE_FLOOD_FILL:
        ldx #FLOOD_OPS_PER_FRAME
@loop:
        ; Stack empty?
        lda FILL_STACK_PTR
        beq @flood_done

        ; Save iteration counter
        stx TEMP4

        ; Pop position (tile is already marked when it was pushed)
        jsr POP_FILL
        stx FLOOD_X         ; Save X coord
        sty FLOOD_Y         ; Save Y coord

        ; Push neighbors - only CHAR_EMPTY tiles (PUSH_IF_EMPTY marks them)

        ; Neighbor above (Y-1)
        ldx FLOOD_X
        ldy FLOOD_Y
        dey
        jsr PUSH_IF_EMPTY

        ; Neighbor below (Y+1)
        ldx FLOOD_X
        ldy FLOOD_Y
        iny
        jsr PUSH_IF_EMPTY

        ; Neighbor left (X-1)
        ldx FLOOD_X
        dex
        ldy FLOOD_Y
        jsr PUSH_IF_EMPTY

        ; Neighbor right (X+1)
        ldx FLOOD_X
        inx
        ldy FLOOD_Y
        jsr PUSH_IF_EMPTY

        ; Restore and decrement iteration counter
        ldx TEMP4
        dex
        bne @loop

        ; More work to do next frame
        rts

@flood_done:
        ; Flood fill complete, move to claim phase
        ; Initialize row/col for claim scan
        lda #FIELD_TOP + 1
        sta FILL_ROW
        lda #FIELD_LEFT + 1
        sta FILL_COL
        lda #3
        sta FILL_STATE
        rts

; Push tile at X,Y only if it's CHAR_EMPTY, and mark it immediately
; This prevents duplicate entries on the stack
PUSH_IF_EMPTY:
        ; Bounds check first
        cpx #FIELD_LEFT + 1
        bcc @skip_pie
        cpx #FIELD_RIGHT
        bcs @skip_pie
        cpy #FIELD_TOP + 1
        bcc @skip_pie
        cpy #FIELD_BOTTOM
        bcs @skip_pie

        ; Save coordinates
        stx SAVE_X
        sty SAVE_Y

        ; Check if tile is CHAR_EMPTY (not yet visited)
        jsr GET_TILE
        cmp #CHAR_EMPTY
        bne @skip_pie

        ; Mark it NOW (before pushing) to prevent any duplicates
        ldx SAVE_X
        ldy SAVE_Y
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #$20
        sta (SCREEN_LO), y

        ; Push it
        ldx SAVE_X
        ldy SAVE_Y
        jsr PUSH_FILL

@skip_pie:
        rts

PUSH_FILL:
        pha
        lda FILL_STACK_PTR
        cmp #250            ; Max stack (increased from 128)
        bcs @full

        txa
        ldx FILL_STACK_PTR
        sta FILL_STACK_X, x
        tya
        sta FILL_STACK_Y, x
        inc FILL_STACK_PTR
@full:  pla
        rts

POP_FILL:
        dec FILL_STACK_PTR
        ldx FILL_STACK_PTR
        lda FILL_STACK_X, x
        pha
        lda FILL_STACK_Y, x
        tay
        pla
        tax
        rts

; Incremental claim - process FILL_OPS_PER_FRAME tiles per frame
UPDATE_CLAIM_UNMARKED:
        ldx #SCAN_OPS_PER_FRAME
@loop:
        ; Save iteration counter
        stx TEMP4

        ; Get current position
        ldx FILL_COL
        ldy FILL_ROW
        stx SAVE_X
        sty SAVE_Y

        jsr CALC_SCREEN_ADDR
        ldy #0
        lda (SCREEN_LO), y

        ; If it's empty (not marked), claim it
        cmp #CHAR_EMPTY
        bne @skip

        ; Claim this tile
        lda #CHAR_CLAIMED
        sta (SCREEN_LO), y

        ; Color it based on fill index (different color per area)
        ldx FILL_COLOR_IDX
        lda CLAIM_COLORS, x
        ldy #0
        sta (COLOR_LO), y

        ; Add to score (BCD-style: each byte 0-99)
        inc SCORE_LO
        lda SCORE_LO
        cmp #100
        bcc @skip
        lda #0
        sta SCORE_LO
        inc SCORE_MID
        lda SCORE_MID
        cmp #100
        bcc @skip
        lda #0
        sta SCORE_MID
        inc SCORE_HI

@skip:
        ; Advance to next tile
        inc FILL_COL
        lda FILL_COL
        cmp #FIELD_RIGHT
        bcc @continue

        ; Next row
        lda #FIELD_LEFT + 1
        sta FILL_COL
        inc FILL_ROW
        lda FILL_ROW
        cmp #FIELD_BOTTOM
        bcc @continue

        ; Claim phase done, move to restore phase
        lda #FIELD_TOP + 1
        sta FILL_ROW
        lda #FIELD_LEFT + 1
        sta FILL_COL
        lda #4
        sta FILL_STATE
        rts

@continue:
        ; Restore and decrement iteration counter
        ldx TEMP4
        dex
        bne @loop
        rts

; Incremental restore - process FILL_OPS_PER_FRAME tiles per frame
UPDATE_RESTORE_MARKED:
        ldx #SCAN_OPS_PER_FRAME
@loop:
        ; Save iteration counter
        stx TEMP4

        ; Get current position
        ldx FILL_COL
        ldy FILL_ROW
        stx SAVE_X
        sty SAVE_Y

        jsr CALC_SCREEN_ADDR
        ldy #0
        lda (SCREEN_LO), y
        cmp #$20            ; Space marker
        bne @skip

        lda #CHAR_EMPTY
        sta (SCREEN_LO), y
        lda #COL_DGREY
        sta (COLOR_LO), y

@skip:
        ; Advance to next tile
        inc FILL_COL
        lda FILL_COL
        cmp #FIELD_RIGHT
        bcc @continue

        ; Next row
        lda #FIELD_LEFT + 1
        sta FILL_COL
        inc FILL_ROW
        lda FILL_ROW
        cmp #FIELD_BOTTOM
        bcc @continue

        ; Restore phase done, move to calc percentage phase
        ; Initialize counters
        lda #0
        sta CLAIMED_COUNT
        sta CLAIMED_COUNT_HI
        sta TOTAL_COUNT_LO
        sta TOTAL_COUNT_HI
        lda #FIELD_TOP + 1
        sta FILL_ROW
        lda #FIELD_LEFT + 1
        sta FILL_COL
        lda #5
        sta FILL_STATE
        rts

@continue:
        ; Restore and decrement iteration counter
        ldx TEMP4
        dex
        bne @loop
        rts

; Incremental calc percentage - process FILL_OPS_PER_FRAME tiles per frame
UPDATE_CALC_PERCENTAGE:
        ldx #SCAN_OPS_PER_FRAME
@loop:
        ; Save iteration counter
        stx TEMP4

        ; Get current position
        ldx FILL_COL
        ldy FILL_ROW
        stx SAVE_X
        sty SAVE_Y

        ; Increment total (16-bit)
        inc TOTAL_COUNT_LO
        bne @nc
        inc TOTAL_COUNT_HI
@nc:
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda (SCREEN_LO), y
        cmp #CHAR_CLAIMED
        beq @is_claimed
        cmp #CHAR_TRAIL_H       ; Also count drawn lines as claimed
        beq @is_claimed
        cmp #CHAR_TRAIL_V
        beq @is_claimed
        cmp #CHAR_CORNER_LB
        beq @is_claimed
        cmp #CHAR_CORNER_RB
        beq @is_claimed
        cmp #CHAR_CORNER_LT
        beq @is_claimed
        cmp #CHAR_CORNER_RT
        bne @not_claimed

@is_claimed:
        ; Increment claimed (16-bit)
        inc CLAIMED_COUNT
        bne @not_claimed
        inc CLAIMED_COUNT_HI

@not_claimed:
        ; Advance to next tile
        inc FILL_COL
        lda FILL_COL
        cmp #FIELD_RIGHT
        bcc @continue

        ; Next row
        lda #FIELD_LEFT + 1
        sta FILL_COL
        inc FILL_ROW
        lda FILL_ROW
        cmp #FIELD_BOTTOM
        bcc @continue

        ; Counting done - calculate final percentage
        jmp @finish_calc

@continue:
        ; Restore and decrement iteration counter
        ldx TEMP4
        dex
        bne @loop
        rts

@finish_calc:
        ; Calculate percentage: (claimed * 100) / total
        ; Simplified: claimed / 7 gives approximate percentage for 684 tiles
        ; Divide 16-bit claimed by 7 (approximate)
        ; Quick method: divide by 8 then add 1/8 of result
        lda CLAIMED_COUNT_HI    ; High byte
        sta TEMP4
        lda CLAIMED_COUNT       ; Low byte

        ; First divide by 8
        lsr TEMP4
        ror
        lsr TEMP4
        ror
        lsr TEMP4
        ror
        sta TEMP1               ; Result / 8

        ; Add result/8 to adjust (makes it closer to /7)
        lsr
        lsr
        lsr
        clc
        adc TEMP1

        ; Clamp to 99%
        cmp #100
        bcc @pct_ok
        lda #99
@pct_ok:
        sta PERCENT_CLAIMED

        jsr UPDATE_HUD

        ; Fill completely done - finish up
        jsr FINISH_FILL
        rts

; ============================================================================
; UPDATE QIX
; ============================================================================

UPDATE_QIX:
        ; Direction change timer
        dec QIX_TIMER
        bne @no_change

        ; Random new direction
        jsr RANDOM
        and #$3F
        clc
        adc #30
        sta QIX_TIMER

        jsr RANDOM
        and #$03
        tax
        lda QIX_DX_TBL, x
        sta QIX_DX
        lda QIX_DY_TBL, x
        sta QIX_DY

@no_change:
        ; Move every other frame
        lda FRAME_COUNT
        and #$01
        beq +
        jmp @done
+
        ; Calculate new position
        lda QIX_X
        clc
        adc QIX_DX
        sta TEMP1

        lda QIX_Y
        clc
        adc QIX_DY
        sta TEMP2

        ; Check bounds
        lda TEMP1
        cmp #FIELD_LEFT + 1
        bcc @bounce
        cmp #FIELD_RIGHT
        bcs @bounce
        lda TEMP2
        cmp #FIELD_TOP + 1
        bcc @bounce
        cmp #FIELD_BOTTOM
        bcs @bounce

        ; Check tile type (can only be in empty area)
        ldx TEMP1
        ldy TEMP2
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @move_ok
        cmp #$20            ; Marked empty is ok too
        beq @move_ok
        cmp #CHAR_TRAIL_H
        beq @hit_trail
        cmp #CHAR_TRAIL_V
        beq @hit_trail
        cmp #CHAR_CORNER_LB
        beq @hit_trail
        cmp #CHAR_CORNER_RB
        beq @hit_trail
        cmp #CHAR_CORNER_LT
        beq @hit_trail
        cmp #CHAR_CORNER_RT
        beq @hit_trail

        ; Hit wall or claimed - bounce
@bounce:
        ; Reverse direction
        lda QIX_DX
        eor #$FF
        clc
        adc #1
        sta QIX_DX

        lda QIX_DY
        eor #$FF
        clc
        adc #1
        sta QIX_DY

        jmp @done

@hit_trail:
        ; Qix hit trail - only death if it hits the CURRENT trail being drawn
        lda PLAYER_DRAWING
        beq @bounce             ; Not drawing = old trail, just bounce
        ; Check if this trail position is in current trail buffer
        ldx #0
@check_qix_trail:
        cpx TRAIL_COUNT
        bcs @bounce             ; Not in current buffer = old trail, bounce
        lda TRAIL_BUFFER_X, x
        cmp TEMP1
        bne @check_qix_next
        lda TRAIL_BUFFER_Y, x
        cmp TEMP2
        beq @qix_hit_current    ; Found in current buffer = death
@check_qix_next:
        inx
        jmp @check_qix_trail
@qix_hit_current:
        jsr PLAYER_DEATH        ; Only die if Qix hits current trail
        jmp @done

@move_ok:
        lda TEMP1
        sta QIX_X
        lda TEMP2
        sta QIX_Y

@done:
        ; Animate color
        lda FRAME_COUNT
        lsr
        lsr
        and #$07
        tax
        lda QIX_COLORS, x
        sta VIC_SPRITE_COL + 1
        rts

QIX_DX_TBL: !byte $FF, $01, $00, $00
QIX_DY_TBL: !byte $00, $00, $FF, $01
QIX_COLORS: !byte COL_RED, COL_ORANGE, COL_YELLOW, COL_PINK
            !byte COL_PURPLE, COL_LBLUE, COL_CYAN, COL_LGREEN

; ============================================================================
; UPDATE SPARX
; ============================================================================

UPDATE_SPARX:
        lda FRAME_COUNT
        and #$03
        bne @done

        ; Update Sparx 1
        ldx SPARX1_X
        ldy SPARX1_Y
        lda SPARX1_DIR
        jsr MOVE_SPARX
        stx SPARX1_X
        sty SPARX1_Y
        sta SPARX1_DIR

        ; Update Sparx 2
        ldx SPARX2_X
        ldy SPARX2_Y
        lda SPARX2_DIR
        jsr MOVE_SPARX
        stx SPARX2_X
        sty SPARX2_Y
        sta SPARX2_DIR

@done:  rts

; Move Sparx along edges
; Input: X=x, Y=y, A=direction (1=up,2=down,3=left,4=right)
; Output: X=new x, Y=new y, A=new direction
MOVE_SPARX:
        sta TEMP3           ; Save direction
        stx SAVE_X          ; Save original X
        sty SAVE_Y          ; Save original Y
        stx TEMP1           ; Working X
        sty TEMP2           ; Working Y

        ; Try to move in current direction
        lda TEMP3
        cmp #1
        beq @try_up
        cmp #2
        beq @try_down
        cmp #3
        beq @try_left
        cmp #4
        beq @try_right
        jmp @turn_cw        ; Invalid dir, turn

@try_up:
        dec TEMP2
        jmp @check

@try_down:
        inc TEMP2
        jmp @check

@try_left:
        dec TEMP1
        jmp @check

@try_right:
        inc TEMP1

@check:
        ; Bounds check
        lda TEMP1
        cmp #FIELD_LEFT
        bcc @turn_cw
        cmp #FIELD_RIGHT + 1
        bcs @turn_cw
        lda TEMP2
        cmp #FIELD_TOP
        bcc @turn_cw
        cmp #FIELD_BOTTOM + 1
        bcs @turn_cw

        ; Must stay on border or claimed edge
        ldx TEMP1
        ldy TEMP2
        jsr GET_TILE
        cmp #CHAR_BORDER
        beq @move_ok
        cmp #CHAR_CLAIMED
        beq @move_ok
        cmp #CHAR_TRAIL_H
        beq @move_ok
        cmp #CHAR_TRAIL_V
        beq @move_ok
        cmp #CHAR_CORNER_LB
        beq @move_ok
        cmp #CHAR_CORNER_RB
        beq @move_ok
        cmp #CHAR_CORNER_LT
        beq @move_ok
        cmp #CHAR_CORNER_RT
        beq @move_ok

        ; Not on edge, turn clockwise
@turn_cw:
        lda TEMP3
        cmp #1
        beq @turn_to_right
        cmp #4
        beq @turn_to_down
        cmp #2
        beq @turn_to_left
        ; Was left (3), turn up
        lda #1
        sta TEMP3
        jmp @return_orig
@turn_to_right:
        lda #4
        sta TEMP3
        jmp @return_orig
@turn_to_down:
        lda #2
        sta TEMP3
        jmp @return_orig
@turn_to_left:
        lda #3
        sta TEMP3

@return_orig:
        ; Return original position with new direction
        ldx SAVE_X
        ldy SAVE_Y
        lda TEMP3
        rts

@move_ok:
        ; Return new position with same direction
        ldx TEMP1
        ldy TEMP2
        lda TEMP3
        rts

; ============================================================================
; CHECK COLLISIONS
; ============================================================================

CHECK_COLLISIONS:
        ; Player vs Sparx 1
        lda PLAYER_X
        cmp SPARX1_X
        bne @no_s1
        lda PLAYER_Y
        cmp SPARX1_Y
        bne @no_s1
        jmp PLAYER_DEATH

@no_s1:
        ; Player vs Sparx 2
        lda PLAYER_X
        cmp SPARX2_X
        bne @no_s2
        lda PLAYER_Y
        cmp SPARX2_Y
        bne @no_s2
        jmp PLAYER_DEATH

@no_s2:
        ; Player vs Qix (within 1 tile when drawing)
        lda PLAYER_DRAWING
        beq @done

        lda PLAYER_X
        sec
        sbc QIX_X
        bcs @pos_x
        eor #$FF
        adc #1
@pos_x: cmp #2
        bcs @done

        lda PLAYER_Y
        sec
        sbc QIX_Y
        bcs @pos_y
        eor #$FF
        adc #1
@pos_y: cmp #2
        bcs @done

        jmp PLAYER_DEATH

@done:  rts

; ============================================================================
; PLAYER DEATH
; ============================================================================

PLAYER_DEATH:
        lda GAME_STATE
        cmp #1
        bne @done           ; Already dying

        lda #2
        sta GAME_STATE
        lda #60
        sta DEATH_TIMER

        ; Stop music for death sequence
        lda #0
        sta MUSIC_ENABLED
        sta SID_CTRL1
        sta SID_CTRL2
        sta SID_CTRL3

        ; Death sound
        lda #$10
        sta SID_FREQ_HI1
        lda #$81            ; Noise
        sta SID_CTRL1
        lda #$0F
        sta SID_AD1
        lda #$F0
        sta SID_SR1

@done:  rts

UPDATE_DYING:
        dec DEATH_TIMER
        bne @flash

        ; Death animation done
        dec LIVES
        bne @respawn

        ; Game over
        lda #4
        sta GAME_STATE
        jsr SHOW_GAME_OVER_MSG
        rts

@respawn:
        ; Clear active trail from screen (completed areas persist)
        jsr CLEAR_TRAIL

        ; Reset player
        lda #FIELD_LEFT
        sta PLAYER_X
        lda #13
        sta PLAYER_Y
        lda #0
        sta PLAYER_DRAWING
        sta TRAIL_COUNT
        sta FILL_STATE          ; Clear any in-progress fill operation

        ; Reset Qix position
        lda #20
        sta QIX_X
        lda #13
        sta QIX_Y

        lda #1
        sta GAME_STATE

        ; Restart the music
        jsr INIT_MUSIC

        jsr UPDATE_HUD
        rts

@flash:
        lda DEATH_TIMER
        and #$04
        beq @black
        lda #COL_RED
        sta VIC_BGCOLOR
        rts
@black:
        lda #COL_BLACK
        sta VIC_BGCOLOR
        rts

CLEAR_TRAIL:
        ; Only clear the current trail buffer, not all trails on screen
        ldx #0
@loop:  cpx TRAIL_COUNT
        beq @done
        stx SAVE_X              ; Save loop counter
        ; Get X,Y from trail buffer
        lda TRAIL_BUFFER_X, x
        sta SAVE_Y              ; Temporarily store column
        lda TRAIL_BUFFER_Y, x
        tay                     ; Y = row
        ldx SAVE_Y              ; X = column
        jsr CALC_SCREEN_ADDR
        ; Clear the trail tile
        ldy #0
        lda #CHAR_EMPTY
        sta (SCREEN_LO), y
        lda #COL_DGREY
        sta (COLOR_LO), y
        ; Next position
        ldx SAVE_X
        inx
        bne @loop               ; Loop until X wraps (max 255 entries)
@done:  rts

; ============================================================================
; UPDATE SPRITES
; ============================================================================

UPDATE_SPRITES:
        ; Clear MSB register
        lda #0
        sta VIC_SPRITE_MSB

        ; Player sprite (sprite 0)
        lda PLAYER_X
        jsr CALC_SPRITE_X
        sta VIC_SPRITE_X0
        bcc @p_no_msb
        lda VIC_SPRITE_MSB
        ora #$01
        sta VIC_SPRITE_MSB
@p_no_msb:
        lda PLAYER_Y
        asl
        asl
        asl
        clc
        adc #50             ; Standard C64 Y offset
        sta VIC_SPRITE_Y0

        ; Qix sprite (sprite 1)
        lda QIX_X
        jsr CALC_SPRITE_X
        sta VIC_SPRITE_X1
        bcc @q_no_msb
        lda VIC_SPRITE_MSB
        ora #$02
        sta VIC_SPRITE_MSB
@q_no_msb:
        lda QIX_Y
        asl
        asl
        asl
        clc
        adc #50             ; Standard C64 Y offset
        sta VIC_SPRITE_Y1

        ; Sparx 1 sprite (sprite 2)
        lda SPARX1_X
        jsr CALC_SPRITE_X
        sta VIC_SPRITE_X2
        bcc @s1_no_msb
        lda VIC_SPRITE_MSB
        ora #$04
        sta VIC_SPRITE_MSB
@s1_no_msb:
        lda SPARX1_Y
        asl
        asl
        asl
        clc
        adc #50             ; Standard C64 Y offset
        sta VIC_SPRITE_Y2

        ; Sparx 2 sprite (sprite 3)
        lda SPARX2_X
        jsr CALC_SPRITE_X
        sta VIC_SPRITE_X3
        bcc @s2_no_msb
        lda VIC_SPRITE_MSB
        ora #$08
        sta VIC_SPRITE_MSB
@s2_no_msb:
        lda SPARX2_Y
        asl
        asl
        asl
        clc
        adc #50             ; Standard C64 Y offset
        sta VIC_SPRITE_Y3

        ; Player color flash when drawing
        lda PLAYER_DRAWING
        beq @normal
        lda FRAME_COUNT
        and #$04
        beq @white
        lda #COL_CYAN
        sta VIC_SPRITE_COL
        rts
@white:
        lda #COL_WHITE
        sta VIC_SPRITE_COL
        rts
@normal:
        lda #COL_CYAN
        sta VIC_SPRITE_COL
        rts

; Calculate sprite X position from tile X
; Input: A = tile X
; Output: A = pixel X (low byte), carry = MSB needed
; C64 standard: sprite X = char_column * 8 + 24
CALC_SPRITE_X:
        ; Multiply by 8
        asl
        asl
        asl                 ; A = tile * 8 (low byte), carry if overflow
        sta TEMP1           ; Save multiplied value
        lda #0
        rol                 ; A = MSB from multiply (0 or 1)
        sta TEMP2           ; Save MSB

        ; Add offset 24
        lda TEMP1
        clc
        adc #24             ; Add screen offset
        sta TEMP1
        lda TEMP2
        adc #0              ; Add carry to MSB

        ; Set carry if MSB needed
        lsr                 ; Shift MSB bit into carry
        lda TEMP1           ; Return low byte in A
        rts

; ============================================================================
; ANIMATE COLORS
; ============================================================================

ANIMATE_COLORS:
        ; Keep border black at all times
        lda #COL_BLACK
        sta VIC_BORDER
        rts

BORDER_COLORS:
        !byte COL_BLUE, COL_BLUE, COL_LBLUE, COL_CYAN
        !byte COL_LBLUE, COL_BLUE, COL_BLUE, COL_PURPLE

; ============================================================================
; LEVEL COMPLETE
; ============================================================================

UPDATE_LEVEL_DONE:
        dec DEATH_TIMER
        bne @anim

        ; Next level
        inc LEVEL
        lda LEVEL
        cmp #10
        bcc @ok
        lda #1
        sta LEVEL
@ok:
        ; Harder target
        lda TARGET_PERCENT
        clc
        adc #2
        cmp #90
        bcc @pct_ok
        lda #90
@pct_ok:
        sta TARGET_PERCENT

        jsr INIT_LEVEL

        lda #1
        sta GAME_STATE
        rts

@anim:
        ; Keep border black
        lda #COL_BLACK
        sta VIC_BORDER
        rts

; ============================================================================
; GAME OVER
; ============================================================================

SHOW_GAME_OVER_MSG:
        jsr INIT_SAD_MUSIC      ; Start sad music for game over
        ldx #0
@lp:    lda GAMEOVER_TXT, x
        beq @done
        sta SCREEN_RAM + 494, x
        lda #COL_RED
        sta COLOR_RAM + 494, x
        inx
        bne @lp
@done:  rts

UPDATE_GAME_OVER:
        ; Flash text
        lda FRAME_COUNT
        and #$07
        tax
        lda CYCLE_COLORS, x
        ldx #10
@col:   sta COLOR_RAM + 494, x
        dex
        bpl @col

        ; Check fire
        lda CIA1_PORTA
        and #$10
        bne @done

        jsr START_NEW_GAME
@done:  rts

; ============================================================================
; SOUND EFFECTS
; ============================================================================

SFX_START_DRAW:
        lda #$30
        sta SID_FREQ_LO1
        lda #$08
        sta SID_FREQ_HI1
        lda #$11
        sta SID_CTRL1
        lda #$09
        sta SID_AD1
        lda #$00
        sta SID_SR1
        rts

SFX_TRAIL:
        lda TRAIL_COUNT
        asl
        clc
        adc #$80
        sta SID_FREQ_LO1
        lda #$04
        sta SID_FREQ_HI1
        lda #$41            ; Pulse
        sta SID_CTRL1
        lda #$00
        sta SID_AD1
        sta SID_SR1
        rts

SFX_CLAIM:
        lda #$00
        sta SID_FREQ_LO1
        lda #$15
        sta SID_FREQ_HI1
        lda #$21
        sta SID_CTRL1
        lda #$09
        sta SID_AD1
        lda #$00
        sta SID_SR1
        rts

; ============================================================================
; RANDOM NUMBER
; ============================================================================

RANDOM:
        lda RNG_SEED
        asl
        bcc @no_eor
        eor #$1D
@no_eor:
        sta RNG_SEED
        rts

; ============================================================================
; MIAMI VICE STYLE MUSIC ENGINE
; ============================================================================
; Authentic Jan Hammer sound - E minor, driving bass, synth lead
; All three SID voices for that iconic 80s TV soundtrack feel

INIT_MUSIC:
        ; Reset music state
        lda #0
        sta MUSIC_TIMER
        sta MUSIC_POS
        sta BASS_NOTE
        sta LEAD_NOTE
        sta ARP_NOTE
        sta ARP_POS
        sta MUSIC_MODE          ; Normal music mode
        lda #1
        sta MUSIC_ENABLED

        ; Voice 1: Deep driving bass - sawtooth for punch
        lda #$00
        sta SID_PW_LO1
        lda #$08
        sta SID_PW_HI1
        lda #$00            ; Attack=0, Decay=0 - instant punch
        sta SID_AD1
        lda #$F0            ; Sustain=15, Release=0 - full sustain
        sta SID_SR1

        ; Voice 2: Synth lead - pulse wave with PWM feel
        lda #$00
        sta SID_PW_LO2
        lda #$08            ; 50% pulse width - full sound
        sta SID_PW_HI2
        lda #$0A            ; Attack=0, Decay=10
        sta SID_AD2
        lda #$A0            ; Sustain=10, Release=0
        sta SID_SR2

        ; Voice 3: Synth pad/arpeggio - triangle for warmth
        lda #$09            ; Attack=0, Decay=9
        sta SID_AD3
        lda #$80            ; Sustain=8, Release=0
        sta SID_SR3

        ; Filter - lowpass for warm bass-heavy sound
        lda #$00
        sta SID_FILT_LO
        lda #$30            ; Lower cutoff for warmth
        sta SID_FILT_HI
        lda #$71            ; Filter voice 1 only + resonance
        sta SID_FILT_CTRL
        lda #$1F            ; Lowpass + max volume
        sta SID_VOLUME

        rts

UPDATE_MUSIC:
        lda MUSIC_ENABLED
        bne @enabled
        rts
@enabled:
        ; Check if sad music mode
        lda MUSIC_MODE
        beq @normal_music
        jmp UPDATE_SAD_MUSIC
@normal_music:
        ; Tempo control - every 6 frames (~8 Hz)
        inc MUSIC_TIMER
        lda MUSIC_TIMER
        cmp #6
        bcc @do_arp
        lda #0
        sta MUSIC_TIMER

        ; === BASS LINE (Voice 1) ===
        ldx MUSIC_POS
        lda BASS_PATTERN, x
        cmp #$FF
        beq @bass_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO1
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI1
        lda #$21            ; Gate on, sawtooth for punchy bass
        sta SID_CTRL1
        jmp @do_lead

@bass_off:
        lda #$20            ; Gate off
        sta SID_CTRL1

@do_lead:
        ; === LEAD MELODY (Voice 2) ===
        ldx MUSIC_POS
        lda LEAD_PATTERN, x
        cmp #$FF
        beq @lead_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO2
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI2
        lda #$41            ; Gate on, pulse wave
        sta SID_CTRL2
        jmp @do_pad

@lead_off:
        lda #$40            ; Gate off
        sta SID_CTRL2

@do_pad:
        ; === PAD/CHORD (Voice 3) ===
        ldx MUSIC_POS
        lda PAD_PATTERN, x
        cmp #$FF
        beq @pad_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO3
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI3
        lda #$11            ; Gate on, triangle for warm pad
        sta SID_CTRL3
        jmp @advance

@pad_off:
        lda #$10            ; Gate off
        sta SID_CTRL3

@advance:
        ; Advance pattern position
        inc MUSIC_POS
        lda MUSIC_POS
        cmp #32             ; 32-step pattern
        bcc @done
        lda #0
        sta MUSIC_POS
        jmp @done

@do_arp:
        ; Arpeggio runs between main beats for shimmer
        lda MUSIC_TIMER
        cmp #3
        bne @done

        ; Quick arpeggio note change on voice 3
        ldx MUSIC_POS
        lda ARP_PATTERN, x
        cmp #$FF
        beq @done

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO3
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI3
        lda #$11            ; Triangle wave
        sta SID_CTRL3

@done:
        rts

; === SAD MUSIC UPDATE ===
; Slower tempo, softer waveforms, melancholic patterns
UPDATE_SAD_MUSIC:
        ; Slower tempo - every 12 frames (~4 Hz) for sadness
        inc MUSIC_TIMER
        lda MUSIC_TIMER
        cmp #12
        bcc @sad_done
        lda #0
        sta MUSIC_TIMER

        ; === SAD BASS (Voice 1) ===
        ldx MUSIC_POS
        lda SAD_BASS_PATTERN, x
        cmp #$FF
        beq @sad_bass_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO1
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI1
        lda #$11            ; Gate on, triangle for soft bass
        sta SID_CTRL1
        jmp @sad_do_lead

@sad_bass_off:
        lda #$10            ; Gate off
        sta SID_CTRL1

@sad_do_lead:
        ; === SAD LEAD (Voice 2) ===
        ldx MUSIC_POS
        lda SAD_LEAD_PATTERN, x
        cmp #$FF
        beq @sad_lead_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO2
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI2
        lda #$11            ; Gate on, triangle for weeping lead
        sta SID_CTRL2
        jmp @sad_do_pad

@sad_lead_off:
        lda #$10            ; Gate off
        sta SID_CTRL2

@sad_do_pad:
        ; === SAD PAD (Voice 3) ===
        ldx MUSIC_POS
        lda SAD_PAD_PATTERN, x
        cmp #$FF
        beq @sad_pad_off

        tay
        lda NOTE_FREQ_LO, y
        sta SID_FREQ_LO3
        lda NOTE_FREQ_HI, y
        sta SID_FREQ_HI3
        lda #$11            ; Gate on, triangle
        sta SID_CTRL3
        jmp @sad_advance

@sad_pad_off:
        lda #$10            ; Gate off
        sta SID_CTRL3

@sad_advance:
        ; Advance pattern position
        inc MUSIC_POS
        lda MUSIC_POS
        cmp #32             ; 32-step pattern
        bcc @sad_done
        lda #0
        sta MUSIC_POS

@sad_done:
        rts

STOP_MUSIC:
        lda #0
        sta MUSIC_ENABLED
        sta SID_CTRL1
        sta SID_CTRL2
        sta SID_CTRL3
        rts

; ============================================================================
; SAD MUSIC FOR GAME OVER
; ============================================================================
; Slow, melancholic tune when all lives are lost

INIT_SAD_MUSIC:
        ; Reset music state
        lda #0
        sta MUSIC_TIMER
        sta MUSIC_POS
        sta BASS_NOTE
        sta LEAD_NOTE
        sta ARP_NOTE
        sta ARP_POS
        lda #1
        sta MUSIC_MODE          ; Sad music mode
        sta MUSIC_ENABLED

        ; Voice 1: Slow bass - triangle for softness
        lda #$00
        sta SID_PW_LO1
        lda #$08
        sta SID_PW_HI1
        lda #$4A            ; Attack=4, Decay=10 - slow attack
        sta SID_AD1
        lda #$40            ; Sustain=4, Release=0 - quiet sustain
        sta SID_SR1

        ; Voice 2: Sad lead - triangle for warmth
        lda #$00
        sta SID_PW_LO2
        lda #$08
        sta SID_PW_HI2
        lda #$6C            ; Attack=6, Decay=12 - very slow
        sta SID_AD2
        lda #$60            ; Sustain=6, Release=0
        sta SID_SR2

        ; Voice 3: Pad - triangle for atmosphere
        lda #$8F            ; Attack=8, Decay=15 - slowest
        sta SID_AD3
        lda #$30            ; Sustain=3, Release=0 - quiet
        sta SID_SR3

        ; Filter - lowpass, very low cutoff for muffled sad sound
        lda #$00
        sta SID_FILT_LO
        lda #$20            ; Very low cutoff
        sta SID_FILT_HI
        lda #$73            ; Filter voices 1,2 + resonance
        sta SID_FILT_CTRL
        lda #$1C            ; Lowpass + reduced volume
        sta SID_VOLUME

        rts

; ============================================================================
; NOTE FREQUENCY TABLE - PAL C64 (985248 Hz)
; ============================================================================
; Formula: value = (Hz * 16777216) / 985248
; Covers E1 to E4 for bass through lead range

NOTE_FREQ_LO:
        ; Octave 1 (deep bass) - notes 0-11
        !byte $17           ; 0:  E1  (41.2 Hz) - $0217
        !byte $30           ; 1:  F1  (43.7 Hz) - $0230
        !byte $4B           ; 2:  F#1 (46.2 Hz) - $024B
        !byte $68           ; 3:  G1  (49.0 Hz) - $0268
        !byte $88           ; 4:  G#1 (51.9 Hz) - $0288
        !byte $AB           ; 5:  A1  (55.0 Hz) - $02AB
        !byte $D0           ; 6:  A#1 (58.3 Hz) - $02D0
        !byte $F8           ; 7:  B1  (61.7 Hz) - $02F8
        !byte $24           ; 8:  C2  (65.4 Hz) - $0324
        !byte $52           ; 9:  C#2 (69.3 Hz) - $0352
        !byte $85           ; 10: D2  (73.4 Hz) - $0385
        !byte $BB           ; 11: D#2 (77.8 Hz) - $03BB

        ; Octave 2 (bass) - notes 12-23
        !byte $F5           ; 12: E2  (82.4 Hz) - $03F5
        !byte $34           ; 13: F2  (87.3 Hz) - $0434
        !byte $78           ; 14: F#2 (92.5 Hz) - $0478
        !byte $C1           ; 15: G2  (98.0 Hz) - $04C1
        !byte $0F           ; 16: G#2 (103.8 Hz)- $050F
        !byte $63           ; 17: A2  (110 Hz)  - $0563
        !byte $BD           ; 18: A#2 (116.5 Hz)- $05BD
        !byte $1E           ; 19: B2  (123.5 Hz)- $061E
        !byte $86           ; 20: C3  (130.8 Hz)- $0686
        !byte $F6           ; 21: C#3 (138.6 Hz)- $06F6
        !byte $6E           ; 22: D3  (146.8 Hz)- $076E
        !byte $F0           ; 23: D#3 (155.6 Hz)- $07F0

        ; Octave 3 (mid) - notes 24-35
        !byte $7B           ; 24: E3  (164.8 Hz)- $087B
        !byte $10           ; 25: F3  (174.6 Hz)- $0910
        !byte $B0           ; 26: F#3 (185.0 Hz)- $09B0
        !byte $5B           ; 27: G3  (196.0 Hz)- $0A5B
        !byte $13           ; 28: G#3 (207.7 Hz)- $0B13
        !byte $D8           ; 29: A3  (220 Hz)  - $0BD8
        !byte $AB           ; 30: A#3 (233.1 Hz)- $0CAB
        !byte $8D           ; 31: B3  (246.9 Hz)- $0D8D
        !byte $7F           ; 32: C4  (261.6 Hz)- $0E7F
        !byte $82           ; 33: C#4 (277.2 Hz)- $0F82
        !byte $98           ; 34: D4  (293.7 Hz)- $1098
        !byte $C2           ; 35: D#4 (311.1 Hz)- $11C2

        ; Octave 4 (lead) - notes 36-47
        !byte $02           ; 36: E4  (329.6 Hz)- $1302
        !byte $5A           ; 37: F4  (349.2 Hz)- $145A
        !byte $CC           ; 38: F#4 (370.0 Hz)- $15CC
        !byte $5A           ; 39: G4  (392.0 Hz)- $175A
        !byte $06           ; 40: G#4 (415.3 Hz)- $1906
        !byte $D2           ; 41: A4  (440 Hz)  - $1AD2
        !byte $C2           ; 42: A#4 (466.2 Hz)- $1CC2
        !byte $D6           ; 43: B4  (493.9 Hz)- $1ED6

NOTE_FREQ_HI:
        ; Octave 1
        !byte $02           ; E1
        !byte $02           ; F1
        !byte $02           ; F#1
        !byte $02           ; G1
        !byte $02           ; G#1
        !byte $02           ; A1
        !byte $02           ; A#1
        !byte $02           ; B1
        !byte $03           ; C2
        !byte $03           ; C#2
        !byte $03           ; D2
        !byte $03           ; D#2

        ; Octave 2
        !byte $03           ; E2
        !byte $04           ; F2
        !byte $04           ; F#2
        !byte $04           ; G2
        !byte $05           ; G#2
        !byte $05           ; A2
        !byte $05           ; A#2
        !byte $06           ; B2
        !byte $06           ; C3
        !byte $06           ; C#3
        !byte $07           ; D3
        !byte $07           ; D#3

        ; Octave 3
        !byte $08           ; E3
        !byte $09           ; F3
        !byte $09           ; F#3
        !byte $0A           ; G3
        !byte $0B           ; G#3
        !byte $0B           ; A3
        !byte $0C           ; A#3
        !byte $0D           ; B3
        !byte $0E           ; C4
        !byte $0F           ; C#4
        !byte $10           ; D4
        !byte $11           ; D#4

        ; Octave 4
        !byte $13           ; E4
        !byte $14           ; F4
        !byte $15           ; F#4
        !byte $17           ; G4
        !byte $19           ; G#4
        !byte $1A           ; A4
        !byte $1C           ; A#4
        !byte $1E           ; B4

; ============================================================================
; MUSIC PATTERNS - Jan Hammer / Miami Vice Style
; ============================================================================
; Key of E minor - the Miami Vice key
; Pattern is 32 steps, tempo ~8 Hz = 4 second loop

; Bass pattern - driving 8th notes with octave jumps
; Uses notes: 0=E1, 12=E2, 24=E3, 15=G2, 17=A2, 19=B2
BASS_PATTERN:
        ; E minor groove (bars 1-2)
        !byte 12, 12, 0, 12     ; E2-E2-E1-E2 (driving)
        !byte 12, 0, 12, 19     ; E2-E1-E2-B2
        !byte 12, 12, 0, 12     ; E2-E2-E1-E2
        !byte 19, 17, 15, 12    ; B2-A2-G2-E2 (walkdown)
        ; Variation (bars 3-4)
        !byte 12, 12, 24, 12    ; E2-E2-E3-E2 (octave up)
        !byte 12, 24, 12, 19    ; E2-E3-E2-B2
        !byte 17, 17, 15, 17    ; A2-A2-G2-A2
        !byte 19, 17, 15, 12    ; B2-A2-G2-E2 (resolve)

; Lead melody - soaring Jan Hammer style
; Uses notes: 24=E3, 27=G3, 29=A3, 31=B3, 36=E4, 39=G4
LEAD_PATTERN:
        ; Phrase 1 - building (bars 1-2)
        !byte $FF, $FF, 24, 27  ; rest-rest-E3-G3
        !byte 29, 27, 24, $FF   ; A3-G3-E3-rest
        !byte $FF, 24, 27, 29   ; rest-E3-G3-A3
        !byte 31, 29, 27, 24    ; B3-A3-G3-E3
        ; Phrase 2 - soaring (bars 3-4)
        !byte 36, $FF, 36, 39   ; E4-rest-E4-G4
        !byte 36, 31, 29, 27    ; E4-B3-A3-G3
        !byte 29, $FF, 27, 29   ; A3-rest-G3-A3
        !byte 31, 29, 27, 24    ; B3-A3-G3-E3

; Pad/chord pattern - sustained notes for atmosphere
; Uses notes: 24=E3, 27=G3, 31=B3 (E minor chord tones)
PAD_PATTERN:
        ; E minor chord sustained
        !byte 24, 24, 24, 24    ; E3 sustained
        !byte 27, 27, 27, 27    ; G3
        !byte 31, 31, 31, 31    ; B3
        !byte 27, 27, 24, 24    ; G3-E3
        ; Second half
        !byte 24, 24, 24, 24    ; E3
        !byte 31, 31, 31, 31    ; B3
        !byte 29, 29, 29, 29    ; A3
        !byte 27, 27, 24, 24    ; G3-E3

; Arpeggio pattern - plays between main beats
; E minor arpeggio: E-G-B
ARP_PATTERN:
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4
        !byte 36, 41, 43, 41    ; E4-A4-B4-A4
        !byte 36, 41, 43, 41    ; E4-A4-B4-A4
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4
        !byte 36, 39, 43, 39    ; E4-G4-B4-G4

; ============================================================================
; SAD MUSIC PATTERNS - Game Over
; ============================================================================
; Slow, melancholic descending melody in E minor
; Sparse bass, weeping lead, sustained pads

; Sad bass - sparse, low, slow
SAD_BASS_PATTERN:
        !byte 0, $FF, $FF, $FF     ; E1 - rest - rest - rest
        !byte $FF, $FF, 0, $FF     ; rest - rest - E1 - rest
        !byte 3, $FF, $FF, $FF     ; G1 - rest - rest - rest
        !byte $FF, $FF, 0, $FF     ; rest - rest - E1 - rest
        !byte 0, $FF, $FF, $FF     ; E1 - rest - rest - rest
        !byte 5, $FF, $FF, $FF     ; A1 - rest - rest - rest
        !byte 3, $FF, $FF, $FF     ; G1 - rest - rest - rest
        !byte 0, $FF, $FF, $FF     ; E1 - long hold

; Sad lead - slow descending melody, very sparse
SAD_LEAD_PATTERN:
        !byte 31, $FF, $FF, $FF    ; B3 - rest - rest - rest
        !byte 29, $FF, $FF, $FF    ; A3 - rest - rest - rest
        !byte 27, $FF, $FF, $FF    ; G3 - rest - rest - rest
        !byte 24, $FF, $FF, $FF    ; E3 - rest - rest - rest
        !byte 27, $FF, $FF, $FF    ; G3 - rest - rest - rest
        !byte 24, $FF, $FF, $FF    ; E3 - rest - rest - rest
        !byte 22, $FF, $FF, $FF    ; D3 - rest - rest - rest
        !byte 24, $FF, $FF, $FF    ; E3 - long final note

; Sad pad - sustained minor chord tones
SAD_PAD_PATTERN:
        !byte 12, 12, 12, 12       ; E2 sustained
        !byte 12, 12, 12, 12       ; E2 sustained
        !byte 15, 15, 15, 15       ; G2 sustained
        !byte 15, 15, 15, 15       ; G2 sustained
        !byte 12, 12, 12, 12       ; E2 sustained
        !byte 17, 17, 17, 17       ; A2 sustained
        !byte 15, 15, 15, 15       ; G2 sustained
        !byte 12, 12, 12, 12       ; E2 final

; Sad arpeggio - no arpeggio, just silence for sadness
SAD_ARP_PATTERN:
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence
        !byte $FF, $FF, $FF, $FF   ; silence

; ============================================================================
; DATA
; ============================================================================

TITLE_TXT:
        !scr "  qixy  "
        !byte 0

SUBTITLE_TXT:
        !scr "    a qix clone for c64    "
        !byte 0

CONTROLS_TXT:
        !scr "   joystick port 2 to move   "
        !byte 0

HOWTO1_TXT:
        !scr "hold fire + move to draw lines"
        !byte 0

HOWTO2_TXT:
        !scr "  claim 75% of area to win!  "
        !byte 0

START_TXT:
        !scr "   press fire to start   "
        !byte 0

SCORE_TXT:
        !scr "score:"
        !byte 0

LIVES_TXT:
        !scr "lives:"
        !byte 0

LEVEL_TXT:
        !scr "lvl:"
        !byte 0

PCT_TXT:
        !scr " "
        !byte 0

GAMEOVER_TXT:
        !scr "game over!"
        !byte 0

PAUSED_TXT:
        !scr "paused"
        !byte 0

CYCLE_COLORS:
        !byte COL_CYAN, COL_LBLUE, COL_PURPLE, COL_PINK
        !byte COL_RED, COL_ORANGE, COL_YELLOW, COL_LGREEN

CLAIM_COLORS:
        !byte COL_CYAN, COL_PURPLE, COL_GREEN, COL_YELLOW
        !byte COL_PINK, COL_LBLUE, COL_ORANGE, COL_LGREEN

; ============================================================================
; TITLE SCREEN BITMAP DATA
; ============================================================================

!source "title_data.asm"

; ============================================================================
; END
; ============================================================================
