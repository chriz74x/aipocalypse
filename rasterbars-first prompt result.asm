; Rasterbar sinusoidali sovrapposte - C64 (sintassi ACME)
; acme -f cbm -o rasterbars.prg rasterbars.asm
phase=$fa : tmp=$fb : base=$fc : cnt=$fd : len=$fe
*=$0801
!byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,0,0,0   ; 10 SYS 2061
start   sei
        lda #$7f : sta $dc0d       ; niente IRQ CIA
        lda #$0b : sta $d011       ; schermo spento = niente badline
        lda #0 : sta $d020 : sta $d021 : sta phase
main    lda $d011 : bmi main       ; aspetta fine vblank
        ldx #$30
w2      cpx $d012 : bne w2         ; aspetta riga $30
loop    lda table,x : sta $d020    ; colore per questa riga
        inx : beq done
w3      cpx $d012 : bne w3
        beq loop
done    lda #0 : sta $d020
        ldx #$30 : lda #0
cl      sta table,x : inx : bne cl ; pulisci tabella
        lda phase : sta tmp
        lda #0 : sta base
        lda #7 : sta cnt           ; 7 barre
bar     ldx tmp : ldy sin,x        ; posizione Y dalla sinusoide
        ldx base : lda #16 : sta len
bl      lda grad,x : sta table,y   ; disegna barra (sovrascrive = sovrapposizione)
        inx : iny : dec len : bne bl
        stx base
        lda tmp : clc : adc #22 : sta tmp   ; sfasamento tra barre
        dec cnt : bne bar
        lda phase : clc : adc #2 : sta phase
        jmp main
!align 255,0
table   !fill 256,0
sin     ; 256 byte: int(143+88*sin(2*pi*i/256))
        !byte 143,145,147,149,151,153,155,158,160,162,164,166,168,170,172,174
        !byte 176,178,180,182,184,186,188,190,191,193,195,197,198,200,202,203
        !byte 205,206,208,209,211,212,213,214,216,217,218,219,220,221,222,223
        !byte 224,225,225,226,227,227,228,228,229,229,230,230,230,230,230,230
        !byte 231,230,230,230,230,230,230,229,229,228,228,227,227,226,225,225
        !byte 224,223,222,221,220,219,218,217,216,214,213,212,211,209,208,206
        !byte 205,203,202,200,198,197,195,193,191,190,188,186,184,182,180,178
        !byte 176,174,172,170,168,166,164,162,160,158,155,153,151,149,147,145
        !byte 143,140,138,136,134,132,130,127,125,123,121,119,117,115,113,111
        !byte 109,107,105,103,101,99,97,95,94,92,90,88,87,85,83,82
        !byte 80,79,77,76,74,73,72,71,69,68,67,66,65,64,63,62
        !byte 61,60,60,59,58,58,57,57,56,56,55,55,55,55,55,55
        !byte 55,55,55,55,55,55,55,56,56,57,57,58,58,59,60,60
        !byte 61,62,63,64,65,66,67,68,69,71,72,73,74,76,77,79
        !byte 80,82,83,85,87,88,90,92,94,95,97,99,101,103,105,107
        !byte 109,111,113,115,117,119,121,123,125,127,130,132,134,136,138,140
grad
        !byte 0,9,2,8,10,15,7,1,1,7,15,10,8,2,9,0
        !byte 0,6,11,4,14,3,13,1,1,13,3,14,4,11,6,0
        !byte 0,0,0,11,5,13,7,1,1,7,13,5,11,0,0,0
        !byte 0,0,0,0,9,8,7,1,1,7,8,9,0,0,0,0
        !byte 0,0,0,6,4,14,3,1,1,3,14,4,6,0,0,0
        !byte 0,0,0,0,2,10,15,1,1,15,10,2,0,0,0,0
        !byte 0,0,0,0,11,12,15,1,1,15,12,11,0,0,0,0
