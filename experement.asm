;------------------------------------------------------------------------------
; I/O and the RAM windows between the I/O chips
;------------------------------------------------------------------------------
via1_prb       = $8000                  ; VIA #1 port B: serial bus. b0 DATA in, b1 DATA out, b2 CLK in, b3 CLK out, b4 ATN ack, b5 fast-serial direction, b7 ATN in
via1_ddrb      = $8002                  ; VIA #1 DDRB ($3A: bits 1,3,4,5 are outputs)
via1_ddra      = $8003                  ; VIA #1 DDRA
via1_t2cl      = $8008                  ; VIA #1 timer 2 counter low
via1_t2ch      = $8009                  ; VIA #1 timer 2 counter high
via1_sr        = $800A                  ; VIA #1 shift register: fast-serial (burst) data byte
via1_acr       = $800B                  ; VIA #1 ACR: bits 2-4 select shift-in ($0C) / shift-out ($14) mode
via1_pcr       = $800C                  ; VIA #1 PCR
via1_ifr       = $800D                  ; VIA #1 IFR: b1 CA1 = ATN edge, b2 shift register done, b6 timer 1
via1_ier       = $800E                  ; VIA #1 IER
via1_pra_nh    = $800F                  ; VIA #1 port A without handshake
part_type      = $8200                  ; partition table: type per partition (0 none,1 native,2 1541,3 1571,4 1581,5 1581 CP/M,$FF system)
part_size_hi   = $8300                  ; partition table: size in 512-byte blocks, high byte
via2_prb       = $8400                  ; VIA #2 port B: SCSI bus control lines
via2_pra       = $8401                  ; VIA #2 port A: SCSI data bus
via2_ddrb      = $8402                  ; VIA #2 DDRB
via2_ddra      = $8403                  ; VIA #2 DDRA: $00 = data bus input, $FF = output
via2_sr        = $840A                  ; VIA #2 shift register
via2_pcr       = $840C                  ; VIA #2 PCR: CA2/CB2 handshake outputs
via2_ifr       = $840D                  ; VIA #2 IFR
via2_ier       = $840E                  ; VIA #2 IER
part_size_lo   = $8600                  ; partition table: size in 512-byte blocks, low byte
part_start_hi  = $8700                  ; partition table: start block, high byte
ppi_pa         = $8800                  ; 8255 port A: parallel port data (RAMLink / parallel cable)
ppi_pb         = $8801                  ; 8255 port B (input): b7 parallel request from host, b6 host handshake, b1-b3 front panel buttons
ppi_pc         = $8802                  ; 8255 port C (output): b7 drive handshake
ppi_ctrl       = $8803                  ; 8255 control word: $92 = port A input, $82 = port A output
part_start_mid = $8A00                  ; partition table: start block, middle byte
part_start_lo  = $8B00                  ; partition table: start block, low byte
rtc_regs       = $8C00                  ; RTC 72421 register 0 (seconds, units); registers follow as BCD digits
rtc_hour10     = $8C05                  ; RTC register 5: hours tens (+ AM/PM bit)
rtc_weekday    = $8C0C                  ; RTC register 12: day of week
rtc_ctrl_d     = $8C0D                  ; RTC control register D (HOLD / BUSY)
ctl_latch      = $8F00                  ; control latch: b5 = write enable for the protected RAM, low bits drive the LEDs

;------------------------------------------------------------------------------
; The original file is a PRG whose two-byte load address is $2000; the image
; itself executes at $9400-$FFFF.  Assemble as a plain binary to reproduce the
; original file byte for byte (drop the !word line to get the bare image).
;------------------------------------------------------------------------------
        !to "hdos_v1.92_rebuilt.prg", plain

* = $93FE
        !word $2000                      ; PRG load address header of the original file


; ==========================================================================
; Start of the image ($9400).  The DOS begins with its copyright text; the
; first executable byte is the serial-bus ATN service at sub_944A.
; ==========================================================================
copyright_msg                           ; $9400
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $9400

sub_944A
        sei
        cld
        ldx $5E
        txs
        lda #$80
        sta $81
        sta $2BD7
        and $2BD8
        sta $2BD8
        lda #$00
        sta $2BFB
        lda $46
        and #$3F
        sta $46
        lda #$02
        sta via1_ifr
        jsr sub_979B
        bit ppi_pb
        bpl loc_9477
        jmp loc_9569
loc_9477
        bit via1_prb
        bpl loc_94F3
        lda #$02
        sta via1_prb
loc_9481
        lda via1_prb
        bpl loc_94F3
        and #$04
        bne loc_9481
loc_948A
        jsr sub_962E
loc_948D
        cmp #$3F
        bne loc_9495
        lda #$BF
        bne loc_949B
loc_9495
        cmp #$5F
        bne loc_94A7
        lda #$7F
loc_949B
        and $46
        sta $46
        lda #$00
        sta $2BD8
        jmp loc_954E
loc_94A7
        cmp $78
        bne loc_94AF
        lda #$80
        bne loc_94B5
loc_94AF
        cmp $77
        bne loc_94C8
        lda #$40
loc_94B5
        ora $46
        sta $46
        ora #$3F
        and $46
        sta $46
        lda $90E3
        sta $2BD6
        jmp loc_94E2
loc_94C8
        tax
        and #$60
        cmp #$60
        bne loc_9539
        stx $83
        txa
        and #$0F
        sta $82
        txa
        and #$F0
        cmp #$E0
        bne loc_954E
        cli
        jsr sub_CCE3
        sei
loc_94E2
        bit $2BFB
        bvc loc_94EE
        bit ppi_pb
        bmi loc_948A
        bpl loc_94F3
loc_94EE
        bit via1_prb
        bmi loc_948A
loc_94F3
        ldx #$00
        stx $2BD7
        lda via1_prb
        ora #$10
        sta via1_prb
        bit $46
        bvc loc_9512
        bit $2BD8
        bpl loc_950C
        jsr sub_9787
loc_950C
        jsr jt_listen
        jmp loc_9530
loc_9512
        bit $46
        bpl loc_9530
        bit $2BFB
        bvc loc_9521
        jsr sub_9622
        jmp loc_952A
loc_9521
        jsr sub_975A
        jsr sub_9775
        jsr sub_97D2
loc_952A
        jsr jt_talk
        jsr sub_97D2
loc_9530
        jsr sub_95F9
        jsr sub_979B
        jmp jt_idle_loop
loc_9539
        bit $2BFB
        bvs loc_955A
        bit $2BD8
        bvc loc_9549
        lda $46
        and #$C0
        bne loc_954E
loc_9549
        lda #$00
        sta via1_prb
loc_954E
        bit $2BFB
        bvs loc_9562
loc_9553
        bit via1_prb
        bpl loc_94F3
        bmi loc_9553
loc_955A
        lda ppi_pc
        ora #$E0
        sta ppi_pc
loc_9562
        bit ppi_pb
        bpl loc_94F3
        bmi loc_9562
loc_9569
        ldx #$0A
loc_956B
        dex
        bne loc_956B
        lda #$40
        sta $2BFB
        lda ppi_pc
        and #$7F
        ora #$60
        sta ppi_pc
        tax
        lda #$92
        sta ppi_ctrl
        stx ppi_pc
        jsr sub_9633
        jmp loc_948D

sub_958C
        bit ppi_pb
        bmi loc_95C7
        bvs sub_958C
        lda $2DC8,x
        sta ppi_pa
        lda $2DA8,x
        and #$08
        bne loc_95B2
        lda ppi_pc
        and #$BF
        sta ppi_pc
        ora #$80
        sta ppi_pc
        ldy #$28
loc_95AF
        dey
        bne loc_95AF
loc_95B2
        lda ppi_pc
        ora #$C0
        sta ppi_pc
        and #$7F
loc_95BC
        bit ppi_pb
        bmi loc_95C7
        bvc loc_95BC
        sta ppi_pc
        rts
loc_95C7
        jmp sub_944A

sub_95CA
        bit ppi_pb
        bmi loc_95C7
        bvs sub_95CA
        ldy ppi_pa
        sty $84
        lda ppi_pc
        ora #$80
        sta ppi_pc
        lda #$01
loc_95E0
        bit ppi_pb
        bmi loc_95C7
        bne loc_95F3
        bvc loc_95E0
        lda ppi_pc
        and #$7F
        sta ppi_pc
        tya
        rts
loc_95F3
        lda #$00
        sta $81
        beq loc_95E0

sub_95F9
        php
        sei
        lda ppi_pc
        ora #$E0
        and #$7F
        tay
        ldx #$92
        stx ppi_ctrl
        sta ppi_pc
        ora #$80
        bit ppi_pb
        bmi loc_961A
        sta ppi_pc
        bit ppi_pb
        bpl loc_9620
loc_961A
        sty ppi_pc
        jmp sub_944A
loc_9620
        plp
        rts

sub_9622
        lda ppi_pc
        ldx #$82
        stx ppi_ctrl
        sta ppi_pc
        rts

sub_962E
        bit $2BFB
        bvc loc_967E

sub_9633
        lda ppi_pc
        ora #$80
        sta ppi_pc
loc_963B
        bit ppi_pb
        bpl loc_967B
        bvs loc_963B
        ldy ppi_pa
        sty $84
        lda #$01
        bit ppi_pb
        beq loc_9659
        cpy $78
        beq loc_9659
        cpy $77
        beq loc_9659
        jmp loc_955A
loc_9659
        lda ppi_pc
        and #$7F
        sta ppi_pc
loc_9661
        bit ppi_pb
        bpl loc_967B
        bvc loc_9661
        tya
        bit $46
        bvc loc_9678
        cmp #$60
        bne loc_9678
        sta $2BFB
        lda #$61
        sta $84
loc_9678
        jmp loc_971B
loc_967B
        jmp loc_94F3
loc_967E
        lda #$08
        sta $96
loc_9682
        jsr sub_9730
        bne loc_9682
        jsr sub_975A
        lda #$01
loc_968C
        bit via1_prb
        bne loc_968C
        ldx #$0A
loc_9693
        jsr sub_9744
        dex
        beq loc_96A2
        jsr sub_977E
        and #$04
        beq loc_9693
        bne loc_96B6
loc_96A2
        jsr sub_9763
        ldx #$18
loc_96A7
        dex
        bne loc_96A7
        jsr sub_975A
loc_96AD
        jsr sub_9730
        beq loc_96AD
        lda #$00
        sta $81
loc_96B6
        ldx #$1A
loc_96B8
        lda via1_prb
        tay
        and #$04
        beq loc_96FB
        dex
        bne loc_96B8
        lda #$3F
        bit $2BD8
        bmi loc_96F7
        bvs loc_96DC
        bne loc_96F7
        ldx $96
        cpx #$01
        beq loc_96DC
        ldx #$01
        stx $2BD8
        dex
        beq loc_96B8
loc_96DC
        lda $84
        lsr
        cmp $77
        beq loc_96E7
        cmp $78
        bne loc_96F7
loc_96E7
        lda #$40
        sta $2BD8
        ldx #$1E
        jsr sub_9763
loc_96F1
        dex
        bne loc_96F1
        jsr sub_975A
loc_96F7
        ldx #$00
        beq loc_96B8
loc_96FB
        tya
        eor #$01
        lsr
        ror $84
loc_9701
        jsr sub_9730
        beq loc_9701
        dec $96
        bne loc_96B6
        jsr sub_9763
        lda $84
        bne loc_971B
        lda #$80
        and $2BD8
        sta $2BD8
        lda #$00
loc_971B
        bit $2BD8
        bmi loc_972F
        cmp #$61
        bne loc_972F
        bit $46
        bpl loc_972F
        sta $2BD8
        lda #$60
        sta $84
loc_972F
        rts

sub_9730
        jsr sub_9744
        and #$04
        rts

sub_9736
        jsr sub_9744
        ror
        bcc sub_9736
        rts

sub_973D
        jsr sub_9744
        ror
        bcs sub_973D
        rts

sub_9744
        bit $2BD7
        bpl loc_974F
        lda via1_prb
        bpl loc_9757
loc_974E
        rts
loc_974F
        lda via1_prb
        bpl loc_974E
        jmp jt_atn_service
loc_9757
        jmp loc_94F3

sub_975A
        lda via1_prb
        and #$FD
        sta via1_prb
        rts

sub_9763
        lda via1_prb
        ora #$02
        sta via1_prb
        rts

sub_976C
        lda via1_prb
        and #$F7
        sta via1_prb
        rts

sub_9775
        lda via1_prb
        ora #$08
        sta via1_prb
        rts

sub_977E
        lda via1_prb
        cmp via1_prb
        bne sub_977E
        rts

sub_9787
        jsr sub_9730
        bne sub_9787
        jsr sub_97B9
        lda #$00
        sta via1_sr
        lda #$04
loc_9796
        bit via1_ifr
        beq loc_9796

sub_979B
        php
        sei
        lda via1_acr
        and #$E3
        sta via1_acr
        ora #$0C
        sta via1_acr
        lda via1_prb
        and #$DF
        sta via1_prb
        bit via1_sr
        plp
        rts

sub_97B7
        bcc sub_979B

sub_97B9
        php
        sei
        lda via1_prb
        ora #$20
        sta via1_prb
        lda via1_acr
        and #$E3
        sta via1_acr
        ora #$14
        sta via1_acr
        plp
        rts

sub_97D2
        txa
        nop
        ldx #$0C
        bne loc_97DB

sub_97D8
        txa
        ldx #$1D
loc_97DB
        dex
        bne loc_97DB
        tax
        rts
loc_97E0
        bit via1_prb
        bmi loc_9847
        jsr sub_976C
        jsr sub_973D
        jsr sub_9736
        lda #$01
        bne loc_9807

sub_97F2
        lda $2DA8,x
        and #$08
        beq loc_97E0
        lda via1_prb
        and #$01
        beq loc_97E0
        ora #$10
        sta via1_prb
        and #$01
loc_9807
        bit via1_prb
        bmi loc_9847
        bne loc_9807
        lda #$38
        sta via1_prb
        lda via1_acr
        and #$E3
        sta via1_acr
        ora #$14
        sta via1_acr
        lda $2DC8,x
        sta via1_t2ch
        sta via1_sr
        lda #$04
loc_982B
        bit via1_ifr
        beq loc_982B
        lda via1_acr
        eor #$18
        sta via1_acr
        lda #$18
        sta via1_prb
        lda #$01
loc_983F
        bit via1_prb
        bmi loc_9847
        beq loc_983F
        rts
loc_9847
        jmp jt_atn_service

sub_984A
        jsr sub_9859
        and #$02
        beq loc_9858
        lda $60
        ora #$0D
        jsr sub_98F4
loc_9858
        rts

sub_9859
        lda via1_prb
        and #$7D
        sta $6F
        and #$71
        sta $60
        lda $2DA8,x
        and #$08
        bne loc_9871
        lda $60
        ora #$03
        sta $6F
loc_9871
        lda $2DC8,x
        ldx $60
        bit via1_prb
        bmi loc_9882
        stx via1_prb
        ldy #$FF
        bne loc_98A1
loc_9882
        jmp jt_atn_service

sub_9885
        lda via1_prb
        and #$70
        sta $60
        ora #$0D
        sta $6F
        ora #$02
        sta via1_prb
        eor #$0D
        sta via1_prb
        ldx #$0E
loc_989C
        dex
        bne loc_989C
loc_989F
        lda ($68),y
loc_98A1
        tax
        lsr
        lsr
        lsr
        lsr
        sta $6C
        txa
        and #$0F
        tax
        lda dat_990C,x
        ldx $60
        jsr sub_9902
        stx via1_prb
        bit via1_prb
loc_98BA
        cpx via1_prb
        beq loc_98BA
        pha
        pla
        nop
        sta via1_prb
        asl
        ora #$10
        and #$1F
        pha
        pla
        bit $00
        sta via1_prb
        ldx $6C
        lda dat_990C,x
        pha
        pla
        bit via1_prb
        sta via1_prb
        asl
        ora #$10
        and #$1F
        nop
        nop
        nop
        nop
        ldx #$00
        iny
        sta via1_prb
        bne loc_989F
        lda $6F,x
        jsr sub_990B

sub_98F4
        sta via1_prb
loc_98F7
        bit via1_prb
        cmp via1_prb
        bcc loc_9882
        bne loc_98F7
        rts

sub_9902
        bit dat_E000

sub_9905
        bit dat_E000
        bit dat_E000

sub_990B
        rts
dat_990C
        !byte $1F,$17,$1D,$15,$1B,$13,$19,$11 ; $990C
        !byte $1E,$16,$1C,$14,$1A,$12,$18,$10 ; $9914
dat_991C
        !byte $00,$80,$20,$A0,$40,$C0,$60,$E0 ; $991C
        !byte $10,$90,$30,$B0,$50,$D0,$70,$F0 ; $9924

sub_992C
        bit via1_sr
        lda #$04
loc_9931
        bit via1_prb
        bmi loc_9964
        bne loc_9931
        ora #$10
        sta via1_prb
        ldx #$80
        lda #$04
loc_9941
        bit via1_prb
        bmi loc_9964
        bne loc_9952
        dex
        bne loc_9941
        lda #$08
        sta $96
        jmp loc_9A3E
loc_9952
        ldx #$12
        lda #$04
loc_9956
        bit via1_ifr
        beq loc_9956
loc_995B
        lda via1_sr
        stx via1_prb
        sta $84
        rts
loc_9964
        jmp jt_atn_service

sub_9967
        lda #$14
        sta via1_prb
        and #$04
loc_996E
        bit via1_prb
        bne loc_996E
        jsr sub_9902
        lda via1_prb
        asl
        jsr sub_9905
        ora via1_prb
        and #$0F
        tax
        ldy #$00
        jsr sub_990B
        lda via1_prb
        asl
        jsr sub_9905
        ora via1_prb
        and #$0F
        ora dat_991C,x
        sta $84
        jsr sub_990B
        lda via1_prb
        bit $84
        bit $84
        ora #$02
        sta via1_prb
        bmi loc_9964
        and #$04
        bne loc_99B0
        sty $81
loc_99B0
        lda $84
        rts

sub_99B3
        lda #$08
        sta $96
        lda via1_prb
        and #$F7
        sta via1_prb
        lsr
        bcc loc_99CC
        jsr sub_973D
        lda $2DA8,x
        and #$08
        bne sub_99DF
loc_99CC
        jsr sub_9736
        jsr sub_99DF
        ldx #$32
loc_99D4
        jsr sub_9744
        and #$01
        beq sub_99DE
        dex
        bne loc_99D4

sub_99DE
        rts

sub_99DF
        jsr sub_9775
        jsr sub_97D2
        jsr sub_973D
        jsr sub_99DE
loc_99EB
        jsr sub_97D2
        ror $2DC8,x
        jsr sub_99DE
        jsr sub_975A
        bcs loc_99FB
        ora #$02
loc_99FB
        sta via1_prb
        jsr sub_976C
        jsr sub_97D2
        txa
        ldx #$0B
loc_9A07
        dex
        bne loc_9A07
        tax
        lda via1_prb
        ora #$08
        and #$FD
        sta via1_prb
        dec $96
        bne loc_99EB
        jmp sub_9736

sub_9A1C
        bit via1_sr
        lda #$08
        sta $96
loc_9A23
        jsr sub_9730
        bne loc_9A23
        jsr sub_975A
        lda #$01
loc_9A2D
        bit via1_prb
        bmi loc_9A79
        bne loc_9A2D
        ldx #$14
loc_9A36
        jsr sub_9730
        bne loc_9A50
        dex
        bne loc_9A36
loc_9A3E
        jsr sub_9763
        jsr sub_97D8
        jsr sub_975A
loc_9A47
        jsr sub_9730
        beq loc_9A47
        lda #$00
        sta $81
loc_9A50
        ldx via1_prb
        lda #$04
        bit via1_ifr
        beq loc_9A5F
        ldx #$12
        jmp loc_995B
loc_9A5F
        txa
        and #$04
        bne loc_9A50
        txa
        eor #$01
        lsr
        ror $84
loc_9A6A
        jsr sub_9730
        beq loc_9A6A
        dec $96
        bne loc_9A50
        jsr sub_9763
        lda $84
loc_9A78
        rts
loc_9A79
        jmp jt_atn_service

sub_9A7C
        lda $0202
        cmp #$2B
        beq loc_9A78
        cmp #$2D
        beq loc_9A78
        jmp jt_warm_start
loc_9A8A
        jsr sub_973D
        lda #$04
loc_9A8F
        tax
        lda $69
        pha
        txa
        pha
        ldy #$01
        lda ($68),y
        sta $5B
        tax
        dey
        lda ($68),y
        sta $5A
        bne loc_9AAF
        pla
        clc
        sbc $5B
        inx
        stx $68
        beq loc_9AAE
        dec $69
loc_9AAE
        pha
loc_9AAF
        pla
        tay
        jsr sub_9885
        pla
        sta $69
        lda $5A
        beq loc_9AC2
        jsr sub_9AE2
        lda #$02
        bne loc_9A8F
loc_9AC2
        sta $68
        jsr sub_9ADA
        jsr sub_9ADA
        jsr sub_9AD7
        ldy #$00
loc_9ACF
        lda ($68),y
        sta ($66),y
        iny
        bne loc_9ACF
        rts

sub_9AD7
        jsr sub_9775

sub_9ADA
        ldx #$28
loc_9ADC
        dex
        bne loc_9ADC
        jmp sub_976C

sub_9AE2
        jsr sub_D973
        tya
        lsr
        tax
        lda #$AA
        jmp sub_E81C
loc_9AED
        lda #$04
loc_9AEF
        pha
        ldy #$01
        lda ($68),y
        sta $5B
        tax
        dey
        lda ($68),y
        sta $5A
        beq loc_9B06
        pla
        pha
        eor #$FF
        tax
        inx
        bne loc_9B0F
loc_9B06
        dex
        pla
        pha
        cmp #$02
        beq loc_9B0F
        dex
        dex
loc_9B0F
        pla
        jsr sub_9B47
        lda $5A
        beq loc_9B1E
        jsr sub_9B98
        lda #$02
        bne loc_9AEF
loc_9B1E
        lda #$00

sub_9B20
        bit ppi_pb
        bmi loc_9B44
        bvs loc_9B1E
        sta ppi_pa
        lda ppi_pc
        ora #$80
        sta ppi_pc
loc_9B32
        bit ppi_pb
        bmi loc_9B44
        bvc loc_9B32
        and #$7F
        sta ppi_pc
        ldx #$28
loc_9B40
        dex
        bne loc_9B40
        rts
loc_9B44
        jmp sub_944A

sub_9B47
        tay
loc_9B48
        bit ppi_pb
        bmi loc_9B44
        bvs loc_9B48
        stx ppi_pa
        lda ppi_pc
        ora #$80
        sta ppi_pc
loc_9B5A
        bit ppi_pb
        bmi loc_9B44
        bvc loc_9B5A
        lda ($68),y
        sta ppi_pa
        lda ppi_pc
        and #$7F
        sta ppi_pc
        dex
        beq loc_9B8D
loc_9B71
        iny
        lda ($68),y
loc_9B74
        bit ppi_pb
        bvs loc_9B74
        sta ppi_pa
        dex
        beq loc_9B92
        iny
        lda ($68),y
loc_9B82
        bit ppi_pb
        bvc loc_9B82
        sta ppi_pa
        dex
        bne loc_9B71
loc_9B8D
        bit ppi_pb
        bvs loc_9B8D
loc_9B92
        bit ppi_pb
        bvc loc_9B92
        rts

sub_9B98
        jsr sub_D973
        tya
        lsr
        tax
        lda #$AA
        jsr sub_E825
        bcs loc_9BA6
        rts
loc_9BA6
        pha
        txa
        pha
        lda #$FF
        jsr sub_9B20
        pla
        tax
        pla
        jmp jt_job_error
loc_9BB4
        lsr $2A67
        ldy #$00
        jsr sub_9C13
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_9BBF
        lda #$02
        pha
        jsr sub_95CA
        tax
        pla
        tay
loc_9BC8
        bit ppi_pb
        bvs loc_9BC8
        lda ppi_pa
        sta ($66),y
        iny
        dex
        beq loc_9BE4
loc_9BD6
        bit ppi_pb
        bvc loc_9BD6
        lda ppi_pa
        sta ($66),y
        iny
        dex
        bne loc_9BC8
loc_9BE4
        bit ppi_pb
        bmi loc_9C10
        bvc loc_9BE4
        jsr sub_9C24
loc_9BEE
        bit ppi_pb
        bmi loc_9C10
        bvs loc_9BEE
        jsr sub_A3F3
        jsr sub_9C13
        ldy #$00
        lda $5A
        sta ($66),y
        iny
        lda $5B
        sta ($66),y
        iny
        jsr sub_9C24
        jsr sub_9C2D
        jmp loc_9BBF
loc_9C10
        jmp sub_944A

sub_9C13
        ldx $80
        lda $2C68,x
        sta $2A57
        clc
        adc #$03
        sta $67
        lda #$00
        sta $66

sub_9C24
        lda $2A57
        asl
        tax
        tya
        sta $A0,x
        rts

sub_9C2D
        jsr sub_E9C7
        bcc loc_9C35
        jmp loc_A159
loc_9C35
        bit $2A5D
        bmi loc_9C67
        lda $2A57
        asl
        tax
        lda $5A
        cmp $2800,x
        bne loc_9C82
        lda $5B
        sbc #$01
        cmp $2801,x
        bne loc_9C82
        ror $2A67
        jsr sub_EF16
        jsr sub_EE68
        ldy #$00
loc_9C5A
        lda ($66),y
        sta ($68),y
        sta $5200,y
        iny
        bne loc_9C5A
        jmp loc_A13F
loc_9C67
        bit $2A67
        bpl loc_9C82
        lsr $2A67
        jsr sub_EE78
        beq loc_9C82
        ldy #$00
loc_9C76
        lda $5200,y
        sta $5000,y
        iny
        bne loc_9C76
        jsr sub_EF16
loc_9C82
        jsr sub_ED28
        jmp loc_A13F

sub_9C88
        jsr sub_B678
        jsr sub_AF03
        jsr sub_B08E
        pha
        jsr sub_B095
        pha
        jsr sub_B085
        bne loc_9CA1
        jsr sub_B010
        jsr sub_B026
loc_9CA1
        jsr sub_A2C7
        ldx #$00
        stx $2C00
        ldy #$90
loc_9CAB
        lda ($58),y
        sta $0200,x
        iny
        inx
        cpx #$10
        bcc loc_9CAB
        stx $56
        jsr sub_A7E1
        jsr sub_A17E
        ldx #$AD
loc_9CC0
        lda $2200,x
        cmp txt_9E49-173,x
        bne loc_9CFF
        inx
        cpx #$B8
        bcc loc_9CC0
        lda $22AB
        beq loc_9CFF
        sta $5A
        sta $2BA7
        lda $22AC
        sta $5B
        sta $2BA9
        jsr sub_B085
        cmp #$02
        beq loc_9CEA
        cmp #$03
        bne loc_9CF9
loc_9CEA
        jsr sub_A2C7
        ldy #$AB
loc_9CEF
        lda $2200,y
        sta ($58),y
        iny
        cpy #$BD
        bcc loc_9CEF
loc_9CF9
        jsr sub_9E2D
        jsr sub_9D1B
loc_9CFF
        jsr sub_9D1B
        lda $2BA7
        sta $5A
        lda $2BA8
        sta $5B
        jsr sub_9E2D
        jsr sub_A348
        pla
        tay
        pla
        jsr sub_B013
        jmp loc_B654

sub_9D1B
        lda #$00
        sta $2BBC
        jsr sub_C07C
        beq loc_9D28
        jmp loc_9E0C
loc_9D28
        jsr sub_B026
        jsr sub_B085
        bne loc_9D68
        jsr sub_A17E
        lda $2222
        beq loc_9D68
        ldy $2223
        jsr sub_B013
        jsr sub_B026
        lda $2224
        sta $2BB6
        lda $2225
        sta $2BB7
        lda $2226
        sta $2BB8
        lsr
        lsr
        lsr
        lsr
        lsr
        sec
        sbc #$07
        eor #$FF
        sta $2BC1
        lda #$FF
        sta $2BC0
        jmp loc_9E04
loc_9D68
        rts
loc_9D69
        ldy #$01
        lda ($94),y
        pha
        iny
        lda ($94),y
        pha
        ldy #$13
        lda ($94),y
        beq loc_9DC7
        sta $5A
        iny
        lda ($94),y
        sta $5B
        iny
        lda ($94),y
        pha
        iny
        lda ($94),y
        pha
        lda $2BED
        pha
        jsr sub_9E2D
        pla
        sta $2BED
        tay
        pla
        tax
        pla
        cmp #$01
        bne loc_9DC7
        txa
        beq loc_9DC7
        cpy #$03
        bne loc_9DC7
        pla
        tax
        sta $5B
        pla
        sta $5A
        pha
        txa
        pha
        jsr sub_A1A2
        ldy #$02
loc_9DB0
        sty $9D
        lda $2200,y
        beq loc_9DC3
        sta $5A
        lda $2201,y
        sta $5B
        jsr sub_9E2D
        ldy $9D
loc_9DC3
        iny
        iny
        bne loc_9DB0
loc_9DC7
        pla
        sta $5B
        pla
        sta $5A
        jsr sub_B085
        bne loc_9E01
        lda $2BED
        cmp #$06
        bne loc_9E01
        lda $5A
        ldy $5B
        jsr sub_B013
        jsr sub_B026
        jsr sub_A17E
        lda $2BB6
        sta $2224
        lda $2BB7
        sta $2225
        lda $2BB8
        sta $2226
        jsr sub_A1CF
        jsr sub_9E2D
        jmp sub_9D1B
loc_9E01
        jsr sub_9E2D
loc_9E04
        jsr sub_C0E0
        bne loc_9E0C
        jmp loc_9D28
loc_9E0C
        ldy #$00
        lda ($94),y
        bmi loc_9E18
        jsr sub_C36D
        jmp loc_9E04
loc_9E18
        and #$07
        sta $2BED
        cmp #$05
        beq loc_9E24
        jmp loc_9D69
loc_9E24
        jsr sub_BCAB
        jsr sub_BCC4
        jmp loc_9E04

sub_9E2D
        jsr sub_D91C
        jsr sub_A35C
        jsr sub_C378
loc_9E36
        jsr sub_D9DB
        lda $5A
        bne loc_9E40
        jmp sub_DB04
loc_9E40
        jsr sub_A35C
        jsr sub_9F5E
        jmp loc_9E36
txt_9E49
        !text "GEOS format"             ; $9E49

sub_9E54
        sei
        bit $2BFB
        bvs loc_9E5F
        ldx #$64
loc_9E5C
        dex
        bne loc_9E5C
loc_9E5F
        jsr sub_DA60
        bcs loc_9E6B
        ldx $80
        lda $2DA8,x
        bmi loc_9E6C
loc_9E6B
        rts
loc_9E6C
        lda $2BD8
        cmp #$61
        bne loc_9E7E
        bit $2BFB
        bvc loc_9E7B
        jmp loc_9AED
loc_9E7B
        jmp loc_9A8A
loc_9E7E
        jsr sub_9EE0
        lda $82
        bne loc_9E8C
        lda $2BC5
        beq loc_9E8C
        ldx #$0C
loc_9E8C
        lda tbl_9ECA,x
        sta $2BFC
        lda tbl_9ECA+1,x
        sta $2BFD
        bit $2BFB
        bvc loc_9EA1
        ldx #$06
        bne loc_9EAB
loc_9EA1
        lda $2BD8
        and #$C0
        asl
        rol
        rol
        rol
        tax
loc_9EAB
        lda tbl_9ED8,x
        sta $2BFE
        lda tbl_9ED8+1,x
        sta $2BFF
loc_9EB7
        ldx $80
        lda $2DA8,x
        bpl loc_9E6B
        jsr sub_A096
        jsr sub_9EC7
        jmp loc_9EB7
sub_9EC7
        jmp ($2BFC)
tbl_9ECA
        !word sub_9EF3                  ; $9ECA
        !word sub_9F2B                  ; $9ECC
        !word sub_9F2B                  ; $9ECE
        !word sub_9F2B                  ; $9ED0
        !word sub_9FA5                  ; $9ED2
        !word sub_9FD6                  ; $9ED4
        !word sub_9FA8                  ; $9ED6
tbl_9ED8
        !word sub_99B3                  ; $9ED8
        !word sub_984A                  ; $9EDA
        !word sub_97F2                  ; $9EDC
        !word sub_958C                  ; $9EDE

sub_9EE0
        lda $82
        sec
        sbc #$0F
        beq loc_9EF0
        jsr sub_DAAC
        cmp #$07
        bne loc_9EF0
        lda #$05
loc_9EF0
        asl
        tax
        rts

sub_9EF3
        lda $DE
        cmp #$FF
        bne loc_9F11
        lda $DF
        cmp #$22
        bne loc_9F11
        lda #$0D
        sta $84
        jsr sub_EE42
        lda #$00
        jsr sub_DFAD
        dec $DE
        lda #$80
        bne loc_9F22
loc_9F11
        jsr sub_A008
        sta $84
        bne loc_9F20
loc_9F18
        lda #$FF
        sta $DE
        lda #$22
        sta $DF
loc_9F20
        lda #$88
loc_9F22
        sta $2DC7
        lda $84
        sta $2DE7
        rts

sub_9F2B
        ldy $80
        lda $2DA8,y
        and #$08
        bne loc_9F38
        sta $2DA8,y
        rts
loc_9F38
        lda $2C68,y
        asl
        tax
        lda ($A0,x)
        pha
        lda $2DE8,y
        cmp $A0,x
        bne loc_9F52
        lda #$00
        sta $A0,x
        lda #$80
        sta $2DA8,y
        bne loc_9F59
loc_9F52
        inc $A0,x
        bne loc_9F59
        jsr sub_9F6E
loc_9F59
        pla
        sta $2DC8,y
        rts

sub_9F5E
        ldy $80
        lda $2C68,y
        asl
        tax
        lda #$00
        sta $A0,x
        lda ($A0,x)
        bne sub_9F6E
        rts

sub_9F6E
        inc $A0,x
        lda ($A0,x)
        sta $2801,x
        dec $A0,x
        lda ($A0,x)
        sta $2800,x
        txa
        lsr
        tax
        lda #$80
        jsr sub_E81C
        txa
        asl
        tax
        lda ($A0,x)
        sta $5A
        php
        inc $A0,x
        lda ($A0,x)
        sta $5B
        inc $A0,x
        plp
        bne loc_9F9A
        sta $2DE8,y
loc_9F9A
        tya
        tax
        inc $2D48,x
        bne loc_9FA4
        inc $2D68,x
loc_9FA4
        rts

sub_9FA5
        jmp loc_D2F0

sub_9FA8
        ldy $80
        lda $2DA8,y
        and #$08
        bne loc_9FB5
        sta $2DA8,y
        rts
loc_9FB5
        jsr sub_CEFE
        pha
        bne loc_9FD1
        lda $2DE8,y
        beq loc_9FC7
        lda #$80
        sta $2DA8,y
        bne loc_9FD1
loc_9FC7
        lda #$00
        sta $2BB1
        jsr sub_C537
        ldy $80
loc_9FD1
        pla
        sta $2DC8,y
        rts

sub_9FD6
        ldy $80
        lda $2DA8,y
        and #$08
        bne loc_9FE4
        lda #$89
        sta $2DA8,y
loc_9FE4
        lda $2C68,y
        asl
        tax
        lda $A0,x
        cmp $2DE8,x
        bne sub_9FF4
        lda #$00
        sta $A0,x

sub_9FF4
        inc $A0,x

sub_9FF6
        lda ($A0,x)
        sta $2DC8,y
        lda $A0,x
        cmp $2DE8,y
        bne loc_A007
        lda #$81
        sta $2DA8,y
loc_A007
        rts

sub_A008
        ldy $80
        lda $2C68,y
        asl
        tax
        lda ($A0,x)
        pha
        lda $2DE8,y
        cmp $A0,x
        bne loc_A01D
        lda #$FF
        sta $A0,x
loc_A01D
        pla
        inc $A0,x
        rts

sub_A021
        sei
        lda $83
        and #$8F
        cmp #$0F
        bcs loc_A030
        jsr sub_DA92
        bcc loc_A042
loc_A02F
        rts
loc_A030
        jsr sub_F5E4
        lda #$1E
        sta $80
        ldx #$00
        txa
loc_A03A
        sta $0200,x
        inx
        bne loc_A03A
        beq loc_A04F
loc_A042
        lda $2BFB
        cmp #$60
        bne loc_A04C
        jmp loc_9BB4
loc_A04C
        jsr sub_9EE0
loc_A04F
        lda tbl_A099,x
        sta $2BFC
        lda tbl_A099+1,x
        sta $2BFD
        bit $2BFB
        bvc loc_A064
        ldx #$06
        bne loc_A06E
loc_A064
        lda $2BD8
        and #$C0
        asl
        rol
        rol
        rol
        tax
loc_A06E
        lda tbl_A0A5,x
        sta $2BFE
        lda tbl_A0A5+1,x
        sta $2BFF
loc_A07A
        ldx $80
        lda $2DA8,x
        lsr
        bcs loc_A08A
        lda $83
        and #$F0
        cmp #$F0
        bne loc_A02F
loc_A08A
        jsr sub_A096
        jsr sub_A093
        jmp loc_A07A
sub_A093
        jmp ($2BFC)
sub_A096
        jmp ($2BFE)
tbl_A099
        !word sub_A0AD                  ; $A099
        !word sub_A0C1                  ; $A09B
        !word sub_A0C1                  ; $A09D
        !word sub_A0C1                  ; $A09F
        !word sub_A163                  ; $A0A1
        !word sub_A168                  ; $A0A3
tbl_A0A5
        !word sub_9A1C                  ; $A0A5
        !word sub_9967                  ; $A0A7
        !word sub_992C                  ; $A0A9
        !word sub_95CA                  ; $A0AB

sub_A0AD
        ldx $DC
        cpx #$FF
        beq loc_A0BA
        lda $84
        sta $0200,x
        inc $DC
loc_A0BA
        bit $81
        bmi loc_A0C0
        inc $4B
loc_A0C0
        rts

sub_A0C1
        ldy $80
        lda $2C68,y
        asl
        tax
        lda $A0,x
        bne loc_A0D6
        jsr sub_A0DD
        ldx $80
        lda $2C68,x
        asl
        tax
loc_A0D6
        lda $84
        sta ($A0,x)
        inc $A0,x
        rts

sub_A0DD
        jsr sub_A3F3
        ldx $2BA1
        lda $2B70,x
        beq loc_A0FB
        ldy $90E8
        ldx part_type,y
        cmp dat_AF79,x
        beq loc_A0FB
        jsr sub_D90D
        lda #$73
        jmp jt_dos_error
loc_A0FB
        ldy $80
        lda $2C68,y
        sta $2A57
        asl
        tax
        lda $5A
        sta ($A0,x)
        inc $A0,x
        lda $5B
        sta ($A0,x)
        inc $A0,x
        php
        sei
        jsr sub_E9C7
        bcs loc_A159
        bit $2A5D
        bmi loc_A13B
        lda $2A57
        asl
        tax
        lda $5A
        cmp $2800,x
        bne loc_A13B
        lda $5B
        sbc #$01
        cmp $2801,x
        bne loc_A13B
        jsr sub_EF16
        jsr sub_ED34
        jmp loc_A13E
loc_A13B
        jsr sub_ED28
loc_A13E
        plp
loc_A13F
        lda $2A57
        asl
        tax
        lda $5A
        sta $2800,x
        lda $5B
        sta $2801,x
        ldx $80
        inc $2D48,x
        bne loc_A158
        inc $2D68,x
loc_A158
        rts
loc_A159
        lda #$04
        ldx $2A57
        sta $20,x
        jmp jt_job_error
sub_A163
        jmp loc_D27B

sub_A166
        rts

sub_A167
        rts

sub_A168
        lda $84
        jsr sub_A170
        jmp sub_9FF6

sub_A170
        pha
        ldy $80
        lda $2C68,y
        asl
        tax
        pla
        sta ($A0,x)
        inc $A0,x
        rts

sub_A17E
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_A181
        lda #$90
        pha
        lda $2BA8
loc_A187
        sta $283F
        lda $2BA7
loc_A18D
        sta $283E
        ldx #$1F
        pla
        jmp jt_do_job

sub_A196
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_A199
        lda #$90
        pha
        lda $2BA9
        jmp loc_A187

sub_A1A2
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_A1A5
        lda #$90
        pha
        lda $5B
        sta $283F
        lda $5A
        jmp loc_A18D

sub_A1B2
        jsr sub_A17E
        lda $2224
        sta $283E
        lda $2225
        sta $283F
        lda $2226
        pha
        lda #$80
        ldx #$1F
        jsr jt_do_job
        pla
        tax
        rts

sub_A1CF
        lda #$90
        ldx #$1F
        jmp jt_do_job
loc_A1D6
        clc
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
sub_A1D8
        sec
        ror $2BA2
        ldx $2BA1
        lda #$00
        sta $2B40,x
        jsr sub_B07E
        asl
        tax
        lda tbl_A1F8-2,x
        sta $2BDC
        lda tbl_A1F8-1,x
        sta $2BDD
        jmp ($2BDC)
tbl_A1F8
        !word sub_A226                  ; $A1F8
        !word sub_A202                  ; $A1FA
        !word sub_A209                  ; $A1FC
        !word sub_A218                  ; $A1FE
        !word sub_A218                  ; $A200

sub_A202
        lda #$12
        ldx #$00
        jmp sub_A241

sub_A209
        jsr sub_A202
        lda #$35
        ldx #$00
loc_A210
        inc $59
        jsr sub_A241
        dec $59
        rts

sub_A218
        jsr sub_B08E
        pha
        ldx #$01
        jsr sub_A241
        pla
        ldx #$02
        bne loc_A210

sub_A226
        ldx $2BA1
        lda $2B80,x
        asl
        clc
        adc #$02
        and #$FE
        tax
        lda #$01
        jsr sub_A241
        lda #$01
        ldx $283D
        inx
        jmp loc_A210

sub_A241
        sta $283C
        stx $283D
        lda $59
        sta $287E
        lda #$00
        sta $289E
        lda #$01
        sta $28BE
        ldx #$1E
        lda #$CC
        bit $2BA2
        bpl loc_A261
        lda #$CE
loc_A261
        jsr jt_do_job
        ldx $2BA1
        rts

sub_A268
        jsr sub_A2C7
        lda $5A
        lsr
        lsr
        lsr
        lsr
        cmp $2B80,x
        bne loc_A277
        rts
loc_A277
        pha
        lda $2B40,x
        beq loc_A280
        jsr sub_A1D8
loc_A280
        pla
        sta $2B80,x
        jmp loc_A1D6

sub_A287
        jsr sub_A2C7
        lda $2B80,x
        bpl loc_A292
        jsr sub_A2AA
loc_A292
        rts

sub_A293
        jsr sub_A2C7
        lda $2B80,x
        beq loc_A2A6
        lda $2B40,x
        beq loc_A2A3
        jsr sub_A1D8
loc_A2A3
        jsr sub_A2AA
loc_A2A6
        rts

sub_A2A7
        jsr sub_A2C7

sub_A2AA
        lda #$00
        sta $2B80,x
        jmp loc_A1D6

sub_A2B2
        jsr sub_A2C7
        inc $2B80,x
        lda $2B80,x
        cmp #$10
        bcc loc_A2C4
        lda #$00
        sta $2B80,x
loc_A2C4
        jmp loc_A1D6

sub_A2C7
        lda $90E8
        ldx #$0F
loc_A2CC
        stx $2BA1
        cmp $2B30,x
        beq loc_A321
        dex
        bpl loc_A2CC
        pha
        ldx #$00
loc_A2DA
        stx $2BA1
        lda $2B30,x
        beq loc_A301
        inx
        cpx #$10
        bcc loc_A2DA
        dex
loc_A2E8
        stx $2BA1
        lda $2B30,x
        sta $2BFA
        jsr sub_A32D
        bcc loc_A301
        ldx $2BA1
        dex
        bpl loc_A2E8
        lda #$70
        jmp jt_dos_error
loc_A301
        ldx $2BA1
        pla
        sta $2B30,x
        lda #$00
        sta $2B40,x
        sta $2B50,x
        sta $2B60,x
        sta $2B70,x
        sta $2FC0,x
        lda #$FF
        sta $2B80,x
        sta $2B90,x
loc_A321
        txa
        asl
        clc
        adc #$60
        sta $59
        lda #$00
        sta $58
        rts

sub_A32D
        ldx #$00
loc_A32F
        lda $2C48,x
        cmp #$FF
        beq loc_A341
        and #$1F
        tay
        lda $2CC8,y
        cmp $2BFA
        beq loc_A347
loc_A341
        inx
        cpx #$13
        bcc loc_A32F
        clc
loc_A347
        rts

sub_A348
        jsr sub_A2C7
        lda $2B40,x
        beq loc_A35B
loc_A350
        jmp sub_A1D8

sub_A353
        jsr sub_A2C7
        lda $2B80,x
        bpl loc_A350
loc_A35B
        rts

sub_A35C
        jsr sub_A539
        beq loc_A390
loc_A361
        sta ($58),y
        jsr sub_A5B4
        bcs loc_A36D
        sec
        sbc #$01
        sta ($58),y
loc_A36D
        jsr sub_A3B1
        bcs loc_A37D
        lda $2B50,x
        bne loc_A37A
        dec $2B60,x
loc_A37A
        dec $2B50,x
loc_A37D
        lda $2B60,x
        bne loc_A38E
        lda $2B50,x
        cmp #$03
        bcs loc_A38E
        lda #$72
        jsr sub_DFB5
loc_A38E
        lda #$01
loc_A390
        rts

sub_A391
        jsr sub_A539
        bne loc_A3B0
        sta ($58),y
        jsr sub_A5B4
        bcs loc_A3A1
        adc #$01
        sta ($58),y
loc_A3A1
        jsr sub_A3B1
        bcs loc_A3AE
        inc $2B50,x
        bne loc_A3AE
        inc $2B60,x
loc_A3AE
        lda #$01
loc_A3B0
        rts

sub_A3B1
        jsr sub_B08E
        cmp $5A
        bne loc_A3CD
        lda part_type,x
        cmp #$01
        bne loc_A3CB
        lda $5A
        cmp #$01
        bne loc_A3CD
        lda $5B
        cmp #$40
        bcs loc_A3CD
loc_A3CB
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
loc_A3CD
        clc
        ldx $2BA1
        lda #$01
        sta $2B40,x
        rts

sub_A3D7
        ldx $5A
        jsr sub_AF7F
loc_A3DC
        lda $2BC9
        beq loc_A3E7
        cmp $5B
        bcc loc_A3F0
        beq loc_A3F0
loc_A3E7
        jsr sub_A539
        bne loc_A3F2
        inc $5B
        bne loc_A3DC
loc_A3F0
        lda #$00
loc_A3F2
        rts

sub_A3F3
        jsr sub_A4CF
        bne loc_A3FB
        jmp sub_A4FF
loc_A3FB
        lda #$03
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_A3FE
        lda #$01
        sta $2BA0
loc_A403
        jsr sub_A5B4
        bne loc_A435
        ldx $2BC6
        cpx $5A
        beq loc_A430
        bcs loc_A424
        inc $5A
        lda $5A
        cmp $2BC8
        bcc loc_A403
        dex
loc_A41B
        stx $5A
        dec $2BA0
        bne loc_A403
        beq loc_A430
loc_A424
        dec $5A
        lda $5A
        cmp $2BC7
        bcs loc_A403
        inx
        bne loc_A41B
loc_A430
        lda #$72
        jmp sub_B66F
loc_A435
        ldx $5A
        jsr sub_AF7F
        jsr sub_A46C
        clc
        adc $5B
        sta $5B
        lda $5B
        cmp $2BC9
        bcc loc_A44E
        sbc $2BC9
        sta $5B
loc_A44E
        jsr sub_A3D7
        bne loc_A45C
loc_A453
        lda #$00
        sta $5B
        jsr sub_A3D7
        beq loc_A45F
loc_A45C
        jmp sub_A35C
loc_A45F
        lda #$71
        jmp jt_dos_error

sub_A464
        jsr sub_A4D2
        bne loc_A3FE
        jmp loc_A4DB

sub_A46C
        jsr sub_B07E
        cmp #$04
        bcc loc_A476
        lda #$01
        rts
loc_A476
        lda #$01
        ldx $5A
        cpx #$12
        bne loc_A480
        lda #$03
loc_A480
        rts

sub_A481
        jsr sub_A4D2
        bne loc_A489
        jmp loc_A4EC
loc_A489
        lda #$00
        sta $2BA0
        lda $2BC6
        sta $5A
loc_A493
        inc $2BA0
        lda $5A
        cmp $2BC6
        bcc loc_A4B4
        lda $2BC6
        sbc $2BA0
        bcc loc_A4B4
        sta $5A
        cmp $2BC7
        bcc loc_A4B4
        jsr sub_A5B4
        beq loc_A4B4
        jmp loc_A453
loc_A4B4
        lda $2BC6
        clc
        adc $2BA0
        sta $5A
        cmp $2BC8
        bcs loc_A4CA
        jsr sub_A5B4
        beq loc_A493
        jmp loc_A453
loc_A4CA
        lda #$67
        jmp jt_dos_error

sub_A4CF
        jsr sub_D989

sub_A4D2
        jsr sub_A287
        jsr sub_AF7F
        jmp sub_B085
loc_A4DB
        lda $5A
        cmp #$01
        bne sub_A4FF
        lda $5B
        cmp #$40
        bcs sub_A4FF
        lda $2BA7
        bne loc_A4F8
loc_A4EC
        lda $2BA7
        cmp #$01
        bne loc_A4F8
        cmp $2BA8
        beq loc_A506
loc_A4F8
        sta $5A
        lda $2BA9
        sta $5B

sub_A4FF
        jsr sub_A519
        bne loc_A516
        lda #$01
loc_A506
        sta $5A
        lda #$40
        sta $5B
        jsr sub_A519
        bne loc_A516
        lda #$72
        jmp sub_B66F
loc_A516
        jmp loc_A361

sub_A519
        jsr sub_A544
loc_A51C
        jsr sub_A550
        bne loc_A538
        inc $5B
        inx
        cpx #$08
        bcc loc_A51C
        ldx #$00
        iny
        cpy #$20
        bcc loc_A51C
        inc $5A
        lda $5A
        cmp $2BC8
        bne sub_A519
loc_A538
        rts

sub_A539
        jsr sub_B07E
        cmp #$04
        bcs loc_A565
        cmp #$01
        bne loc_A579

sub_A544
        jsr sub_A60B
        jsr sub_A268
        jsr sub_A5C5
        jsr sub_A5A0

sub_A550
        lda ($58),y
        and dat_A55D,x
        php
        lda ($58),y
        eor dat_A55D,x
        plp
        rts
dat_A55D
        !byte $80,$40,$20,$10,$08,$04,$02,$01 ; $A55D
loc_A565
        jsr sub_A5D9
loc_A568
        jsr sub_A5A0
        iny
loc_A56C
        lda ($58),y
        and dat_A5AC,x
        php
        lda ($58),y
        eor dat_A5AC,x
        plp
        rts
loc_A579
        jsr sub_A60B
        lda $5A
        cmp #$24
        bcc loc_A597
        inc $59
        lda $5A
        sec
        sbc #$24
        sta $58
        asl
        clc
        adc $58
        sta $58
        jsr sub_A5A0
        jmp loc_A56C
loc_A597
        lda $5A
        asl
        asl
        sta $58
        jmp loc_A568

sub_A5A0
        lda $5B
        and #$07
        tax
        lda $5B
        lsr
        lsr
        lsr
        tay
        rts
dat_A5AC
        !byte $01,$02,$04,$08,$10,$20,$40,$80 ; $A5AC

sub_A5B4
        jsr sub_B07E
        cmp #$04
        bcs sub_A5D9
        cmp #$01
        bne loc_A5F7
        jsr sub_A60B
        jsr sub_A268

sub_A5C5
        lda $5A
        asl
        asl
        asl
        asl
        asl
        bcc loc_A5D0
        inc $59
loc_A5D0
        clc
        adc $58
        sta $58
        ldy #$00
        sec
        rts

sub_A5D9
        jsr sub_A60B
        lda $5A
        cmp #$29
        bcc loc_A5E6
        inc $59
        sbc #$28
loc_A5E6
        asl
        sta $58
        asl
        clc
        adc $58
        adc #$0A
        sta $58
loc_A5F1
        ldy #$00
        lda ($58),y
        clc
        rts
loc_A5F7
        jsr sub_A60B
        lda $5A
        cmp #$24
        bcc loc_A604
        adc #$B8
        bne loc_A606
loc_A604
        asl
        asl
loc_A606
        sta $58
        jmp loc_A5F1

sub_A60B
        jsr sub_A2C7
        lda $2B90,x
        bpl loc_A618
        lda #$74
        jmp jt_dos_error
loc_A618
        rts
loc_A619
        jsr sub_A2C7
        ldx #$01
        jsr sub_AF7F
        ldx $2BA1
        lda #$00
        sta $2B50,x
        sta $2B60,x
        jsr sub_B085
        beq loc_A664
        lda $5A
        pha
        ldx $2BC7
        dex
        stx $5A
loc_A63A
        inc $5A
        lda $5A
        cmp $2BC6
        beq loc_A63A
        cmp $2BC8
        bcs loc_A65E
        jsr sub_A5B4
        lda ($58),y
        clc
        ldx $2BA1
        adc $2B50,x
        sta $2B50,x
        bcc loc_A63A
        inc $2B60,x
        bne loc_A63A
loc_A65E
        pla
        sta $5A
        ldx #$00
        rts
loc_A664
        lda $5A
        pha
        jsr sub_A293
        lda #$01
        sta $5A
        lda #$20
        sta $58
        ldy #$08
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_A675
        ldy #$00
        lda #$00
        sta $2BA0
loc_A67C
        ldx #$08
        lda ($58),y
loc_A680
        asl
        bcc loc_A688
        inc $2BA0
        beq loc_A69F
loc_A688
        dex
        bne loc_A680
        iny
        cpy #$20
        bcc loc_A67C
        ldx $2BA1
        lda $2B50,x
        clc
        adc $2BA0
        sta $2B50,x
        bcc loc_A6A5
loc_A69F
        ldx $2BA1
        inc $2B60,x
loc_A6A5
        inc $5A
        lda $5A
        cmp $2BC8
        beq loc_A6C7
        lda $58
        clc
        adc #$20
        sta $58
        bne loc_A675
        inc $59
        lda $59
        and #$01
        bne loc_A675
        jsr sub_A2B2
        lda $2B80,x
        bne loc_A675
loc_A6C7
        pla
        sta $5A
        ldx #$00
        rts

sub_A6CD
        jsr sub_B6E7
        jsr sub_B833
        jsr sub_EE3C
        jsr sub_B07E
        beq loc_A6DF
        cmp #$06
        bcc loc_A6E4
loc_A6DF
        lda #$77
        jmp sub_DF3B
loc_A6E4
        jsr sub_A2C7
        lda #$00
        sta $2B90,x
        jsr sub_DB26
        ldx $2C01
        cpx $56
        beq loc_A70E
        lda $0200,x
        sta $2BA3
        lda $0201,x
        sta $2BA4
        jsr sub_B08E
        bne loc_A71B
        txa
        jsr sub_AFF4
        jmp loc_A71B
loc_A70E
        jsr sub_AF03
        jsr sub_B08E
        bne loc_A71B
        lda #$73
        jmp sub_B66F
loc_A71B
        ldx #$01
        jsr sub_AF7F
        jsr sub_B085
        bne loc_A732
        lda #$01
        cmp $2BA7
        bne loc_A731
        cmp $2BA8
        beq loc_A736
loc_A731
        rts
loc_A732
        cmp #$04
        bcc loc_A73C
loc_A736
        jsr sub_A74B
        jsr sub_A181
loc_A73C
        jsr sub_A7BF
        jsr sub_A199
        jsr sub_A7E1
        jsr sub_A348
        jmp sub_AF03

sub_A74B
        jsr sub_A767
        jsr sub_B085
        bne loc_A7B4
        lda $2BA7
        sta $2220
        lda $2BA8
        sta $2221
        lda #$48
        ldx #$31
        tay
        jmp loc_A7AB

sub_A767
        jsr sub_A7B5
        lda $2BA7
        sta $2200
        lda $2BA9
        sta $2201
        ldx #$18
        lda #$A0
loc_A77A
        sta $2204,x
        dex
        bpl loc_A77A
        ldx $2C00
        ldy #$00
loc_A785
        lda $0200,x
        cmp #$2C
        beq loc_A799
        sta $2204,y
        inx
        cpx $56
        bcs loc_A799
        iny
        cpy #$10
        bcc loc_A785
loc_A799
        lda $2BA3
        sta $2216
        lda $2BA4
        sta $2217
        lda #$44
        ldx #$33
        ldy #$44
loc_A7AB
        sta $2202
        stx $2219
        sty $221A
loc_A7B4
        rts

sub_A7B5
        lda #$00
        tax
loc_A7B8
        sta $2200,x
        inx
        bne loc_A7B8
        rts

sub_A7BF
        jsr sub_A196
        ldx #$00
loc_A7C4
        lda #$00
        sta $2200,x
        sta $2201,x
        sta $2202,x
        txa
        clc
        adc #$20
        tax
        bne loc_A7C4
        beq loc_A7DB

sub_A7D8
        jsr sub_A7B5
loc_A7DB
        lda #$FF
        sta $2201
        rts

sub_A7E1
        jsr sub_A2C7
        jsr sub_A9A3
        ldx $2BA1
        lda #$01
        sta $2B40,x
        jsr sub_B07E
        asl
        tax
        lda tbl_A803-2,x
        sta $2BDC
        lda tbl_A803-1,x
        sta $2BDD
        jmp ($2BDC)
tbl_A803
        !word sub_A80D                  ; $A803
        !word sub_A8BE                  ; $A805
        !word sub_A917                  ; $A807
        !word sub_A85B                  ; $A809
        !word sub_A85B                  ; $A80B

sub_A80D
        ldy #$02
        lda #$48
        sta ($58),y
        iny
        eor #$FF
        sta ($58),y
        iny
        jsr sub_A90A
        lda #$C0
        sta ($58),y
        ldy #$08
        ldx $2BC8
        dex
        txa
        sta ($58),y
        ldy #$24
        lda #$1F
        sta ($58),y
        iny
        lda #$00
        ldx $2BA1
        sta $2B80,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_A839
        ldy #$00
        lda #$FF
        jsr sub_A9A6
        jsr sub_A1D8
        inc $2B80,x
        lda $2B80,x
        cmp #$10
        bcc loc_A839
        lda $2BC8
        sbc #$02
        sta $2B60,x
        lda #$C0
        sta $2B50,x
        rts

sub_A85B
        lda $2BC7
        sta $5A
loc_A860
        jsr sub_A5D9
        lda #$28
        sta ($58),y
        lda #$FF
loc_A869
        iny
        sta ($58),y
        cpy #$05
        bcc loc_A869
        inc $5A
        lda $5A
        cmp $2BC8
        bcc loc_A860
        lda $2BA7
        sta $5A
        jsr sub_A5D9
        lda #$24
        sta ($58),y
        iny
        lda #$F0
        sta ($58),y
        jsr sub_A2C7
        lda $2BA7
        ldx #$02
        jsr sub_A8A3
        inc $59
        lda #$00
        ldx #$FF
        jsr sub_A8A3
        dec $59
        jmp loc_A619

sub_A8A3
        ldy #$00
        sta ($58),y
        iny
        txa
        sta ($58),y
        iny
        lda #$44
        sta ($58),y
        iny
        eor #$FF
        sta ($58),y
        iny
        jsr sub_A90A
        lda #$C0
        sta ($58),y
        rts

sub_A8BE
        jsr sub_A8C4
        jmp loc_A619

sub_A8C4
        ldy #$00
        ldx #$00
loc_A8C8
        lda dat_A976,x
        sta $2BA0
loc_A8CE
        lda dat_A97F,x
        sta ($58),y
        iny
        lda dat_A988,x
        sta ($58),y
        iny
        lda dat_A991,x
        sta ($58),y
        iny
        lda dat_A99A,x
        sta ($58),y
        iny
        dec $2BA0
        bne loc_A8CE
        inx
        cpx #$09
        bcc loc_A8C8
        ldy #$90
        ldx $2C00
loc_A8F5
        lda $0200,x
        cmp #$2C
        beq loc_A908
        sta ($58),y
        inx
        cpx $56
        bcs loc_A908
        iny
        cpy #$A0
        bcc loc_A8F5
loc_A908
        ldy #$A2

sub_A90A
        lda $2BA3
        sta ($58),y
        iny
        lda $2BA4
        sta ($58),y
        iny
        rts

sub_A917
        jsr sub_A8C4
        ldy #$03
        lda #$80
        sta ($58),y
        ldx #$01
        ldy #$DD
loc_A924
        lda dat_A976,x
        sta $2BA0
        lda dat_A97F,x
loc_A92D
        sta ($58),y
        iny
        dec $2BA0
        bne loc_A92D
        inx
        cpx #$06
        bcc loc_A924
        ldy #$EE
        lda #$00
        sta ($58),y
        inc $59
        ldx #$01
        ldy #$00
loc_A946
        lda dat_A976,x
        sta $2BA0
loc_A94C
        lda dat_A988,x
        sta ($58),y
        iny
        lda dat_A991,x
        sta ($58),y
        iny
        lda dat_A99A,x
        sta ($58),y
        iny
        dec $2BA0
        bne loc_A94C
        inx
        cpx #$06
        bcc loc_A946
        ldy #$33
        lda #$00
loc_A96C
        sta ($58),y
        iny
        cpy #$36
        bcc loc_A96C
        jmp loc_A619
dat_A976
        !byte $01,$11,$01,$06,$06,$05,$05,$01,$01 ; $A976
dat_A97F
        !byte $12,$15,$11,$13,$12,$11,$A0,$A0,$A0 ; $A97F
dat_A988
        !byte $01,$FF,$FC,$FF,$FF,$FF,$A0,$32,$A0 ; $A988
dat_A991
        !byte $41,$FF,$FF,$FF,$FF,$FF,$A0,$41,$A0 ; $A991
dat_A99A
        !byte $00,$1F,$07,$07,$03,$01,$A0,$A0,$00 ; $A99A

sub_A9A3
        lda #$00
        tay

sub_A9A6
        sta ($58),y
        iny
        bne sub_A9A6
        inc $59
loc_A9AD
        sta ($58),y
        iny
        bne loc_A9AD
        dec $59
        rts

sub_A9B5
        ldy #$00
        ldx #$00
        lda #$2D
        jsr sub_B761
        bne loc_A9C6
loc_A9C0
        jmp loc_DF97
loc_A9C3
        jmp loc_DF94
loc_A9C6
        txa
        bne loc_A9C3
        ldx #$07
        lda $0200,y
loc_A9CE
        cmp dat_AC09,x
        beq loc_A9D8
        dex
        bpl loc_A9CE
        bmi loc_A9C0
loc_A9D8
        txa
        ora #$80
        sta $2BE2
        jsr sub_A9F3
        lda $2BE2
        asl
        tax
        lda tbl_AC11+1,x
        sta $51
        lda tbl_AC11,x
        sta $50

sub_A9F0
        jmp ($0050)

sub_A9F3
        ldy #$00
        ldx #$00
        lda #$3A
        jsr sub_B761
        bne sub_AA00
        ldy #$03

sub_AA00
        lda $0200,y
        cmp #$20
        beq loc_AA0F
        cmp #$1D
        beq loc_AA0F
        cmp #$2C
        bne loc_AA15
loc_AA0F
        iny
        cpy $56
        bcc sub_AA00
        rts
loc_AA15
        jsr sub_AA24
        inc $2BEA
        ldy $2BEC
        cpx #$04
        bcc loc_AA0F
        bcs loc_A9C3

sub_AA24
        lda #$00
        sta $50
        sta $51
        sta $53
        ldx #$FF
loc_AA2E
        lda $0200,y
        cmp #$40
        bcs loc_AA4C
        cmp #$30
        bcc loc_AA4C
        and #$0F
        pha
        lda $51
        sta $52
        lda $50
        sta $51
        pla
        sta $50
        iny
        cpy $56
        bcc loc_AA2E
loc_AA4C
        sty $2BEC
        clc
        lda #$00
loc_AA52
        inx
        cpx #$03
        bcs loc_AA66
        ldy $50,x
loc_AA59
        dey
        bmi loc_AA52
        adc dat_AA74,x
        bcc loc_AA59
        clc
        inc $53
        bne loc_AA59
loc_AA66
        pha
        ldx $2BEA
        lda $53
        sta $2C20,x
        pla
        sta $2C28,x
        rts
dat_AA74
        !byte $01,$0A,$64               ; $AA74

sub_AA77
        jsr sub_ABE7
        jsr sub_AED0
        jsr sub_A391
        jmp loc_B654

sub_AA83
        jsr sub_ABE7
        jsr sub_AED0
        lda $5B
        pha
        jsr sub_A3D7
        beq loc_AA9C
        pla
        cmp $5B
        bne loc_AAB5
        jsr sub_A35C
        jmp loc_B654
loc_AA9C
        pla
loc_AA9D
        lda #$00
        sta $5B
        inc $5A
        beq loc_AABA
        lda $2BC8
        beq loc_AAB0
        cmp $5A
        bcc loc_AABA
        beq loc_AABA
loc_AAB0
        jsr sub_A3D7
        beq loc_AA9D
loc_AAB5
        lda #$65
        jsr jt_dos_error
loc_AABA
        lda #$65
        jsr sub_B66F

sub_AABF
        jsr sub_ABE3
        jmp sub_D8AA

sub_AAC5
        jsr sub_DAB7
        lda ($A0,x)
        rts

sub_AACB
        jsr sub_AABF
        lda #$00
        jsr sub_DCC6
        jsr sub_AAC5
        sta $2DE8,y
        lda #$89
        sta $2DA8,y
        rts

sub_AADF
        jsr sub_AACB
        jsr sub_9FF4
        jmp loc_B654

sub_AAE8
        pha
        pha
        jmp loc_AAF0

sub_AAED
        jsr sub_A9F3
loc_AAF0
        jsr sub_AACB
        lda $2DE8,y
        sta $2DC8,y
        lda #$FF
        sta $2DE8,y
        pla
        pla
        jmp loc_B654

sub_AB03
        jsr sub_ABE3
        jsr sub_DCD4
        tay
        dey
        cmp #$02
        bcs loc_AB11
        ldy #$01
loc_AB11
        lda #$00
        jsr sub_DCC6
        tya
        jsr sub_CEEA
        txa
        pha
        jsr sub_AB39
        pla
        tax
        ldy $80
        jmp loc_ABC2

sub_AB26
        pha
        pha
        jmp loc_AB2E

sub_AB2B
        jsr sub_A9F3
loc_AB2E
        jsr sub_ABE3
        jsr sub_AB39
        pla
        pla
        jmp loc_B654

sub_AB39
        jsr sub_D8AD
        jsr sub_A2C7
        lda #$00
        jsr sub_DCC6
        jsr sub_B085
        ldx $5A
        ldy $5B
        cmp #$06
        bcs loc_AB77
        cmp #$04
        bcs loc_AB78
        cmp #$02
        beq loc_AB8B
        bcs loc_AB83
        cpx #$01
        bne loc_AB77
        cpy #$02
        bcc loc_AB77
        cpy #$22
        bcs loc_AB77
        dey
        dey
        tya
        lsr
        ldx $2BA1
        cmp $2B80,x
        bne loc_AB77
        tya
        lsr
        bcc loc_AB95
        bcs loc_AB93
loc_AB77
        rts
loc_AB78
        cpx #$28
        bne loc_AB82
        dey
        beq loc_AB95
        dey
        beq loc_AB93
loc_AB82
        rts
loc_AB83
        cpx #$35
        bne loc_AB8B
        tya
        beq loc_AB93
        rts
loc_AB8B
        cpx #$12
        bne loc_AB92
        tya
        beq loc_AB95
loc_AB92
        rts
loc_AB93
        inc $59
loc_AB95
        ldy #$00
loc_AB97
        lda ($94),y
        sta ($58),y
        iny
        bne loc_AB97
        rts

sub_AB9F
        jsr sub_AABF
        lda #$00
        sta $50
        lda $9C
        clc
        adc #$03
        sta $51
        jsr sub_A9F0
        jmp loc_B654

sub_ABB3
        jsr sub_ABC8
        lda $9C
        asl
        tax
        lda $2C29
        sta $A0,x
        jsr sub_DAB7
loc_ABC2
        jsr sub_9FF6
        jmp loc_B654

sub_ABC8
        lda $2C28
        cmp #$0F
        bcc loc_ABD4
loc_ABCF
        lda #$70
        jmp sub_B66F
loc_ABD4
        sta $82
        jsr sub_DA60
        bcs loc_ABCF
        jsr sub_DCF2
        sta $9C
        ldx #$01
        rts

sub_ABE3
        jsr sub_ABC8
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_ABE7
        ldx #$00
        lda $2C29,x
        sta $5A
        lda $2C2A,x
        sta $5B
        lda $2C28,x
        bne loc_AC04
        lda $90E8
        jsr sub_B693
        jsr sub_D91C
        jmp sub_EE3C
loc_AC04
        lda #$74
        jmp sub_B66F
dat_AC09
        !byte $41,$46,$52,$57,$45,$50,$D2,$D7 ; $AC09
tbl_AC11
        !word sub_AA83                  ; $AC11
        !word sub_AA77                  ; $AC13
        !word sub_AADF                  ; $AC15
        !word sub_AB03                  ; $AC17
        !word sub_AB9F                  ; $AC19
        !word sub_ABB3                  ; $AC1B
        !word sub_AAE8                  ; $AC1D
        !word sub_AB26                  ; $AC1F
loc_AC21
        jsr sub_B6DE
        bne loc_AC29
        jmp loc_B114
loc_AC29
        jsr sub_B6F1
        jsr sub_B83D
        lda $2BE3
        and #$55
        bne loc_AC43
        ldx $2C00
        lda $0200,x
        cmp #$2A
        bne loc_AC43
loc_AC40
        jmp loc_DF94
loc_AC43
        lda $2BE3
        and #$D9
        bne loc_AC40
        jsr sub_BE95
        jsr sub_AD71
        lda $2BEB
        cmp #$03
        bcc loc_ACAA
        lda $2C10
        cmp $2C11
        bne loc_ACAA
        lda $2C40
        cmp $2C41
        bne loc_ACAA
        lda $2C38
        cmp $2C39
        bne loc_ACAA
        lda $2C30
        cmp $2C31
        bne loc_ACAA
        jsr sub_B1CE
        lda #$01
        sta $2BEC
        jsr sub_AD03
        jsr sub_DAAC
        bcs loc_AC8B
        cmp #$02
        bne loc_AC90
loc_AC8B
        lda #$64
        jsr sub_B66F
loc_AC90
        lda #$12
        sta $82
        lda $2C59
        sta $2C5A
        lda #$FF
        sta $2C59
        jsr sub_C929
        ldx #$02
        jsr sub_ACC2
        jmp loc_B654
loc_ACAA
        jsr sub_ACB0
        jmp loc_B654

sub_ACB0
        jsr sub_B1EA
        lda $2C10
        jsr sub_B023
        jsr sub_C389
        jsr sub_C3BD
        ldx $2BEA

sub_ACC2
        stx $2BEC
        jsr sub_AD03
        lda #$11
        sta $82
        jsr sub_DA60
        jsr sub_DAAC
        bne loc_ACD7
        jsr sub_AD41
loc_ACD7
        lda #$08
        sta $81
        jmp loc_ACE1
loc_ACDE
        jsr sub_CEBD
loc_ACE1
        jsr sub_CE84
        lda #$80
        jsr sub_D9FD
        beq loc_ACDE
        jsr sub_DAAC
        beq loc_ACF3
        jsr sub_CEBD
loc_ACF3
        ldx $2BEC
        inx
        cpx $2BEB
        bcc sub_ACC2
        lda #$12
        sta $82
        jmp sub_CD1C

sub_AD03
        ldx $2BEC
        lda $2C30,x
        sta $5A
        lda $2C38,x
        sta $5B
        lda $2C10,x
        jsr sub_B023
        jsr sub_C378
        ldx $2BEC
        lda $2C40,x
        jsr sub_DCC6
        ldx $2BEC
        lda $2C18,x
        and #$07
        sta $2BED
        lda #$00
        sta $2BF3
        jsr sub_C894
        ldy #$01
        jsr sub_DAAC
        beq loc_AD3D
        iny
loc_AD3D
        tya
        jmp sub_DCC6

sub_AD41
        jsr sub_D3A6
        jsr sub_D7BE
        bne loc_AD4D
        lda $2BF6
        pha
loc_AD4D
        lda $9A
        pha
        lda $99
        pha
        lda #$12
        sta $82
        jsr sub_DA92
        jsr sub_D687
        sta $9B
        pla
        sta $99
        pla
        sta $9A
        jsr sub_D7BE
        bne loc_AD6E
        pla
        sta $2BF6
loc_AD6E
        jmp loc_D52B

sub_AD71
        ldx #$00
loc_AD73
        lda $2C18,x
        and #$07
        cmp #$05
        bcs loc_AD83
        inx
        cpx $2BEB
        bcc loc_AD73
        rts
loc_AD83
        lda #$64
        jmp sub_B66F

sub_AD88
        lda $0201
        cmp #$2D
        bne loc_ADAE
        lda $0202
        cmp #$43
        beq loc_ADB4
        cmp #$38
        beq loc_ADA8
        cmp #$39
        beq loc_ADA8
        cmp #$44
        bne loc_ADAE
        lda #$80
        sta $2BE7
        rts
loc_ADA8
        and #$0F
        sta $2BE6
        rts
loc_ADAE
        jmp loc_B260
loc_ADB1
        jmp loc_DF97
loc_ADB4
        lda $56
        cmp #$0C
        bcc loc_ADB1
        sei
        jsr sub_AE39
        lda $2A00
        cmp #$2F
        beq loc_ADDC
loc_ADC5
        jsr sub_AE57
loc_ADC8
        lda $2A10
        sta $2DE7
        lda #$FF
        ldx #$23
        sta $DE
        stx $DF
        lda #$88
        sta $2DC7
        rts
loc_ADDC
        jsr sub_AE28
        beq loc_ADC5
        lda #$28
        sta $2A00
        lda $2A08
        sta $DE
        lda $2A07
        sta $DF
        lda #$00
        sta $2A07
        lda #$01
        sta $2A08
loc_ADFA
        jsr sub_EEE1
        lda #$00
        sta $68
        lda #$52
        sta $69
        jsr sub_AE57
        bne loc_ADC8
        inc $2A05
        bne loc_AE17
        inc $2A04
        bne loc_AE17
        inc $2A03
loc_AE17
        ldx $DE
        bne loc_AE1D
        dec $DF
loc_AE1D
        dec $DE
        bne loc_ADFA
        ldx $DF
        bne loc_ADFA
        jmp loc_ADC8

sub_AE28
        lda #$00
        sta $2A07
        sta $2A08
        jsr sub_AE57
        pha
        jsr sub_AE39
        pla
        rts

sub_AE39
        jsr sub_EED7
        lda $0204
        sta $68
        lda $0205
        sta $69
        ldx #$06
        ldy #$00
loc_AE4A
        lda $0200,x
        sta $2A00,y
        iny
        inx
        cpx $56
        bcc loc_AE4A
        rts

sub_AE57
        lda $0203
        jsr sub_F14E
        bne loc_AE65
        lda #$85
        sta $2A10
        rts
loc_AE65
        jsr sub_EFA7
        lda $2A10
        rts
loc_AE6C
        ldx $56
        dex
        bne loc_AE7E
        lda #$01
        jsr sub_DAC2
        jmp loc_AEA6
loc_AE79
        lda #$70
        jmp sub_B66F
loc_AE7E
        ldy #$01
        jsr sub_AA00
        lda $2C28
        cmp #$1E
        bcs loc_AE79
        sta $41
        jsr sub_DCA5
        beq loc_AE79
        lda #$00
        jsr sub_DAC2
        ldx $80
        lda $2C28
        sta $2C68,x
        tax
        lda #$00
        sta $20,x
        sta $2960,x
loc_AEA6
        ldx $82
        lda $2C48,x
        ora #$40
        sta $2C48,x
        ldy $80
        lda #$FF
        sta $2DE8,y
        lda #$89
        sta $2DA8,y
        lda $2C68,y
        sta $2DC8,y
        asl
        tax
        lda #$01
        sta $A0,x
        lda #$0E
        sta $2D88,y
        jmp loc_B654

sub_AED0
        jsr sub_B07E
        cmp #$FF
        bne loc_AEDA
        lda #$00
        rts
loc_AEDA
        jsr sub_A2C7
        lda $2B90,x
        beq loc_AEEB
        jsr sub_AF03
        ldx $2BA1
        lda $2B90,x
loc_AEEB
        rts

sub_AEEC
        jsr sub_B678
        jsr sub_B07E
        cmp #$04
        beq loc_AEFA
        cmp #$05
        bne loc_AEFD
loc_AEFA
        jsr sub_AFF4
loc_AEFD
        jsr sub_AF03
        jmp loc_B654

sub_AF03
        jsr sub_DB26
        lda #$00
        sta $2BF7
        jsr sub_A2C7
        lda #$FF
        sta $2B90,x
        jsr sub_B07E
        beq loc_AF20
        cmp #$FF
        beq loc_AF20
        cmp #$06
        bcc loc_AF21
loc_AF20
        rts
loc_AF21
        jsr sub_B08E
        bne loc_AF29
        jsr sub_AFF4
loc_AF29
        jsr sub_A2A7
        ldx $2BA1
        ldy #$02
        lda ($58),y
        sta $2B70,x
        jsr sub_B085
        beq loc_AF3F
        cmp #$04
        bcc loc_AF50
loc_AF3F
        ldy #$03
        lda ($58),y
        eor #$FF
        ldx $2BA1
        cmp $2B70,x
        bne loc_AF20
        ldy #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_AF50
        ldy #$A2
        lda ($58),y
        sta $2BA3
        iny
        lda ($58),y
        sta $2BA4
        ldx $2BA1
        lda #$00
        sta $2B90,x
        jsr sub_B026
        jmp loc_A619

sub_AF6B
        cmp #$00
        beq loc_AF78
        pha
        jsr sub_B07E
        tax
        pla
        cmp dat_AF79,x
loc_AF78
        rts
dat_AF79
        !byte $00,$48,$41,$41,$44,$44   ; $AF79

sub_AF7F
        stx $2BC9
        jsr sub_B08E
        sta $2BC6
        jsr sub_B085
        beq loc_AFA3
        cmp #$03
        beq loc_AFBD
        bcc loc_AFBA
        cmp #$06
        bcc loc_AFDC
        cmp #$FF
        beq loc_AF9C
        rts
loc_AF9C
        lda #$01
        sta $2BC6
        ldx #$00
loc_AFA3
        lda part_size_lo,x
        asl
        lda part_size_hi,x
        rol
        tax
        inx
        stx $2BC8
        ldx #$01
        stx $2BC7
        dex
        stx $2BC9
        rts
loc_AFBA
        lda #$24
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_AFBD
        lda #$47
        sta $2BC8
        lda #$01
        sta $2BC7
        lda $2BC9
        ldx #$00
loc_AFCC
        cmp dat_EAC3,x
        bcc loc_AFD4
        inx
        bne loc_AFCC
loc_AFD4
        dex
        lda dat_EADC,x
        sta $2BC9
        rts
loc_AFDC
        lda $9200,x
        sta $2BC8
        lda $2BC6
        cmp #$28
        bne loc_AFEB
        lda #$01
loc_AFEB
        sta $2BC7
        lda #$28
        sta $2BC9
        rts

sub_AFF4
        jsr sub_B085
        beq sub_B010
        cmp #$04
        bcc loc_B003
        lda #$28
        ldy #$51
        bne sub_B013
loc_B003
        cmp #$02
        bne loc_B00A
        ldy #$24
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B00A
        ldy #$47
        lda #$12
        bne sub_B013

sub_B010
        lda #$01
        tay

sub_B013
        jsr sub_F73B
        ldx $90E8
        sta $9100,x
        tya
        sta $9200,x
        jmp sub_F730

sub_B023
        jsr sub_F79E

sub_B026
        jsr sub_B08E
        bne loc_B031
        jsr sub_AFF4
        jsr sub_B08E
loc_B031
        sta $2BA7
        lda #$00
        sta $2BA8
        jsr sub_B085
        beq loc_B066
        cmp #$04
        bcc loc_B060
        cmp #$06
        bcc loc_B05A
        cmp #$FF
        bne loc_B059
        lda $90E6
        sta $2BA7
        lda $90E7
        sta $2BA8
        sta $2BA9
loc_B059
        rts
loc_B05A
        lda #$03
        sta $2BA9
        rts
loc_B060
        lda #$01
        sta $2BA9
        rts
loc_B066
        jsr sub_B095
        sta $2BA8
        cmp #$01
        bne loc_B077
        cmp $2BA7
        bne loc_B077
        lda #$21
loc_B077
        clc
        adc #$01
        sta $2BA9
        rts

sub_B07E
        ldx $90E8
        lda part_type,x
        rts

sub_B085
        ldx $90E8
        lda part_type,x
        cmp #$01
        rts

sub_B08E
        ldx $90E8
        lda $9100,x
        rts

sub_B095
        ldx $90E8
        lda $9200,x
        rts
loc_B09C
        lda $0201
        cmp #$2D
        bne loc_B114
        lda $0203
        sta $50
        lda $0204
        sta $51
        ldy #$00
        lda $0202
        cmp #$52
        beq loc_B0EA
        cmp #$57
        beq loc_B119
        cmp #$45
        bne loc_B114
        lda $51
        cmp #$80
        bcc loc_B0C9
        cmp #$FF
        bcs loc_B0C9
        rts
loc_B0C9
        cmp #$06
        bne loc_B0E1
        lda $50
        bne loc_B0E1
        ldy #$07
loc_B0D3
        lda $0608,y
        cmp dat_B125,y
        bne loc_B0E1
        dey
        bpl loc_B0D3
        jmp loc_B209
loc_B0E1
        ldy #$00
        lda #$45
        cmp #$45
        jmp ($0050)
loc_B0EA
        lda ($50),y
        sta $84
        lda $56
        cmp #$06
        bcc loc_B10E
        ldx $0205
        dex
        beq loc_B10E
        txa
        clc
        adc $50
        inc $50
        sta $2E07
        lda $50
        sta $DE
        lda $51
        sta $DF
        jmp loc_9F20
loc_B10E
        jsr sub_DA60
        jmp loc_9F18
loc_B114
        lda #$31
        jmp sub_B66F
loc_B119
        lda $0206,y
        sta ($50),y
        iny
        cpy $0205
        bcc loc_B119
        rts
dat_B125
        !byte $06,$A2,$00,$86,$F9,$20,$86,$D5 ; $B125
loc_B12D
        lda $0201
        cmp #$2D
        bne loc_B176
        lda $0202
        cmp #$48
        bne loc_B174
        jsr sub_BDF5
        lda #$00
        jsr sub_BA20
        jsr sub_A17E
        jsr sub_B085
        beq loc_B14F
        cmp #$04
        bcc loc_B152
loc_B14F
        ldy #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B152
        ldy #$90
        lda #$10
        sta $50
        ldx $2C00
loc_B15B
        cpx $56
        bcs loc_B163
        lda $0200,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B163
        lda #$A0
        sta $2200,y
        inx
        iny
        dec $50
        bne loc_B15B
        jsr sub_A181
        jmp loc_B654
loc_B174
        cmp #$50
loc_B176
        php
        jsr sub_B6E7
        jsr sub_B83D
        plp
        bne loc_B18E
        lda #$00
        sta $2C10
        jsr sub_B023
        lda $2C00
        sta $2C08
loc_B18E
        lda $2C10
        sta $2C11
        lda $2C01
        sta $2C09
        jsr sub_BECF
        jsr sub_B1EA
        lda $2C31
        sta $5A
        lda $2C39
        sta $5B
        jsr sub_D9A1
        jsr sub_D965
        lda $2C41
        clc
        adc #$03
        jsr sub_DCC6
        jsr sub_DCF2
        tay
        ldx $2C00
        lda #$10
        jsr sub_C11E
        jsr sub_D9A7
        jsr sub_D965
        jmp loc_B654

sub_B1CE
        lda $2C19
        and #$07
        sta $2BED
        ldx $2BEB
loc_B1D9
        dex
        cpx $2BEA
        bcc loc_B1E9
        lda $2C20,x
        bne loc_B1D9
        lda #$62
        jmp sub_B66F
loc_B1E9
        rts

sub_B1EA
        jsr sub_B1CE
loc_B1ED
        lda $2C20,x
        beq loc_B1F7
        lda #$63
        jmp sub_B66F
loc_B1F7
        dex
        bpl loc_B1ED
        rts

sub_B1FB
        jsr sub_BDF5
        jsr sub_AED0
        jsr sub_BECF
        lda $2C20
        beq loc_B227
loc_B209
        ldx $2BB6
        ldy $2BB7
        lda $2BB8
        pha
        stx $5A
        sty $5B
        jsr sub_A1A2
        pla
        tax
        lda $2200,x
        eor #$40
        sta $2200,x
        jsr sub_A1A5
loc_B227
        jmp sub_DB6B

sub_B22A
        lda $0201
        cmp #$2D
        bne loc_B23C
        lda $0202
        cmp #$30
        beq loc_B23F
        cmp #$31
        beq loc_B252
loc_B23C
        jmp loc_DF97
loc_B23F
        lda #$80
        bit $2BF9
        beq loc_B251
        lda #$7F
        and $49
        sta $49
        lda #$00
        sta $2BF9
loc_B251
        rts
loc_B252
        lda #$80
        bit $49
        bne loc_B25F
        sta $2BF9
        ora $49
        sta $49
loc_B25F
        rts
loc_B260
        jsr sub_B6E7
        jsr sub_B8F8
        jsr sub_B83D
loc_B269
        ldx #$00
        stx $85
loc_B26D
        stx $2BBD
        lda $2C10,x
        bne loc_B278
        jmp loc_B320
loc_B278
        jsr sub_BEB4
        jsr sub_B023
        jsr sub_BE84
        lda $2BBD
        jsr sub_BF0B
        bpl loc_B28C
        jmp loc_B311
loc_B28C
        jsr sub_DA0F
        bcc loc_B309
        ldy #$00
        lda ($94),y
        sta $2BA6
        and #$40
        bne loc_B309
        lda $2BA6
        and #$07
        cmp #$06
        bne loc_B2AC
        lda $2BE2
        cmp #$03
        bne loc_B309
loc_B2AC
        jsr sub_C36D
        lda $2BA6
        and #$07
        cmp #$05
        bne loc_B2E0
        iny
        lda ($94),y
        sta $5A
        iny
        lda ($94),y
        sta $5B
        ldy #$1C
        lda ($94),y
        sta $2BA6
        iny
        lda ($94),y
        sta $2BA5
loc_B2CF
        jsr sub_D91C
        jsr sub_A391
        jsr sub_BC76
        bne loc_B2CF
        jsr sub_A348
        jmp loc_B307
loc_B2E0
        ldy #$13
        lda ($94),y
        beq loc_B2F0
        sta $5A
        iny
        lda ($94),y
        sta $5B
        jsr sub_B32B
loc_B2F0
        ldx $2BBF
        lda #$20
        and $2C18,x
        bne loc_B307
        lda $2C20,x
        sta $5A
        lda $2C28,x
        sta $5B
        jsr sub_B32B
loc_B307
        inc $85
loc_B309
        jsr sub_BF02
        bmi loc_B311
        jmp loc_B28C
loc_B311
        jsr sub_BEB4
        ldx $2BBD
        inx
        cpx $2BEB
        bcs loc_B320
        jmp loc_B26D
loc_B320
        lda $85
        sta $5A
        ldy #$00
        lda #$01
        jmp loc_B661

sub_B32B
        jsr sub_A391
        lda $5A
        sta $283E
        lda $5B
        sta $283F
        ldx #$1F
        lda #$AA
        jsr sub_E81C
        ldy #$01
        lda ($68),y
        sta $5B
        dey
        lda ($68),y
        sta $5A
        bne sub_B32B
        jsr sub_A348
        jmp sub_DB04

sub_B352
        sei
        lda $0201
        cmp #$2D
        bne loc_B368
        lda $0202
        cmp #$52
        beq loc_B3AC
        cmp #$57
        bne loc_B368
        jmp loc_B48B
loc_B368
        jmp loc_DF97
dat_B36B
        !byte $15,$14,$12,$11,$0F,$0E,$09,$08 ; $B36B
        !byte $06,$05,$0C,$0B           ; $B373
txt_B377
        !text "SMTWTFS"                 ; $B377
txt_B37E
        !text "UOUEHRA"                 ; $B37E
txt_B385
        !text "NNEDUIT"                 ; $B385
txt_B38C
        !text "..S.R.."                 ; $B38C
txt_B393
        !text "       /  /     :  :    M" ; $B393
loc_B3AC
        lda $0203
        cmp #$41
        beq loc_B3C1
        cmp #$42
        bne loc_B3BA
        jmp loc_B42C
loc_B3BA
        cmp #$44
        bne loc_B368
        jmp loc_B440
loc_B3C1
        ldx #$18
loc_B3C3
        lda txt_B393,x
        sta $2300,x
        dex
        bpl loc_B3C3
        jsr sub_B5A5
        lda rtc_weekday
        and #$07
        tax
        lda txt_B377,x
        sta $2DE7
        sta $2300
        lda txt_B37E,x
        sta $2301
        lda txt_B385,x
        sta $2302
        lda txt_B38C,x
        sta $2303
        ldx #$0B
loc_B3F2
        lda rtc_regs,x
        and dat_B550,x
        ora #$30
        ldy dat_B36B,x
        sta $2300,y
        dex
        bpl loc_B3F2
        ldy #$17
        lda rtc_hour10
        and #$04
        bne loc_B40F
        lda #$41
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B40F
        lda #$50
        sta $2300,y
        iny
loc_B415
        tya
        clc
        adc #$00
        sta $2E07
        jsr sub_F5ED
        inc $DE
        lda #$88
        sta $2DC7
loc_B426
        lda #$00
        sta rtc_ctrl_d
        rts
loc_B42C
        jsr sub_B457
        ldy #$01
loc_B431
        lda $2B00,y
        sta $2300,y
        iny
        cpy #$08
        bcc loc_B431
        dey
        jmp loc_B415
loc_B440
        jsr sub_B457
        ldy #$01
loc_B445
        lda $2B00,y
        jsr sub_B464
        sta $2300,y
        iny
        cpy #$08
        bcc loc_B445
        dey
        jmp loc_B415

sub_B457
        jsr sub_B55D
        lda $2B00
        sta $2DE7
        sta $2300
        rts

sub_B464
        pha
        and #$0F
        sta $50
        pla
        and #$F0
        lsr
        pha
        clc
        adc $50
        sta $50
        pla
        lsr
        lsr
        clc
        adc $50
        rts

sub_B47A
        pha
        lda #$00
        sta $50
        pla
loc_B480
        cmp #$0A
        bcc loc_B48A
        sbc #$0A
        inc $50
        bne loc_B480
loc_B48A
        rts
loc_B48B
        lda $0203
        cmp #$41
        beq loc_B4A3
        cmp #$42
        bne loc_B499
        jmp loc_B4E1
loc_B499
        cmp #$44
        bne loc_B4A0
        jmp loc_B512
loc_B4A0
        jmp loc_DF97
loc_B4A3
        lda $56
        cmp #$1D
        bcc loc_B4BE
        ldx #$06
loc_B4AB
        lda $0204
        cmp txt_B377,x
        bne loc_B4BB
        lda $0205
        cmp txt_B37E,x
        beq loc_B4C1
loc_B4BB
        dex
        bpl loc_B4AB
loc_B4BE
        jmp loc_DF97
loc_B4C1
        txa
        jsr sub_B5A5
        sta rtc_weekday
        ldx #$0B
loc_B4CA
        ldy dat_B36B,x
        lda $0204,y
        and dat_B550,x
        sta rtc_regs,x
        dex
        bpl loc_B4CA
        lda $021B
        and #$10
        jmp loc_B505
loc_B4E1
        jsr sub_B539
        ldy #$05
        ldx #$0B
loc_B4E8
        lda $0200,y
        pha
        lsr
        lsr
        lsr
        lsr
        and dat_B550,x
        sta rtc_regs,x
        pla
        dex
        and dat_B550,x
        sta rtc_regs,x
        iny
        dex
        bpl loc_B4E8
loc_B502
        lda $0200,y
loc_B505
        beq loc_B509
        lda #$04
loc_B509
        ora rtc_hour10
        sta rtc_hour10
        jmp loc_B426
loc_B512
        jsr sub_B539
        ldx #$0B
        ldy #$05
loc_B519
        lda $0200,y
        jsr sub_B47A
        pha
        lda $50
        and dat_B550,x
        sta rtc_regs,x
        pla
        dex
        and dat_B550,x
        sta rtc_regs,x
        dex
        iny
        cpy #$0B
        bcc loc_B519
        jmp loc_B502

sub_B539
        lda $56
        cmp #$0C
        bcc loc_B546
        lda $0204
        cmp #$07
        bcc loc_B549
loc_B546
        jmp loc_DF97
loc_B549
        jsr sub_B5A5
        sta rtc_weekday
        rts
dat_B550
        !byte $0F,$07,$0F,$07,$0F,$03,$0F,$03 ; $B550
        !byte $0F,$01,$0F,$0F,$07       ; $B558

sub_B55D
        php
        sei
        jsr sub_B5A5
        lda rtc_weekday
        and #$07
        sta $2B00
        ldx #$0B
        ldy #$01
loc_B56E
        lda rtc_regs,x
        and dat_B550,x
        asl
        asl
        asl
        asl
        sta $50
        dex
        lda rtc_regs,x
        and dat_B550,x
        clc
        sed
        adc $50
        cld
        sta $2B00,y
        iny
        dex
        bpl loc_B56E
        lda rtc_hour10
        and #$04
        sta $2B00,y
        lda #$00
        sta rtc_ctrl_d
        plp
        rts
loc_B59C
        sta rtc_ctrl_d
        ldx #$4C
loc_B5A1
        dex
        bne loc_B5A1
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
sub_B5A5
        pha
        lda #$01
        sta rtc_ctrl_d
        lda rtc_ctrl_d
        and #$02
        bne loc_B59C
        pla
        rts

sub_B5B4
        txa
        pha
        jsr sub_B55D
        ldy #$01
        pla
        pha
        tax
loc_B5BE
        lda $2B00,y
        jsr sub_B464
        sta $2217,x
        inx
        iny
        cpy #$06
        bcc loc_B5BE
        pla
        tax
        lda $221A,x
        sbc #$0C
        bne loc_B5D9
        sta $221A,x
loc_B5D9
        lda $2B07
        beq loc_B5E7
        lda #$0C
        clc
        adc $221A,x
        sta $221A,x
loc_B5E7
        rts
txt_B5E8
        !text "VI/MBUP&CRSNTGLW"        ; $B5E8
dat_B5F8
        !byte $FF,$FF,$FF,$9E,$FF,$FF,$FF,$FF ; $B5F8
        !byte $51,$DD,$1C,$9E,$18       ; $B600
dat_B605
        !byte $21,$09,$24,$0C,$00,$1E,$12,$27 ; $B605
        !byte $03,$15,$18,$0F,$1B,$06,$57,$5A ; $B60D

sub_B615
        lda $2BD6
        jsr sub_B023
        lda #$00
        sta $2BB4
        sta $2BB5
        jsr sub_DFA8
        lda $83
        and #$8F
        bpl loc_B633
        eor #$8F
        beq loc_B633
        jmp loc_C694
loc_B633
        jsr sub_B7AC
        lda ($DC),y
        ldx #$0F
loc_B63A
        cmp txt_B5E8,x
        beq loc_B645
        dex
        bpl loc_B63A
        jmp loc_DF97
loc_B645
        stx $2BE2
        lda dat_B605,x
        sta $50
        lda #$FF
        sta $51
        jmp ($0050)
loc_B654
        lda $2BDE
        beq loc_B65C
        jmp sub_B66F
loc_B65C
        lda #$00
        tay
        sty $5A
loc_B661
        sty $5B
loc_B663
        jsr sub_DFB5
        jsr sub_F5E4
        jsr sub_EE42
loc_B66C
        jmp sub_DB6B

sub_B66F
        ldy #$00
        sty $5A
        sty $5B
        jmp jt_dos_error

sub_B678
        ldy #$00
        jsr sub_B6B8

sub_B67D
        dey
        jsr sub_B6CF
        bne loc_B68D
loc_B683
        dey
        jsr sub_B6CF
        beq loc_B683
        iny
        jsr sub_B690
loc_B68D
        jmp sub_EE3C

sub_B690
        jsr sub_BAE9

sub_B693
        jsr sub_B69D
        bcc loc_B6B4
        lda #$74
        jmp sub_B66F

sub_B69D
        cmp #$00
        bne loc_B6A4
        lda $90E8
loc_B6A4
        pha
        tax
        lda part_type,x
        beq loc_B6B5
        cmp #$06
        bcs loc_B6B5
        pla
        jsr sub_B023
        clc
loc_B6B4
        rts
loc_B6B5
        pla
        sec
        rts

sub_B6B8
        lda $0200,y
        cmp #$3A
        beq loc_B6CE
        cmp #$2C
        beq loc_B6CC
        cmp #$3D
        beq loc_B6CC
        iny
        cpy $56
        bcc sub_B6B8
loc_B6CC
        ora #$00
loc_B6CE
        rts

sub_B6CF
        lda $0200,y
        cmp #$30
        bcc loc_B6DD
        cmp #$3A
        bcs loc_B6CC
        cmp $0200,y
loc_B6DD
        rts

sub_B6DE
        ldy #$00
        ldx #$00
        lda #$3A
        jmp sub_B761

sub_B6E7
        jsr sub_B6DE
        bne sub_B6F1
loc_B6EC
        lda #$34
        jmp sub_B66F

sub_B6F1
        dey
        dey
        sty $2C00
        txa
        bne loc_B6EC

sub_B6F9
        lda #$3D
        jsr sub_B761
        txa
        beq loc_B703
        lda #$40
loc_B703
        ora #$21
        sta $2BE3
        inx
        stx $2BEA
        stx $2BEB
        lda $2BE4
        beq loc_B721
        lda #$80
        ora $2BE3
        sta $2BE3
        lda #$00
        sta $2BE4
loc_B721
        tya
        beq loc_B74D
        sta $2C00,x
        lda $2BEA
        sta $2BEC
        lda #$8D
        jsr sub_B761
        inx
        stx $2BEB
        dex
        lda $2BE4
        beq loc_B73E
        lda #$08
loc_B73E
        cpx $2BEA
        beq loc_B745
        ora #$04
loc_B745
        ora #$03
        eor $2BE3
        sta $2BE3
loc_B74D
        lda $2BE3
        ldx $2BE2
        and dat_B5F8,x
        bne loc_B759
        rts
loc_B759
        sta $2BDE
        lda #$30
        jmp sub_B66F

sub_B761
        sta $2BE5
loc_B764
        cpy $56
        bcs loc_B797
        lda ($DC),y
        iny
        cmp $2BE5
        beq loc_B799
        cmp #$2A
        beq loc_B778
        cmp #$3F
        bne loc_B77B
loc_B778
        inc $2BE4
loc_B77B
        cmp #$2C
        bne loc_B764
        tya
        sta $2C01,x
        lda $2BE4
        and #$7F
        beq loc_B792
        lda #$80
        sta $2C18,x
        sta $2BE4
loc_B792
        inx
        cpx #$05
        bcc loc_B764
loc_B797
        ldy #$00
loc_B799
        lda $56
        sta $2C01,x
        lda $2BE4
        and #$7F
        beq loc_B7AA
        lda #$80
        sta $2C18,x
loc_B7AA
        tya
        rts

sub_B7AC
        ldy $DC
        beq loc_B7E6
        dey
        beq loc_B7E5
        lda $0200
        cmp #$55
        bne loc_B7C1
        lda $0201
        cmp #$30
        beq loc_B7C5
loc_B7C1
        lda $0200,y
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B7C5
        lda #$00
        cmp #$0D
        beq loc_B7E6
        dey
        lda $0200
        cmp #$55
        bne loc_B7DA
        lda $0201
        cmp #$30
        beq loc_B7DE
loc_B7DA
        lda $0200,y
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B7DE
        lda #$00
        cmp #$0D
        beq loc_B7E6
        iny
loc_B7E5
        iny
loc_B7E6
        sty $56
        cpy #$FF
        ldy #$FF
        bcc sub_B7F6
        sty $2BE2
        lda #$32
        jmp sub_B66F

sub_B7F6
        ldy #$00
        tya
        sta $DC
        sta $2BF3
        sta $2BED
        sta $2BEE
        sta $97
        sta $2BEC
        sta $2BEA
        sta $2BEB
        sta $2BE4
        sta $2BDE
        ldx #$05
loc_B817
        sta $2BFF,x
        sta $2C2F,x
        sta $2C37,x
        sta $2C3F,x
        sta $2C0F,x
        sta $2C17,x
        sta $2C1F,x
        sta $2C27,x
        dex
        bne loc_B817
        rts

sub_B833
        jsr sub_B843
        bcc loc_B842
loc_B838
        lda #$74
        jmp sub_B66F

sub_B83D
        jsr sub_B851
        bcs loc_B838
loc_B842
        rts

sub_B843
        lda $2BEB
        sta $2BEA
        lda #$01
        sta $2BEB
        sta $2BEC

sub_B851
        ldx #$00
loc_B853
        stx $97
        jsr sub_B866
        ldx $97
        inx
        cpx $2BEB
        bcc loc_B853
        lda $2C10
        jmp sub_B69D

sub_B866
        lda $90E8
        cpx #$00
        beq loc_B870
        lda $2C10
loc_B870
        sta $2C10,x
        lda $2C00,x
        sta $2C08,x
        inx
        ldy $2C00,x
        sty $50
        tax
        tay
loc_B881
        lda $0200,x
        cmp #$3A
        beq loc_B896
        cmp #$3D
        beq loc_B895
        cmp #$2C
        beq loc_B895
        inx
        cpx $50
        bcc loc_B881
loc_B895
        rts
loc_B896
        lda $0200,y
        cmp #$3E
        beq loc_B895
        cmp #$3C
        beq loc_B895
        inx
        txa
        pha
        ldx $97
        sta $2C08,x
        tay
        dey
        beq loc_B8EB
        dey
        lda $0200,y
        cmp #$2F
        bne loc_B8D5
loc_B8B5
        lda $0200,y
        cmp #$2F
        bne loc_B8C2
        tya
        sta $2C08,x
        lda #$2F
loc_B8C2
        cmp #$3D
        beq loc_B8CF
        cmp #$2C
        beq loc_B8CF
        dey
        cpy #$FF
        bne loc_B8B5
loc_B8CF
        ldy $2C08,x
        beq loc_B8EB
        dey
loc_B8D5
        jsr sub_B6CF
        bne loc_B8EB
loc_B8DA
        dey
        cpy #$FF
        beq loc_B8E4
        jsr sub_B6CF
        beq loc_B8DA
loc_B8E4
        iny
        jsr sub_BAE9
        tay
        bne loc_B8EE
loc_B8EB
        lda $90E8
loc_B8EE
        ldx $97
        sta $2C10,x
        pla
        sta $2C00,x
        rts

sub_B8F8
        ldy #$00
        lda $2BEA
        cmp $2BEB
        beq loc_B922
        dec $2BEB
        ldy $2BEB

sub_B908
        lda $2C00,y
        tay
        lda ($DC),y
        ldy $90E8
        beq loc_B927
        ldy #$06
        cmp #$42
        beq loc_B922
        dey
loc_B91A
        cmp txt_C292,y
        beq loc_B922
        dey
        bne loc_B91A
loc_B922
        tya
        sta $2BEE
        rts
loc_B927
        ldy #$07
loc_B929
        cmp txt_C299,y
        beq loc_B922
        dey
        bne loc_B929
        beq loc_B922

sub_B933
        lda $0201
        cmp #$50
        beq loc_B94B
        cmp #$D0
        beq loc_B945
        cmp #$44
        beq loc_B97B
        jmp loc_AC21
loc_B945
        lda $0202
        jmp loc_B95E
loc_B94B
        lda $56
        cmp #$02
        bne loc_B959
        lda $90E3
        sta $5A
        jmp loc_B974
loc_B959
        ldy #$02
        jsr sub_BAE9
loc_B95E
        tax
        pha
        sta $5A
        lda part_type,x
        beq loc_B96B
        cmp #$FF
        bne loc_B970
loc_B96B
        lda #$77
        jmp jt_dos_error
loc_B970
        pla
        jsr sub_F78C
loc_B974
        ldy #$00
        lda #$02
        jmp loc_B661
loc_B97B
        jsr sub_B6DE
        beq loc_B9BA
        dey
        dey
        sty $2C00
        jsr sub_B833
        jsr sub_B085
        bne loc_B9DB
        ldy $2C08
        cpy $2C00
        bne loc_B9F5
        iny
        cpy $56
        bne loc_B9F5
        dey
        lda $0200,y
        cmp #$5F
        beq loc_B9AC
        cmp #$2F
        bne loc_B9F5
loc_B9A6
        jsr sub_B010
loc_B9A9
        jmp loc_B65C
loc_B9AC
        jsr sub_A17E
        lda $2222
        beq loc_B9A9
        ldy $2223
        jmp loc_BA0A
loc_B9BA
        lda $56
        cmp #$03
        bne loc_B9D0
        jsr sub_B085
        bne loc_B9DB
        lda $0202
        cmp #$5F
        beq loc_B9AC
        cmp #$2F
        beq loc_B9A6
loc_B9D0
        ldx #$00
        ldy #$02
        lda #$2F
        jsr sub_B761
        bne loc_B9DE
loc_B9DB
        jmp loc_DF94
loc_B9DE
        dey
        sty $2C08
        jsr sub_B67D
        lda $90E8
        sta $2C10
        jsr sub_B085
        bne loc_B9DB
        lda #$00
        sta $2C00
loc_B9F5
        lda #$01
        sta $2BEB
        lda #$00
        jsr sub_BA20
        lda $2C00
        bne loc_BA10
        lda $2BA7
        ldy $2BA8
loc_BA0A
        jsr sub_B013
        jmp loc_B65C
loc_BA10
        jsr sub_BED9
        ldy $2C28
        lda $2C20
        bne loc_BA0A
loc_BA1B
        lda #$39
        jmp sub_B66F

sub_BA20
        sta $2BCD
        jsr sub_B026
        jsr sub_B085
        bne loc_BA36
        ldx $2BCD
        lda $2C08,x
        cmp $2C00,x
        bne loc_BA37
loc_BA36
        rts
loc_BA37
        sta $2BCC
        lda $2BB4
        pha
        lda $2BB5
        pha
        lda $2C18,x
        pha
        lda $2C00,x
        pha
        lda $2BEE
        pha
        lda $2C20,x
        pha
        lda $82
        pha
        lda #$06
        sta $2BEE
        sta $2BB4
        sta $2BB5
loc_BA60
        inc $2BCC
        ldx $2BCC
        cpx $56
        bcs loc_BACA
        lda $0200,x
        cmp #$3A
        beq loc_BACA
        cmp #$2F
        bne loc_BA84
        lda #$01
        sta $2BA7
        sta $2BA8
        lda #$22
        sta $2BA9
        bne loc_BA60
loc_BA84
        txa
        ldy $2BCD
        sta $2C00,y
loc_BA8B
        inx
        cpx $56
        bcs loc_BA97
        lda $0200,x
        cmp #$2F
        bne loc_BA8B
loc_BA97
        lda $56
        pha
        stx $2BCC
        stx $56
        lda #$00
        sta $2C20,y
        jsr sub_BE84
        jsr sub_BF15
        beq loc_BAAF
        jmp loc_BA1B
loc_BAAF
        pla
        sta $56
        ldy $2BCD
        lda $2C20,y
        sta $2BA7
        lda $2C28,y
        sta $2BA8
        clc
        adc #$01
        sta $2BA9
        jmp loc_BA60
loc_BACA
        ldx $2BCD
        pla
        sta $82
        pla
        sta $2C20,x
        pla
        sta $2BEE
        pla
        sta $2C00,x
        pla
        sta $2C18,x
        pla
        sta $2BB5
        pla
        sta $2BB4
        rts

sub_BAE9
        php
        sei
        tya
        pha
        ldx #$00
loc_BAEF
        lda $0200,y
        cmp #$30
        bcc loc_BB02
        cmp #$3A
        bcs loc_BB02
        cpy $56
        bcs loc_BB02
        iny
        inx
        bne loc_BAEF
loc_BB02
        dex
        cpx #$03
        bcc loc_BB0A
loc_BB07
        jmp loc_DF94
loc_BB0A
        pla
        tay
        lda #$00
        sta $2A65
loc_BB11
        lda $0200,y
        and #$0F
        sta $2A64
        beq loc_BB2C
        clc
        lda $2A65
loc_BB1F
        adc dat_BB35,x
        bcs loc_BB07
        dec $2A64
        bne loc_BB1F
        sta $2A65
loc_BB2C
        iny
        dex
        bpl loc_BB11
        lda $2A65
        plp
        rts
dat_BB35
        !byte $01,$0A,$64               ; $BB35

sub_BB38
        lda #$01
        sta $2C00
        lda $56
        sta $2C01
        jsr sub_B833
        jsr sub_B07E
        cmp #$04
        beq loc_BB53
        cmp #$05
        beq loc_BB53
        jmp loc_DF97
loc_BB53
        jsr sub_AED0
        lda $2C00
        cmp $56
        beq loc_BBBE
        jsr sub_BECF
        lda $2C20
        beq loc_BB78
        jsr sub_BBF5
        bcc loc_BB8A
        lda #$63
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_BB6D
        lda #$62
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_BB70
        lda #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_BB73
        lda #$77
        jsr sub_B66F
loc_BB78
        jsr sub_BBF5
        bcc loc_BB6D
        ldx $2BEF
        lda $0206,x
        cmp #$43
        bne loc_BB70
        jmp loc_BC31
loc_BB8A
        lda $2C18
        and #$07
        cmp #$05
        bne loc_BB6D
        jsr sub_BCAB
loc_BB96
        jsr sub_D91C
        jsr sub_BC76
        bne loc_BB96
        bcc loc_BB73
        ldy #$02
        lda ($94),y
        bne loc_BB73
        dey
        lda $5A
        tax
        sbc ($94),y
        cmp #$02
        beq loc_BB73
        bcc loc_BB73
        lda ($94),y
        pha
        txa
        tay
        pla
        jsr sub_B013
        jmp loc_BBC1
loc_BBBE
        jsr sub_AFF4
loc_BBC1
        jsr sub_DB26
        jsr sub_AF03
        lda $2BC7
        sta $5A
        ldy $2BC8
        dey
        sty $5B
        lda #$02
        ldy #$00
        jmp loc_B663

sub_BBD9
        jsr sub_BC03
loc_BBDC
        jsr sub_D91C
        lda $5A
        cmp #$28
        beq loc_BBF0
        jsr sub_A539
        beq loc_BBF0
        jsr sub_BC76
        bne loc_BBDC
        rts
loc_BBF0
        lda #$67
        jmp jt_dos_error

sub_BBF5
        ldx #$01
        jsr sub_C156
        lda $56
        sec
        sbc $2BEF
        cmp #$04
        rts

sub_BC03
        ldy $2BEF
        iny
        lda $0200,y
        sta $5A
        iny
        lda $0200,y
        sta $5B
        iny
        lda $0200,y
        sta $2BA6
        iny
        lda $0200,y
        sta $2BA5
        clc
        lda $2BA6
        adc $2BA5
        beq loc_BC2C
        jmp sub_D91C
loc_BC2C
        lda #$77
        jsr sub_B66F
loc_BC31
        jsr sub_BBD9
        lda #$05
        sta $2BED
        lda #$12
        sta $82
        jsr sub_BC03
        jsr sub_CBC0
        jsr sub_C3BD
        jsr sub_BC03
loc_BC49
        jsr sub_D91C
        lda $5A
        jsr sub_A35C
        jsr sub_BC76
        bne loc_BC49
        jsr sub_BC03
        ldx $80
        lda $2BA6
        sta $2D48,x
        lda $2BA5
        sta $2D68,x
        lda #$00
        jsr sub_CEEA
        lda #$12
        sta $82
        jsr sub_CD1C
        jmp loc_B654

sub_BC76
        lda $2BA6
        bne loc_BC83
        lda $2BA5
        beq loc_BC9E
        dec $2BA5
loc_BC83
        dec $2BA6
        inc $5B
        lda $2BC9
        cmp $5B
        bne loc_BC9E
        lda #$00
        sta $5B
        lda $5A
        cmp $2BA7
        beq loc_BCA6
        inc $5A
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
loc_BC9E
        clc
        lda $2BA5
        ora $2BA6
        rts
loc_BCA6
        lda #$67
        jmp jt_dos_error

sub_BCAB
        ldy #$01
        lda ($94),y
        sta $5A
        iny
        lda ($94),y
        sta $5B
        ldy #$1C
        lda ($94),y
        sta $2BA6
        iny
        lda ($94),y
        sta $2BA5
        rts

sub_BCC4
        jsr sub_D91C
        jsr sub_A35C
        jsr sub_BC76
        bne sub_BCC4
        rts

sub_BCD0
        lda $0201
        cmp #$44
        beq loc_BCDA
loc_BCD7
        jmp loc_B09C
loc_BCDA
        jsr sub_BDF5
        bne loc_BCD7
        jsr sub_BE84
        jsr sub_A481
        lda $5A
        sta $2C20
        lda $5B
        sta $2C28
loc_BCEF
        lda $5A
        sta $2BCA
        lda $5B
        sta $2BCB
        jsr sub_A4FF
        lda $5B
        pha
        lda $5A
        pha
        cmp $2BCA
        bne loc_BD0F
        ldx $2BCB
        inx
        cpx $5B
        beq loc_BD35
loc_BD0F
        lda $2BCA
        sta $5A
        lda $2BCB
        sta $5B
        jsr sub_A391
        pla
        tax
        sta $5A
        pla
        sta $5B
        cpx $2C20
        bne loc_BCEF
        cmp $2C28
        bne loc_BCEF
        jsr sub_A391
        lda #$65
        jmp sub_B66F
loc_BD35
        pla
        pla
        lda #$00
        sta $2C20
        jsr sub_BA20
        lda $2BA8
        pha
        lda $2BA7
        pha
        jsr sub_BED9
        lda $2C20
        beq loc_BD54
        lda #$63
        jmp sub_B66F
loc_BD54
        lda #$06
        sta $2BED
        lda $2BCA
        sta $5A
        lda $2BCB
        sta $5B
        jsr sub_C3BD
        ldx $80
        lda #$02
        sta $2D48,x
        lda #$00
        sta $2D68,x
        jsr sub_CDF1
        jsr sub_A348
        ldx $2BCB
        stx $2BA8
        inx
        stx $2BA9
        lda $2BCA
        sta $2BA7
        jsr sub_A74B
        pla
        sta $2222
        pla
        sta $2223
        lda $2C30
        sta $2224
        lda $2C38
        sta $2225
        lda $2C40
        sta $2226
        jsr sub_A181
        jsr sub_A7D8
        jmp sub_A199

sub_BDAE
        lda $0201
        cmp #$44
        beq loc_BDB8
loc_BDB5
        jmp loc_B12D
loc_BDB8
        jsr sub_BDF5
        bne loc_BDB5
        lda $2C08
        pha
        ldx $2C00
        dex
        stx $2C08
        lda #$2F
        sta $0200,x
        lda #$00
        jsr sub_BA20
        pla
        sta $2C08
        lda #$00
        sta $2BBC
        jsr sub_C07C
        beq loc_BDE9
        ldy #$00
        sty $5A
        lda #$01
        jmp loc_B661
loc_BDE9
        ldx $2C00
        dex
        lda #$3A
        sta $0200,x
        jmp loc_B269

sub_BDF5
        lda #$03
        sta $2BE2
        jsr sub_B6E7
        jsr sub_B833
        jmp sub_B085

sub_BE03
        ldx #$01
loc_BE05
        lda $0200,x
        cmp txt_BE1A-1,x
        bne loc_BE1D
        inx
        cpx #$04
        bcc loc_BE05
        ldx #$01
        jsr sub_F7A7
        jmp loc_B65C
txt_BE1A
        !text "EOS"                     ; $BE1A
loc_BE1D
        lda $0201
        cmp #$2D
        bne loc_BE2B
        lda $0202
        cmp #$50
        beq loc_BE2E
loc_BE2B
        jmp loc_DF97
loc_BE2E
        lda $56
        cmp #$04
        bcc loc_BE3B
        lda $0203
        cmp #$FF
        bne loc_BE3E
loc_BE3B
        lda $90E8
loc_BE3E
        pha
        lsr
        lsr
        lsr
        jsr sub_F64A
        bcc loc_BE4C
        lda #$78
        jmp jt_job_error
loc_BE4C
        pla
        pha
        and #$07
        asl
        asl
        asl
        asl
        asl
        clc
        adc #$02
        sta $68
        ldy #$00
        lda ($68),y
        sta $2DE7
loc_BE61
        lda ($68),y
        sta $2300,y
        iny
        cpy #$1E
        bcc loc_BE61
        pla
        ldy #$02
        sta $2300,y
        lda #$1D
        clc
        adc #$00
        sta $2E07
        jsr sub_F5ED
        inc $DE
        lda #$88
        sta $2DC7
        rts

sub_BE84
        lda #$00
        sta $50
        jsr sub_AED0
        beq loc_BE92
        lda #$74
        jmp sub_B66F
loc_BE92
        jmp sub_EE3C

sub_BE95
        ldx $2BEB
        dex
loc_BE99
        stx $2BBD
        lda $2C10,x
        beq loc_BEB0
        jsr sub_BEB4
        jsr sub_B023
        lda $2BBD
        jsr sub_BED1
        jsr sub_BEB4
loc_BEB0
        dex
        bpl loc_BE99
        rts

sub_BEB4
        ldx $2BBD
        lda $2C10,x
        pha
        ldy $2BEB
        dey
loc_BEBF
        pla
        pha
        eor $2C10,y
        sta $2C10,y
        dey
        bpl loc_BEBF
        pla
        sta $2C10,x
        rts

sub_BECF
        lda #$00

sub_BED1
        pha
        jsr sub_BE84
        pla
        jsr sub_BA20

sub_BED9
        jsr sub_BE84
        lda #$00
        sta $2BBC
        jsr sub_C07C
        bne loc_BEEC
loc_BEE6
        rts
loc_BEE7
        jsr sub_C0F3
        beq loc_BEFC
loc_BEEC
        jsr sub_BF7C
        lda $2BBE
        beq loc_BEF5
        rts
loc_BEF5
        lda $2BBF
        bmi loc_BEE7
        bpl loc_BEEC
loc_BEFC
        lda $2BBE
        beq loc_BEE6
        rts

sub_BF02
        jsr sub_C0E0
        beq loc_BF22
        bne loc_BF2A

sub_BF09
        lda #$00

sub_BF0B
        pha
        lda #$00
        sta $2BBC
        pla
        jsr sub_BA20

sub_BF15
        lda #$00
        sta $2BBC
        jsr sub_C07C
        bne loc_BF2A
        sta $2BBE
loc_BF22
        lda #$FF
        rts

sub_BF25
        jsr sub_C0F3
        beq loc_BF22
loc_BF2A
        jsr sub_BF7C
        ldx $2BBF
        bpl loc_BF39
        lda $2BBE
        beq sub_BF25
        bne loc_BF7B
loc_BF39
        bit $2BB4
        bpl loc_BF51
        ldx #$00
        ldy #$17
loc_BF42
        lda ($94),y
        cmp $2B08,x
        bcc loc_BF51
        bne sub_BF25
        inx
        iny
        cpy #$1C
        bcc loc_BF42
loc_BF51
        bit $2BB5
        bpl loc_BF69
        ldx #$00
        ldy #$17
loc_BF5A
        lda ($94),y
        cmp $2B0D,x
        bcc sub_BF25
        bne loc_BF69
        inx
        iny
        cpy #$1C
        bcc loc_BF5A
loc_BF69
        ldx $2BBF
        lda $2BEE
        beq loc_BF7B
        lda $2C18,x
        and #$07
        cmp $2BEE
        bne sub_BF25
loc_BF7B
        rts

sub_BF7C
        ldx #$FF
        stx $2BBF
        inx
        stx $2BE4
        jsr sub_C02E
        beq loc_BF90
loc_BF8A
        rts
loc_BF8B
        jsr sub_C039
        bne loc_BF8A
loc_BF90
        lda $2C10,x
        cmp $90E8
        bne loc_BF8B
        lda $2C00,x
        tax
        jsr sub_C156
        ldy #$03
        bne loc_BFB6
loc_BFA3
        lda $0200,x
        cmp ($94),y
        beq loc_BFB4
        cmp #$3F
        bne loc_BF8B
        lda ($94),y
        cmp #$A0
        beq loc_BF8B
loc_BFB4
        inx
        iny
loc_BFB6
        cpx $2BEF
        bcs loc_BFC5
        lda $0200,x
        cmp #$2A
        bne loc_BFA3
        jmp loc_C052
loc_BFC5
        cpy #$13
        bcs loc_BFCF
        lda ($94),y
        cmp #$A0
        bne loc_BF8B
loc_BFCF
        ldx $2BEC
        stx $2BBF
        lda $2C18,x
        and #$80
        sta $2BE4
        lda $2BB8
        sta $2C40,x
        lda $5A
        sta $2C30,x
        lda $5B
        sta $2C38,x
        ldy #$00
        lda ($94),y
        iny
        pha
        and #$40
        sta $50
        pla
        and #$DF
        bmi loc_BFFE
        ora #$20
loc_BFFE
        and #$27
        ora $50
        sta $50
        lda #$80
        and $2C18,x
        ora $50
        sta $2C18,x
        lda ($94),y
        bne loc_C019
        cmp $90E8
        bne loc_C019
        lda #$01
loc_C019
        sta $2C20,x
        iny
        lda ($94),y
        sta $2C28,x
        lda $2BF3
        bne sub_C02E
        ldy #$15
        lda ($94),y
        sta $2BF3

sub_C02E
        lda #$FF
        sta $2BBE
        lda $2BEB
        sta $2BEC

sub_C039
        dec $2BEC
        bpl loc_C03F
        rts
loc_C03F
        ldx $2BEC
        lda $2C18,x
        bmi loc_C04C
        lda $2C20,x
        bne sub_C039
loc_C04C
        lda #$00
        sta $2BBE
        rts
loc_C052
        stx $5C
        ldx $2BEF
        dex
        cpx $5C
        beq loc_C076
        ldy #$13
loc_C05E
        dey
        lda ($94),y
        cmp #$A0
        beq loc_C05E
loc_C065
        lda $0200,x
        cmp ($94),y
        beq loc_C070
        cmp #$3F
        bne loc_C079
loc_C070
        dey
        dex
        cpx $5C
        bne loc_C065
loc_C076
        jmp loc_BFCF
loc_C079
        jmp loc_BF8B

sub_C07C
        ldy #$00
        sty $2BBA
        dey
        sty $2BBF
        sty $2BC0
        lda $2BA7
        sta $5A
        lda $2BA9
        sta $5B
        jsr sub_C378
loc_C095
        lda $2BC0
        bne loc_C09B
        rts
loc_C09B
        lda #$07
        sta $2BC1
        lda #$00
        jsr sub_DCE2
        sta $2BC0
loc_C0A8
        jsr sub_DCD4
        dec $2BC1
        ldy #$00
        lda ($94),y
        bne loc_C0D7
        lda $2BBA
        bne sub_C0F3
        jsr sub_D986
        lda $90E8
        sta $2BB9
        lda $5A
        sta $2BBA
        lda $5B
        sta $2BBB
        lda $94
        ldx $2BBC
        sta $2BBC
        beq sub_C0F3
        rts
loc_C0D7
        ldx #$01
        cpx $2BBC
        bne loc_C10B
        beq sub_C0F3

sub_C0E0
        lda $2BB6
        sta $5A
        lda $2BB7
        sta $5B
        jsr sub_C378
        lda $2BB8
        jsr sub_DCC6

sub_C0F3
        lda #$FF
        sta $2BBF
        lda $2BC1
        bmi loc_C105
        lda #$20
        jsr sub_DC5B
        jmp loc_C0A8
loc_C105
        jsr sub_9F5E
        jmp loc_C095
loc_C10B
        lda $94
        sta $2BB8
        jsr sub_D986
        lda $5B
        sta $2BB7
        lda $5A
        sta $2BB6
        rts

sub_C11E
        pha
        jsr sub_C156
        jsr sub_C138
        pla
        sec
        sbc $2BC2
        tax
        beq loc_C137
        bcc loc_C137
        lda #$A0
loc_C131
        sta ($94),y
        iny
        dex
        bne loc_C131
loc_C137
        rts

sub_C138
        tya
        asl
        tay
        lda $00A0,y
        sta $94
        lda $00A1,y
        sta $95
        ldy #$00
loc_C147
        lda $0200,x
        sta ($94),y
        iny
        beq loc_C155
        inx
        cpx $2BEF
        bcc loc_C147
loc_C155
        rts

sub_C156
        lda #$00
        sta $2BC2
        txa
        pha
loc_C15D
        lda $0200,x
        cmp #$2C
        beq loc_C177
        cmp #$3D
        beq loc_C177
        inc $2BC2
        inx
        lda #$0F
        cmp $2BC2
        bcc loc_C177
        cpx $56
        bcc loc_C15D
loc_C177
        stx $2BEF
        pla
        tax
        rts

sub_C17D
        lda $82
        pha
        lda $80
        pha
        jsr sub_C18D
        pla
        sta $80
        pla
        sta $82
        rts

sub_C18D
        lda #$11
        sta $82
        jsr sub_DA60
        jsr sub_DCD4
        lda $2BBF
        bpl loc_C1A1
        jsr sub_C350
        clc
        rts
loc_C1A1
        ldx #$18
        ldy #$1D
        bit $2BB3
        bpl loc_C1AE
        lda #$00
        beq loc_C1B0
loc_C1AE
        lda ($94),y
loc_C1B0
        sta $2BC4
        beq loc_C1B7
        ldx #$16
loc_C1B7
        dey
        bit $2BB3
        bpl loc_C1D1
        lda $94
        lsr
        lsr
        lsr
        lsr
        lsr
        sta $2BC3
        lda $5B
        asl
        asl
        asl
        clc
        adc $2BC3
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C1D1
        lda ($94),y
        sta $2BC3
        cpx #$16
        beq loc_C1E4
        cmp #$0A
        bcc loc_C1E4
        dex
        cmp #$64
        bcc loc_C1E4
        dex
loc_C1E4
        jsr sub_C2BF
        lda ($94),y
        bit $2BB3
        bmi loc_C1FB
        pha
        asl
        bpl loc_C1F7
        lda #$3C
        sta $2FE1,x
loc_C1F7
        pla
        jmp loc_C206
loc_C1FB
        cmp #$FF
        bne loc_C201
        lda #$00
loc_C201
        clc
        adc #$07
        sec
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C206
        and #$0F
        tay
        lda txt_C2B0,y
        sta $2FE0,x
        dex
        lda txt_C2A1,y
        sta $2FE0,x
        dex
        lda txt_C292,y
        sta $2FE0,x
        dex
        dex
        bcs loc_C226
        lda #$2A
        sta $2FE1,x
loc_C226
        lda #$A0
        sta $2FE0,x
        dex
        ldy #$12
loc_C22E
        lda ($94),y
        sta $2FE0,x
        dex
        dey
        cpy #$03
        bcs loc_C22E
        lda #$22
        sta $2FE0,x
loc_C23E
        inx
        cpx #$20
        bcs loc_C24E
        lda $2FE0,x
        cmp #$22
        beq loc_C24E
        cmp #$A0
        bne loc_C23E
loc_C24E
        lda #$22
        sta $2FE0,x
loc_C253
        inx
        cpx #$20
        bcs loc_C262
        lda #$7F
        and $2FE0,x
        sta $2FE0,x
        bpl loc_C253
loc_C262
        ldx #$04
        ldy #$1B
loc_C266
        lda ($94),y
        sta $2BAA,x
        dey
        dex
        bpl loc_C266
        lda $2BAD
        cmp #$0C
        bcc loc_C27E
        sbc #$0C
        sta $2BAD
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C27E
        lda #$00
        sta $2BAF
        lda $2BAD
        bne loc_C28D
        lda #$0C
        sta $2BAD
loc_C28D
        jsr sub_BF25
        sec
        rts
txt_C292
        !text "DSPURCD"                 ; $C292
txt_C299
        !text "SN478CPF"                ; $C299
txt_C2A1
        !text "EERSEBIYA1118RO"         ; $C2A1
txt_C2B0
        !text "LQGRLMRST   1NR"         ; $C2B0

sub_C2BF
        ldy #$1B
        lda #$20
loc_C2C3
        sta $2FDF,y
        dey
        bne loc_C2C3
        rts
dat_C2CA
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $C2CA
        !byte $20,$20,$20,$20,$20,$20,$20,$20 ; $C2D2
        !byte $A0,$A0,$48,$44,$A0,$31,$48 ; $C2DA

sub_C2E1
        bit $2BB3
        bpl loc_C2F3
        ldx #$17
loc_C2E8
        lda dat_C2CA,x
        sta $2204,x
        dex
        bpl loc_C2E8
        bmi loc_C2F9
loc_C2F3
        jsr sub_AED0
        jsr sub_A17E
loc_C2F9
        jsr sub_C2BF
        lda #$FF
        sta $50
        lda #$00
        sta $2BC3
        sta $2BC4
        lda #$22
        sta $95
        ldy $90E8
        cpy #$FF
        beq loc_C31E
        lda part_type,y
        cmp #$01
        beq loc_C31E
        cmp #$04
        bcc loc_C321
loc_C31E
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C321
        lda #$90
        sta $94
        ldy #$00
loc_C327
        lda ($94),y
        cmp #$A0
        bne loc_C32F
        lda #$20
loc_C32F
        sta $2FE2,y
        iny
        cpy #$17
        bcc loc_C327
        ldy #$FF
        lda #$04
        sta $94
        lda #$12
        sta $2FE0
        lda #$22
        sta $2FE1
        sta $2FF2
        lda #$20
        sta $2FF3
        rts

sub_C350
        jsr sub_C2BF
        ldy #$0B
loc_C355
        lda txt_C361,y
        sta $2FE0,y
        dey
        bpl loc_C355
        jmp sub_C67C
txt_C361
        !text "BLOCKS FREE."            ; $C361

sub_C36D
        ldy #$00
        tya
        sta ($94),y
        jsr sub_D9A7
        jmp sub_D965

sub_C378
        lda #$01

sub_C37A
        sta $2BED
        lda #$11
        sta $82
        jsr sub_CAF7
        lda #$02
        jmp sub_DCC6

sub_C389
        lda #$12
        sta $82
        jmp sub_CBBD

sub_C390
        jsr sub_D986
        jsr sub_A464
        lda #$00
        jsr sub_DCC6
        lda $5A
        jsr sub_CEEA
        lda $5B
        jsr sub_CEEA
        jsr sub_D885
        jsr sub_D965
        lda #$00
        jsr sub_DCC6
loc_C3B0
        jsr sub_CEEA
        bne loc_C3B0
        jsr sub_CEEA
        lda #$FF
        jmp sub_CEEA

sub_C3BD
        lda $82
        pha
        lda $80
        pha
        lda $5B
        pha
        lda $5A
        pha
        lda #$00
        sta $2C30
        lda #$11
        sta $82
        jsr sub_D986
        lda $2BED
        pha
        lda $2C10
        cmp $2BB9
        beq loc_C3ED
        ldx #$01
        stx $2BBC
        jsr sub_C07C
        beq loc_C417
        bne loc_C42D
loc_C3ED
        lda $2BBA
        beq loc_C40D
        cmp $5A
        bne loc_C3FD
        lda $5B
        cmp $2BBB
        beq loc_C42D
loc_C3FD
        lda $2BBA
        sta $5A
        lda $2BBB
        sta $5B
        jsr sub_D8AA
        jmp loc_C42D
loc_C40D
        lda #$01
        sta $2BBC
        jsr sub_C0F3
        bne loc_C42D
loc_C417
        jsr sub_C390
        sec
        ror $2C30
        lda $5B
        sta $2BBB
        lda $5A
        sta $2BBA
        lda #$02
        sta $2BBC
loc_C42D
        lda $2BBC
        jsr sub_DCC6
        pla
        sta $2BED
        cmp #$04
        bne loc_C43D
        ora #$80
loc_C43D
        jsr sub_CEEA
        pla
        sta $2C20
        jsr sub_CEEA
        pla
        sta $2C28
        jsr sub_CEEA
        jsr sub_DCF2
        tay
        lda $2C00
        tax
        lda #$10
        jsr sub_C11E
        ldy #$10
        lda #$00
loc_C45F
        sta ($94),y
        iny
        cpy #$1B
        bcc loc_C45F
        lda $2BED
        cmp #$04
        bne loc_C480
        ldy #$10
        lda $2BF4
        sta ($94),y
        iny
        lda $2BF5
        sta ($94),y
        iny
        lda $2BF3
        sta ($94),y
loc_C480
        jsr sub_D8AD
        bit $2C30
        bpl loc_C4BE
        jsr sub_B085
        bne loc_C4BE
        lda $2BA7
        cmp #$01
        bne loc_C499
        cmp $2BA8
        beq loc_C4BE
loc_C499
        jsr sub_A1B2
        lda $2200,x
        cmp #$86
        bne loc_C4BE
        lda $2201,x
        cmp $2BA7
        bne loc_C4BE
        lda $2202,x
        cmp $2BA8
        bne loc_C4BE
        inc $221C,x
        bne loc_C4BB
        inc $221D,x
loc_C4BB
        jsr sub_A1CF
loc_C4BE
        pla
        sta $80
        tax
        pla
        sta $82
        lda $2BBA
        sta $2C30
        sta $2CE8,x
        lda $2BBB
        sta $2C38
        sta $2D08,x
        lda $2BBC
        sta $2C40
        sta $2D28,x
        lda $2BED
        sta $2C18
        rts

sub_C4E7
        lda #$00
        sta $82
        lda #$01
        jsr sub_DAC2
        lda #$00
        jsr sub_DCC6
        ldx $80
        lda #$00
        sta $2DE8,x
        jsr sub_DCF2
        tax
        lda #$00
        sta $2960,x
        lda #$01
        jsr sub_CEEA
        lda #$04
        jsr sub_CEEA
        lda #$01
        jsr sub_CEEA
        jsr sub_CEEA
        lda $90E8
        bne loc_C51E
        lda #$FF
loc_C51E
        jsr sub_CEEA
        lda #$00
        jsr sub_CEEA
        jsr sub_C5AD
        dec $A0,x
        dec $A0,x
        lda #$01
        sta $2BB1
        lda #$00
        jsr sub_CEEA

sub_C537
        lda #$01
        jsr sub_CEEA
        jsr sub_CEEA
        jsr sub_C17D
        bcc loc_C573
        lda $2BC3
        jsr sub_CEEA
        lda $2BC4
        jsr sub_CEEA
        jsr sub_C5AD
        bit $2BB3
        bvc loc_C55B
        jsr sub_C5BB
loc_C55B
        lda #$00
        jsr sub_CEEA
        bne sub_C537
loc_C562
        lda #$00
        sta $A0,x
        lda #$88
        ldy $80
        sta $2BC5
        sta $2DA8,y
        lda $84
        rts
loc_C573
        bit $2BB3
        bpl loc_C582
        jsr sub_CEEA
        dec $A0,x
        dec $A0,x
        jmp loc_C591
loc_C582
        lda $2BC3
        jsr sub_CEEA
        lda $2BC4
        jsr sub_CEEA
        jsr sub_C5AD
loc_C591
        dec $A0,x
        dec $A0,x
        lda #$00
        jsr sub_CEEA
        jsr sub_CEEA
        jsr sub_CEEA
        lda $A0,x
        sec
        sbc #$01
        ldy $80
        sta $2DE8,y
        jmp loc_C562

sub_C5AD
        ldy #$00
loc_C5AF
        lda $2FE0,y
        jsr sub_CEEA
        iny
        cpy #$1B
        bne loc_C5AF
        rts

sub_C5BB
        lda #$1F
        sta $2BB2
loc_C5C0
        dec $A0,x
        dec $2BB2
loc_C5C5
        lda ($A0,x)
        cmp #$20
        beq loc_C5C0
        bit $2BB0
        bmi loc_C5DB
        dec $A0,x
        dec $2BB2
        cmp #$3C
        beq loc_C5C5
        bne loc_C5E8
loc_C5DB
        jsr sub_C670
        cmp #$3C
        beq loc_C5E5
        jsr sub_C66E
loc_C5E5
        jsr sub_C66E
loc_C5E8
        jsr sub_C61C
loc_C5EB
        lda #$29
        bit $2BB0
        bpl loc_C5F4
        lda #$3F
loc_C5F4
        cmp $2BB2
        beq loc_C601
        lda #$01
        jsr sub_C670
        jmp loc_C5EB
loc_C601
        inc $2BB1
        lda #$06
        bit $2BB0
        bpl loc_C60D
        lda #$04
loc_C60D
        cmp $2BB1
        bne loc_C61B
loc_C612
        lda #$01
        jsr sub_CEEA
        bne loc_C612
        dec $A0,x
loc_C61B
        rts

sub_C61C
        ldy #$01
loc_C61E
        jsr sub_C658
        iny
        cpy #$03
        bne loc_C638
        bit $2BB0
        bpl loc_C638
        ldy #$00
        jsr sub_C658
        jsr sub_C66E
        jsr sub_C66E
        ldy #$03
loc_C638
        cpy #$05
        bcc loc_C61E
        lda #$20
        jsr sub_C670
        lda #$41
        bit $2BAF
        bpl loc_C64A
        lda #$50
loc_C64A
        jsr sub_C670
        bit $2BB0
        bpl loc_C657
        lda #$4D
        jsr sub_C670
loc_C657
        rts

sub_C658
        lda txt_C677,y
        jsr sub_C670
        lda $2BAA,y
        jsr sub_B47A
        pha
        lda $50
        jsr sub_C66B
        pla

sub_C66B
        ora #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_C66E
        lda #$20

sub_C670
        jsr sub_CEEA
        inc $2BB2
        rts
txt_C677
        !text "/ / ."                   ; $C677

sub_C67C
        txa
        pha
        tya
        pha
        jsr sub_A60B
        lda $2B50,x
        sta $2BC3
        lda $2B60,x
        sta $2BC4
        pla
        tay
        pla
        tax
        rts
loc_C694
        lda $82
        sta $4A
        jsr sub_B7AC
        stx $2BE2
        ldx $0200
        lda $4A
        bne loc_C6D3
        cpx #$2A
        bne loc_C6D3
        jsr sub_A2C7
        lda $2FC0,x
        beq loc_C70F
        sta $5A
        lda $2FD0,x
        sta $5B
        lda $90E8
        sta $2C10
        lda #$02
        sta $2C18
        jsr sub_EE3C
        jsr sub_CAF7
        lda #$04
loc_C6CB
        ldx $80
        sta $2D88,y
        jmp loc_B654
loc_C6D3
        cpx #$24
        bne loc_C708
        lda $4A
        bne loc_C6DE
        jmp loc_C967
loc_C6DE
        jsr sub_B6DE
        bne loc_C6E9
        jsr sub_B678
        jmp loc_C6F6
loc_C6E9
        dey
        dey
        sty $2C00
        jsr sub_B833
        lda #$00
        jsr sub_BA20
loc_C6F6
        lda $2BA7
        sta $5A
        lda $2BA8
        sta $5B
        jsr sub_CAF7
        lda #$02
        jmp loc_C6CB
loc_C708
        cpx #$23
        bne loc_C717
        jmp loc_AE6C
loc_C70F
        lda #$02
        sta $2BEE
        jsr sub_AF03
loc_C717
        jsr sub_B6DE
        bne loc_C720
        ldx #$00
        beq loc_C72C
loc_C720
        txa
        beq loc_C728
        lda #$30
        jmp sub_B66F
loc_C728
        dey
        beq loc_C72C
        dey
loc_C72C
        sty $2C00
        lda #$8D
        jsr sub_B761
        inx
        stx $2BEB
        jsr sub_B833
        jsr sub_BE84
        jsr sub_BF09
        ldx #$00
        stx $2BF3
        stx $2BF0
        stx $2BED
        inx
        cpx $2BEA
        bcs loc_C762
        jsr sub_C8FE
        inx
        cpx $2BEA
        bcs loc_C762
        cpy #$04
        beq loc_C798
        jsr sub_C8FE
loc_C762
        ldx $4A
        stx $82
        cpx #$02
        bcs loc_C777
        stx $2BF0
        lda $2BED
        bne loc_C78E
        lda #$02
        sta $2BED
loc_C777
        lda $2BED
        bne loc_C78E
        lda $2C18
        and #$07
        sta $2BED
        lda $2C20
        bne loc_C78E
        lda #$01
        sta $2BED
loc_C78E
        lda $2BF0
        cmp #$01
        beq loc_C7AD
        jmp loc_C832
loc_C798
        ldy $2C00,x
        lda $0200,y
        sta $2BF3
        lda $2C20
        bne loc_C762
        lda #$01
        sta $2BF0
        bne loc_C762
loc_C7AD
        lda $2C18
        and #$80
        tax
        bne loc_C7CA
        lda #$20
        bit $2C18
        beq loc_C7C2
        jsr sub_C36D
        jmp loc_C8DF
loc_C7C2
        lda $2C20
        bne loc_C7CA
        jmp loc_C8DF
loc_C7CA
        lda $0200
        cmp #$40
        beq loc_C7DE
        txa
        bne loc_C7D9
        lda #$63
        jmp sub_B66F
loc_C7D9
        lda #$33
        jmp sub_B66F
loc_C7DE
        lda $2C18
        and #$07
        cmp $2BED
        bne loc_C859
        cmp #$04
        beq loc_C859
        jsr sub_CBBD
        lda $80
        sta $2BE0
        lda #$11
        sta $82
        jsr sub_DA60
        lda $2BB8
        jsr sub_DCC6
        ldy #$00
        lda ($94),y
        ora #$20
        sta ($94),y
        ldy #$1A
        lda $5A
        sta ($94),y
        iny
        lda $5B
        sta ($94),y
        ldx $2BE0
        lda $2C30
        sta $2CE8,x
        lda $2C38
        sta $2D08,x
        lda $2C40
        sta $2D28,x
        jsr sub_D986
        jsr sub_D8AD
        jmp loc_C8E5
loc_C832
        lda $2C20
        bne loc_C83C
        lda #$62
        jmp sub_B66F
loc_C83C
        lda $2BF0
        cmp #$03
        beq loc_C84F
        lda #$20
        bit $2C18
        beq loc_C84F
        lda #$60
        jmp sub_B66F
loc_C84F
        lda $2C18
        and #$07
        cmp $2BED
        beq loc_C85E
loc_C859
        lda #$64
        jmp sub_B66F
loc_C85E
        ldy #$00
        sty $2BEC
        ldx $2BF0
        cpx #$02
        bne loc_C884
        cmp #$04
        beq loc_C859
        lda ($94),y
        and #$4F
        sta ($94),y
        lda $82
        pha
        lda #$11
        sta $82
        jsr sub_D986
        jsr sub_D8AD
        pla
        sta $82
loc_C884
        jsr sub_C894
        lda $2BF0
        cmp #$02
        bne loc_C8E5
        jsr sub_C929
        jmp loc_B654

sub_C894
        ldy #$13
        lda ($94),y
        sta $2BF4
        iny
        lda ($94),y
        sta $2BF5
        iny
        lda ($94),y
        ldx $2BF3
        sta $2BF3
        txa
        beq loc_C8B7
        cmp $2BF3
        beq loc_C8B7
        lda #$50
        jsr sub_B66F
loc_C8B7
        ldx $2BEC
        lda $2C20,x
        sta $5A
        lda $2C28,x
        sta $5B
        jsr sub_CAF7
        ldy $80
        ldx $2BEC
        lda $2C30,x
        sta $2CE8,y
        lda $2C38,x
        sta $2D08,y
        lda $2C40,x
        sta $2D28,y
        rts
loc_C8DF
        jsr sub_CBBD
        jsr sub_C3BD
loc_C8E5
        lda $82
        cmp #$02
        bcs loc_C8FB
        jsr sub_D989
        jsr sub_A2C7
        lda $5A
        sta $2FC0,x
        lda $5B
        sta $2FD0,x
loc_C8FB
        jmp loc_B654

sub_C8FE
        ldy $2C00,x
        lda $0200,y
        ldy #$04
loc_C906
        dey
        bmi loc_C911
        cmp txt_C91F,y
        bne loc_C906
        sty $2BF0
loc_C911
        ldy #$06
loc_C913
        dey
        bmi loc_C91E
        cmp txt_C923,y
        bne loc_C913
        sty $2BED
loc_C91E
        rts
txt_C91F
        !text "RWAM"                    ; $C91F
txt_C923
        !text "DSPULC"                  ; $C923

sub_C929
        jsr sub_D9DB
        lda $5A
        beq loc_C936
        jsr sub_9F5E
        jmp sub_C929
loc_C936
        ldx $80
        lda $2D48,x
        bne loc_C940
        dec $2D68,x
loc_C940
        dec $2D48,x
        ldx $5B
        inx
        txa
        bne loc_C953
        lda #$00
        jsr sub_DCC6
        jsr sub_A0DD
        lda #$02
loc_C953
        jsr sub_DCC6
        ldx $80
        lda #$01
        sta $2DA8,x
        lda #$80
        ora $80
        ldx $82
        sta $2C48,x
        rts
loc_C967
        lda #$0C
        sta $2BE2
        ldy #$01
        sty $2BB3
        ldx $56
        dex
        beq loc_C9A9
        jsr sub_B6B8
        beq loc_C9D0
        ldy #$01
        lda $0201
        cmp #$3D
        bne loc_C998
        lda $0202
        cmp #$54
        beq loc_C98F
        cmp #$50
        bne loc_C998
loc_C98F
        ldy #$03
        sty $2BB3
        cpy $56
        beq loc_C9A9
loc_C998
        dey
loc_C999
        iny
        jsr sub_B6CF
        beq loc_C999
        cpy $56
        bne loc_C9D0
        ldy $2BB3
        jsr sub_B690
loc_C9A9
        lda $90E8
        sta $2C10
        inc $2BEA
        inc $2BEB
        ldy $2BB3
        lda #$2A
        sta $0200,y
        sty $2C00
        sty $2C08
        iny
        sty $56
        sty $2C01
        lda #$80
        sta $2C18
        bmi loc_C9E8
loc_C9D0
        jsr sub_B6DE
        bne loc_C9DD
        jsr sub_B7F6
        ldy $2BB3
        iny
        iny
loc_C9DD
        dey
        dey
        sty $2C00
        jsr sub_B6F9
        jsr sub_B83D
loc_C9E8
        lda $0201
        cmp #$3D
        bne loc_CA3E
        lda $0202
        cmp #$50
        beq loc_CA3B
        cmp #$54
        bne loc_CA3E
        lda #$40
        sta $2BB3
        lsr $2BB0
        ldy $2BEA
loc_CA05
        cpy $2BEB
        bcs loc_CA43
        ldx $2C00,y
        lda $0200,x
        cmp #$3C
        bne loc_CA1B
        ror $2BB4
        clc
        jsr sub_CA8A
loc_CA1B
        cmp #$3E
        bne loc_CA26
        ror $2BB5
        sec
        jsr sub_CA8A
loc_CA26
        cmp #$4C
        bne loc_CA2D
        ror $2BB0
loc_CA2D
        cmp #$4E
        bne loc_CA36
        lda #$00
        sta $2BB3
loc_CA36
        iny
        bne loc_CA05
        beq loc_CA43
loc_CA3B
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_CA3E
        lda #$00
        sta $2BB3
loc_CA43
        bit $2BB3
        bpl loc_CA57
        lda #$00
        tay
loc_CA4B
        sta $2C10,y
        iny
        cpy $2BEA
        bcc loc_CA4B
        jsr sub_B023
loc_CA57
        lda #$00
        sta $2BEE
        ldy $2BEA
        cpy $2BEB
        beq loc_CA67
        jsr sub_B908
loc_CA67
        jsr sub_BE84
        lda #$00
        jsr sub_BA20
        jsr sub_C2E1
        jsr sub_BF15
        jsr sub_C4E7
        jsr sub_CEFE
        ldx $80
        sta $2DC8,x
        lda #$04
        sta $2D88,x
        lda #$00
        sta $DC
        rts

sub_CA8A
        pha
        tya
        pha
        lda #$04
        bcc loc_CA93
        lda #$09
loc_CA93
        pha
        ldy #$00
        stx $51
loc_CA98
        ldx $51
        txa
        clc
        adc dat_CAF2,y
        tax
        jsr sub_CADB
        sta $2BAA,y
        iny
        cpy #$05
        bcc loc_CA98
        lda $2BAD
        sbc #$0C
        bne loc_CAB5
        sta $2BAD
loc_CAB5
        inx
        inx
        lda $0200,x
        and #$7F
        cmp #$41
        beq loc_CAC9
        lda $2BAD
        clc
        adc #$0C
        sta $2BAD
loc_CAC9
        pla
        tay
        ldx #$04
loc_CACD
        lda $2BAA,x
        sta $2B08,y
        dey
        dex
        bpl loc_CACD
        pla
        tay
        pla
        rts

sub_CADB
        lda $0200,x
        and #$0F
        asl
        sta $50
        asl
        asl
        adc $50
        sta $50
        inx
        lda $0200,x
        and #$0F
        adc $50
        rts
dat_CAF2
        !byte $07,$01,$04,$0A,$0D       ; $CAF2

sub_CAF7
        lda #$01
        jsr sub_DAC2
        jsr sub_CB92
        lda $2BED
        pha
        asl
        sta $2D88,x
        jsr sub_D85A
        ldx $80
        lda $5A
        bne loc_CB15
        lda $5B
        sta $2DE8,x
loc_CB15
        pla
        cmp #$04
        bne loc_CB84
        ldy $82
        lda $2C48,y
        ora #$40
        sta $2C48,y
        lda $2BF3
        sta $2E08,x
        jsr sub_DC76
        bpl loc_CB32
        jmp loc_DAEC
loc_CB32
        ldx $80
        sta $2CA8,x
        ldy $2BF4
        sty $5A
        ldy $2BF5
        sty $5B
        jsr sub_D976
        jsr sub_D9B9
        jsr sub_D965
        lda #$02
        jsr sub_D098
        ldx $80
        ldy #$00
        lda ($94),y
        sec
        sbc #$FE
        beq loc_CB5C
        lda #$20
loc_CB5C
        sta $2EA8,x
        bne loc_CB72
        lda $2BF4
        sta $2E88,x
        lda $2BF5
        sta $2E68,x
        lda #$FF
        sta $2E48,x
loc_CB72
        ldx $80
        lda #$02
        sta $2E28,x
        lda #$00
        jsr sub_DCC6
        jsr sub_D32B
        jmp sub_D989
loc_CB84
        jsr sub_A008
        ldx $80
        sta $2DC8,x
        lda #$88
        sta $2DA8,x
        rts

sub_CB92
        ldx $80
        lda $2C68,x
        asl
        bmi loc_CBA0
        tay
        lda #$02
        sta $00A0,y
loc_CBA0
        lda $2C88,x
        ora #$80
        sta $2C88,x
        asl
        bmi loc_CBB1
        tay
        lda #$02
        sta $00A0,y
loc_CBB1
        lda #$00
        sta $2DE8,x
        sta $2D48,x
        sta $2D68,x
        rts

sub_CBBD
        jsr sub_A481

sub_CBC0
        lda #$01
        jsr sub_DABF
        jsr sub_D973
        jsr sub_CB92
        ldx $80
        lda $2BED
        pha
        asl
        sta $2D88,x
        pla
        cmp #$04
        beq loc_CBE0
        lda #$01
        sta $2DA8,x
        rts
loc_CBE0
        ldy $82
        lda $2C48,y
        and #$3F
        ora #$40
        sta $2C48,y
        lda $2BF3
        sta $2E08,x
        jsr sub_DC76
        bpl loc_CBFA
        jmp loc_DAEC
loc_CBFA
        pha
        jsr sub_B07E
        cmp #$01
        beq loc_CC06
        cmp #$04
        bcc loc_CC09
loc_CC06
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_CC09
        lda #$20
        ldx $80
        sta $2EA8,x
        pla
        sta $2CA8,x
        jsr sub_D07D
        jsr sub_A3F3
        lda $5A
        sta $2BF4
        lda $5B
        sta $2BF5
        ldx $80
        lda $2CA8,x
        jsr sub_D976
        lda #$00
        jsr sub_D0A6
        lda #$00
        jsr sub_CCDA
        lda #$11
        jsr sub_CCDA
        lda #$00
        jsr sub_CCDA
        lda $2BF3
        jsr sub_CCDA
        lda $5A
        jsr sub_CCDA
        lda $5B
        jsr sub_CCDA
        lda #$10
        jsr sub_D0A6
        jsr sub_D989
        lda $5A
        jsr sub_CCDA
        lda $5B
        jsr sub_CCDA
        jsr sub_D9B3
        jsr sub_D965
        jsr sub_D7BE
        bne loc_CC70
        jsr sub_CC92
loc_CC70
        lda #$02
        jsr sub_DCC6
        ldx $80
        sec
        lda #$00
        sbc $2E08,x
        sta $2E28,x
        jsr sub_D4E2
        jsr sub_D03C
        jsr sub_D9A7
        jsr sub_D965
        jsr sub_A348
        jmp loc_CB72

sub_CC92
        ldx $80
        lda $2CA8,x
        jsr sub_D07D
        jsr sub_D0A6
        lda $2BF4
        jsr sub_CCDA
        lda $2BF5
        jsr sub_CCDA
        lda #$FE
        jsr sub_CCDA
        lda $2BF4
        jsr sub_CCDA
        lda $2BF5
        jsr sub_CCDA
        jsr sub_A3F3
        ldx $80
        lda $5A
        sta $2E88,x
        sta $2BF4
        lda $5B
        sta $2E68,x
        sta $2BF5
        lda #$FF
        sta $2E48,x
        jsr sub_D7D9
        jmp sub_D989

sub_CCDA
        pha
        ldx $80
        lda $2CA8,x
        jmp loc_CEF6

sub_CCE3
        lda $82
        bne loc_CCF2
        lda #$00
        sta $2BC5
        jsr sub_DB04
loc_CCEF
        jmp sub_DB6B
loc_CCF2
        cmp #$0F
        beq loc_CD0A
        jsr sub_CD1C
        lda $82
        cmp #$02
        bcc loc_CCEF
        lda $2BDE
        bne loc_CD07
loc_CD04
        jmp loc_B65C
loc_CD07
        jmp loc_B66C
loc_CD0A
        lda #$0E
        sta $82
loc_CD0E
        jsr sub_CD1C
        dec $82
        bpl loc_CD0E
        lda $2BDE
        beq loc_CD04
        bne loc_CD07

sub_CD1C
        ldx $82
        lda $2C48,x
        cmp #$FF
        bne loc_CD26
        rts
loc_CD26
        and #$3F
        sta $80
        tax
        lda $2CC8,x
        jsr sub_B023
        jsr sub_DAAC
        cmp #$07
        beq loc_CD47
        cmp #$04
        beq loc_CD4D
        jsr sub_DA92
        bcs loc_CD4A
        jsr sub_CDAF
        jsr sub_CDF1
loc_CD47
        jsr sub_A353
loc_CD4A
        jmp sub_DB04
loc_CD4D
        jsr sub_DA54
        jsr sub_DB79
        jsr sub_D3A6
        ldx $99
        stx $54
        jsr sub_D7BE
        beq loc_CD8A
        inc $54
        lda #$00
        sta $51
        sta $52
        lda $9A
        sec
        sbc #$0E
        sta $53
        jsr sub_D105
        ldx $80
        lda $51
        sta $2D48,x
        lda $52
        sta $2D68,x
loc_CD7D
        lda #$40
        jsr sub_D9FD
        beq loc_CD87
        jsr sub_CDF1
loc_CD87
        jmp sub_DB04
loc_CD8A
        lda $9A
        sec
        sbc #$0E
        sta $53
        lda $2BF6
        sta $88
        jsr sub_D11A
        ldx #$00
        lda #$02
        jsr sub_D14F
        ldx $80
        lda $8B
        sta $2D48,x
        lda $8C
        sta $2D68,x
        jmp loc_CD7D

sub_CDAF
        ldx $80
        lda $2D48,x
        ora $2D68,x
        bne loc_CDC5
        jsr sub_DCD4
        cmp #$02
        bne loc_CDC5
        lda #$0D
        jsr sub_CEEA
loc_CDC5
        jsr sub_DCD4
        cmp #$02
        bne loc_CDDB
        ldx $80
        lda $2D48,x
        bne loc_CDD6
        dec $2D68,x
loc_CDD6
        dec $2D48,x
        lda #$00
loc_CDDB
        sec
        sbc #$01
        pha
        lda #$00
        jsr sub_DCC6
        jsr sub_CEEA
        pla
        jsr sub_CEEA
        jsr sub_D885
        jmp sub_D965

sub_CDF1
        lda $82
        pha
        ldx $80
        lda $2CE8,x
        sta $5A
        lda $2D08,x
        sta $5B
        jsr sub_A1A2
        ldy $80
        ldx $2D28,y
        lda $2200,x
        and #$20
        bne loc_CE1B
        lda #$80
        ora $2200,x
        and #$8F
        sta $2200,x
        bne loc_CE5B
loc_CE1B
        lda $2D88,y
        and #$0F
        cmp #$08
        beq loc_CE5B
        lda $2200,x
        and #$8F
        sta $2200,x
        lda $2201,x
        sta $5A
        lda $2202,x
        sta $5B
        lda $221A,x
        bne loc_CE47
        sta $5A
        lda $221B,x
        sta $5B
        lda #$67
        jmp jt_dos_error
loc_CE47
        sta $2201,x
        lda $221B,x
        sta $2202,x
        lda #$00
        sta $221A,x
        sta $221B,x
        jsr sub_B32B
loc_CE5B
        pla
        sta $82
        jsr sub_DA92
        ldy $80
        ldx $2D28,y
        lda $2D48,y
        sta $221C,x
        lda $2D68,y
        sta $221D,x
        jsr sub_B5B4
        ldy $80
        lda $2CE8,y
        sta $5A
        lda $2D08,y
        sta $5B
        jmp sub_A1A5

sub_CE84
        lda #$11
        sta $82
        jsr sub_CEA3
        sta $84
        ldx $80
        lda $2DA8,x
        and #$08
        sta $81
        bne loc_CEA2
        jsr sub_DAAC
        beq loc_CEA2
        lda #$80
        jsr sub_D9EB
loc_CEA2
        rts

sub_CEA3
        jsr sub_DA60
        jsr sub_EE3C
        jsr sub_DAAC
        bne loc_CEB4
        jsr sub_9FA5
        jmp loc_CEB7
loc_CEB4
        jsr sub_9F2B
loc_CEB7
        ldx $80
        lda $2DC8,x
        rts

sub_CEBD
        ldx #$12
        stx $82
        jsr sub_DA92
        jsr sub_EE3C
        jsr sub_DAAC
        bcc loc_CED1
        lda #$20
        jsr sub_D9F2
loc_CED1
        lda $82
        cmp #$0F
        bne loc_CEDA
        jmp sub_A0AD
loc_CEDA
        jsr sub_DAAC
        bcs loc_CEE2
        jmp sub_A0C1
loc_CEE2
        bne loc_CEE7
        jmp sub_A163
loc_CEE7
        jmp sub_A168

sub_CEEA
        pha
        jsr sub_DCF2
        bpl loc_CEF6
        pla
        lda #$61
        jmp sub_B66F
loc_CEF6
        asl
        tax
        pla
        sta ($A0,x)
        inc $A0,x
        rts

sub_CEFE
        ldx $80
        lda $2C68,x
        bpl loc_CF08
        lda $2C88,x
loc_CF08
        and #$BF
        asl
        tax
        ldy $80
        lda $2DE8,y
        beq loc_CF25
        lda ($A0,x)
        pha
        lda $A0,x
        cmp $2DE8,y
        bne loc_CF21
        lda #$FF
        sta $A0,x
loc_CF21
        pla
        inc $A0,x
        rts
loc_CF25
        lda ($A0,x)
        inc $A0,x
        rts

sub_CF2A
        jsr sub_CEEA
        beq loc_CF30
        rts
loc_CF30
        jsr sub_A3F3
        lda #$00
        jsr sub_DCC6
        lda $5A
        jsr sub_CEEA
        lda $5B
        jsr sub_CEEA
        jsr sub_D885
        jsr sub_DB79
        jsr sub_D973
        lda #$02
        jmp sub_DCC6

sub_CF50
        jsr sub_CF88
        jsr sub_CFCD
        lda $90
        sta $9B
        jsr sub_CFD0
        inc $9B
        inc $9B
        jsr sub_D7BE
        beq loc_CF73
        lda $8B
        sta $99
        lda $90
        asl
        clc
        adc #$10
        sta $9A
        rts
loc_CF73
        lda $90
        asl
        clc
        adc #$10
        sta $9A
        jsr sub_CFD3
        lda $90
        sta $99
        lda $8B
        sta $2BF6
        rts

sub_CF88
        jsr sub_CFFF
        sta $92
        ldx $80
        lda $2D48,x
        sta $90
        lda $2D68,x
        sta $91
        bne loc_CF9F
        lda $90
        beq loc_CFAA
loc_CF9F
        lda $90
        sec
        sbc #$01
        sta $90
        bcs loc_CFAA
        dec $91
loc_CFAA
        lda $2E08,x
        sta $50
loc_CFAF
        lsr $50
        bcc loc_CFB6
        jsr sub_D013
loc_CFB6
        jsr sub_D00B
        lda $50
        bne loc_CFAF
        lda $98
        clc
        adc $8B
        sta $8B
        bcc loc_CFCC
        inc $8C
        bne loc_CFCC
        inc $8D
loc_CFCC
        rts

sub_CFCD
        lda #$FE
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_CFD0
        lda #$78
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_CFD3
        lda #$06
        sta $50
        lda #$00
        sta $90
        sta $91
        ldx #$18
loc_CFDF
        asl $8B
        rol $8C
        rol $8D
        rol $90
        rol $91
        lda $90
        sec
        sbc $50
        tay
        lda $91
        sbc #$00
        bcc loc_CFFB
        inc $8B
        sta $91
        sty $90
loc_CFFB
        dex
        bne loc_CFDF
        rts

sub_CFFF
        lda #$00
        sta $8B
        sta $8C
        sta $8D
        rts

sub_D008
        jsr sub_D00B

sub_D00B
        clc
        rol $90
        rol $91
        rol $92
        rts

sub_D013
        clc
        ldx #$FD
loc_D016
        lda $8E,x
        adc $93,x
        sta $8E,x
        inx
        bne loc_D016
        rts

sub_D020
        jsr sub_D04F
        lda $5A
        sta ($94),y
        iny
        lda $5B
        sta ($94),y
        jmp sub_D2D5

sub_D02F
        jsr sub_D04F
        lda ($94),y
        sta $5A
        iny
        lda ($94),y
        sta $5B
        rts

sub_D03C
        jsr sub_D04F
        lda #$00
        sta ($94),y
        iny
        ldx $80
        lda $2E28,x
        tax
        dex
        txa
        sta ($94),y
        rts

sub_D04F
        jsr sub_DCF2
        asl
        tax
        lda $A1,x
        sta $95
        lda #$00
        sta $94
        ldy #$00
        rts

sub_D05F
        pha
        lda #$00
        sta $50
        sta $52
        tya
        clc
        adc #$03
        sta $51
        txa
        clc
        adc #$03
        sta $53
        pla
        tay
        dey
loc_D075
        lda ($50),y
        sta ($52),y
        dey
        bpl loc_D075
        rts

sub_D07D
        tay
        clc
        adc #$03
        sta $51
        lda #$00
        sta $50
        tay
loc_D088
        sta ($50),y
        iny
        bne loc_D088
        rts

sub_D08E
        lda #$00
        jsr sub_D098
        ldy #$02
        lda ($94),y
        rts

sub_D098
        sta $94
        ldx $80
        lda $2CA8,x
        tax
        clc
        adc #$03
        sta $95
        rts

sub_D0A6
        pha
        jsr sub_D098
        pha
        txa
        asl
        tax
        pla
        sta $A1,x
        pla
        sta $A0,x
        rts

sub_D0B5
        jsr sub_D156
        bmi loc_D0C9
        bvc loc_D0D0
        ldx $80
        lda $2CA8,x
        jsr sub_D0D9
        jsr sub_D156
        bpl loc_D0D0
loc_D0C9
        jsr sub_D3A6
        bit dat_D520
        rts
loc_D0D0
        lda $9A
        jsr sub_D0A6
        bit dat_D521
        rts

sub_D0D9
        sta $9C
        lda #$80
        bne loc_D0E3
        sta $9C
        lda #$90
loc_D0E3
        sta $55
        lda ($94),y
        sta $5A
        iny
        lda ($94),y
        sta $5B
        lda $9C
        jsr sub_D976
        ldx $9C
        jmp loc_D960

sub_D0F8
        ldx $80
        lda $2CA8,x
        jmp loc_DCD7
loc_D100
        lda #$78
        jsr sub_D110

sub_D105
        dex
        bpl loc_D100
        lda $53
        lsr
        jsr sub_D110
        lda $54

sub_D110
        clc
        adc $51
        sta $51
        bcc loc_D119
        inc $52
loc_D119
        rts

sub_D11A
        jsr sub_CFFF
        jsr sub_D146
        ldy $88
loc_D122
        dey
        bmi loc_D12F
        ldx #$02
        lda #$D6
        jsr sub_D14F
        jmp loc_D122
loc_D12F
        ldy $54
loc_D131
        dey
        bmi loc_D13E
        ldx #$00
        lda #$79
        jsr sub_D14F
        jmp loc_D131
loc_D13E
        lda $53
        lsr
        ldx #$00
        jmp sub_D14F

sub_D146
        ldx #$00
        stx $90
        stx $91
        stx $92
        rts

sub_D14F
        stx $91
        sta $90
        jmp sub_D013

sub_D156
        jsr sub_D7BE
        bne loc_D167
        lda $2BF6
        jsr sub_D818
        beq loc_D167
        bit dat_D522
        rts
loc_D167
        jsr sub_D08E
        cmp $99
        bne loc_D17C
        ldy $9A
        lda ($94),y
        beq loc_D178
        bit dat_D521
        rts
loc_D178
        bit dat_D523
        rts
loc_D17C
        lda $99
        cmp #$06
        bcs loc_D18C
        asl
        tay
        lda #$04
        sta $94
        lda ($94),y
        bne loc_D190
loc_D18C
        bit dat_D522
        rts
loc_D190
        bit dat_D520
        rts

sub_D194
        lda #$20
        jsr sub_D9F2
        lda #$80
        jsr sub_D9FD
        bne loc_D1E6
        ldx $80
        inc $2D48,x
        bne loc_D1AA
        inc $2D68,x
loc_D1AA
        ldx $80
        lda $2E28,x
        beq loc_D1E1
        jsr sub_DCD4
        ldx $80
        cmp $2E28,x
        bcc loc_D1BE
        jsr sub_D207
loc_D1BE
        ldx $80
        lda $2E28,x
        jsr sub_DCC6
        lda ($A0,x)
        sta $84
        lda #$20
        jsr sub_D9F2
        jsr sub_D506

sub_D1D2
        pha
        bcc loc_D1FE
        lda #$00
        jsr sub_DCE2
        bne loc_D1FE
        pla
        cmp #$02
        beq loc_D1F3
loc_D1E1
        lda #$80
        jsr sub_D9EB
loc_D1E6
        jsr sub_DAB7
        lda $A0,x
        sta $2DE8,y
        lda #$0D
        sta $84
        rts
loc_D1F3
        jsr sub_D1FF
        ldx $80
        lda #$00
        sta $2E28,x
        rts
loc_D1FE
        pla

sub_D1FF
        ldx $80
        sta $2E28,x
        jmp loc_D347

sub_D207
        jsr sub_D9DB
        jsr sub_DCFF
        bvc loc_D225
        jsr sub_D9A7
        jsr sub_DB79
        lda #$02
        jsr sub_DCC6
        jsr sub_DA03
        bne loc_D233
        jsr sub_D9A1
        jmp sub_D965
loc_D225
        jsr sub_DB79
        jsr sub_DA03
        bne loc_D233
        jsr sub_D9A1
        jsr sub_D965
loc_D233
        jsr sub_D9DB
        lda $5A
        beq loc_D243
        jsr sub_DB79
        jsr sub_D9A1
        jmp sub_DB79
loc_D243
        rts

sub_D244
        jsr sub_D2D5
        jsr sub_DCF2
        asl
        tax
        lda $84
        sta ($A0,x)
        ldy $A0,x
        iny
        bne loc_D25E
        ldy $80
        lda $2E28,y
        beq loc_D266
        ldy #$02
loc_D25E
        tya
        ldy $80
        cmp $2E28,y
        bne loc_D26B
loc_D266
        lda #$20
        jmp sub_D9EB
loc_D26B
        inc $A0,x
        bne loc_D27A
        lda $2BF7
        ora #$10
        sta $2BF7
        jmp sub_D207
loc_D27A
        rts
loc_D27B
        lda #$A0
        jsr sub_D9FD
        bne loc_D2A9
loc_D282
        lda $84
        jsr sub_D244
        lda $81
        beq loc_D298
        rts
loc_D28C
        lda #$20
        jsr sub_D9FD
        beq loc_D298
        lda #$51
        sta $2BDE
loc_D298
        jsr sub_D2C3
        jsr sub_D32B
        lda $2BDE
        beq loc_D2A6
        jmp sub_B66F
loc_D2A6
        jmp sub_DFA8
loc_D2A9
        and #$80
        bne loc_D2B2
        lda $81
        beq loc_D28C
        rts
loc_D2B2
        lda $84
        pha
        jsr sub_D525
        pla
        sta $84
        lda #$80
        jsr sub_D9F2
        jmp loc_D282

sub_D2C3
        lda #$20
        jsr sub_D9FD
        bne loc_D2D4
        lda #$00
        sta $84
        jsr sub_D244
        jmp sub_D2C3
loc_D2D4
        rts

sub_D2D5
        lda #$40
        jsr sub_D9EB
        jsr sub_DCFF
        ora #$40
        ldx $44
        sta $2C68,x
        rts

sub_D2E5
        jsr sub_DCFF
        and #$BF
        ldx $44
        sta $2C68,x
        rts
loc_D2F0
        lda #$80
        jsr sub_D9FD
        bne loc_D336
        jsr sub_DAB7
        lda $A0,x
        cmp $2DE8,y
        beq sub_D32B
        inc $A0,x
        bne loc_D313
        lda $2BF7
        ora #$10
        sta $2BF7
        jsr sub_D207
loc_D310
        jsr sub_DAB7
loc_D313
        lda ($A0,x)
loc_D315
        sta $2DC8,y
        lda #$89
        sta $2DA8,y
        lda $A0,x
        cmp $2DE8,y
        beq loc_D325
        rts
loc_D325
        lda #$81
        sta $2DA8,y
        rts

sub_D32B
        jsr sub_D194
        jsr sub_DAB7
        lda $84
        jmp loc_D315
loc_D336
        ldx $80
        lda #$0D
        sta $2DC8,x
        lda #$81
        sta $2DA8,x
        lda #$50
        jsr sub_B66F
loc_D347
        ldx $80
        lda $2E28,x
        sta $86
        dec $86
        cmp #$02
        bne loc_D358
        lda #$FF
        sta $86
loc_D358
        lda $2E08,x
        sta $87
        jsr sub_DCD4
        ldx $80
        cmp $86
        bcc loc_D37F
        beq loc_D37F
        jsr sub_DB79
        jsr sub_D38D
        bcc loc_D378
        ldx $80
        sta $2DE8,x
        jmp sub_DB79
loc_D378
        jsr sub_DB79
        lda #$FF
        sta $86
loc_D37F
        jsr sub_D38D
        bcs loc_D387
        jsr sub_DCD4
loc_D387
        ldx $80
        sta $2DE8,x
        rts

sub_D38D
        jsr sub_D04F
        ldy $86
loc_D392
        lda ($94),y
        bne loc_D3A3
        dey
        cpy #$02
        bcc loc_D39F
        dec $87
        bne loc_D392
loc_D39F
        dec $87
        clc
        rts
loc_D3A3
        tya
        sec
        rts

sub_D3A6
        jsr sub_D7BE
        bne loc_D3AE
        jsr sub_D801
loc_D3AE
        jsr sub_D08E
        sta $99
        lda #$04
        sta $94
        ldy #$0A
        bne loc_D3BF
loc_D3BB
        dey
        dey
        bmi loc_D3E6
loc_D3BF
        lda ($94),y
        beq loc_D3BB
        tya
        lsr
        cmp $99
        beq loc_D3D3
        sta $99
        ldx $80
        lda $2CA8,x
        jsr sub_D0D9
loc_D3D3
        ldy #$00
        sty $94
        lda ($94),y
        bne loc_D3E6
        iny
        lda ($94),y
        tay
        dey
        sty $9A
        tya
        jmp sub_D0A6
loc_D3E6
        lda #$67
        jsr jt_dos_error

sub_D3EB
        jsr sub_B7AC
        lda $0201
        sta $82
        jsr sub_DA60
        bcc loc_D3FD
        lda #$70
        jsr sub_B66F
loc_D3FD
        lda #$A0
        jsr sub_D9F2
        jsr sub_DAAC
        beq loc_D40C
        lda #$64
        jsr sub_B66F
loc_D40C
        lda $0202
        sta $2D48,x
        lda $0203
        sta $2D68,x
        ldx $80
        lda #$89
        sta $2DA8,x
        lda $0204
        beq loc_D435
        sec
        sbc #$01
        beq loc_D435
        cmp $2E08,x
        bcc loc_D435
        lda #$51
        sta $2BDE
        lda #$00
loc_D435
        sta $98
        jsr sub_CF50
        jsr sub_D0B5
        bvc loc_D447
        lda #$80
        jsr sub_D9EB
        jmp loc_D336
loc_D447
        jsr sub_D457
        lda #$80
        jsr sub_D9FD
        beq loc_D454
        jmp loc_D336
loc_D454
        jmp loc_B654

sub_D457
        jsr sub_D47F
        lda $9B
        jsr sub_DCC6
        ldx $80
        lda $2E08,x
        sec
        sbc $98
        bcs loc_D46C
        jmp loc_D3E6
loc_D46C
        clc
        adc $9B
        bcc loc_D474
        adc #$01
        sec
loc_D474
        jsr sub_D1D2
        jmp loc_D310

sub_D47A
        lda #$51
        jsr sub_B66F

sub_D47F
        lda $94
        sta $88
        lda $95
        sta $89
        jsr sub_D4BD
        beq loc_D4AE
        jsr sub_DA54
        jsr sub_D02F
        lda $5A
        beq loc_D4AF
        jsr sub_DB79
        jsr sub_D4BD
        bne loc_D4AF
        jsr sub_D02F
        lda $5A
        beq loc_D4AE
        jsr sub_DB79
        jsr sub_D9A1
        jmp sub_DB79
loc_D4AE
        rts
loc_D4AF
        ldy #$00
        lda ($88),y
        sta $5A
        iny
        lda ($88),y
        sta $5B
        jmp loc_D86E

sub_D4BD
        jsr sub_D989
        ldy #$00
        lda ($88),y
        cmp $5A
        beq loc_D4C9
        rts
loc_D4C9
        iny
        lda ($88),y
        cmp $5B
        bne loc_D4E1
        lda $2BF7
        and #$10
        beq loc_D4E1
        lda $2BF7
        and #$EF
        sta $2BF7
        eor #$10
loc_D4E1
        rts

sub_D4E2
        jsr sub_D04F
        ldy #$02
        lda #$00
loc_D4E9
        sta ($94),y
        iny
        bne loc_D4E9
        jsr sub_D506
loc_D4F1
        sta $2E28,x
        tay
        lda #$FF
        sta ($94),y
        jsr sub_D506
        bcc loc_D4F1
        bne loc_D505
        lda #$00
        sta $2E28,x
loc_D505
        rts

sub_D506
        ldx $80
        lda $2E28,x
        sec
        beq loc_D51C
        clc
        adc $2E08,x
        bcc loc_D51F
        bne loc_D51C
        lda #$02
        bit dat_D524
        rts
loc_D51C
        adc #$01
        sec
loc_D51F
        rts
dat_D520
        !byte $7F                       ; $D520
dat_D521
        !byte $3F                       ; $D521
dat_D522
        !byte $FF                       ; $D522
dat_D523
        !byte $BF                       ; $D523
dat_D524
        !byte $00                       ; $D524

sub_D525
        jsr sub_D687
        jsr sub_CF50
loc_D52B
        jsr sub_C67C
        ldy $80
        ldx $2E08,y
        dex
        txa
        clc
        adc $9B
        bcc loc_D546
        inc $9A
        inc $9A
        bne loc_D546
        inc $99
        lda #$10
        sta $9A
loc_D546
        lda $86
        clc
        adc #$02
        jsr sub_D0A6
        lda $99
        cmp #$06
        bcc loc_D565
        jsr sub_D7BE
        bne loc_D560
        sta $99
        inc $2BF6
        bne loc_D565
loc_D560
        lda #$52
        jsr sub_B66F
loc_D565
        lda $9A
        sec
        sbc $86
        bcs loc_D56F
        sbc #$0F
        clc
loc_D56F
        pha
        jsr sub_D7BE
        beq loc_D593
        pla
        sta $53
        lda $99
        sbc $85
        sta $54
        ldx #$00
        stx $51
        stx $52
        tax
        jsr sub_D105
        lda $52
        bne loc_D5BB
        ldx $51
        dex
        bne loc_D5BB
        beq loc_D5B9
loc_D593
        pla
        sta $53
        lda $99
        sbc $85
        bcs loc_D5A0
        inc $88
        adc #$06
loc_D5A0
        sta $54
        lda $2BF6
        sec
        sbc $88
        sta $88
        jsr sub_D11A
        lda $8C
        bne loc_D5BB
        ldx $8B
        bne loc_D5B6
        rts
loc_D5B6
        dex
        bne loc_D5BB
loc_D5B9
        inc $87
loc_D5BB
        cmp $2BC4
        bcc loc_D5C9
        bne loc_D560
        lda $2BC3
        cmp $51
        bcc loc_D560
loc_D5C9
        lda #$01
        jsr sub_DCE2
        clc
        adc #$01
        ldx $80
        sta $2E28,x
        jsr sub_A3F3
        jsr sub_D020
        lda $87
        bne loc_D5F5
        jsr sub_D9A7
loc_D5E3
        jsr sub_DB79
        jsr sub_D973
        jsr sub_A3F3
        jsr sub_D020
        jsr sub_D4E2
        jmp loc_D601
loc_D5F5
        jsr sub_DB79
        jsr sub_D973
        jsr sub_D4E2
        jsr sub_D03C
loc_D601
        jsr sub_D9A7
        jsr sub_D02F
        lda $5A
        pha
        lda $5B
        pha
        jsr sub_D989
        lda $5B
        pha
        lda $5A
        pha
        jsr sub_D0F8
        tax
        bne loc_D626
        jsr sub_D6A8
        lda #$10
        jsr sub_D0A6
        inc $85
loc_D626
        pla
        jsr sub_CCDA
        pla
        jsr sub_CCDA
        pla
        sta $5B
        pla
        sta $5A
        beq loc_D651
        jsr sub_D7BE
        bne loc_D642
        lda $8A
        cmp $2BF6
        bcc loc_D5E3
loc_D642
        lda $85
        cmp $99
        bne loc_D5E3
        jsr sub_D0F8
        cmp $9A
        bcc loc_D5E3
        beq loc_D5F5
loc_D651
        jsr sub_D0F8
        pha
        lda #$00
        jsr sub_D098
        lda #$00
        tay
        sta ($94),y
        iny
        pla
        sec
        sbc #$01
        sta ($94),y
        jsr sub_D9B3
        jsr sub_D965
        jsr sub_A348
        jsr sub_CF50
        jsr sub_DB79
        jsr sub_D0B5
        bvs loc_D67D
        jmp sub_D457
loc_D67D
        lda #$80
        jsr sub_D9EB
        lda #$50
        jsr sub_B66F

sub_D687
        jsr sub_D3A6
        jsr sub_D47F
        jsr sub_D7BE
        bne loc_D699
        lda $2BF6
        sta $8A
        sta $88
loc_D699
        lda $9A
        sta $86
        lda $99
        sta $85
        lda #$00
        sta $87
        sta $98
        rts

sub_D6A8
        jsr sub_A3F3
        jsr sub_DB79
        jsr sub_DA54
        jsr sub_DCF2
        pha
        jsr sub_D07D
        ldx $80
        lda $2CA8,x
        tay
        pla
        tax
        jsr sub_D7BE
        bne loc_D6C8
        jmp loc_D797
loc_D6C8
        lda #$10
        jsr sub_D05F
        lda #$00
        jsr sub_D098
        ldy #$02
        lda ($94),y
        pha
        lda #$00
        jsr sub_DCC6
        pla
        clc
        adc #$01
        sta ($94),y
        asl
        adc #$04
        sta $88
        tay
        sec
        sbc #$02
        sta $89
loc_D6ED
        lda $5A
        sta $86
        sta ($94),y
        iny
        lda $5B
        sta $87
        sta ($94),y
        ldy #$00
        tya
        sta ($94),y
        iny
        lda #$11
        sta ($94),y
        lda #$10
        jsr sub_DCC6
        jsr sub_D99B
        jsr sub_D965
        ldx $80
        lda $2CA8,x
        pha
        jsr sub_DCFF
        ldx $80
        sta $2CA8,x
        pla
        ldx $44
        sta $2C68,x
        lda #$00
        jsr sub_DCC6
        ldy #$00
        lda $5A
        sta ($94),y
        iny
        lda $5B
        sta ($94),y
        jsr sub_D7BE
        bne loc_D779
        lda $85
        cmp #$FF
        bne loc_D779
        lda $5B
        pha
        lda $5A
        pha
        jsr sub_D9A7
        jsr sub_D965
        jsr sub_DB79
        jsr sub_D7D6
        inc $8A
        lda $8A
        asl
        clc
        adc #$03
        jsr sub_D0A6
        pla
        jsr sub_CCDA
        pla
        jsr sub_CCDA
        jsr sub_D7D9
        lda $8A
        pha
        jmp loc_D824
loc_D76C
        jsr sub_DCF2
        ldx $80
        jsr sub_D0D9
        lda #$00
        jsr sub_DCC6
loc_D779
        dec $89
        dec $89
        ldy $88
        lda $86
        sta ($94),y
        iny
        lda $87
        sta ($94),y
        jsr sub_D9A7
        jsr sub_D965
        ldy $89
        cpy #$03
        bcs loc_D76C
        jmp sub_DB79
loc_D797
        lda $85
        cmp #$05
        bcs loc_D7A0
        jmp loc_D6C8
loc_D7A0
        lda #$FF
        sta $85
        lda #$00
        jsr sub_DCC6
        ldy #$02
        sta ($94),y
        ldx $80
        lda $2E08,x
        iny
        sta ($94),y
        iny
        beq loc_D7BB
        jmp loc_D6ED
loc_D7BB
        jmp loc_D6C8

sub_D7BE
        stx $2BF8
        ldx $80
        lda $2EA8,x
        ldx $2BF8
        and #$20
        rts

sub_D7CC
        ldx $80
        lda #$FE
        cmp $2E48,x
        bne sub_D7D6
        rts

sub_D7D6
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_D7D9
        lda #$90
        pha
        ldx $80
        lda $2E88,x
        sta $5A
        lda $2E68,x
        sta $5B
        lda #$FF
        sta $2E48,x
        lda $2CA8,x
        sta $9C
        jsr sub_D976
        pla
        jsr sub_D95C
        ldx $80
        lda #$FE
        sta $2E48,x
        rts

sub_D801
        lda #$5A
        sta $2BF6
        jsr sub_D818
        bne loc_D80C
        rts
loc_D80C
        dec $2BF6
        lda $2BF6
        jsr sub_D82A
        bne loc_D80C
        rts

sub_D818
        ldx $80
        cmp $2E48,x
        bne loc_D820
        rts
loc_D820
        pha
        jsr sub_D7CC
loc_D824
        lda #$03
        jsr sub_D098
        pla

sub_D82A
        tax
        asl
        tay
        lda ($94),y
        bne loc_D834
        ora #$FF
        rts
loc_D834
        sta $5A
        iny
        lda ($94),y
        sta $5B
        txa
        pha
        lda #$FF
        ldx $80
        sta $2E48,x
        lda $2CA8,x
        sta $9C
        jsr sub_D976
        lda #$80
        jsr sub_D95C
        ldx $80
        pla
        sta $2E48,x
        lda #$00
        rts

sub_D85A
        jsr sub_D973
        jsr sub_D882
        jsr sub_D965
        jsr sub_CEFE
        sta $5A
        jsr sub_CEFE
        sta $5B
        rts
loc_D86E
        jsr sub_D85A
        lda $5A
        bne loc_D876
        rts
loc_D876
        jsr sub_DB79
        jsr sub_D973
        jsr sub_D882
        jmp sub_DB79

sub_D882
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_D885
        lda #$90
        sta $55
        jsr sub_DCF2
        tax
        jsr sub_D8BB
        txa
        pha
        asl
        tax
        lda #$00
        sta $A0,x
        jsr sub_DAAC
        cmp #$04
        bcs loc_D8A7
        inc $2D48,x
        bne loc_D8A7
        inc $2D68,x
loc_D8A7
        pla
        tax
        rts

sub_D8AA
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_D8AD
        lda #$90
        sta $55
        lda $9C
        jsr sub_D976
        ldx $9C
        jmp loc_D960

sub_D8BB
        lda $55

sub_D8BD
        pha
        stx $9C
        bit $2BDF
        bvc loc_D8C8
        jmp loc_D94F
loc_D8C8
        txa
        asl
        tax
        lda $2801,x
        sta $55
        lda $2800,x
        beq loc_D905
        tax
        jsr sub_AF7F
        lda $9C
        asl
        tax
        lda $2BC8
        beq loc_D8E9
        cmp $2800,x
        beq loc_D905
        bcc loc_D905
loc_D8E9
        pla
        pha
        cmp #$90
        bne loc_D94F
        jsr sub_A287
        lda $2B70,x
        jsr sub_AF6B
        bne loc_D947
        lda $2BC9
        beq loc_D94F
        cmp $55
        beq loc_D905
        bcs loc_D94F
loc_D905
        jsr sub_D90D
loc_D908
        lda #$66
        jmp jt_dos_error

sub_D90D
        lda $9C
        asl
        tax
        lda $2800,x
        sta $5A
        lda $2801,x
        sta $5B
        rts

sub_D91C
        txa
        pha
        ldx $5A
        jsr sub_AF7F
        lda $5A
        beq loc_D908
        lda $2BC8
        beq loc_D932
        cmp $5A
        beq loc_D908
        bcc loc_D908
loc_D932
        lda $5A
        cmp $2BC7
        bcc loc_D908
        lda $2BC9
        beq loc_D944
        cmp $5B
        beq loc_D908
        bcc loc_D908
loc_D944
        pla
        tax
        rts
loc_D947
        jsr sub_D90D
        lda #$73
        jmp jt_dos_error
loc_D94F
        ldx $9C
        pla
        sta $55
        jmp jt_do_job

sub_D957
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_D95A
        lda #$90

sub_D95C
        ldx $9C
        sta $55
loc_D960
        lda $55
        jsr sub_D8BD

sub_D965
        lda $20,x
        jsr jt_do_job
        clc
        pha
        lda #$00
        sta $2BDF
        pla
        rts

sub_D973
        jsr sub_DCF2

sub_D976
        asl
        tay
        lda $5A
        sta $2800,y
        lda $5B
        sta $2801,y
        lda #$00
        tax
        rts

sub_D986
        jsr sub_DA60

sub_D989
        jsr sub_DCF2
        sta $9C
        asl
        tay
        lda $2800,y
        sta $5A
        lda $2801,y
        sta $5B
        rts

sub_D99B
        lda #$90
        sta $55
        bne loc_D9C5

sub_D9A1
        lda #$80
        sta $55
        bne loc_D9C5

sub_D9A7
        lda #$90
        sta $55
        bne loc_D9D1
        lda #$80
        sta $55
        bne loc_D9D1

sub_D9B3
        lda #$90
        sta $55
        bne loc_D9BB

sub_D9B9
        lda #$80
loc_D9BB
        sta $55
        ldx $80
        lda $2CA8,x
        tax
        bpl loc_D9D8
loc_D9C5
        jsr sub_D973
        jsr sub_DCF2
        tax
        lda #$00
        sta $2960,x
loc_D9D1
        jsr sub_D2E5
        jsr sub_DCF2
        tax
loc_D9D8
        jmp sub_D8BB

sub_D9DB
        lda #$00
        jsr sub_DCC6
        jsr sub_CEFE
        sta $5A
        jsr sub_CEFE
        sta $5B
        rts

sub_D9EB
        ldx $80
        ora $2D88,x
        bne loc_D9F9

sub_D9F2
        ldx $80
        eor #$FF
        and $2D88,x
loc_D9F9
        sta $2D88,x
        rts

sub_D9FD
        ldx $80
        and $2D88,x
        rts

sub_DA03
        jsr sub_DCF2
        tax
        lda $2960,x
        and #$FE
        cmp #$90
        rts

sub_DA0F
        ldx #$00
loc_DA11
        stx $52
        lda $2C48,x
        cmp #$FF
        bne loc_DA22
loc_DA1A
        ldx $52
        inx
        cpx #$10
        bcc loc_DA11
        rts
loc_DA22
        stx $52
        and #$3F
        tay
        ldx $2BBF
        lda $2D88,y
        cmp $2C18,x
        bne loc_DA1A
        lda $2CC8,y
        cmp $2C10,x
        bne loc_DA1A
        lda $2CE8,y
        cmp $2C30,x
        bne loc_DA1A
        lda $2D08,y
        cmp $2C38,x
        bne loc_DA1A
        lda $2D28,y
        cmp $2C40,x
        bne loc_DA1A
        clc
        rts

sub_DA54
        jsr sub_DCFF
        bvc loc_DA5F
        jsr sub_D9A7
        jsr sub_D965
loc_DA5F
        rts

sub_DA60
        lda $82
        cmp #$13
        bcc loc_DA68
        and #$0F
loc_DA68
        cmp #$0F
        bne loc_DA6E
        lda #$10
loc_DA6E
        tax
        sec
        lda $2C48,x
        bmi loc_DA91

sub_DA75
        and #$3F
        sta $80
        tax
        cmp #$1F
        beq loc_DA82
        cmp #$1E
        bne loc_DA88
loc_DA82
        lda $2BD6
        jmp loc_DA8B
loc_DA88
        lda $2CC8,x
loc_DA8B
        jsr sub_B023
        lda $80
        clc
loc_DA91
        rts

sub_DA92
        lda $82
        cmp #$13
        bcc loc_DA9A
        and #$0F
loc_DA9A
        tax
        lda $2C48,x
        tay
        asl
        bcc loc_DAA8
        bmi loc_DAAA
loc_DAA4
        tya
        jmp sub_DA75
loc_DAA8
        bmi loc_DAA4
loc_DAAA
        sec
        rts

sub_DAAC
        ldx $80
        lda $2D88,x
        lsr
        and #$07
        cmp #$04
        rts

sub_DAB7
        jsr sub_DCF2
        asl
        tax
        ldy $80
        rts

sub_DABF
        sec
        bcs loc_DAC3

sub_DAC2
        clc
loc_DAC3
        php
        sta $50
        jsr sub_DB04
        jsr sub_DB48
        lda $90E8
        sta $2CC8,x
        txa
        ldx $82
        plp
        bcc loc_DADA
        ora #$80
loc_DADA
        sta $2C48,x
        and #$3F
        tay
        jsr sub_DC68
        dec $50
        bmi loc_DB03
        jsr sub_DC76
        bpl loc_DAF4
loc_DAEC
        jsr sub_DC68
        lda #$70
        jmp sub_B66F
loc_DAF4
        sta $2C68,y
        dec $50
        bmi loc_DB03
        jsr sub_DC76
        bmi loc_DAEC
        sta $2C88,y
loc_DB03
        rts

sub_DB04
        lda $82
        cmp #$0F
        bne loc_DB0B
loc_DB0A
        rts
loc_DB0B
        tax
        lda $2C48,x
        cmp #$FF
        beq loc_DB0A
        and #$3F
        sta $80
        lda #$FF
        sta $2C48,x
        ldx $80
        lda #$00
        sta $2DA8,x
        jmp sub_DC68

sub_DB26
        lda #$0E
        sta $82
loc_DB2A
        ldx $82
        lda $2C48,x
        cmp #$FF
        beq loc_DB43
        and #$3F
        sta $80
        tax
        lda $2CC8,x
        cmp $90E8
        bne loc_DB43
        jsr sub_DB04
loc_DB43
        dec $82
        bpl loc_DB2A
        rts

sub_DB48
        lda #$00
        sta $80
loc_DB4C
        ldx #$12
loc_DB4E
        lda $2C48,x
        and #$3F
        cmp $80
        beq loc_DB5E
        dex
        bpl loc_DB4E
        lda $80
        tax
        rts
loc_DB5E
        inc $80
        lda $80
        cmp #$20
        bcc loc_DB4C
        lda #$70
        jmp sub_B66F

sub_DB6B
        lda #$11
        sta $82
        jsr sub_DB04
        lda #$12
        sta $82
        jmp sub_DB04

sub_DB79
        ldx $80
        lda $2C68,x
        bmi loc_DB83
        lda $2C88,x
loc_DB83
        cmp #$FF
        beq loc_DBA3
        lda $2C68,x
        eor #$80
        sta $2C68,x
        pha
        lda $2C88,x
        eor #$80
        sta $2C88,x
        tay
        pla
        bpl loc_DB9D
        tya
loc_DB9D
        and #$BF
        tax
        jmp sub_D965
loc_DBA3
        lda $2C68,x
        bpl loc_DBAB
        lda $2C88,x
loc_DBAB
        and #$BF
        tay
        jsr sub_DC76
        bpl loc_DBB8
        lda #$70
        jmp sub_B66F
loc_DBB8
        ldx $80
        ora #$80
        ldy $2C68,x
        bpl loc_DBC6
        sta $2C68,x
        bmi loc_DBC9
loc_DBC6
        sta $2C88,x
loc_DBC9
        lda $5A
        pha
        lda $5B
        pha
        lda #$01
        sta $52
        lda $2C68,x
        bpl loc_DBDB
        lda $2C88,x
loc_DBDB
        and #$BF
        tay
        clc
        adc #$03
        sta $53
        ldy #$00
        lda ($52),y
        sta $5B
        lda #$00
        sta $52
        lda $2C68,x
        bpl loc_DBF5
        lda $2C88,x
loc_DBF5
        and #$BF
        tay
        clc
        adc #$03
        sta $53
        ldy #$00
        lda ($52),y
        sta $5A
        beq loc_DC33
        jsr sub_DAAC
        beq loc_DC15
        jsr sub_DA03
        bne loc_DC15
        jsr sub_DC48
        jmp loc_DC2A
loc_DC15
        ldx $80
        lda $2C68,x
        eor #$80
        sta $2C68,x
        lda $2C88,x
        eor #$80
        sta $2C88,x
        jsr sub_D9A1
loc_DC2A
        pla
        sta $5B
        pla
        sta $5A
        jmp loc_DC3C
loc_DC33
        pla
        sta $5B
        pla
        sta $5A
        jsr sub_DC48
loc_DC3C
        jsr sub_DCF2
        tax
        jmp sub_D965

sub_DC43
        lda #$70
        jmp sub_B66F

sub_DC48
        ldx $80
        lda $2C68,x
        eor #$80
        sta $2C68,x
        lda $2C88,x
        eor #$80
        sta $2C88,x
        rts

sub_DC5B
        sta $50
        jsr sub_DCD4
        clc
        adc $50
        sta $A0,x
        sta $94
        rts

sub_DC68
        ldx $80
        lda #$FF
        sta $2C68,x
        sta $2C88,x
        sta $2CA8,x
        rts

sub_DC76
        tya
        pha
        jsr sub_DC94
        bmi loc_DC90
loc_DC7D
        lda $20,x
        bmi loc_DC7D
        lda #$00
        sta $20,x
        sta $2960,x
        txa
        asl
        tay
        lda #$02
        sta $00A0,y
loc_DC90
        pla
        tay
        txa
        rts

sub_DC94
        lda #$1E
        sta $41
loc_DC98
        dec $41
        bmi loc_DCA1
        jsr sub_DCA5
        beq loc_DC98
loc_DCA1
        lda $41
        tax
        rts

sub_DCA5
        ldx #$1F
loc_DCA7
        lda $2C68,x
        and #$1F
        cmp $41
        beq loc_DCC5
        lda $2C88,x
        and #$1F
        cmp $41
        beq loc_DCC5
        lda $2CA8,x
        and #$1F
        cmp $41
        beq loc_DCC5
        dex
        bpl loc_DCA7
loc_DCC5
        rts

sub_DCC6
        sta $50
        jsr sub_DCF2
        asl
        tax
        lda $50
        sta $A0,x
        jmp loc_DCD9

sub_DCD4
        jsr sub_DCF2
loc_DCD7
        asl
        tax
loc_DCD9
        lda $A1,x
        sta $95
        lda $A0,x
        sta $94
        rts

sub_DCE2
        sta $52
        jsr sub_DCF2
        tax
        clc
        adc #$03
        sta $53
        ldy #$00
        lda ($52),y
        rts

sub_DCF2
        ldx $80
        lda $2C68,x
        bpl loc_DCFC
        lda $2C88,x
loc_DCFC
        and #$BF
        rts

sub_DCFF
        ldx $80
        stx $44
        lda $2C68,x
        bpl loc_DD11
        txa
        clc
        adc #$20
        sta $44
        lda $2C88,x
loc_DD11
        sta $51
        and #$1F
        bit $51
        rts

sub_DD18
        ldx $80
        lda $2C68,x
        bmi loc_DD22
        lda $2C88,x
loc_DD22
        cmp #$FF
        rts

sub_DD25
        ldx $80
        ora #$80
        ldy $2C68,x
        bpl loc_DD32
        sta $2C68,x
        rts
loc_DD32
        sta $2C88,x
        rts

sub_DD36
        lda $0201
        cmp #$30
        beq loc_DD4E
        and #$0F
        asl
        tay
        dey
        lda ($62),y
        sta $65
        dey
        lda ($62),y
        sta $64
        jmp loc_DD9D
loc_DD4E
        lda $56
        cmp #$03
        bcs loc_DD5D

sub_DD54
        lda #<tbl_DDA6
        sta $62
        lda #>tbl_DDA6
        sta $63

sub_DD5C
        rts
loc_DD5D
        sei
        jsr sub_B07E
        cmp #$01
        beq loc_DD78
        cmp #$04
        beq loc_DD7B
        cmp #$05
        beq loc_DD7B
        cmp #$03
        beq loc_DD7E
        cmp #$02
        beq loc_DD7E
        jmp loc_DF97
loc_DD78
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_DD7B
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_DD7E
        lda #$40
        sta $2BE8
        jsr sub_EE3C
        lda #$00
        sta $6E
        lda $0202
        sta $4C
        and #$1F
        asl
        tax
        lda tbl_DDBA,x
        sta $64
        lda tbl_DDBA+1,x
        sta $65
loc_DD9D
        jsr sub_DDA3
        jmp loc_B654
sub_DDA3
        jmp ($0064)
tbl_DDA6
        !word sub_AAED                  ; $DDA6
        !word sub_AB2B                  ; $DDA8
        !word $0500                     ; $DDAA
        !word $0503                     ; $DDAC
        !word $0506                     ; $DDAE
        !word $0509                     ; $DDB0
        !word $050C                     ; $DDB2
        !word $050F                     ; $DDB4
        !word sub_9A7C                  ; $DDB6
        !word sub_F497                  ; $DDB8
tbl_DDBA
        !word sub_E4C9                  ; $DDBA
        !word sub_E3E7                  ; $DDBC
        !word sub_E51B                  ; $DDBE
        !word sub_E51E                  ; $DDC0
        !word sub_E59A                  ; $DDC2
        !word sub_E3E7                  ; $DDC4
        !word sub_E61E                  ; $DDC6
        !word sub_E61E                  ; $DDC8
        !word sub_E78E                  ; $DDCA
        !word sub_E78E                  ; $DDCC
        !word sub_E5C8                  ; $DDCE
        !word sub_E3E7                  ; $DDD0
        !word sub_E5AD                  ; $DDD2
        !word sub_E3E7                  ; $DDD4
        !word sub_E67B                  ; $DDD6
        !word sub_E67B                  ; $DDD8
        !word sub_E4C9                  ; $DDDA
        !word sub_E3E7                  ; $DDDC
        !word sub_E51B                  ; $DDDE
        !word sub_E51E                  ; $DDE0
        !word sub_E59A                  ; $DDE2
        !word sub_E3E7                  ; $DDE4
        !word sub_E61E                  ; $DDE6
        !word sub_E61E                  ; $DDE8
        !word sub_DD5C                  ; $DDEA
        !word sub_DD5C                  ; $DDEC
        !word sub_E5C8                  ; $DDEE
        !word sub_E3E7                  ; $DDF0
        !word sub_E706                  ; $DDF2
        !word sub_E706                  ; $DDF4
        !word sub_E711                  ; $DDF6
        !word sub_E2DD                  ; $DDF8
txt_DDFA
        !text "&COPYRIGHT CMD 89"       ; $DDFA

sub_DE0B
        ldx $5E
        txs
        jsr sub_DEFD
        jsr sub_DB6B
        jmp loc_F557
loc_DE17
        jsr sub_DECB
        ldx #$00
loc_DE1C
        lda txt_DDFA,x
        sta $0200,x
        inx
        cpx #$11
        bcc loc_DE1C
        stx $56

sub_DE29
        ldy #$01
        sty $2C00
        jsr sub_B833
        jsr sub_BECF
        lda $2C20
        bne loc_DE3E
        lda #$39
        jmp sub_B66F
loc_DE3E
        lda #$FF
        sta $85
        lda $2C28
        sta $5B
        lda $2C20
        sta $5A
        lda #$03
        jsr sub_C37A
loc_DE51
        lda #$00
        sta $2BD2
        jsr sub_DEB7
        sta $87
        jsr sub_DEC1
        jsr sub_DEB7
        sta $88
        jsr sub_DEC1
        jsr sub_DEB7
        sta $2BD3
        jsr sub_DEC1
        lda $85
        beq loc_DE79
        lda $88
        pha
        lda $87
        pha
loc_DE79
        jsr sub_DEB7
        ldy #$00
        sty $85
        sta ($87),y
        jsr sub_DEC1
        inc $87
        bne loc_DE8B
        inc $88
loc_DE8B
        dec $2BD3
        bne loc_DE79
        jsr sub_CE84
        lda $2BD2
        cmp $84
        bne loc_DEAA
        lda $81
        bne loc_DE51
        jsr sub_DB6B
        pla
        sta $87
        pla
        sta $88
        jmp ($0087)
loc_DEAA
        lda #$50
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_DEAD
        lda #$51
        pha
        jsr sub_D989
        pla
        jmp jt_dos_error

sub_DEB7
        jsr sub_CE84
        lda $81
        beq loc_DEAD
        lda $84
        rts

sub_DEC1
        clc
        adc $2BD2
        adc #$00
        sta $2BD2
        rts

sub_DECB
        lda jt_job_error+1
        sta $2BCE
        lda jt_job_error+2
        sta $2BCF
        lda jt_dos_error+1
        sta $2BD0
        lda jt_dos_error+2
        sta $2BD1
        ldx #$36
        jsr sub_DEEA
        ldx #$33

sub_DEEA
        lda #<sub_DE0B
        ldy #>sub_DE0B

sub_DEEE
        pha
        jsr sub_F73B
        pla
        sta jt_cmd_block+1,x
        tya
        sta jt_cmd_block+2,x
        jmp sub_F730

sub_DEFD
        ldx #$36
        lda $2BCE
        ldy $2BCF
        jsr sub_DEEE
        ldx #$33
        lda $2BD0
        ldy $2BD1
        jmp sub_DEEE

sub_DF13
        cmp #$10
        bcs loc_DF1B
        tay
        lda dat_DF84,y
loc_DF1B
        pha
        txa
        sta $9C
        asl
        tay
        lda $2800,y
        sta $5A
        lda $2801,y
        sta $5B
        lda $2BE2
        cmp #$00
        bne loc_DF3A
        lda #$FF
        sta $2BE2
        jsr sub_AF03
loc_DF3A
        pla

sub_DF3B
        jsr sub_DFB5
loc_DF3E
        ldx $5E
        txs
        jsr sub_F5E4
        jsr sub_DB6B
        jsr sub_EE2C
        lda $83
        and #$0F
        sta $82
        cmp #$0F
        beq loc_DF81
        bit $46
        bvs loc_DF60
        bpl loc_DF66
        jsr sub_DA60
        jmp loc_DF71
loc_DF60
        jsr sub_DA92
        jmp loc_DF71
loc_DF66
        tax
        lda $2C48,x
        cmp #$FF
        beq loc_DF81
        jsr sub_DA75
loc_DF71
        jsr sub_A2C7
        lda #$00
        sta $2B40,x
        jsr sub_DAAC
        bcs loc_DF81
        jsr sub_DB04
loc_DF81
        jmp jt_idle_loop
dat_DF84
        !byte $00,$00,$40,$41,$66,$44,$45,$46 ; $DF84
        !byte $26,$47,$76,$42,$43,$76,$48,$74 ; $DF8C
loc_DF94
        lda #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_DF97
        lda #$31
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_DF9A
        lda #$32
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_DF9D
        lda #$33
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_DFA0
        lda #$34
        jsr sub_DFAD
        jmp loc_DF3E

sub_DFA8
        jsr sub_EE42
        lda #$00

sub_DFAD
        pha
        lda #$00
        sta $5A
        sta $5B
        pla

sub_DFB5
        sta $50
        txa
        pha
        tya
        pha
        lda $50
        ldx #$00
loc_DFBF
        cmp dat_E0AD,x
        beq loc_DFC7
        inx
        bne loc_DFBF
loc_DFC7
        pha
        txa
        asl
        tax
        lda tbl_E0D5+1,x
        sta $DF
        lda tbl_E0D5,x
        sta $DE
        pla
        pha
        ldx #$00
        jsr sub_E053
        lda $2300
        sta $2DE7
        jsr sub_E096
        ldy #$00
loc_DFE7
        lda ($DE),y
        beq loc_DFF1
        jsr sub_E098
        iny
        bne loc_DFE7
loc_DFF1
        pla
        tay
        and #$F0
        cmp #$40
        bne loc_E020
        tya
        pha
        ldy $9C
        lda $28C0,y
dat_E000
        jsr sub_E04A
        lda $28E0,y
        jsr sub_E04A
        pla
        cmp #$40
        bne loc_E020
        lda $2900,y
        jsr sub_E041
        lda $2920,y
        jsr sub_E041
        lda $2940,y
        jsr sub_E041
loc_E020
        lda $5A
        jsr sub_E065
        lda $5B
        jsr sub_E065
        dex
        txa
        clc
        adc #$00
        sta $2E07
        jsr sub_F5ED
        inc $DE
        lda #$88
        sta $2DC7
        pla
        tay
        pla
        tax
        rts

sub_E041
        jsr sub_E08D
        jsr sub_E053
        ldy $9C
        rts

sub_E04A
        jsr sub_E08D
        jsr sub_E05C
        ldy $9C
        rts

sub_E053
        pha
        lsr
        lsr
        lsr
        lsr
        jsr sub_E05E
        pla

sub_E05C
        and #$0F

sub_E05E
        tay

sub_E05F
        lda txt_E09D,y
        jmp sub_E098

sub_E065
        pha
        jsr sub_E096
        pla
        cmp #$64
        bcc loc_E073
        ldy #$64
        jsr sub_E07A
loc_E073
        ldy #$0A
        jsr sub_E07A
        ldy #$01

sub_E07A
        sty $50
        ldy #$00
loc_E07E
        cmp $50
        bcc loc_E087
        sbc $50
        iny
        bne loc_E07E
loc_E087
        pha
        jsr sub_E05F
        pla
        rts

sub_E08D
        pha
        lda #$20
        sta $2300,x
        inx
        pla
        rts

sub_E096
        lda #$2C

sub_E098
        sta $2300,x
        inx
        rts
txt_E09D
        !text "0123456789ABCDEF"        ; $E09D
dat_E0AD
        !byte $00,$52,$50,$51,$26,$30,$31,$32,$33,$34 ; $E0AD
        !byte $60,$63,$64,$65,$66,$67,$61,$39,$62,$01 ; $E0B7
        !byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$02 ; $E0C1
        !byte $38,$40,$41,$42,$43,$44,$45,$46,$47,$48 ; $E0CB
tbl_E0D5
        !word txt_E125                  ; $E0D5
        !word txt_E129                  ; $E0D7
        !word txt_E137                  ; $E0D9
        !word txt_E14A                  ; $E0DB
        !word txt_E15D                  ; $E0DD
        !word txt_E16E                  ; $E0DF
        !word txt_E16E                  ; $E0E1
        !word txt_E16E                  ; $E0E3
        !word txt_E16E                  ; $E0E5
        !word txt_E16E                  ; $E0E7
        !word txt_E17B                  ; $E0E9
        !word txt_E18B                  ; $E0EB
        !word txt_E197                  ; $E0ED
        !word txt_E1AA                  ; $E0EF
        !word txt_E1B3                  ; $E0F1
        !word txt_E1B3                  ; $E0F3
        !word txt_E1C1                  ; $E0F5
        !word txt_E1CF                  ; $E0F7
        !word txt_E1CF                  ; $E0F9
        !word txt_E1DE                  ; $E0FB
        !word txt_E1EF                  ; $E0FD
        !word txt_E1FA                  ; $E0FF
        !word txt_E20A                  ; $E101
        !word txt_E219                  ; $E103
        !word txt_E22A                  ; $E105
        !word txt_E23A                  ; $E107
        !word txt_E247                  ; $E109
        !word txt_E256                  ; $E10B
        !word txt_E271                  ; $E10D
        !word txt_E27E                  ; $E10F
        !word txt_E2C6                  ; $E111
        !word txt_E291                  ; $E113
        !word txt_E29C                  ; $E115
        !word txt_E29C                  ; $E117
        !word txt_E29C                  ; $E119
        !word txt_E2A9                  ; $E11B
        !word txt_E2A9                  ; $E11D
        !word txt_E2A9                  ; $E11F
        !word txt_E2A9                  ; $E121
        !word txt_E2BA                  ; $E123
txt_E125
        !text " OK"                     ; $E125
        !byte $00                       ; $E128
txt_E129
        !text "FILE TOO LONG"           ; $E129
        !byte $00                       ; $E136
txt_E137
        !text "RECORD NOT PRESENT"      ; $E137
        !byte $00                       ; $E149
txt_E14A
        !text "OVERFLOW IN RECORD"      ; $E14A
        !byte $00                       ; $E15C
txt_E15D
        !text "WRITE PROTECT ON"        ; $E15D
        !byte $00                       ; $E16D
txt_E16E
        !text "SYNTAX ERROR"            ; $E16E
        !byte $00                       ; $E17A
txt_E17B
        !text "WRITE FILE OPEN"         ; $E17B
        !byte $00                       ; $E18A
txt_E18B
        !text "FILE EXISTS"             ; $E18B
        !byte $00                       ; $E196
txt_E197
        !text "FILE TYPE MISMATCH"      ; $E197
        !byte $00                       ; $E1A9
txt_E1AA
        !text "NO BLOCK"                ; $E1AA
        !byte $00                       ; $E1B2
txt_E1B3
        !text "ILLEGAL BLOCK"           ; $E1B3
        !byte $00                       ; $E1C0
txt_E1C1
        !text "FILE NOT OPEN"           ; $E1C1
        !byte $00                       ; $E1CE
txt_E1CF
        !text "FILE NOT FOUND"          ; $E1CF
        !byte $00                       ; $E1DD
txt_E1DE
        !text " FILES SCRATCHED"        ; $E1DE
        !byte $00                       ; $E1EE
txt_E1EF
        !text "NO CHANNEL"              ; $E1EF
        !byte $00                       ; $E1F9
txt_E1FA
        !text "DIRECTORY ERROR"         ; $E1FA
        !byte $00                       ; $E209
txt_E20A
        !text "PARTITION FULL"          ; $E20A
        !byte $00                       ; $E218
txt_E219
        !text "CMD HD DOS V1.92"        ; $E219
        !byte $00                       ; $E229
txt_E22A
        !text "DRIVE NOT READY"         ; $E22A
        !byte $00                       ; $E239
txt_E23A
        !text "FORMAT ERROR"            ; $E23A
        !byte $00                       ; $E246
txt_E247
        !text "HARDWARE ERROR"          ; $E247
        !byte $00                       ; $E255
txt_E256
        !text "SELECTED PARTITION ILLEGAL" ; $E256
        !byte $00                       ; $E270
txt_E271
        !text "SYSTEM ERROR"            ; $E271
        !byte $00                       ; $E27D
txt_E27E
        !text "PARTITION SELECTED"      ; $E27E
        !byte $00                       ; $E290
txt_E291
        !text "SCSI ERROR"              ; $E291
        !byte $00                       ; $E29B
txt_E29C
        !text "STATUS ERROR"            ; $E29C
        !byte $00                       ; $E2A8
txt_E2A9
        !text "CONTROLLER ERROR"        ; $E2A9
        !byte $00                       ; $E2B9
txt_E2BA
        !text "ILLEGAL JOB"             ; $E2BA
        !byte $00                       ; $E2C5
txt_E2C6
        !text "DIRECTORY NOT FOUND"     ; $E2C6
        !byte $00                       ; $E2D9
loc_E2DA
        jmp loc_B654

sub_E2DD
        lda $46
        and #$04
        beq loc_E2DA
        ldy #$03
        jsr sub_B6B8
        beq loc_E2EC
        ldy #$04
loc_E2EC
        cpy #$04
        bcc loc_E2F1
        dey
loc_E2F1
        sty $2C00
        lda $56
        sta $2C01
        lda $0203
        cmp #$2A
        bne loc_E30E
        jsr sub_A2C7
        lda $2FC0,x
        beq loc_E30E
        ldy $2FD0,x
        jmp loc_E35B
loc_E30E
        jsr sub_B843
        bcs loc_E335
        jsr sub_AED0
        bne loc_E335
        lda #$01
        sta $2BEA
        sta $2BEB
        jsr sub_BECF
        lda $2C20
        beq loc_E338
        lda $2C18
        and #$03
        cmp #$02
        beq loc_E34B
        bit $4C
        bmi loc_E34B
loc_E335
        lda #$0F
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E338
        lda #$02
        pha
        jsr sub_E410
        pla
        cmp #$0F
        beq loc_E346
        lda #$62
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E346
        lda #$74
        jmp sub_B66F
loc_E34B
        jsr sub_A2C7
        lda $2C28
        tay
        sta $2FD0,x
        lda $2C20
        sta $2FC0,x
loc_E35B
        sta $5A
        sty $5B
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E362
        lda #$00
        sta $96
        ldx #$00
        lda #$AA
        jsr sub_E3A8
        jsr sub_97B9
        ldy #$01
        lda ($68),y
        sta $5B
        dey
        lda ($68),y
        sta $5A
        bne loc_E38C
        lda #$1F
        jsr jt_burst_send_byte
        ldx $5B
        dex
        txa
        sec
        sbc $96
        jmp loc_E390
loc_E38C
        ldx #$FE
        lda #$00
loc_E390
        jsr jt_burst_send_byte
        ldy #$02
loc_E395
        lda ($68),y
        jsr jt_burst_send_byte
        iny
        dex
        bne loc_E395
        jsr sub_979B
        lda $5A
        bne loc_E362
        jmp loc_B654

sub_E3A8
        pha
        txa
        jsr sub_D976
        pla
        jsr sub_E825
        cmp #$02
        bcs loc_E3B6
        rts
loc_E3B6
        pha
        lda #$02
        jsr sub_E410
        pla
        jmp sub_DF13

sub_E3C0
        sta $2BE1
        lda $6A
        bit $2BE8
        bpl loc_E3DB
        and #$80
        ora #$20
        ora $2BE1
        and $70
        ora $71
loc_E3D5
        sta $6A
        lda $2BE1
        rts
loc_E3DB
        and #$F0
        ora $2BE1
        jmp loc_E3D5

sub_E3E3
        jsr sub_E825
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_E3E7
        lda #$4F

sub_E3E9
        jsr sub_E3C0
        cmp #$02
        bcc sub_E401
        bit $4C
        bvs sub_E401
        jsr sub_E401
loc_E3F7
        lda $2BE1
        and #$0F
        ldx #$00
        jmp jt_job_error

sub_E401
        lda $6A
        bit $2BE8
        bvc sub_E410
        and #$0F
        bne loc_E40E
        lda #$01
loc_E40E
        ora $6A

sub_E410
        pha
        jsr sub_97B9
        pla
        jsr jt_burst_send_byte
        jmp sub_979B

sub_E41B
        pha
loc_E41C
        bit ppi_pb
        bmi loc_E43A
        lda via1_prb
        bmi loc_E43A
        and #$04
        cmp $6E
        beq loc_E41C
        sta $6E
        pla
        sta via1_sr
        lda #$04
loc_E434
        bit via1_ifr
        beq loc_E434
        rts
loc_E43A
        jmp jt_atn_service

sub_E43D
        bit via1_sr
        lda via1_prb
        eor #$08
        sta via1_prb
        lda #$04
loc_E44A
        bit ppi_pb
        bmi loc_E43A
        bit via1_prb
        bmi loc_E43A
        bit via1_ifr
        beq loc_E44A
        lda via1_sr
        rts

sub_E45D
        bit ppi_pb
        bmi loc_E43A
        lda via1_prb
        bmi loc_E43A
        and #$04
        cmp $6E
        beq sub_E45D
        sta $6E
        rts

sub_E470
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_E473
        ldx #$02
loc_E475
        ldy #$00
        jsr sub_97B9
loc_E47A
        lda ($68),y
        jsr jt_burst_send_byte
        iny
        bne loc_E47A
        dex
        beq loc_E48A
        inc $69
        jmp loc_E47A
loc_E48A
        jmp sub_979B

sub_E48D
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_E490
        ldx #$02
loc_E492
        ldy #$00
        jsr sub_979B
loc_E497
        jsr jt_burst_get_byte
        sta ($68),y
        iny
        bne loc_E497
        dex
        beq loc_E4A7
        inc $69
        jmp loc_E497
loc_E4A7
        jmp sub_976C

sub_E4AA
        jsr sub_E4BF

sub_E4AD
        lda $0203
        sta $5A
        lda $0204
        sta $5B

sub_E4B7
        lda #$00
        jsr sub_D976
        lda #$00
        rts

sub_E4BF
        lda $4C
        and #$10
        ldx #$00
        sta $2840,x
        rts

sub_E4C9
        bit $2BE8
        bmi loc_E4E9
loc_E4CE
        lda #$20
        bit $4C
        bne loc_E4E0
        jsr sub_E4AD
        lda #$80
        jsr sub_E3E3
        bit $4C
        bmi loc_E4E3
loc_E4E0
        jsr sub_E470
loc_E4E3
        jsr sub_E7E0
        jmp loc_E4CE
loc_E4E9
        bit $4C
        bmi loc_E4FE
loc_E4ED
        jsr sub_E4AA
        lda #$B2
        jsr sub_E3E3
        jsr sub_E473
        jsr sub_E7AD
        jmp loc_E4ED
loc_E4FE
        bit $71
        bmi loc_E513
loc_E502
        jsr sub_E4AD
        lda #$80
        jsr sub_E3E3
        jsr sub_E470
        jsr sub_E7AD
        jmp loc_E502
loc_E513
        lda #$8D
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_E516
        lda #$0B
loc_E518
        jmp sub_E3E9

sub_E51B
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_E51E
        lda #$4F
        sta $2BE1
        bit $2BE8
        bmi loc_E555
        bit $4C
        bmi loc_E537
loc_E52C
        lda #$00
        sta $68
        lda #$03
        sta $69
        jsr sub_E48D
loc_E537
        lda #$20
        bit $4C
        bne loc_E54F
        lda $2BE1
        cmp #$02
        bcs loc_E518
        jsr sub_E4AD
        lda #$90
        jsr sub_E3E3
        jsr sub_E45D
loc_E54F
        jsr sub_E7E0
        jmp loc_E52C
loc_E555
        bit $4C
        bmi loc_E577
loc_E559
        jsr sub_EE5F
        jsr sub_E490
        lda $2BE1
        cmp #$02
        bcs loc_E518
        jsr sub_E4AA
        lda #$B4
        jsr sub_E3E3
        jsr sub_E45D
        jsr sub_E7AD
        jmp loc_E559
loc_E577
        lda #$00
        sta $68
        lda #$03
        sta $69
        jsr sub_E48D
        lda $2BE1
        cmp #$02
        bcs loc_E518
        jsr sub_E4AD
        lda #$90
        jsr sub_E3E3
        jsr sub_E45D
        jsr sub_E7AD
        jmp loc_E577

sub_E59A
        lda $4C
        lsr
        bcc loc_E5A2
        jmp sub_E3E7
loc_E5A2
        lda #$00
        sta $6A
        ldx #$00
        lda #$C0
        jmp sub_E3E3

sub_E5AD
        lda #$20
        bit $4C
        bpl loc_E5B6
        jmp sub_E401
loc_E5B6
        beq loc_E5C2
        lda $0204
        sta $71
        lda $0205
        sta $70
loc_E5C2
        lda $0203
        sta $6A
        rts

sub_E5C8
        jsr sub_E59A
        bit $2BE8
        bmi loc_E5D1
        rts
loc_E5D1
        bit $4C
        bpl loc_E5E3
        jsr sub_E4AA
        lda #$01
        sta $2801
        lda #$A8
        jsr sub_E825
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E5E3
        lda #$00
        jsr sub_E3E9
        jsr sub_97B9
        lda #$0A
        jsr jt_burst_send_byte
        bit $4C
        bpl loc_E5F8
        lda $0203
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E5F8
        lda #$00
        jsr jt_burst_send_byte
        lda #$01
        jsr jt_burst_send_byte
        lda #$0A
        jsr jt_burst_send_byte
        lda #$01
        jsr jt_burst_send_byte
        lda $4C
        and #$20
        beq loc_E61D
        ldx #$01
loc_E614
        txa
        jsr jt_burst_send_byte
        inx
        cpx #$0B
        bcc loc_E614
loc_E61D
        rts

sub_E61E
        lda #$01
        bit $4C
        beq loc_E62C
        lda #$4F
        jsr sub_E3C0
        jmp loc_E3F7
loc_E62C
        bit $2BE8
        bmi loc_E63E
        bit $0203
        bmi loc_E63B
        lda #$01
        jmp sub_E3C0
loc_E63B
        jmp loc_E67E
loc_E63E
        bmi loc_E686
        ldx #$00
loc_E642
        lda txt_E65D,x
        sta $0200,x
        inx
        cpx #$0C
        bcc loc_E642
        stx $56
        ldx #$01
        stx $2C00
        lda #$0A
        sta $2C01
        dex
        jmp jt_cmd_new
txt_E65D
        !text "N0:CMD HD"               ; $E65D
txt_E666
        !text ",89"                     ; $E666
        !byte $02,$4F,$0A               ; $E669
dat_E66C
        !byte $00,$E5,$01               ; $E66C
        !byte $02,$00,$0A               ; $E66F
dat_E672
        !byte $00,$00,$01               ; $E672
        !byte $02,$4F,$0A,$4F,$00,$01   ; $E675

sub_E67B
        lda #$0E
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E67E
        lda #$06
        jsr sub_E3C0
        jmp loc_DF97
loc_E686
        ldx #$03
loc_E688
        cpx $56
        beq loc_E69E
        lda $0200,x
        cmp dat_E66C,x
        bcc sub_E67B
        cmp dat_E672,x
        bcc loc_E69B
        bne sub_E67B
loc_E69B
        inx
        bne loc_E688
loc_E69E
        cpx #$09
        bcs loc_E6AB
        lda txt_E666,x
        sta $0200,x
        inx
        bne loc_E69E
loc_E6AB
        ldx #$00
        lda $0207
loc_E6B0
        sta $5000,x
        sta $5100,x
        inx
        bne loc_E6B0
        lda $4C
        and #$EF
        sta $4C
loc_E6BF
        lda $0206
        sta $5A
        lda $0208
        sta $5B
        jsr sub_E4BF
        jsr sub_E4B7
        lda #$B4
        jsr sub_E825
        cmp #$02
        bcc loc_E6DB
        jmp loc_E67E
loc_E6DB
        inc $0208
        lda $0208
        cmp #$0B
        bcc loc_E6BF
        lda #$01
        sta $0208
        lda $4C
        eor #$10
        sta $4C
        and #$10
        bne loc_E6BF
        inc $0206
        lda $0206
        cmp $0204
        bcc loc_E6BF
        beq loc_E6BF
        lda #$00
        jmp sub_E3C0

sub_E706
        bit $2BE8
        bmi loc_E70C
        rts
loc_E70C
        lda #$00
        jmp sub_E3E9

sub_E711
        sei
        ldx $0204
        lda $56
        cmp #$04
        bcs loc_E71E
loc_E71B
        jmp loc_DF97
loc_E71E
        lda $0203
        cmp #$42
        bne loc_E73F
        txa
        cmp #$30
        beq loc_E72E
        cmp #$31
        bne loc_E71B
loc_E72E
        pha
        lda $46
        and #$FB
        sta $46
        pla
        and #$01
        asl
        asl
        ora $46
        sta $46
        rts
loc_E73F
        cmp #$53
        bne loc_E746
        stx $57
        rts
loc_E746
        cmp #$52
        bne loc_E74D
        stx $61
        rts
loc_E74D
        cmp #$54
        beq loc_E759
        cmp #$56
        beq loc_E759
        cmp #$4D
        bne loc_E75A
loc_E759
        rts
loc_E75A
        cmp #$4D
        beq loc_E76F
        cmp #$04
        bcc loc_E71B
        cmp #$1F
        bcs loc_E71B
        ora #$40
        sta $78
        eor #$60
        sta $77
        rts
loc_E76F
        lda #$00
        sta $6E
        sta $68
        lda $0205
        sta $69
        cpx #$57
        beq loc_E788
        cpx #$52
        bne loc_E71B
        ldx $0206
        jmp loc_E475
loc_E788
        ldx $0206
        jmp loc_E492

sub_E78E
        bit $2BE8
        bvs loc_E796
loc_E793
        jmp sub_E67B
loc_E796
        bit $4C
        bmi loc_E7A7
        lda $56
        cmp #$04
        bcc loc_E793
        lda $0203
        sta $2BE9
        rts
loc_E7A7
        lda $2BE9
        jmp sub_E410

sub_E7AD
        dec $0205
        bne loc_E7B5
        pla
        pla
        rts
loc_E7B5
        inc $0204
        lda $0204
        bit $4C
        bpl loc_E7CC
        cmp #$28
        bcc loc_E7CB
        lda #$00
        sta $0204
loc_E7C8
        inc $0203
loc_E7CB
        rts
loc_E7CC
        cmp #$0B
        bcc loc_E7CB
        lda #$01
        sta $0204
        lda $4C
        eor #$10
        sta $4C
        and #$10
        beq loc_E7C8
        rts

sub_E7E0
        dec $0205
        bne loc_E7E8
        pla
        pla
        rts
loc_E7E8
        bit $2BE8
        bvc loc_E80E
        ldx #$00
        lda $0203
loc_E7F2
        cmp dat_EAC3,x
        bcc loc_E7FA
        inx
        bne loc_E7F2
loc_E7FA
        dex
        lda $0204
        clc
        adc $2BE9
        cmp dat_EADC,x
        bcc loc_E80A
        sbc dat_EADC,x
loc_E80A
        sta $0204
        rts
loc_E80E
        inc $0204
        bne loc_E81B
        inc $0203
        bne loc_E81B
        inc $0203
loc_E81B
        rts

sub_E81C
        jsr sub_E825
        bcs loc_E822
        rts
loc_E822
        jmp jt_job_error

sub_E825
        php
        sei
        cpx #$20
        bcc loc_E831
        lda #$0E
        plp
        cmp #$02
        rts
loc_E831
        sta $20,x
        sta $2960,x
        lda $2A61
        and #$3F
        sta $2A62
loc_E83E
        tya
        pha
        txa
        pha
        jsr sub_E860
        pla
        tax
        pla
        tay
        lda $20,x
        cmp #$02
        bcs loc_E853
loc_E84F
        plp
        cmp #$02
        rts
loc_E853
        dec $2A62
        bmi loc_E84F
        lda $2960,x
        sta $20,x
        jmp loc_E83E

sub_E860
        php
        sei
        jsr sub_E88C
        ldx #$00
loc_E867
        lda $20,x
        bpl loc_E882
        sta $2A56
        stx $2A57
        lsr
        lda #$C2
        bcs loc_E879
        jsr sub_E924
loc_E879
        jsr sub_EC14
        jsr sub_E8DF
        ldx $2A57
loc_E882
        inx
        cpx #$20
        bcc loc_E867
        jsr sub_E8FB
        plp
        rts

sub_E88C
        jsr sub_B07E
        ldx #$00
        cmp #$01
        beq loc_E8D3
        cmp #$04
        bcc loc_E8B9
        cmp #$06
        bcs loc_E8D3
loc_E89D
        lda $02,x
        bpl loc_E8B2
        sta $20,x
        txa
        asl
        tay
        lda $000B,y
        sta $2800,y
        lda $000C,y
        sta $2801,y
loc_E8B2
        inx
        cpx #$0B
        bcc loc_E89D
        bcs loc_E8D3
loc_E8B9
        lda $00,x
        bpl loc_E8CE
        sta $20,x
        txa
        asl
        tay
        lda $0006,y
        sta $2800,y
        lda $0007,y
        sta $2801,y
loc_E8CE
        inx
        cpx #$05
        bcc loc_E8B9
loc_E8D3
        ldx #$0A
loc_E8D5
        lda $00,x
        and #$7F
        sta $00,x
        dex
        bpl loc_E8D5
        rts

sub_E8DF
        jsr sub_B07E
        ldx $2A57
        cmp #$01
        beq loc_E8FA
        cmp #$04
        bcc loc_E8F6
        cmp #$06
        bcs loc_E8FA
        lda $20,x
        sta $02,x
        rts
loc_E8F6
        lda $20,x
        sta $00,x
loc_E8FA
        rts

sub_E8FB
        lda #$02
        and $49
        beq loc_E915
        dec $2A60
        bne loc_E913
        lda #$19
        sta $2A60
        lda ctl_latch
        eor #$02
        sta ctl_latch
loc_E913
        lda #$02
loc_E915
        ora #$20
        and ctl_latch
        eor $49
        eor #$DF
        and #$EF
        sta ctl_latch
        rts

sub_E924
        ldx #$2A
        lda $2A56
loc_E929
        cmp dat_E944,x
        beq loc_E934
        dex
        bpl loc_E929
        lda #$C1
        rts
loc_E934
        txa
        asl
        tax
        lda tbl_E96F,x
        sta $E8
        lda tbl_E96F+1,x
        sta $E9
        jmp ($00E8)
dat_E944
        !byte $80,$90,$A0,$B0,$C0,$D0,$E0,$F0 ; $E944
        !byte $82,$84,$86,$88,$8A,$8C,$8E,$92 ; $E94C
        !byte $94,$96,$98,$9A,$9C,$9E,$A2,$A4 ; $E954
        !byte $A6,$A8,$AA,$AC,$B2,$B4,$B6,$B8 ; $E95C
        !byte $CC,$CE,$EC,$EE,$F2,$F4,$F6,$F8 ; $E964
        !byte $FA,$FC,$FE               ; $E96C
tbl_E96F
        !word sub_ED05                  ; $E96F
        !word sub_ED23                  ; $E971
        !word sub_ED43                  ; $E973
        !word sub_ED20                  ; $E975
        !word sub_ED68                  ; $E977
        !word sub_ED79                  ; $E979
        !word sub_ED79                  ; $E97B
        !word sub_ED7F                  ; $E97D
        !word sub_EC74                  ; $E97F
        !word sub_ED20                  ; $E981
        !word sub_ED20                  ; $E983
        !word sub_ED20                  ; $E985
        !word sub_ED20                  ; $E987
        !word sub_ED20                  ; $E989
        !word sub_ED20                  ; $E98B
        !word sub_ED20                  ; $E98D
        !word sub_EE3C                  ; $E98F
        !word sub_EE4D                  ; $E991
        !word sub_EE2C                  ; $E993
        !word sub_EE42                  ; $E995
        !word sub_ED20                  ; $E997
        !word sub_ED20                  ; $E999
        !word sub_ED20                  ; $E99B
        !word sub_ED85                  ; $E99D
        !word sub_ED9E                  ; $E99F
        !word sub_ED5C                  ; $E9A1
        !word sub_ECC2                  ; $E9A3
        !word sub_ECD9                  ; $E9A5
        !word sub_EDF9                  ; $E9A7
        !word sub_EE02                  ; $E9A9
        !word sub_EE56                  ; $E9AB
        !word sub_ED4B                  ; $E9AD
        !word sub_EC9E                  ; $E9AF
        !word sub_ECA9                  ; $E9B1
        !word sub_EDA4                  ; $E9B3
        !word sub_EDA1                  ; $E9B5
        !word sub_F136                  ; $E9B7
        !word sub_EF74                  ; $E9B9
        !word sub_EF71                  ; $E9BB
        !word sub_EE14                  ; $E9BD
        !word sub_EE17                  ; $E9BF
        !word sub_EDAC                  ; $E9C1
        !word sub_EDA9                  ; $E9C3

sub_E9C5
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
sub_E9C7
        clc
        ror $2A5C
        jsr sub_EA7B

sub_E9CE
        jsr sub_EA70
        jsr sub_EA93
        bcc sub_E9DA
loc_E9D6
        lda #$C0
        sec
        rts

sub_E9DA
        ldy $2A5E
        lda $2A5A
        cmp part_size_hi,y
        bcc loc_E9EF
        bne loc_E9D6
        lda $2A5B
        cmp part_size_lo,y
        bcs loc_E9D6
loc_E9EF
        clc
        lda $2A5B
        adc part_start_lo,y
        sta $2A65
        lda $2A5A
        adc part_start_mid,y
        sta $2A64
        lda #$00
        adc part_start_hi,y
        sta $2A63

sub_EA0A
        ldy #$FF
loc_EA0C
        iny
        lda $2A63
        cmp $9038,y
        bcc loc_EA29
        bne loc_EA0C
        lda $2A64
        cmp $9070,y
        bcc loc_EA29
        bne loc_EA0C
        lda $2A65
        cmp $90A8,y
        bcs loc_EA0C
loc_EA29
        dey
        lda $9000,y
        bmi loc_E9D6
        ldx $2A57
        jsr sub_EA5F
        sec
        lda $2A65
        sbc $90A8,y
        sta $2940,x
        lda $2A64
        sbc $9070,y
        sta $2920,x
        lda $2A63
        sbc $9038,y
        sta $2900,x

sub_EA51
        lda #$00
        sta $66
        lda $2A57
        clc
        adc #$03
        sta $67
        clc
loc_EA5E
        rts

sub_EA5F
        pha
        and #$07
        sta $28E0,x
        pla
        lsr
        lsr
        lsr
        lsr
        and #$07
        sta $28C0,x
        rts

sub_EA70
        ldx $2A57
        lda $90E8
        sta $2A5E
        tay
        rts

sub_EA7B
        lda $2A57
        asl
        tax
        lda $2800,x
        sta $2A58
        lda $2801,x
        sta $2A59
        lda $2840,x
        sta $2A5F
        rts

sub_EA93
        ldy $2A5E
        lda part_type,y
        beq loc_EA5E
        cmp #$FF
        bne loc_EAA1
        lda #$00
loc_EAA1
        asl
        tax
        lda tbl_EAB3,x
        sta $E8
        lda tbl_EAB3+1,x
        sta $E9
        bit $2A5C
        jmp ($00E8)
tbl_EAB3
        !word sub_EAE4                  ; $EAB3
        !word sub_EAFD                  ; $EAB5
        !word sub_EB09                  ; $EAB7
        !word sub_EB16                  ; $EAB9
        !word sub_EB79                  ; $EABB
        !word sub_EB58                  ; $EABD
        !word sub_EAE4                  ; $EABF
        !word sub_EAE4                  ; $EAC1
dat_EAC3
        !byte $01,$12,$19,$1F,$24,$35,$3C,$42 ; $EAC3
        !byte $47                       ; $EACB
dat_EACC
        !byte $00,$01,$01,$02,$02,$04,$04,$05 ; $EACC
dat_EAD4
        !byte $00,$65,$EA,$56,$AB,$10,$95,$01 ; $EAD4
dat_EADC
        !byte $15,$13,$12,$11,$15,$13,$12,$11 ; $EADC

sub_EAE4
        bmi loc_EAEF
        lda $2A58
loc_EAE9
        jsr sub_EAF2
        jmp loc_EB94
loc_EAEF
        lda $2A58

sub_EAF2
        sta $2A5A
        lda $2A59
        sta $2A5B
        clc
        rts

sub_EAFD
        bmi loc_EAEF
        ldx $2A58
        beq loc_EB14
        dex
        txa
        jmp loc_EAE9

sub_EB09
        bmi loc_EB14
        lda $2A58
        beq loc_EB14
        cmp #$24
        bcc loc_EB21
loc_EB14
        sec
        rts

sub_EB16
        bmi loc_EB14
        lda $2A58
        beq loc_EB14
        cmp #$47
        bcs loc_EB14
loc_EB21
        ldx #$00
loc_EB23
        cmp dat_EAC3,x
        bcc loc_EB2B
        inx
        bne loc_EB23
loc_EB2B
        dex
        lda dat_EADC,x
        cmp $2A59
        beq loc_EB14
        bcc loc_EB14
        sta $2A66
        txa
        pha
        lda $2A58
        sec
        sbc dat_EAC3,x
        jsr sub_EBFD
        pla
        tay
        ldx dat_EACC,y
        lda dat_EAD4,y
        ldy #$00
        jsr sub_EBE5
        lda $2A59
        jmp loc_EB91

sub_EB58
        bmi loc_EBA1
        lda $2A56
        cmp #$80
        bne loc_EB7B
        lda $2A58
        cmp #$01
        bne loc_EB7B
        lda $2A59
        bne loc_EB7B
        lda #$28
        sta $2A58
        lda #$05
        sta $2A59
        bne loc_EB7B

sub_EB79
        bmi loc_EBA1
loc_EB7B
        lda #$28
        sta $2A66
        ldx $2A58
        beq loc_EB9F
        dex
        txa
        jsr sub_EBFD
        lda $2A59
        cmp #$28
        bcs loc_EB9F
loc_EB91
        jsr sub_EBC4
loc_EB94
        lsr $2A5A
        ror $2A5B
        ror $2A5D
        clc
        rts
loc_EB9F
        sec
        rts
loc_EBA1
        lda $2A58
        cmp #$50
        bcs loc_EB9F
        lda #$14
        sta $2A66
        lda $2A58
        jsr sub_EBFD
        ldx $2A59
        dex
        txa
        cmp #$0A
        bcs loc_EB9F
        ldx $2A5F
        beq sub_EBC4
        clc
        adc #$0A

sub_EBC4
        jsr sub_EBE1
        lda $2A65
        sta $2A5B
        lda $2A64
        sta $2A5A
        clc
        rts

sub_EBD5
        lda #$00
        sta $2A65
        sta $2A64
        sta $2A63
        rts

sub_EBE1
        ldx #$00
        ldy #$00

sub_EBE5
        clc
        pha
        adc $2A65
        sta $2A65
        txa
        adc $2A64
        sta $2A64
        tya
        adc $2A63
        sta $2A63
loc_EBFB
        pla
        rts

sub_EBFD
        ldx #$00
        ldy #$00
        pha
        jsr sub_EBD5
        lda $2A66
        beq loc_EBFB
        pla
loc_EC0B
        jsr sub_EBE5
        dec $2A66
        bne loc_EC0B
        rts

sub_EC14
        cmp #$02
        bne loc_EC2D
        jsr sub_EFB7
        cmp #$00
        bne loc_EC2D
        lda $2A13
        and #$0F
        cmp #$01
        beq loc_EC2B
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_EC2B
        lda #$00
loc_EC2D
        ldx #$00
loc_EC2F
        cmp dat_EC5E,x
        beq loc_EC3D
        inx
        cpx #$0B
        bcc loc_EC2F
        lda #$0D
        bne loc_EC40
loc_EC3D
        lda dat_EC69,x
loc_EC40
        ldx $2A57
        cmp #$00
        beq loc_EC5B
        pha
        lda $2A11
        sta $2900,x
        lda $2A13
        sta $2920,x
        lda $2A1D
        sta $2940,x
        pla
loc_EC5B
        sta $20,x
        rts
dat_EC5E
        !byte $00,$02,$08,$10,$18,$85,$86,$87 ; $EC5E
        !byte $C0,$C1,$C3               ; $EC66
dat_EC69
        !byte $00,$02,$03,$0B,$0C,$05,$06,$07 ; $EC69
        !byte $04,$0E,$08               ; $EC71

sub_EC74
        lda #$20
        sta $8006
        lda #$4E
        sta $8007
        sta $8005
        lda via1_acr
        ora #$40
        sta via1_acr
        lda #$FF
        sta $2A50
        lda #$19
        sta $2A60
        lda #$01
        sta $2A61
        jsr sub_F1BB
        lda #$00
        rts

sub_EC9E
        jsr sub_E9C7
        bcs loc_ECD8
        jsr sub_ECB4
        jmp loc_ED0A

sub_ECA9
        jsr sub_E9C7
        bcs loc_ECD8
        jsr sub_ECB4
        jmp sub_ED28

sub_ECB4
        ldx $2A57
        lda $2880,x
        sta $66
        lda $2860,x
        sta $67
        rts

sub_ECC2
        jsr sub_E9C7
        bcs loc_ECD8
        jsr sub_EE78
        beq loc_ECD3

sub_ECCC
        lda #$28
loc_ECCE
        jsr sub_EF0A
        bne loc_ECD8
loc_ECD3
        jsr sub_EE68
        lda #$00
loc_ECD8
        rts

sub_ECD9
        jsr sub_E9C7
        bcs loc_ECD8
        jsr sub_EE68
        jsr sub_EE78
        beq loc_ED01
        ldy #$00
loc_ECE8
        lda ($68),y
        sta $5200,y
        iny
        bne loc_ECE8
        jsr sub_ECCC
        cmp #$00
        bne loc_ECD8
        ldy #$00
loc_ECF9
        lda $5200,y
        sta ($68),y
        iny
        bne loc_ECF9
loc_ED01
        lda #$2A
        bne loc_ECCE

sub_ED05
        jsr sub_E9C7
        bcs loc_ED22
loc_ED0A
        jsr sub_EE78
        beq loc_ED16
        lda #$28
        jsr sub_EF0A
        bne loc_ED22
loc_ED16
        jsr sub_EE68
loc_ED19
        lda ($68),y
        sta ($66),y
        iny
        bne loc_ED19

sub_ED20
        lda #$00
loc_ED22
        rts

sub_ED23
        jsr sub_E9C7
        bcs loc_ED4A

sub_ED28
        jsr sub_EE78
        beq sub_ED34
        lda #$28
        jsr sub_EF0A
        bne loc_ED4A

sub_ED34
        jsr sub_EE68
loc_ED37
        lda ($66),y
        sta ($68),y
        iny
        bne loc_ED37
        lda #$2A
        jmp sub_EF0A

sub_ED43
        jsr sub_E9C7
        bcs loc_ED4A
        lda #$00
loc_ED4A
        rts

sub_ED4B
        jsr sub_EA7B
        lda #$00
        sta $2A59
        lsr $2A5C
        jsr sub_E9CE
        bcc loc_ED61
loc_ED5B
        rts

sub_ED5C
        jsr sub_E9C5
        bcs loc_ED5B
loc_ED61
        lda #$2B
        ldy #$00
        jmp sub_EF3C

sub_ED68
        jsr sub_EA70
        lda #$00
        sta $2A5A
        sta $2A5B
        jsr sub_E9DA
        bcc loc_ED61
        rts

sub_ED79
        jsr sub_EA51
        jmp ($0066)

sub_ED7F
        jsr sub_EA51
        lda #$00
        rts

sub_ED85
        jsr sub_ED8B
        jmp sub_EDAC

sub_ED8B
        ldx $2A57
        lda #$03
        sta $2860,x
        lda #$00
        sta $2880,x
        lda #$01
        sta $28A0,x
        rts

sub_ED9E
        jsr sub_ED8B

sub_EDA1
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EDA4
        ldy #$28
        sec
        bcs loc_EDAF

sub_EDA9
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EDAC
        ldy #$28
        clc
loc_EDAF
        ldx $2A57
        lda $2860,x
        pha
        lda $2880,x
        pha
        tya
        pha
        lda $28A0,x
        pha
        bcc loc_EDDD
        lda $2840,x
        sta $2A65
        txa
        asl
        tax
        lda $2801,x
        sta $2A64
        lda $2800,x
        sta $2A63
        jsr sub_EA0A
        jmp loc_EDE0
loc_EDDD
        jsr sub_E9C5
loc_EDE0
        bcc loc_EDE9
        pla
        pla
        pla
        pla
        lda #$C0
        rts
loc_EDE9
        pla
        tay
        pla
        sec
        jsr sub_EF42
        pla
        sta $68
        pla
        sta $69
        jmp loc_EF81

sub_EDF9
        jsr sub_E9C5
        bcs loc_EE13
        lda #$28
        bne loc_EE09

sub_EE02
        jsr sub_E9C5
        bcs loc_EE13
        lda #$2A
loc_EE09
        jsr sub_EF0A
        bne loc_EE13
        jsr sub_EE5F
        lda #$00
loc_EE13
        rts

sub_EE14
        ldy #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EE17
        ldy #$00
        lda #$00
        ldx $2A57
        sta $2900,x
        sta $2920,x
        sta $2940,x
        lda #$1B
        jmp loc_EF7D

sub_EE2C
        lda #$50
        sta $2BDE
        lda #$32
        sta $2A60
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_EE39
        lda #$40
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EE3C
        lda #$01
        ora $49
        bne loc_EE51

sub_EE42
        lda #$00
        sta $2BDE
        lda #$FD
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_EE4A
        lda #$BF
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EE4D
        lda #$FE
        and $49
loc_EE51
        sta $49
loc_EE53
        lda #$00
        rts

sub_EE56
        lda #$80
        and $49
        beq loc_EE53
        lda #$C3
        rts

sub_EE5F
        ldy #$00
        sty $68
        lda #$50
        sta $69
        rts

sub_EE68
        ldy #$00
        sty $68
        lda #$50
        sta $69
        bit $2A5D
        bpl loc_EE77
        inc $69
loc_EE77
        rts

sub_EE78
        ldx $2A57
        lda $28C0,x
        cmp $2A50
        bne loc_EEA1
        lda $28E0,x
        cmp $2A51
        bne loc_EEA1
        lda $2900,x
        cmp $2A52
        bne loc_EEA1
        lda $2920,x
        cmp $2A53
        bne loc_EEA1
        lda $2940,x
        cmp $2A54
loc_EEA1
        rts

sub_EEA2
        php
        pha
        jsr sub_EED7
        pla
        sta $2A00
        lda #$00
        ldx $2A57
        sty $2A04
        plp
        bcc loc_EEC5
        lda $2940,x
        sta $2A03
        lda $2920,x
        sta $2A02
        lda $2900,x
loc_EEC5
        sta $2A01
        lda $28E0,x
        asl
        asl
        asl
        asl
        asl
        ora $2A01
        sta $2A01
        rts

sub_EED7
        lda #$00
        ldx #$4F
loc_EEDB
        sta $2A00,x
        dex
        bpl loc_EEDB

sub_EEE1
        ldx #$FF
        stx $2A10
        stx $2A30
        lda #$00
        sta $E0
        lda #$2A
        sta $E1
        lda #$10
        sta $E2
        lda #$2A
        sta $E3
        lda #$30
        sta $E4
        lda #$2A
        sta $E5
        lda #$00
        sta $68
        lda #$50
        sta $69
        rts

sub_EF0A
        ldx #$FF
        stx $2A50
        ldy #$01
        jsr sub_EF3C
        bne loc_EF39

sub_EF16
        ldx $2A57
        lda $28C0,x
        sta $2A50
        lda $28E0,x
        sta $2A51
        lda $2900,x
        sta $2A52
        lda $2920,x
        sta $2A53
        lda $2940,x
        sta $2A54
        lda #$00
loc_EF39
        jmp loc_EFB1

sub_EF3C
        jsr sub_EF42
        jmp loc_EF81

sub_EF42
        pha
        jsr sub_EED7
        pla
        ldx $2A57
        sta $2A00
        sty $2A08
        lda $2940,x
        sta $2A05
        lda $2920,x
        sta $2A04
        lda $2900,x
        sta $2A03
        lda $28E0,x
        asl
        asl
        asl
        asl
        asl
        ora $2A01
        sta $2A01
        rts

sub_EF71
        lda #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sub_EF74
        lda #$00
        ldy #$00
        clc
        bcc loc_EF7E
        ldy #$01
loc_EF7D
        sec
loc_EF7E
        jsr sub_EEA2
loc_EF81
        lda $2A00
        cmp #$0A
        beq loc_EF8C
        cmp #$2A
        bne loc_EF97
loc_EF8C
        lda #$80
        and $49
        beq loc_EF97
        lda #$C3
        jmp loc_EFB1
loc_EF97
        ldx $2A57
        lda $28C0,x
        jsr sub_F14E
        bne sub_EFA7
        lda #$85
        jmp loc_EFB1

sub_EFA7
        jsr sub_EFD2
        cmp #$00
        bne loc_EFB1
        lda $2A10
loc_EFB1
        sta $2A10
        cmp #$00
        rts

sub_EFB7
        lda #$03
        ldy #$1B
        clc
        jsr sub_EEA2
        lda #$11
        sta $68
        lda #$2A
        sta $69
        jmp loc_EF81
loc_EFCA
        lda ctl_latch
        and #$EF
        sta ctl_latch

sub_EFD2
        lda #$20
loc_EFD4
        bit via2_prb
        bvs loc_EFD4
        bmi loc_EFE3
        bne loc_EFD4
        jsr sub_F116
        lda #$00
        rts
loc_EFE3
        beq loc_F010
        lda via2_prb
        and #$07
        cmp #$00
        bne loc_EFF1
        jmp loc_F018
loc_EFF1
        cmp #$04
        bne loc_EFF8
        jmp loc_F04F
loc_EFF8
        cmp #$01
        bne loc_EFFF
        jmp loc_F073
loc_EFFF
        cmp #$05
        bne loc_F006
        jmp loc_F0B4
loc_F006
        cmp #$07
        bne loc_F00D
        jmp loc_F0E5
loc_F00D
        lda #$87
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_F010
        lda #$86
        pha
        jsr sub_F136
        pla
        rts
loc_F018
        ldy $68
        lda #$00
        sta $68
        lda #$FF
        sta via2_ddra
        lda #$A0
        sta via2_prb
loc_F028
        lda via2_prb
        cmp #$A0
        bne loc_F04A
        lda ($68),y
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora $9300,x
        sta ctl_latch
        stx via2_pra
        iny
        bne loc_F028
        inc $69
        jmp loc_F028
loc_F04A
        sty $68
        jmp loc_EFCA
loc_F04F
        ldy $68
        lda #$00
        sta $68
        sta via2_ddra
        lda #$AC
        sta via2_prb
loc_F05D
        lda via2_prb
        cmp #$AC
        bne loc_F04A
        lda via2_pra
        eor #$FF
        sta ($68),y
        iny
        bne loc_F05D
        inc $69
        jmp loc_F05D
loc_F073
        ora #$20
        ldy #$FF
        sty via2_ddra
        iny
        sta via2_prb
        sta $2A55
loc_F081
        bit via2_prb
        bvs loc_F081
        lda $2A55
loc_F089
        cmp via2_prb
        beq loc_F089
        ora #$80
        cmp via2_prb
        bne loc_F0B1
        lda ($E0),y
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora $9300,x
        sta ctl_latch
        stx via2_pra
        inc $E0
        bne loc_F081
        inc $E1
        jmp loc_F081
loc_F0B1
        jmp loc_EFCA
loc_F0B4
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta $2A55
loc_F0C1
        bit via2_prb
        bvs loc_F0C1
        lda $2A55
loc_F0C9
        cmp via2_prb
        beq loc_F0C9
        ora #$80
        cmp via2_prb
        bne loc_F0B1
        lda via2_pra
        eor #$FF
        sta ($E2),y
        inc $E2
        bne loc_F0C1
        inc $E3
        jmp loc_F0C1
loc_F0E5
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta $2A55
loc_F0F2
        bit via2_prb
        bvs loc_F0F2
        lda $2A55
loc_F0FA
        cmp via2_prb
        beq loc_F0FA
        ora #$80
        cmp via2_prb
        bne loc_F0B1
        lda via2_pra
        eor #$FF
        sta ($E4),y
        inc $E4
        bne loc_F0F2
        inc $E5
        jmp loc_F0F2

sub_F116
        lda #$DB
        sta via2_pcr
        lda #$00
        sta via2_ddra
        lda #$08
        sta via2_prb
        lda ppi_pc
        and #$E3
        sta ppi_pc
        lda ctl_latch
        and #$EF
        sta ctl_latch
        rts

sub_F136
        jsr sub_F116
        lda ppi_pc
        ora #$08
        sta ppi_pc
        ldx #$28
loc_F143
        dex
        bne loc_F143
        and #$F7
        sta ppi_pc
        lda #$00
        rts

sub_F14E
        php
        sei
        tax
loc_F151
        lda #$20
        and via2_prb
        beq loc_F15A
        bne loc_F151
loc_F15A
        sec
loc_F15B
        rol
        dex
        bpl loc_F15B
        ldx #$FF
        stx via2_ddra
        ora $90E5
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora $9300,x
        sta ctl_latch
        stx via2_pra
        lda #$00
        sta via2_prb
        lda #$FB
        ldx #$10
        sta via2_pcr
        stx via2_prb
        ldx #$00
        ldy #$00
loc_F18B
        lda via2_prb
        and #$20
        bne loc_F1A7
        dex
        bne loc_F18B
        dey
        bne loc_F18B
        lda #$DB
        sta via2_pcr
        ldx #$54
loc_F19F
        dex
        bne loc_F19F
        lda via2_prb
        and #$20
loc_F1A7
        ldx #$08
        stx via2_prb
        ldx #$DB
        stx via2_pcr
        plp
        tax
        bne loc_F1BA
        jsr sub_F116
        ldx #$00
loc_F1BA
        rts

sub_F1BB
        php
        sei
        jsr sub_F74F
        ldx #$00
loc_F1C2
        txa
        sta $2A65
        lsr
        lsr
        lsr
        lsr
        eor $2A65
        and #$0F
        tay
        lda dat_F1DE,y
        sta $9300,x
        inx
        bne loc_F1C2
        jsr sub_F746
        plp
        rts
dat_F1DE
        !byte $10,$00,$00,$10,$00,$10,$10,$00 ; $F1DE
        !byte $00,$10,$10,$00,$10,$00,$00,$10 ; $F1E6

sub_F1EE
        ora #$20

sub_F1F0
        pha
        sei
        jsr sub_975A
        lda #$00
        sta via1_prb
        lda #$7A
        sta via1_ddrb
        pla

sub_F200
        sei
        pha
        jsr sub_9775
        jsr sub_975A
        jsr sub_F2C5
        lda #$00
        sta $2BD5
        pla

sub_F211
        sei
        sta $2BD4
        jsr sub_975A
        lda via1_prb
        and #$01
        beq loc_F268
        jsr sub_976C
        bit $2BD5
        bpl loc_F22D
        jsr sub_F441
        jsr sub_F43A
loc_F22D
        jsr sub_F441
        txa
        pha
        jsr sub_9775
        ldx #$08
loc_F237
        lda #$14
loc_F239
        sbc #$01
        bne loc_F239
        ror $2BD4
        bcs loc_F248
        jsr sub_9763
        jmp loc_F24B
loc_F248
        jsr sub_975A
loc_F24B
        jsr sub_976C
        lda #$14
loc_F250
        sbc #$01
        bne loc_F250
        lda via1_prb
        and #$FD
        ora #$08
        sta via1_prb
        dex
        bne loc_F237
        jsr sub_F43A
        pla
        tax
        clc
        rts
loc_F268
        jsr sub_F272
        sec
        rts
loc_F26D
        lda #$3F
        jsr sub_F1F0

sub_F272
        jsr sub_F288
        lda #$14
loc_F277
        sbc #$01
        bne loc_F277
        jsr sub_976C
        jsr sub_975A
        clc
        rts

sub_F283
        lda #$6F
        jsr sub_F200

sub_F288
        lda via1_prb
        ora #$50
        sta via1_prb
        lda #$3A
        sta via1_ddrb
loc_F295
        rts

sub_F296
        jsr sub_F1EE
        bcs loc_F295
        jsr sub_F283
        bcs loc_F295
        ldx #$00
loc_F2A2
        lda dat_F2BF,x
        jsr sub_F211
        inx
        cpx #$06
        bcc loc_F2A2
        lda $77
        jsr sub_F211
        lda #$80
        sta $2BD5
        lda $78
        jsr sub_F211
        jmp loc_F26D
dat_F2BF
        !byte $4D,$2D,$57,$77,$00,$02   ; $F2BF

sub_F2C5
        txa
        ldx #$00
loc_F2C8
        dex
        bne loc_F2C8
        ldx #$90
loc_F2CD
        dex
        bne loc_F2CD
        tax
        rts

sub_F2D2
        lda $90E4
        bpl loc_F2F0
        and #$7F
        sec
        sbc $2BE6
        bne loc_F2E2
        sta $2BE6
loc_F2E2
        lda $49
        and #$FB
        and #$F7
        sta $49
        lda $90E1
        jsr sub_F305
loc_F2F0
        ldx $2BE6
        beq loc_F317
        cpx #$08
        bne loc_F2FC
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_F2FC
        lda #$08
        ora $49
        sta $49
        txa
        ora #$80

sub_F305
        jsr sub_F795
        and #$7F
        pha
        jsr sub_F296
        pla
        ora #$20
        sta $77
        eor #$60
        sta $78
loc_F317
        rts

sub_F318
        php
        sei
        lda #$08
        and ppi_pb
        bne loc_F334
        jsr sub_F427
        bcs loc_F376
        lda #$80
        eor $49
        sta $49
        lda #$00
        sta $2BF9
        jmp loc_F365
loc_F334
        bit $2BE7
        bmi loc_F35D
        lda $2BE6
        beq loc_F347
        ora #$80
        cmp $90E4
        beq loc_F365
        bne loc_F35D
loc_F347
        lda #$02
        and ppi_pb
        beq loc_F358
        lda #$04
        and ppi_pb
        bne loc_F36C
        lda #$09
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_F358
        lda #$08
        sta $2BE6
loc_F35D
        jsr sub_F448
        bne loc_F365
        jsr sub_F2D2
loc_F365
        cli
        jsr sub_F465
        jsr sub_F45C
loc_F36C
        lda #$00
        sta $2BE7
        sta $2BE6
        plp
        rts
loc_F376
        lda $49
        bit dat_F388+1
        bne loc_F365
        pha
        lda #$00
        sta $50
        sta $51
        sta $52
        sta $53
dat_F388
        lda #$01
        sta $49
        cli
        pha
loc_F38E
        jsr sub_F465
loc_F391
        pla
        sta $49
loc_F394
        ldx #$FA
loc_F396
        lda ppi_pb
        and #$0E
        eor #$0E
        bne loc_F3AE
        jsr sub_F2C5
        dex
        bne loc_F396
        lda $49
        eor #$01
        sta $49
        jmp loc_F394
loc_F3AE
        ldx #$01
        stx $49
        pha
        jsr sub_F427
        pla
        bcs loc_F3EA
        lsr
        cmp #$04
        bcc loc_F3C0
        lda #$03
loc_F3C0
        tax
        cpx $53
        stx $53
        bne loc_F3C9
        inc $4F,x
loc_F3C9
        lda $4F,x
        cmp dat_F423,x
        bcs loc_F3D5
        jsr sub_F3FC
        bcc loc_F3D9
loc_F3D5
        lda #$00
        sta $4F,x
loc_F3D9
        ldy $4F,x
        lda dat_F41A,y
        ora #$01
        pha
        cpx #$03
        bne loc_F38E
        jsr sub_F468
        beq loc_F391
loc_F3EA
        pla
        sta $49
        jsr sub_F465
        plp
        jsr sub_F3FC
        bne loc_F3F9
        lda $90E3
loc_F3F9
        jmp loc_B95E

sub_F3FC
        lda #$00
        clc
        ldy $50
loc_F401
        dey
        bmi loc_F408
        adc #$64
        bne loc_F401
loc_F408
        ldy $51
loc_F40A
        dey
        bmi loc_F413
        adc #$0A
        bcs loc_F419
        bcc loc_F40A
loc_F413
        adc $52
        bcs loc_F419
        cmp #$FF
loc_F419
        rts
dat_F41A
        !byte $00,$80,$08,$88,$04,$84,$0C,$8C ; $F41A
        !byte $40                       ; $F422
dat_F423
        !byte $C0                       ; $F423
        !byte $03,$0A,$0A               ; $F424

sub_F427
        ldy #$1E
loc_F429
        jsr sub_F45C
        lda #$08
        and ppi_pb
        bne loc_F438
        dey
        bne loc_F429
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
loc_F438
        clc
        rts

sub_F43A
        lda via1_prb
        ror
        bcc sub_F43A
        rts

sub_F441
        lda via1_prb
        ror
        bcs sub_F441
        rts

sub_F448
        lda #$01
        and $49
        bne loc_F45B
        lda #$F0
        and via1_prb
        sta via1_prb
        lda via1_prb
        and #$05
loc_F45B
        rts

sub_F45C
        ldx #$4B
loc_F45E
        jsr sub_F2C5
        dex
        bne loc_F45E
        rts

sub_F465
        jsr sub_F45C

sub_F468
        lda ppi_pb
        and #$0E
        eor #$0E
        bne sub_F468
        rts

sub_F472
        sei
        cld
        ldx #$8F
        txs
        jsr sub_F75B
        lda $90E1
        jsr sub_F795
        lda $90E2
        jsr sub_F78C
        jsr sub_F73B
        lda #$00
        sta $49
        tax
loc_F48E
        sta $9100,x
        sta $9200,x
        inx
        bne loc_F48E

sub_F497
        sei
        cld
        lda #$DB
        sta via2_pcr
        lda #$08
        sta via2_prb
        lda #$18
        sta via2_ddrb
        lda #$00
        sta via2_ddra
        lda #$00
        sta via2_sr
        lda #$7F
        sta via2_ier
        sta via2_ifr
        lda #$FF
        sta via1_pra_nh
        lda #$3A
        sta via1_ddra
        lda #$D5
        sta via1_prb
        lda #$3A
        sta via1_ddrb
        lda #$00
        sta via1_t2ch
        lda #$05
        sta via1_t2cl
        lda #$7F
        sta via1_ier
        sta via1_ifr
        lda #$00
        sta via1_pcr
        lda #$0C
        sta via1_acr
        lda #$C6
        sta via1_ier
        lda #$92
        ldx #$E2
        jsr $90F8
        lda #$02
        sta $01
        ldy #$00
        sty $00
        tya
loc_F4FF
        sta ($00),y
        iny
        bne loc_F4FF
        inc $01
        ldx $01
        cpx #$80
        bcc loc_F4FF
        lda #$80
        sta $2BDA

sub_F511
        sei
        ldy $49
        ldx #$00
        txa
loc_F517
        sta $00,x
        sta $0100,x
        inx
        bne loc_F517
        sty $49
        ldx #$8F
        txs
        stx $5E
        jsr sub_F609
        lda $90E3
        sta $2BD6
        jsr sub_B023
        jsr sub_F562
        ldy #$32
loc_F537
        jsr sub_F2C5
        dey
        bne loc_F537
        ldx #$00
        lda #$82
        jsr sub_E81C
        ldy #$00
loc_F546
        dex
        bne loc_F546
        dey
        bne loc_F546
        jsr sub_AF03
        bit $2BDA
        bpl loc_F557
        jmp loc_DE17
loc_F557
        lda #$73
        jsr sub_DFAD
        jsr sub_9744
        jmp jt_idle_loop

sub_F562
        lda #$FF
        ldx #$00
loc_F566
        sta $2C48,x
        inx
        cpx #$13
        bcc loc_F566
        ldx #$00
loc_F570
        sta $2C68,x
        sta $2C88,x
        sta $2CA8,x
        inx
        cpx #$20
        bcc loc_F570
        lda #$1E
        ora #$80
        sta $2C57
        lda #$1F
        sta $2C58
        lda #$01
        sta $2DC6
        lda #$1E
        sta $2C86
        lda #$88
        sta $2DC7
        lda #$1F
        sta $2C87
        ldx #$00
        ldy #$03
loc_F5A2
        lda #$00
        sta $A0,x
        inx
        tya
        sta $A0,x
        iny
        inx
        cpx #$40
        bcc loc_F5A2
        jsr sub_F5E4
        jsr sub_F5ED
        jsr sub_DD54
        jsr sub_F5F6
        lda #$02
        sta $2A61
        lda #$04
        sta $46
        lda #$01
        sta $57
        lda #$02
        sta $61
        lda #$05
        sta $2BE9
        lda #$00
        sta $2BE7
        sta $2BE6
        sta $71
        lda #$FF
        sta $70
        sta $2BFA
        rts

sub_F5E4
        lda #$00
        sta $DC
        lda #$02
        sta $DD
        rts

sub_F5ED
        lda #$00
        sta $DE
        lda #$23
        sta $DF
        rts

sub_F5F6
        lda $90E4
        bmi loc_F5FE
        lda $90E1
loc_F5FE
        and #$1F
        ora #$20
        sta $77
        eor #$60
        sta $78
        rts

sub_F609
        php
        sei
        jsr sub_F73B
        ldx #$00
        ldy #$00
loc_F612
        lda jump_table_defaults,x
        sta jt_cmd_block+1,y
        lda jump_table_defaults+1,x
        sta jt_cmd_block+2,y
        iny
        iny
        iny
        inx
        inx
        cpx #$3E
        bcc loc_F612
        jsr sub_F730
        plp
        rts

sub_F62C
        ldx #$00
        jsr sub_F726
        lda #$00
        sta $28A0
loc_F636
        jsr sub_F64A
        bcs loc_F649
        jsr sub_F65F
        inc $28A0
        lda $28A0
        cmp #$20
        bcc loc_F636
        clc
loc_F649
        rts

sub_F64A
        clc
        adc $90E7
        sta $2801
        lda #$00
        tax
        adc $90E6
        sta $2800
        lda #$AA
        jmp sub_F704

sub_F65F
        jsr sub_F73B
        lda $28A0
        asl
        asl
        asl
        tax
        lda #$02
        sta $68
loc_F66D
        ldy #$00
        lda ($68),y
        sta part_type,x
        ldy #$1C
        lda ($68),y
        sta part_size_hi,x
        iny
        lda ($68),y
        sta part_size_lo,x
        ldy #$13
        lda ($68),y
        sta part_start_hi,x
        iny
        lda ($68),y
        sta part_start_mid,x
        iny
        lda ($68),y
        sta part_start_lo,x
        inx
        lda $68
        clc
        adc #$20
        sta $68
        bcc loc_F66D
        jmp sub_F730

sub_F6A1
        jsr sub_F726
        lda #$50
        sta $2860,x
        txa
        asl
        tax
        lda #$00
        sta $2800,x
        lda #$02
        sta $2801,x
        txa
        lsr
        tax
        lda #$01
        sta $28A0,x
        lda #$00
        sta $2880,x
        lda #$FC
        jmp sub_F704

sub_F6C8
        jsr sub_F6A1
        bcc loc_F6CE
        rts
loc_F6CE
        txa
        pha
        ldx #$0F
loc_F6D2
        lda $51F0,x
        cmp dat_F6F4,x
        bne loc_F6F0
        dex
        bpl loc_F6D2
        jsr sub_F73B
        ldx #$00
loc_F6E2
        lda $5100,x
        sta $9000,x
        inx
        bne loc_F6E2
        jsr sub_F730
        clc
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
loc_F6F0
        sec
        pla
        tax
        rts
dat_F6F4
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $F6F4
        !byte $8D,$03,$88,$8E,$02,$88,$EA,$60 ; $F6FC

sub_F704
        php
        sei
        sta $20,x
        lda $90E8
        pha
        lda #$00
        jsr sub_F79E
        jsr sub_F73B
        lda $20,x
        jsr sub_E825
        pla
        jsr sub_F79E
        jsr sub_F730
        lda $20,x
        plp
        cmp #$02
        rts

sub_F726
        pha
        php
        cli
loc_F729
        lda $20,x
        bmi loc_F729
        plp
        pla
        rts

sub_F730
        pha
        lda ctl_latch
        and #$DF
        sta ctl_latch
        pla
        rts

sub_F73B
        pha
        lda ctl_latch
        ora #$20
        sta ctl_latch
        pla
        rts

sub_F746
        pha
        lda $2BDB
        sta ctl_latch
        pla
        rts

sub_F74F
        pha
        lda ctl_latch
        sta $2BDB
        jsr sub_F73B
        pla
        rts

sub_F75B
        pha
        lda ppi_pc
        ora #$02
        sta ppi_pc
        pla
        rts

sub_F766
        pha
        lda ppi_pc
        and #$FD
        sta ppi_pc
        pla
        rts

sub_F771
        jsr sub_F74F
        sta $90E0
        jmp sub_F746

sub_F77A
        jsr sub_F74F
        sta $90E1
        jmp sub_F746

sub_F783
        jsr sub_F74F
        sta $90E2
        jmp sub_F746

sub_F78C
        jsr sub_F74F
        sta $90E3
        jmp sub_F746

sub_F795
        jsr sub_F74F
        sta $90E4
        jmp sub_F746

sub_F79E
        jsr sub_F74F
        sta $90E8
        jmp sub_F746

sub_F7A7
        txa
        asl
        asl
        asl
        asl
        asl
        asl
        pha
        ldx #$00
        jsr sub_F6A1
        bcs loc_F7F7
        pla
        pha
        tax
        lda $5000,x
        sta $5200
        lda $5001,x
        sta $5201
        lda $5003,x
        sta $5204
        lda $5002,x
        sta $5205
        lda #$00
        sta $5202
        sta $5203
        jsr sub_F7FA
        bcs loc_F7F7
        pla
        pha
        tax
        lda $5202
        cmp $5005,x
        bne loc_F7F7
        lda $5203
        cmp $5004,x
        bne loc_F7F7
        pla
        jsr sub_F771
        clc
        rts
loc_F7F7
        pla
        sec
        rts

sub_F7FA
        sei
        lda $5200
        sta $6C
        lda #$00
        sta $6B
        ldx #$00
        lda $5205
        lsr
        sta $2800,x
        lda $5204
        ror
        sta $2801,x
        lda $5201
        lsr
        sta $28A0,x
        lda $6B
        sta $2880,x
        lda $6C
        sta $2860,x
        lda #$FC
        jsr sub_F704
        bcs loc_F855
        ldx $5201
        ldy #$00
loc_F831
        lda $5202
loc_F834
        clc
        adc ($6B),y
        bcc loc_F83C
        inc $5203
loc_F83C
        iny
        bne loc_F834
        sta $5202
        inc $6C
        lda $6C
        cmp #$C0
        bne loc_F851
        lda #$40
        sta $6C
        jsr sub_F766
loc_F851
        dex
        bne loc_F831
        clc
loc_F855
        rts

sub_F856
        sei
        jsr sub_95F9
        lda #$10
        sta via1_prb
        lda #$00
        cmp $4B
        beq loc_F86E
        sta $4B
        cli
        jsr sub_B615
        jsr sub_979B
loc_F86E
        cli
        bit via1_prb
        bmi loc_F879
        bit ppi_pb
        bpl loc_F87C
loc_F879
        jmp jt_atn_service
loc_F87C
        sei
        ldy #$00
        ldx #$0E
loc_F881
        lda $2C48,x
        cmp #$FF
        beq loc_F889
        iny
loc_F889
        dex
        bpl loc_F881
        ldx #$1F
loc_F88E
        lda $20,x
        bpl loc_F893
        iny
loc_F893
        dex
        bpl loc_F88E
        tya
        beq loc_F89F
        jsr sub_EE3C
        jmp loc_F8A2
loc_F89F
        jsr sub_EE4D
loc_F8A2
        jsr sub_F318
        jmp loc_F86E

sub_F8A8
        pha
        tya
        pha
        txa
        pha
        ldx via1_ifr
        txa
        and #$02
        beq loc_F8C0
        sta via1_ifr
        lda #$40
        ora $2BD7
        sta $2BD7
loc_F8C0
        txa
        and #$04
        beq loc_F8D4
        sta via1_ifr
        and $46
        beq loc_F8D4
        lda #$80
        ora $2BD8
        sta $2BD8
loc_F8D4
        txa
        and #$40
        beq loc_F8DF
        sta via1_ifr
        jsr jt_run_jobs
loc_F8DF
        tsx
        lda $0104,x
        and #$10
        beq loc_F8EA
        jsr jt_run_jobs
loc_F8EA
        pla
        tax
        pla
        tay
        pla
        rti

; --------------------------------------------------------------------------
; Unused space (zero filled) up to the vector tables.
; --------------------------------------------------------------------------
free_space                              ; $F8F0
        !fill 1296, $00                 ; $F8F0-$FDFF

; --------------------------------------------------------------------------
; Default targets of the 31 jump-table slots at jt_cmd_block, in slot order.
; sub_F609 copies these words into the operands of the JMPs on every warm
; start, undoing any run-time patch made through sub_DEEE.
; --------------------------------------------------------------------------
jump_table_defaults                     ; $FE00
        !word sub_A9B5                  ; $FE00
        !word sub_B933                  ; $FE02
        !word sub_BE03                  ; $FE04
        !word sub_AEEC                  ; $FE06
        !word sub_BCD0                  ; $FE08
        !word sub_A6CD                  ; $FE0A
        !word sub_D3EB                  ; $FE0C
        !word sub_BDAE                  ; $FE0E
        !word sub_AD88                  ; $FE10
        !word sub_B352                  ; $FE12
        !word sub_DD36                  ; $FE14
        !word sub_9C88                  ; $FE16
        !word sub_BB38                  ; $FE18
        !word sub_DE29                  ; $FE1A
        !word sub_F511                  ; $FE1C
        !word sub_DEEE                  ; $FE1E
        !word sub_F856                  ; $FE20
        !word sub_DF3B                  ; $FE22
        !word sub_DF13                  ; $FE24
        !word sub_F8A8                  ; $FE26
        !word sub_944A                  ; $FE28
        !word sub_A021                  ; $FE2A
        !word sub_9E54                  ; $FE2C
        !word sub_E43D                  ; $FE2E
        !word sub_E41B                  ; $FE30
        !word sub_E81C                  ; $FE32
        !word sub_E825                  ; $FE34
        !word sub_E860                  ; $FE36
        !word sub_E9C7                  ; $FE38
        !word sub_B1FB                  ; $FE3A
        !word sub_B22A                  ; $FE3C
free_space_2                            ; $FE3E
        !fill 98, $00                   ; $FE3E-$FE9F

; Second copy of the copyright text (not referenced by code).
copyright_msg_2                         ; $FEA0
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $FEA0
free_space_3                            ; $FEEA
        !fill 22, $00                   ; $FEEA-$FEFF

; ==========================================================================
; Public jump table: 31 x JMP.  The DOS reaches its own major services
; through these slots, so they can be re-vectored at run time (sub_DEEE
; patches a slot; the image lives in write-protected RAM).  The command
; dispatcher sub_B615 jumps to $FF00+offset using the offset table dat_B605.
; ==========================================================================
jt_cmd_block                            ; $FF00
        jmp sub_A9B5                    ; 'B'  block commands (B-R B-W B-A B-F B-P B-E)
jt_cmd_copy                             ; $FF03
        jmp sub_B933                    ; 'C'  copy / change partition / change directory
jt_cmd_g                                ; $FF06
        jmp sub_BE03                    ; 'G'  G-P get partition info, GEOS
jt_cmd_initialize                       ; $FF09
        jmp sub_AEEC                    ; 'I'  initialize
jt_cmd_m                                ; $FF0C
        jmp sub_BCD0                    ; 'M'  M-R M-W M-E, MD make directory
jt_cmd_new                              ; $FF0F
        jmp sub_A6CD                    ; 'N'  new (format partition)
jt_cmd_position                         ; $FF12
        jmp sub_D3EB                    ; 'P'  position (relative files)
jt_cmd_rename                           ; $FF15
        jmp sub_BDAE                    ; 'R'  rename, RD remove directory
jt_cmd_scratch                          ; $FF18
        jmp sub_AD88                    ; 'S'  scratch
jt_cmd_time                             ; $FF1B
        jmp sub_B352                    ; 'T'  time: T-R / T-W
jt_cmd_user                             ; $FF1E
        jmp sub_DD36                    ; 'U'  user commands, U0 burst commands
jt_cmd_validate                         ; $FF21
        jmp sub_9C88                    ; 'V'  validate
jt_cmd_slash                            ; $FF24
        jmp sub_BB38                    ; '/'
jt_cmd_utility                          ; $FF27
        jmp sub_DE29                    ; '&'  utility loader
jt_warm_start                           ; $FF2A
        jmp sub_F511                    ; warm start
jt_set_vector                           ; $FF2D
        jmp sub_DEEE                    ; patch jump-table slot X with address A (lo) / Y (hi)
jt_idle_loop                            ; $FF30
        jmp sub_F856                    ; idle loop
jt_dos_error                            ; $FF33
        jmp sub_DF3B                    ; report DOS error A and abort the command
jt_job_error                            ; $FF36
        jmp sub_DF13                    ; report job error A of job X and abort the command
jt_irq                                  ; $FF39
        jmp sub_F8A8                    ; IRQ / BRK handler (target of the IRQ vector)
jt_atn_service                          ; $FF3C
        jmp sub_944A                    ; serial bus ATN service
jt_listen                               ; $FF3F
        jmp sub_A021                    ; addressed as listener: receive data
jt_talk                                 ; $FF42
        jmp sub_9E54                    ; addressed as talker: send data
jt_burst_get_byte                       ; $FF45
        jmp sub_E43D
jt_burst_send_byte                      ; $FF48
        jmp sub_E41B
jt_do_job                               ; $FF4B
        jmp sub_E81C                    ; run job A for buffer X, job error on failure
jt_do_job_status                        ; $FF4E
        jmp sub_E825                    ; run job A for buffer X, return status
jt_run_jobs                             ; $FF51
        jmp sub_E860                    ; execute all pending jobs
jt_job_to_block                         ; $FF54
        jmp sub_E9C7                    ; convert the job's track/sector into a block address
jt_cmd_l                                ; $FF57
        jmp sub_B1FB                    ; 'L'
jt_cmd_w                                ; $FF5A
        jmp sub_B22A                    ; 'W'
free_space_4                            ; $FF5D
        !fill 157, $00                  ; $FF5D-$FFF9

; --------------------------------------------------------------------------
; 6502 hardware vectors
; --------------------------------------------------------------------------
hw_vectors                              ; $FFFA
        !word sub_9A7C                  ; $FFFA  NMI
        !word sub_F472                  ; $FFFC  RESET
        !word jt_irq                    ; $FFFE  IRQ/BRK (through the jump table)
