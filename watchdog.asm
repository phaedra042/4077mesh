; ====================
         ; Dual Watchdog Driver
         ; Cassette Buffer
         ; ($033c)
         ; $C000: HD Device
         ; $C001: Config
         ; Partition
         ; $C002: 30min Timer
         ; Enabled (0=Off, 1=On)
         ; $C003-$C004: 16bit
         ; Boot Watchdog
         ; ====================

         *= $033c

wdhd     = $c000
wdco     = $c001
wden     = $c002
wdhi     = $c003
wdlo     = $c004
irqv     = $0314
kbuff    = $0277
kcnt     = $c6
bwrm     = $e37b

init
         sei
         lda irqv
         sta oldirq
         lda irqv+1
         sta oldirq+1
         lda #<handler
         sta irqv
         lda #>handler
         sta irqv+1

         ; Clear background
         ; timer counters
         lda #0
         sta tickcnt
         sta seclo
         sta sechi
         cli
         rts

handler
         ; 1. BOOT WATCHDOG
         ; CHECK
         lda wdlo
         ora wdhi
         beq trigger
         lda wdlo
         bne declo
         dec wdhi
declo
         dec wdlo

         ; 2. 30MINUTE
         ; BACKGROUND TIMER
         lda wden
         ; Is 30min timer
         ; enabled ($C002)?
         beq chain
         ; If 0, skip entirely

         inc tickcnt
         ; Count system ticks
         ; (60Hz NTSC / 50Hz
         ; PAL)
         lda tickcnt
         cmp #60
         bne chain

         lda #0
         sta tickcnt
         ; Reset tick counter

         ; Increment 16bit
         ; second counter
         ; (seclo / sechi)
         inc seclo
         bne checktime
         inc sechi

checktime
         ; Safe 16bit
         ; comparison for >=
         ; 300 ($012C)
         lda sechi
         cmp #>300
         bcc chain
         ; If sechi < high
         ; byte, keep waiting
         bne inject
         ; If sechi > high
         ; byte, trigger
         ; immediately!

         lda seclo
         cmp #<300
         bcc chain
         ; If seclo < low byte
         ; , keep waiting

inject
         ; Reset 16bit second
         ; counter for the next
         ; cycle
         lda #0
         sta seclo
         sta sechi

         ; Inject 'c' into
         ; keyboard buffer
         ; safely
         ldx kcnt
         ; Get current buffer
         ; count
         cpx #10
         ; Guard against buffer
         ; overflow
         bcs chain
         lda #67
         ; Screencode
         ; lowercase 'c'
         sta kbuff,x
         inx
         stx kcnt

chain
         jmp (oldirq)

trigger
         sei
         lda oldirq
         sta irqv
         lda oldirq+1
         sta irqv+1
         cli
         ldx #$00
copystr
         lda str,x
         beq setbuff
         sta kbuff,x
         inx
         cpx #16
         bcc copystr
setbuff
         stx kcnt
         ldx #$ff
         txs
         jmp bwrm

oldirq   !word $00
tickcnt  !byte $00
seclo    !byte $00
sechi    !byte $00

str
         !text "/boot"
         !byte $0d
         !text "run"
         !byte $0d
         !byte $00
         ;-----------------