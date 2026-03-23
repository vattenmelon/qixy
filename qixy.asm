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
GAME_STATE      = $1C       ; 0=title, 1=playing, 2=dying, 3=level_complete, 4=game_over, 5=hiscore_entry, 6=hiscore_show
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

; High score entry variables
HS_NAME_POS     = $44       ; Current cursor position in name (0-7)
HS_ENTRY_IDX    = $45       ; Which high score slot we're entering (0-4)
HS_BLINK_TMR    = $46       ; Cursor blink timer
LAST_KEY        = $47       ; Last key pressed (for debounce)
KEY_DELAY       = $48       ; Key repeat delay counter
SAVE_ADDR       = $49       ; 2 bytes: pointer for KERNAL SAVE routine

; Bitmap line drawing variables
LINE_X1         = $4B       ; Line start X (0-319) - 16-bit
LINE_X1_HI      = $4C
LINE_Y1         = $4D       ; Line start Y (0-199)
LINE_X2         = $4E       ; Line end X - 16-bit
LINE_X2_HI      = $4F
LINE_Y2         = $50       ; Line end Y
LINE_DX         = $51       ; Delta X (16-bit)
LINE_DX_HI      = $52
LINE_DY         = $53       ; Delta Y
LINE_SX         = $54       ; Step X direction (-1 or 1)
LINE_SY         = $55       ; Step Y direction (-1 or 1)
LINE_ERR        = $56       ; Error term (16-bit, signed)
LINE_ERR_HI     = $57
LINE_CUR_X      = $58       ; Current X (16-bit)
LINE_CUR_X_HI   = $59
LINE_CUR_Y      = $5A       ; Current Y
PREV_TRAIL_X    = $5B       ; Previous trail char X (for line segments)
PREV_TRAIL_Y    = $5C       ; Previous trail char Y
BITMAP_PTR      = $5D       ; Bitmap pointer (16-bit)
BITMAP_PTR_HI   = $5E
CHAR_PTR        = $5F       ; Pointer to charset data (16-bit)
CHAR_PTR_HI     = $60
STRING_PTR      = $61       ; Pointer to string data (16-bit)
STRING_PTR_HI   = $62
GRACE_TIMER     = $63       ; Post-claim invincibility timer (frames)
PREV_PERCENT    = $64       ; Percentage before current claim (for extra life check)

; Qix speed control (not in zero page to avoid KERNAL/BASIC conflicts)
QIX_SPEED       = $C5F0     ; Frame divisor for Qix movement (higher = slower)

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

; High score table: 5 entries x 12 bytes each = 60 bytes
; Each entry: 8 bytes name + 3 bytes score (LO/MID/HI) + 1 byte level
; NOTE: Must be placed AFTER FIELD_STATE which ends at $C568 ($C180 + 1000)
HISCORE_TABLE   = $C600     ; 60 bytes for 5 high scores
HISCORE_NAME    = $C600     ; Names start here (8 bytes each, entries 12 apart)
HISCORE_SCORE   = $C608     ; Scores (3 bytes each, entries 12 apart)
HISCORE_LEVEL   = $C60B     ; Levels (1 byte each, entries 12 apart)
HUD_BUF         = $C640     ; 80 bytes: 2 rows x 40 cols of screen codes
HUD_COLOR       = $C690     ; 80 bytes: color for each cell
ENTRY_NAME      = $C63C     ; 8 bytes for current name entry buffer

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
CIA1_DDRA       = $DC02     ; Data direction register A
CIA1_DDRB       = $DC03     ; Data direction register B
CIA2_PORTA      = $DD00     ; VIC bank selection

VIC_MEMPTR      = $D018     ; Alias for VIC_MEMSETUP

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
        jsr INIT_HISCORE_TABLE  ; Initialize high score table
        jsr LOAD_HISCORES       ; Try to load saved high scores from disk
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
        cmp #5
        beq @hs_entry
        cmp #6
        beq @hs_show
        jmp MAIN_LOOP

@title:
        jsr UPDATE_TITLE
        jmp MAIN_LOOP

@hs_entry:
        jsr UPDATE_HISCORE_ENTRY
        jmp MAIN_LOOP

@hs_show:
        jsr UPDATE_HISCORE_SHOW
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
        ; Decrement grace timer if active
        lda GRACE_TIMER
        beq @no_grace_dec
        dec GRACE_TIMER
@no_grace_dec:
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

        ; Colors - Neon synthwave palette
        lda #COL_LGREEN         ; Player - bright green
        sta VIC_SPRITE_COL + 0
        lda #COL_RED            ; Qix - stays red (menacing)
        sta VIC_SPRITE_COL + 1
        lda #COL_WHITE          ; Sparx 1 - white for visibility
        sta VIC_SPRITE_COL + 2
        lda #COL_YELLOW         ; Sparx 2 - yellow
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
        and #%11111100          ; Clear bank bits first
        ora #%00000011          ; Bank 0 (bits = 11)
        sta CIA2_PORTA

        ; Set text mode explicitly (standard C64 values)
        lda #$1B                ; Text mode, display on, 25 rows
        sta VIC_CTRL1
        lda #$C8                ; 40 columns, no multicolor
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
        ; Switch to hires bitmap mode for gameplay
        jsr INIT_SPRITES        ; Initialize sprites in Bank 0 first
        jsr ENABLE_HIRES_BITMAP_MODE
        jsr CLEAR_GAMEPLAY_BITMAP
        jsr COPY_SPRITES_TO_BANK1

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
        lda #120            ; 2 second grace period at start (~60fps)
        sta GRACE_TIMER

        lda #$FF
        sta PREV_TRAIL_X        ; Initialize for line drawing

        lda #3
        sta LIVES
        lda #1
        sta LEVEL
        lda #75
        sta TARGET_PERCENT
        lda #6
        sta QIX_SPEED

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

        ; Fill interior with empty (black in bitmap)
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
        ; Update character map (for game logic)
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_BORDER
        sta (SCREEN_LO), y
        lda #COL_CYAN           ; Neon cyan border
        sta (COLOR_LO), y
        ; Fill bitmap cell (for display)
        ldx SAVE_X
        ldy SAVE_Y
        jsr FILL_BITMAP_CELL
        rts

DRAW_EMPTY_TILE:
        stx SAVE_X
        sty SAVE_Y
        ; Update character map (for game logic)
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_EMPTY
        sta (SCREEN_LO), y
        lda #COL_DGREY
        sta (COLOR_LO), y
        ; Clear bitmap cell (for display)
        ldx SAVE_X
        ldy SAVE_Y
        jsr CLEAR_BITMAP_CELL
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
        lda #COL_PINK           ; Neon pink trail
        sta (COLOR_LO), y

        ; Draw pixel-precise trail in bitmap
        ldx SAVE_X
        ldy SAVE_Y
        jsr DRAW_TRAIL_BITMAP

        ; Set bitmap cell color to neon pink
        ldx SAVE_X
        ldy SAVE_Y
        lda #$A0                ; Pink foreground on black background (neon trail)
        jsr SET_BITMAP_COLOR

        ; Update previous direction
        lda PLAYER_DIR
        sta PREV_DRAW_DIR
        rts

DRAW_CLAIMED_TILE:
        stx SAVE_X
        sty SAVE_Y
        ; Update character map (for game logic)
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_CLAIMED
        sta (SCREEN_LO), y
        ; Color based on fill index (different color per area)
        ldx FILL_COLOR_IDX
        lda CLAIM_COLORS, x
        ldy #0
        sta (COLOR_LO), y
        ; Fill bitmap cell (for display)
        ldx SAVE_X
        ldy SAVE_Y
        jsr FILL_BITMAP_CELL
        ; Set bitmap color (foreground in high nibble, black background)
        ldx FILL_COLOR_IDX
        lda CLAIM_COLORS, x
        asl
        asl
        asl
        asl                     ; Shift color to high nibble
        ldx SAVE_X
        ldy SAVE_Y
        jsr SET_BITMAP_COLOR
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
        ; Build HUD into HUD_BUF, then draw with compact loop
        ; Row 0: "SCORE: ......  ...LEVEL: .."
        ; Row 1: "LIVES: .  ...........FILL: ../..%"
        jsr UPDATE_HUD_BUF
        jsr DRAW_HUD_BITMAP
        rts

UPDATE_HUD:
        jsr UPDATE_HUD_BUF
        jsr DRAW_HUD_BITMAP
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
        lda #$FF
        sta PREV_TRAIL_X        ; Reset previous trail position for line drawing

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
        ; Save current percentage before claim (for extra life check)
        lda PERCENT_CLAIMED
        sta PREV_PERCENT

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

        ; Grant grace period (invincibility during and after claim)
        lda #90             ; ~1.5 seconds at 60fps
        sta GRACE_TIMER
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

        ; Check if this claim was >50% of the field in one try
        lda PERCENT_CLAIMED
        sec
        sbc PREV_PERCENT
        cmp #50
        bcc @no_extra_life
        ; Award extra life
        inc LIVES
        jsr SFX_EXTRA_LIFE
@no_extra_life:

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

        ; Fill bitmap cell (for display)
        ldx SAVE_X
        ldy SAVE_Y
        jsr FILL_BITMAP_CELL

        ; Set bitmap color (foreground in high nibble, black background)
        ldx FILL_COLOR_IDX
        lda CLAIM_COLORS, x
        asl
        asl
        asl
        asl                     ; Shift color to high nibble
        ldx SAVE_X
        ldy SAVE_Y
        jsr SET_BITMAP_COLOR

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
        ; Move every QIX_SPEED-th frame
        lda FRAME_COUNT
        sec
-       sbc QIX_SPEED
        bcs -
        adc QIX_SPEED   ; A = FRAME_COUNT mod QIX_SPEED
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
QIX_COLORS: !byte COL_RED, COL_PINK, COL_PURPLE, COL_ORANGE
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

; Move Sparx along edges using right-hand wall following
; Input: X=x, Y=y, A=direction (1=up,2=down,3=left,4=right)
; Output: X=new x, Y=new y, A=new direction
MOVE_SPARX:
        sta TEMP3           ; Save original direction
        stx SAVE_X          ; Save original X
        sty SAVE_Y          ; Save original Y

        ; Sparx movement: follow borders, enter new claimed borders via shortcuts.
        ; Interior of playfield is always on the CW side of movement direction.
        ;
        ; 1. Check CW side for SHORTCUTS (trail/claimed-on-boundary, NOT border)
        ; 2. Continue straight
        ; 3. Turn CW (corners)
        ; 4. Turn CCW
        ; 5. Reverse

        ; Step 1: Check CW for shortcuts into claimed territory
        lda TEMP3
        jsr @get_cw
        jsr @try_shortcut
        bcs @move_ok

        ; Step 2: Continue straight
        lda TEMP3
        jsr @try_dir
        bcs @move_ok

        ; Step 3: Turn CW (at corners)
        lda TEMP3
        jsr @get_cw
        jsr @try_dir
        bcs @move_ok

        ; Step 4: Turn CCW
        lda TEMP3
        jsr @get_ccw
        jsr @try_dir
        bcs @move_ok

        ; Step 5: Reverse
        lda TEMP3
        jsr @get_cw
        jsr @get_cw
        jsr @try_dir
        bcs @move_ok

        ; Completely stuck - return original position
        ldx SAVE_X
        ldy SAVE_Y
        lda TEMP3
        rts

@move_ok:
        ; A = direction that worked, position in TEMP1/TEMP2
        ldx TEMP1
        ldy TEMP2
        rts

; Try shortcut: move in direction A, but ONLY accept trail or claimed-on-boundary
; (NOT plain border - this prevents wrong turns at outer corners)
; Returns: C=1 if valid (TEMP1/TEMP2 set, A=dir), C=0 if not
@try_shortcut:
        pha                 ; Save direction on stack
        ldx SAVE_X
        ldy SAVE_Y
        pla
        pha
        jsr @apply_dir      ; Apply direction to X,Y
        stx TEMP1
        sty TEMP2
        ; Bounds check
        cpx #FIELD_LEFT
        bcc @ts_fail
        cpx #FIELD_RIGHT + 1
        bcs @ts_fail
        cpy #FIELD_TOP
        bcc @ts_fail
        cpy #FIELD_BOTTOM + 1
        bcs @ts_fail
        ; Check tile - only trail and claimed-on-boundary
        jsr GET_TILE
        cmp #CHAR_TRAIL_H
        beq @ts_ok
        cmp #CHAR_TRAIL_V
        beq @ts_ok
        cmp #CHAR_CORNER_LB
        beq @ts_ok
        cmp #CHAR_CORNER_RB
        beq @ts_ok
        cmp #CHAR_CORNER_LT
        beq @ts_ok
        cmp #CHAR_CORNER_RT
        beq @ts_ok
        cmp #CHAR_CLAIMED
        bne @ts_fail
        ; Save candidate position before boundary check (GET_TILE corrupts TEMP1)
        lda TEMP1
        pha
        lda TEMP2
        pha
        jsr @check_on_boundary
        pla
        sta TEMP2
        pla
        sta TEMP1
        bcc @ts_fail
@ts_ok:
        pla                 ; Get direction from stack
        sec
        rts
@ts_fail:
        pla
        clc
        rts

; Try moving in direction A from SAVE_X/SAVE_Y
; Returns: C=1 if valid (TEMP1/TEMP2 set, A=dir), C=0 if not
; Does not modify TEMP3 (original direction preserved)
@try_dir:
        pha                 ; Save direction being tried on stack
        ldx SAVE_X
        ldy SAVE_Y
        pla
        pha
        jsr @apply_dir      ; Apply direction to X,Y
        stx TEMP1
        sty TEMP2
        ; Bounds check
        cpx #FIELD_LEFT
        bcc @td_fail
        cpx #FIELD_RIGHT + 1
        bcs @td_fail
        cpy #FIELD_TOP
        bcc @td_fail
        cpy #FIELD_BOTTOM + 1
        bcs @td_fail

        ; Check tile type
        jsr GET_TILE
        cmp #CHAR_BORDER
        beq @td_ok
        cmp #CHAR_TRAIL_H
        beq @td_ok
        cmp #CHAR_TRAIL_V
        beq @td_ok
        cmp #CHAR_CORNER_LB
        beq @td_ok
        cmp #CHAR_CORNER_RB
        beq @td_ok
        cmp #CHAR_CORNER_LT
        beq @td_ok
        cmp #CHAR_CORNER_RT
        beq @td_ok
        ; CHAR_CLAIMED only valid if adjacent to CHAR_EMPTY
        cmp #CHAR_CLAIMED
        bne @td_fail
        ; Save candidate position before boundary check (GET_TILE corrupts TEMP1)
        lda TEMP1
        pha
        lda TEMP2
        pha
        jsr @check_on_boundary
        pla
        sta TEMP2
        pla
        sta TEMP1
        bcc @td_fail

@td_ok:
        pla                 ; Get tried direction from stack
        sec                 ; C=1 = success
        rts

@td_fail:
        pla                 ; Clean up stack
        clc                 ; C=0 = fail
        rts

; Apply direction in A to X,Y registers
; A: 1=up, 2=down, 3=left, 4=right
@apply_dir:
        cmp #1
        beq @ad_up
        cmp #2
        beq @ad_down
        cmp #3
        beq @ad_left
        ; 4 = right
        inx
        rts
@ad_up: dey
        rts
@ad_down:
        iny
        rts
@ad_left:
        dex
        rts

; Get counter-clockwise direction: A in, A out
; up->left->down->right->up
@get_ccw:
        cmp #1              ; up -> left
        beq @ccw_left
        cmp #3              ; left -> down
        beq @ccw_down
        cmp #2              ; down -> right
        beq @ccw_right
        ; right -> up
        lda #1
        rts
@ccw_left:
        lda #3
        rts
@ccw_down:
        lda #2
        rts
@ccw_right:
        lda #4
        rts

; Get clockwise direction: A in, A out
; up->right->down->left->up
@get_cw:
        cmp #1              ; up -> right
        beq @cw_right
        cmp #4              ; right -> down
        beq @cw_down
        cmp #2              ; down -> left
        beq @cw_left
        ; left -> up
        lda #1
        rts
@cw_right:
        lda #4
        rts
@cw_down:
        lda #2
        rts
@cw_left:
        lda #3
        rts

; Check if tile at TEMP1,TEMP2 is adjacent to CHAR_EMPTY (on boundary)
; Returns: C=1 if on boundary, C=0 if not
@check_on_boundary:
        ; Save position on stack
        lda TEMP1
        pha
        lda TEMP2
        pha

        ; Check up
        pla
        tay                 ; Y = TEMP2
        pla
        tax                 ; X = TEMP1
        pha                 ; Push TEMP1 back
        tya
        pha                 ; Push TEMP2 back
        cpy #FIELD_TOP
        beq @cob_no_up
        dey
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @cob_found_cleanup

@cob_no_up:
        ; Check down - reload from stack
        pla
        tay                 ; Y = TEMP2
        pla
        tax                 ; X = TEMP1
        pha
        tya
        pha
        cpy #FIELD_BOTTOM
        beq @cob_no_down
        iny
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @cob_found_cleanup

@cob_no_down:
        ; Check left - reload from stack
        pla
        tay
        pla
        tax
        pha
        tya
        pha
        cpx #FIELD_LEFT
        beq @cob_no_left
        dex
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @cob_found_cleanup

@cob_no_left:
        ; Check right - reload from stack
        pla
        tay
        pla
        tax
        cpx #FIELD_RIGHT
        beq @cob_not_found
        inx
        jsr GET_TILE
        cmp #CHAR_EMPTY
        beq @cob_found

@cob_not_found:
        clc
        rts

@cob_found_cleanup:
        ; Clean up stack (2 bytes)
        pla
        pla
@cob_found:
        sec
        rts

; ============================================================================
; CHECK COLLISIONS
; ============================================================================

CHECK_COLLISIONS:
        ; Skip all collisions during grace period
        lda GRACE_TIMER
        bne @done

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

        lda #120            ; 2 second grace period after respawn
        sta GRACE_TIMER

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
        ; Save loop counter on stack
        txa
        pha
        ; Get X,Y from trail buffer
        lda TRAIL_BUFFER_X, x
        sta SAVE_X              ; Store column
        lda TRAIL_BUFFER_Y, x
        sta SAVE_Y              ; Store row
        ; Clear character map
        tay                     ; Y = row
        ldx SAVE_X              ; X = column
        jsr CALC_SCREEN_ADDR
        ldy #0
        lda #CHAR_EMPTY
        sta (SCREEN_LO), y
        lda #COL_DGREY
        sta (COLOR_LO), y
        ; Clear bitmap cell
        ldx SAVE_X              ; X = column
        ldy SAVE_Y              ; Y = row
        jsr CLEAR_BITMAP_CELL
        ; Restore loop counter and continue
        pla
        tax
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

        ; Player color: grace period blink (yellow/red)
        lda GRACE_TIMER
        beq @no_grace
        lda FRAME_COUNT
        and #$04
        beq @grace_red
        lda #COL_YELLOW
        sta VIC_SPRITE_COL
        rts
@grace_red:
        lda #COL_RED
        sta VIC_SPRITE_COL
        rts

@no_grace:
        lda #COL_WHITE          ; Normal: white
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
        ; Speed up Qix (25% faster each level)
        ; New speed = speed * 3/4 (reduce by 25%)
        lda QIX_SPEED
        lsr             ; speed / 2
        lsr             ; speed / 4
        sta TEMP1       ; TEMP1 = speed / 4
        lda QIX_SPEED
        sec
        sbc TEMP1       ; speed - speed/4 = speed * 3/4
        bne @spd_ok
        lda #1          ; minimum speed divisor of 1
@spd_ok:
        sta QIX_SPEED

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

        ; Check if score qualifies for high score table
        jsr CHECK_HISCORE
        lda HS_ENTRY_IDX
        cmp #$FF
        beq @no_hiscore

        ; Got a high score! Show entry screen
        jsr SHOW_HISCORE_ENTRY
        lda #5
        sta GAME_STATE
        rts

@no_hiscore:
        ; No high score, show high score table then title
        jsr SHOW_HISCORE_TABLE
        lda #6
        sta GAME_STATE
@done:  rts

; ============================================================================
; HIGH SCORE SYSTEM
; ============================================================================

; Initialize high score table with default values
; Layout: 5 entries * 12 bytes = 60 bytes total
; Each entry: 8 bytes name, 3 bytes score (LO/MID/HI), 1 byte level
INIT_HISCORE_TABLE:
        ldx #0              ; Source index for names (0-39)
        ldy #0              ; Dest index for table (0-59)
        lda #0
        sta TEMP1           ; Entry counter (0-4)

@entry_loop:
        ; Copy 8 bytes of name
        lda #8
        sta TEMP2
@name_loop:
        lda DEFAULT_HS_NAMES, x
        sta HISCORE_TABLE, y
        inx
        iny
        dec TEMP2
        bne @name_loop

        ; Save X (names index) before using it for score lookup
        stx TEMP3

        ; Set descending default scores: 50, 40, 30, 20, 10
        ldx TEMP1           ; Entry 0-4
        lda DEFAULT_SCORES_LO, x
        sta HISCORE_TABLE, y    ; Score LO
        iny
        lda #0
        sta HISCORE_TABLE, y    ; Score MID
        iny
        sta HISCORE_TABLE, y    ; Score HI
        iny

        ; Level = 1
        lda #1
        sta HISCORE_TABLE, y
        iny

        ; Restore X (names index) for next iteration
        ldx TEMP3

        ; Next entry
        inc TEMP1
        lda TEMP1
        cmp #5
        bne @entry_loop
        rts

; Check if current score qualifies for high score table
; Sets HS_ENTRY_IDX to position (0-4) or $FF if no entry
CHECK_HISCORE:
        ldx #0              ; Entry index
        ldy #0              ; Table offset

@check_loop:
        ; Compare score (HI byte first)
        lda SCORE_HI
        cmp HISCORE_TABLE + 10, y   ; HI byte at offset +10
        bcc @next_entry
        bne @found_slot

        ; HI equal, check MID
        lda SCORE_MID
        cmp HISCORE_TABLE + 9, y    ; MID byte at offset +9
        bcc @next_entry
        bne @found_slot

        ; MID equal, check LO
        lda SCORE_LO
        cmp HISCORE_TABLE + 8, y    ; LO byte at offset +8
        bcc @next_entry
        beq @next_entry     ; Equal doesn't qualify

@found_slot:
        stx HS_ENTRY_IDX
        rts

@next_entry:
        ; Move to next entry (12 bytes per entry)
        tya
        clc
        adc #12
        tay
        inx
        cpx #5
        bcc @check_loop

        ; No slot found
        lda #$FF
        sta HS_ENTRY_IDX
        rts

; Insert new high score at HS_ENTRY_IDX, shifting others down
INSERT_HISCORE:
        ; Shift entries down: move entry 3->4, 2->3, 1->2, 0->1 as needed
        ; Start from entry 4 and work backwards to HS_ENTRY_IDX+1

        ldx #4              ; Start with last entry slot
@shift_loop:
        cpx HS_ENTRY_IDX
        beq @insert_new     ; Reached the slot, stop shifting
        bcc @insert_new     ; Past the slot (shouldn't happen)

        ; Copy entry (X-1) to entry X
        ; Source offset = (X-1) * 12
        ; Dest offset = X * 12
        dex                 ; X now points to source entry
        stx TEMP1           ; Save source entry index

        ; Calculate source offset = X * 12
        txa
        asl                 ; *2
        asl                 ; *4
        sta TEMP2
        asl                 ; *8
        clc
        adc TEMP2           ; *12
        tay                 ; Y = source offset

        ; Copy 12 bytes
        ldx #12
@copy_loop:
        lda HISCORE_TABLE, y
        sta HISCORE_TABLE + 12, y   ; Dest is 12 bytes later
        iny
        dex
        bne @copy_loop

        ; Continue with previous entry
        ldx TEMP1           ; Restore entry index
        jmp @shift_loop

@insert_new:
        ; Calculate offset for new entry
        lda HS_ENTRY_IDX
        asl
        asl                 ; *4
        sta TEMP1
        asl                 ; *8
        clc
        adc TEMP1           ; *12
        tay

        ; Copy name from ENTRY_NAME
        ldx #0
@copy_name:
        lda ENTRY_NAME, x
        sta HISCORE_TABLE, y
        iny
        inx
        cpx #8
        bne @copy_name

        ; Copy score
        lda SCORE_LO
        sta HISCORE_TABLE, y
        iny
        lda SCORE_MID
        sta HISCORE_TABLE, y
        iny
        lda SCORE_HI
        sta HISCORE_TABLE, y
        iny

        ; Copy level
        lda LEVEL
        sta HISCORE_TABLE, y
        rts

; Show high score entry screen
SHOW_HISCORE_ENTRY:
        ; Disable sprites
        lda #0
        sta VIC_SPRITE_EN

        ; Switch to VIC bank 0 ($0000-$3FFF) for standard character ROM
        lda CIA2_PORTA
        ora #$03            ; Bank 0
        sta CIA2_PORTA

        ; Switch to text mode
        lda #$1B
        sta VIC_CTRL1
        lda #$C8
        sta VIC_CTRL2

        ; Set up VIC for ROM charset: screen at $0400, chars at $1000 (ROM)
        lda #$14
        sta VIC_MEMPTR

        ; Enable KERNAL ROM for keyboard input
        lda $01
        ora #$03            ; Enable KERNAL and BASIC ROM
        sta $01

        ; Clear screen
        ldx #0
@clr:   lda #$20            ; Space - must reload, gets overwritten below
        sta SCREEN_RAM, x
        sta SCREEN_RAM + 256, x
        sta SCREEN_RAM + 512, x
        sta SCREEN_RAM + 768, x
        lda #COL_BLACK
        sta COLOR_RAM, x
        sta COLOR_RAM + 256, x
        sta COLOR_RAM + 512, x
        sta COLOR_RAM + 768, x
        inx
        bne @clr

        ; Set colors
        lda #COL_BLACK
        sta VIC_BGCOLOR
        lda #COL_BLUE
        sta VIC_BORDER

        ; Draw title "NEW HIGH SCORE!"
        ldx #0
@t1:    lda HS_TITLE_TXT, x
        beq @t1done
        sta SCREEN_RAM + 52, x
        lda #COL_YELLOW
        sta COLOR_RAM + 52, x
        inx
        bne @t1
@t1done:

        ; Draw "YOUR SCORE:" and score value
        ldx #0
@t2:    lda HS_SCORE_TXT, x
        beq @t2done
        sta SCREEN_RAM + 163, x
        lda #COL_WHITE
        sta COLOR_RAM + 163, x
        inx
        bne @t2
@t2done:
        jsr DRAW_ENTRY_SCORE

        ; Draw "LEVEL:" and level value
        ldx #0
@t3:    lda HS_LEVEL_TXT, x
        beq @t3done
        sta SCREEN_RAM + 243, x
        lda #COL_CYAN
        sta COLOR_RAM + 243, x
        inx
        bne @t3
@t3done:
        jsr DRAW_ENTRY_LEVEL

        ; Draw "ENTER YOUR NAME:"
        ldx #0
@t4:    lda HS_ENTER_TXT, x
        beq @t4done
        sta SCREEN_RAM + 332, x
        lda #COL_LGREEN
        sta COLOR_RAM + 332, x
        inx
        bne @t4
@t4done:

        ; Initialize name entry
        lda #0
        sta HS_NAME_POS
        sta HS_BLINK_TMR
        sta LAST_KEY
        sta KEY_DELAY

        ; Fill entry name with spaces
        ldx #7
        lda #$20
@fill:  sta ENTRY_NAME, x
        dex
        bpl @fill

        ; Draw name entry field with dots (placeholders)
        ldx #0
@draw_field:
        lda #$2E            ; Period character
        sta SCREEN_RAM + 416, x
        lda #COL_LGREY
        sta COLOR_RAM + 416, x
        inx
        cpx #8
        bne @draw_field

        ; Draw "PRESS RETURN WHEN DONE"
        ldx #0
@t5:    lda HS_DONE_TXT, x
        beq @t5done
        sta SCREEN_RAM + 612, x
        lda #COL_LGREY
        sta COLOR_RAM + 612, x
        inx
        bne @t5
@t5done:
        rts

; Draw score on entry screen at position 175
DRAW_ENTRY_SCORE:
        ; Display 6-digit score at screen position 175
        ; SCORE_HI, SCORE_MID, SCORE_LO each hold 0-99
        ldx #0              ; Screen offset

        ; High byte (2 digits)
        lda SCORE_HI
        jsr @draw_two_digits

        ; Mid byte (2 digits)
        lda SCORE_MID
        jsr @draw_two_digits

        ; Low byte (2 digits)
        lda SCORE_LO
        jsr @draw_two_digits
        rts

@draw_two_digits:
        ; A = value 0-99, X = screen offset, increments X by 2
        sta TEMP3
        ; Divide by 10
        ldy #0              ; Tens counter
@div:   cmp #10
        bcc @div_end
        sec
        sbc #10
        iny
        bne @div            ; Always branch
@div_end:
        ; Y = tens, A = ones
        sta TEMP4           ; Save ones
        tya
        ora #$30            ; Convert to screen code
        sta SCREEN_RAM + 175, x
        lda #COL_WHITE
        sta COLOR_RAM + 175, x
        inx
        lda TEMP4
        ora #$30
        sta SCREEN_RAM + 175, x
        lda #COL_WHITE
        sta COLOR_RAM + 175, x
        inx
        rts

; Draw level on entry screen
DRAW_ENTRY_LEVEL:
        lda LEVEL
        cmp #10
        bcc @single
        ; Two digit level
        lda #$31            ; '1'
        sta SCREEN_RAM + 250
        lda #COL_CYAN
        sta COLOR_RAM + 250
        lda LEVEL
        sec
        sbc #10
        ora #$30
        sta SCREEN_RAM + 251
        lda #COL_CYAN
        sta COLOR_RAM + 251
        rts
@single:
        lda LEVEL
        ora #$30
        sta SCREEN_RAM + 250
        lda #COL_CYAN
        sta COLOR_RAM + 250
        rts

; Update high score entry screen
UPDATE_HISCORE_ENTRY:
        ; Blink cursor
        inc HS_BLINK_TMR
        lda HS_BLINK_TMR
        and #$10
        beq @cursor_on
        lda #$20            ; Space (cursor off)
        jmp @draw_cursor
@cursor_on:
        lda #$A0            ; Reverse space (cursor on)
@draw_cursor:
        ldx HS_NAME_POS
        sta SCREEN_RAM + 416, x
        lda #COL_WHITE
        sta COLOR_RAM + 416, x

        ; Read keyboard
        jsr READ_KEYBOARD
        cmp #0
        beq @no_key

        ; Check for RETURN ($80 = done)
        cmp #$80
        beq @done_entry

        ; Check for DEL ($81 = backspace)
        cmp #$81
        beq @backspace

        ; Check if valid character (screen codes)
        ; Letters A-Z = $01-$1A, numbers 0-9 = $30-$39, space = $20
        cmp #$20            ; Space
        beq @valid_char
        cmp #$01            ; Letters A-Z ($01-$1A)
        bcc @no_key
        cmp #$1B
        bcc @valid_char
        cmp #$30            ; Numbers 0-9 ($30-$39)
        bcc @no_key
        cmp #$3A
        bcs @no_key

@valid_char:
        ; Store character (already a screen code)
        ldx HS_NAME_POS
        cpx #8
        bcs @no_key         ; Name full
        sta ENTRY_NAME, x
        sta SCREEN_RAM + 416, x
        lda #COL_YELLOW
        sta COLOR_RAM + 416, x
        inc HS_NAME_POS
        jmp @no_key

@backspace:
        lda HS_NAME_POS
        beq @no_key
        dec HS_NAME_POS
        ldx HS_NAME_POS
        lda #$2E            ; Period placeholder
        sta SCREEN_RAM + 416, x
        lda #COL_LGREY
        sta COLOR_RAM + 416, x
        lda #$20
        sta ENTRY_NAME, x
        jmp @no_key

@done_entry:
        ; Ensure at least one character
        lda HS_NAME_POS
        beq @no_key

        ; Insert the high score
        jsr INSERT_HISCORE

        ; Show high score table
        jsr SHOW_HISCORE_TABLE
        lda #6
        sta GAME_STATE
        rts

@no_key:
        rts

; Read keyboard - returns screen code in A, 0 if no key
; Uses KERNAL SCNKEY to scan keyboard, then reads buffer
READ_KEYBOARD:
        ; Key debounce
        lda KEY_DELAY
        beq @can_read
        dec KEY_DELAY
        lda #0
        rts

@can_read:
        ; Call KERNAL SCNKEY to scan keyboard matrix
        jsr $FF9F           ; SCNKEY - updates keyboard buffer

        ; Check if any key in buffer
        lda $C6             ; Number of chars in keyboard buffer
        beq @no_key

        ; Get character from buffer (PETSCII)
        lda $0277           ; First char in buffer
        ldx #0
        stx $C6             ; Clear buffer

        ; Check if same key still held
        cmp LAST_KEY
        beq @no_key

        ; New key - save and convert
        sta LAST_KEY
        lda #6              ; Debounce frames
        sta KEY_DELAY

        ; Convert PETSCII to screen code
        lda LAST_KEY

        ; Check for RETURN ($0D)
        cmp #$0D
        bne @not_return
        lda #$80            ; Special code for RETURN
        rts

@not_return:
        ; Check for DELETE ($14)
        cmp #$14
        bne @not_delete
        lda #$81            ; Special code for DELETE
        rts

@not_delete:
        ; Check for SPACE ($20)
        cmp #$20
        bne @not_space
        lda #$20            ; Space screen code = $20
        rts

@not_space:
        ; Convert letters A-Z: PETSCII $41-$5A or $C1-$DA -> screen $01-$1A
        cmp #$41
        bcc @check_numbers
        cmp #$5B
        bcs @check_lower
        ; Uppercase A-Z ($41-$5A)
        sec
        sbc #$40            ; Convert to $01-$1A
        rts

@check_lower:
        ; Lowercase a-z in PETSCII is $C1-$DA (with shift)
        cmp #$C1
        bcc @check_numbers
        cmp #$DB
        bcs @check_numbers
        sec
        sbc #$C0            ; Convert to $01-$1A
        rts

@check_numbers:
        ; Numbers 0-9: PETSCII $30-$39 -> screen $30-$39 (same)
        cmp #$30
        bcc @invalid
        cmp #$3A
        bcs @invalid
        rts                 ; Return as-is

@invalid:
@no_key:
        lda #0
        sta LAST_KEY
        rts

; Show high score table
SHOW_HISCORE_TABLE:
        ; Disable sprites
        lda #0
        sta VIC_SPRITE_EN

        ; Switch to VIC bank 0 for standard charset
        lda CIA2_PORTA
        ora #$03
        sta CIA2_PORTA

        ; Switch to text mode
        lda #$1B
        sta VIC_CTRL1
        lda #$C8
        sta VIC_CTRL2

        ; Use ROM charset
        lda #$14
        sta VIC_MEMPTR

        ; Clear screen
        ldx #0
@clr:   lda #$20                ; Must reload - gets overwritten below
        sta SCREEN_RAM, x
        sta SCREEN_RAM + 256, x
        sta SCREEN_RAM + 512, x
        sta SCREEN_RAM + 768, x
        lda #COL_BLACK
        sta COLOR_RAM, x
        sta COLOR_RAM + 256, x
        sta COLOR_RAM + 512, x
        sta COLOR_RAM + 768, x
        inx
        bne @clr

        lda #COL_BLACK
        sta VIC_BGCOLOR
        lda #COL_PURPLE
        sta VIC_BORDER

        ; Draw "HIGH SCORES" title
        ldx #0
@title: lda HSTABLE_TITLE, x
        beq @title_done
        sta SCREEN_RAM + 54, x
        lda #COL_YELLOW
        sta COLOR_RAM + 54, x
        inx
        bne @title
@title_done:

        ; Draw header "NAME     SCORE  LVL"
        ldx #0
@hdr:   lda HSTABLE_HDR, x
        beq @hdr_done
        sta SCREEN_RAM + 129, x
        lda #COL_LGREY
        sta COLOR_RAM + 129, x
        inx
        bne @hdr
@hdr_done:

        ; Draw 5 high score entries
        lda #0
        sta TEMP2           ; Entry counter
        lda #<(SCREEN_RAM + 209)
        sta SCREEN_LO
        lda #>(SCREEN_RAM + 209)
        sta SCREEN_HI
        ; Initialize color pointer (must be set BEFORE @draw_entries loop)
        lda #<(COLOR_RAM + 209)
        sta COLOR_LO
        lda #>(COLOR_RAM + 209)
        sta COLOR_HI

@draw_entries:
        ; Calculate table offset: entry * 12
        lda TEMP2
        asl
        asl                 ; *4
        sta TEMP1
        asl                 ; *8
        clc
        adc TEMP1           ; *12
        tax                 ; X = table offset

        ; Draw rank number (1-5)
        ldy #0
        lda TEMP2
        clc
        adc #$31            ; '1' + entry
        sta (SCREEN_LO), y
        iny
        lda #$2E            ; '.'
        sta (SCREEN_LO), y
        iny
        lda #$20            ; Space
        sta (SCREEN_LO), y
        iny

        ; Draw name (8 chars)
        stx TEMP3           ; Save table offset
@draw_name:
        lda HISCORE_TABLE, x
        cmp #$20
        bne @not_space
        lda #$2E            ; Show dots for empty spaces
@not_space:
        sta (SCREEN_LO), y
        inx
        iny
        cpy #11             ; 3 + 8 chars
        bne @draw_name

        ldx TEMP3           ; Restore table offset

        ; Space
        lda #$20
        sta (SCREEN_LO), y
        iny

        ; Draw score (6 digits from 3 bytes)
        lda HISCORE_TABLE + 10, x    ; HI byte
        jsr @draw_byte
        lda HISCORE_TABLE + 9, x     ; MID byte
        jsr @draw_byte
        lda HISCORE_TABLE + 8, x     ; LO byte
        jsr @draw_byte

        ; Space
        lda #$20
        sta (SCREEN_LO), y
        iny

        ; Draw level
        lda HISCORE_TABLE + 11, x    ; Level
        cmp #10
        bcc @lvl_single
        ; Two digits
        pha
        lda #$31
        sta (SCREEN_LO), y
        iny
        pla
        sec
        sbc #10
@lvl_single:
        ora #$30
        sta (SCREEN_LO), y

        ; Color the row
        lda TEMP2
        tax
        lda HS_ROW_COLORS, x
        tax                 ; Color in X

        ldy #0
@color_row:
        txa
        sta (COLOR_LO), y
        iny
        cpy #22
        bne @color_row

        ; Calculate color RAM address
        lda SCREEN_LO
        sta COLOR_LO
        lda SCREEN_HI
        clc
        adc #$D4            ; COLOR_RAM = SCREEN_RAM + $D400
        sta COLOR_HI

        ; Move to next row (add 40)
        lda SCREEN_LO
        clc
        adc #40
        sta SCREEN_LO
        lda SCREEN_HI
        adc #0
        sta SCREEN_HI

        ; Also update color pointer
        lda COLOR_LO
        clc
        adc #40
        sta COLOR_LO
        lda COLOR_HI
        adc #0
        sta COLOR_HI

        inc TEMP2
        lda TEMP2
        cmp #5
        bcs @entries_done
        jmp @draw_entries

@entries_done:
        ; Draw "PRESS FIRE" prompt
        ldx #0
@prompt:
        lda HSTABLE_PROMPT, x
        beq @prompt_done
        sta SCREEN_RAM + 529, x
        lda #COL_WHITE
        sta COLOR_RAM + 529, x
        inx
        bne @prompt
@prompt_done:

        ; Convert all screen letters to uppercase codes for lowercase charset
        ; Screen codes $01-$1A (letters) get $40 added → $41-$5A (uppercase in lowercase charset)
        lda #<SCREEN_RAM
        sta SCREEN_LO
        lda #>SCREEN_RAM
        sta SCREEN_HI
        ldx #4              ; 4 pages
        ldy #0
@conv_loop:
        lda (SCREEN_LO), y
        cmp #$1B
        bcs @conv_skip
        cmp #$01
        bcc @conv_skip
        ora #$40
        sta (SCREEN_LO), y
@conv_skip:
        iny
        bne @conv_loop
        inc SCREEN_HI
        dex
        bne @conv_loop

        ; Draw copyright text in lowercase (screen codes $01-$1A = lowercase in lowercase charset)
        ldx #0
@copy:  lda HSTABLE_COPY, x
        beq @copy_done
        sta SCREEN_RAM + 888, x
        lda #COL_DGREY
        sta COLOR_RAM + 888, x
        inx
        bne @copy
@copy_done:

        ; Switch to lowercase charset (char ROM at $1800)
        lda #$16
        sta VIC_MEMPTR

        rts

; Helper: draw byte (0-99) as 2 decimal digits (Y = screen offset, preserves X)
@draw_byte:
        stx TEMP4           ; Save X
        ; Divide A by 10: TEMP3 = quotient (tens), A = remainder (ones)
        ldx #0
@div:   cmp #10
        bcc @div_end
        sec
        sbc #10
        inx
        bne @div            ; Always branch (X won't be 0 until 256 iterations)
@div_end:
        ; X = tens, A = ones
        pha
        txa
        ora #$30
        sta (SCREEN_LO), y
        iny
        pla
        ora #$30
        sta (SCREEN_LO), y
        iny
        ldx TEMP4           ; Restore X
        rts

; Update high score display - wait for fire to return to title
UPDATE_HISCORE_SHOW:
        ; Flash the title
        lda FRAME_COUNT
        and #$07
        tax
        lda CYCLE_COLORS, x
        ldx #10
@flash: sta COLOR_RAM + 54, x
        dex
        bpl @flash

        ; Check F1 key (row 0, column 4) for save
        lda #$FE                ; Select keyboard row 0
        sta CIA1_PORTA
        lda CIA1_PORTB
        and #$10                ; Check column 4 (F1 key)
        bne @check_fire         ; Not pressed, check fire

        ; F1 pressed - save high scores
        lda #$FF                ; Restore CIA for joystick
        sta CIA1_PORTA
        jsr SAVE_HISCORES
        rts

@check_fire:
        lda #$FF                ; Restore CIA for joystick
        sta CIA1_PORTA

        ; Check fire button
        lda CIA1_PORTA
        and #$10
        bne @done

        ; Return to title
        jsr SHOW_TITLE
        lda #0
        sta GAME_STATE
@done:  rts

; Save high scores to disk
SAVE_HISCORES:
        ; Show "SAVING..." message (centered on row 14)
        ldx #0
@msg:   lda SAVING_TXT, x
        beq @msg_done
        sta SCREEN_RAM + 575, x
        lda #COL_YELLOW
        sta COLOR_RAM + 575, x
        inx
        bne @msg
@msg_done:

        ; Set filename: "QIXY-HISCORE"
        lda #12                 ; Length of filename
        ldx #<HS_FILENAME
        ldy #>HS_FILENAME
        jsr $FFBD               ; SETNAM

        ; Set file params: LA=1, device=8, SA=0
        lda #1                  ; Logical file number
        ldx #8                  ; Device 8 (disk)
        ldy #0                  ; Secondary address (0 = save with load address)
        jsr $FFBA               ; SETLFS

        ; Set up start address pointer in zero page
        lda #<HISCORE_TABLE
        sta SAVE_ADDR
        lda #>HISCORE_TABLE
        sta SAVE_ADDR + 1

        ; Save: A = ZP pointer, X/Y = end address + 1
        lda #SAVE_ADDR
        ldx #<(HISCORE_TABLE + 60)
        ldy #>(HISCORE_TABLE + 60)
        jsr $FFD8               ; SAVE
        bcc @save_ok

        ; Error - show error message
        ldx #0
@err:   lda SAVE_ERR_TXT, x
        beq @wait_release
        sta SCREEN_RAM + 575, x
        lda #COL_RED
        sta COLOR_RAM + 575, x
        inx
        bne @err
        jmp @wait_release

@save_ok:
        ; Show success message
        ldx #0
@succ:  lda SAVED_TXT, x
        beq @wait_release
        sta SCREEN_RAM + 575, x
        lda #COL_LGREEN
        sta COLOR_RAM + 575, x
        inx
        bne @succ

@wait_release:
        ; Wait for F1 to be released
        lda #$FE                ; Select keyboard row 0
        sta CIA1_PORTA
        lda CIA1_PORTB
        and #$10                ; Check F1
        beq @wait_release       ; Loop while still pressed

        lda #$FF                ; Restore CIA
        sta CIA1_PORTA

        ; Small delay so user sees the message
        ldx #0
        ldy #0
@delay: dex
        bne @delay
        dey
        bne @delay

        ; Clear the message line
        ldx #11
        lda #$20                ; Space
@clr:   sta SCREEN_RAM + 575, x
        dex
        bpl @clr

        rts

; Load high scores from disk (called at startup, silent on error)
LOAD_HISCORES:
        ; Set filename: "QIXY-HISCORE"
        lda #12                 ; Length of filename
        ldx #<HS_FILENAME
        ldy #>HS_FILENAME
        jsr $FFBD               ; SETNAM

        ; Set file params: LA=1, device=8, SA=1
        lda #1                  ; Logical file number
        ldx #8                  ; Device 8 (disk)
        ldy #1                  ; Secondary address (1 = load to address in file header)
        jsr $FFBA               ; SETLFS

        ; Load: A=0 means LOAD operation
        lda #0
        jsr $FFD5               ; LOAD
        ; Ignore errors silently - just use defaults if file not found

        rts

; ============================================================================
; HIGH SCORE DATA
; ============================================================================

; Default high score names (5 entries * 8 chars = 40 bytes)
; NOTE: Use lowercase in source - ACME !scr converts lowercase to screen codes
; The ROM charset displays these as uppercase on screen
DEFAULT_HS_NAMES:
        !scr "claude  "     ; 1st
        !scr "reizer  "     ; 2nd
        !scr "qixy    "     ; 3rd
        !scr "c64     "     ; 4th
        !scr "player  "     ; 5th

; Default scores (LO byte only - MID and HI are 0)
; Values: 50, 40, 30, 20, 10 (descending for entries 0-4)
DEFAULT_SCORES_LO:
        !byte 50, 40, 30, 20, 10

HS_ROW_COLORS:
        !byte COL_YELLOW, COL_WHITE, COL_CYAN, COL_LGREEN, COL_LBLUE

; Text strings
HS_TITLE_TXT:
        !scr "new high score!"
        !byte 0

HS_SCORE_TXT:
        !scr "your score:"
        !byte 0

HS_LEVEL_TXT:
        !scr "level:"
        !byte 0

HS_ENTER_TXT:
        !scr "enter your name:"
        !byte 0

HS_DONE_TXT:
        !scr "press return when done"
        !byte 0

HSTABLE_TITLE:
        !scr "high scores"
        !byte 0

HSTABLE_HDR:
        !scr "   name     score  lvl"
        !byte 0

HSTABLE_PROMPT:
        !scr "fire=continue  f1=save"
        !byte 0

HSTABLE_COPY:
        !scr "2026 - ERLING REIZER AS"
        !byte 0

; Save high score text strings
HS_FILENAME:
        !pet "qixy-hiscore"      ; Filename in PETSCII

SAVING_TXT:
        !scr "saving...  "
        !byte 0

SAVED_TXT:
        !scr "saved!     "
        !byte 0

SAVE_ERR_TXT:
        !scr "save error!"
        !byte 0

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

SFX_EXTRA_LIFE:
        ; High rising tone on voice 1 for extra life fanfare
        lda #$00
        sta SID_FREQ_LO1
        lda #$20
        sta SID_FREQ_HI1
        lda #$11            ; Triangle wave
        sta SID_CTRL1
        lda #$0A
        sta SID_AD1
        lda #$A0
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
; Crockett's Theme inspired - Em/C/Am/B progression
; Driving octave bass, soaring sparse lead, atmospheric pads

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

        ; Voice 1: Driving bass - sawtooth for 80s punch
        lda #$00
        sta SID_PW_LO1
        lda #$06
        sta SID_PW_HI1
        lda #$02            ; Attack=0, Decay=2 - tight punch
        sta SID_AD1
        lda #$A0            ; Sustain=10, Release=0
        sta SID_SR1

        ; Voice 2: Soaring synth lead - pulse wave, Jan Hammer style
        lda #$00
        sta SID_PW_LO2
        lda #$08            ; 50% pulse width
        sta SID_PW_HI2
        lda #$1A            ; Attack=1, Decay=10 - slight swell
        sta SID_AD2
        lda #$A6            ; Sustain=10, Release=6 - smooth tail
        sta SID_SR2

        ; Voice 3: Atmospheric pad - triangle for warmth
        lda #$6B            ; Attack=6, Decay=11 - slow swell
        sta SID_AD3
        lda #$50            ; Sustain=5, Release=0
        sta SID_SR3

        ; Filter - lowpass, brighter cutoff for 80s sheen
        lda #$00
        sta SID_FILT_LO
        lda #$40            ; Higher cutoff - brighter 80s sound
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
        ; Tempo control - every 7 frames (~7 Hz, slower groove)
        inc MUSIC_TIMER
        lda MUSIC_TIMER
        cmp #7
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

; ============================================================================
; DATA
; ============================================================================
; Skip over CHARSET_RAM ($2000-$27FF) and SPRITE_RAM ($2800-$2BFF)
; to avoid overlapping with reserved VIC memory areas
CODE_END_MARKER:  ; Debug: check this address to see available space before $2000
* = $2C00

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
        !byte $02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03
        ; Octave 2
        !byte $03,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07
        ; Octave 3
        !byte $08,$09,$09,$0A,$0B,$0B,$0C,$0D,$0E,$0F,$10,$11
        ; Octave 4
        !byte $13,$14,$15,$17,$19,$1A,$1C,$1E

; Bass pattern - driving octave pulse, Crockett's Theme style
; Chord progression: Em - C/G - Am - B->Em
; 0=E1, 3=G1, 5=A1, 7=B1, 8=C2, 12=E2, 15=G2, 17=A2, 19=B2, 20=C3
BASS_PATTERN:
        ; Bar 1 (Em): Driving octave pulse
        !byte 12, $FF, 12, 0    ; E2-rest-E2-E1
        !byte 12, $FF, 12, 0    ; E2-rest-E2-E1
        ; Bar 2 (C/G): Harmonic shift
        !byte 20, $FF, 20, 8    ; C3-rest-C3-C2
        !byte 15, $FF, 15, 3    ; G2-rest-G2-G1
        ; Bar 3 (Am): Tension
        !byte 17, $FF, 17, 5    ; A2-rest-A2-A1
        !byte 17, $FF, 17, 5    ; A2-rest-A2-A1
        ; Bar 4 (B->Em): Resolution
        !byte 19, $FF, 19, 7    ; B2-rest-B2-B1
        !byte 12, $FF, 12, 0    ; E2-rest-E2-E1

; Lead melody - soaring, sparse, Crockett's Theme vibe
; Long notes with space between them - less is more
; 29=A3, 31=B3, 32=C4, 34=D4, 36=E4, 39=G4
LEAD_PATTERN:
        ; Bar 1: Atmospheric opening - emerge from silence
        !byte $FF, $FF, $FF, 36 ; rest-rest-rest-E4
        !byte $FF, $FF, 39, $FF ; rest-rest-G4-rest
        ; Bar 2: Descend with space
        !byte 36, $FF, $FF, 32  ; E4-rest-rest-C4
        !byte $FF, $FF, $FF, $FF ; rest (let it breathe)
        ; Bar 3: Second phrase - building
        !byte $FF, $FF, 29, $FF ; rest-rest-A3-rest
        !byte 32, $FF, 36, $FF  ; C4-rest-E4-rest
        ; Bar 4: Climax and resolve
        !byte 39, $FF, 36, $FF  ; G4-rest-E4-rest
        !byte 34, $FF, 31, $FF  ; D4-rest-B3-rest

; Pad/chord pattern - sustained notes for 80s atmosphere
; Follows chord progression: Em - C - Am - B/Em
PAD_PATTERN:
        ; Bar 1 (Em): E3 sustained
        !byte 24, 24, 24, 24    ; E3
        !byte 24, 24, 24, 24    ; E3
        ; Bar 2 (C/G): Shift to C then G
        !byte 20, 20, 20, 20    ; C3
        !byte 27, 27, 27, 27    ; G3
        ; Bar 3 (Am): A sustained
        !byte 29, 29, 29, 29    ; A3
        !byte 29, 29, 29, 29    ; A3
        ; Bar 4 (B->Em): Resolve
        !byte 19, 19, 19, 19    ; B2
        !byte 24, 24, 24, 24    ; E3

; Arpeggio pattern - broken chord shimmer between beats
; Follows chord changes for harmonic richness
ARP_PATTERN:
        !byte 36, 39, 43, 39    ; Em: E4-G4-B4-G4
        !byte 36, 39, 43, 39    ; Em: E4-G4-B4-G4
        !byte 32, 36, 39, 36    ; C:  C4-E4-G4-E4
        !byte 27, 31, 39, 31    ; G:  G3-B3-G4-B3
        !byte 29, 32, 36, 32    ; Am: A3-C4-E4-C4
        !byte 29, 32, 36, 32    ; Am: A3-C4-E4-C4
        !byte 31, 36, 43, 36    ; B:  B3-E4-B4-E4
        !byte 36, 39, 43, 39    ; Em: E4-G4-B4-G4

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
        !scr "score: "
        !byte 0

LIVES_TXT:
        !scr "lives: "
        !byte 0

LEVEL_TXT:
        !scr "level: "
        !byte 0

FILL_TXT:
        !scr "fill: "
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
        ; Neon synthwave palette - vibrant colors that pop against black
        !byte COL_CYAN, COL_PINK, COL_LGREEN, COL_YELLOW
        !byte COL_PURPLE, COL_LBLUE, COL_ORANGE, COL_GREEN

; ============================================================================
; HIRES BITMAP ROUTINES (placed here at $2C00+ to avoid charset corruption)
; ============================================================================

; Memory constants for gameplay bitmap mode
GAMEPLAY_BITMAP = $4000     ; 8000 bytes for hires bitmap ($4000-$5F3F)
GAMEPLAY_SCREEN = $6000     ; Screen RAM for bitmap colors ($6000-$63E7)
GAMEPLAY_SPRITES = $6400    ; Sprite data in Bank 1 (after screen)

; Enable HIRES bitmap mode for gameplay
; VIC Bank 1 ($4000-$7FFF), hires bitmap mode
ENABLE_HIRES_BITMAP_MODE:
        ; Switch to VIC Bank 1 ($4000-$7FFF)
        lda CIA2_PORTA
        and #%11111100
        ora #%00000010          ; Bank 1
        sta CIA2_PORTA

        ; Enable bitmap mode
        lda #$3B                ; Bitmap mode, display on, 25 rows
        sta VIC_CTRL1

        ; Disable multicolor for hires
        lda #$C8                ; 40 columns, no multicolor
        sta VIC_CTRL2

        ; Screen at $6000, Bitmap at $4000
        ; Screen offset = ($6000-$4000)/$400 = 8, bits 4-7 = 8
        lda #$80
        sta VIC_MEMSETUP

        lda #COL_BLACK
        sta VIC_BGCOLOR
        lda #COL_BLUE           ; Dark blue border for synthwave aesthetic
        sta VIC_BORDER
        rts

; Clear the gameplay bitmap and set screen colors
CLEAR_GAMEPLAY_BITMAP:
        ; Clear bitmap ($4000-$5F3F = 8000 bytes)
        lda #<GAMEPLAY_BITMAP
        sta SCREEN_LO           ; Reuse SCREEN_LO/HI as temp pointer
        lda #>GAMEPLAY_BITMAP
        sta SCREEN_HI

        ldx #31                 ; 31 pages = 7936 bytes
        ldy #0
        lda #$00
@clear_page:
        sta (SCREEN_LO), y
        iny
        bne @clear_page
        inc SCREEN_HI
        dex
        bne @clear_page

        ; Clear remaining 64 bytes
        ldy #0
@clear_last:
        sta (SCREEN_LO), y
        iny
        cpy #64
        bne @clear_last

        ; Set screen RAM colors ($6000, 1000 bytes)
        lda #<GAMEPLAY_SCREEN
        sta SCREEN_LO
        lda #>GAMEPLAY_SCREEN
        sta SCREEN_HI

        ldx #4                  ; 4 pages
        lda #$30                ; Cyan on black (neon border)
        ldy #0
@color_page:
        sta (SCREEN_LO), y
        iny
        bne @color_page
        inc SCREEN_HI
        dex
        bne @color_page

        ; Set sprite pointers at $6000 + $3F8 = $63F8
        ; Sprites at $6400 = block ($6400-$4000)/64 = 144
        lda #(GAMEPLAY_SPRITES - $4000) / 64
        sta GAMEPLAY_SCREEN + $3F8
        lda #(GAMEPLAY_SPRITES - $4000) / 64 + 1
        sta GAMEPLAY_SCREEN + $3F9
        lda #(GAMEPLAY_SPRITES - $4000) / 64 + 2
        sta GAMEPLAY_SCREEN + $3FA
        lda #(GAMEPLAY_SPRITES - $4000) / 64 + 3
        sta GAMEPLAY_SCREEN + $3FB
        rts

; Copy sprite data from Bank 0 ($2800) to Bank 1 ($6400)
COPY_SPRITES_TO_BANK1:
        ldx #0
@copy:  lda SPRITE_RAM, x
        sta GAMEPLAY_SPRITES, x
        lda SPRITE_RAM + 64, x
        sta GAMEPLAY_SPRITES + 64, x
        lda SPRITE_RAM + 128, x
        sta GAMEPLAY_SPRITES + 128, x
        lda SPRITE_RAM + 192, x
        sta GAMEPLAY_SPRITES + 192, x
        inx
        cpx #64
        bne @copy
        lda #%00001111
        sta VIC_SPRITE_EN
        rts

; Bitmap row address lookup table (25 rows)
; Each row = base + row * 320
BITMAP_ROW_LO:
        !byte <(GAMEPLAY_BITMAP + 0)
        !byte <(GAMEPLAY_BITMAP + 320)
        !byte <(GAMEPLAY_BITMAP + 640)
        !byte <(GAMEPLAY_BITMAP + 960)
        !byte <(GAMEPLAY_BITMAP + 1280)
        !byte <(GAMEPLAY_BITMAP + 1600)
        !byte <(GAMEPLAY_BITMAP + 1920)
        !byte <(GAMEPLAY_BITMAP + 2240)
        !byte <(GAMEPLAY_BITMAP + 2560)
        !byte <(GAMEPLAY_BITMAP + 2880)
        !byte <(GAMEPLAY_BITMAP + 3200)
        !byte <(GAMEPLAY_BITMAP + 3520)
        !byte <(GAMEPLAY_BITMAP + 3840)
        !byte <(GAMEPLAY_BITMAP + 4160)
        !byte <(GAMEPLAY_BITMAP + 4480)
        !byte <(GAMEPLAY_BITMAP + 4800)
        !byte <(GAMEPLAY_BITMAP + 5120)
        !byte <(GAMEPLAY_BITMAP + 5440)
        !byte <(GAMEPLAY_BITMAP + 5760)
        !byte <(GAMEPLAY_BITMAP + 6080)
        !byte <(GAMEPLAY_BITMAP + 6400)
        !byte <(GAMEPLAY_BITMAP + 6720)
        !byte <(GAMEPLAY_BITMAP + 7040)
        !byte <(GAMEPLAY_BITMAP + 7360)
        !byte <(GAMEPLAY_BITMAP + 7680)

BITMAP_ROW_HI:
        !byte >(GAMEPLAY_BITMAP + 0)
        !byte >(GAMEPLAY_BITMAP + 320)
        !byte >(GAMEPLAY_BITMAP + 640)
        !byte >(GAMEPLAY_BITMAP + 960)
        !byte >(GAMEPLAY_BITMAP + 1280)
        !byte >(GAMEPLAY_BITMAP + 1600)
        !byte >(GAMEPLAY_BITMAP + 1920)
        !byte >(GAMEPLAY_BITMAP + 2240)
        !byte >(GAMEPLAY_BITMAP + 2560)
        !byte >(GAMEPLAY_BITMAP + 2880)
        !byte >(GAMEPLAY_BITMAP + 3200)
        !byte >(GAMEPLAY_BITMAP + 3520)
        !byte >(GAMEPLAY_BITMAP + 3840)
        !byte >(GAMEPLAY_BITMAP + 4160)
        !byte >(GAMEPLAY_BITMAP + 4480)
        !byte >(GAMEPLAY_BITMAP + 4800)
        !byte >(GAMEPLAY_BITMAP + 5120)
        !byte >(GAMEPLAY_BITMAP + 5440)
        !byte >(GAMEPLAY_BITMAP + 5760)
        !byte >(GAMEPLAY_BITMAP + 6080)
        !byte >(GAMEPLAY_BITMAP + 6400)
        !byte >(GAMEPLAY_BITMAP + 6720)
        !byte >(GAMEPLAY_BITMAP + 7040)
        !byte >(GAMEPLAY_BITMAP + 7360)
        !byte >(GAMEPLAY_BITMAP + 7680)

; Fill an 8x8 character cell in the bitmap (solid white)
; Input: X = char column (0-39), Y = char row (0-24)
; Preserves X, Y
FILL_BITMAP_CELL:
        stx TEMP3
        sty TEMP4
        ; Get row base address
        lda BITMAP_ROW_LO, y
        sta SCREEN_LO
        lda BITMAP_ROW_HI, y
        sta SCREEN_HI
        ; Add column * 8 (handle overflow for columns >= 32)
        txa
        asl
        asl
        asl
        bcc +               ; No overflow if carry clear
        inc SCREEN_HI       ; Column >= 32, add 256 to address
+       clc
        adc SCREEN_LO
        sta SCREEN_LO
        bcc +
        inc SCREEN_HI
+       ; Fill 8 bytes with $FF
        ldy #0
        lda #$FF
-       sta (SCREEN_LO), y
        iny
        cpy #8
        bne -
        ldx TEMP3
        ldy TEMP4
        rts

; Clear an 8x8 character cell in the bitmap (black)
; Input: X = char column (0-39), Y = char row (0-24)
; Preserves X, Y
CLEAR_BITMAP_CELL:
        stx TEMP3
        sty TEMP4
        ; Get row base address
        lda BITMAP_ROW_LO, y
        sta SCREEN_LO
        lda BITMAP_ROW_HI, y
        sta SCREEN_HI
        ; Add column * 8 (handle overflow for columns >= 32)
        txa
        asl
        asl
        asl
        bcc +               ; No overflow if carry clear
        inc SCREEN_HI       ; Column >= 32, add 256 to address
+       clc
        adc SCREEN_LO
        sta SCREEN_LO
        bcc +
        inc SCREEN_HI
+       ; Clear 8 bytes to $00
        ldy #0
        lda #$00
-       sta (SCREEN_LO), y
        iny
        cpy #8
        bne -
        ldx TEMP3
        ldy TEMP4
        rts

; Set bitmap cell color at (X=column, Y=row)
; A = color byte (high nibble = foreground, low nibble = background)
; Screen RAM at $6000 + row * 40 + column
SET_BITMAP_COLOR:
        pha                     ; Save color
        stx TEMP3               ; Save column
        sty TEMP4               ; Save row
        ; Calculate screen RAM address: $6000 + Y * 40 + X
        ; Y*40 = Y*32 + Y*8
        tya
        asl
        asl
        asl                     ; A = Y * 8
        sta SCREEN_LO
        lda #0
        sta SCREEN_HI           ; Initialize high byte
        tya
        asl
        asl
        asl
        asl
        asl                     ; A = Y * 32 (low byte)
        clc
        adc SCREEN_LO           ; A = Y*32 + Y*8 = Y*40
        sta SCREEN_LO
        bcc +
        inc SCREEN_HI           ; Handle overflow from Y*40
+       tya
        lsr
        lsr
        lsr                     ; A = Y / 8 (high byte contribution from Y*32)
        clc
        adc SCREEN_HI           ; Add overflow from addition
        adc #>GAMEPLAY_SCREEN   ; Add high byte of $6000
        sta SCREEN_HI
        ; Add column
        txa
        clc
        adc SCREEN_LO
        sta SCREEN_LO
        bcc +
        inc SCREEN_HI
+       ; Store color
        pla                     ; Restore color
        ldy #0
        sta (SCREEN_LO), y
        ldx TEMP3
        ldy TEMP4
        rts

; Draw a character from charset into bitmap
; A = screen code, X = column (0-39), Y = row (0-24)
DRAW_BITMAP_CHAR:
        stx TEMP3
        sty TEMP4
        ; Calculate charset source address: CHARSET_RAM + screencode * 8
        ; Screen code in A
        ldx #0
        stx CHAR_PTR_HI
        asl
        rol CHAR_PTR_HI
        asl
        rol CHAR_PTR_HI
        asl
        rol CHAR_PTR_HI
        sta CHAR_PTR
        lda CHAR_PTR_HI
        clc
        adc #>CHARSET_RAM
        sta CHAR_PTR_HI
        ; Calculate bitmap destination: GAMEPLAY_BITMAP + row * 320 + col * 8
        ldy TEMP4                   ; row
        lda BITMAP_ROW_LO, y
        sta BITMAP_PTR
        lda BITMAP_ROW_HI, y
        sta BITMAP_PTR_HI
        lda TEMP3                   ; col
        asl
        asl
        asl
        bcc +
        inc BITMAP_PTR_HI
+       clc
        adc BITMAP_PTR
        sta BITMAP_PTR
        bcc +
        inc BITMAP_PTR_HI
+       ; Copy 8 bytes from charset to bitmap
        ldy #0
-       lda (CHAR_PTR), y
        sta (BITMAP_PTR), y
        iny
        cpy #8
        bne -
        ldx TEMP3
        ldy TEMP4
        rts

; ============================================================================
; HUD BITMAP ROUTINES
; ============================================================================

; Build HUD content into HUD_BUF (80 bytes = 2 rows of 40)
; and HUD_COLOR (80 bytes = colors for each cell)
UPDATE_HUD_BUF:
        ; Clear buffer with spaces and white-on-black color
        ldx #79
        lda #$20                    ; space screen code
@clr:   sta HUD_BUF, x
        dex
        bpl @clr
        ldx #79
        lda #$10                    ; white on black
@clrc:  sta HUD_COLOR, x
        dex
        bpl @clrc

        ; Row 0: "SCORE: " at col 0
        ldx #0
@sc:    lda SCORE_TXT, x
        beq @sc_done
        sta HUD_BUF, x
        inx
        bne @sc
@sc_done:
        ; Score digits at col 7
        lda SCORE_HI
        jsr BYTE_TO_DEC
        stx HUD_BUF + 7
        sty HUD_BUF + 8
        lda SCORE_MID
        jsr BYTE_TO_DEC
        stx HUD_BUF + 9
        sty HUD_BUF + 10
        lda SCORE_LO
        jsr BYTE_TO_DEC
        stx HUD_BUF + 11
        sty HUD_BUF + 12
        ; Color score cyan ($30)
        lda #$30
        ldx #5
@csc:   sta HUD_COLOR + 7, x
        dex
        bpl @csc

        ; "LEVEL: " at col 28
        ldx #0
@lv:    lda LEVEL_TXT, x
        beq @lv_done
        sta HUD_BUF + 28, x
        inx
        bne @lv
@lv_done:
        ; Level digits at col 35
        lda LEVEL
        jsr BYTE_TO_DEC
        stx HUD_BUF + 35
        sty HUD_BUF + 36
        ; Color level yellow ($70)
        lda #$70
        sta HUD_COLOR + 35
        sta HUD_COLOR + 36

        ; Row 1: "LIVES: " at col 0 (offset +40)
        ldx #0
@li:    lda LIVES_TXT, x
        beq @li_done
        sta HUD_BUF + 40, x
        inx
        bne @li
@li_done:
        ; Lives digit at col 7
        lda LIVES
        clc
        adc #$30
        sta HUD_BUF + 47
        ; Color lives green ($50)
        lda #$50
        sta HUD_COLOR + 47

        ; "FILL: " at col 22 (offset +40 = 62)
        ldx #0
@fi:    lda FILL_TXT, x
        beq @fi_done
        sta HUD_BUF + 62, x
        inx
        bne @fi
@fi_done:
        ; Fill "XX/YY%" at col 28 (offset +40 = 68)
        lda PERCENT_CLAIMED
        jsr BYTE_TO_DEC
        stx HUD_BUF + 68
        sty HUD_BUF + 69
        lda #$2F                    ; /
        sta HUD_BUF + 70
        lda TARGET_PERCENT
        jsr BYTE_TO_DEC
        stx HUD_BUF + 71
        sty HUD_BUF + 72
        lda #$25                    ; %
        sta HUD_BUF + 73
        ; Color fill pct green ($50)
        lda #$50
        sta HUD_COLOR + 68
        sta HUD_COLOR + 69
        rts

; Draw HUD_BUF to bitmap (rows 0-1, cols 0-39)
DRAW_HUD_BITMAP:
        ldx #0                      ; buffer index / column
        ldy #0                      ; row
@loop:  lda HUD_BUF, x
        jsr DRAW_BITMAP_CHAR
        lda HUD_COLOR, x
        jsr SET_BITMAP_COLOR
        inx
        cpx #40
        bne @loop
        ; Row 1
        ldx #0
        ldy #1
@loop2: lda HUD_BUF + 40, x
        jsr DRAW_BITMAP_CHAR
        lda HUD_COLOR + 40, x
        jsr SET_BITMAP_COLOR
        inx
        cpx #40
        bne @loop2
        rts

; Draw pixel-precise trail in bitmap cell
; X = char column, Y = char row
; Uses PREV_DRAW_DIR and PLAYER_DIR to determine shape
DRAW_TRAIL_BITMAP:
        stx TEMP3               ; Save char X
        sty TEMP4               ; Save char Y

        ; Calculate pixel coordinates for cell center
        ; Pixel X = char_X * 8 + 3 (center-ish)
        ; Pixel Y = char_Y * 8 + 3
        txa
        asl
        asl
        asl                     ; A = char_X * 8
        sta LINE_CUR_X
        lda #0
        sta LINE_CUR_X_HI
        ; Handle X >= 32 (X*8 >= 256)
        lda TEMP3
        cmp #32
        bcc +
        inc LINE_CUR_X_HI
+
        tya
        asl
        asl
        asl                     ; A = char_Y * 8
        sta LINE_CUR_Y

        ; Check if corner or straight line
        lda PREV_DRAW_DIR
        beq @straight           ; First tile, no previous direction
        cmp PLAYER_DIR
        beq @straight           ; Same direction = straight line

        ; It's a corner - draw L-shape
        ; Need to draw from entry edge to center, then center to exit edge
        jsr @draw_entry_half    ; Draw from entry edge to center
        jsr @draw_exit_half     ; Draw from center to exit edge
        jmp @done

@straight:
        ; Straight line - draw full line through cell
        lda PLAYER_DIR
        cmp #3
        bcs @horiz_line         ; 3=left, 4=right = horizontal

        ; Vertical line (up=1, down=2)
        ; Draw 4-pixel wide vertical line (columns 2-5)
        lda LINE_CUR_X
        clc
        adc #2
        sta LINE_CUR_X
        bcc +
        inc LINE_CUR_X_HI
+       jsr @draw_vline_8       ; Column 2
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       jsr @draw_vline_8       ; Column 3
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       jsr @draw_vline_8       ; Column 4
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       jsr @draw_vline_8       ; Column 5
        jmp @done

@horiz_line:
        ; Horizontal line (left=3, right=4)
        ; Draw 4-pixel wide horizontal line (rows 2-5)
        lda LINE_CUR_Y
        clc
        adc #2
        sta LINE_CUR_Y
        jsr @draw_hline_8       ; Row 2
        inc LINE_CUR_Y
        jsr @draw_hline_8       ; Row 3
        inc LINE_CUR_Y
        jsr @draw_hline_8       ; Row 4
        inc LINE_CUR_Y
        jsr @draw_hline_8       ; Row 5
        jmp @done

@draw_entry_half:
        ; Draw from entry edge to center based on PREV_DRAW_DIR
        lda PREV_DRAW_DIR
        cmp #1
        bne +
        jmp @entry_from_bottom  ; up = entering from bottom
+       cmp #2
        bne +
        jmp @entry_from_top     ; down = entering from top
+       cmp #3
        bne +
        jmp @entry_from_right   ; left = entering from right
+       ; right(4) = entering from left
@entry_from_left:
        ; Draw horizontal from left edge (x+0) to center (x+5), 4 pixels wide
        lda TEMP4
        asl
        asl
        asl
        clc
        adc #2
        sta LINE_CUR_Y          ; Start at row 2
        ldx #4                  ; 4 rows
@efl_loop:
        lda TEMP3
        asl
        asl
        asl
        sta LINE_CUR_X
        lda #0
        sta LINE_CUR_X_HI
        lda TEMP3
        cmp #32
        bcc +
        inc LINE_CUR_X_HI
+       txa
        pha
        jsr @draw_hline_6       ; Draw 6 pixels (to center)
        pla
        tax
        inc LINE_CUR_Y
        dex
        bne @efl_loop
        rts

@entry_from_right:
        ; Draw horizontal from center (x+2) to right edge, 4 pixels wide
        lda TEMP4
        asl
        asl
        asl
        clc
        adc #2
        sta LINE_CUR_Y          ; Start at row 2
        ldx #4                  ; 4 rows
@efr_loop:
        lda TEMP3
        asl
        asl
        asl
        clc
        adc #2                  ; Start at column 2
        sta LINE_CUR_X
        lda #0
        sta LINE_CUR_X_HI
        lda TEMP3
        cmp #32
        bcc +
        inc LINE_CUR_X_HI
+       txa
        pha
        jsr @draw_hline_6       ; Draw 6 pixels (center to edge)
        pla
        tax
        inc LINE_CUR_Y
        dex
        bne @efr_loop
        rts

@entry_from_top:
        ; Draw vertical from top edge (y+0) to center, 4 pixels wide
        lda TEMP3
        asl
        asl
        asl
        clc
        adc #2
        sta LINE_CUR_X          ; Start at column 2
        lda #0
        sta LINE_CUR_X_HI
        lda TEMP3
        cmp #32
        bcc +
        inc LINE_CUR_X_HI
+       ldx #4                  ; 4 columns
@eft_loop:
        lda TEMP4
        asl
        asl
        asl
        sta LINE_CUR_Y          ; Start at top edge
        txa
        pha
        jsr @draw_vline_6       ; Draw 6 pixels (edge to center)
        pla
        tax
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       dex
        bne @eft_loop
        rts

@entry_from_bottom:
        ; Draw vertical from center (y+2) to bottom edge, 4 pixels wide
        lda TEMP3
        asl
        asl
        asl
        clc
        adc #2
        sta LINE_CUR_X          ; Start at column 2
        lda #0
        sta LINE_CUR_X_HI
        lda TEMP3
        cmp #32
        bcc +
        inc LINE_CUR_X_HI
+       ldx #4                  ; 4 columns
@efb_loop:
        lda TEMP4
        asl
        asl
        asl
        clc
        adc #2                  ; Start at row 2 (center)
        sta LINE_CUR_Y
        txa
        pha
        jsr @draw_vline_6       ; Draw 6 pixels (center to edge)
        pla
        tax
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       dex
        bne @efb_loop
        rts

@draw_exit_half:
        ; Draw from center to exit edge based on PLAYER_DIR
        lda PLAYER_DIR
        cmp #1
        beq @exit_to_top        ; up = exiting to top
        cmp #2
        beq @exit_to_bottom     ; down = exiting to bottom
        cmp #3
        beq @exit_to_left       ; left = exiting to left
        ; right(4) = exiting to right
        jmp @entry_from_right   ; Same as entry from right (center to right edge)

@exit_to_left:
        jmp @entry_from_left    ; Same as entry from left (left edge to center)

@exit_to_top:
        jmp @entry_from_top     ; Same as entry from top (top edge to center)

@exit_to_bottom:
        jmp @entry_from_bottom  ; Same as entry from bottom (center to bottom)

@draw_hline_8:
        ; Draw 8 horizontal pixels starting at (LINE_CUR_X, LINE_CUR_Y)
        ldx #8
@hl8:   txa
        pha                     ; Save loop counter (PLOT_PIXEL corrupts X)
        jsr PLOT_PIXEL
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       pla
        tax                     ; Restore loop counter
        dex
        bne @hl8
        ; Restore X position
        sec
        lda LINE_CUR_X
        sbc #8
        sta LINE_CUR_X
        bcs +
        dec LINE_CUR_X_HI
+       rts

@draw_hline_4:
        ; Draw 4 horizontal pixels
        ldx #4
@hl4:   txa
        pha                     ; Save loop counter
        jsr PLOT_PIXEL
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       pla
        tax                     ; Restore loop counter
        dex
        bne @hl4
        rts

@draw_hline_6:
        ; Draw 6 horizontal pixels (for corners - edge to center)
        ldx #6
@hl6:   txa
        pha
        jsr PLOT_PIXEL
        inc LINE_CUR_X
        bne +
        inc LINE_CUR_X_HI
+       pla
        tax
        dex
        bne @hl6
        rts

@draw_vline_8:
        ; Draw 8 vertical pixels starting at (LINE_CUR_X, LINE_CUR_Y)
        ldx #8
@vl8:   txa
        pha                     ; Save loop counter
        jsr PLOT_PIXEL
        inc LINE_CUR_Y
        pla
        tax                     ; Restore loop counter
        dex
        bne @vl8
        ; Restore Y position
        sec
        lda LINE_CUR_Y
        sbc #8
        sta LINE_CUR_Y
        rts

@draw_vline_4:
        ; Draw 4 vertical pixels
        ldx #4
@vl4:   txa
        pha                     ; Save loop counter
        jsr PLOT_PIXEL
        inc LINE_CUR_Y
        pla
        tax                     ; Restore loop counter
        dex
        bne @vl4
        rts

@draw_vline_6:
        ; Draw 6 vertical pixels (for corners - edge to center)
        ldx #6
@vl6:   txa
        pha
        jsr PLOT_PIXEL
        inc LINE_CUR_Y
        pla
        tax
        dex
        bne @vl6
        rts

@done:
        ldx TEMP3
        ldy TEMP4
        rts

; Pixel bitmasks (bit 7 = leftmost pixel in byte)
PIXEL_MASKS:
        !byte %10000000, %01000000, %00100000, %00010000
        !byte %00001000, %00000100, %00000010, %00000001

; Plot a pixel at (LINE_CUR_X, LINE_CUR_Y)
; Uses BITMAP_PTR as temp pointer
PLOT_PIXEL:
        ; Calculate bitmap address
        ; Address = $4000 + (Y/8)*320 + (Y AND 7) + (X/8)*8

        ; Get char row (Y / 8)
        lda LINE_CUR_Y
        lsr
        lsr
        lsr                     ; A = char_row (0-24)
        tay

        ; Get row base address
        lda BITMAP_ROW_LO, y
        sta BITMAP_PTR
        lda BITMAP_ROW_HI, y
        sta BITMAP_PTR_HI

        ; Add (Y AND 7) - pixel row within char
        lda LINE_CUR_Y
        and #$07
        clc
        adc BITMAP_PTR
        sta BITMAP_PTR
        bcc +
        inc BITMAP_PTR_HI
+
        ; Add (X / 8) * 8 = X AND $F8
        ; But X is 16-bit, so handle high byte
        lda LINE_CUR_X
        and #$F8
        clc
        adc BITMAP_PTR
        sta BITMAP_PTR
        lda LINE_CUR_X_HI
        adc BITMAP_PTR_HI
        sta BITMAP_PTR_HI

        ; Get pixel mask (X AND 7)
        lda LINE_CUR_X
        and #$07
        tax
        lda PIXEL_MASKS, x

        ; Set the pixel
        ldy #0
        ora (BITMAP_PTR), y
        sta (BITMAP_PTR), y
        rts

; Draw line from (LINE_X1, LINE_Y1) to (LINE_X2, LINE_Y2)
; Bresenham's line algorithm
DRAW_LINE:
        ; Initialize current position
        lda LINE_X1
        sta LINE_CUR_X
        lda LINE_X1_HI
        sta LINE_CUR_X_HI
        lda LINE_Y1
        sta LINE_CUR_Y

        ; Calculate dx = abs(x2 - x1)
        sec
        lda LINE_X2
        sbc LINE_X1
        sta LINE_DX
        lda LINE_X2_HI
        sbc LINE_X1_HI
        sta LINE_DX_HI

        ; If dx negative, negate it and set sx = -1
        bpl @dx_pos
        ; Negate dx
        lda #0
        sec
        sbc LINE_DX
        sta LINE_DX
        lda #0
        sbc LINE_DX_HI
        sta LINE_DX_HI
        lda #$FF                ; sx = -1
        sta LINE_SX
        bne @dx_done
@dx_pos:
        lda #$01                ; sx = 1
        sta LINE_SX
@dx_done:

        ; Calculate dy = -abs(y2 - y1)
        sec
        lda LINE_Y2
        sbc LINE_Y1
        sta LINE_DY
        bpl @dy_pos
        ; dy is negative, negate to get abs
        lda #0
        sec
        sbc LINE_DY
        sta LINE_DY
        lda #$FF                ; sy = -1
        sta LINE_SY
        jmp @dy_done
@dy_pos:
        lda #$01                ; sy = 1
        sta LINE_SY
@dy_done:
        ; Now negate dy (Bresenham uses -abs(dy))
        lda #0
        sec
        sbc LINE_DY
        sta LINE_DY

        ; err = dx + dy (dy is already negative)
        clc
        lda LINE_DX
        adc LINE_DY
        sta LINE_ERR
        lda LINE_DX_HI
        adc #$FF                ; Sign extend dy (which is negative)
        sta LINE_ERR_HI

        ; If LINE_DY was 0, high byte should be from dx only
        lda LINE_DY
        bne @err_ok
        lda LINE_DX_HI
        sta LINE_ERR_HI
@err_ok:

@loop:
        ; Plot current pixel
        jsr PLOT_PIXEL

        ; Check if we've reached the end
        lda LINE_CUR_X
        cmp LINE_X2
        bne @not_done
        lda LINE_CUR_X_HI
        cmp LINE_X2_HI
        bne @not_done
        lda LINE_CUR_Y
        cmp LINE_Y2
        bne @not_done
        rts                     ; Done!

@not_done:
        ; e2 = 2 * err (store in TEMP1/TEMP2)
        lda LINE_ERR
        asl
        sta TEMP1
        lda LINE_ERR_HI
        rol
        sta TEMP2

        ; if e2 >= dy (remember dy is negative, so this is e2 > dy)
        ; Compare TEMP1/2 with LINE_DY (sign-extended)
        ; Since dy is negative 8-bit stored in LINE_DY, sign extend to compare
        lda TEMP2
        bmi @check_dy           ; e2 is negative
        ; e2 is positive or zero, dy is negative, so e2 >= dy
        jmp @do_dy_branch
@check_dy:
        ; Both negative, compare magnitudes
        lda LINE_DY
        beq @do_dy_branch       ; dy=0, always branch
        ; LINE_DY is -abs(dy), TEMP1/2 is 2*err
        ; We want: 2*err >= dy (where dy is negative)
        ; i.e., 2*err >= -abs(original_dy)
        sec
        lda TEMP1
        sbc LINE_DY
        lda TEMP2
        sbc #$FF                ; Sign extend LINE_DY
        bpl @do_dy_branch       ; If result >= 0, take branch
        jmp @skip_dy

@do_dy_branch:
        ; err += dy
        clc
        lda LINE_ERR
        adc LINE_DY
        sta LINE_ERR
        lda LINE_ERR_HI
        adc #$FF                ; Sign extend dy
        sta LINE_ERR_HI

        ; x += sx
        lda LINE_SX
        bmi @dec_x
        ; Increment x
        inc LINE_CUR_X
        bne @skip_dy
        inc LINE_CUR_X_HI
        jmp @skip_dy
@dec_x:
        ; Decrement x
        lda LINE_CUR_X
        bne +
        dec LINE_CUR_X_HI
+       dec LINE_CUR_X

@skip_dy:
        ; if e2 <= dx
        ; TEMP1/2 still has 2*err
        sec
        lda LINE_DX
        sbc TEMP1
        lda LINE_DX_HI
        sbc TEMP2
        bmi @loop               ; dx < e2, skip

        ; err += dx
        clc
        lda LINE_ERR
        adc LINE_DX
        sta LINE_ERR
        lda LINE_ERR_HI
        adc LINE_DX_HI
        sta LINE_ERR_HI

        ; y += sy
        lda LINE_SY
        bmi @dec_y
        inc LINE_CUR_Y
        jmp @loop
@dec_y:
        dec LINE_CUR_Y
        jmp @loop

; ============================================================================
; TITLE SCREEN BITMAP DATA
; ============================================================================

!source "title_data.asm"

; ============================================================================
; END
; ============================================================================
