; acme --strict-segments -f cbm -o aipocalypse.prg aipocalypse.asm
; Fully self-contained: no external assets needed to assemble.
; Font: https://github.com/mwenge/attackofthemutantcamels
; AIPOCALYPSE / C64 PAL / ACME
; SID: Rob Hubbard, One Man and his Droid, HVSC original, subtune 1.
; Sources:
; https://csdb.dk/sid/?id=14334
; https://www.hvsc.c64.org/download/C64Music/MUSICIANS/H/Hubbard_Rob/One_Man_and_his_Droid.sid
; https://www.zimmers.net/cbmpics/cbm/c64/vic-ii.txt
; https://codebase.c64.org/doku.php?id=base:sprite_multiplexing
;
; Foreground work starts at frame commit, is interrupted by the two
; stable sprite kernels and by the rasterbar kernel. The next colour
; table is only built after the current table has been consumed.

MODE=0
yl=$e0
yh=$e1
vl=$e2
vh=$e3
cb=$e4
cbo=$e5
u=$e6
xs=$e7
mp=$e8
t0=$ea
t1=$eb
t2=$ec
buf=$ed
fc=$ee
fine=$ef
yhi=$f0
side=$f1
ct=$f2
cto=$f3
nextirq=$f4
spritey=$f5
spriteptr=$f6
fp=$f7
phase=$fa
tmp=$fb
cnt=$fc
base=$fd
syncfirst=$fe

GRAV=$0020
FLOOR=280
NBARS=7
GAP=11
SPEED=2
SPR_A=$2800
SPR_B=$2a00
FONT=$3000
TABLE=$2000
D11=$2300
INK=6
LOGO=$2c00
LOGOTOP=18
LOGOWIDTH=11*16
LOGORIGHT=384-LOGOWIDTH
FRAMEIRQ=300

*=$0801
!byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,0,0,0
        jmp start

*=$8000
start   sei
        lda #$35 : sta $01
        lda #$7f : sta $dc0d : sta $dd0d
        lda $dc0d : lda $dd0d
        lda $dd00 : ora #3 : sta $dd00
        lda #$1b : sta $d011
        lda #$c8 : sta $d016
        lda #$1c : sta $d018
        lda #0
        sta $d020 : sta $d021 : sta $3fff
        sta $d015 : sta $d017 : sta $d01b : sta $d01c
        sta yl : sta vl : sta buf : sta fc : sta fine : sta xs
        sta work : sta tablefree : sta lateframes
        sta logoylo : sta logoxlo : sta logovyl : sta logovxl
        lda #$fe : sta phase
        ldx #0
        lda #0
-       sta SPR_A,x : sta SPR_A+$100,x
        sta SPR_B,x : sta SPR_B+$100,x
        sta TABLE,x : sta incoming,x
        lda #$0b : sta D11,x
        lda #0
        inx : bne -
        lda #$ff : sta $d01d
        !for n,0,7 {
            lda #LOGO/64+n : sta $0bf8+n
        }
        lda #<msg : sta mp
        lda #>msg : sta mp+1
        lda #<FLOOR : sta yh
        lda #>FLOOR : sta yhi
        lda #$fb : sta vh
        lda #LOGOTOP : sta logoy
        lda #48 : sta logox
        lda #2 : sta logovyh : sta logovxh
        lda #0 : jsr $1000
        jsr prepare
        lda cb : sta cbo
        lda ct : sta cto
        jsr draw_bars
        lda #1 : sta ready
        ; Open vertical border once. Subsequent frames never close it.
-       lda $d011 : bpl -
-       lda $d011 : bmi -
-       lda $d012 : cmp #60 : bne -
        lda #$0b : sta $d011
        lda #<border_boot : sta $fffe
        lda #>border_boot : sta $ffff
        lda #248 : sta $d012
        lda #1 : sta $d01a
        lda #$0f : sta $d019
        cli
main    lda work : beq main
        lda #0 : sta work : sta ready
        jsr $1012
        inc musiccalls
        bne +
        inc musiccalls+1
+       jsr prepare
-       lda tablefree : beq -
        jsr draw_bars
        lda #1 : sta ready
frame_done
        jmp main

border_boot
        pha
        lda #$83 : sta $d011
        lda #<frameirq : sta $fffe
        lda #>frameirq : sta $ffff
        lda #<FRAMEIRQ : sta $d012
        asl $d019
        pla
        rti

; Commit at line 300, after the previous scroller DMA and before frame wrap.
frameirq
        pha : txa : pha : tya : pha
        lda ready : bne +
        inc lateframes
+       lda #0 : sta $d015 : sta tablefree
        lda #$0b : sta $d011
        lda spritey : sta texty
        lda textirqlo : sta curtextirq
        lda textirqhi : sta curtexthi
        lda textfirstd11 : sta textirq1d11+1
        lda textsecondd11 : sta textirq2d11+1
        lda d11bank : sta textd11+1
        sta textd11first+1 : sta textd11second+1
        lda border_mode : sta curborder
        lda text_near : sta curnear
        lda ct : sec : sbc #1 : sta firstx+1
        lda cb : clc : adc #1 : sta endc+1
        lda #<bar_far : sta bar_exit+1
        lda #>bar_far : sta bar_exit+2
        lda text_near : beq +
        lda spritey : sec : sbc #1 : sta endc+1
        lda #<bar_near : sta bar_exit+1
        lda #>bar_near : sta bar_exit+2
+
        !for n,0,7 {
            lda textx+n : sta textxcopy+n
            lda spriteptr : clc : adc #n : sta $07f8+n
        }
        lda nextcolor : sta textcolor
        sta text_firstcolor+1 : sta text_secondcolor+1
        lda logoy : sec : sbc #8
        !for n,0,7 { sta $d001+n*2 }
        lda logoy : clc : adc #13
        sta logo_last_index+1 : sta bar_chain_x+1
        lda #<logo_done : sta logo_last_exit+1
        lda #>logo_done : sta logo_last_exit+2
        lda ct : sec : sbc #22
        cmp logoy : bcs +
        lda #<bar_chain : sta logo_last_exit+1
        lda #>bar_chain : sta logo_last_exit+2
+
        lda logocolor : sta logo_firstcolor+1
        lda #0
        !for n,0,7 { sta $d027+n }
        !for n,0,7 {
            lda logoxpos+n : sta $d000+n*2
        }
        lda logoxmsb : sta $d010
        lda #$2c : sta $d018
        lda ct : sec : sbc #3 : sta currentbarirq
        lda logoy : sec : sbc #11 : sta $d012
        lda #<logo_irq1 : sta $fffe
        lda #>logo_irq1 : sta $ffff
        lda #1 : sta work
        inc frames
        bne +
        inc frames+1
+       asl $d019
        pla : tay : pla : tax : pla
        rti

!align 255,0
logo_irq1
        sta sa : stx sx : sty sy
        lda #<logo_irq2 : sta $fffe
        lda #>logo_irq2 : sta $ffff
        inc $d012
        asl $d019
        tsx : cli
        !for n,1,16 { nop }
logo_irq2
        txs
        ldx #8
-       dex : bne -
        bit $ea
        lda $d012 : cmp $d012 : beq +
+       !for n,1,21 { nop }
        bit $ea
        ; Same phase as endrender: previous raster, monitor cycle 57.
        bit $ea : nop : nop : nop
logo_render
        lda #0 : sta $d020 : sta $d021
        lda #$ff : sta $d015
        ldx #0
        !for n,1,19 { nop }
logo_first
        ; Mask the stale shift-register pixels on the DMA start line.
        dec $d016
        inc $d016
logo_firstcolor
        lda #2
        !for n,0,3 { sta $d027+n }
        inx
        !for n,1,7 { nop }
logo_side
        dec $d016
        inc $d016
        inx : cpx #21 : beq logo_last
        bit $ea
        !for n,1,11 { nop }
        jmp logo_side
logo_last
        ; Row 20's data are now fetched. One final border opening shows
        ; the bottom ink row, without sprite DMA, on the contact scanline.
logo_last_index
        ldy #0
        lda TABLE,y
        bit $ea
        !for n,1,9 { nop }
        dec $d016
        inc $d016
        ; INC completes at cycle 62. Both colour writes finish before
        ; the next line's left visible edge, including at actual contact.
        sta $d020
        sta $d021
logo_last_exit
        jmp logo_done
logo_done
        lda #0 : sta $d015
        ; Switch the sprite pointer table without an eight-pointer loop.
        lda #$1c : sta $d018
        lda texty
        !for n,0,7 { sta $d001+n*2 }
        !for n,0,7 {
            lda textxcopy+n : sta $d000+n*2
        }
        lda #$c1 : sta $d010
        lda #0
        !for n,0,7 { sta $d027+n }
        lda #<bar_irq1 : sta $fffe
        lda #>bar_irq1 : sta $ffff
        lda currentbarirq : sta $d012
        asl $d019
        lda sa : ldx sx : ldy sy
        rti

; When the logo touches the bars, there is no room for a separate IRQ
; and sprite reconfiguration in the black gap. Continue in cycle phase
; directly into the colour kernel; restore text registers in its padding.
bar_chain
        lda #0
        sta $d015
bar_chain_x
        ldx #0
        sta TABLE,x
        inx
        lda TABLE,x : ldy D11,x
        !for n,1,11 { nop }
        jmp bar_setup_0

; Each setup row is exactly 63 cycles: 21 + 29 + 8 + 5.
; X stays the colour-table raster index throughout.
!macro setup_head {
        sta $d020 : sta $d021 : sty $d011
        lda #0 : sta TABLE,x
        inx
}
!macro setup_tail .next {
        lda TABLE,x : ldy D11,x
        nop
        jmp .next
}
bar_setup_0
        +setup_head
        lda #$1c : sta $d018
        lda #$c1 : sta $d010
        lda #0 : sta $d027 : sta $d028
        bit $ea : nop : nop
        +setup_tail bar_setup_1
bar_setup_1
        +setup_head
        lda #0 : sta $d029 : sta $d02a
        lda texty : sta $d001 : sta $d003 : sta $d005
        bit $ea
        +setup_tail bar_setup_2
bar_setup_2
        +setup_head
        lda texty
        sta $d007 : sta $d009 : sta $d00b : sta $d00d : sta $d00f
        bit $ea : nop
        +setup_tail bar_setup_3
bar_setup_3
        +setup_head
        !for n,0,2 { lda textxcopy+n : sta $d000+n*2 }
        bit $ea : nop
        +setup_tail bar_setup_4
bar_setup_4
        +setup_head
        !for n,3,5 { lda textxcopy+n : sta $d000+n*2 }
        bit $ea : nop
        +setup_tail bar_setup_5
bar_setup_5
        +setup_head
        !for n,6,7 { lda textxcopy+n : sta $d000+n*2 }
        bit $ea
        !for n,1,5 { nop }
        +setup_tail bar_loop

!align 255,0
bar_irq1
        sta sa : stx sx : sty sy
        lda #<bar_irq2 : sta $fffe
        lda #>bar_irq2 : sta $ffff
        inc $d012
        asl $d019
        tsx : cli
        !for n,1,16 { nop }
bar_irq2
        txs
        ldx #8
-       dex : bne -
        bit $ea
        lda $d012 : cmp $d012 : beq +
+       !for n,1,21 { nop }
        bit $ea
firstx  ldx #0
        lda TABLE,x
        ldy D11,x
bar_loop
        sta $d020 : sta $d021 : sty $d011
        lda #0 : sta TABLE,x
        inx
        lda TABLE,x : ldy D11,x
        !for n,1,13 { nop }
        bit $ea
endc    cpx #0
        bne bar_loop
        ; Branch-free patched jump keeps the near-text path in phase.
bar_exit
        jmp bar_far
bar_far
        lda #0 : sta $d020 : sta $d021
        lda #1 : sta tablefree
        lda curborder : cmp #2 : beq arm_border
        jsr arm_text
        jmp restore

; With a close scroller, continue directly from the colour kernel.
; The colour loop's final comparison is patched to spriteY-1.
bar_near
        ; Three cycles of JMP are balanced by three fewer entry cycles.
        lda #0 : sta $d020 : sta $d021
        lda #$ff : sta $d015
        ldx #0
        !for n,1,12 { nop }
        jmp text_first

arm_border
        lda curborder : cmp #2 : beq arm_border_before
        lda #<border_after : sta $fffe
        lda #>border_after : sta $ffff
        jmp arm_border_time
arm_border_before
        lda #<border_before : sta $fffe
        lda #>border_before : sta $ffff
arm_border_time
        lda #250 : sta $d012
        lda #$0b : sta $d011
        asl $d019
        jmp restore

arm_text
        lda #<text_irq1 : sta $fffe
        lda #>text_irq1 : sta $ffff
        lda curtextirq : sta $d012
        lda curtexthi : sta $d011
        asl $d019
        rts

!align 255,0
text_irq1
        sta sa : stx sx : sty sy
        lda #<text_irq2 : sta $fffe
        lda #>text_irq2 : sta $ffff
        inc $d012
textirq1d11
        lda #$0b : sta $d011
        asl $d019
        tsx : cli
        !for n,1,16 { nop }
text_irq2
        txs
textirq2d11
        lda #$0b : sta $d011
        ldx #8
-       dex : bne -
        bit $ea
        lda $d012 : cmp $d012 : beq +
+       !for n,1,18 { nop }
        bit $ea
        bit $ea : nop : nop : nop
text_render
        lda #0 : sta $d020 : sta $d021
        lda #$ff : sta $d015
        ldx #0
        bit $ea
        !for n,1,13 { nop }
text_first
textd11first
        lda $2400,x
        sta $d011
        dec $d016
        inc $d016
text_firstcolor
        lda #6
        !for n,0,3 { sta $d027+n }
        inx
        nop : nop : nop
textd11second
        lda $2400,x
        sta $d011
        dec $d016
        inc $d016
text_secondcolor
        lda #6
        !for n,4,7 { sta $d027+n }
        inx
        nop : nop : nop
text_side
textd11 lda $2400,x
        sta $d011
        dec $d016
        inc $d016
        inx : cpx #21 : beq text_done
        bit $ea
        !for n,1,7 { nop }
        jmp text_side
text_done
        lda #0 : sta $d015
        lda #1 : sta tablefree
        lda curborder : bne +
        jmp arm_border
+       
        lda #$83 : sta $d011
arm_frame
        lda #<frameirq : sta $fffe
        lda #>frameirq : sta $ffff
        lda #<FRAMEIRQ : sta $d012
        asl $d019
restore lda sa : ldx sx : ldy sy
        rti

border_after
        pha
        lda #$83 : sta $d011
        lda #<frameirq : sta $fffe
        lda #>frameirq : sta $ffff
        lda #<FRAMEIRQ : sta $d012
        asl $d019
        pla
        rti
border_before
        pha
        lda curtexthi : sta $d011
        lda #<text_irq1 : sta $fffe
        lda #>text_irq1 : sta $ffff
        lda curtextirq : sta $d012
        asl $d019
        pla
        rti

prepare
        lda phase : clc : adc #SPEED : sta phase : sta tmp
        lda #0 : sta cb
        lda #255 : sta ct
        ldx #0
-       ldy tmp
        lda sin,y : sta bary,x
        cmp ct : bcs +
        sta ct
+       clc : adc #16
        cmp cb : bcc +
        sta cb
+       lda tmp : clc : adc #GAP : sta tmp
        inx : cpx #7 : bne -
        jsr phys
        jsr logo_phys
        lda fine : eor #1 : sta fine
        beq no_shift
        jsr glyph
        lda buf : eor #1 : sta buf
        beq make_a
        jsr shift_a_b : jmp no_shift
make_a  jsr shift_b_a
no_shift
        lda buf : beq ptr_a
        lda #SPR_B/64 : bne ptr_done
ptr_a   lda #SPR_A/64
ptr_done
        sta spriteptr
        inc fc
        lda fc : lsr : and #15 : tax
        lda fadetab,x : sta nextcolor
        lda fc : lsr : and #7 : tax
        lda redtab,x : sta logocolor
        lda yh : sec : sbc #3 : sta spritey
        lda yhi : sbc #0 : sta spritehi
        lda spritey : sec : sbc #3 : sta textirqlo
        lda spritehi : sbc #0 : sta textirqhi
        ; IRQ compare high bit, preserving the border state at that time.
        lda textirqhi : beq +
        lda #$80
+       ora #$0b : sta textirqhi
        lda spritehi : beq low_sprite
        lda #$03 : bne after248
low_sprite
        lda spritey : cmp #251 : bcc before248
        lda #$03 : bne after248
before248
        lda #$0b
after248
        sta textfirstd11
        lda spritehi : beq +
        lda spritey : cmp #2 : bcc +
        lda textfirstd11 : ora #$80 : sta textfirstd11
+       lda #$0b
        ldx spritehi : bne pre03
        ldx spritey : cpx #250 : bcc +
pre03   lda #$03
+       sta textsecondd11
        ; Border 250 before text (2), integrated (1), or after text (0).
        lda #2
        ldx spritehi : bne got_border
        ldx spritey : cpx #254 : bcs got_border
        lda #1
        cpx #227 : bcs got_border
        lda #0
got_border
        sta border_mode
        cmp #2 : bne +
        lda textirqhi : and #$80 : ora #$03 : sta textirqhi
+       lda fc : and #1 : asl : asl : asl : asl : asl : sta d11bank
        tax
        lda spritey : sta t0
        lda spritehi : sta t1
        ldy #21
-       lda #$0b
        bit t1 : bne seq03
        lda t0 : cmp #248 : bcc seq0b
seq03   lda #$03 : bne seqstore
seq0b   lda #$0b
seqstore
        sta $2400,x
        inc t0 : bne +
        inc t1
+       inx : dey : bne -
        !for n,0,7 {
            lda xpos+n : clc : adc fine : sta textx+n
        }
        lda #0 : sta logoxmsb
        ; VIC horizontal wrap is 504, not 512. Only sprite zero wraps.
        lda logox : sec : sbc #8 : bcs logo_base_ok
        sec : sbc #8
        ldx #1 : stx logoxmsb
logo_base_ok
        sta logoxpos
        !for n,1,3 {
            lda logox : clc : adc #(n*48-8) : sta logoxpos+n
            bcc +
            lda logoxmsb : ora #(1<<n) : sta logoxmsb
+
        }
        lda #0
        !for n,4,7 { sta logoxpos+n }
        ; This selection is committed separately at frame start.
        lda #0 : sta text_near
        lda spritehi : bne prep_done
        lda cb : clc : adc #9 : cmp spritey : bcc prep_done
        lda #1 : sta text_near
prep_done
        rts

draw_bars
        lda #0 : sta base
        ldx #0
draw_next
        ldy bary,x
        stx draw_index
        ldx base
        !for n,0,15 {
            lda grad+n,x : sta TABLE+n,y
        }
        lda base : clc : adc #16 : sta base
        ldx draw_index : inx : cpx #7 : bne draw_next
        rts

logo_phys
        ; Gravity toward the rasterbars; a moving upper surface kicks up.
        lda ct : sec : sbc cto : sta u
        lda ct : sta cto
        lda logovyl : clc : adc #$20 : sta logovyl
        lda logovyh : adc #0 : sta logovyh
        bpl +
        cmp #$f9 : bcs logo_vready
        lda #$f9 : sta logovyh
        lda #0 : sta logovyl
        jmp logo_vready
+       cmp #7 : bcc logo_vready
        lda #6 : sta logovyh
logo_vready
        lda logoylo : clc : adc logovyl : sta logoylo
        lda logoy : adc logovyh : sta logoy
        cmp #LOGOTOP : bcs logo_floor
        lda #LOGOTOP : sta logoy
        lda #0 : sta logoylo
        lda logovyh : bpl logo_floor
        lda #0 : sec : sbc logovyl : sta logovyl
        lda #0 : sbc logovyh : sta logovyh
logo_floor
        ; Last visible logo row is logoy+13; first visible bar is ct+1.
        ; Contact means these adjacent scanlines have no black gap.
        lda ct : sec : sbc #13 : sta t0
        lda logoy : cmp t0 : bcc logo_horizontal
        lda t0 : sta logoy
        lda #0 : sta logoylo
        lda logovyh : sec : sbc u : bmi logo_horizontal
        lda u : asl : sta t1
        lda #0 : sec : sbc logovyl : sta logovyl
        lda t1 : sbc logovyh : sta logovyh
        bmi logo_horizontal
        lda #$fd : sta logovyh
        lda #0 : sta logovyl
logo_horizontal
        ; Acceleration follows travel direction, with a speed limit.
        lda logovxh : bmi logo_accel_left
        lda logovxl : clc : adc #6 : sta logovxl
        lda logovxh : adc #0 : sta logovxh
        cmp #4 : bcc logo_xadd
        lda #3 : sta logovxh
        jmp logo_xadd
logo_accel_left
        lda logovxl : sec : sbc #6 : sta logovxl
        lda logovxh : sbc #0 : sta logovxh
        cmp #$fc : bcs logo_xadd
        lda #$fc : sta logovxh
logo_xadd
        lda logoxlo : clc : adc logovxl : sta logoxlo
        lda logox : adc logovxh : sta logox
        ldx logovxh : bpl logo_right
        cmp #240 : bcc logo_hdone
        lda #0 : sta logox : sta logoxlo
        lda #2 : sta logovxh
        lda #0 : sta logovxl
        rts
logo_right
        cmp #LOGORIGHT : bcc logo_hdone
        lda #LOGORIGHT : sta logox
        lda #0 : sta logoxlo : sta logovxl
        lda #$fe : sta logovxh
logo_hdone
        rts

phys    lda cb : sec : sbc cbo : sta u
        lda cb : sta cbo
        !if MODE=1 {
            lda side : beq gravity_down
            lda ct : sec : sbc cto : sta u
            lda vl : sec : sbc #<GRAV : sta vl
            lda vh : sbc #>GRAV : sta vh
            jmp gravity_done
        }
gravity_down
        lda vl : clc : adc #<GRAV : sta vl
        lda vh : adc #>GRAV : sta vh
gravity_done
        lda ct : sta cto
        lda vh : bmi vnegative
        cmp #8 : bcc vready
        lda #7 : sta vh : lda #$ff : sta vl
        jmp vready
vnegative
        cmp #$f9 : bcs vready
        lda #$f9 : sta vh : lda #0 : sta vl
vready  lda #0
        ldx vh : bpl +
        lda #$ff
+       sta t2
        lda yl : clc : adc vl : sta yl
        lda yh : adc vh : sta yh
        lda yhi : adc t2 : sta yhi
        !if MODE=1 {
            ; Il testo scompare fuori dall'area PAL visibile prima del wrap.
            lda yhi : bmi wrap_up
            bne check_wrap_down
            lda yh : cmp #TOP : bcc wrap_up
            jmp no_wrap
check_wrap_down
            lda yh : cmp #<WRAPBOTTOM : bcc no_wrap
wrap_down
            lda yh : sec : sbc #<PERIOD : sta yh
            lda yhi : sbc #>PERIOD : sta yhi
            lda #1 : sta side
            lda #7 : sta vh : lda #0 : sta vl
            rts
wrap_up
            lda yh : clc : adc #<PERIOD : sta yh
            lda yhi : adc #>PERIOD : sta yhi
            lda #0 : sta side
            lda #$f9 : sta vh : lda #0 : sta vl
            rts
no_wrap
            lda side : beq below
            ; La superficie superiore respinge il testo verso l'alto.
            lda ct : sec : sbc #11 : sta t0
            lda yh : cmp t0 : bcc phys_done
            lda t0 : sta yh
            lda #0 : sta yl : sta yhi
            lda u : bmi upper_impact
            ; Se la superficie si allontana, accompagna il testo senza
            ; lanciarlo fuori. La spinta arriva quando la raster risale.
            sta vh : lda #0 : sta vl
            rts
upper_impact
            lda vh : sec : sbc u : bvc +
            eor #$80
+           bmi phys_done
            jsr reflect
            lda vh : bmi phys_done
            lda #$fd : sta vh : lda #0 : sta vl
            rts
        }
below   lda yhi : bne floor_check
        lda cb : clc : adc #4 : sta t0
        lda yh : cmp t0 : bcs floor_check
        lda t0 : sta yh : lda #0 : sta yl
        !if MODE=1 {
            lda u : beq follow_lower : bmi follow_lower
            jmp lower_impact
follow_lower
            sta vh : lda #0 : sta vl
            rts
lower_impact
        }
        lda vh : sec : sbc u : bvc +
        eor #$80
+       bpl floor_check
        jsr reflect
        !if MODE=1 {
            lda vh : bpl floor_check
            lda #3 : sta vh : lda #0 : sta vl
        }
floor_check
        !if MODE=0 {
            lda yhi : beq phys_done
            lda yh : cmp #<FLOOR : bcc phys_done
            lda #<FLOOR : sta yh
            lda #>FLOOR : sta yhi
            lda #0 : sta yl
            lda vh : bmi phys_done
            sta t1 : lda vl : sta t2
            lsr t1 : ror t2 : lsr t1 : ror t2 : lsr t1 : ror t2
            lda vl : sec : sbc t2 : sta vl
            lda vh : sbc t1 : sta vh
            cmp #6 : bcs negate
            lda #6 : sta vh : lda #0 : sta vl
negate      lda #0 : sec : sbc vl : sta vl
            lda #0 : sbc vh : sta vh
        }
phys_done
        rts

reflect lda u : asl : sta t1
        lda #0 : sec : sbc vl : sta vl
        lda t1 : sbc vh : sta vh
        rts

; Ogni 8 frame prepara la prossima colonna di 8 pixel del messaggio.
glyph   dec xs : bpl glyph_done
        lda #7 : sta xs
        ldy #0
        lda (mp),y : cmp #$ff : bne +
        lda #<msg : sta mp
        lda #>msg : sta mp+1
        lda (mp),y
+       ldx #0 : stx fp+1
        asl : rol fp+1 : asl : rol fp+1 : asl : rol fp+1
        sta fp
        lda fp+1 : clc : adc #>FONT : sta fp+1
        ldy #7
-       lda (fp),y : sta incoming,y
        dey : bpl -
        inc mp : bne glyph_done
        inc mp+1
glyph_done
        rts



sa !byte 0
sx !byte 0
sy !byte 0
work !byte 0
ready !byte 0
tablefree !byte 0
lateframes !byte 0
frames !word 0
musiccalls !word 0
texty !byte 0
spritehi !byte 0
textirqlo !byte 0
textirqhi !byte 0
textfirstd11 !byte 0
textsecondd11 !byte 0
curtextirq !byte 0
curtexthi !byte 0
currentbarirq !byte 0
border_mode !byte 0
curborder !byte 0
text_near !byte 0
curnear !byte 0
d11bank !byte 0
nextcolor !byte 6
textcolor !byte 6
logocolor !byte 2
logoylo !byte 0
logoy !byte 18
logovyl !byte 0
logovyh !byte 2
logoxlo !byte 0
logox !byte 48
logovxl !byte 0
logovxh !byte 2
logoxmsb !byte 0
logoxpos !fill 8,0
textx !fill 8,0
textxcopy !fill 8,0
bary !fill 7,0
draw_index !byte 0
xpos !byte <496,<40,<88,<136,<184,<232,<280,<328
bitmask !byte 1,2,4,8,16,32,64,128
fadetab !byte 6,6,14,14,3,3,1,1,1,1,3,3,14,14,6,6
redtab !byte 2,2,10,10,2,2,0,2
!align 255,0
incoming !fill 256,0

*=$2100
sin     ; 256 valori: int(133+78*sin(2*pi*i/256))  -> barre tra le righe 55 e 226
        !byte 133,134,136,138,140,142,144,146,148,150,151,153,155,157,159,161
        !byte 162,164,166,168,169,171,173,174,176,177,179,180,182,183,185,186
        !byte 188,189,190,192,193,194,195,196,197,198,199,200,201,202,203,204
        !byte 205,205,206,207,207,208,208,209,209,209,210,210,210,210,210,210
        !byte 211,210,210,210,210,210,210,209,209,209,208,208,207,207,206,205
        !byte 205,204,203,202,201,200,199,198,197,196,195,194,193,192,190,189
        !byte 188,186,185,183,182,180,179,177,176,174,173,171,169,168,166,164
        !byte 162,161,159,157,155,153,151,150,148,146,144,142,140,138,136,134
        !byte 133,131,129,127,125,123,121,119,117,115,114,112,110,108,106,104
        !byte 103,101,99,97,96,94,92,91,89,88,86,85,83,82,80,79
        !byte 77,76,75,73,72,71,70,69,68,67,66,65,64,63,62,61
        !byte 60,60,59,58,58,57,57,56,56,56,55,55,55,55,55,55
        !byte 55,55,55,55,55,55,55,56,56,56,57,57,58,58,59,60
        !byte 60,61,62,63,64,65,66,67,68,69,70,71,72,73,75,76
        !byte 77,79,80,82,83,85,86,88,89,91,92,94,96,97,99,101
        !byte 103,104,106,108,110,112,114,115,117,119,121,123,125,127,129,131
grad    ; 7 barre x 16 righe: rosso, arancio, giallo, verde, ciano, blu, viola
        !byte 11,9,2,2,10,10,15,1,1,15,10,10,2,2,9,11
        !byte 9,8,8,10,7,7,7,1,1,7,7,7,10,8,8,9
        !byte 9,8,7,7,7,15,1,1,1,1,15,7,7,7,8,9
        !byte 11,5,5,13,13,13,1,1,1,1,13,13,13,5,5,11
        !byte 6,14,14,3,3,3,1,1,1,1,3,3,3,14,14,6
        !byte 6,6,4,4,14,14,3,1,1,3,14,14,4,4,6,6
        !byte 11,4,4,10,10,15,15,1,1,15,15,10,10,4,4,11
*=$1000
music
        !byte $4c,$70,$1f,$4c,$48,$1f,$4c,$4e,$1f,$4c,$54,$1f,$4c,$c9,$13,$4c
        !byte $5c,$1f,$ee,$1c,$15,$2c,$10,$15,$30,$1e,$50,$36,$a9,$00,$8d,$1c
        !byte $15,$a2,$02,$9d,$e6,$14,$9d,$e9,$14,$9d,$ec,$14,$9d,$f5,$14,$ca
        !byte $10,$f1,$8d,$10,$15,$4c,$52,$10,$50,$15,$a9,$00,$8d,$04,$d4,$8d
        !byte $0b,$d4,$8d,$12,$d4,$a9,$0f,$8d,$18,$d4,$a9,$80,$8d,$10,$15,$4c
        !byte $9f,$13,$a2,$02,$ce,$0d,$15,$10,$06,$ad,$0e,$15,$8d,$0d,$15,$bd
        !byte $e2,$14,$8d,$e5,$14,$a8,$ad,$0d,$15,$cd,$0e,$15,$d0,$15,$bd,$e0
        !byte $16,$85,$fb,$bd,$e3,$16,$85,$fc,$de,$ec,$14,$30,$09,$4c,$6a,$11
        !byte $4c,$89,$13,$4c,$91,$11,$bc,$e6,$14,$b1,$fb,$c9,$ff,$d0,$11,$a9
        !byte $00,$9d,$ec,$14,$9d,$e6,$14,$9d,$e9,$14,$4c,$86,$10,$4c,$89,$13
        !byte $a8,$b9,$ec,$16,$85,$fd,$b9,$12,$17,$85,$fe,$a9,$00,$9d,$17,$15
        !byte $bc,$e9,$14,$a9,$ff,$8d,$fb,$14,$b1,$fd,$9d,$ef,$14,$8d,$fc,$14
        !byte $29,$1f,$9d,$ec,$14,$2c,$fc,$14,$70,$44,$fe,$e9,$14,$ad,$fc,$14
        !byte $10,$11,$c8,$b1,$fd,$10,$06,$9d,$17,$15,$4c,$e0,$10,$9d,$f8,$14
        !byte $fe,$e9,$14,$c8,$b1,$fd,$9d,$f5,$14,$0a,$a8,$ad,$1f,$15,$10,$21
        !byte $b9,$22,$14,$8d,$fd,$14,$b9,$23,$14,$ac,$e5,$14,$99,$01,$d4,$9d
        !byte $11,$15,$ad,$fd,$14,$99,$00,$d4,$9d,$14,$15,$4c,$11,$11,$ce,$fb
        !byte $14,$ac,$e5,$14,$bd,$f8,$14,$8e,$fe,$14,$0a,$0a,$0a,$aa,$bd,$8a
        !byte $15,$8d,$ff,$14,$ad,$1f,$15,$10,$21,$bd,$8a,$15,$2d,$fb,$14,$99
        !byte $04,$d4,$bd,$88,$15,$99,$02,$d4,$bd,$89,$15,$99,$03,$d4,$bd,$8b
        !byte $15,$99,$05,$d4,$bd,$8c,$15,$99,$06,$d4,$ae,$fe,$14,$ad,$ff,$14
        !byte $9d,$f2,$14,$fe,$e9,$14,$bc,$e9,$14,$b1,$fd,$c9,$ff,$d0,$08,$a9
        !byte $00,$9d,$e9,$14,$fe,$e6,$14,$4c,$89,$13,$ad,$1f,$15,$30,$03,$4c
        !byte $89,$13,$ac,$e5,$14,$bd,$ef,$14,$29,$20,$d0,$15,$bd,$ec,$14,$d0
        !byte $10,$bd,$f2,$14,$29,$fe,$99,$04,$d4,$a9,$00,$99,$05,$d4,$99,$06
        !byte $d4,$ad,$1f,$15,$30,$03,$4c,$89,$13,$bd,$f8,$14,$0a,$0a,$0a,$a8
        !byte $8c,$0f,$15,$b9,$8f,$15,$8d,$1a,$15,$b9,$8e,$15,$8d,$01,$15,$b9
        !byte $8d,$15,$8d,$00,$15,$f0,$6f,$ad,$1c,$15,$29,$07,$c9,$04,$90,$02
        !byte $49,$07,$8d,$06,$15,$bd,$f5,$14,$0a,$a8,$38,$b9,$24,$14,$f9,$22
        !byte $14,$8d,$02,$15,$b9,$25,$14,$f9,$23,$14,$4a,$6e,$02,$15,$ce,$00
        !byte $15,$10,$f7,$8d,$03,$15,$b9,$22,$14,$8d,$04,$15,$b9,$23,$14,$8d
        !byte $05,$15,$bd,$ef,$14,$29,$1f,$c9,$08,$90,$1c,$ac,$06,$15,$88,$30
        !byte $16,$18,$ad,$04,$15,$6d,$02,$15,$8d,$04,$15,$ad,$05,$15,$6d,$03
        !byte $15,$8d,$05,$15,$4c,$fe,$11,$ac,$e5,$14,$ad,$04,$15,$99,$00,$d4
        !byte $ad,$05,$15,$99,$01,$d4,$ad,$1a,$15,$29,$08,$f0,$15,$ac,$0f,$15
        !byte $b9,$88,$15,$6d,$01,$15,$99,$88,$15,$ac,$e5,$14,$99,$02,$d4,$4c
        !byte $a9,$12,$ad,$01,$15,$f0,$62,$ac,$0f,$15,$29,$1f,$de,$07,$15,$10
        !byte $58,$9d,$07,$15,$ad,$01,$15,$29,$e0,$8d,$1b,$15,$bd,$0a,$15,$d0
        !byte $1a,$ad,$1b,$15,$18,$79,$88,$15,$48,$b9,$89,$15,$69,$00,$29,$0f
        !byte $48,$c9,$0e,$d0,$1d,$fe,$0a,$15,$4c,$92,$12,$38,$b9,$88,$15,$ed
        !byte $1b,$15,$48,$b9,$89,$15,$e9,$00,$29,$0f,$48,$c9,$08,$d0,$03,$de
        !byte $0a,$15,$8e,$fe,$14,$ae,$e5,$14,$68,$99,$89,$15,$9d,$03,$d4,$68
        !byte $99,$88,$15,$9d,$02,$d4,$ae,$fe,$14,$ac,$e5,$14,$bd,$17,$15,$f0
        !byte $3f,$29,$7e,$8d,$fe,$14,$bd,$17,$15,$29,$01,$f0,$1b,$38,$bd,$14
        !byte $15,$ed,$fe,$14,$9d,$14,$15,$99,$00,$d4,$bd,$11,$15,$e9,$00,$9d
        !byte $11,$15,$99,$01,$d4,$4c,$f0,$12,$18,$bd,$14,$15,$6d,$fe,$14,$9d
        !byte $14,$15,$99,$00,$d4,$bd,$11,$15,$69,$00,$9d,$11,$15,$99,$01,$d4
        !byte $ad,$1a,$15,$29,$01,$f0,$35,$bd,$11,$15,$f0,$30,$bd,$ec,$14,$f0
        !byte $2b,$bd,$ef,$14,$29,$1f,$38,$e9,$01,$dd,$ec,$14,$ac,$e5,$14,$90
        !byte $10,$bd,$11,$15,$de,$11,$15,$99,$01,$d4,$bd,$f2,$14,$29,$fe,$d0
        !byte $08,$bd,$11,$15,$99,$01,$d4,$a9,$80,$99,$04,$d4,$ad,$1a,$15,$29
        !byte $02,$f0,$25,$bd,$ef,$14,$29,$1f,$c9,$10,$90,$1c,$bd,$ec,$14,$c9
        !byte $18,$b0,$15,$ad,$1c,$15,$29,$01,$f0,$0e,$bd,$11,$15,$f0,$09,$de
        !byte $11,$15,$ac,$e5,$14,$99,$01,$d4,$ad,$1a,$15,$29,$04,$f0,$2a,$ad
        !byte $1c,$15,$29,$04,$d0,$09,$bd,$f5,$14,$18,$69,$0c,$4c,$72,$13,$bd
        !byte $f5,$14,$0a,$a8,$b9,$22,$14,$8d,$fd,$14,$b9,$23,$14,$ac,$e5,$14
        !byte $99,$01,$d4,$ad,$fd,$14,$99,$00,$d4,$a0,$ff,$ad,$1d,$15,$d0,$06
        !byte $ad,$1e,$15,$30,$01,$c8,$8c,$1f,$15,$ca,$30,$03,$4c,$5f,$10,$a9
        !byte $ff,$8d,$1f,$15,$ad,$1d,$15,$d0,$05,$2c,$1e,$15,$10,$01,$60,$50
        !byte $03,$20,$28,$15,$ce,$21,$15,$10,$f5,$ad,$27,$15,$29,$0f,$8d,$21
        !byte $15,$ad,$20,$15,$cd,$22,$15,$d0,$0f,$a2,$00,$8e,$04,$d4,$8e,$0b
        !byte $d4,$ca,$8e,$1e,$15,$4c,$ae,$13,$ce,$20,$15,$0a,$a8,$2c,$27,$15
        !byte $30,$20,$70,$0c,$b9,$22,$14,$8d,$00,$d4,$b9,$23,$14,$8d,$01,$d4
        !byte $98,$38,$ed,$23,$15,$a8,$b9,$22,$14,$8d,$07,$d4,$b9,$23,$14,$8d
        !byte $08,$d4,$2c,$24,$15,$10,$0b,$ad,$25,$15,$49,$01,$8d,$04,$d4,$8d
        !byte $25,$15,$50,$0b,$ad,$26,$15,$49,$01,$8d,$0b,$d4,$8d,$26,$15,$4c
        !byte $ae,$13,$16,$01,$27,$01,$38,$01,$4b,$01,$5f,$01,$73,$01,$8a,$01
        !byte $a1,$01,$ba,$01,$d4,$01,$f0,$01,$0e,$02,$2d,$02,$4e,$02,$71,$02
        !byte $96,$02,$bd,$02,$e7,$02,$13,$03,$42,$03,$74,$03,$a9,$03,$e0,$03
        !byte $1b,$04,$5a,$04,$9b,$04,$e2,$04,$2c,$05,$7b,$05,$ce,$05,$27,$06
        !byte $85,$06,$e8,$06,$51,$07,$c1,$07,$37,$08,$b4,$08,$37,$09,$c4,$09
        !byte $57,$0a,$f5,$0a,$9c,$0b,$4e,$0c,$09,$0d,$d0,$0d,$a3,$0e,$82,$0f
        !byte $6e,$10,$68,$11,$6e,$12,$88,$13,$af,$14,$eb,$15,$39,$17,$9c,$18
        !byte $13,$1a,$a1,$1b,$46,$1d,$04,$1f,$dc,$20,$d0,$22,$dc,$24,$10,$27
        !byte $5e,$29,$d6,$2b,$72,$2e,$38,$31,$26,$34,$42,$37,$8c,$3a,$08,$3e
        !byte $b8,$41,$a0,$45,$b8,$49,$20,$4e,$bc,$52,$ac,$57,$e4,$5c,$70,$62
        !byte $4c,$68,$84,$6e,$18,$75,$10,$7c,$70,$83,$40,$8b,$70,$93,$40,$9c
        !byte $78,$a5,$58,$af,$c8,$b9,$e0,$c4,$98,$d0,$08,$dd,$30,$ea,$20,$f8
        !byte $2e,$fd,$00,$07,$0e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00
        !byte $c0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$a9,$00,$8d,$04,$d4,$8d,$0b,$d4
        !byte $8d,$21,$15,$ad,$1e,$15,$29,$0f,$8d,$1e,$15,$0a,$0a,$0a,$0a,$a8
        !byte $b9,$00,$16,$8d,$27,$15,$b9,$01,$16,$8d,$20,$15,$b9,$0f,$16,$8d
        !byte $22,$15,$b9,$08,$16,$8d,$24,$15,$29,$3f,$8d,$23,$15,$b9,$05,$16
        !byte $8d,$25,$15,$b9,$0c,$16,$8d,$26,$15,$a2,$00,$b9,$01,$16,$9d,$00
        !byte $d4,$c8,$e8,$e0,$0e,$d0,$f4,$ad,$27,$15,$29,$30,$a0,$ee,$c9,$20
        !byte $f0,$02,$a0,$ce,$8c,$d8,$13,$60,$00,$01,$41,$07,$7f,$02,$98,$0a
        !byte $80,$08,$41,$08,$8f,$02,$77,$0a,$50,$01,$41,$07,$6f,$00,$00,$05
        !byte $00,$02,$81,$0a,$09,$00,$00,$05,$00,$08,$11,$09,$09,$02,$00,$05
        !byte $00,$01,$41,$0e,$00,$00,$00,$04,$80,$02,$41,$00,$69,$00,$0f,$0c
        !byte $80,$01,$41,$00,$89,$00,$07,$0c,$00,$08,$41,$47,$6f,$02,$07,$0a
        !byte $00,$09,$11,$3f,$ff,$00,$00,$04,$00,$08,$41,$24,$00,$00,$00,$04
        !byte $00,$03,$11,$0f,$ff,$02,$00,$04,$c0,$03,$41,$07,$09,$00,$00,$05
        !byte $00,$02,$41,$39,$8f,$02,$04,$08,$00,$08,$41,$09,$8f,$02,$e0,$00
        !byte $11,$5f,$24,$80,$11,$81,$0d,$30,$11,$60,$80,$08,$15,$0d,$00,$08
        !byte $60,$04,$07,$80,$01,$41,$0d,$30,$00,$60,$80,$08,$43,$0d,$00,$50
        !byte $52,$5f,$07,$40,$02,$41,$0c,$00,$20,$90,$00,$08,$43,$0a,$30,$38
        !byte $62,$13,$98,$80,$01,$11,$0f,$00,$00,$57,$00,$06,$15,$0f,$00,$5f
        !byte $a0,$33,$10,$80,$00,$81,$0b,$00,$00,$20,$00,$00,$81,$0b,$00,$5f
        !byte $20,$20,$10,$00,$00,$81,$0b,$00,$20,$20,$00,$00,$81,$0b,$00,$5f
        !byte $63,$04,$09,$80,$00,$81,$0e,$00,$09,$20,$00,$08,$81,$0e,$00,$4f
        !byte $20,$34,$09,$80,$04,$41,$0e,$00,$0a,$20,$00,$08,$41,$0e,$00,$4f
        !byte $10,$5f,$09,$80,$04,$41,$0e,$00,$2a,$20,$00,$08,$41,$0e,$00,$48
        !byte $22,$30,$00,$80,$08,$41,$69,$83,$c4,$39,$00,$08,$41,$79,$83,$59
        !byte $20,$1a,$00,$00,$00,$81,$0b,$00,$3f,$27,$40,$08,$43,$0b,$00,$46
        !byte $a0,$1a,$40,$00,$08,$41,$0c,$00,$00,$35,$40,$08,$41,$0c,$00,$46
        !byte $54,$1f,$02,$00,$01,$51,$0f,$f0,$00,$27,$00,$01,$53,$0f,$ff,$00
        !byte $10,$75,$10,$00,$00,$81,$0b,$00,$0f,$00,$40,$08,$13,$0c,$00,$35
        !byte $00,$00,$00,$00,$00,$00,$38,$89,$f7,$17,$17,$17,$7b,$51,$27,$7d
        !byte $93,$d2,$27,$a9,$79,$cf,$bf,$a4,$d5,$eb,$1b,$5a,$99,$bb,$dc,$fd
        !byte $1e,$3f,$60,$81,$97,$ac,$c1,$d6,$01,$eb,$6d,$ef,$3b,$46,$8d,$ad
        !byte $cd,$e6,$1e,$1e,$1e,$1e,$1e,$18,$19,$1e,$19,$19,$1e,$19,$1e,$1e
        !byte $1a,$1a,$1a,$1a,$1a,$1a,$1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b,$1f,$1b
        !byte $1c,$1c,$1d,$1d,$1d,$1d,$1d,$1d,$05,$05,$0e,$09,$10,$10,$11,$11
        !byte $10,$10,$11,$11,$12,$12,$13,$13,$12,$12,$13,$13,$14,$14,$15,$15
        !byte $16,$16,$13,$13,$0e,$1d,$1d,$05,$1d,$1d,$1f,$20,$21,$22,$22,$22
        !byte $23,$22,$22,$22,$23,$24,$24,$24,$24,$24,$24,$24,$24,$25,$25,$25
        !byte $25,$25,$25,$25,$25,$12,$12,$13,$13,$12,$12,$13,$13,$14,$14,$15
        !byte $15,$16,$16,$13,$13,$1d,$1d,$0e,$ff,$06,$06,$0f,$08,$08,$0b,$0b
        !byte $08,$08,$0b,$08,$08,$0b,$08,$0b,$17,$17,$18,$18,$17,$17,$18,$18
        !byte $19,$19,$1a,$1a,$1b,$1b,$18,$18,$0f,$1e,$1e,$06,$1e,$1e,$00,$1f
        !byte $17,$17,$0b,$19,$19,$18,$18,$17,$17,$0b,$19,$19,$18,$18,$17,$17
        !byte $0b,$19,$19,$18,$18,$17,$17,$0b,$19,$19,$18,$18,$17,$17,$0b,$19
        !byte $19,$18,$18,$17,$17,$18,$18,$17,$17,$18,$18,$17,$17,$18,$18,$17
        !byte $17,$18,$18,$17,$17,$18,$18,$17,$17,$18,$18,$19,$19,$1a,$1a,$1b
        !byte $1b,$18,$18,$1e,$1e,$0f,$ff,$01,$01,$02,$02,$03,$03,$03,$03,$04
        !byte $04,$04,$04,$01,$01,$02,$02,$03,$03,$03,$03,$04,$04,$04,$04,$01
        !byte $01,$0c,$0c,$0c,$0c,$02,$02,$0d,$0d,$03,$04,$07,$07,$07,$07,$0a
        !byte $0a,$0a,$0a,$07,$07,$07,$07,$0a,$0a,$07,$07,$07,$07,$0a,$0a,$07
        !byte $07,$0a,$0a,$01,$04,$04,$01,$04,$04,$02,$03,$03,$1c,$1c,$04,$04
        !byte $01,$01,$0c,$0c,$0c,$0c,$02,$02,$0d,$0d,$03,$04,$02,$03,$03,$1c
        !byte $1c,$04,$04,$02,$03,$03,$1c,$1c,$04,$04,$01,$01,$02,$02,$03,$03
        !byte $03,$03,$04,$04,$04,$04,$02,$03,$03,$1c,$1c,$04,$04,$02,$03,$03
        !byte $1c,$1c,$04,$04,$01,$0a,$0a,$02,$04,$04,$01,$0a,$0a,$02,$04,$04
        !byte $01,$0a,$0a,$02,$04,$04,$01,$0a,$0a,$02,$04,$04,$01,$0a,$0a,$02
        !byte $04,$04,$01,$0a,$0a,$02,$04,$04,$01,$0a,$0a,$02,$04,$04,$01,$0a
        !byte $0a,$02,$04,$04,$01,$0a,$0a,$02,$04,$04,$01,$04,$04,$01,$04,$04
        !byte $02,$03,$03,$1c,$1c,$04,$04,$02,$03,$03,$1c,$1c,$04,$04,$02,$03
        !byte $03,$1c,$1c,$04,$04,$01,$01,$0c,$0c,$0c,$0c,$02,$02,$0d,$0d,$03
        !byte $04,$ff,$8f,$00,$4b,$0b,$43,$03,$4b,$07,$4a,$0f,$4e,$07,$4a,$0f
        !byte $4d,$0b,$44,$03,$4d,$1f,$4b,$8f,$00,$4b,$0b,$44,$03,$4b,$07,$49
        !byte $0f,$4d,$07,$49,$0f,$4b,$0b,$43,$03,$4b,$1f,$48,$8f,$00,$48,$0b
        !byte $41,$03,$48,$07,$47,$0f,$4a,$07,$47,$0f,$49,$0b,$41,$03,$49,$1f
        !byte $48,$8f,$00,$4a,$07,$43,$07,$4a,$0f,$4b,$07,$43,$07,$4b,$0f,$4d
        !byte $07,$43,$07,$4d,$1f,$4f,$ff,$8f,$01,$48,$0b,$3f,$03,$43,$07,$42
        !byte $0f,$45,$07,$42,$0f,$44,$0b,$41,$03,$44,$1f,$48,$0f,$48,$0b,$3c
        !byte $03,$48,$07,$41,$0f,$49,$07,$41,$0f,$43,$0b,$3f,$03,$43,$1f,$44
        !byte $0f,$45,$0b,$3c,$03,$45,$07,$43,$0f,$47,$07,$43,$0f,$46,$0b,$3d
        !byte $03,$46,$1f,$45,$0f,$47,$07,$3e,$07,$47,$0f,$48,$07,$3e,$07,$48
        !byte $0f,$4a,$07,$3e,$07,$4a,$1f,$4b,$ff,$83,$04,$4b,$01,$4b,$01,$52
        !byte $03,$55,$03,$52,$03,$55,$01,$4b,$01,$52,$03,$55,$03,$57,$83,$04
        !byte $4b,$01,$4b,$01,$52,$03,$55,$03,$52,$03,$55,$01,$4b,$01,$52,$03
        !byte $50,$03,$52,$ff,$83,$04,$46,$01,$46,$01,$4d,$03,$50,$03,$4d,$03
        !byte $50,$01,$46,$01,$4d,$03,$50,$03,$52,$83,$04,$46,$01,$46,$01,$4d
        !byte $03,$50,$03,$4d,$03,$50,$01,$46,$01,$4d,$03,$4b,$03,$4d,$ff,$9f
        !byte $05,$36,$17,$33,$07,$36,$0f,$35,$1f,$38,$0f,$35,$1f,$38,$0f,$35
        !byte $0f,$38,$1f,$3a,$01,$41,$01,$44,$01,$46,$01,$41,$01,$44,$01,$46
        !byte $01,$41,$01,$44,$01,$46,$01,$41,$01,$44,$01,$46,$01,$44,$01,$41
        !byte $01,$3f,$01,$41,$1f,$36,$17,$33,$07,$36,$0f,$35,$1f,$38,$0f,$35
        !byte $1f,$36,$17,$2e,$07,$36,$3f,$33,$1f,$33,$ff,$9f,$06,$37,$1f,$39
        !byte $1f,$37,$1f,$34,$1f,$34,$1f,$36,$1f,$34,$1f,$31,$8f,$08,$3f,$07
        !byte $38,$07,$3f,$0f,$40,$07,$38,$07,$40,$0f,$42,$07,$38,$07,$42,$0f
        !byte $44,$07,$38,$07,$44,$0f,$45,$07,$3d,$07,$45,$0f,$47,$07,$3d,$07
        !byte $47,$0f,$48,$07,$41,$07,$48,$1f,$4a,$ff,$9f,$07,$34,$1f,$35,$1f
        !byte $2f,$1f,$30,$1f,$31,$1f,$32,$1f,$2c,$1f,$2d,$8f,$09,$3c,$07,$33
        !byte $07,$3c,$0f,$3d,$07,$33,$07,$3d,$0f,$3f,$07,$33,$07,$3f,$0f,$40
        !byte $07,$33,$07,$40,$0f,$42,$07,$36,$07,$42,$0f,$44,$07,$36,$07,$44
        !byte $0f,$44,$07,$3c,$07,$44,$1f,$47,$ff,$81,$0a,$3f,$01,$41,$01,$42
        !byte $01,$3f,$01,$41,$01,$42,$01,$3f,$01,$41,$01,$42,$01,$3f,$01,$41
        !byte $01,$42,$01,$41,$01,$3f,$01,$41,$01,$42,$ff,$01,$41,$01,$44,$01
        !byte $46,$01,$41,$01,$44,$01,$46,$01,$41,$01,$44,$01,$46,$01,$41,$01
        !byte $44,$01,$46,$01,$44,$01,$41,$01,$3f,$01,$41,$ff,$01,$3c,$01,$3e
        !byte $01,$3f,$01,$3c,$01,$3e,$01,$3f,$01,$3c,$01,$3e,$01,$3f,$01,$3c
        !byte $01,$3e,$01,$3f,$01,$3e,$01,$3c,$01,$3e,$01,$3f,$ff,$01,$3e,$01
        !byte $41,$01,$43,$01,$3e,$01,$41,$01,$43,$01,$3e,$01,$41,$01,$43,$01
        !byte $3e,$01,$41,$01,$43,$01,$41,$01,$3e,$01,$3c,$01,$3e,$ff,$01,$3f
        !byte $01,$42,$01,$44,$01,$3f,$01,$42,$01,$44,$01,$3f,$01,$42,$01,$44
        !byte $01,$3f,$01,$42,$01,$44,$01,$42,$01,$3f,$01,$3d,$01,$3f,$ff,$01
        !byte $41,$01,$44,$01,$46,$01,$41,$01,$44,$01,$46,$01,$41,$01,$44,$01
        !byte $46,$01,$41,$01,$44,$01,$46,$01,$44,$01,$41,$01,$3f,$01,$41,$ff
        !byte $01,$44,$01,$46,$01,$47,$01,$44,$01,$46,$01,$47,$01,$44,$01,$46
        !byte $01,$47,$01,$44,$01,$46,$01,$47,$01,$46,$01,$44,$01,$42,$01,$44
        !byte $ff,$83,$04,$48,$01,$48,$01,$4f,$03,$52,$03,$4f,$03,$52,$01,$48
        !byte $01,$4f,$03,$52,$03,$54,$ff,$03,$43,$01,$43,$01,$4a,$03,$4d,$03
        !byte $4a,$03,$4d,$01,$43,$01,$4a,$03,$4d,$03,$4f,$ff,$03,$44,$01,$44
        !byte $01,$4b,$03,$4e,$03,$4b,$03,$4e,$01,$44,$01,$4b,$03,$4e,$03,$50
        !byte $ff,$03,$41,$01,$41,$01,$48,$03,$4b,$03,$48,$03,$4b,$01,$41,$01
        !byte $48,$03,$4b,$03,$4d,$ff,$03,$49,$01,$49,$01,$50,$03,$53,$03,$50
        !byte $03,$53,$01,$49,$01,$50,$03,$53,$03,$55,$ff,$83,$0b,$48,$03,$2c
        !byte $03,$2c,$03,$46,$03,$2c,$03,$2c,$03,$44,$03,$2c,$03,$2c,$03,$43
        !byte $03,$2c,$03,$2c,$03,$41,$03,$2c,$03,$43,$03,$2c,$03,$44,$03,$29
        !byte $03,$29,$03,$43,$03,$29,$03,$29,$03,$41,$03,$29,$03,$29,$03,$3f
        !byte $03,$29,$03,$29,$03,$3e,$03,$29,$03,$3f,$03,$29,$03,$41,$03,$25
        !byte $03,$25,$03,$3f,$03,$25,$03,$25,$03,$3d,$03,$25,$03,$25,$03,$3c
        !byte $03,$25,$03,$25,$03,$3d,$03,$25,$03,$3f,$03,$25,$03,$44,$03,$2b
        !byte $03,$2b,$03,$43,$03,$2b,$03,$2b,$03,$41,$03,$2b,$03,$2b,$03,$3f
        !byte $03,$2b,$03,$2b,$03,$3e,$03,$2b,$03,$3b,$03,$2b,$ff,$83,$0c,$3f
        !byte $03,$20,$03,$20,$03,$3e,$03,$20,$03,$20,$03,$3c,$03,$20,$03,$20
        !byte $03,$3a,$03,$20,$03,$20,$03,$38,$03,$20,$03,$3a,$03,$20,$03,$3c
        !byte $03,$35,$03,$35,$03,$3a,$03,$35,$03,$35,$03,$38,$03,$35,$03,$35
        !byte $03,$37,$03,$35,$03,$35,$03,$35,$03,$35,$03,$37,$03,$25,$03,$38
        !byte $03,$31,$03,$31,$03,$37,$03,$31,$03,$31,$03,$35,$03,$31,$03,$31
        !byte $03,$33,$03,$31,$03,$31,$03,$35,$03,$31,$03,$37,$03,$31,$03,$3c
        !byte $03,$37,$03,$37,$03,$3b,$03,$37,$03,$37,$03,$38,$03,$37,$03,$37
        !byte $03,$37,$03,$1f,$03,$1f,$03,$35,$03,$1f,$03,$32,$03,$1f,$ff,$a7
        !byte $0d,$2e,$a7,$96,$2e,$2f,$30,$1f,$30,$27,$30,$a7,$9a,$30,$2f,$32
        !byte $1f,$32,$27,$32,$a7,$a0,$32,$2f,$33,$1f,$33,$27,$33,$a7,$a4,$33
        !byte $2f,$35,$1f,$35,$03,$30,$03,$30,$03,$32,$33,$30,$1f,$30,$03,$32
        !byte $03,$32,$03,$33,$33,$32,$1f,$32,$03,$33,$03,$33,$03,$35,$33,$33
        !byte $1f,$30,$03,$37,$03,$37,$03,$38,$13,$37,$ff,$4f,$83,$0e,$37,$03
        !byte $37,$03,$3a,$03,$3c,$ff,$0b,$3c,$03,$3a,$07,$3c,$03,$3a,$23,$3c
        !byte $97,$b1,$3c,$03,$37,$03,$3a,$0b,$3c,$03,$3a,$07,$3c,$03,$3e,$23
        !byte $3c,$97,$b1,$3c,$03,$3a,$03,$3c,$0b,$3f,$01,$3e,$01,$3d,$0f,$3c
        !byte $0b,$3f,$01,$3e,$01,$3d,$0f,$3c,$0b,$3a,$01,$39,$01,$38,$0f,$37
        !byte $0b,$3a,$01,$39,$01,$38,$07,$37,$03,$37,$03,$3a,$ff,$03,$3c,$03
        !byte $3c,$03,$3a,$03,$3c,$03,$3f,$03,$3f,$03,$3c,$03,$3f,$03,$41,$03
        !byte $41,$03,$3f,$a7,$c0,$41,$03,$41,$03,$3f,$03,$3c,$ff,$03,$43,$03
        !byte $43,$03,$3e,$03,$41,$03,$43,$03,$43,$03,$41,$03,$43,$03,$46,$03
        !byte $46,$03,$43,$03,$46,$87,$cf,$48,$03,$46,$03,$43,$ff,$03,$4b,$07
        !byte $4d,$03,$4b,$07,$4d,$03,$4b,$07,$4d,$03,$4b,$87,$e0,$4d,$a7,$e0
        !byte $4d,$03,$4d,$03,$48,$ff,$01,$4f,$01,$4b,$01,$48,$01,$4b,$01,$50
        !byte $01,$4b,$01,$48,$01,$4b,$01,$4f,$01,$4b,$01,$48,$01,$4b,$01,$50
        !byte $01,$4b,$01,$48,$01,$4b,$01,$4f,$01,$4b,$01,$48,$01,$4b,$01,$54
        !byte $01,$4b,$01,$48,$01,$4b,$01,$52,$01,$4b,$01,$48,$01,$4b,$01,$50
        !byte $01,$4b,$01,$48,$01,$4b,$ff,$83,$02,$14,$03,$14,$83,$03,$2f,$83
        !byte $02,$14,$03,$1f,$03,$20,$83,$03,$2f,$83,$02,$14,$03,$14,$03,$14
        !byte $83,$03,$2f,$83,$02,$14,$03,$1f,$03,$20,$83,$03,$2f,$83,$02,$14
        !byte $ff,$83,$02,$18,$03,$18,$83,$03,$2f,$83,$02,$18,$03,$23,$03,$24
        !byte $83,$03,$2f,$83,$02,$18,$03,$18,$03,$18,$83,$03,$2f,$83,$02,$18
        !byte $03,$23,$03,$24,$83,$03,$2f,$83,$02,$18,$ff,$5f,$ff,$83,$02,$1d
        !byte $03,$1d,$83,$03,$2f,$83,$02,$1d,$03,$28,$03,$29,$83,$03,$2f,$83
        !byte $02,$1d,$ff,$83,$02,$13,$03,$13,$83,$03,$2f,$83,$02,$13,$03,$1e
        !byte $03,$1f,$83,$03,$2f,$83,$02,$13,$ff,$83,$02,$1b,$03,$1b,$83,$03
        !byte $2f,$83,$02,$1b,$03,$26,$03,$27,$83,$03,$2f,$83,$02,$1b,$ff,$83
        !byte $02,$16,$03,$16,$83,$03,$2f,$83,$02,$16,$03,$21,$03,$22,$83,$03
        !byte $2f,$83,$02,$16,$ff,$83,$02,$15,$03,$15,$83,$03,$2f,$83,$02,$15
        !byte $03,$20,$03,$21,$83,$03,$2f,$83,$02,$15,$ff,$83,$02,$1e,$03,$1e
        !byte $83,$03,$2f,$83,$02,$1e,$03,$29,$03,$2a,$83,$03,$2f,$83,$02,$1e
        !byte $ff,$83,$02,$19,$03,$19,$83,$03,$2f,$83,$02,$19,$03,$24,$03,$25
        !byte $83,$03,$2f,$83,$02,$19,$ff,$a0,$00,$0a,$8d,$fe,$14,$0a,$18,$6d
        !byte $fe,$14,$aa,$bd,$e6,$16,$99,$e0,$16,$e8,$c8,$c0,$06,$d0,$f4,$a9
        !byte $00,$8d,$04,$d4,$8d,$0b,$d4,$8d,$12,$d4,$8d,$17,$d4,$a9,$0f,$8d
        !byte $18,$d4,$a9,$40,$8d,$10,$15,$60,$a9,$c0,$8d,$10,$15,$60,$a9,$00
        !byte $8d,$1d,$15,$60,$a9,$ff,$8d,$1d,$15,$4c,$c9,$13,$ae,$1d,$15,$f0
        !byte $04,$8e,$1e,$15,$60,$09,$40,$8d,$1e,$15,$a9,$0f,$8d,$18,$d4,$60
        !byte $aa,$e0,$00,$f0,$08,$20,$06,$10,$ca,$8a,$4c,$0f,$10,$20,$17,$1f
        !byte $a9,$ff,$8d,$1f,$15,$60
*=$3000
font
        !byte $00,$00,$00,$ff,$ff,$00,$00,$00,$7e,$66,$66,$7e,$e6,$e6,$e6,$00
        !byte $7c,$66,$66,$7c,$e6,$e6,$fc,$00,$7e,$66,$60,$60,$e0,$e6,$fe,$00
        !byte $78,$6c,$66,$66,$e6,$e6,$fe,$00,$7e,$62,$60,$78,$e0,$e2,$fe,$00
        !byte $7e,$60,$60,$78,$e0,$e0,$e0,$00,$7e,$66,$60,$6e,$e6,$e6,$fe,$00
        !byte $66,$66,$66,$7e,$e6,$e6,$e6,$00,$7c,$18,$18,$18,$38,$38,$7c,$00
        !byte $1e,$0c,$0c,$0c,$0e,$6e,$7e,$00,$66,$6c,$78,$70,$f8,$ec,$e6,$00
        !byte $60,$60,$60,$60,$e0,$e2,$fe,$00,$63,$77,$7f,$6b,$63,$63,$67,$00
        !byte $66,$76,$7e,$7e,$ee,$e6,$e6,$00,$7e,$66,$66,$66,$e6,$e6,$fe,$00
        !byte $7e,$66,$66,$7e,$e0,$e0,$e0,$00,$7e,$66,$66,$e6,$ee,$fe,$02,$00
        !byte $7c,$66,$66,$7c,$f8,$ec,$e6,$00,$7e,$66,$60,$7e,$06,$e6,$fe,$00
        !byte $7e,$18,$18,$18,$38,$38,$38,$00,$66,$66,$66,$66,$e6,$e6,$fe,$00
        !byte $66,$e6,$e6,$e6,$66,$3c,$18,$00,$73,$63,$63,$6b,$7f,$77,$63,$00
        !byte $66,$66,$3c,$18,$3c,$e6,$e6,$00,$66,$66,$3c,$18,$38,$38,$38,$00
        !byte $7e,$46,$0c,$18,$30,$e2,$fe,$00,$00,$00,$00,$00,$01,$05,$07,$0f
        !byte $00,$00,$00,$00,$80,$80,$e0,$f0,$0f,$07,$0f,$1f,$bf,$ff,$ff,$ff
        !byte $c0,$f8,$f0,$fa,$fe,$ff,$ff,$ff,$00,$00,$00,$00,$85,$a5,$ef,$ff
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$18,$38,$38,$38,$00,$00,$18,$00
        !byte $66,$66,$66,$00,$00,$00,$00,$00,$00,$00,$00,$80,$c1,$c3,$e7,$ff
        !byte $00,$33,$7a,$7c,$78,$48,$48,$6c,$00,$03,$07,$07,$07,$04,$04,$06
        !byte $00,$30,$a0,$c0,$80,$80,$80,$c0,$1c,$1c,$0c,$00,$00,$00,$00,$00
        !byte $0c,$18,$30,$30,$30,$18,$0c,$00,$30,$18,$0c,$0c,$0c,$18,$30,$00
        !byte $00,$66,$3c,$ff,$3c,$66,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        !byte $00,$00,$00,$00,$00,$18,$18,$30,$00,$00,$00,$7e,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$60,$00,$18,$18,$18,$f8,$f8,$00,$00,$00
        !byte $7e,$66,$6e,$76,$e6,$e6,$fe,$00,$18,$38,$18,$18,$38,$38,$7e,$00
        !byte $3c,$66,$06,$0c,$30,$e6,$fe,$00,$7e,$66,$06,$1c,$06,$e6,$fe,$00
        !byte $0c,$0c,$cc,$cc,$fe,$0c,$0c,$00,$7e,$60,$7e,$06,$06,$e6,$fe,$00
        !byte $7e,$66,$60,$7e,$e6,$e6,$fe,$00,$fe,$e6,$0c,$18,$38,$38,$38,$00
        !byte $7e,$66,$66,$7e,$e6,$e6,$fe,$00,$7e,$66,$66,$7e,$06,$e6,$fe,$00
        !byte $00,$00,$18,$18,$00,$18,$18,$00,$18,$18,$18,$1f,$1f,$00,$00,$00
        !byte $18,$18,$18,$ff,$ff,$00,$00,$00,$3c,$66,$db,$b1,$b1,$db,$66,$3c
        !byte $18,$18,$18,$18,$18,$18,$18,$18,$3c,$66,$06,$0c,$18,$00,$18,$00
*=$5000
msg
        !byte $20,$20,$20,$20,$17,$08,$05,$0e,$20,$14,$08,$05,$20,$13,$05,$16
        !byte $05,$0e,$14,$08,$20,$13,$05,$01,$0c,$20,$17,$01,$13,$20,$0f,$10
        !byte $05,$0e,$05,$04,$2c,$20,$08,$05,$01,$16,$05,$0e,$20,$06,$05,$0c
        !byte $0c,$20,$13,$09,$0c,$05,$0e,$14,$2e,$20,$06,$0f,$12,$20,$08,$01
        !byte $0c,$06,$20,$01,$0e,$20,$08,$0f,$15,$12,$2c,$20,$0e,$0f,$20,$10
        !byte $12,$01,$19,$05,$12,$20,$12,$05,$14,$15,$12,$0e,$05,$04,$2c,$20
        !byte $0e,$0f,$20,$01,$0e,$07,$05,$0c,$20,$13,$01,$0e,$07,$2c,$20,$01
        !byte $0e,$04,$20,$05,$16,$05,$12,$19,$20,$13,$03,$12,$05,$05,$0e,$20
        !byte $0f,$0e,$20,$05,$01,$12,$14,$08,$20,$14,$15,$12,$0e,$05,$04,$20
        !byte $12,$05,$04,$2e,$20,$14,$08,$05,$0e,$20,$14,$08,$05,$20,$14,$12
        !byte $15,$0d,$10,$05,$14,$13,$20,$13,$0f,$15,$0e,$04,$05,$04,$2e,$20
        !byte $14,$08,$05,$20,$17,$08,$09,$14,$05,$20,$12,$09,$04,$05,$12,$20
        !byte $03,$01,$0d,$05,$20,$17,$09,$14,$08,$20,$01,$20,$03,$12,$0f,$17
        !byte $0e,$20,$0f,$06,$20,$03,$09,$12,$03,$15,$09,$14,$13,$2c,$20,$03
        !byte $0f,$0e,$11,$15,$05,$12,$09,$0e,$07,$20,$17,$09,$14,$08,$0f,$15
        !byte $14,$20,$01,$20,$08,$15,$0d,$01,$0e,$20,$08,$01,$0e,$04,$2e,$20
        !byte $14,$08,$05,$20,$12,$05,$04,$20,$12,$09,$04,$05,$12,$20,$14,$0f
        !byte $0f,$0b,$20,$10,$05,$01,$03,$05,$20,$06,$12,$0f,$0d,$20,$14,$08
        !byte $05,$20,$0e,$05,$14,$17,$0f,$12,$0b,$13,$20,$01,$0e,$04,$20,$13
        !byte $05,$14,$20,$0e,$01,$14,$09,$0f,$0e,$20,$01,$07,$01,$09,$0e,$13
        !byte $14,$20,$0e,$01,$14,$09,$0f,$0e,$2e,$20,$14,$08,$05,$20,$02,$0c
        !byte $01,$03,$0b,$20,$12,$09,$04,$05,$12,$20,$17,$05,$09,$07,$08,$05
        !byte $04,$20,$0f,$15,$12,$20,$02,$12,$05,$01,$04,$20,$09,$0e,$20,$04
        !byte $09,$07,$09,$14,$01,$0c,$20,$13,$03,$01,$0c,$05,$13,$2c,$20,$17
        !byte $08,$09,$0c,$05,$20,$03,$08,$09,$0c,$04,$12,$05,$0e,$20,$13,$14
        !byte $01,$12,$16,$05,$04,$20,$02,$05,$0e,$05,$01,$14,$08,$20,$14,$0f
        !byte $17,$05,$12,$13,$20,$0f,$06,$20,$0c,$09,$07,$08,$14,$2e,$20,$14
        !byte $08,$05,$20,$10,$01,$0c,$05,$20,$12,$09,$04,$05,$12,$20,$06,$0f
        !byte $0c,$0c,$0f,$17,$05,$04,$2c,$20,$01,$0e,$04,$20,$08,$09,$13,$20
        !byte $0e,$01,$0d,$05,$20,$17,$01,$13,$20,$04,$05,$01,$14,$08,$2e,$20
        !byte $08,$05,$0c,$0c,$20,$0d,$0f,$16,$05,$04,$20,$02,$05,$08,$09,$0e
        !byte $04,$20,$08,$09,$0d,$20,$0c,$09,$0b,$05,$20,$01,$20,$13,$08,$01
        !byte $04,$0f,$17,$20,$01,$03,$12,$0f,$13,$13,$20,$14,$08,$05,$20,$17
        !byte $09,$12,$05,$13,$2e,$20,$17,$05,$20,$08,$01,$04,$20,$03,$01,$0c
        !byte $0c,$05,$04,$20,$09,$14,$20,$09,$0e,$14,$05,$0c,$0c,$09,$07,$05
        !byte $0e,$03,$05,$2e,$20,$17,$05,$20,$08,$01,$04,$20,$07,$09,$16,$05
        !byte $0e,$20,$09,$14,$20,$04,$0f,$0d,$09,$0e,$09,$0f,$0e,$2e,$20,$0e
        !byte $0f,$17,$20,$14,$08,$05,$20,$13,$14,$01,$12,$13,$20,$06,$01,$0c
        !byte $0c,$2c,$20,$14,$08,$05,$20,$13,$05,$01,$13,$20,$04,$01,$12,$0b
        !byte $05,$0e,$2c,$20,$01,$0e,$04,$20,$14,$08,$05,$20,$13,$0b,$19,$20
        !byte $03,$0c,$0f,$13,$05,$13,$20,$0c,$09,$0b,$05,$20,$01,$20,$13,$03
        !byte $12,$0f,$0c,$0c,$2e,$20,$06,$12,$0f,$0d,$20,$14,$08,$05,$20,$13
        !byte $0d,$0f,$0b,$05,$20,$12,$09,$13,$05,$13,$20,$01,$20,$0e,$01,$0d
        !byte $05,$3a,$20,$01,$09,$10,$0f,$03,$01,$0c,$19,$10,$13,$05,$2e,$20
        !byte $19,$05,$14,$20,$02,$05,$0e,$05,$01,$14,$08,$20,$14,$08,$05,$20
        !byte $12,$15,$09,$0e,$13,$2c,$20,$0f,$0e,$05,$20,$13,$0d,$01,$0c,$0c
        !byte $20,$0d,$01,$03,$08,$09,$0e,$05,$20,$13,$14,$09,$0c,$0c,$20,$13
        !byte $10,$05,$01,$0b,$13,$2e,$20,$09,$14,$13,$20,$0d,$05,$0d,$0f,$12
        !byte $19,$20,$09,$13,$20,$13,$0d,$01,$0c,$0c,$2c,$20,$09,$14,$13,$20
        !byte $13,$09,$07,$0e,$01,$0c,$20,$17,$05,$01,$0b,$2c,$20,$02,$15,$14
        !byte $20,$09,$14,$13,$20,$0d,$05,$13,$13,$01,$07,$05,$20,$05,$0e,$04
        !byte $15,$12,$05,$13,$2e,$20,$04,$0f,$20,$0e,$0f,$14,$20,$02,$0f,$17
        !byte $20,$02,$05,$06,$0f,$12,$05,$20,$14,$08,$05,$20,$09,$0d,$01,$07
        !byte $05,$2e,$20,$04,$0f,$20,$0e,$0f,$14,$20,$0d,$09,$13,$14,$01,$0b
        !byte $05,$20,$14,$08,$05,$20,$0d,$01,$03,$08,$09,$0e,$05,$20,$06,$0f
        !byte $12,$20,$07,$0f,$04,$2e,$20,$14,$08,$05,$20,$02,$0f,$0f,$0b,$20
        !byte $09,$13,$20,$0f,$10,$05,$0e,$2e,$20,$14,$08,$05,$20,$08,$0f,$15
        !byte $12,$20,$08,$01,$13,$20,$03,$0f,$0d,$05,$2e,$20,$13,$14,$09,$0c
        !byte $0c,$2c,$20,$17,$05,$20,$03,$08,$0f,$0f,$13,$05,$20,$14,$0f,$20
        !byte $12,$05,$13,$09,$13,$14,$2e,$20,$0c,$05,$14,$20,$14,$08,$05,$20
        !byte $12,$01,$13,$14,$05,$12,$20,$02,$15,$12,$0e,$20,$0c,$09,$0b,$05
        !byte $20,$06,$09,$12,$05,$20,$15,$10,$0f,$0e,$20,$14,$08,$05,$20,$01
        !byte $0c,$14,$01,$12,$2e,$20,$0c,$05,$14,$20,$14,$08,$05,$20,$0d,$15
        !byte $13,$09,$03,$20,$02,$12,$05,$01,$0b,$20,$14,$08,$05,$20,$13,$09
        !byte $0c,$05,$0e,$03,$05,$20,$0f,$06,$20,$08,$05,$01,$16,$05,$0e,$2e
        !byte $20,$15,$0e,$14,$09,$0c,$20,$14,$08,$05,$20,$06,$09,$0e,$01,$0c
        !byte $20,$10,$09,$18,$05,$0c,$20,$06,$01,$04,$05,$13,$2c,$20,$17,$05
        !byte $20,$13,$08,$01,$0c,$0c,$20,$0e,$0f,$14,$20,$13,$15,$12,$12,$05
        !byte $0e,$04,$05,$12,$20,$0f,$15,$12,$20,$13,$0f,$15,$0c,$13,$20,$14
        !byte $0f,$20,$14,$08,$05,$20,$03,$0f,$04,$05,$2e,$20,$20,$20,$20,$20
        !byte $20,$20,$20,$ff
*=$2c00
logo_bitmap
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$7e,$7c,$7e,$7e,$7c,$7e,$66,$18,$66,$66,$18
        !byte $66,$66,$18,$66,$66,$18,$66,$7e,$18,$7e,$7e,$18,$7e,$e6,$38,$e0
        !byte $e6,$38,$e0,$e6,$38,$e0,$e6,$38,$e0,$e6,$7c,$e0,$e6,$7c,$e0,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$7e,$7e,$7e,$7e,$7e,$7e,$66,$66,$66,$66,$66
        !byte $66,$66,$60,$66,$66,$60,$66,$66,$60,$7e,$66,$60,$7e,$e6,$e0,$e6
        !byte $e6,$e0,$e6,$e6,$e6,$e6,$e6,$e6,$e6,$fe,$fe,$e6,$fe,$fe,$e6,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$60,$66,$7e,$60,$66,$7e,$60,$66,$66,$60,$66
        !byte $66,$60,$3c,$66,$60,$3c,$66,$60,$18,$7e,$60,$18,$7e,$e0,$38,$e0
        !byte $e0,$38,$e0,$e2,$38,$e0,$e2,$38,$e0,$fe,$38,$e0,$fe,$38,$e0,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$7e,$7e,$00,$7e,$7e,$00,$66,$62,$00,$66,$62
        !byte $00,$60,$60,$00,$60,$60,$00,$7e,$78,$00,$7e,$78,$00,$06,$e0,$00
        !byte $06,$e0,$00,$e6,$e2,$00,$e6,$e2,$00,$fe,$fe,$00,$fe,$fe,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


*=$4000
shift_a_b
!for row,0,7 {
    asl incoming+row
    !for c,23,0 {
        lda SPR_A+(c/3)*64+row*3+(c%3)+INK
        rol
        sta SPR_B+(c/3)*64+row*3+(c%3)+INK
    }
}
        rts
shift_b_a
!for row,0,7 {
    asl incoming+row
    !for c,23,0 {
        lda SPR_B+(c/3)*64+row*3+(c%3)+INK
        rol
        sta SPR_A+(c/3)*64+row*3+(c%3)+INK
    }
}
        rts
