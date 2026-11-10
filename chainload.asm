; =======================================================
          ; C64 Generic Chain-Loader (Max 16-Char Filename Limit)
          ; Runs from $C020 (49,184 decimal)
          ; 
          ; Purpose: Safely opens a file, reads its native 2-byte 
          ; load address header via a stream peek, closes the channel 
          ; to release the serial bus, and performs a fast explicit 
          ; load (SA=1) to prevent JiffyDOS header-load lockups.
          ; =======================================================

; --- Zero-Page and Memory Vectors ---
wdhd      = $C000   ; Workdisk / Device number storage byte
wdco      = $C001   ; Working storage / config partition
wden      = $C002   ; Watchdog Cron enable
wdhi      = $C003   ; watchdog high byte
wdlo      = $C004   ; watchdog low byte

txttab    = $2B     ; BASIC pointer: Start of BASIC program text
vartab    = $2D     ; BASIC pointer: Start of variables
arytab    = $2F     ; BASIC pointer: Start of arrays
strend    = $31     ; BASIC pointer: End of array storage / top of memory

clr       = $A68E   ; KERNAL vector: Clear BASIC variables (CLR)
run       = $A7AE   ; KERNAL vector: Execute/Run loaded BASIC program
clrchn    = $FFCC   ; KERNAL vector: Restore default I/O channels (screen/keyboard)
clall     = $FFE7   ; KERNAL vector: Close all open files in KERNAL file table
unlstn    = $FFAE   ; KERNAL vector: Send UNLISTEN command to clear serial bus output
untalk    = $FFAB   ; KERNAL vector: Send UNTALK command to clear serial bus input

; --- KERNAL Vector Jump Table ($FFBA - $FFD5) ---
setlfs    = $FFBA   ; Set Logical File, Device, and Secondary Address
setnam    = $FFBD   ; Set Filename Pointer and Length
open      = $FFC0   ; Open a Logical File channel
close     = $FFC3   ; Close a Logical File channel
chkin     = $FFC6   ; Open channel for input (read stream)
basin     = $FFCF   ; Read byte from current input channel
load      = $FFD5   ; Load file into memory (or verify)

          *= $C020  ; Origin address for machine language routine

start
          pla             ; a sys call puts 2 bytes on the stack
          pla             ; we don't want a memory leak
          cli             ; 1. Enable interrupts: Essential for JiffyDOS fast-loader timing
          jsr clall       ; 2. Wipe software file table to clear any lingering file states
          jsr clrchn      ; 3. Reset standard I/O channels back to screen and keyboard
          
          ; 4. Force physical hardware serial bus lines into an idle/released state
          jsr unlstn      ; Release ATN/Clock/Data lines for output
          jsr untalk      ; Release ATN/Clock/Data lines for input

          ; 5. Scan the zero-terminated filename string buffer (max 16 chars)
          ldy #$00        ; Initialize string index counter in Y
lenloop
          lda fnstr,y     ; Load character from filename buffer
          beq gotlen      ; If byte is $00 (null terminator), finish scan
          iny             ; Increment character count
          cpy #$10        ; Check if we've hit the 16-character ($10) max limit
          bne lenloop     ; If not, loop back for the next character

gotlen
          ; 6. Pass the evaluated filename length and memory pointers to SETNAM
          tya             ; Transfer calculated string length from Y to A
          ldx #<fnstr     ; Load low byte of filename string address into X
          ldy #>fnstr     ; Load high byte of filename string address into Y
          jsr setnam      ; Register filename with KERNAL

          ; 7. Open the file with Secondary Address 0 (SA=0) to inspect its header
          lda #$01        ; Logical file number (1)
          ldx wdhd        ; Device number (patched from BASIC or system state)
          ldy #$00        ; Secondary address 0 (open file to read native header bytes)
          jsr setlfs
          jsr open        ; Execute OPEN vector
          bcs loaderr     ; Branch immediately if Carry is set (indicates disk/file error)

          ; 8. Redirect input stream to our logical file to read the header
          ldx #$01        ; Target logical file number (1)
          jsr chkin       ; Set input channel to file 1
          bcs loaderr     ; Branch on error

          jsr basin       ; Read byte 1: Native load address LOW byte
          sta lodlo       ; Store low byte locally
          jsr basin       ; Read byte 2: Native load address HIGH byte
          sta lodhi       ; Store high byte locally

          ; 9. Close the peek-stream to release the drive and bus before real load
          jsr clrchn      ; Restore default keyboard/screen input channels
          lda #$01        ; Logical file number (1)
          jsr close       ; Tell drive/KERNAL to close the file channel

          ; 10. Perform lightning-fast explicit load (SA=1) using the parsed address
          lda #$01        ; Logical file number (1)
          ldx wdhd        ; Device number
          ldy #$01        ; Secondary address 1: Explicit load mode (bypass header handshake)
          jsr setlfs      ; Set up parameters for actual data transfer

          lda #$00        ; Operation mode: 0 = Load to memory (1 = verify mode)
          ldx lodlo       ; Pass parsed low byte as explicit destination
          ldy lodhi       ; Pass parsed high byte as explicit destination
          jsr load        ; Execute KERNAL LOAD (bypasses JiffyDOS SA=0 lockup)
          bcs loaderr     ; Branch on error if load fails
          
          ; 11. Update BASIC end-of-program pointers using coordinates returned by LOAD

         lda lodlo
         sta txttab      ; Set start of BASIC program text low byte ($2B)
         lda lodhi
         sta txttab+1    ; Set start of BASIC program text high byte ($2C)
         
          stx vartab      ; Update low byte of variable start pointer
          sty vartab+1    ; Update high byte of variable start pointer
          stx arytab      ; Update low byte of array start pointer
          sty arytab+1    ; Update high byte of array start pointer
          stx strend      ; Update low byte of string storage end pointer
          sty strend+1    ; Update high byte of string storage end pointer
          
          jsr clr         ; Wipe out existing BASIC variables to prevent corruption
          jmp run         ; Jump straight into BASIC warm-start vector to execute program

loaderr
          ; --- Error Recovery Handler ---
          jsr clrchn      ; Ensure input/output channels are restored
          lda #$01        ; Logical file number 1
          jsr close       ; Force-close file channel if left open during failure
          rts             ; Return safely back to caller

; --- Local Storage Variables ---
lodlo     !byte 0         ; Storage for extracted load address low byte
lodhi     !byte 0         ; Storage for extracted load address high byte

fnstr
          ; --- Filename String Buffer ---
          ; Starts at $C06A. Max 16 bytes padded with $00 null terminator.
          !byte 0,0,0,0,0
          !byte 0,0,0,0,0
          !byte 0,0,0,0,0
          !byte 0,0
;------------------------------------------------------------------------