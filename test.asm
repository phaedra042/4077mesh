; ==============================================================================
;  CMD HD DOS v1.92   (c) 1990 Creative Micro Designs, Inc.
;  Reverse-engineered source, reassembles to the original binary.
;
;  Assembler : ACME / C64 Studio syntax.  The !to line below writes
;              hdos_v1.92_rebuilt.prg as a plain binary.
;  Original  : 'hdos v1.92.prg', 27650 bytes = 2-byte load address $2000
;              followed by the image for $9400-$FFFF in the drive's RAM.
;  CPU       : NMOS 6502, documented opcodes only.
;
;  Entry points
;    RESET  $F472  reset            (vector $FFFC)
;    NMI    $9A7C  nmi_ui_command   (vector $FFFA; also the UI command)
;    IRQ    $FF39  -> irq_handler   (vector $FFFE, through the jump table)
;    $944A  atn_service: first code byte, serial bus attention service
;    $FF00  public jump table, 31 slots; defaults at $FE00
;
;  Conventions
;    sub_XXXX / loc_XXXX / dat_XXXX   addresses that were not given a name
;    !byte $2C / $24 before a label   the BIT skip trick: the bytes that
;                                     follow are a second entry point
;    (?) in a comment                 interpretation that is not certain
; ==============================================================================

;------------------------------------------------------------------------------
; zero page
;------------------------------------------------------------------------------
job_queue             = $20             ; job code / status per buffer, 32 slots
buf_wanted            = $41             ; buffer number being looked for / allocated
buf_table_index       = $44             ; index of the active buffer's entry in the channel buffer tables
bus_role              = $46             ; bit7 = addressed as talker, bit6 = addressed as listener, bit2 = burst mode allowed
panel_state           = $49             ; shadow of the LED bits of the control latch: b0 activity, b1 error, b2 SWAP 8, b3 SWAP 9, b6 GEOS, b7 write protect
open_sa               = $4A             ; secondary address of the OPEN being processed
cmd_pending           = $4B             ; non-zero when a complete command / OPEN string waits in the command buffer
burst_cmd             = $4C             ; burst command byte
tmp0                  = $50             ; general work byte / low byte of a temporary vector
tmp1                  = $51             ; general work byte / high byte of a temporary vector
tmp2                  = $52             ; general work byte
tmp3                  = $53             ; general work byte
tmp4                  = $54             ; work byte
job_code              = $55             ; job code to be queued ($80 read / $90 write)
cmd_len               = $56             ; length of the string in the command buffer
burst_interleave_s    = $57             ; sector interleave set by U0>S
bam_ptr               = $58             ; pointer (lo/hi $58/$59) into the BAM cache buffer of the current slot: slot base, track entry or bitmap
bam_ptr_hi            = $59             ; high byte of the BAM cache pointer
track                 = $5A             ; current track
sector                = $5B             ; current sector
stack_save            = $5E             ; stack pointer restored on every attention service / error
jiffy_port_idle       = $60             ; JiffyDOS send: port value with CLK/DATA released
burst_retries         = $61             ; retry count set by U0>R
user_vec_ptr          = $62             ; pointer to the user command vector table
call_vector           = $64             ; vector for user / burst command dispatch
buf_ptr               = $66             ; pointer to the job's buffer / transfer address
data_ptr              = $68             ; data pointer of block transfers / SCSI data phase
burst_status          = $6A             ; burst status byte
jiffy_nibble          = $6C             ; JiffyDOS send: high nibble of the current byte
burst_last_clk        = $6E             ; burst: last CLK state seen (?)
jiffy_port_final      = $6F             ; JiffyDOS send: final port value carrying the EOI status
burst_status_and      = $70             ; burst status mask (AND)
burst_status_or       = $71             ; burst status mask (OR); bit7 = logical sector addressing
listen_addr           = $77             ; this drive's LISTEN address ($20 + device)
talk_addr             = $78             ; this drive's TALK address ($40 + device)
channel               = $80             ; current channel index (0-$1D files, $1E command, $1F error)
eoi_flag              = $81             ; set to $80 before a transfer, 0 once EOI / last byte was seen
sec_addr              = $82             ; current secondary address (channel number 0-15)
sec_addr_raw          = $83             ; secondary address byte as received ($6x open/data, $Ex close, $Fx open)
bus_data              = $84             ; byte received from / to be sent to the host
work_count            = $85             ; scratch: files deleted; also general flag
rel_end_index         = $86             ; REL: side sector index of the file end; also scan index
rel_work              = $87             ; REL work byte / jump vector low
rel_ptr               = $88             ; REL work pointer low / group counter
rel_end_group         = $8A             ; REL: side sector group of the file end
acc24                 = $8B             ; 24-bit accumulator (acc24 low)
factor24              = $90             ; 24-bit factor / division remainder
dir_ptr               = $94             ; pointer to the current directory entry / buffer position
bit_count             = $96             ; bit counter of the serial byte routines
name_index            = $97             ; index of the name being resolved
rel_byte_pos          = $98             ; REL: byte position within the record
rel_side_num          = $99             ; REL: side sector number of the wanted record
rel_side_index        = $9A             ; REL: index of the block pointer in the side sector
rel_block_offset      = $9B             ; REL: offset of the record in its data block
buf_num               = $9C             ; buffer number being worked on
val_index             = $9D             ; validate: index into the VLIR record table
buf_ptrs              = $A0             ; buffer pointers, 2 bytes per buffer (lo/hi), 32 buffers
cmdbuf_ptr            = $DC             ; pointer of buffer $1E: command buffer
errbuf_ptr            = $DE             ; pointer of buffer $1F: error message buffer
scsi_cmd_ptr          = $E0             ; pointer to the next command byte
scsi_status_ptr       = $E2             ; pointer for the status byte
scsi_msg_ptr          = $E4             ; pointer for the message byte
job_vector            = $E8             ; vector for job handler / converter dispatch

;------------------------------------------------------------------------------
; stack page, command buffer and data buffers
;------------------------------------------------------------------------------
cmd_buf               = $0200           ; command / file name input buffer
sys_buf               = $2200           ; system buffer (buffer $1F): header and directory work block

;------------------------------------------------------------------------------
; DOS variables
;------------------------------------------------------------------------------
msg_buf               = $2300           ; error / reply message buffer ($2300-$27FF: error buffers)
job_track             = $2800           ; job header: track, 2 bytes per job slot
job_sector            = $2801           ; job header: sector
job_side              = $2840           ; per job slot: side flag (bit 4) for physical 1581 addressing
job_ptr_hi            = $2860           ; per job slot: data address high
job_ptr_lo            = $2880           ; per job slot: data address low
job_block_count       = $28A0           ; per job slot: number of blocks
job_scsi_id           = $28C0           ; per job slot: SCSI ID of the device
job_scsi_lun          = $28E0           ; per job slot: logical unit number
job_block_hi          = $2900           ; per job slot: block address on the device, high
job_block_mid         = $2920           ; per job slot: block address, middle
job_block_lo          = $2940           ; per job slot: block address, low
job_code_saved        = $2960           ; per job slot: job code kept for retries
scsi_cdb              = $2A00           ; SCSI command descriptor block
scsi_status           = $2A10           ; status of the last SCSI command
scsi_sense            = $2A11           ; REQUEST SENSE data
scsi_message          = $2A30           ; message byte of the last command
cache_scsi_id         = $2A50           ; block cache: device ID ($FF = empty); LUN and block follow
scsi_phase            = $2A55           ; expected control line state of the current phase
job_current           = $2A56           ; job code being executed
job_buffer            = $2A57           ; buffer number of the job being set up / executed
job_cur_track         = $2A58           ; track of the job being executed
job_cur_sector        = $2A59           ; sector of the job being executed
block_offset_hi       = $2A5A           ; block offset inside the partition, high
block_offset_lo       = $2A5B           ; block offset inside the partition, low
addr_raw_flag         = $2A5C           ; bit7 = raw / physical addressing
half_block_flag       = $2A5D           ; bit7 = sector is the second half of its 512-byte block
job_part_num          = $2A5E           ; partition the job is addressed to
job_cur_side          = $2A5F           ; side flag of the job
led_blink_timer       = $2A60           ; error LED blink counter
job_retries           = $2A61           ; retry count for failed jobs
job_retries_left      = $2A62           ; retries left for the current job
block_abs             = $2A63           ; absolute block address (3 bytes, high first); also 24-bit sum
mul_count             = $2A66           ; multiplier / sectors per track
half_block_cached     = $2A67           ; bit7 = first half of a 512-byte block is held in the cache (?)
time_bcd              = $2B00           ; clock as read: weekday, year, month, day, hour, minute, second, PM flag
filter_date_from      = $2B08           ; listing/search filter: earliest date and time (5 bytes)
filter_date_to        = $2B0D           ; listing/search filter: latest date and time (5 bytes)
bam_slot_partition    = $2B30           ; 16 entries: partition number cached in BAM slot n (0 = slot free)
bam_dirty             = $2B40           ; per BAM slot: cache modified
bam_free_lo           = $2B50           ; 16 entries: blocks free of the slot's partition, low byte
bam_free_hi           = $2B60           ; 16 entries: blocks free of the slot's partition, high byte
bam_dos_version       = $2B70           ; 16 entries: DOS version byte read from offset 2 of the BAM ('H' native, 'A' 1541/71, 'D' 1581), 0 = unknown
bam_group             = $2B80           ; per BAM slot: BAM group (16 tracks each) held in the cache
bam_slot_invalid      = $2B90           ; 16 entries: $FF = partition not initialised / BAM invalid (error 74), 0 = valid
bam_temp_count        = $2BA0           ; scratch counter: allocation passes, track distance, bits per track, table run length
bam_slot              = $2BA1           ; index (0-15) of the BAM cache slot of the current partition
bam_io_dir            = $2BA2           ; bit7 = BAM write, clear = BAM read
disk_id               = $2BA3           ; two disk ID characters ($2BA3/$2BA4) of the current partition / from the N command
range_count_hi        = $2BA5           ; partition file: block count high
range_count_lo        = $2BA6           ; partition file: block count low; also type byte scratch
dir_hdr_track         = $2BA7           ; track of the current directory header
dir_hdr_sector        = $2BA8           ; sector of the current directory header
dir_first_sector      = $2BA9           ; sector of the first directory block (1541/71: 1, 1581: 3, native: header+1, root 34)
entry_date            = $2BAA           ; date and time of the entry being listed: year, month, day, hour, minute
entry_pm              = $2BAF           ; bit7 = PM
listing_long          = $2BB0           ; bit7 = long date format in the listing
listing_col           = $2BB1           ; listing: entries on the current line group
listing_width         = $2BB2           ; listing: characters written on the line
listing_mode          = $2BB3           ; bit7 = partition directory, bit6 = with date and time
search_type_a         = $2BB4           ; file type filter of the directory search (?)
search_type_b         = $2BB5           ; bit7 = 'not after' date filter active
entry_track           = $2BB6           ; track of the directory block of the current entry
entry_sector          = $2BB7           ; sector of that block
entry_offset          = $2BB8           ; offset of the current entry in its block
free_entry_part       = $2BB9           ; partition of the remembered free directory entry
free_entry_track      = $2BBA           ; track of the block with a free entry (0 = none)
free_entry_sector     = $2BBB           ; sector of that block
free_entry_offset     = $2BBC           ; search mode in (0 used / 1 free), offset of the free entry out
name_loop             = $2BBD           ; index of the name being processed
search_done           = $2BBE           ; 0 = names still unresolved, $FF = all found
match_index           = $2BBF           ; index of the name that matched
dir_link              = $2BC0           ; link track of the current directory block (0 = last)
dir_entries_left      = $2BC1           ; entries left in the current directory block
name_len              = $2BC2           ; length of the current name
line_number_lo        = $2BC3           ; listing: block count / partition number low
line_number_hi        = $2BC4           ; listing: block count high
dir_listing_flag      = $2BC5           ; non-zero while secondary address 0 delivers a directory listing
alloc_dir_track       = $2BC6           ; directory header track of the partition: centre of the allocation strategy, excluded from blocks free on emulation types
first_track           = $2BC7           ; first legal track of the partition
last_track_plus1      = $2BC8           ; last track + 1 of the partition
sectors_per_track     = $2BC9           ; number of sectors on the track last passed to the limits routine; 0 = 256 (native)
md_track              = $2BCA           ; MD: candidate header track
md_sector             = $2BCB           ; MD: candidate header sector
path_index            = $2BCC           ; path resolution: current command index
path_file             = $2BCD           ; path resolution: file table index
saved_job_error_vec   = $2BCE           ; saved job error vector during the boot load (2 bytes)
saved_dos_error_vec   = $2BD0           ; saved DOS error vector (2 bytes)
utl_checksum_val      = $2BD2           ; utility loader: running checksum
utl_count_val         = $2BD3           ; utility loader: bytes left in the block
ctl_shift             = $2BD4           ; controller mode: byte being shifted out
ctl_eoi               = $2BD5           ; controller mode: bit7 = send the next byte with EOI
cmd_partition         = $2BD6           ; partition used by the command channel
atn_state             = $2BD7           ; bit7 = inside the attention service, bit6 = ATN interrupt pending
bus_protocol          = $2BD8           ; bit7 = burst host, bit6 = JiffyDOS host, $61 = fast load mode
boot_flag             = $2BDA           ; bit7 = cold start: try the auto-boot file
latch_saved           = $2BDB           ; saved control latch value
jump_vector           = $2BDC           ; scratch vector ($2BDC/$2BDD) for JMP (indirect) table dispatch
cmd_error_code        = $2BDE           ; error to report when the command ends (0 = none)
job_no_check          = $2BDF           ; bit6 = queue the next job without geometry check
write_channel         = $2BE0           ; channel of the file being written
burst_result          = $2BE1           ; result of the last burst job
cmd_index             = $2BE2           ; index of the command being executed (bit7 set inside B commands)
syntax_image          = $2BE3           ; parse result bits, checked against the command's mask
wildcard_count        = $2BE4           ; wildcards seen while scanning (bit7 = in an earlier name)
scan_char             = $2BE5           ; character searched by the scanner
swap_request          = $2BE6           ; device number swap requested: 8 or 9, 0 = none
swap_default          = $2BE7           ; bit7 = return to the default device number requested
burst_mode            = $2BE8           ; burst: $00 native, $80 1581, $40 1541/1571 partition
sector_interleave     = $2BE9           ; sector interleave for burst transfers (default 5)
param_count           = $2BEA           ; number of parsed parameters / first source file index
file_count            = $2BEB           ; number of file names in the command
parse_index           = $2BEC           ; command buffer index / current file index
file_type             = $2BED           ; file type of the entry being processed (0-7)
type_option           = $2BEE           ; file / partition type requested with '=' or ','
name_end              = $2BEF           ; index of the end of the name in the command
open_mode             = $2BF0           ; 0 read, 1 write, 2 append, 3 modify
record_len            = $2BF3           ; record length of a REL file
side_track            = $2BF4           ; side sector track of a REL file
side_sector           = $2BF5           ; side sector sector of a REL file
rel_group             = $2BF6           ; REL: side sector group (super side sector index)
rel_flags             = $2BF7           ; REL: bit4 = moved on to the next block
wp_by_software        = $2BF9           ; bit7 = write protect was set by the W command
evict_partition       = $2BFA           ; partition number of the BAM slot being considered for reuse
par_mode              = $2BFB           ; bit6 = transaction over the parallel port, $60 = parallel fast block mode
chan_vector           = $2BFC           ; vector: byte source / sink of the current transfer
bus_vector            = $2BFE           ; vector: protocol send / receive routine
file_name_pos         = $2C00           ; per file: position of the name in the command buffer
name2_index           = $2C01           ; index behind the first comma of the command (N: the ID), = command length if none
file_name_start       = $2C08           ; per file: index of the name proper (behind partition and path)
file_partition        = $2C10           ; per file: partition number
file_type_flags       = $2C18           ; per file: directory type byte of the match
file_track            = $2C20           ; per file: first track of the match (0 = not found); also parameter high bytes
file_sector           = $2C28           ; per file: first sector; also parsed decimal parameters
file_dir_track        = $2C30           ; per file: track of the directory block holding the entry
file_dir_sector       = $2C38           ; per file: sector of that directory block
file_dir_index        = $2C40           ; per file: offset of the entry in the directory block
sa_channel            = $2C48           ; channel index per secondary address ($FF free, bit7 write, bit6 direct)
chan_buf_a            = $2C68           ; per channel: active buffer number (bit7 = inactive)
chan_buf_b            = $2C88           ; per channel: second buffer number
chan_side_buf         = $2CA8           ; per channel: buffer of the side sector (REL), $FF none
chan_partition        = $2CC8           ; per channel: partition of the file
chan_dir_track        = $2CE8           ; per channel: track of the directory block of the file's entry
chan_dir_sector       = $2D08           ; per channel: sector of that block
chan_dir_offset       = $2D28           ; per channel: offset of the entry
chan_blocks_lo        = $2D48           ; per channel: block count low
chan_blocks_hi        = $2D68           ; per channel: block count high
chan_file_type        = $2D88           ; per channel: file type * 2 plus mode flags
chan_status           = $2DA8           ; per channel: bit7 ready to talk, bit0 ready to listen, bit3 clear = last byte
chan_data             = $2DC8           ; per channel: next byte to send
chan_last_index       = $2DE8           ; per channel: buffer index of the last valid byte (0 = not last block)
errchan_last_index    = $2E07           ; last-byte index of the error channel (chan_last_index + $1F)
chan_record_len       = $2E08           ; per channel: record length (REL)
chan_record_ptr       = $2E28           ; per channel: buffer index of the next record
chan_side_group       = $2E48           ; per channel: side sector group held ($FF none, $FE super)
chan_super_sector     = $2E68           ; per channel: sector of the super side sector
chan_super_track      = $2E88           ; per channel: track of the super side sector
chan_rel_flags        = $2EA8           ; per channel: bit5 set = no super side sector
last_prg_track        = $2FC0           ; per BAM slot: start track of the last program loaded/saved
last_prg_sector       = $2FD0           ; per BAM slot: start sector of it
line_buf              = $2FE0           ; directory line being built (27 characters)
block_cache           = $5000           ; 512-byte block cache; $5000-$5FFF is reserved for disk buffers (manual, appendix D)
work_block            = $5200           ; work buffer
bam_cache             = $6000           ; BAM cache: 16 slots of 512 bytes (two BAM sectors each), slot n at $6000+n*$200

;------------------------------------------------------------------------------
; I/O and the RAM windows between the I/O chips
;------------------------------------------------------------------------------
via1_prb              = $8000           ; VIA #1 port B, serial bus: b0 DATA IN, b1 DATA OUT, b2 CLK IN, b3 CLK OUT, b4 ATN ACK, b5 FST DIR, b6 ATN OUT, b7 ATN IN (per schematic)
via1_ddrb             = $8002           ; VIA #1 DDRB ($3A: bits 1,3,4,5 are outputs)
via1_ddra             = $8003           ; VIA #1 DDRA
via1_t2cl             = $8008           ; VIA #1 timer 2 counter low
via1_t2ch             = $8009           ; VIA #1 timer 2 counter high
via1_sr               = $800A           ; VIA #1 shift register: fast serial data (CB2 = FST DATA, CB1 = FST CLK)
via1_acr              = $800B           ; VIA #1 ACR: bits 2-4 select shift-in ($0C) / shift-out ($14) mode
via1_pcr              = $800C           ; VIA #1 PCR
via1_ifr              = $800D           ; VIA #1 IFR: b1 CA1 = ATN, b2 shift register done, b6 timer 1
via1_ier              = $800E           ; VIA #1 IER
via1_pra_nh           = $800F           ; VIA #1 port A: auxiliary serial port and serial-bus reset lines (b0-b4 AUX DATA/CLK/ATN, b5 SB RESET ENA, b6 SB RESET IN, b7 AUX ATN)
part_type             = $8200           ; partition table: type per partition (0 none,1 native,2 1541,3 1571,4 1581,5 1581 CP/M,$FF system)
part_size_hi          = $8300           ; partition table: size in 512-byte blocks, high byte
via2_prb              = $8400           ; VIA #2 port B, SCSI control: b0 C/D, b1 MSG, b2 I/O, b3 BDIRIN (data bus direction), b4 SEL OUT, b5 BSY, b6 ACK IN, b7 REQ (per schematic)
via2_pra              = $8401           ; VIA #2 port A: SCSI data bus, active low (/DB0-/DB7)
via2_ddrb             = $8402           ; VIA #2 DDRB
via2_ddra             = $8403           ; VIA #2 DDRA: $00 = data bus input, $FF = output
via2_sr               = $840A           ; VIA #2 shift register
via2_pcr              = $840C           ; VIA #2 PCR: CA2 generates ACK, CB2 = FORCE, CA1 = RST, CB1 = BSY
via2_ifr              = $840D           ; VIA #2 IFR
via2_ier              = $840E           ; VIA #2 IER
part_size_lo          = $8600           ; partition table: size in 512-byte blocks, low byte
part_start_hi         = $8700           ; partition table: start block, high byte
ppi_pa                = $8800           ; 8255 port A: parallel port data PD0-PD7
ppi_pb                = $8801           ; 8255 port B (in): b0 PRDY IN, b1 SWAP 8 button, b2 SWAP 9 button, b3 WRITE PROTECT button, b4 SCSI SEL IN, b5 PEXT IN, b6 PCLK IN, b7 PATN
ppi_pc                = $8802           ; 8255 port C (out): b0 ROMOS, b1 ALTMAP, b2 SCSI ATN OUT, b3 SCSI RST OUT, b4 SCSI BSY OUT, b5 PEXT OUT, b6 PCLK OUT, b7 PRDY OUT
ppi_ctrl              = $8803           ; 8255 control word: $92 = port A input, $82 = port A output
part_start_mid        = $8A00           ; partition table: start block, middle byte
part_start_lo         = $8B00           ; partition table: start block, low byte
rtc_regs              = $8C00           ; RTC 72421 register 0 (seconds, units); registers follow as BCD digits
rtc_hour10            = $8C05           ; RTC register 5: hours tens (+ AM/PM bit)
rtc_weekday           = $8C0C           ; RTC register 12: day of week
rtc_ctrl_d            = $8C0D           ; RTC control register D (HOLD / BUSY)
ctl_latch             = $8F00           ; control latch (74HCT374): b0 ACT LED, b1 ERR LED, b2 SW8 LED, b3 SW9 LED, b4 SCSI PARITY, b5 WPRAM (RAM write enable), b6 GEOS LED, b7 WRP LED

;------------------------------------------------------------------------------
; write-protected RAM below the DOS image
;------------------------------------------------------------------------------
cfg_device_tab        = $9000           ; per device: bit7 absent, bits4-6 SCSI ID, bits0-2 LUN
cfg_dev_start_hi      = $9038           ; per device: first block, high
cfg_dev_start_mid     = $9070           ; per device: first block, middle
cfg_dev_start_lo      = $90A8           ; per device: first block, low
cfg_geos_entry        = $90E0           ; set by the GEOS command (?)
cfg_default_device    = $90E1           ; configured device number
cfg_default_part_boot = $90E2           ; configured default partition
default_partition     = $90E3           ; default partition (CP command)
cfg_device            = $90E4           ; active device number, bit7 = swapped
cfg_own_id_mask       = $90E5           ; bit mask of the controller's own SCSI ID
sys_start_hi          = $90E6           ; system area start, high byte
sys_start_lo          = $90E7           ; system area start, low byte
cur_partition         = $90E8           ; current partition number
cfg_ppi_stub          = $90F8           ; code stub from the configuration block: STA $8803 / STX $8802 / RTS
part_dir_track        = $9100           ; per partition: current directory track
part_dir_sector       = $9200           ; per partition: current directory sector (native) or track limit
parity_table          = $9300           ; parity bit for every byte value

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
; first executable byte is the serial-bus ATN service at atn_service.
; ==========================================================================
copyright_msg                           ; $9400
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $9400

; ==========================================================================
; Serial bus / parallel port attention service (jump table slot jt_atn_service).
; Entered from the idle loop when the host pulls ATN low or raises the
; parallel request line, and re-entered from the byte routines whenever
; ATN appears in mid transfer.  Resets the stack, reads the command bytes
; sent under attention (LISTEN, TALK, UNLISTEN, UNTALK, secondary address)
; and then runs the listener or talker loop.
; ==========================================================================
atn_service                             ; $944A
        sei
        cld
        ldx stack_save                  ; restore the stack pointer saved at start-up
        txs
        lda #$80                        ; bit 7 of atn_state: inside the attention service
        sta eoi_flag
        sta atn_state
        and bus_protocol                ; keep only the burst flag of bus_protocol
        sta bus_protocol
        lda #$00
        sta par_mode                    ; transaction is serial until proven parallel
        lda bus_role
        and #$3F                        ; drop the talker and listener roles
        sta bus_role
        lda #$02
        sta via1_ifr                    ; clear the pending ATN (CA1) interrupt flag
        jsr burst_sr_input
        bit ppi_pb                      ; PATN: parallel request line active?
        bpl atn_serial
        jmp atn_parallel
atn_serial                              ; $9477
        bit via1_prb                    ; ATN really low?
        bpl atn_done
        lda #$02
        sta via1_prb                    ; pull DATA low: answer the attention
atn_wait_clk                            ; $9481
        lda via1_prb
        bpl atn_done
        and #$04                        ; wait for the host to release CLK
        bne atn_wait_clk
atn_next_byte                           ; $948A
        jsr atn_get_byte
atn_dispatch                            ; $948D
        cmp #$3F                        ; $3F = UNLISTEN
        bne atn_chk_untalk
        lda #$BF
        bne atn_clear_role
atn_chk_untalk                          ; $9495
        cmp #$5F                        ; $5F = UNTALK
        bne atn_chk_talk
        lda #$7F
atn_clear_role                          ; $949B
        and bus_role
        sta bus_role
        lda #$00
        sta bus_protocol
        jmp atn_wait_end
atn_chk_talk                            ; $94A7
        cmp talk_addr                   ; this drive's TALK address?
        bne atn_chk_listen
        lda #$80                        ; bit 7 of bus_role: talker
        bne atn_set_role
atn_chk_listen                          ; $94AF
        cmp listen_addr                 ; this drive's LISTEN address?
        bne atn_secondary
        lda #$40                        ; bit 6 of bus_role: listener
atn_set_role                            ; $94B5
        ora bus_role
        sta bus_role
        ora #$3F
        and bus_role
        sta bus_role
        lda default_partition           ; command channel works on the default partition
        sta cmd_partition
        jmp atn_more
atn_secondary                           ; $94C8
        tax
        and #$60                        ; $60-$7F / $E0-$FF: secondary address
        cmp #$60
        bne atn_not_ours
        stx sec_addr_raw                ; keep the full secondary address byte
        txa
        and #$0F
        sta sec_addr                    ; channel number 0-15
        txa
        and #$F0
        cmp #$E0                        ; $Ex = CLOSE
        bne atn_wait_end
        cli
        jsr close_handler               ; close the file with interrupts enabled
        sei
atn_more                                ; $94E2
        bit par_mode                    ; more bytes while attention is still active
        bvc loc_94EE
        bit ppi_pb
        bmi atn_next_byte
        bpl atn_done
loc_94EE
        bit via1_prb
        bmi atn_next_byte
atn_done                                ; $94F3
        ldx #$00
        stx atn_state                   ; leave attention mode
        lda via1_prb
        ora #$10                        ; set ATN acknowledge so DATA is not held
        sta via1_prb
        bit bus_role                    ; listener?
        bvc atn_chk_talker
        bit bus_protocol                ; burst host: announce fast serial first
        bpl atn_do_listen
        jsr burst_announce
atn_do_listen                           ; $950C
        jsr jt_listen                   ; receive data until the next attention
        jmp atn_exit
atn_chk_talker                          ; $9512
        bit bus_role                    ; talker?
        bpl atn_exit
        bit par_mode
        bvc atn_talk_serial
        jsr par_set_output              ; parallel: turn the port around
        jmp atn_do_talk
atn_talk_serial                         ; $9521
        jsr serial_data_release         ; serial turnaround: release DATA, pull CLK
        jsr serial_clk_assert
        jsr delay_short
atn_do_talk                             ; $952A
        jsr jt_talk                     ; send data until the next attention
        jsr delay_short
atn_exit                                ; $9530
        jsr par_release
        jsr burst_sr_input
        jmp jt_idle_loop                ; back to the idle loop
atn_not_ours                            ; $9539
        bit par_mode                    ; byte was meant for another device
        bvs par_not_ours
        bit bus_protocol
        bvc loc_9549
        lda bus_role
        and #$C0
        bne atn_wait_end
loc_9549
        lda #$00                        ; release all serial lines
        sta via1_prb
atn_wait_end                            ; $954E
        bit par_mode                    ; wait for the end of the attention
        bvs atn_wait_par
atn_wait_serial                         ; $9553
        bit via1_prb
        bpl atn_done
        bmi atn_wait_serial
par_not_ours                            ; $955A
        lda ppi_pc                      ; idle the parallel handshake lines
        ora #$E0
        sta ppi_pc
atn_wait_par                            ; $9562
        bit ppi_pb
        bpl atn_done
        bmi atn_wait_par

; Attention arrived over the parallel port: mark the transaction as
; parallel in par_mode, turn 8255 port A to input and fetch the first byte.
atn_parallel                            ; $9569
        ldx #$0A                        ; short settling delay
loc_956B
        dex
        bne loc_956B
        lda #$40                        ; bit 6 of par_mode: parallel transaction
        sta par_mode
        lda ppi_pc
        and #$7F
        ora #$60
        sta ppi_pc
        tax
        lda #$92                        ; 8255 mode: port A input
        sta ppi_ctrl
        stx ppi_pc
        jsr par_atn_get_byte
        jmp atn_dispatch

; Send one byte to the host over the parallel port (protocol table send_byte_tab).
; In: X = channel; byte in chan_data,X; bit 3 of chan_status,X clear = last byte.
par_send_byte                           ; $958C
        bit ppi_pb                      ; PCLK IN busy? (PATN aborts)
        bmi par_abort
        bvs par_send_byte
        lda chan_data,x                 ; byte to send
        sta ppi_pa
        lda chan_status,x               ; bit 3 clear = this is the last byte
        and #$08
        bne par_send_strobe
        lda ppi_pc                      ; last byte: signalled on PCLK OUT (port C bit 6)
        and #$BF
        sta ppi_pc
        ora #$80
        sta ppi_pc
        ldy #$28
loc_95AF
        dey
        bne loc_95AF
par_send_strobe                         ; $95B2
        lda ppi_pc                      ; PRDY OUT and PCLK OUT high: data valid
        ora #$C0
        sta ppi_pc
        and #$7F
loc_95BC
        bit ppi_pb                      ; wait for PCLK IN from the host
        bmi par_abort
        bvc loc_95BC
        sta ppi_pc                      ; strobe off
        rts

; Host raised the request line during a transfer: restart the service.
par_abort                               ; $95C7
        jmp atn_service

; Receive one byte from the host over the parallel port (table recv_byte_tab).
; Out: A = bus_data = byte; eoi_flag cleared when the host flags the last byte.
par_recv_byte                           ; $95CA
        bit ppi_pb
        bmi par_abort
        bvs par_recv_byte
        ldy ppi_pa                      ; read the data byte
        sty bus_data
        lda ppi_pc                      ; acknowledge on PRDY OUT
        ora #$80
        sta ppi_pc
        lda #$01
par_recv_wait                           ; $95E0
        bit ppi_pb
        bmi par_abort
        bne par_recv_eoi                ; PRDY IN set: host signals the last byte
        bvc par_recv_wait
        lda ppi_pc
        and #$7F
        sta ppi_pc
        tya
        rts
par_recv_eoi                            ; $95F3
        lda #$00                        ; eoi_flag = 0: EOI
        sta eoi_flag
        beq par_recv_wait

; End of a parallel transaction: port A back to input, handshake lines
; idle.  Restarts the attention service if the host is already asking again.
par_release                             ; $95F9
        php
        sei
        lda ppi_pc
        ora #$E0
        and #$7F
        tay
        ldx #$92                        ; port A input
        stx ppi_ctrl
        sta ppi_pc
        ora #$80
        bit ppi_pb                      ; host asking again already?
        bmi par_release_abort
        sta ppi_pc
        bit ppi_pb
        bpl loc_9620
par_release_abort                       ; $961A
        sty ppi_pc
        jmp atn_service
loc_9620
        plp
        rts

; Switch 8255 port A to output (drive will talk); port C is rewritten
; because a mode write clears the output latches.
par_set_output                          ; $9622
        lda ppi_pc
        ldx #$82                        ; 8255 mode: port A output
        stx ppi_ctrl
        sta ppi_pc
        rts

; Fetch the next byte sent under attention, parallel or serial.
; Out: A = bus_data = byte.
atn_get_byte                            ; $962E
        bit par_mode                    ; parallel transaction?
        bvc serial_atn_get_byte

; Parallel version of the attention byte fetch.  Bytes that are neither a
; secondary address nor this drive's LISTEN/TALK address end the service.
; A secondary address of $60 while listening selects the fast block mode
; (par_mode = $60) and is reported to the caller as $61.
par_atn_get_byte                        ; $9633
        lda ppi_pc
        ora #$80
        sta ppi_pc
loc_963B
        bit ppi_pb
        bpl atn_get_abort
        bvs loc_963B
        ldy ppi_pa                      ; command byte
        sty bus_data
        lda #$01
        bit ppi_pb
        beq par_atn_accept
        cpy talk_addr                   ; our TALK address?
        beq par_atn_accept
        cpy listen_addr                 ; our LISTEN address?
        beq par_atn_accept
        jmp par_not_ours
par_atn_accept                          ; $9659
        lda ppi_pc
        and #$7F
        sta ppi_pc
loc_9661
        bit ppi_pb
        bpl atn_get_abort
        bvc loc_9661
        tya
        bit bus_role
        bvc loc_9678
        cmp #$60                        ; secondary $60 as listener: fast block mode
        bne loc_9678
        sta par_mode
        lda #$61
        sta bus_data
loc_9678
        jmp atn_byte_fixup
atn_get_abort                           ; $967B
        jmp atn_done

; Serial version: standard Commodore byte receive with EOI handshake.
; Also detects a JiffyDOS host: JiffyDOS holds off the last bit of the
; address byte; the drive answers by pulsing DATA and sets bit 6 of bus_protocol.
serial_atn_get_byte                     ; $967E
        lda #$08
        sta bit_count                   ; 8 bits
loc_9682
        jsr serial_test_clk             ; wait for CLK released (talker ready)
        bne loc_9682
        jsr serial_data_release         ; release DATA: listener ready
        lda #$01
loc_968C
        bit via1_prb
        bne loc_968C
        ldx #$0A                        ; wait for CLK low; time out = EOI
sag_wait_talker                         ; $9693
        jsr serial_read_port
        dex
        beq sag_eoi
        jsr serial_read_stable
        and #$04
        beq sag_wait_talker
        bne sag_bit
sag_eoi                                 ; $96A2
        jsr serial_data_assert          ; EOI: pull DATA for a moment as acknowledge
        ldx #$18
loc_96A7
        dex
        bne loc_96A7
        jsr serial_data_release
loc_96AD
        jsr serial_test_clk
        beq loc_96AD
        lda #$00                        ; eoi_flag = 0: EOI
        sta eoi_flag
sag_bit                                 ; $96B6
        ldx #$1A                        ; bit time-out counter
sag_bit_wait                            ; $96B8
        lda via1_prb
        tay
        and #$04                        ; CLK released = bit valid
        beq sag_take_bit
        dex
        bne sag_bit_wait
        lda #$3F                        ; time-out inside a byte: JiffyDOS host?
        bit bus_protocol
        bmi sag_rearm
        bvs sag_jiffy_check
        bne sag_rearm
        ldx bit_count                   ; only on the last bit
        cpx #$01
        beq sag_jiffy_check
        ldx #$01
        stx bus_protocol
        dex
        beq sag_bit_wait
sag_jiffy_check                         ; $96DC
        lda bus_data                    ; is the partial byte our TALK or LISTEN address?
        lsr
        cmp listen_addr
        beq sag_jiffy_ack
        cmp talk_addr
        bne sag_rearm
sag_jiffy_ack                           ; $96E7
        lda #$40                        ; bit 6 of bus_protocol: JiffyDOS host
        sta bus_protocol
        ldx #$1E
        jsr serial_data_assert          ; answer with a DATA pulse
loc_96F1
        dex
        bne loc_96F1
        jsr serial_data_release
sag_rearm                               ; $96F7
        ldx #$00
        beq sag_bit_wait
sag_take_bit                            ; $96FB
        tya                             ; DATA input is inverted
        eor #$01
        lsr
        ror bus_data                    ; shift the bit in, LSB first
loc_9701
        jsr serial_test_clk             ; wait for CLK low again
        beq loc_9701
        dec bit_count
        bne sag_bit
        jsr serial_data_assert          ; byte complete: pull DATA
        lda bus_data
        bne atn_byte_fixup
        lda #$80
        and bus_protocol
        sta bus_protocol
        lda #$00

; Post-process an attention byte: secondary address $61 received as
; talker selects the fast load mode (bus_protocol = $61) and is turned into $60.
atn_byte_fixup                          ; $971B
        bit bus_protocol
        bmi loc_972F
        cmp #$61                        ; secondary $61 as talker: fast load mode
        bne loc_972F
        bit bus_role
        bpl loc_972F
        sta bus_protocol
        lda #$60
        sta bus_data
loc_972F
        rts

; Out: Z clear while the CLK input is asserted.
serial_test_clk                         ; $9730
        jsr serial_read_port
        and #$04
        rts

; Wait until the DATA input is asserted (bit 0 reads 1).
serial_wait_data_low                    ; $9736
        jsr serial_read_port
        ror
        bcc serial_wait_data_low
        rts

; Wait until the DATA input is released.
serial_wait_data_high                   ; $973D
        jsr serial_read_port
        ror
        bcs serial_wait_data_high
        rts

; Read the serial port, watching ATN.  While inside the attention service
; (atn_state bit 7) a released ATN ends it; outside, an asserted ATN restarts
; the service.  Out: A = port value.
serial_read_port                        ; $9744
        bit atn_state
        bpl loc_974F                    ; inside the attention service?
        lda via1_prb
        bpl loc_9757                    ; ATN released: service is over
loc_974E
        rts
loc_974F
        lda via1_prb
        bpl loc_974E                    ; ATN asserted: start the service
        jmp jt_atn_service
loc_9757
        jmp atn_done

; Release the DATA line.
serial_data_release                     ; $975A
        lda via1_prb
        and #$FD
        sta via1_prb
        rts

; Pull the DATA line low.
serial_data_assert                      ; $9763
        lda via1_prb
        ora #$02
        sta via1_prb
        rts

; Release the CLK line.
serial_clk_release                      ; $976C
        lda via1_prb
        and #$F7
        sta via1_prb
        rts

; Pull the CLK line low.
serial_clk_assert                       ; $9775
        lda via1_prb
        ora #$08
        sta via1_prb
        rts

; Read the serial port until two consecutive reads agree.
serial_read_stable                      ; $977E
        lda via1_prb
        cmp via1_prb
        bne serial_read_stable
        rts

; Burst (fast serial) host detected and drive is listener: wait for CLK,
; then clock one dummy byte out of the shift register so the host learns
; that this drive speaks fast serial.  Falls into burst_sr_input.
burst_announce                          ; $9787
        jsr serial_test_clk
        bne burst_announce
        jsr burst_sr_output
        lda #$00                        ; dummy byte
        sta via1_sr
        lda #$04
loc_9796
        bit via1_ifr                    ; wait for the shift register to empty
        beq loc_9796

; Put the VIA shift register in input mode (shift in under external
; clock), fast-serial direction bit low, and clear a pending SR flag.
burst_sr_input                          ; $979B
        php
        sei
        lda via1_acr                    ; ACR bits 2-4 = 011: shift in under external clock
        and #$E3
        sta via1_acr
        ora #$0C
        sta via1_acr
        lda via1_prb                    ; fast-serial direction: input
        and #$DF
        sta via1_prb
        bit via1_sr                     ; dummy read clears the SR flag
        plp
        rts

; Unreachable leftover (would be BCC burst_sr_input).
dead_97b7
        bcc burst_sr_input

; Put the VIA shift register in output mode and raise the fast-serial
; direction bit.
burst_sr_output                         ; $97B9
        php
        sei
        lda via1_prb                    ; fast-serial direction: output
        ora #$20
        sta via1_prb
        lda via1_acr                    ; ACR bits 2-4 = 101: shift out
        and #$E3
        sta via1_acr
        ora #$14
        sta via1_acr
        plp
        rts

; Short delay, X preserved.  delay_long is the longer entry.
delay_short                             ; $97D2
        txa
        nop
        ldx #$0C
        bne delay_loop

; Longer delay, X preserved.
delay_long                              ; $97D8
        txa
        ldx #$1D
delay_loop                              ; $97DB
        dex
        bne delay_loop
        tax
        rts
burst_send_eoi                          ; $97E0
        bit via1_prb                    ; last byte: EOI handshake first
        bmi burst_send_abort
        jsr serial_clk_release
        jsr serial_wait_data_high
        jsr serial_wait_data_low
        lda #$01
        bne burst_send_wait

; Send one byte with the burst protocol (protocol table send_byte_tab): the byte
; goes out through the shift register clocked by timer 2; the host
; acknowledges by toggling DATA.  burst_send_eoi is the path for the last byte.
; In: X = channel.
burst_send_byte                         ; $97F2
        lda chan_status,x               ; bit 3 clear = last byte
        and #$08
        beq burst_send_eoi
        lda via1_prb
        and #$01
        beq burst_send_eoi
        ora #$10
        sta via1_prb
        and #$01
burst_send_wait                         ; $9807
        bit via1_prb
        bmi burst_send_abort
        bne burst_send_wait
        lda #$38
        sta via1_prb
        lda via1_acr                    ; shift register to output
        and #$E3
        sta via1_acr
        ora #$14
        sta via1_acr
        lda chan_data,x                 ; byte into timer 2 and shift register
        sta via1_t2ch
        sta via1_sr
        lda #$04                        ; wait until it is shifted out
loc_982B
        bit via1_ifr
        beq loc_982B
        lda via1_acr                    ; shift register back to input
        eor #$18
        sta via1_acr
        lda #$18
        sta via1_prb
        lda #$01                        ; wait for the host to toggle DATA
loc_983F
        bit via1_prb
        bmi burst_send_abort
        beq loc_983F
        rts
burst_send_abort                        ; $9847
        jmp jt_atn_service

; Send one byte with the JiffyDOS protocol (protocol table send_byte_tab).
jiffy_send_byte                         ; $984A
        jsr jiffy_send_setup
        and #$02
        beq loc_9858
        lda jiffy_port_idle
        ora #$0D
        jsr jiffy_send_finish
loc_9858
        rts

; Prepare the JiffyDOS send state (jiffy_port_idle = idle port value, jiffy_port_final = final
; value carrying the EOI status) and send one byte through jiffy_send_loop.
jiffy_send_setup                        ; $9859
        lda via1_prb
        and #$7D
        sta jiffy_port_final
        and #$71
        sta jiffy_port_idle
        lda chan_status,x               ; bit 3 clear = last byte: EOI status
        and #$08
        bne loc_9871
        lda jiffy_port_idle
        ora #$03
        sta jiffy_port_final
loc_9871
        lda chan_data,x
        ldx jiffy_port_idle
        bit via1_prb                    ; attention aborts
        bmi jiffy_abort
        stx via1_prb
        ldy #$FF
        bne loc_98A1
jiffy_abort                             ; $9882
        jmp jt_atn_service

; JiffyDOS block send: transmit the bytes (data_ptr),Y .. end of page, two
; bits at a time on CLK/DATA with cycle-exact timing, then the status.
jiffy_send_block                        ; $9885
        lda via1_prb
        and #$70
        sta jiffy_port_idle
        ora #$0D
        sta jiffy_port_final
        ora #$02
        sta via1_prb
        eor #$0D
        sta via1_prb
        ldx #$0E
loc_989C
        dex
        bne loc_989C
jiffy_send_loop                         ; $989F
        lda (data_ptr),y                ; next byte
loc_98A1
        tax
        lsr                             ; high nibble
        lsr
        lsr
        lsr
        sta jiffy_nibble
        txa
        and #$0F
        tax
        lda jiffy_send_tab,x            ; port pattern for the low nibble
        ldx jiffy_port_idle
        jsr delay_12
        stx via1_prb
        bit via1_prb
loc_98BA
        cpx via1_prb                    ; wait for the host to release DATA
        beq loc_98BA
        pha
        pla
        nop
        sta via1_prb                    ; bits 0 and 1
        asl
        ora #$10
        and #$1F
        pha
        pla
        bit $00
        sta via1_prb                    ; bits 2 and 3
        ldx jiffy_nibble
        lda jiffy_send_tab,x
        pha
        pla
        bit via1_prb
        sta via1_prb                    ; bits 4 and 5
        asl
        ora #$10
        and #$1F
        nop
        nop
        nop
        nop
        ldx #$00
        iny
        sta via1_prb                    ; bits 6 and 7
        bne jiffy_send_loop
        lda jiffy_port_final,x          ; status: more data / EOI
        jsr delay_rts

jiffy_send_finish                       ; $98F4
        sta via1_prb
loc_98F7
        bit via1_prb                    ; wait for the host; attention aborts
        cmp via1_prb
        bcc jiffy_abort
        bne loc_98F7
        rts

; Timing padding: 12, 8 or 4 cycles plus the call overhead.
delay_12                                ; $9902
        bit dat_E000

delay_8                                 ; $9905
        bit dat_E000
delay_4                                 ; $9908
        bit dat_E000

delay_rts                               ; $990B
        rts

; JiffyDOS send table: port patterns for a nibble (bit pairs on CLK/DATA).
jiffy_send_tab                          ; $990C
        !byte $1F,$17,$1D,$15,$1B,$13,$19,$11 ; $990C
        !byte $1E,$16,$1C,$14,$1A,$12,$18,$10 ; $9914

; JiffyDOS receive table: high nibble values indexed by received bits.
jiffy_recv_tab                          ; $991C
        !byte $00,$80,$20,$A0,$40,$C0,$60,$E0 ; $991C
        !byte $10,$90,$30,$B0,$50,$D0,$70,$F0 ; $9924

; Receive one byte with the burst protocol (table recv_byte_tab).  Falls back to
; the standard receiver when the host does not clock the shift register.
burst_recv_byte                         ; $992C
        bit via1_sr                     ; clear the SR flag
        lda #$04
loc_9931
        bit via1_prb                    ; wait for CLK released
        bmi burst_recv_abort
        bne loc_9931
        ora #$10                        ; set ATN acknowledge
        sta via1_prb
        ldx #$80
        lda #$04
loc_9941
        bit via1_prb                    ; wait for CLK low with time-out
        bmi burst_recv_abort
        bne loc_9952
        dex
        bne loc_9941
        lda #$08                        ; no clock: use the standard receiver
        sta bit_count
        jmp srb_eoi
loc_9952
        ldx #$12
        lda #$04
loc_9956
        bit via1_ifr                    ; wait for the shift register to fill
        beq loc_9956
burst_recv_take                         ; $995B
        lda via1_sr                     ; the received byte
        stx via1_prb
        sta bus_data
        rts
burst_recv_abort                        ; $9964
        jmp jt_atn_service

; Receive one byte with the JiffyDOS protocol (table recv_byte_tab).
; Out: A = bus_data = byte; eoi_flag cleared on EOI.
jiffy_recv_byte                         ; $9967
        lda #$14                        ; release CLK and DATA: ready
        sta via1_prb
        and #$04
loc_996E
        bit via1_prb                    ; wait for the host to start
        bne loc_996E
        jsr delay_12
        lda via1_prb                    ; bits 4/5 then 6/7 arrive on CLK and DATA
        asl
        jsr delay_8
        ora via1_prb
        and #$0F
        tax
        ldy #$00
        jsr delay_rts
        lda via1_prb                    ; bits 0/1 then 2/3
        asl
        jsr delay_8
        ora via1_prb
        and #$0F
        ora jiffy_recv_tab,x            ; combine with the decoded high nibble
        sta bus_data
        jsr delay_rts
        lda via1_prb                    ; EOI status is on CLK
        bit bus_data
        bit bus_data
        ora #$02                        ; pull DATA: byte accepted
        sta via1_prb
        bmi burst_recv_abort
        and #$04
        bne loc_99B0
        sty eoi_flag                    ; eoi_flag = 0: EOI
loc_99B0
        lda bus_data
        rts

; Send one byte with the standard serial protocol (table send_byte_tab), LSB
; first, with the EOI delay on the last byte.  In: X = channel.
serial_send_byte                        ; $99B3
        lda #$08
        sta bit_count
        lda via1_prb                    ; release CLK: ready to send
        and #$F7
        sta via1_prb
        lsr                             ; DATA already released? then the listener is missing
        bcc loc_99CC
        jsr serial_wait_data_high
        lda chan_status,x               ; bit 3 clear = last byte
        and #$08
        bne ssb_send_bits
loc_99CC
        jsr serial_wait_data_low        ; EOI: wait for the listener's DATA pulse
        jsr ssb_send_bits
        ldx #$32                        ; wait for DATA released, with time-out
loc_99D4
        jsr serial_read_port
        and #$01
        beq ssb_rts
        dex
        bne loc_99D4

ssb_rts                                 ; $99DE
        rts

; Clock out the eight bits of chan_data,X.
ssb_send_bits                           ; $99DF
        jsr serial_clk_assert
        jsr delay_short
        jsr serial_wait_data_high
        jsr ssb_rts
ssb_bit                                 ; $99EB
        jsr delay_short
        ror chan_data,x                 ; next bit into carry
        jsr ssb_rts
        jsr serial_data_release         ; put the bit on DATA (inverted)
        bcs loc_99FB
        ora #$02
loc_99FB
        sta via1_prb
        jsr serial_clk_release          ; release CLK: bit valid
        jsr delay_short
        txa
        ldx #$0B
loc_9A07
        dex
        bne loc_9A07
        tax
        lda via1_prb                    ; pull CLK, release DATA
        ora #$08
        and #$FD
        sta via1_prb
        dec bit_count
        bne ssb_bit
        jmp serial_wait_data_low        ; wait for the listener to pull DATA

; Receive one byte with the standard serial protocol (table recv_byte_tab),
; including the EOI handshake.  If the shift register fills meanwhile the
; host is a burst host and the byte is taken from there.
; Out: A = bus_data = byte; eoi_flag cleared on EOI.
serial_recv_byte                        ; $9A1C
        bit via1_sr
        lda #$08
        sta bit_count
loc_9A23
        jsr serial_test_clk             ; wait for CLK released
        bne loc_9A23
        jsr serial_data_release         ; release DATA: ready
        lda #$01
loc_9A2D
        bit via1_prb
        bmi srb_abort
        bne loc_9A2D
        ldx #$14                        ; CLK low within the time-out? else EOI
loc_9A36
        jsr serial_test_clk
        bne srb_bit
        dex
        bne loc_9A36
srb_eoi                                 ; $9A3E
        jsr serial_data_assert          ; EOI: pulse DATA
        jsr delay_long
        jsr serial_data_release
loc_9A47
        jsr serial_test_clk
        beq loc_9A47
        lda #$00                        ; eoi_flag = 0: EOI
        sta eoi_flag
srb_bit                                 ; $9A50
        ldx via1_prb
        lda #$04                        ; shift register filled: burst host
        bit via1_ifr
        beq loc_9A5F
        ldx #$12
        jmp burst_recv_take
loc_9A5F
        txa
        and #$04
        bne srb_bit
        txa                             ; DATA input is inverted
        eor #$01
        lsr
        ror bus_data
loc_9A6A
        jsr serial_test_clk
        beq loc_9A6A
        dec bit_count
        bne srb_bit
        jsr serial_data_assert          ; pull DATA: byte accepted
        lda bus_data
loc_9A78
        rts
srb_abort                               ; $9A79
        jmp jt_atn_service

; NMI vector target and handler of the UI (U9) command, as in the 1541:
; UI+ and UI- (bus speed select) are accepted and ignored, anything else
; is a warm start.
nmi_ui_command                          ; $9A7C
        lda cmd_buf+2                   ; third character of the command
        cmp #$2B                        ; UI+
        beq loc_9A78
        cmp #$2D                        ; UI-
        beq loc_9A78
        jmp jt_warm_start               ; plain UI: warm start

; JiffyDOS fast LOAD: send the whole file block by block straight from
; the buffer, following the track/sector links, without the per-byte
; channel machinery.
jiffy_fastload                          ; $9A8A
        jsr serial_wait_data_high
        lda #$04                        ; first block: data starts at offset 4 (after the load address?)
jfl_block                               ; $9A8F
        tax
        lda data_ptr+1
        pha
        txa
        pha
        ldy #$01
        lda (data_ptr),y                ; link: sector / bytes used
        sta sector
        tax
        dey
        lda (data_ptr),y                ; link: track, 0 = last block
        sta track
        bne loc_9AAF
        pla                             ; last block: start so that it ends on the last byte
        clc
        sbc sector
        inx
        stx data_ptr
        beq loc_9AAE
        dec data_ptr+1
loc_9AAE
        pha
loc_9AAF
        pla
        tay
        jsr jiffy_send_block            ; send the block
        pla
        sta data_ptr+1
        lda track
        beq jfl_end
        jsr jfl_read_block
        lda #$02                        ; following blocks start at offset 2
        bne jfl_block
jfl_end                                 ; $9AC2
        sta data_ptr
        jsr jfl_delay_clk_release
        jsr jfl_delay_clk_release
        jsr jfl_pulse_clk
        ldy #$00
loc_9ACF
        lda (data_ptr),y
        sta (buf_ptr),y
        iny
        bne loc_9ACF
        rts

; Pulse CLK (end-of-load signalling).
jfl_pulse_clk                           ; $9AD7
        jsr serial_clk_assert

; Delay, then release CLK.
jfl_delay_clk_release                   ; $9ADA
        ldx #$28
loc_9ADC
        dex
        bne loc_9ADC
        jmp serial_clk_release

; Read the next block of the file (track/sector) into the channel buffer.
jfl_read_block                          ; $9AE2
        jsr header_set_active
        tya
        lsr
        tax
        lda #$AA                        ; job $AA: read block
        jmp job_run_or_error

; Parallel fast LOAD: as jiffy_fastload but over the parallel port.  Each block is
; preceded by a count byte.
par_fastload                            ; $9AED
        lda #$04                        ; first block starts at offset 4
pfl_block                               ; $9AEF
        pha
        ldy #$01
        lda (data_ptr),y
        sta sector
        tax
        dey
        lda (data_ptr),y
        sta track
        beq loc_9B06                    ; last block?
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
        jsr par_send_block              ; send count and data
        lda track
        beq par_send_zero
        jsr pfl_read_block
        lda #$02
        bne pfl_block
par_send_zero                           ; $9B1E
        lda #$00

; Send byte A over the parallel port with full handshake.
par_send_raw                            ; $9B20
        bit ppi_pb                      ; request line aborts
        bmi par_fast_abort
        bvs par_send_zero
        sta ppi_pa                      ; data out
        lda ppi_pc                      ; strobe
        ora #$80
        sta ppi_pc
loc_9B32
        bit ppi_pb
        bmi par_fast_abort
        bvc loc_9B32
        and #$7F                        ; strobe off
        sta ppi_pc
        ldx #$28
loc_9B40
        dex
        bne loc_9B40
        rts
par_fast_abort                          ; $9B44
        jmp atn_service

; Send count byte X, then X bytes from (data_ptr),Y over the parallel port,
; alternating on both edges of the host handshake line.
par_send_block                          ; $9B47
        tay
loc_9B48
        bit ppi_pb
        bmi par_fast_abort
        bvs loc_9B48
        stx ppi_pa
        lda ppi_pc
        ora #$80
        sta ppi_pc
loc_9B5A
        bit ppi_pb
        bmi par_fast_abort
        bvc loc_9B5A
        lda (data_ptr),y
        sta ppi_pa
        lda ppi_pc
        and #$7F
        sta ppi_pc
        dex
        beq loc_9B8D
loc_9B71
        iny
        lda (data_ptr),y
loc_9B74
        bit ppi_pb
        bvs loc_9B74
        sta ppi_pa
        dex
        beq loc_9B92
        iny
        lda (data_ptr),y
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

; Read the next file block; on a job error send $FF to the host and
; report the error.
pfl_read_block                          ; $9B98
        jsr header_set_active
        tya
        lsr
        tax
        lda #$AA
        jsr job_run                     ; job $AA: read block
        bcs pfl_read_error
        rts
pfl_read_error                          ; $9BA6
        pha
        txa
        pha
        lda #$FF                        ; $FF tells the host about the error
        jsr par_send_raw
        pla
        tax
        pla
        jmp jt_job_error

; Parallel fast SAVE (par_mode = $60): receive the file block by block,
; allocating and linking blocks as they fill.
par_fastsave                            ; $9BB4
        lsr half_block_cached           ; nothing cached yet
        ldy #$00
        jsr pfs_buffer_setup
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
pfs_next                                ; $9BBF
        lda #$02
        pha
        jsr par_recv_byte               ; count byte from the host
        tax
        pla
        tay
pfs_recv                                ; $9BC8
        bit ppi_pb
        bvs pfs_recv
        lda ppi_pa                      ; store the byte in the buffer
        sta (buf_ptr),y
        iny
        dex
        beq loc_9BE4
loc_9BD6
        bit ppi_pb
        bvc loc_9BD6
        lda ppi_pa
        sta (buf_ptr),y
        iny
        dex
        bne pfs_recv
loc_9BE4
        bit ppi_pb
        bmi pfs_abort
        bvc loc_9BE4
        jsr pfs_store_ptr
loc_9BEE
        bit ppi_pb
        bmi pfs_abort
        bvs loc_9BEE
        jsr alloc_next_block            ; allocate the next block
        jsr pfs_buffer_setup
        ldy #$00
        lda track                       ; link bytes: next track / sector
        sta (buf_ptr),y
        iny
        lda sector
        sta (buf_ptr),y
        iny
        jsr pfs_store_ptr
        jsr pfs_write_block             ; write the block just completed
        jmp pfs_next
pfs_abort                               ; $9C10
        jmp atn_service

; Point buf_ptr/buf_ptr+1 at the channel's buffer and remember its number.
pfs_buffer_setup                        ; $9C13
        ldx channel                     ; channel's buffer number
        lda chan_buf_a,x
        sta job_buffer
        clc
        adc #$03                        ; buffers start at page 3
        sta buf_ptr+1
        lda #$00
        sta buf_ptr

; Store Y as the buffer pointer of buffer job_buffer.
pfs_store_ptr                           ; $9C24
        lda job_buffer
        asl
        tax
        tya
        sta buf_ptrs,x
        rts

; Write the received block.  Consecutive half blocks of one 512-byte
; disk block are combined through the work buffers (?) to save a
; read-modify-write cycle.
pfs_write_block                         ; $9C2D
        jsr job_to_block                ; translate track/sector to a block address
        bcc loc_9C35
        jmp fbf_illegal_block           ; illegal block
loc_9C35
        bit half_block_flag             ; odd half of a 512-byte block?
        bmi pfs_write_cached
        lda job_buffer
        asl
        tax
        lda track                       ; same block as the one cached?
        cmp job_track,x
        bne pfs_write_plain
        lda sector
        sbc #$01
        cmp job_sector,x
        bne pfs_write_plain
        ror half_block_cached
        jsr cache_note
        jsr data_ptr_half
        ldy #$00
loc_9C5A
        lda (buf_ptr),y                 ; copy the buffer to the job buffer and the half-block cache
        sta (data_ptr),y
        sta work_block,y
        iny
        bne loc_9C5A
        jmp fbf_set_header
pfs_write_cached                        ; $9C67
        bit half_block_cached
        bpl pfs_write_plain
        lsr half_block_cached
        jsr cache_test
        beq pfs_write_plain
        ldy #$00
loc_9C76
        lda work_block,y
        sta block_cache,y
        iny
        bne loc_9C76
        jsr cache_note
pfs_write_plain                         ; $9C82
        jsr jwr_cached
        jmp fbf_set_header

; ==========================================================================
; V - validate.  Rebuilds the BAM from scratch and then walks the whole
; directory tree, marking the blocks of every closed file as used and
; deleting unclosed entries.  Native partitions: subdirectories are
; followed recursively.  GEOS disks: the border block and VLIR record
; chains are followed as well.
; ==========================================================================
cmd_validate                            ; $9C88
        jsr parse_partition_led         ; partition number from the command, LED on
        jsr partition_init              ; initialise the partition
        jsr partition_dir_track         ; remember the current directory
        pha
        jsr partition_dir_sector
        pha
        jsr partition_is_native
        bne val_rebuild_bam
        jsr dir_set_root                ; native: start from the root directory
        jsr dir_setup
val_rebuild_bam                         ; $9CA1
        jsr bam_select_slot
        ldx #$00
        stx file_name_pos
        ldy #$90                        ; copy the disk name from the cached header (offset $90)
loc_9CAB
        lda (bam_ptr),y
        sta cmd_buf,x
        iny
        inx
        cpx #$10
        bcc loc_9CAB
        stx cmd_len                     ; name length 16
        jsr bam_create                  ; build an empty BAM
        jsr header_read                 ; header block into the system buffer
        ldx #$AD                        ; 'GEOS format' at offset $AD?
val_geos_check                          ; $9CC0
        lda sys_buf,x
        cmp txt_geos_format-173,x
        bne val_walk
        inx
        cpx #$B8
        bcc val_geos_check
        lda sys_buf+171                 ; GEOS border block track / sector
        beq val_walk
        sta track
        sta dir_hdr_track
        lda sys_buf+172
        sta sector
        sta dir_first_sector
        jsr partition_is_native
        cmp #$02                        ; 1541 / 1571: keep the GEOS bytes in the cached BAM
        beq loc_9CEA
        cmp #$03
        bne loc_9CF9
loc_9CEA
        jsr bam_select_slot
        ldy #$AB
loc_9CEF
        lda sys_buf,y
        sta (bam_ptr),y
        iny
        cpy #$BD
        bcc loc_9CEF
loc_9CF9
        jsr val_mark_chain              ; mark the border block chain
        jsr val_directory
val_walk                                ; $9CFF
        jsr val_directory
        lda dir_hdr_track
        sta track
        lda dir_hdr_sector
        sta sector
        jsr val_mark_chain
        jsr bam_flush
        pla                             ; restore the current directory
        tay
        pla
        jsr dir_set_current
        jmp cmd_done                    ; done

; Validate one directory: step through all entries of the current
; directory; on a native partition return to the parent directory (via
; the parent pointers in the directory header) when it is exhausted.
val_directory                           ; $9D1B
        lda #$00
        sta free_entry_offset
        jsr dir_first_entry             ; first directory entry
        beq val_dir_done
        jmp val_entry
val_dir_done                            ; $9D28
        jsr dir_setup
        jsr partition_is_native         ; only native partitions have subdirectories
        bne val_rts
        jsr header_read
        lda sys_buf+34                  ; parent directory header track, 0 = root
        beq val_rts
        ldy sys_buf+35
        jsr dir_set_current
        jsr dir_setup
        lda sys_buf+36                  ; position of our entry in the parent directory
        sta entry_track
        lda sys_buf+37
        sta entry_sector
        lda sys_buf+38
        sta entry_offset
        lsr
        lsr
        lsr
        lsr
        lsr
        sec
        sbc #$07
        eor #$FF
        sta dir_entries_left
        lda #$FF
        sta dir_link
        jmp val_next_entry
val_rts                                 ; $9D68
        rts

; Mark the blocks of one closed file.  A GEOS VLIR file (structure byte
; 1, type USR, with an info block) has its record chains marked too;
; a DIR entry makes the walk descend into that subdirectory.
val_file                                ; $9D69
        ldy #$01                        ; file's first track / sector
        lda (dir_ptr),y
        pha
        iny
        lda (dir_ptr),y
        pha
        ldy #$13                        ; info block (GEOS) track
        lda (dir_ptr),y
        beq val_file_done
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        iny
        lda (dir_ptr),y                 ; GEOS structure and file type bytes
        pha
        iny
        lda (dir_ptr),y
        pha
        lda file_type
        pha
        jsr val_mark_chain
        pla
        sta file_type
        tay
        pla
        tax
        pla
        cmp #$01                        ; VLIR structure?
        bne val_file_done
        txa
        beq val_file_done
        cpy #$03
        bne val_file_done
        pla
        tax
        sta sector
        pla
        sta track
        pha
        txa
        pha
        jsr sysbuf_read_ts              ; read the VLIR index block
        ldy #$02
val_vlir_record                         ; $9DB0
        sty val_index                   ; 127 record pointers
        lda sys_buf,y
        beq loc_9DC3
        sta track
        lda sys_buf+1,y
        sta sector
        jsr val_mark_chain
        ldy val_index
loc_9DC3
        iny
        iny
        bne val_vlir_record
val_file_done                           ; $9DC7
        pla
        sta sector
        pla
        sta track
        jsr partition_is_native
        bne val_chain_next
        lda file_type                   ; type 6 = DIR: descend
        cmp #$06
        bne val_chain_next
        lda track
        ldy sector
        jsr dir_set_current
        jsr dir_setup
        jsr header_read
        lda entry_track
        sta sys_buf+36
        lda entry_sector
        sta sys_buf+37
        lda entry_offset
        sta sys_buf+38
        jsr sysbuf_write
        jsr val_mark_chain
        jmp val_directory
val_chain_next                          ; $9E01
        jsr val_mark_chain
val_next_entry                          ; $9E04
        jsr dir_resume_entry
        bne val_entry
        jmp val_dir_done
val_entry                               ; $9E0C
        ldy #$00
        lda (dir_ptr),y                 ; bit 7 clear: file not closed properly
        bmi val_closed_entry
        jsr dir_delete_entry            ; delete the entry
        jmp val_next_entry
val_closed_entry                        ; $9E18
        and #$07                        ; file type
        sta file_type
        cmp #$05                        ; type 5
        beq val_type5
        jmp val_file
val_type5                               ; $9E24
        jsr entry_get_range
        jsr range_allocate
        jmp val_next_entry

; Mark the chain of blocks starting at track/sector as allocated,
; following the track/sector links through a temporary read channel.
val_mark_chain                          ; $9E2D
        jsr check_track_sector          ; error 66 if the block is illegal
        jsr bam_alloc_block             ; mark it allocated
        jsr open_internal_read
val_chain_loop                          ; $9E36
        jsr channel_read_link           ; read the link bytes
        lda track
        bne loc_9E40                    ; track 0: end of chain, release the channel
        jmp channel_free
loc_9E40
        jsr bam_alloc_block
        jsr file_first_block
        jmp val_chain_loop

; Signature looked for at offset $AD of the header block.
txt_geos_format                         ; $9E49
        !text "GEOS format"             ; $9E49

; ==========================================================================
; Talker loop (jump table slot jt_talk).  Sends the bytes of the channel
; selected by the secondary address until the host takes ATN again.
; Picks a routine that produces the next byte (by channel type) and one
; that puts a byte on the bus (by protocol) and calls them in turn.
; ==========================================================================
talk_handler                            ; $9E54
        sei
        bit par_mode                    ; parallel transaction: no settle delay
        bvs loc_9E5F
        ldx #$64
talk_delay                              ; $9E5C
        dex
        bne talk_delay
loc_9E5F
        jsr channel_find_read           ; channel for the secondary address
        bcs talk_rts
        ldx channel
        lda chan_status,x               ; ready to talk?
        bmi talk_start
talk_rts                                ; $9E6B
        rts
talk_start                              ; $9E6C
        lda bus_protocol                ; fast load mode selected by secondary address $61?
        cmp #$61
        bne talk_normal
        bit par_mode
        bvc talk_jiffy_fastload
        jmp par_fastload
talk_jiffy_fastload                     ; $9E7B
        jmp jiffy_fastload
talk_normal                             ; $9E7E
        jsr channel_type_index
        lda sec_addr
        bne talk_set_source
        lda dir_listing_flag            ; LOAD of '$': directory byte source
        beq talk_set_source
        ldx #$0C
talk_set_source                         ; $9E8C
        lda talk_source_tab,x
        sta chan_vector
        lda talk_source_tab+1,x
        sta chan_vector+1
        bit par_mode                    ; parallel: fixed protocol
        bvc loc_9EA1
        ldx #$06
        bne loc_9EAB
loc_9EA1
        lda bus_protocol                ; bits 6/7 of the protocol flags select the routine
        and #$C0
        asl
        rol
        rol
        rol
        tax
loc_9EAB
        lda send_byte_tab,x
        sta bus_vector
        lda send_byte_tab+1,x
        sta bus_vector+1
talk_loop                               ; $9EB7
        ldx channel
        lda chan_status,x               ; until the channel has nothing more
        bpl talk_rts
        jsr bus_transfer_byte           ; send the current byte
        jsr talk_fetch_next             ; prepare the next one
        jmp talk_loop

; Call the selected byte source.
talk_fetch_next                         ; $9EC7
        jmp (chan_vector)

; Byte sources by channel type: 0 command/error channel, 1-3 sequential
; files (SEQ/PRG/USR), 4 relative file, 5 direct access (#), 6 directory.
talk_source_tab                         ; $9ECA
        !word talk_cmd_channel          ; $9ECA
        !word talk_seq_file             ; $9ECC
        !word talk_seq_file             ; $9ECE
        !word talk_seq_file             ; $9ED0
        !word talk_rel_file             ; $9ED2
        !word talk_direct               ; $9ED4
        !word talk_directory            ; $9ED6

; Send routines by bus protocol: standard, JiffyDOS, burst, parallel.
send_byte_tab                           ; $9ED8
        !word serial_send_byte          ; $9ED8
        !word jiffy_send_byte           ; $9EDA
        !word burst_send_byte           ; $9EDC
        !word par_send_byte             ; $9EDE

; Out: X = 2 * channel type index for talk_source_tab / listen_sink_tab
; (0 for secondary address 15, 5 for a direct access channel).
channel_type_index                      ; $9EE0
        lda sec_addr
        sec                             ; secondary address 15: command channel
        sbc #$0F
        beq loc_9EF0
        jsr channel_file_type           ; file type of the channel
        cmp #$07                        ; type 7 (direct access) uses entry 5
        bne loc_9EF0
        lda #$05
loc_9EF0
        asl
        tax
        rts

; Byte source: error message buffer.  After the last byte a carriage
; return is sent and the status is reset to 00, OK.
talk_cmd_channel                        ; $9EF3
        lda errbuf_ptr                  ; pointer at the end marker $22FF?
        cmp #$FF
        bne loc_9F11
        lda errbuf_ptr+1
        cmp #$22
        bne loc_9F11
        lda #$0D                        ; send a carriage return
        sta bus_data
        jsr led_error_off
        lda #$00                        ; rebuild 00, OK,00,00
        jsr status_set_no_ts
        dec errbuf_ptr
        lda #$80                        ; status: last byte
        bne loc_9F22
loc_9F11
        jsr errbuf_get_byte
        sta bus_data
        bne errbuf_last_byte
errbuf_set_end                          ; $9F18
        lda #$FF                        ; mark the buffer as exhausted
        sta errbuf_ptr
        lda #$22
        sta errbuf_ptr+1
errbuf_last_byte                        ; $9F20
        lda #$88                        ; status: ready to talk, more data
loc_9F22
        sta chan_status+31
        lda bus_data
        sta chan_data+31
        rts

; Byte source: sequential file.  Takes the next byte from the buffer and
; reads the following block when the buffer is used up.
talk_seq_file                           ; $9F2B
        ldy channel
        lda chan_status,y               ; bit 3 clear: previous byte was the last
        and #$08
        bne loc_9F38
        sta chan_status,y
        rts
loc_9F38
        lda chan_buf_a,y
        asl
        tax
        lda (buf_ptrs,x)                ; next data byte
        pha
        lda chan_last_index,y           ; reached the last byte of the last block?
        cmp buf_ptrs,x
        bne loc_9F52
        lda #$00
        sta buf_ptrs,x
        lda #$80                        ; status $80: this one is the last
        sta chan_status,y
        bne loc_9F59
loc_9F52
        inc buf_ptrs,x                  ; end of buffer: read the next block
        bne loc_9F59
        jsr file_next_block
loc_9F59
        pla
        sta chan_data,y
        rts

; Start reading a file block: if the block has a successor read it.
file_first_block                        ; $9F5E
        ldy channel
        lda chan_buf_a,y
        asl
        tax
        lda #$00
        sta buf_ptrs,x
        lda (buf_ptrs,x)                ; link track 0 = no further block
        bne file_next_block
        rts

; Read the block named by the link bytes of the current buffer and set
; the end-of-data index when it is the last block of the file.
file_next_block                         ; $9F6E
        inc buf_ptrs,x                  ; link sector
        lda (buf_ptrs,x)
        sta job_sector,x
        dec buf_ptrs,x
        lda (buf_ptrs,x)                ; link track
        sta job_track,x
        txa
        lsr
        tax
        lda #$80                        ; job $80: read
        jsr job_run_or_error
        txa
        asl
        tax
        lda (buf_ptrs,x)                ; track byte of the new block
        sta track
        php
        inc buf_ptrs,x
        lda (buf_ptrs,x)
        sta sector
        inc buf_ptrs,x
        plp
        bne loc_9F9A
        sta chan_last_index,y           ; last block: sector byte = index of the last data byte
loc_9F9A
        tya
        tax
        inc chan_blocks_lo,x            ; count the block
        bne loc_9FA4
        inc chan_blocks_hi,x
loc_9FA4
        rts

; Byte source: relative file.
talk_rel_file                           ; $9FA5
        jmp rel_read_byte

; Byte source: directory listing (generated on the fly).
talk_directory                          ; $9FA8
        ldy channel
        lda chan_status,y
        and #$08
        bne loc_9FB5
        sta chan_status,y
        rts
loc_9FB5
        jsr buffer_get_byte             ; next byte of the listing
        pha
        bne loc_9FD1
        lda chan_last_index,y
        beq loc_9FC7
        lda #$80
        sta chan_status,y
        bne loc_9FD1
loc_9FC7
        lda #$00
        sta listing_col
        jsr listing_line                ; generate the next directory line
        ldy channel
loc_9FD1
        pla
        sta chan_data,y
        rts

; Byte source: direct access buffer.
talk_direct                             ; $9FD6
        ldy channel
        lda chan_status,y
        and #$08
        bne loc_9FE4
        lda #$89                        ; status $89: talk and listen, not last
        sta chan_status,y
loc_9FE4
        lda chan_buf_a,y
        asl
        tax
        lda buf_ptrs,x
        cmp chan_last_index,x
        bne direct_next_byte
        lda #$00
        sta buf_ptrs,x

direct_next_byte                        ; $9FF4
        inc buf_ptrs,x

direct_load_byte                        ; $9FF6
        lda (buf_ptrs,x)
        sta chan_data,y
        lda buf_ptrs,x
        cmp chan_last_index,y
        bne loc_A007
        lda #$81                        ; status $81: last byte reached
        sta chan_status,y
loc_A007
        rts

; Get the next byte of the command/error channel buffer.
errbuf_get_byte                         ; $A008
        ldy channel
        lda chan_buf_a,y
        asl
        tax
        lda (buf_ptrs,x)
        pha
        lda chan_last_index,y
        cmp buf_ptrs,x
        bne loc_A01D
        lda #$FF
        sta buf_ptrs,x
loc_A01D
        pla
        inc buf_ptrs,x
        rts

; ==========================================================================
; Listener loop (jump table slot jt_listen).  Receives bytes for the channel
; selected by the secondary address until the host takes ATN again.  A
; secondary address of the OPEN kind or the command channel collects the
; bytes in the command buffer.
; ==========================================================================
listen_handler                          ; $A021
        sei
        lda sec_addr_raw                ; OPEN ($Fx) or command channel?
        and #$8F
        cmp #$0F
        bcs listen_open
        jsr channel_find_write          ; data: channel open for writing?
        bcc listen_data
listen_rts                              ; $A02F
        rts
listen_open                             ; $A030
        jsr cmdbuf_ptr_reset            ; collect the name / command in the command buffer
        lda #$1E                        ; command channel index
        sta channel
        ldx #$00
        txa                             ; clear the command buffer
loc_A03A
        sta cmd_buf,x
        inx
        bne loc_A03A
        beq listen_set_sink
listen_data                             ; $A042
        lda par_mode                    ; parallel fast block mode: receive whole blocks
        cmp #$60
        bne loc_A04C
        jmp par_fastsave
loc_A04C
        jsr channel_type_index
listen_set_sink                         ; $A04F
        lda listen_sink_tab,x
        sta chan_vector
        lda listen_sink_tab+1,x
        sta chan_vector+1
        bit par_mode
        bvc loc_A064
        ldx #$06
        bne loc_A06E
loc_A064
        lda bus_protocol
        and #$C0
        asl
        rol
        rol
        rol
        tax
loc_A06E
        lda recv_byte_tab,x
        sta bus_vector
        lda recv_byte_tab+1,x
        sta bus_vector+1
listen_loop                             ; $A07A
        ldx channel
        lda chan_status,x               ; bit 0: channel ready to listen
        lsr
        bcs loc_A08A
        lda sec_addr_raw                ; OPEN keeps listening regardless
        and #$F0
        cmp #$F0
        bne listen_rts
loc_A08A
        jsr bus_transfer_byte           ; receive a byte
        jsr listen_store                ; store it
        jmp listen_loop

; Call the selected byte sink.
listen_store                            ; $A093
        jmp (chan_vector)

; Call the selected bus protocol routine (send or receive one byte).
bus_transfer_byte                       ; $A096
        jmp (bus_vector)

; Byte sinks by channel type: 0 command buffer, 1-3 sequential files,
; 4 relative file, 5 direct access.
listen_sink_tab                         ; $A099
        !word listen_cmd_channel        ; $A099
        !word listen_seq_file           ; $A09B
        !word listen_seq_file           ; $A09D
        !word listen_seq_file           ; $A09F
        !word listen_rel_file           ; $A0A1
        !word listen_direct             ; $A0A3

; Receive routines by bus protocol: standard, JiffyDOS, burst, parallel.
recv_byte_tab                           ; $A0A5
        !word serial_recv_byte          ; $A0A5
        !word jiffy_recv_byte           ; $A0A7
        !word burst_recv_byte           ; $A0A9
        !word par_recv_byte             ; $A0AB

; Byte sink: command buffer.  The last byte (EOI) marks a command pending.
listen_cmd_channel                      ; $A0AD
        ldx cmdbuf_ptr
        cpx #$FF                        ; buffer full: drop the byte
        beq loc_A0BA
        lda bus_data
        sta cmd_buf,x
        inc cmdbuf_ptr
loc_A0BA
        bit eoi_flag                    ; EOI: command complete
        bmi loc_A0C0
        inc cmd_pending                 ; cmd_pending != 0: command waiting to be executed
loc_A0C0
        rts

; Byte sink: sequential file.  When the buffer is full it is written out.
listen_seq_file                         ; $A0C1
        ldy channel
        lda chan_buf_a,y
        asl
        tax
        lda buf_ptrs,x                  ; pointer wrapped: buffer full
        bne loc_A0D6
        jsr file_buffer_full
        ldx channel
        lda chan_buf_a,x
        asl
        tax
loc_A0D6
        lda bus_data                    ; store the byte
        sta (buf_ptrs,x)
        inc buf_ptrs,x
        rts

; A file buffer is full: allocate the next block, store its address in
; the link bytes and write the buffer.  Refuses with error 73 when the
; partition's DOS version byte is not the expected one.
file_buffer_full                        ; $A0DD
        jsr alloc_next_block            ; allocate the next block into track/sector
        ldx bam_slot
        lda bam_dos_version,x           ; DOS version byte of the partition
        beq fbf_link
        ldy cur_partition
        ldx part_type,y
        cmp dos_version_tab,x           ; must match the partition type
        beq fbf_link
        jsr job_header_to_ts
        lda #$73                        ; error 73
        jmp jt_dos_error
fbf_link                                ; $A0FB
        ldy channel
        lda chan_buf_a,y
        sta job_buffer
        asl
        tax
        lda track                       ; link bytes: next track / sector
        sta (buf_ptrs,x)
        inc buf_ptrs,x
        lda sector
        sta (buf_ptrs,x)
        inc buf_ptrs,x
        php
        sei
        jsr job_to_block                ; translate the block address
        bcs fbf_illegal_block
        bit half_block_flag             ; half-block write optimisation (?)
        bmi fbf_write_plain
        lda job_buffer
        asl
        tax
        lda track
        cmp job_track,x
        bne fbf_write_plain
        lda sector
        sbc #$01
        cmp job_sector,x
        bne fbf_write_plain
        jsr cache_note
        jsr jwr_copy
        jmp loc_A13E
fbf_write_plain                         ; $A13B
        jsr jwr_cached
loc_A13E
        plp
fbf_set_header                          ; $A13F
        lda job_buffer                  ; the buffer now holds the new block
        asl
        tax
        lda track
        sta job_track,x
        lda sector
        sta job_sector,x
        ldx channel
        inc chan_blocks_lo,x            ; count the block
        bne loc_A158
        inc chan_blocks_hi,x
loc_A158
        rts
fbf_illegal_block                       ; $A159
        lda #$04                        ; job status 4 -> error 66
        ldx job_buffer
        sta job_queue,x
        jmp jt_job_error

; Byte sink: relative file.
listen_rel_file                         ; $A163
        jmp rel_write_byte

; Two unreferenced RTS.
dead_a166
        rts

dead_a167
        rts

; Byte sink: direct access buffer.
listen_direct                           ; $A168
        lda bus_data
        jsr buffer_put_byte
        jmp direct_load_byte

; Store A at the buffer pointer of the current channel and advance it.
buffer_put_byte                         ; $A170
        pha
        ldy channel
        lda chan_buf_a,y
        asl
        tax
        pla
        sta (buf_ptrs,x)
        inc buf_ptrs,x
        rts

; Read (header_read) or write (header_write) the directory header block of the
; current directory through the system buffer (sys_buf, job slot $1F).
header_read                             ; $A17E
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write the directory header block.
header_write                            ; $A181
        lda #$90
        pha
        lda dir_hdr_sector              ; header sector
hdr_set_sector                          ; $A187
        sta job_track+63
        lda dir_hdr_track               ; header track
hdr_set_track                           ; $A18D
        sta job_track+62
        ldx #$1F                        ; system buffer = job slot $1F
        pla
        jmp jt_do_job

; Read / write the first directory block of the current directory.
dirblock_read                           ; $A196
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write the first directory block.
dirblock_write                          ; $A199
        lda #$90
        pha
        lda dir_first_sector            ; sector of the first directory block
        jmp hdr_set_sector

; Read / write block track/sector through the system buffer.
sysbuf_read_ts                          ; $A1A2
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write block track/sector from the system buffer.
sysbuf_write_ts                         ; $A1A5
        lda #$90
        pha
        lda sector
        sta job_track+63
        lda track
        jmp hdr_set_track

; Read the header block of the parent directory (pointer in the current
; header); returns the parent's entry index in X (?).
parent_header_read                      ; $A1B2
        jsr header_read
        lda sys_buf+36                  ; parent header track / sector
        sta job_track+62
        lda sys_buf+37
        sta job_track+63
        lda sys_buf+38                  ; entry index within the parent block (?)
        pha
        lda #$80
        ldx #$1F
        jsr jt_do_job
        pla
        tax
        rts

; Write the system buffer back to the block it was read from.
sysbuf_write                            ; $A1CF
        lda #$90
        ldx #$1F
        jmp jt_do_job

; Load (bam_load) or write back (bam_write_back) the BAM block(s) of the current
; partition's cache slot, dispatched by partition type.
bam_load                                ; $A1D6
        clc
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction

; Write the cached BAM back to disk.
bam_write_back                          ; $A1D8
        sec
        ror bam_io_dir                  ; bit 7 of bam_io_dir: write
        ldx bam_slot
        lda #$00                        ; cache is clean
        sta bam_dirty,x
        jsr partition_type              ; partition type selects the routine
        asl
        tax
        lda bam_io_tab-2,x
        sta jump_vector
        lda bam_io_tab-1,x
        sta $2BDD
        jmp (jump_vector)

; BAM block I/O by partition type 1-5: native, 1541, 1571, 1581, 1581 CP/M.
bam_io_tab                              ; $A1F8
        !word bam_io_native             ; $A1F8
        !word bam_io_1541               ; $A1FA
        !word bam_io_1571               ; $A1FC
        !word bam_io_1581               ; $A1FE
        !word bam_io_1581               ; $A200

; 1541: BAM is track 18 sector 0.
bam_io_1541                             ; $A202
        lda #$12                        ; track 18, sector 0
        ldx #$00
        jmp bam_block_job

; 1571: track 18 sector 0 plus the second side's BAM at track 53 sector 0.
bam_io_1571                             ; $A209
        jsr bam_io_1541
        lda #$35                        ; track 53, sector 0 into the second cache page
        ldx #$00
bam_io_second                           ; $A210
        inc bam_ptr_hi
        jsr bam_block_job
        dec bam_ptr_hi
        rts

; 1581: sectors 1 and 2 of the directory track.
bam_io_1581                             ; $A218
        jsr partition_dir_track         ; directory track
        pha
        ldx #$01
        jsr bam_block_job
        pla
        ldx #$02
        bne bam_io_second

; Native: track 1, sector 2 + BAM group; each group is two blocks.
bam_io_native                           ; $A226
        ldx bam_slot
        lda bam_group,x                 ; BAM group number
        asl
        clc
        adc #$02
        and #$FE
        tax
        lda #$01                        ; track 1
        jsr bam_block_job
        lda #$01                        ; second block of the group
        ldx job_track+61
        inx
        jmp bam_io_second

; Queue a direct read ($CC) or write ($CE) of block A (track) / X
; (sector) to the cache page bam_ptr_hi through job slot $1E.
bam_block_job                           ; $A241
        sta job_track+60
        stx job_track+61
        lda bam_ptr_hi                  ; data pointer: cache page
        sta job_ptr_hi+30
        lda #$00
        sta job_ptr_lo+30
        lda #$01                        ; one block
        sta job_block_count+30
        ldx #$1E
        lda #$CC                        ; job $CC read / $CE write to an arbitrary address
        bit bam_io_dir
        bpl loc_A261
        lda #$CE
loc_A261
        jsr jt_do_job
        ldx bam_slot
        rts

; Make sure the BAM group covering track track is the one in the cache.
bam_select_group                        ; $A268
        jsr bam_select_slot
        lda track                       ; 16 tracks per BAM group
        lsr
        lsr
        lsr
        lsr
        cmp bam_group,x
        bne loc_A277
        rts
loc_A277
        pha
        lda bam_dirty,x                 ; write back the old group first if modified
        beq loc_A280
        jsr bam_write_back
loc_A280
        pla
        sta bam_group,x
        jmp bam_load

; Reload BAM group 0 if the cache was invalidated.
bam_ensure_loaded                       ; $A287
        jsr bam_select_slot
        lda bam_group,x
        bpl loc_A292
        jsr bam_load_first
loc_A292
        rts

; Flush a modified BAM and go back to group 0.
bam_flush_reset                         ; $A293
        jsr bam_select_slot
        lda bam_group,x
        beq loc_A2A6
        lda bam_dirty,x
        beq loc_A2A3
        jsr bam_write_back
loc_A2A3
        jsr bam_load_first
loc_A2A6
        rts

; Select the cache slot and load BAM group 0.
bam_load_group0                         ; $A2A7
        jsr bam_select_slot

; Load BAM group 0.
bam_load_first                          ; $A2AA
        lda #$00
        sta bam_group,x
        jmp bam_load

; Advance to the next BAM group (16 groups), loading it.
bam_next_group                          ; $A2B2
        jsr bam_select_slot
        inc bam_group,x
        lda bam_group,x
        cmp #$10
        bcc loc_A2C4
        lda #$00
        sta bam_group,x
loc_A2C4
        jmp bam_load

; Select the BAM cache slot of the current partition (cur_partition).
; There are 16 slots; slot n owns a 512-byte buffer at bam_cache+n*$200 that
; holds two BAM sectors. If the partition has no slot yet, a free slot
; (partition 0) is claimed, otherwise the highest slot whose partition has
; no open file is taken over (without writing its BAM back) and reset:
; nothing loaded, BAM invalid. Error 70 NO CHANNEL if all 16 are busy.
; Out: X = bam_slot = slot, bam_ptr/bam_ptr_hi -> start of the slot's BAM buffer, A = 0
bam_select_slot                         ; $A2C7
        lda cur_partition               ; A = current partition number
        ldx #$0F                        ; search slots 15..0 for this partition
bam_slot_find_loop                      ; $A2CC
        stx bam_slot                    ; bam_slot always follows the slot being examined
        cmp bam_slot_partition,x        ; slot already assigned to this partition?
        beq bam_slot_set_ptr            ; yes: only set up the buffer pointer
        dex
        bpl bam_slot_find_loop
        pha                             ; not cached yet: keep the partition number
        ldx #$00                        ; look for an unused slot (partition 0), 0 upwards
bam_slot_free_loop                      ; $A2DA
        stx bam_slot
        lda bam_slot_partition,x
        beq bam_slot_init               ; free slot found: claim it
        inx
        cpx #$10                        ; 16 slots
        bcc bam_slot_free_loop
        dex                             ; none free: X = 15, try to take over a slot
bam_slot_evict_loop                     ; $A2E8
        stx bam_slot
        lda bam_slot_partition,x        ; partition that occupies this slot
        sta evict_partition             ; remembered for the open-file scan
        jsr partition_has_open_file     ; carry set = a file is open on that partition
        bcc bam_slot_init               ; no open file: reuse the slot (its BAM is not written back here)
        ldx bam_slot
        dex
        bpl bam_slot_evict_loop
        lda #$70                        ; all 16 cached partitions have open files: error 70 NO CHANNEL
        jmp jt_dos_error
bam_slot_init                           ; $A301
        ldx bam_slot                    ; X = slot to (re)assign
        pla                             ; current partition number
        sta bam_slot_partition,x        ; slot now belongs to the current partition
        lda #$00
        sta bam_dirty,x                 ; BAM not modified
        sta bam_free_lo,x               ; blocks free = 0 (low byte)
        sta bam_free_hi,x               ; blocks free (high byte)
        sta bam_dos_version,x           ; DOS version byte of the BAM unknown
        sta last_prg_track,x            ; clear per-slot track of the last loaded file (?) (see $C6AC)
        lda #$FF
        sta bam_group,x                 ; $FF = no BAM block in the buffer
        sta bam_slot_invalid,x          ; $FF = partition not initialised, BAM invalid
bam_slot_set_ptr                        ; $A321
        txa                             ; slot * 2 pages
        asl
        clc
        adc #$60                        ; buffer of slot n is at bam_cache + n*$200
        sta bam_ptr_hi                  ; pointer high byte
        lda #$00
        sta bam_ptr                     ; pointer low byte = 0
        rts

; Check whether any secondary address 0-18 has a file open on the
; partition in evict_partition.
; Out: carry set = yes (slot may not be evicted), carry clear = no
partition_has_open_file                 ; $A32D
        ldx #$00                        ; X = secondary address
part_open_scan                          ; $A32F
        lda sa_channel,x                ; channel assigned to this secondary address
        cmp #$FF                        ; $FF = not in use
        beq part_open_next
        and #$1F                        ; channel index
        tay
        lda chan_partition,y            ; partition of the file open on that channel
        cmp evict_partition             ; the partition whose slot we want?
        beq part_open_done              ; yes: return with carry set (from the CMP)
part_open_next                          ; $A341
        inx
        cpx #$13                        ; secondary addresses 0-18
        bcc part_open_scan
        clc                             ; no open file found
part_open_done                          ; $A347
        rts

; Write the cached BAM of the current partition back to disk if it has
; been modified (bam_dirty,slot <> 0).
; Out: X = slot
bam_flush                               ; $A348
        jsr bam_select_slot             ; X = slot
        lda bam_dirty,x                 ; BAM modified since it was read?
        beq bam_flush_done              ; no: nothing to write
bam_flush_write                         ; $A350
        jmp bam_write_back              ; write the cached BAM sectors: bam_write_back

; Write the cached BAM of the current partition back to disk if a BAM
; block is loaded at all (bam_group,slot < $80), modified or not.
; Called when a file is closed (clc_flush_bam).
bam_write_if_loaded                     ; $A353
        jsr bam_select_slot
        lda bam_group,x                 ; BAM block loaded? ($FF = none)
        bpl bam_flush_write             ; yes: write it
bam_flush_done                          ; $A35B
        rts

; Allocate block track/sector in the BAM of the current partition.
; Clears the block's bit, decrements the per-track free count (emulation
; types) and the partition's blocks-free total (unless the block lies in
; the uncounted directory/system area) and marks the BAM modified. When
; fewer than 3 blocks remain, message 72 DISK FULL is placed in the error
; channel without aborting.
; Out: Z set = block was already allocated (nothing changed);
;      A = 1 / Z clear = block allocated now
; Entry bam_alloc_store: A = new BAM byte, bam_ptr,Y -> BAM byte (from the bit test).
bam_alloc_block                         ; $A35C
        jsr bam_test_block              ; Z = bit state, A = BAM byte with the bit inverted
        beq bam_alloc_done              ; already allocated: return with Z set
bam_alloc_store                         ; $A361
        sta (bam_ptr),y                 ; store the BAM byte with the bit cleared (= allocated)
        jsr bam_track_entry             ; bam_ptr -> free count of the track; carry set = native, no count
        bcs bam_alloc_count             ; native: skip the per-track count
        sec
        sbc #$01                        ; one block less free on this track
        sta (bam_ptr),y
bam_alloc_count                         ; $A36D
        jsr bam_dirty_check_counted     ; mark BAM modified; carry set = block is not counted in blocks free
        bcs bam_alloc_check_low         ; uncounted area: leave the total alone
        lda bam_free_lo,x               ; 16-bit decrement of the blocks-free total of this slot
        bne bam_alloc_dec_low
        dec bam_free_hi,x
bam_alloc_dec_low                       ; $A37A
        dec bam_free_lo,x
bam_alloc_check_low                     ; $A37D
        lda bam_free_hi,x               ; fewer than 3 blocks left?
        bne bam_alloc_ok                ; high byte <> 0: plenty
        lda bam_free_lo,x
        cmp #$03
        bcs bam_alloc_ok                ; 3 or more
        lda #$72                        ; put message 72 DISK FULL in the error channel, no abort: status_set
        jsr status_set
bam_alloc_ok                            ; $A38E
        lda #$01                        ; A = 1, Z clear: block allocated
bam_alloc_done                          ; $A390
        rts

; Free block track/sector in the BAM of the current partition.
; Sets the block's bit, increments the per-track free count (emulation
; types) and the blocks-free total (unless the block is in the uncounted
; area) and marks the BAM modified. Does nothing if already free.
bam_free_block                          ; $A391
        jsr bam_test_block              ; Z = bit state, A = BAM byte with the bit inverted
        bne bam_free_done               ; already free: nothing to do
        sta (bam_ptr),y                 ; store the BAM byte with the bit set (= free)
        jsr bam_track_entry             ; bam_ptr -> free count of the track; carry set = native, no count
        bcs bam_free_count
        adc #$01                        ; one block more free on this track (carry is clear)
        sta (bam_ptr),y
bam_free_count                          ; $A3A1
        jsr bam_dirty_check_counted     ; mark BAM modified; carry set = block is not counted in blocks free
        bcs bam_free_ok
        inc bam_free_lo,x               ; 16-bit increment of the blocks-free total of this slot
        bne bam_free_ok
        inc bam_free_hi,x
bam_free_ok                             ; $A3AE
        lda #$01
bam_free_done                           ; $A3B0
        rts

; Mark the BAM of the current slot as modified and tell whether block
; track/sector counts towards 'blocks free'. Not counted are: on emulation
; partitions the whole directory track (18 or 40, as on the real drives);
; on native partitions track 1 sectors 0-63 (only tested while the
; current directory header is on track 1).
; Out: carry set = not counted, carry clear = counted; X = slot, A = 1
bam_dirty_check_counted                 ; $A3B1
        jsr partition_dir_track         ; A = directory header track, X = partition number
        cmp track                       ; block on that track?
        bne loc_A3CD                    ; no: counted (branch into the CLC hidden in the BIT below)
        lda part_type,x                 ; partition type
        cmp #$01                        ; native?
        bne bam_block_uncounted         ; emulation: the whole directory track is uncounted
        lda track                       ; native: only track 1 ...
        cmp #$01
        bne loc_A3CD                    ; other track: counted
        lda sector                      ; ... sectors 0-63 (system area, header, BAM, root directory)
        cmp #$40
        bcs loc_A3CD                    ; sector 64 and up: counted
bam_block_uncounted                     ; $A3CB
        sec                             ; carry set = not counted
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction  skip trick: the operand byte $18 is the CLC reached by the branches above
loc_A3CD
        clc
bam_set_dirty                           ; $A3CE
        ldx bam_slot
        lda #$01                        ; flag the cached BAM of this slot as modified
        sta bam_dirty,x
        rts

; Find the first free sector on track track, starting at sector sector.
; Out: Z clear (A <> 0) = found, sector = sector;
;      Z set (A = 0) = no free sector from there to the end of the track.
;      sectors_per_track = sectors on this track (0 = 256)
find_free_sector                        ; $A3D7
        ldx track                       ; set sectors_per_track = sectors on this track (0 = 256, native)
        jsr track_limits
find_free_sec_loop                      ; $A3DC
        lda sectors_per_track           ; sector limit of the track
        beq find_free_sec_test          ; 0 = native: sectors run up to 255
        cmp sector                      ; start sector beyond the end of the track?
        bcc find_free_sec_none          ; yes: nothing free
        beq find_free_sec_none
find_free_sec_test                      ; $A3E7
        jsr bam_test_block              ; test the BAM bit of track/sector
        bne find_free_sec_done          ; bit set = free: return with Z clear
        inc sector                      ; try the next sector
        bne find_free_sec_loop          ; (falls through after sector 255: none found)
find_free_sec_none                      ; $A3F0
        lda #$00                        ; A = 0, Z set: no free sector
find_free_sec_done                      ; $A3F2
        rts

; Allocate the next block for the file on the current channel (the
; 1541 NXTTS). Starts from the T/S of the channel's current block.
; Emulation partitions: classic strategy - stay on the track while it has
; free blocks (sector + interleave, first free sector from there), else
; move away from the directory track, then try the other side; up to 3
; passes, then error 72. Native partitions: first free block at or above
; the current one, wrapping to track 1 sector 64 once.
; Out: track/sector = allocated block (already marked in the BAM)
alloc_next_block                        ; $A3F3
        jsr alloc_setup_channel         ; get T/S of the file's current block, load BAM, set limits; Z = native
        bne alloc_next_emul             ; emulation partition: 1541-style search
        jmp alloc_native_search         ; native: linear search from the current block
alloc_next_emul                         ; $A3FB
        lda #$03                        ; 3 passes for a file block
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  skip trick: the hidden LDA #$01 is the entry from alloc_next_dir_block (1 pass)
loc_A3FE
        lda #$01
        sta bam_temp_count              ; pass counter
alloc_track_loop                        ; $A403
        jsr bam_track_entry             ; A = free blocks on track track
        bne alloc_track_found           ; track has free blocks: choose a sector
        ldx alloc_dir_track             ; directory track
        cpx track
        beq alloc_disk_full             ; arrived on the directory track itself: disk full
        bcs alloc_track_down            ; current track is below the directory: keep moving down
        inc track                       ; above the directory: move one track up
        lda track
        cmp last_track_plus1            ; past the last track?
        bcc alloc_track_loop            ; no: test that track
        dex                             ; yes: change sides, continue at directory track - 1
alloc_other_side                        ; $A41B
        stx track
        dec bam_temp_count              ; one pass used up
        bne alloc_track_loop            ; more passes: test that track
        beq alloc_disk_full             ; no pass left: disk full
alloc_track_down                        ; $A424
        dec track                       ; move one track down
        lda track
        cmp first_track                 ; below the first track?
        bcs alloc_track_loop            ; no: test that track
        inx                             ; yes: change sides, continue at directory track + 1
        bne alloc_other_side            ; always
alloc_disk_full                         ; $A430
        lda #$72                        ; error 72 DISK FULL, command aborted via cmd_error
        jmp cmd_error
alloc_track_found                       ; $A435
        ldx track                       ; set sectors_per_track = sectors on the chosen track
        jsr track_limits
        jsr get_sector_interleave       ; A = sector interleave
        clc
        adc sector                      ; candidate = current sector + interleave
        sta sector
        lda sector
        cmp sectors_per_track           ; beyond the end of the track?
        bcc alloc_sector_search
        sbc sectors_per_track           ; wrap around (carry is set)
        sta sector
alloc_sector_search                     ; $A44E
        jsr find_free_sector            ; first free sector from the candidate upwards
        bne alloc_take_block            ; found: allocate it
alloc_from_sector0                      ; $A453
        lda #$00                        ; none: search the track again from sector 0
        sta sector
        jsr find_free_sector
        beq alloc_bam_error             ; the free count said > 0 but no bit is set
alloc_take_block                        ; $A45C
        jmp bam_alloc_block             ; mark track/sector allocated in the BAM
alloc_bam_error                         ; $A45F
        lda #$71                        ; error 71 DIR ERROR (BAM count and bitmap disagree)
        jmp jt_dos_error

; Allocate the next block for a directory chain (called when a new
; directory block has to be appended, $C393). track/sector = current block.
; Emulation: as alloc_next_block but with a single pass. Native: if the current
; block is in the root area (track 1, sector < 64) the search starts at
; the current directory header track, otherwise at the current block.
alloc_next_dir_block                    ; $A464
        jsr alloc_setup                 ; load BAM, set track limits; Z = native
        bne loc_A3FE                    ; emulation: common search, 1 pass (LDA #$01 hidden in the BIT at $A3FD)
        jmp alloc_native_dir            ; native: choose the start point for a directory block

; Sector interleave for the emulation partitions.
; Out: A = 1, except 3 on track 18 of a 1541/1571 partition (directory)
get_sector_interleave                   ; $A46C
        jsr partition_type              ; partition type
        cmp #$04                        ; 1581 / 1581 CP/M?
        bcc interleave_emul
        lda #$01                        ; yes: interleave 1
        rts
interleave_emul                         ; $A476
        lda #$01                        ; 1541/1571: interleave 1 ...
        ldx track
        cpx #$12                        ; ... except on track 18, the directory track
        bne interleave_done
        lda #$03                        ; where it is 3 as in the original DOS
interleave_done                         ; $A480
        rts

; Allocate the first block of a new file (the 1541 INTTS).
; Emulation: the closest track to the directory track that has free
; blocks, alternately below and above, first free sector on it; error 67
; when the tracks above are exhausted. Native: first free block from
; track 1 sector 64 (root directory current) or from the current
; subdirectory's header track / first directory sector upwards.
; Out: track/sector = allocated block
alloc_first_block                       ; $A481
        jsr alloc_setup                 ; load BAM, set track limits; Z = native
        bne alloc_first_emul            ; emulation: search around the directory track
        jmp alloc_native_first          ; native: start near the current directory
alloc_first_emul                        ; $A489
        lda #$00                        ; distance from the directory track
        sta bam_temp_count
        lda alloc_dir_track             ; start at the directory track
        sta track
alloc_first_loop                        ; $A493
        inc bam_temp_count              ; next distance
        lda track                       ; (track is never below the directory track here)
        cmp alloc_dir_track
        bcc alloc_first_above
        lda alloc_dir_track             ; track below = directory track - distance (carry is set)
        sbc bam_temp_count
        bcc alloc_first_above           ; underflow: nothing left below
        sta track
        cmp first_track                 ; below the first legal track?
        bcc alloc_first_above
        jsr bam_track_entry             ; A = free blocks on that track
        beq alloc_first_above           ; none: try the track above
        jmp alloc_from_sector0          ; take the first free sector of this track
alloc_first_above                       ; $A4B4
        lda alloc_dir_track             ; track above = directory track + distance
        clc
        adc bam_temp_count
        sta track
        cmp last_track_plus1            ; beyond the last track?
        bcs alloc_first_fail            ; yes: give up
        jsr bam_track_entry             ; A = free blocks on that track
        beq alloc_first_loop            ; none: increase the distance
        jmp alloc_from_sector0          ; take the first free sector of this track
alloc_first_fail                        ; $A4CA
        lda #$67                        ; error 67 ILLEGAL TRACK OR SECTOR: no track with free blocks
        jmp jt_dos_error

; Common set-up for the allocators. Entry alloc_setup_channel first loads track/sector
; from the header of the channel's active buffer. Then: select the BAM
; slot, load the BAM if none is loaded, set the track limits
; alloc_dir_track/first_track/last_track_plus1.
; Out: Z set = native partition, A = partition type
alloc_setup_channel                     ; $A4CF
        jsr header_get_active           ; track/sector = T/S header of the channel's active buffer: header_get_active

; Allocator set-up without fetching the channel's track/sector (see alloc_setup_channel).
alloc_setup                             ; $A4D2
        jsr bam_ensure_loaded           ; select BAM slot, load the BAM if nothing is loaded: bam_ensure_loaded
        jsr track_limits                ; set limits alloc_dir_track-last_track_plus1 (X = slot here, so sectors_per_track is not meaningful yet)
        jmp partition_is_native         ; Z = native partition

; Native part of alloc_next_dir_block: choose the start point for a new directory block.
alloc_native_dir                        ; $A4DB
        lda track                       ; current block on track 1 ...
        cmp #$01
        bne alloc_native_search
        lda sector                      ; ... sector 0-63 (root directory area)?
        cmp #$40
        bcs alloc_native_search         ; no: search upwards from the current block
        lda dir_hdr_track               ; yes: go to the current directory's header track
        bne alloc_native_near_dir       ; (always taken, the track is never 0)

; Native part of alloc_first_block: start at 1/64 when the current directory is the
; root (header 1/1), else at the subdirectory's header track and first
; directory sector; falls into the linear search.
alloc_native_first                      ; $A4EC
        lda dir_hdr_track               ; current directory header at 1/1 (root)?
        cmp #$01
        bne alloc_native_near_dir
        cmp dir_hdr_sector              ; A = 1: header sector 1?
        beq alloc_native_retry          ; root directory: start at track 1, sector 64
alloc_native_near_dir                   ; $A4F8
        sta track                       ; subdirectory: start on its header track ...
        lda dir_first_sector            ; ... at its first directory sector
        sta sector

; Native partitions: allocate the first free block at or after track/sector;
; if none up to the last track, search again from track 1 sector 64.
; Error 72 DISK FULL if that fails too.
; Out: track/sector = allocated block
alloc_native_search                     ; $A4FF
        jsr native_find_free            ; scan the bitmap upwards from track/sector
        bne alloc_native_take           ; found: allocate it
        lda #$01                        ; nothing up to the last track: wrap around to track 1
alloc_native_retry                      ; $A506
        sta track
        lda #$40                        ; sector 64 = first block behind the system area
        sta sector
        jsr native_find_free            ; scan once more
        bne alloc_native_take
        lda #$72                        ; error 72 DISK FULL, command aborted via cmd_error
        jmp cmd_error
alloc_native_take                       ; $A516
        jmp bam_alloc_store             ; A = BAM byte with the bit cleared, bam_ptr,Y -> byte: store and count

; Native partitions: scan the BAM bitmap upwards from track/sector to the
; last track for a free block (BAM groups are loaded as needed).
; Out: Z clear = found: track/sector = block, bam_ptr,Y -> its BAM byte,
;      A = that byte with the bit cleared;  Z set = none found
native_find_free                        ; $A519
        jsr bam_test_native             ; load BAM group, bam_ptr -> track bitmap, X = bit, Y = byte; fall into test
native_find_loop                        ; $A51C
        jsr bam_test_bit_msb            ; test bit X of bitmap byte Y
        bne native_find_done            ; bit set = free block found
        inc sector                      ; next sector
        inx                             ; next bit
        cpx #$08
        bcc native_find_loop
        ldx #$00                        ; next bitmap byte
        iny
        cpy #$20                        ; 32 bytes = 256 sectors per track
        bcc native_find_loop
        inc track                       ; next track (sector has wrapped to 0)
        lda track
        cmp last_track_plus1            ; last track + 1 reached?
        bne native_find_free            ; no: set up that track (may switch to another BAM group)
native_find_done                        ; $A538
        rts                             ; Z set when falling through = no free block

; Test the BAM bit of block track/sector of the current partition.
; Dispatches on the partition type (native / 1541+1571 / 1581 layout).
; Error 74 if the partition's BAM is not valid.
; Out: Z set = allocated (bit 0), Z clear = free (bit 1);
;      A = BAM byte with this bit inverted, bam_ptr,Y -> the BAM byte,
;      X = bit index (sector mod 8)
bam_test_block                          ; $A539
        jsr partition_type              ; partition type
        cmp #$04
        bcs bam_test_1581               ; types 4/5: 1581 BAM layout
        cmp #$01
        bne bam_test_1541               ; types 2/3: 1541/1571 BAM layout

; Native BAM bit test: one 32-byte bitmap per track, 8 tracks per sector,
; sector s = byte s/8, bit 7 first. See bam_test_block for the results.
bam_test_native                         ; $A544
        jsr bam_select_checked          ; select slot; error 74 if the BAM is invalid
        jsr bam_select_group            ; make sure the BAM group holding track track is loaded
        jsr bam_native_track_ptr        ; bam_ptr -> 32-byte bitmap of the track
        jsr sector_to_bit_index         ; X = sector mod 8, Y = sector / 8

; Test bit X (mask table bit_mask_msb_first, bit 7 first) of the byte at bam_ptr,Y.
; Out: Z from the bit, A = byte with the bit inverted
bam_test_bit_msb                        ; $A550
        lda (bam_ptr),y                 ; isolate the block's bit (bit 7 = lowest sector)
        and bit_mask_msb_first,x
        php                             ; keep Z: set = allocated, clear = free
        lda (bam_ptr),y                 ; return the byte with that bit inverted
        eor bit_mask_msb_first,x
        plp
        rts

; Bit masks for the native BAM: sector mod 8 = 0 is bit 7.
bit_mask_msb_first                      ; $A55D
        !byte $80,$40,$20,$10,$08,$04,$02,$01 ; $A55D

; 1581 BAM bit test: 6-byte entry per track (free count + 5 bitmap bytes),
; bit 0 first.
bam_test_1581                           ; $A565
        jsr bam_1581_track_entry        ; bam_ptr -> 6-byte entry of the track

; CBM-layout bit test with bam_ptr -> track entry: skip the count byte, then
; test bit (sector mod 8) of bitmap byte (sector / 8). Mask table bit_mask_lsb_first.
bam_test_skip_count                     ; $A568
        jsr sector_to_bit_index         ; X = sector mod 8, Y = sector / 8
        iny                             ; skip the free-count byte of the entry
bam_test_bit_lsb                        ; $A56C
        lda (bam_ptr),y                 ; isolate the block's bit (bit 0 = lowest sector)
        and bit_mask_lsb_first,x
        php                             ; keep Z: set = allocated, clear = free
        lda (bam_ptr),y                 ; return the byte with that bit inverted
        eor bit_mask_lsb_first,x
        plp
        rts

; 1541/1571 BAM bit test. Tracks 1-35: 4-byte entry at track*4 of block
; 18/0 (first page). Tracks 36-70 (1571): 3 bitmap bytes at (track-36)*3
; of block 53/0 (second page).
bam_test_1541                           ; $A579
        jsr bam_select_checked          ; select slot; error 74 if the BAM is invalid
        lda track                       ; track 36 or higher (second side of a 1571)?
        cmp #$24
        bcc bam_test_1541_side0         ; no: entry in block 18/0
        inc bam_ptr_hi                  ; second buffer page = BAM block 53/0
        lda track                       ; bitmap offset = (track - 36) * 3
        sec
        sbc #$24
        sta bam_ptr
        asl
        clc
        adc bam_ptr
        sta bam_ptr
        jsr sector_to_bit_index         ; X = sector mod 8, Y = sector / 8
        jmp bam_test_bit_lsb            ; test; there is no count byte in block 53/0
bam_test_1541_side0                     ; $A597
        lda track                       ; entry offset = track * 4
        asl
        asl
        sta bam_ptr
        jmp bam_test_skip_count         ; test, skipping the count byte

; Split sector sector into bitmap coordinates.
; Out: X = sector mod 8 (bit index), Y = sector / 8 (byte offset)
sector_to_bit_index                     ; $A5A0
        lda sector                      ; bit index = sector mod 8
        and #$07
        tax
        lda sector                      ; byte offset = sector / 8
        lsr
        lsr
        lsr
        tay
        rts

; Bit masks for the Commodore BAM layouts: sector mod 8 = 0 is bit 0.
bit_mask_lsb_first                      ; $A5AC
        !byte $01,$02,$04,$08,$10,$20,$40,$80 ; $A5AC

; Point bam_ptr/bam_ptr_hi at the BAM entry of track track (current partition).
; Emulation types: -> the track's free-count byte.
;   Out: A = free blocks on the track (Z set = none), Y = 0, carry clear
; Native: -> the track's 32-byte bitmap (there is no count byte).
;   Out: Y = 0, carry set
; X = BAM slot. Error 74 if the BAM is not valid.
bam_track_entry                         ; $A5B4
        jsr partition_type              ; partition type
        cmp #$04
        bcs bam_1581_track_entry        ; types 4/5: 1581 layout
        cmp #$01
        bne bam_1541_track_entry        ; types 2/3: 1541/1571 layout
        jsr bam_select_checked          ; native: select slot; error 74 if the BAM is invalid
        jsr bam_select_group            ; make sure the BAM group holding track track is loaded

; Native: add (track mod 16) * 32 to bam_ptr/bam_ptr_hi = offset of the track's
; bitmap inside the loaded 16-track BAM group. Out: Y = 0, carry set.
bam_native_track_ptr                    ; $A5C5
        lda track                       ; track * 32 (low 8 bits) ...
        asl
        asl
        asl
        asl
        asl
        bcc bam_native_ptr_add          ; ... bit 3 of the track selects the second sector of the group
        inc bam_ptr_hi
bam_native_ptr_add                      ; $A5D0
        clc                             ; add to the buffer start
        adc bam_ptr
        sta bam_ptr
        ldy #$00
        sec                             ; carry set = no free-count byte
        rts

; 1581: point bam_ptr/bam_ptr_hi at the 6-byte BAM entry of track track: offset
; $10 + (track-1)*6 in BAM sector 1 (tracks 1-40, first page) or sector 2
; (tracks 41-80, second page). Out: A = free count, Y = 0, carry clear.
bam_1581_track_entry                    ; $A5D9
        jsr bam_select_checked          ; select slot; error 74 if the BAM is invalid
        lda track
        cmp #$29                        ; track 41 or higher?
        bcc bam_1581_entry_calc
        inc bam_ptr_hi                  ; yes: second BAM sector = second buffer page
        sbc #$28                        ; track - 40 (carry is set)
bam_1581_entry_calc                     ; $A5E6
        asl                             ; offset = track*2 + track*4 + $0A = $10 + (track-1)*6
        sta bam_ptr
        asl
        clc
        adc bam_ptr
        adc #$0A
        sta bam_ptr

; Return the free-count byte at bam_ptr: A = count, Y = 0, carry clear.
bam_read_free_count                     ; $A5F1
        ldy #$00                        ; A = free blocks on the track
        lda (bam_ptr),y
        clc                             ; carry clear = count byte present
        rts

; 1541/1571: point bam_ptr at the free-count byte of track track in block
; 18/0: track*4 for tracks 1-35, $DD + (track-36) for tracks 36-70.
bam_1541_track_entry                    ; $A5F7
        jsr bam_select_checked          ; select slot; error 74 if the BAM is invalid
        lda track
        cmp #$24                        ; track 36 or higher (second side of a 1571)?
        bcc bam_1541_entry_side0
        adc #$B8                        ; yes: count is at $DD + (track-36) of block 18/0 (carry set: +$B9)
        bne bam_1541_entry_set          ; always
bam_1541_entry_side0                    ; $A604
        asl                             ; tracks 1-35: entry offset = track * 4
        asl
bam_1541_entry_set                      ; $A606
        sta bam_ptr
        jmp bam_read_free_count

; Select the BAM slot of the current partition and insist that its BAM
; is valid: error 74 DRIVE NOT READY if bam_slot_invalid,slot has bit 7 set.
; Out: X = slot, bam_ptr/bam_ptr_hi -> BAM buffer
bam_select_checked                      ; $A60B
        jsr bam_select_slot
        lda bam_slot_invalid,x          ; bit 7 set = partition not initialised, BAM invalid
        bpl bam_select_ok
        lda #$74                        ; error 74 DRIVE NOT READY
        jmp jt_dos_error
bam_select_ok                           ; $A618
        rts

; Recalculate the blocks-free total (bam_free_lo/bam_free_hi,slot) of the current
; partition from its BAM. Emulation types: sum of the per-track counts
; except the directory track. Native: count the 1 bits of all tracks,
; skipping sectors 0-63 of track 1, paging through the BAM groups.
; Out: X = 0, track preserved
count_blocks_free                       ; $A619
        jsr bam_select_slot
        ldx #$01                        ; set the track limits alloc_dir_track-last_track_plus1
        jsr track_limits
        ldx bam_slot
        lda #$00                        ; blocks free = 0
        sta bam_free_lo,x
        sta bam_free_hi,x
        jsr partition_is_native         ; native partition?
        beq count_native                ; yes: count bits
        lda track                       ; emulation: sum the per-track counts; save the current track
        pha
        ldx first_track                 ; start one below the first track
        dex
        stx track
count_emul_loop                         ; $A63A
        inc track                       ; next track
        lda track
        cmp alloc_dir_track             ; the directory track is not counted
        beq count_emul_loop
        cmp last_track_plus1            ; past the last track?
        bcs count_emul_done             ; yes: done
        jsr bam_track_entry             ; bam_ptr,Y -> free count of the track
        lda (bam_ptr),y
        clc
        ldx bam_slot                    ; add it to the 16-bit total of this slot
        adc bam_free_lo,x
        sta bam_free_lo,x
        bcc count_emul_loop             ; no carry: next track
        inc bam_free_hi,x               ; carry into the high byte
        bne count_emul_loop             ; always
count_emul_done                         ; $A65E
        pla                             ; restore the current track
        sta track
        ldx #$00
        rts

; Native blocks-free count: walk the 32-byte bitmaps of tracks 1..last.
count_native                            ; $A664
        lda track                       ; save the current track
        pha
        jsr bam_flush_reset             ; make sure BAM group 0 (tracks 1-15) is in the buffer: bam_flush_reset
        lda #$01                        ; begin with track 1
        sta track
        lda #$20                        ; its bitmap is at offset $20 of the first BAM sector
        sta bam_ptr
        ldy #$08                        ; skip 8 bytes: sectors 0-63 of track 1 are not counted
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  skip trick: hidden LDY #$00 is the loop entry for every further track
loc_A675
        ldy #$00
        lda #$00                        ; free blocks on this track = 0
        sta bam_temp_count
count_native_byte                       ; $A67C
        ldx #$08                        ; 8 bits per bitmap byte
        lda (bam_ptr),y
count_native_bit                        ; $A680
        asl                             ; next bit into carry (bit 7 first)
        bcc count_native_next_bit       ; 0 = allocated
        inc bam_temp_count              ; 1 = free: count it
        beq count_native_carry          ; 256 free: the 8-bit count wrapped, add $100 to the total directly
count_native_next_bit                   ; $A688
        dex
        bne count_native_bit
        iny
        cpy #$20                        ; 32 bitmap bytes per track
        bcc count_native_byte
        ldx bam_slot                    ; add the track's count to the total of this slot
        lda bam_free_lo,x
        clc
        adc bam_temp_count
        sta bam_free_lo,x
        bcc count_native_next_trk
count_native_carry                      ; $A69F
        ldx bam_slot                    ; carry into the high byte
        inc bam_free_hi,x
count_native_next_trk                   ; $A6A5
        inc track                       ; next track
        lda track
        cmp last_track_plus1            ; last track + 1: finished
        beq count_native_done
        lda bam_ptr                     ; advance to the next 32-byte bitmap
        clc
        adc #$20
        sta bam_ptr
        bne loc_A675                    ; still inside the page
        inc bam_ptr_hi                  ; next buffer page
        lda bam_ptr_hi
        and #$01                        ; odd page = second sector of the group: carry on
        bne loc_A675
        jsr bam_next_group              ; both pages done: load the next BAM group (resets bam_ptr/bam_ptr_hi): bam_next_group
        lda bam_group,x                 ; group number wrapped to 0 = all 16 groups done
        bne loc_A675                    ; no: continue in the new group
count_native_done                       ; $A6C7
        pla                             ; restore the current track
        sta track
        ldx #$00
        rts

; N (NEW) command: N[part]:name[,id] - create an empty file system in a
; partition of type 1-5 (error 77 otherwise). All files open on the
; partition are closed. Native and 1581 types: a header block is built
; and written; 1541/1571: the header is part of the BAM block. The first
; directory block is emptied and a fresh BAM is built and written, then
; the partition is re-initialised. Without an ID the old ID is kept.
; In a native partition N only works while the root directory is
; current; inside a subdirectory it silently does nothing.
cmd_new                                 ; $A6CD
        jsr parse_one_name              ; locate the ':' in the command; syntax error 34 if missing: parse_one_name
        jsr resolve_first_name          ; evaluate the partition number / path; error 74 if unusable: resolve_first_name
        jsr led_activity_on             ; activity LED on: led_activity_on
        jsr partition_type              ; type of the selected partition
        beq new_bad_partition           ; 0: partition does not exist
        cmp #$06                        ; types 1-5 (native, 1541, 1571, 1581, 1581 CP/M) can be formatted
        bcc new_partition_ok
new_bad_partition                       ; $A6DF
        lda #$77                        ; error 77 SELECTED PARTITION ILLEGAL
        jmp dos_error
new_partition_ok                        ; $A6E4
        jsr bam_select_slot
        lda #$00                        ; declare the BAM slot valid so that the BAM routines accept it
        sta bam_slot_invalid,x
        jsr channels_free_partition     ; close every file open on this partition: channels_free_partition
        ldx name2_index                 ; index behind the first comma (= command length if there is none)
        cpx cmd_len                     ; no ',id' given?
        beq new_without_id              ; none: keep the existing ID
        lda cmd_buf,x                   ; take the two ID characters from the command
        sta disk_id
        lda cmd_buf+1,x
        sta disk_id+1
        jsr partition_dir_track         ; directory header track of the partition known?
        bne new_do_format               ; yes
        txa                             ; (A is overwritten by the callee at once)
        jsr dir_reset_default           ; no: set the default header location for this partition type: dir_reset_default
        jmp new_do_format
new_without_id                          ; $A70E
        jsr partition_init              ; no ID: initialise the partition, which fetches the old ID from the BAM
        jsr partition_dir_track         ; directory header track still 0?
        bne new_do_format               ; no (normal case, partition_init sets a default)
        lda #$73                        ; error 73 DOS MISMATCH, command aborted via cmd_error
        jmp cmd_error
new_do_format                           ; $A71B
        ldx #$01                        ; set the track limits alloc_dir_track-last_track_plus1
        jsr track_limits
        jsr partition_is_native         ; native partition?
        bne new_emulation
        lda #$01                        ; native: is the current directory the root (header at 1/1)?
        cmp dir_hdr_track
        bne new_exit
        cmp dir_hdr_sector
        beq new_write_header            ; yes: build header, directory and BAM
new_exit                                ; $A731
        rts                             ; inside a subdirectory: N does nothing
new_emulation                           ; $A732
        cmp #$04                        ; 1541/1571: header is part of the BAM block, no separate header
        bcc new_clear_dir
new_write_header                        ; $A736
        jsr build_dir_header            ; build the header block in the directory buffer sys_buf
        jsr header_write                ; write it to the header T/S dir_hdr_track/dir_hdr_sector: header_write
new_clear_dir                           ; $A73C
        jsr clear_first_dir_block       ; read the first directory block and mark its 8 entries unused
        jsr dirblock_write              ; write it back to dir_hdr_track/dir_first_sector: dirblock_write
        jsr bam_create                  ; build a fresh BAM for this partition type
        jsr bam_flush                   ; write the BAM if it is still marked modified
        jmp partition_init              ; re-initialise the partition from disk and return

; Build a directory header block in the directory buffer sys_buf.
; Layout: 0/1 link to first directory block (dir_hdr_track/dir_first_sector), 2 DOS
; version, 4-$13 name padded with $A0, $16/$17 ID, $19/$1A DOS type,
; $14,$15,$18,$1B,$1C = $A0. 1581 types: version 'D', type '3D'.
; Native: version 'H', type '1H', and $20/$21 = T/S of the header block
; itself. Also used by MD for a subdirectory header ($BD88).
; In: disk name in the command at index file_name_pos, ID in disk_id/disk_id+1
build_dir_header                        ; $A74B
        jsr build_header_common         ; build the common (1581-style) header
        jsr partition_is_native         ; native partition?
        bne header_done                 ; no: done
        lda dir_hdr_track               ; native: offsets $20/$21 = T/S of this header block itself
        sta sys_buf+32
        lda dir_hdr_sector
        sta sys_buf+33
        lda #$48                        ; DOS version 'H'
        ldx #$31                        ; DOS type '1' ...
        tay                             ; ... 'H'
        jmp header_set_dos_type

; Build the 1581-style header in sys_buf (see build_dir_header).
build_header_common                     ; $A767
        jsr clear_dir_buffer            ; zero the directory buffer
        lda dir_hdr_track               ; offsets 0/1: link to the first directory block
        sta sys_buf
        lda dir_first_sector
        sta sys_buf+1
        ldx #$18                        ; fill offsets $04-$1C with shifted spaces
        lda #$A0
header_pad_loop                         ; $A77A
        sta sys_buf+4,x
        dex
        bpl header_pad_loop
        ldx file_name_pos               ; index of the disk name in the command
        ldy #$00
header_name_loop                        ; $A785
        lda cmd_buf,x                   ; copy the name up to a comma, ...
        cmp #$2C
        beq header_name_done
        sta sys_buf+4,y
        inx
        cpx cmd_len                     ; ... the end of the command ...
        bcs header_name_done
        iny
        cpy #$10                        ; ... or 16 characters
        bcc header_name_loop
header_name_done                        ; $A799
        lda disk_id                     ; offsets $16/$17: disk ID
        sta sys_buf+22
        lda disk_id+1
        sta sys_buf+23
        lda #$44                        ; DOS version 'D' (1581)
        ldx #$33                        ; DOS type '3' ...
        ldy #$44                        ; ... 'D'
header_set_dos_type                     ; $A7AB
        sta sys_buf+2                   ; offset 2: DOS version
        stx sys_buf+25                  ; offsets $19/$1A: DOS type
        sty sys_buf+26
header_done                             ; $A7B4
        rts

; Fill the directory buffer sys_buf-$22FF with zero. Out: A = X = 0.
clear_dir_buffer                        ; $A7B5
        lda #$00
        tax
clear_dir_buf_loop                      ; $A7B8
        sta sys_buf,x                   ; 256 bytes of sys_buf
        inx
        bne clear_dir_buf_loop
        rts

; Read the first directory block and mark all 8 entries unused (bytes
; 0-2 of each 32-byte entry zeroed), link = 00/$FF. Result in sys_buf;
; the caller writes it back.
clear_first_dir_block                   ; $A7BF
        jsr dirblock_read               ; read block dir_hdr_track/dir_first_sector (first directory block) into sys_buf: dirblock_read
        ldx #$00
clear_dir_entry_loop                    ; $A7C4
        lda #$00                        ; clear bytes 0-2 of the entry (block link / file type = unused)
        sta sys_buf,x
        sta sys_buf+1,x
        sta sys_buf+2,x
        txa                             ; next 32-byte directory entry
        clc
        adc #$20
        tax
        bne clear_dir_entry_loop        ; 8 entries per block
        beq dir_block_set_last          ; always

; Make sys_buf an empty directory block: all zero, link = 00/$FF.
build_empty_dir_block                   ; $A7D8
        jsr clear_dir_buffer            ; zero the whole directory buffer
dir_block_set_last                      ; $A7DB
        lda #$FF                        ; link 00/$FF: last block of the chain
        sta sys_buf+1
        rts

; Create a fresh BAM for the current partition in its cache slot: clear
; the 512-byte buffer, mark it modified and jump to the builder for the
; partition type (table at bam_create_table). Used by N and by validate ($9CB8).
; In: disk name in the command buffer (1541/1571), ID in disk_id/disk_id+1
bam_create                              ; $A7E1
        jsr bam_select_slot
        jsr bam_buffer_clear            ; zero both pages of the BAM buffer
        ldx bam_slot
        lda #$01                        ; mark the BAM as modified
        sta bam_dirty,x
        jsr partition_type              ; partition type 1-5
        asl                             ; word index; the table base is 2 below bam_create_table because type 0 never gets here
        tax
        lda bam_create_table-2,x
        sta jump_vector
        lda bam_create_table-1,x
        sta $2BDD
        jmp (jump_vector)               ; jump to the BAM builder for this partition type

; BAM builders by partition type 1-5 (indexed with type*2 from 2 below).
bam_create_table                        ; $A803
        !word bam_create_native         ; $A803  1 native, 2 1541, 3 1571, 4 1581, 5 1581 CP/M
        !word bam_create_1541           ; $A805
        !word bam_create_1571           ; $A807
        !word bam_create_1581           ; $A809
        !word bam_create_1581           ; $A80B

; Native BAM: 32 sectors, track 1 sectors 2-33, written here in 16 groups
; of two sectors. First sector: 2 = 'H', 3 = $B7 (complement), 4/5 = ID,
; 6 = $C0, 8 = last track; from $20 on one 32-byte bitmap per track
; (track t at t*32 across the sectors; 1 = free, bit 7 = lowest sector).
; Track 1 starts with sectors 0-34 allocated (system, header 1/1, BAM,
; first directory block 1/34). Blocks free = tracks*256 - 64.
bam_create_native                       ; $A80D
        ldy #$02                        ; offset 2: DOS version 'H'
        lda #$48
        sta (bam_ptr),y
        iny
        eor #$FF                        ; offset 3: its complement ($B7)
        sta (bam_ptr),y
        iny
        jsr bam_put_disk_id             ; offsets 4/5: disk ID; Y = 6 afterwards
        lda #$C0                        ; offset 6: $C0 (I/O byte as in a 1581 BAM)
        sta (bam_ptr),y
        ldy #$08                        ; offset 8: last track number of the partition
        ldx last_track_plus1
        dex
        txa
        sta (bam_ptr),y
        ldy #$24                        ; offset $24 = bitmap byte of track 1 for sectors 32-39:
        lda #$1F                        ; sectors 32-34 used; with the zeroed bytes before it, 0-34 are allocated
        sta (bam_ptr),y
        iny
        lda #$00
        ldx bam_slot                    ; BAM group 0 (tracks 0-15) is the one in the buffer
        sta bam_group,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  skip trick: hidden LDY #$00 is the loop entry for groups 1-15
loc_A839
        ldy #$00
        lda #$FF                        ; everything else: free
        jsr bam_buffer_fill             ; fill from offset Y to the end of both pages
        jsr bam_write_back              ; write the two BAM sectors of this group: bam_write_back
        inc bam_group,x                 ; next group of 16 tracks
        lda bam_group,x
        cmp #$10                        ; all 16 groups (track 1, sectors 2-33) written?
        bcc loc_A839                    ; no: next group, completely $FF
        lda last_track_plus1            ; blocks free = tracks * 256 - 64:
        sbc #$02                        ; high byte = last track - 1 (carry is set)
        sta bam_free_hi,x
        lda #$C0                        ; low byte = 256 - 64
        sta bam_free_lo,x
        rts

; 1581 BAM (types 4 and 5): every track 40 free / $FF x5; the directory
; track 36 free with sectors 0-3 allocated. Both BAM sectors get the
; header: link, 'D', $BB, ID, $C0. Then the free blocks are counted.
bam_create_1581                         ; $A85B
        lda first_track                 ; from the first track ...
        sta track
bam1581_track_loop                      ; $A860
        jsr bam_1581_track_entry        ; bam_ptr -> 6-byte BAM entry of the track, Y = 0
        lda #$28                        ; 40 blocks free
        sta (bam_ptr),y
        lda #$FF                        ; bitmap bytes 1-5: all free
bam1581_fill_loop                       ; $A869
        iny
        sta (bam_ptr),y
        cpy #$05
        bcc bam1581_fill_loop
        inc track
        lda track
        cmp last_track_plus1            ; ... to the last track
        bcc bam1581_track_loop
        lda dir_hdr_track               ; directory header track (40):
        sta track
        jsr bam_1581_track_entry
        lda #$24                        ; 36 blocks free
        sta (bam_ptr),y
        iny
        lda #$F0                        ; sectors 0-3 used: header, two BAM sectors, first directory block
        sta (bam_ptr),y
        jsr bam_select_slot             ; reset bam_ptr/bam_ptr_hi to the start of the buffer
        lda dir_hdr_track               ; BAM sector 1: link = directory track ...
        ldx #$02                        ; ... sector 2
        jsr bam1581_put_header
        inc bam_ptr_hi                  ; second page = BAM sector 2
        lda #$00                        ; link 00/$FF: last block
        ldx #$FF
        jsr bam1581_put_header
        dec bam_ptr_hi                  ; back to the first page
        jmp count_blocks_free           ; count the free blocks and return

; Write a 1581 BAM sector header at bam_ptr: 0 = A (link track), 1 = X (link
; sector), 2 = 'D', 3 = $BB, 4/5 = disk ID, 6 = $C0.
bam1581_put_header                      ; $A8A3
        ldy #$00                        ; offset 0: link track
        sta (bam_ptr),y
        iny
        txa                             ; offset 1: link sector
        sta (bam_ptr),y
        iny
        lda #$44                        ; offset 2: DOS version 'D'
        sta (bam_ptr),y
        iny
        eor #$FF                        ; offset 3: its complement ($BB)
        sta (bam_ptr),y
        iny
        jsr bam_put_disk_id             ; offsets 4/5: disk ID
        lda #$C0                        ; offset 6: I/O byte $C0 (1581: verify on, check header CRC)
        sta (bam_ptr),y
        rts

; 1541 BAM: build block 18/0 and count the free blocks.
bam_create_1541                         ; $A8BE
        jsr build_1541_bam_block        ; build block 18/0 in the BAM buffer
        jmp count_blocks_free           ; count the free blocks and return

; Build a 1541 BAM/header block (18/0) at bam_ptr from run-length tables:
; link 18/1, version 'A', 35 track entries (count + 3 bitmap bytes;
; track 18 with sectors 0 and 1 allocated), $A0 padding and DOS type '2A'
; at $A5. Then the disk name ($90-$9F) and ID ($A2/$A3) are copied from
; the command.
; Out: Y = $A4
build_1541_bam_block                    ; $A8C4
        ldy #$00                        ; Y = offset in the block
        ldx #$00                        ; X = run number 0-8
bam1541_run_loop                        ; $A8C8
        lda bamtab_run_length,x         ; number of 4-byte groups in this run
        sta bam_temp_count
bam1541_entry_loop                      ; $A8CE
        lda bamtab_byte0,x              ; one group = one byte from each of the four tables
        sta (bam_ptr),y
        iny
        lda bamtab_byte1,x
        sta (bam_ptr),y
        iny
        lda bamtab_byte2,x
        sta (bam_ptr),y
        iny
        lda bamtab_byte3,x
        sta (bam_ptr),y
        iny
        dec bam_temp_count              ; run complete?
        bne bam1541_entry_loop
        inx
        cpx #$09                        ; 9 runs fill offsets $00-$AB
        bcc bam1541_run_loop
        ldy #$90                        ; disk name goes to offset $90
        ldx file_name_pos               ; index of the name in the command
bam1541_name_loop                       ; $A8F5
        lda cmd_buf,x                   ; copy up to a comma, ...
        cmp #$2C
        beq bam1541_put_id
        sta (bam_ptr),y
        inx
        cpx cmd_len                     ; ... the end of the command ...
        bcs bam1541_put_id
        iny
        cpy #$A0                        ; ... or 16 characters
        bcc bam1541_name_loop
bam1541_put_id                          ; $A908
        ldy #$A2                        ; disk ID goes to offsets $A2/$A3

; Store the two disk ID characters disk_id/disk_id+1 at bam_ptr,Y; Y = Y + 2.
bam_put_disk_id                         ; $A90A
        lda disk_id                     ; first ID character
        sta (bam_ptr),y
        iny
        lda disk_id+1                   ; second ID character
        sta (bam_ptr),y
        iny
        rts

; 1571 BAM: block 18/0 as for the 1541 plus offset 3 = $80 (double
; sided) and the free counts of tracks 36-70 at $DD-$FF; block 53/0
; (second page) gets the 3-byte bitmaps of tracks 36-70. Track 53 is
; marked completely allocated. Then the free blocks are counted.
bam_create_1571                         ; $A917
        jsr build_1541_bam_block        ; build block 18/0 as for a 1541
        ldy #$03                        ; offset 3: $80 = double sided
        lda #$80
        sta (bam_ptr),y
        ldx #$01                        ; runs 1-5 = the 35 track entries
        ldy #$DD                        ; free counts of tracks 36-70 go to offsets $DD-$FF
bam1571_count_run                       ; $A924
        lda bamtab_run_length,x         ; number of tracks in this zone
        sta bam_temp_count
        lda bamtab_byte0,x              ; free count of an empty track of the zone
bam1571_count_loop                      ; $A92D
        sta (bam_ptr),y
        iny
        dec bam_temp_count
        bne bam1571_count_loop
        inx
        cpx #$06
        bcc bam1571_count_run
        ldy #$EE                        ; offset $EE = track 53 (holds the second BAM block): no free blocks
        lda #$00
        sta (bam_ptr),y
        inc bam_ptr_hi                  ; second page = block 53/0
        ldx #$01                        ; runs 1-5 again
        ldy #$00                        ; bitmaps of tracks 36-70, 3 bytes each, from offset 0
bam1571_bits_run                        ; $A946
        lda bamtab_run_length,x         ; number of tracks in this zone
        sta bam_temp_count
bam1571_bits_loop                       ; $A94C
        lda bamtab_byte1,x              ; the three bitmap bytes of an empty track
        sta (bam_ptr),y
        iny
        lda bamtab_byte2,x
        sta (bam_ptr),y
        iny
        lda bamtab_byte3,x
        sta (bam_ptr),y
        iny
        dec bam_temp_count
        bne bam1571_bits_loop
        inx
        cpx #$06
        bcc bam1571_bits_run
        ldy #$33                        ; offsets $33-$35 = track 53: every sector allocated
        lda #$00
bam1571_clr_trk53                       ; $A96C
        sta (bam_ptr),y
        iny
        cpy #$36
        bcc bam1571_clr_trk53
        jmp count_blocks_free           ; count the free blocks (this also resets bam_ptr_hi) and return

; Run-length description of a fresh 1541 BAM block: run n consists of
; bamtab_run_length[n] groups of the four bytes bamtab_byte0[n], bamtab_byte1[n], bamtab_byte2[n],
; bamtab_byte3[n]. Runs 1-5 are the track zones (17, 1, 6, 6, 5 tracks) and
; are reused for the second side of a 1571.
bamtab_run_length                       ; $A976
        !byte $01,$11,$01,$06,$06,$05,$05,$01,$01 ; $A976  run lengths: header, 17+1+6+6+5 tracks, 5+1+1 trailer groups
bamtab_byte0                            ; $A97F
        !byte $12,$15,$11,$13,$12,$11,$A0,$A0,$A0 ; $A97F  byte 0: link track 18 / free counts 21,17,19,18,17 / $A0
bamtab_byte1                            ; $A988
        !byte $01,$FF,$FC,$FF,$FF,$FF,$A0,$32,$A0 ; $A988  byte 1: link sector 1 / bitmap (track 18: sectors 0,1 used) / '2' at $A5
bamtab_byte2                            ; $A991
        !byte $41,$FF,$FF,$FF,$FF,$FF,$A0,$41,$A0 ; $A991  byte 2: version 'A' / bitmap / 'A' at $A6
bamtab_byte3                            ; $A99A
        !byte $00,$1F,$07,$07,$03,$01,$A0,$A0,$00 ; $A99A  byte 3: 0 / bitmap for 21,19,19,18,17 sectors / $A0, last byte 0

; Clear both pages of the BAM buffer at bam_ptr/bam_ptr_hi.
; Entry bam_buffer_fill: fill with A from offset Y to the end of the first page
; and the whole second page. Out: Y = 0, bam_ptr_hi unchanged.
bam_buffer_clear                        ; $A9A3
        lda #$00                        ; fill value 0, from offset 0
        tay

; Fill the BAM buffer with A: first page from offset Y to its end, then
; the complete second page. In: A = fill byte, Y = start offset.
bam_buffer_fill                         ; $A9A6
        sta (bam_ptr),y                 ; first page from offset Y
        iny
        bne bam_buffer_fill
        inc bam_ptr_hi                  ; second page, all 256 bytes
bam_fill_page2                          ; $A9AD
        sta (bam_ptr),y
        iny
        bne bam_fill_page2
        dec bam_ptr_hi                  ; restore the pointer
        rts

; ==========================================================================
; B - block commands.  The letter after the '-' selects the sub command
; from blk_sub_chars: B-A allocate, B-F free, B-R read, B-W write, B-E execute,
; B-P buffer pointer; shifted R / W are the raw forms used by U1 / U2.
; ==========================================================================
cmd_block                               ; $A9B5
        ldy #$00
        ldx #$00
        lda #$2D                        ; find the '-'
        jsr scan_for_char
        bne loc_A9C6
blk_syntax_31                           ; $A9C0
        jmp syntax_error_31
blk_syntax_30                           ; $A9C3
        jmp syntax_error_30
loc_A9C6
        txa                             ; must be the second character
        bne blk_syntax_30
        ldx #$07
        lda cmd_buf,y
blk_find_sub                            ; $A9CE
        cmp blk_sub_chars,x
        beq blk_dispatch
        dex
        bpl blk_find_sub
        bmi blk_syntax_31
blk_dispatch                            ; $A9D8
        txa                             ; bit 7: called from the B command
        ora #$80
        sta cmd_index
        jsr blk_parse_params
        lda cmd_index
        asl
        tax
        lda blk_sub_tab+1,x
        sta tmp1
        lda blk_sub_tab,x
        sta tmp0

; Jump through the vector in $50/$51.
jump_via_50                             ; $A9F0
        jmp (tmp0)

; Skip to the parameters behind the ':' (or the 4th character) and parse
; them.
blk_parse_params                        ; $A9F3
        ldy #$00
        ldx #$00
        lda #$3A                        ; find the ':'
        jsr scan_for_char
        bne parse_dec_params
        ldy #$03

; Parse up to four decimal parameters separated by space, cursor-right
; or comma, starting at command buffer index Y.
; Out: values in file_sector+n (low) / file_track+n (high), count in param_count.
parse_dec_params                        ; $AA00
        lda cmd_buf,y
        cmp #$20                        ; skip space, cursor-right and comma
        beq pdp_next
        cmp #$1D
        beq pdp_next
        cmp #$2C
        bne pdp_number
pdp_next                                ; $AA0F
        iny
        cpy cmd_len
        bcc parse_dec_params
        rts
pdp_number                              ; $AA15
        jsr parse_decimal
        inc param_count                 ; one more parameter
        ldy parse_index
        cpx #$04                        ; at most four
        bcc pdp_next
        bcs blk_syntax_30

; Parse one decimal number (up to three digits) at index Y.
; Out: stored in the parameter tables at index param_count; X = digit count.
parse_decimal                           ; $AA24
        lda #$00
        sta tmp0
        sta tmp1
        sta tmp3
        ldx #$FF
pd_digit                                ; $AA2E
        lda cmd_buf,y
        cmp #$40                        ; stop at the first non-digit
        bcs pd_convert
        cmp #$30
        bcc pd_convert
        and #$0F
        pha
        lda tmp1                        ; shift the previous digits up
        sta tmp2
        lda tmp0
        sta tmp1
        pla
        sta tmp0
        iny
        cpy cmd_len
        bcc pd_digit
pd_convert                              ; $AA4C
        sty parse_index
        clc
        lda #$00
loc_AA52
        inx
        cpx #$03
        bcs loc_AA66
        ldy tmp0,x                      ; digit count times its weight
loc_AA59
        dey
        bmi loc_AA52
        adc dec_weights,x
        bcc loc_AA59
        clc
        inc tmp3                        ; overflow into the high byte
        bne loc_AA59
loc_AA66
        pha
        ldx param_count
        lda tmp3
        sta file_track,x
        pla
        sta file_sector,x
        rts

; Decimal weights 1, 10, 100.
dec_weights                             ; $AA74
        !byte $01,$0A,$64               ; $AA74

; B-F: free block track/sector in the BAM.
block_free                              ; $AA77
        jsr blk_get_ts
        jsr partition_check_ready
        jsr bam_free_block              ; free the block
        jmp cmd_done

; B-A: allocate block track/sector.  If it is already in use the next
; free block is searched and reported with error 65 NO BLOCK.
block_allocate                          ; $AA83
        jsr blk_get_ts
        jsr partition_check_ready
        lda sector
        pha
        jsr find_free_sector            ; allocate it; Z set = was already allocated
        beq loc_AA9C
        pla
        cmp sector
        bne ba_error_65
        jsr bam_alloc_block             ; mark it
        jmp cmd_done
loc_AA9C
        pla
ba_search_next                          ; $AA9D
        lda #$00                        ; search upwards for a free block
        sta sector
        inc track
        beq ba_no_block
        lda last_track_plus1
        beq loc_AAB0
        cmp track
        bcc ba_no_block
        beq ba_no_block
loc_AAB0
        jsr find_free_sector
        beq ba_search_next
ba_error_65                             ; $AAB5
        lda #$65                        ; error 65 with the free block's address
        jsr jt_dos_error
ba_no_block                             ; $AABA
        lda #$65
        jsr cmd_error

; Get channel, track and sector from the parameters and read the block
; into the channel's buffer.
blk_read_block                          ; $AABF
        jsr blk_get_chan_ts
        jmp buffer_block_read           ; read the block

; Out: A = byte at the buffer pointer of the current channel.
blk_buffer_byte                         ; $AAC5
        jsr channel_buf_index
        lda (buf_ptrs,x)
        rts

; Read the block and prepare the channel for byte-wise reading: the
; first byte of the block becomes the index of the last valid byte.
blk_read_setup                          ; $AACB
        jsr blk_read_block
        lda #$00
        jsr buffer_set_ptr
        jsr blk_buffer_byte
        sta chan_last_index,y           ; byte 0 = index of the last data byte
        lda #$89                        ; status: ready to talk and listen
        sta chan_status,y
        rts

; B-R: read block; the first byte is taken as the data length.
block_read                              ; $AADF
        jsr blk_read_setup
        jsr direct_next_byte
        jmp cmd_done

; Raw block read entered from the sub command table.
block_read_raw                          ; $AAE8
        pha
        pha
        jmp u1_common

; U1 / UA: read a whole block (all 256 bytes are data).
user_u1                                 ; $AAED
        jsr blk_parse_params
u1_common                               ; $AAF0
        jsr blk_read_setup
        lda chan_last_index,y           ; all 256 bytes are data
        sta chan_data,y
        lda #$FF
        sta chan_last_index,y
        pla
        pla
        jmp cmd_done

; B-W: write block; the buffer pointer is stored in byte 0 as length.
block_write                             ; $AB03
        jsr blk_get_chan_ts
        jsr buffer_get_ptr              ; current buffer pointer
        tay
        dey
        cmp #$02
        bcs loc_AB11
        ldy #$01
loc_AB11
        lda #$00
        jsr buffer_set_ptr
        tya                             ; length goes into byte 0
        jsr buffer_put_byte_chk
        txa
        pha
        jsr blk_write_block
        pla
        tax
        ldy channel
        jmp blk_load_byte_done

; Raw block write entered from the sub command table.
block_write_raw                         ; $AB26
        pha
        pha
        jmp u2_common

; U2 / UB: write a whole block.
user_u2                                 ; $AB2B
        jsr blk_parse_params
u2_common                               ; $AB2E
        jsr blk_get_chan_ts
        jsr blk_write_block
        pla
        pla
        jmp cmd_done

; Write the channel's buffer to track/sector.  If the block is a BAM block
; currently held in the BAM cache, the cache is updated as well.
blk_write_block                         ; $AB39
        jsr buffer_block_write
        jsr bam_select_slot             ; is this block part of the cached BAM?
        lda #$00
        jsr buffer_set_ptr
        jsr partition_is_native
        ldx track
        ldy sector
        cmp #$06
        bcs bwb_rts
        cmp #$04
        bcs bwb_1581
        cmp #$02
        beq bwb_1541
        bcs bwb_1571
        cpx #$01                        ; native: track 1, sectors 2-33
        bne bwb_rts
        cpy #$02
        bcc bwb_rts
        cpy #$22
        bcs bwb_rts
        dey
        dey
        tya
        lsr
        ldx bam_slot
        cmp bam_group,x                 ; the group currently cached?
        bne bwb_rts
        tya
        lsr
        bcc bwb_copy_to_cache
        bcs bwb_second_page
bwb_rts                                 ; $AB77
        rts
bwb_1581                                ; $AB78
        cpx #$28                        ; 1581: directory track, sectors 1 and 2
        bne loc_AB82
        dey
        beq bwb_copy_to_cache
        dey
        beq bwb_second_page
loc_AB82
        rts
bwb_1571                                ; $AB83
        cpx #$35                        ; 1571: track 53 sector 0
        bne bwb_1541
        tya
        beq bwb_second_page
        rts
bwb_1541                                ; $AB8B
        cpx #$12                        ; 1541: track 18 sector 0
        bne loc_AB92
        tya
        beq bwb_copy_to_cache
loc_AB92
        rts
bwb_second_page                         ; $AB93
        inc bam_ptr_hi                  ; second cache page
bwb_copy_to_cache                       ; $AB95
        ldy #$00
loc_AB97
        lda (dir_ptr),y
        sta (bam_ptr),y
        iny
        bne loc_AB97
        rts

; B-E: read a block and execute it as code.
block_execute                           ; $AB9F
        jsr blk_read_block
        lda #$00
        sta tmp0
        lda buf_num                     ; buffer address = page 3 + buffer number
        clc
        adc #$03
        sta tmp1
        jsr jump_via_50
        jmp cmd_done

; B-P: set the buffer pointer of a channel.
block_pointer                           ; $ABB3
        jsr blk_get_channel
        lda buf_num
        asl
        tax
        lda $2C29                       ; new pointer value
        sta buf_ptrs,x
        jsr channel_buf_index
blk_load_byte_done                      ; $ABC2
        jsr direct_load_byte
        jmp cmd_done

; First parameter = channel number: find its channel and buffer.
; Out: buf_num = buffer number, X = 1.  Error 70 if not open.
blk_get_channel                         ; $ABC8
        lda file_sector                 ; channel number, must be below 15
        cmp #$0F
        bcc loc_ABD4
blk_no_channel                          ; $ABCF
        lda #$70                        ; error 70 NO CHANNEL
        jmp cmd_error
loc_ABD4
        sta sec_addr
        jsr channel_find_read
        bcs blk_no_channel
        jsr active_buffer
        sta buf_num
        ldx #$01
        rts

; Channel from parameter 0, then drive / track / sector from the next
; three parameters (blk_get_ts: drive / track / sector from parameters 0-2).
; Checks the block address (error 66) and that the drive number is 0
; (error 74).
blk_get_chan_ts                         ; $ABE3
        jsr blk_get_channel
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  X = 1: parameters follow the channel number

; Drive / track / sector from parameters 0-2.
blk_get_ts                              ; $ABE7
        ldx #$00
        lda $2C29,x
        sta track
        lda $2C2A,x
        sta sector
        lda file_sector,x               ; drive number must be 0
        bne blk_bad_drive
        lda cur_partition
        jsr partition_select_chk        ; re-select the current partition
        jsr check_track_sector          ; error 66 if illegal
        jmp led_activity_on
blk_bad_drive                           ; $AC04
        lda #$74                        ; error 74 DRIVE NOT READY
        jmp cmd_error

; Sub command letters of the B command.
blk_sub_chars                           ; $AC09
        !byte $41,$46,$52,$57,$45,$50,$D2,$D7 ; $AC09

; Handlers in the order of blk_sub_chars.
blk_sub_tab                             ; $AC11
        !word block_allocate            ; $AC11
        !word block_free                ; $AC13
        !word block_read                ; $AC15
        !word block_write               ; $AC17
        !word block_execute             ; $AC19
        !word block_pointer             ; $AC1B
        !word block_read_raw            ; $AC1D
        !word block_write_raw           ; $AC1F

; C - copy / concatenate files (the file form of the C command).
; Several sources sharing the target's directory entry mean 'append to
; an existing file'; otherwise a new target file is created.
copy_files                              ; $AC21
        jsr find_colon
        bne loc_AC29
        jmp cmd_syntax_31
loc_AC29
        jsr parse_names
        jsr resolve_names
        lda syntax_image                ; wildcards are not allowed in the target
        and #$55
        bne copy_check
        ldx file_name_pos
        lda cmd_buf,x
        cmp #$2A
        bne copy_check
copy_syntax                             ; $AC40
        jmp syntax_error_30
copy_check                              ; $AC43
        lda syntax_image
        and #$D9
        bne copy_syntax
        jsr search_all_names
        jsr copy_check_types
        lda file_count                  ; three or more names sharing one entry: append
        cmp #$03
        bcc copy_single
        lda file_partition
        cmp $2C11
        bne copy_single
        lda file_dir_index
        cmp $2C41
        bne copy_single
        lda file_dir_sector
        cmp $2C39
        bne copy_single
        lda file_dir_track
        cmp $2C31
        bne copy_single
        jsr check_file_found
        lda #$01
        sta parse_index
        jsr copy_open_source
        jsr channel_file_type
        bcs loc_AC8B
        cmp #$02
        bne loc_AC90
loc_AC8B
        lda #$64                        ; error 64 FILE TYPE MISMATCH
        jsr cmd_error
loc_AC90
        lda #$12
        sta sec_addr
        lda sa_channel+17
        sta sa_channel+18
        lda #$FF
        sta sa_channel+17
        jsr append_seek_end
        ldx #$02
        jsr copy_one_source
        jmp cmd_done
copy_single                             ; $ACAA
        jsr copy_create_target
        jmp cmd_done

; Create the target file (error 63 if it exists) and copy every source
; into it.
copy_create_target                      ; $ACB0
        jsr check_target_free           ; error 63 if the target exists
        lda file_partition
        jsr partition_select
        jsr open_internal_write
        jsr dir_create_entry
        ldx param_count

; Copy source file number X byte by byte to the target channel.
copy_one_source                         ; $ACC2
        stx parse_index
        jsr copy_open_source
        lda #$11
        sta sec_addr
        jsr channel_find_read
        jsr channel_file_type
        bne loc_ACD7
        jsr copy_rel_record
loc_ACD7
        lda #$08                        ; prime the EOI flag
        sta eoi_flag
        jmp copy_get
copy_put                                ; $ACDE
        jsr internal_put_byte           ; write the byte to the target
copy_get                                ; $ACE1
        jsr internal_get_byte           ; read a byte from the source
        lda #$80                        ; end of the source file?
        jsr chan_flag_test
        beq copy_put
        jsr channel_file_type
        beq copy_next_source
        jsr internal_put_byte
copy_next_source                        ; $ACF3
        ldx parse_index
        inx
        cpx file_count
        bcc copy_one_source
        lda #$12                        ; close the target
        sta sec_addr
        jmp close_channel

; Open source file parse_index for reading on the internal channel.
copy_open_source                        ; $AD03
        ldx parse_index
        lda file_dir_track,x            ; directory entry location of the source
        sta track
        lda file_dir_sector,x
        sta sector
        lda file_partition,x
        jsr partition_select
        jsr open_internal_read
        ldx parse_index
        lda file_dir_index,x
        jsr buffer_set_ptr
        ldx parse_index
        lda file_type_flags,x
        and #$07
        sta file_type
        lda #$00
        sta record_len
        jsr open_read_entry
        ldy #$01
        jsr channel_file_type
        beq loc_AD3D
        iny
loc_AD3D
        tya
        jmp buffer_set_ptr

; Relative file copy: carry the record position across (?).
copy_rel_record                         ; $AD41
        jsr rel_seek_end
        jsr rel_has_no_super
        bne loc_AD4D
        lda rel_group
        pha
loc_AD4D
        lda rel_side_index
        pha
        lda rel_side_num
        pha
        lda #$12
        sta sec_addr
        jsr channel_find_write
        jsr rel_end_position
        sta rel_block_offset
        pla
        sta rel_side_num
        pla
        sta rel_side_index
        jsr rel_has_no_super
        bne loc_AD6E
        pla
        sta rel_group
loc_AD6E
        jmp rel_extend_to

; All files must be ordinary file types (0-4), else error 64.
copy_check_types                        ; $AD71
        ldx #$00
loc_AD73
        lda file_type_flags,x
        and #$07
        cmp #$05
        bcs copy_type_error
        inx
        cpx file_count
        bcc loc_AD73
        rts
copy_type_error                         ; $AD83
        lda #$64                        ; error 64
        jmp cmd_error

; ==========================================================================
; S - scratch, plus the CMD specific S- sub commands:
;   S-8 / S-9  request a device number swap to 8 / 9
;   S-D        request a return to the default device number
;   S-C        send a SCSI command block to a device (pass-through)
; Everything else is the normal scratch at scratch_files.
; ==========================================================================
cmd_scratch                             ; $AD88
        lda cmd_buf+1
        cmp #$2D                        ; 'S-' ?
        bne s_scratch
        lda cmd_buf+2
        cmp #$43                        ; S-C
        beq scsi_command
        cmp #$38                        ; S-8
        beq s_swap_set
        cmp #$39                        ; S-9
        beq s_swap_set
        cmp #$44                        ; S-D
        bne s_scratch
        lda #$80                        ; bit 7 of swap_default: return to the default device
        sta swap_default
        rts
s_swap_set                              ; $ADA8
        and #$0F                        ; swap_request = 8 or 9: swap request
        sta swap_request
        rts
s_scratch                               ; $ADAE
        jmp scratch_files
s_syntax                                ; $ADB1
        jmp syntax_error_31

; S-C: SCSI Send (manual p. 9-39).  Command: 'S-C' device, buffer
; address low/high, then the SCSI command bytes.  The completion status
; is returned as the single byte of the next read from the command
; channel (00 OK, 02 check condition, 08 busy, ...).
scsi_command                            ; $ADB4
        lda cmd_len                     ; needs at least a 6-byte command block
        cmp #$0C
        bcc s_syntax
        sei
        jsr scsi_setup_cdb
        lda scsi_cdb                    ; opcode of the command block
        cmp #$2F
        beq scsi_verify_loop
scsi_run_once                           ; $ADC5
        jsr scsi_execute
scsi_reply_status                       ; $ADC8
        lda scsi_status                 ; status byte becomes the one-byte reply
        sta chan_data+31
        lda #$FF
        ldx #$23
        sta errbuf_ptr
        stx errbuf_ptr+1
        lda #$88                        ; status $88: ready, last byte
        sta chan_status+31
        rts

; Command block opcode $2F (verify): emulated by reading every block
; with opcode $28 into the work buffer, one block at a time (?).
scsi_verify_loop                        ; $ADDC
        jsr scsi_probe
        beq scsi_run_once
        lda #$28                        ; replace by opcode $28 (read)
        sta scsi_cdb
        lda scsi_cdb+8                  ; block count from the command block
        sta errbuf_ptr
        lda scsi_cdb+7
        sta errbuf_ptr+1
        lda #$00
        sta scsi_cdb+7
        lda #$01
        sta scsi_cdb+8
svl_block                               ; $ADFA
        jsr scsi_ptrs_reset
        lda #$00                        ; data go to the work buffer at work_block
        sta data_ptr
        lda #$52
        sta data_ptr+1
        jsr scsi_execute
        bne scsi_reply_status
        inc scsi_cdb+5                  ; next block address
        bne loc_AE17
        inc scsi_cdb+4
        bne loc_AE17
        inc scsi_cdb+3
loc_AE17
        ldx errbuf_ptr
        bne loc_AE1D
        dec errbuf_ptr+1
loc_AE1D
        dec errbuf_ptr
        bne svl_block
        ldx errbuf_ptr+1
        bne svl_block
        jmp scsi_reply_status

; Run the command once with a zero block count; restore the block.
scsi_probe                              ; $AE28
        lda #$00
        sta scsi_cdb+7
        sta scsi_cdb+8
        jsr scsi_execute
        pha
        jsr scsi_setup_cdb
        pla
        rts

; Copy the command descriptor block from the command buffer to scsi_cdb
; and set the data pointer data_ptr/data_ptr+1.
scsi_setup_cdb                          ; $AE39
        jsr cdb_clear
        lda cmd_buf+4                   ; data buffer address from the command
        sta data_ptr
        lda cmd_buf+5
        sta data_ptr+1
        ldx #$06                        ; command block starts at the 7th character
        ldy #$00
ssc_copy                                ; $AE4A
        lda cmd_buf,x
        sta scsi_cdb,y
        iny
        inx
        cpx cmd_len
        bcc ssc_copy
        rts

; Select the SCSI device named in the command and run the command.
; Out: A = scsi_status = status ($85 when the device does not answer).
scsi_execute                            ; $AE57
        lda cmd_buf+3                   ; device number from the command
        jsr scsi_select
        bne scsi_exec_run
        lda #$85                        ; status $85: no such device
        sta scsi_status
        rts
scsi_exec_run                           ; $AE65
        jsr srn_phases
        lda scsi_status
        rts

; OPEN of '#': direct access channel.  '#' alone takes any free buffer,
; '#n' asks for buffer n.  Error 70 if none is available.
open_direct_channel                     ; $AE6C
        ldx cmd_len
        dex                             ; just '#': any buffer
        bne odc_specific
        lda #$01
        jsr channel_alloc_read
        jmp odc_finish
odc_no_channel                          ; $AE79
        lda #$70
        jmp cmd_error
odc_specific                            ; $AE7E
        ldy #$01
        jsr parse_dec_params
        lda file_sector                 ; requested buffer number
        cmp #$1E
        bcs odc_no_channel
        sta buf_wanted
        jsr buffer_in_use               ; buffer in use?
        beq odc_no_channel
        lda #$00
        jsr channel_alloc_read
        ldx channel
        lda file_sector
        sta chan_buf_a,x
        tax
        lda #$00
        sta job_queue,x
        sta job_code_saved,x
odc_finish                              ; $AEA6
        ldx sec_addr
        lda sa_channel,x                ; bit 6: direct access channel
        ora #$40
        sta sa_channel,x
        ldy channel
        lda #$FF
        sta chan_last_index,y
        lda #$89                        ; status: talk and listen
        sta chan_status,y
        lda chan_buf_a,y                ; first byte read back is the buffer number
        sta chan_data,y
        asl
        tax
        lda #$01
        sta buf_ptrs,x
        lda #$0E                        ; file type 7 = direct access
        sta chan_file_type,y
        jmp cmd_done

; Make sure the current partition has been initialised.
; Out: A = 0 when ready.
partition_check_ready                   ; $AED0
        jsr partition_type
        cmp #$FF
        bne pcr_check
        lda #$00
        rts
pcr_check                               ; $AEDA
        jsr bam_select_slot
        lda bam_slot_invalid,x
        beq pcr_rts
        jsr partition_init
        ldx bam_slot
        lda bam_slot_invalid,x
pcr_rts                                 ; $AEEB
        rts

; I - initialize the partition named in the command.
cmd_initialize                          ; $AEEC
        jsr parse_partition_led
        jsr partition_type              ; 1581 types: back to the default directory first
        cmp #$04
        beq loc_AEFA
        cmp #$05
        bne ini_do
loc_AEFA
        jsr dir_reset_default
ini_do                                  ; $AEFD
        jsr partition_init
        jmp cmd_done

; Initialise the current partition: close its channels, mark the BAM
; slot invalid, read the BAM / header and take the DOS version byte and
; disk ID from it.
partition_init                          ; $AF03
        jsr channels_free_partition     ; close the channels of this partition
        lda #$00
        sta rel_flags
        jsr bam_select_slot
        lda #$FF                        ; $FF: not initialised
        sta bam_slot_invalid,x
        jsr partition_type              ; no partition, system or foreign: nothing to read
        beq pin_rts
        cmp #$FF
        beq pin_rts
        cmp #$06
        bcc pin_read
pin_rts                                 ; $AF20
        rts
pin_read                                ; $AF21
        jsr partition_dir_track
        bne loc_AF29
        jsr dir_reset_default
loc_AF29
        jsr bam_load_group0             ; load the BAM
        ldx bam_slot
        ldy #$02
        lda (bam_ptr),y                 ; DOS version byte
        sta bam_dos_version,x
        jsr partition_is_native
        beq pin_check_id
        cmp #$04
        bcc loc_AF50
pin_check_id                            ; $AF3F
        ldy #$03                        ; native / 1581: complement at offset 3 must match
        lda (bam_ptr),y
        eor #$FF
        ldx bam_slot
        cmp bam_dos_version,x
        bne pin_rts
        ldy #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_AF50
        ldy #$A2
        lda (bam_ptr),y                 ; disk ID
        sta disk_id
        iny
        lda (bam_ptr),y
        sta disk_id+1
        ldx bam_slot
        lda #$00                        ; partition is ready
        sta bam_slot_invalid,x
        jsr dir_setup
        jmp count_blocks_free

; Compare DOS version byte A with the one expected for the partition
; type.  Out: Z set when it matches (or A = 0).
dos_version_check                       ; $AF6B
        cmp #$00
        beq dvc_rts
        pha
        jsr partition_type
        tax
        pla
        cmp dos_version_tab,x           ; expected version byte
dvc_rts                                 ; $AF78
        rts

; Expected DOS version byte per partition type: -, 'H' native, 'A' 1541,
; 'A' 1571, 'D' 1581, 'D' 1581 CP/M.
dos_version_tab                         ; $AF79
        !byte $00,$48,$41,$41,$44,$44   ; $AF79

; Set the geometry limits used to check a block address on track X:
; first_track first track, last_track_plus1 last track + 1, sectors_per_track sectors on the track.
track_limits                            ; $AF7F
        stx sectors_per_track
        jsr partition_dir_track         ; directory track
        sta alloc_dir_track
        jsr partition_is_native
        beq tl_native
        cmp #$03
        beq tl_1571
        bcc tl_1541
        cmp #$06
        bcc tl_1581
        cmp #$FF
        beq tl_system
        rts
tl_system                               ; $AF9C
        lda #$01
        sta alloc_dir_track
        ldx #$00
tl_native                               ; $AFA3
        lda part_size_lo,x              ; native: last track from the partition size
        asl
        lda part_size_hi,x
        rol
        tax
        inx
        stx last_track_plus1
        ldx #$01                        ; first track 1, 256 sectors on every track
        stx first_track
        dex
        stx sectors_per_track
        rts
tl_1541                                 ; $AFBA
        lda #$24                        ; 1541: tracks 1-35
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
tl_1571                                 ; $AFBD
        lda #$47                        ; 1571: tracks 1-70
        sta last_track_plus1
        lda #$01
        sta first_track
        lda sectors_per_track
        ldx #$00
tl_zone                                 ; $AFCC
        cmp zone_first_track,x          ; find the speed zone of the track
        bcc loc_AFD4
        inx
        bne tl_zone
loc_AFD4
        dex
        lda zone_sectors,x              ; sectors per track in that zone
        sta sectors_per_track
        rts
tl_1581                                 ; $AFDC
        lda part_dir_sector,x           ; 1581: track limit from the table, 40 sectors
        sta last_track_plus1
        lda alloc_dir_track
        cmp #$28                        ; directory track of a sub-partition (?)
        bne loc_AFEB
        lda #$01
loc_AFEB
        sta first_track
        lda #$28
        sta sectors_per_track
        rts

; Reset the partition's directory pointers to the type's default:
; native 1/1, 1541 track 18, 1571 track 18, 1581 track 40.
dir_reset_default                       ; $AFF4
        jsr partition_is_native
        beq dir_set_root
        cmp #$04
        bcc drd_15x1
        lda #$28
        ldy #$51
        bne dir_set_current
drd_15x1                                ; $B003
        cmp #$02
        bne drd_1571
        ldy #$24
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
drd_1571                                ; $B00A
        ldy #$47
        lda #$12
        bne dir_set_current

; Directory = root (track 1, sector 1).
dir_set_root                            ; $B010
        lda #$01
        tay

; Store A / Y as directory track and second value for the current
; partition (tables in write-protected RAM).
dir_set_current                         ; $B013
        jsr ram_unprotect               ; enable writes to the protected RAM
        ldx cur_partition
        sta part_dir_track,x
        tya
        sta part_dir_sector,x
        jmp ram_protect                 ; protect again

; Make partition A the current one and set up its directory variables.
partition_select                        ; $B023
        jsr cfg_set_cur_partition

; Derive header track/sector and first directory sector for the current
; partition from its type.
dir_setup                               ; $B026
        jsr partition_dir_track
        bne dsu_store                   ; no directory track yet: use the default
        jsr dir_reset_default
        jsr partition_dir_track
dsu_store                               ; $B031
        sta dir_hdr_track
        lda #$00
        sta dir_hdr_sector
        jsr partition_is_native
        beq dsu_native
        cmp #$04
        bcc dsu_15x1
        cmp #$06
        bcc dsu_1581
        cmp #$FF
        bne loc_B059
        lda sys_start_hi                ; system partition: header at the system area start
        sta dir_hdr_track
        lda sys_start_lo
        sta dir_hdr_sector
        sta dir_first_sector
loc_B059
        rts
dsu_1581                                ; $B05A
        lda #$03                        ; 1581: directory starts at sector 3
        sta dir_first_sector
        rts
dsu_15x1                                ; $B060
        lda #$01                        ; 1541/1571: directory starts at sector 1
        sta dir_first_sector
        rts
dsu_native                              ; $B066
        jsr partition_dir_sector        ; native: header sector
        sta dir_hdr_sector
        cmp #$01                        ; root header 1/1: directory starts at sector 34
        bne loc_B077
        cmp dir_hdr_track
        bne loc_B077
        lda #$21
loc_B077
        clc                             ; otherwise right after the header
        adc #$01
        sta dir_first_sector
        rts

; Out: A = type of the current partition, X = partition number.
partition_type                          ; $B07E
        ldx cur_partition
        lda part_type,x
        rts

; Out: A = partition type, Z set when it is a native partition.
partition_is_native                     ; $B085
        ldx cur_partition
        lda part_type,x
        cmp #$01
        rts

; Out: A = directory track of the current partition.
partition_dir_track                     ; $B08E
        ldx cur_partition
        lda part_dir_track,x
        rts

; Out: A = directory sector (native) / track limit of the partition.
partition_dir_sector                    ; $B095
        ldx cur_partition
        lda part_dir_sector,x
        rts

; ==========================================================================
; M-R / M-W / M-E memory commands (reached from the M command front end).
; Command: 'M-' letter, address low, address high, count, data...
; ==========================================================================
cmd_memory                              ; $B09C
        lda cmd_buf+1
        cmp #$2D                        ; '-' ?
        bne cmd_syntax_31
        lda cmd_buf+3                   ; address from the command
        sta tmp0
        lda cmd_buf+4
        sta tmp1
        ldy #$00
        lda cmd_buf+2
        cmp #$52                        ; R
        beq mem_read
        cmp #$57                        ; W
        beq mem_write
        cmp #$45                        ; E
        bne cmd_syntax_31
        lda tmp1
        cmp #$80                        ; refuse via1_prb-$FEFF
        bcc mem_exec_check
        cmp #$FF
        bcs mem_exec_check
        rts

; M-E.  Execution of addresses via1_prb-$FEFF is silently refused.  Code at
; $0600 whose bytes 8-15 match mem_exec_signature is not run either: that is a known
; host program's drive routine (it calls 1541 ROM addresses), which is
; diverted to a built-in replacement at lock_toggle.
mem_exec_check                          ; $B0C9
        cmp #$06                        ; code at $0600?
        bne mem_exec_go
        lda tmp0
        bne mem_exec_go
        ldy #$07
mem_exec_sig_loop                       ; $B0D3
        lda $0608,y
        cmp mem_exec_signature,y
        bne mem_exec_go
        dey
        bpl mem_exec_sig_loop
        jmp lock_toggle                 ; known program: run the built-in substitute
mem_exec_go                             ; $B0E1
        ldy #$00
        lda #$45
        cmp #$45
        jmp (tmp0)                      ; run the user's code

; M-R: the byte(s) at the address become the next data read from the
; command channel (count in the 6th command byte, default 1).
mem_read                                ; $B0EA
        lda (tmp0),y                    ; first byte
        sta bus_data
        lda cmd_len                     ; count given?
        cmp #$06
        bcc mem_read_single
        ldx cmd_buf+5
        dex
        beq mem_read_single
        txa
        clc                             ; end address of the range
        adc tmp0
        inc tmp0
        sta errchan_last_index
        lda tmp0                        ; read pointer of the error channel = memory address
        sta errbuf_ptr
        lda tmp1
        sta errbuf_ptr+1
        jmp errbuf_last_byte
mem_read_single                         ; $B10E
        jsr channel_find_read           ; single byte reply
        jmp errbuf_set_end

; Error 31 SYNTAX ERROR (unknown command).
cmd_syntax_31                           ; $B114
        lda #$31
        jmp cmd_error

; M-W: copy count bytes from the command buffer to the address.
mem_write                               ; $B119
        lda cmd_buf+6,y
        sta (tmp0),y
        iny
        cpy cmd_buf+5
        bcc mem_write
        rts

; Signature compared with $0608-$060F by M-E.
mem_exec_signature                      ; $B125
        !byte $06,$A2,$00,$86,$F9,$20,$86,$D5 ; $B125

; R command variants: R-H rename the disk / directory header,
; R-P rename a partition (looked up in the partition directory),
; otherwise rename a file.
rename_dispatch                         ; $B12D
        lda cmd_buf+1
        cmp #$2D
        bne rename_file
        lda cmd_buf+2
        cmp #$48                        ; R-H
        bne rename_chk_p
        jsr parse_single_file
        lda #$00
        jsr resolve_path
        jsr header_read                 ; read the header block
        jsr partition_is_native
        beq rnh_offset_4
        cmp #$04
        bcc rnh_offset_90
rnh_offset_4                            ; $B14F
        ldy #$04                        ; native / 1581: name at offset 4
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  1541 / 1571: name at offset $90
rnh_offset_90                           ; $B152
        ldy #$90
        lda #$10                        ; 16 characters, padded with shifted space
        sta tmp0
        ldx file_name_pos
rnh_copy                                ; $B15B
        cpx cmd_len
        bcs rnh_pad
        lda cmd_buf,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
rnh_pad                                 ; $B163
        lda #$A0
        sta sys_buf,y
        inx
        iny
        dec tmp0
        bne rnh_copy
        jsr header_write                ; write the header back
        jmp cmd_done
rename_chk_p                            ; $B174
        cmp #$50                        ; R-P ?

; Rename a file or partition: the new name must not exist (error 63),
; the old one must (error 62); the name is rewritten in the entry.
rename_file                             ; $B176
        php
        jsr parse_one_name
        jsr resolve_names
        plp
        bne rnf_lookup
        lda #$00                        ; R-P: look in the partition directory (partition 0)
        sta file_partition
        jsr partition_select
        lda file_name_pos
        sta file_name_start
rnf_lookup                              ; $B18E
        lda file_partition
        sta $2C11
        lda name2_index
        sta $2C09
        jsr dir_search_all              ; search the directory
        jsr check_target_free
        lda $2C31
        sta track
        lda $2C39
        sta sector
        jsr block_read_next             ; read the directory block of the old entry
        jsr job_wait
        lda $2C41                       ; name field = entry offset + 3
        clc
        adc #$03
        jsr buffer_set_ptr
        jsr active_buffer
        tay
        ldx file_name_pos
        lda #$10                        ; copy the new name, 16 characters
        jsr name_to_buffer_padded
        jsr block_write_next            ; write the directory block back
        jsr job_wait
        jmp cmd_done

; Error 62 FILE NOT FOUND unless every source file was found.
check_file_found                        ; $B1CE
        lda $2C19
        and #$07
        sta file_type
        ldx file_count
cff_loop                                ; $B1D9
        dex
        cpx param_count
        bcc cff_rts
        lda file_track,x
        bne cff_loop
        lda #$62                        ; error 62
        jmp cmd_error
cff_rts                                 ; $B1E9
        rts

; Error 63 FILE EXISTS if any target name was found.
check_target_free                       ; $B1EA
        jsr check_file_found
ctf_loop                                ; $B1ED
        lda file_track,x
        beq ctf_next
        lda #$63                        ; error 63
        jmp cmd_error
ctf_next                                ; $B1F7
        dex
        bpl ctf_loop
        rts

; ==========================================================================
; L - lock / unlock a file: toggles bit 6 of the file type byte in the
; directory entry.
; ==========================================================================
cmd_lock                                ; $B1FB
        jsr parse_single_file           ; one file name
        jsr partition_check_ready
        jsr dir_search_all              ; find it
        lda file_track
        beq lock_done

; Toggle the lock bit of the entry found by the last search.  Also the
; substitute for the host drive code intercepted by M-E (mem_exec_check).
lock_toggle                             ; $B209
        ldx entry_track                 ; directory block and entry offset of the match
        ldy entry_sector
        lda entry_offset
        pha
        stx track
        sty sector
        jsr sysbuf_read_ts
        pla
        tax
        lda sys_buf,x
        eor #$40                        ; toggle the lock bit
        sta sys_buf,x
        jsr sysbuf_write_ts             ; write the block back
lock_done                               ; $B227
        jmp internal_channels_free

; ==========================================================================
; W - software write protect: W-1 on, W-0 off.  Mirrors the front panel
; WRITE PROTECT state in bit 7 of panel_state.
; ==========================================================================
cmd_write_protect                       ; $B22A
        lda cmd_buf+1
        cmp #$2D
        bne wp_syntax
        lda cmd_buf+2
        cmp #$30                        ; W-0
        beq wp_off
        cmp #$31                        ; W-1
        beq wp_on
wp_syntax                               ; $B23C
        jmp syntax_error_31
wp_off                                  ; $B23F
        lda #$80
        bit wp_by_software
        beq wp_rts
        lda #$7F                        ; clear the write protect state
        and panel_state
        sta panel_state
        lda #$00
        sta wp_by_software
wp_rts                                  ; $B251
        rts
wp_on                                   ; $B252
        lda #$80
        bit panel_state
        bne wp_rts2
        sta wp_by_software              ; remember that software set it
        ora panel_state
        sta panel_state
wp_rts2                                 ; $B25F
        rts

; S - scratch files.  Every name in the command is matched against its
; directory; locked files are skipped, a directory only goes away through
; RD.  The chains (and a REL file's side sectors) are freed and the
; number of deleted files is reported with message 01.
scratch_files                           ; $B260
        jsr parse_one_name
        jsr parse_type_option           ; optional file type
        jsr resolve_names
scr_start                               ; $B269
        ldx #$00
        stx work_count
scr_next_name                           ; $B26D
        stx name_loop
        lda file_partition,x
        bne scr_search
        jmp scr_report
scr_search                              ; $B278
        jsr toggle_other_partitions
        jsr partition_select
        jsr require_partition_ready     ; partition must be ready
        lda name_loop
        jsr dir_find_first_path         ; first match
        bpl scr_entry
        jmp scr_name_done
scr_entry                               ; $B28C
        jsr file_is_open                ; skip files that are open
        bcc scr_next_match
        ldy #$00
        lda (dir_ptr),y
        sta range_count_lo
        and #$40                        ; locked?
        bne scr_next_match
        lda range_count_lo
        and #$07
        cmp #$06                        ; type 6 = DIR: only removable through RD
        bne scr_delete
        lda cmd_index
        cmp #$03
        bne scr_next_match
scr_delete                              ; $B2AC
        jsr dir_delete_entry            ; delete the entry
        lda range_count_lo
        and #$07
        cmp #$05                        ; type 5 = partition file: free its block range
        bne scr_free_chains
        iny
        lda (dir_ptr),y
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        ldy #$1C
        lda (dir_ptr),y
        sta range_count_lo
        iny
        lda (dir_ptr),y
        sta range_count_hi
scr_free_range                          ; $B2CF
        jsr check_track_sector
        jsr bam_free_block
        jsr range_next_block
        bne scr_free_range
        jsr bam_flush
        jmp scr_count
scr_free_chains                         ; $B2E0
        ldy #$13                        ; side sector chain of a REL file
        lda (dir_ptr),y
        beq loc_B2F0
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        jsr free_chain
loc_B2F0
        ldx match_index
        lda #$20
        and file_type_flags,x
        bne scr_count
        lda file_track,x                ; main chain
        sta track
        lda file_sector,x
        sta sector
        jsr free_chain
scr_count                               ; $B307
        inc work_count                  ; one more file scratched
scr_next_match                          ; $B309
        jsr dir_search_next
        bmi scr_name_done
        jmp scr_entry
scr_name_done                           ; $B311
        jsr toggle_other_partitions
        ldx name_loop
        inx
        cpx file_count
        bcs scr_report
        jmp scr_next_name
scr_report                              ; $B320
        lda work_count
        sta track
        ldy #$00
        lda #$01                        ; message 01 FILES SCRATCHED
        jmp cmd_status_y

; Free the chain of blocks starting at track/sector, reading each block
; for its link through the system buffer.
free_chain                              ; $B32B
        jsr bam_free_block              ; free this block
        lda track
        sta job_track+62
        lda sector
        sta job_track+63
        ldx #$1F
        lda #$AA                        ; job $AA: read it for the link
        jsr job_run_or_error
        ldy #$01
        lda (data_ptr),y
        sta sector
        dey
        lda (data_ptr),y
        sta track
        bne free_chain
        jsr bam_flush                   ; write the BAM back
        jmp channel_free

; ==========================================================================
; T - real time clock.  T-RA/T-RB/T-RD read the time as ASCII text, BCD
; or binary; T-WA/T-WB/T-WD set it.  The reply is read from the command
; channel.
; ==========================================================================
cmd_time                                ; $B352
        sei
        lda cmd_buf+1
        cmp #$2D
        bne time_syntax
        lda cmd_buf+2
        cmp #$52                        ; T-R
        beq time_read
        cmp #$57                        ; T-W
        bne time_syntax
        jmp time_write
time_syntax                             ; $B368
        jmp syntax_error_31

; Position of each RTC digit (register 11..0 order) in the ASCII string.
time_ascii_pos                          ; $B36B
        !byte $15,$14,$12,$11,$0F,$0E,$09,$08 ; $B36B
        !byte $06,$05,$0C,$0B           ; $B373

; Day names in column order: SUN. MON. TUES WED. THUR FRI. SAT.
day_names                               ; $B377
        !text "SMTWTFS"                 ; $B377
txt_B37E
        !text "UOUEHRA"                 ; $B37E
txt_B385
        !text "NNEDUIT"                 ; $B385
txt_B38C
        !text "..S.R.."                 ; $B38C

; Template 'dow. mo/da/yr hr:mi:se xM'.
time_template                           ; $B393
        !text "       /  /     :  :    M" ; $B393
time_read                               ; $B3AC
        lda cmd_buf+3
        cmp #$41                        ; A = ASCII
        beq time_read_ascii
        cmp #$42                        ; B = BCD
        bne loc_B3BA
        jmp time_read_bcd
loc_B3BA
        cmp #$44                        ; D = decimal
        bne time_syntax
        jmp time_read_decimal

; T-RA: 'SAT. 01/31/26 11:59:59 PM'.
time_read_ascii                         ; $B3C1
        ldx #$18
loc_B3C3
        lda time_template,x
        sta msg_buf,x
        dex
        bpl loc_B3C3
        jsr rtc_hold                    ; hold the clock
        lda rtc_weekday                 ; weekday
        and #$07
        tax
        lda day_names,x
        sta chan_data+31
        sta msg_buf
        lda txt_B37E,x
        sta msg_buf+1
        lda txt_B385,x
        sta msg_buf+2
        lda txt_B38C,x
        sta msg_buf+3
        ldx #$0B                        ; twelve digit registers
tra_digits                              ; $B3F2
        lda rtc_regs,x
        and rtc_digit_masks,x
        ora #$30
        ldy time_ascii_pos,x
        sta msg_buf,y
        dex
        bpl tra_digits
        ldy #$17
        lda rtc_hour10                  ; AM/PM bit of the hours register
        and #$04
        bne tra_pm
        lda #$41
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
tra_pm                                  ; $B40F
        lda #$50
        sta msg_buf,y
        iny

; Set up Y+1 bytes of the message buffer as the command channel reply.
time_reply                              ; $B415
        tya
        clc
        adc #$00
        sta errchan_last_index
        jsr errbuf_ptr_reset            ; reply pointer to the message buffer
        inc errbuf_ptr
        lda #$88
        sta chan_status+31
rtc_release                             ; $B426
        lda #$00                        ; release the clock
        sta rtc_ctrl_d
        rts

; T-RB: weekday, year, month, day, hour, minute, second, AM/PM in BCD.
time_read_bcd                           ; $B42C
        jsr time_fetch
        ldy #$01
loc_B431
        lda time_bcd,y
        sta msg_buf,y
        iny
        cpy #$08
        bcc loc_B431
        dey
        jmp time_reply

; T-RD: the same eight bytes in binary.
time_read_decimal                       ; $B440
        jsr time_fetch
        ldy #$01
loc_B445
        lda time_bcd,y
        jsr bcd_to_binary
        sta msg_buf,y
        iny
        cpy #$08
        bcc loc_B445
        dey
        jmp time_reply

; Read the clock into time_bcd and start the reply with the weekday.
time_fetch                              ; $B457
        jsr rtc_read
        lda time_bcd
        sta chan_data+31
        sta msg_buf
        rts

; Convert BCD in A to binary.
bcd_to_binary                           ; $B464
        pha
        and #$0F
        sta tmp0
        pla
        and #$F0
        lsr
        pha
        clc
        adc tmp0
        sta tmp0
        pla
        lsr
        lsr
        clc
        adc tmp0
        rts

; Split binary A into tens (tmp0) and units (A).
binary_split_tens                       ; $B47A
        pha
        lda #$00
        sta tmp0
        pla
loc_B480
        cmp #$0A
        bcc loc_B48A
        sbc #$0A
        inc tmp0
        bne loc_B480
loc_B48A
        rts
time_write                              ; $B48B
        lda cmd_buf+3
        cmp #$41
        beq time_write_ascii
        cmp #$42
        bne loc_B499
        jmp time_write_bcd
loc_B499
        cmp #$44
        bne loc_B4A0
        jmp time_write_decimal
loc_B4A0
        jmp syntax_error_31

; T-WA: set the clock from an ASCII string in the T-RA layout.
time_write_ascii                        ; $B4A3
        lda cmd_len                     ; full string required
        cmp #$1D
        bcc loc_B4BE
        ldx #$06
twa_find_day                            ; $B4AB
        lda cmd_buf+4                   ; match the first two letters of the day name
        cmp day_names,x
        bne loc_B4BB
        lda cmd_buf+5
        cmp txt_B37E,x
        beq twa_set
loc_B4BB
        dex
        bpl twa_find_day
loc_B4BE
        jmp syntax_error_31
twa_set                                 ; $B4C1
        txa
        jsr rtc_hold
        sta rtc_weekday
        ldx #$0B
loc_B4CA
        ldy time_ascii_pos,x
        lda cmd_buf+4,y
        and rtc_digit_masks,x
        sta rtc_regs,x
        dex
        bpl loc_B4CA
        lda cmd_buf+27                  ; 'P' of PM?
        and #$10
        jmp tw_pm_flag

; T-WB: set the clock from BCD bytes.
time_write_bcd                          ; $B4E1
        jsr tw_check_day
        ldy #$05
        ldx #$0B
loc_B4E8
        lda cmd_buf,y
        pha
        lsr
        lsr
        lsr
        lsr
        and rtc_digit_masks,x
        sta rtc_regs,x
        pla
        dex
        and rtc_digit_masks,x
        sta rtc_regs,x
        iny
        dex
        bpl loc_B4E8
tw_set_pm                               ; $B502
        lda cmd_buf,y
tw_pm_flag                              ; $B505
        beq loc_B509
        lda #$04                        ; set the PM bit
loc_B509
        ora rtc_hour10
        sta rtc_hour10
        jmp rtc_release

; T-WD: set the clock from binary bytes.
time_write_decimal                      ; $B512
        jsr tw_check_day
        ldx #$0B
        ldy #$05
loc_B519
        lda cmd_buf,y
        jsr binary_split_tens
        pha
        lda tmp0
        and rtc_digit_masks,x
        sta rtc_regs,x
        pla
        dex
        and rtc_digit_masks,x
        sta rtc_regs,x
        dex
        iny
        cpy #$0B
        bcc loc_B519
        jmp tw_set_pm

; Check the command length and weekday (0-6), hold the clock and write
; the weekday register.
tw_check_day                            ; $B539
        lda cmd_len
        cmp #$0C
        bcc tw_syntax
        lda cmd_buf+4                   ; weekday 0-6
        cmp #$07
        bcc loc_B549
tw_syntax                               ; $B546
        jmp syntax_error_31
loc_B549
        jsr rtc_hold
        sta rtc_weekday
        rts

; Valid bits of RTC registers 0-12.
rtc_digit_masks                         ; $B550
        !byte $0F,$07,$0F,$07,$0F,$03,$0F,$03 ; $B550
        !byte $0F,$01,$0F,$0F,$07       ; $B558

; Read the RTC into time_bcd: weekday, year, month, day, hour, minute,
; second (BCD), AM/PM flag.
rtc_read                                ; $B55D
        php
        sei
        jsr rtc_hold
        lda rtc_weekday
        and #$07
        sta time_bcd
        ldx #$0B
        ldy #$01
loc_B56E
        lda rtc_regs,x
        and rtc_digit_masks,x           ; tens digit
        asl
        asl
        asl
        asl
        sta tmp0
        dex
        lda rtc_regs,x
        and rtc_digit_masks,x
        clc
        sed                             ; decimal add gives BCD
        adc tmp0
        cld
        sta time_bcd,y
        iny
        dex
        bpl loc_B56E
        lda rtc_hour10
        and #$04
        sta time_bcd,y
        lda #$00
        sta rtc_ctrl_d
        plp
        rts
rtc_hold_retry                          ; $B59C
        sta rtc_ctrl_d
        ldx #$4C
loc_B5A1
        dex
        bne loc_B5A1
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction

; Set the RTC HOLD bit and wait until it is not busy.  A is preserved.
rtc_hold                                ; $B5A5
        pha
        lda #$01                        ; HOLD
        sta rtc_ctrl_d
        lda rtc_ctrl_d                  ; BUSY? release and try again
        and #$02
        bne rtc_hold_retry
        pla
        rts

; Store the current date and time (binary, 24 hour) as year, month, day,
; hour, minute at offset $17+X of the directory work block.
dir_time_stamp                          ; $B5B4
        txa
        pha
        jsr rtc_read
        ldy #$01
        pla
        pha
        tax
loc_B5BE
        lda time_bcd,y
        jsr bcd_to_binary
        sta sys_buf+23,x
        inx
        iny
        cpy #$06
        bcc loc_B5BE
        pla
        tax
        lda sys_buf+26,x                ; 12 o'clock is hour 0 in 12 hour mode
        sbc #$0C
        bne loc_B5D9
        sta sys_buf+26,x
loc_B5D9
        lda time_bcd+7                  ; PM: add 12
        beq loc_B5E7
        lda #$0C
        clc
        adc sys_buf+26,x
        sta sys_buf+26,x
loc_B5E7
        rts

; First letters of the commands, searched from the end.
cmd_chars                               ; $B5E8
        !text "VI/MBUP&CRSNTGLW"        ; $B5E8

; Syntax masks for the first 13 commands, as in the 1541 DOS: a set
; bit names a parse result that is not allowed.  $FF = no check here.
cmd_syntax_masks                        ; $B5F8
        !byte $FF,$FF,$FF,$9E,$FF,$FF,$FF,$FF ; $B5F8
        !byte $51,$DD,$1C,$9E,$18       ; $B600

; Low byte of the jt_cmd_block jump table slot of each command.
cmd_jump_offsets                        ; $B605
        !byte $21,$09,$24,$0C,$00,$1E,$12,$27 ; $B605
        !byte $03,$15,$18,$0F,$1B,$06,$57,$5A ; $B60D

; ==========================================================================
; Execute the pending command channel string or OPEN request.  For a data
; channel the string is a file name and goes to the OPEN code; otherwise
; the first letter selects the command.
; ==========================================================================
cmd_execute                             ; $B615
        lda cmd_partition               ; command channel uses the default partition
        jsr partition_select
        lda #$00
        sta search_type_a
        sta search_type_b
        jsr status_ok
        lda sec_addr_raw                ; secondary address 15?
        and #$8F
        bpl cmd_lookup
        eor #$8F
        beq cmd_lookup
        jmp open_file                   ; no: this is an OPEN
cmd_lookup                              ; $B633
        jsr cmd_trim                    ; trim and set the length
        lda (cmdbuf_ptr),y              ; first character
        ldx #$0F
cmd_find                                ; $B63A
        cmp cmd_chars,x
        beq cmd_found
        dex
        bpl cmd_find
        jmp syntax_error_31             ; error 31: unknown command
cmd_found                               ; $B645
        stx cmd_index
        lda cmd_jump_offsets,x          ; slot in the jump table page
        sta tmp0
        lda #$FF
        sta tmp1
        jmp (tmp0)

; Command finished: report the error noted in cmd_error_code, or 00, OK.
cmd_done                                ; $B654
        lda cmd_error_code              ; error noted while parsing?
        beq cmd_ok
        jmp cmd_error

; Finish with 00, OK,00,00.
cmd_ok                                  ; $B65C
        lda #$00
        tay
        sty track

; Finish with message A and track / Y as the two numbers.
cmd_status_y                            ; $B661
        sty sector
cmd_status                              ; $B663
        jsr status_set                  ; build the status message
        jsr cmdbuf_ptr_reset            ; reset the command buffer pointer
        jsr led_error_off               ; LED off
cmd_finish                              ; $B66C
        jmp internal_channels_free      ; release the internal channels

; Abort the command with DOS error A (track and sector reported as 0).
cmd_error                               ; $B66F
        ldy #$00
        sty track
        sty sector
        jmp jt_dos_error

; Parse the partition number in front of the ':' (default: current
; partition), select it and switch the activity LED on.
parse_partition_led                     ; $B678
        ldy #$00
        jsr find_separator

parse_partition_back                    ; $B67D
        dey
        jsr is_digit
        bne loc_B68D
loc_B683
        dey
        jsr is_digit
        beq loc_B683
        iny
        jsr parse_partition_num
loc_B68D
        jmp led_activity_on

; Decimal partition number at index Y: select it, error 74 if it does
; not exist.
parse_partition_num                     ; $B690
        jsr parse_byte_decimal

partition_select_chk                    ; $B693
        jsr partition_select_valid
        bcc loc_B6B4
        lda #$74                        ; error 74 DRIVE NOT READY
        jmp cmd_error

; Select partition A (0 = keep the current one) if it is of a usable
; type.  Out: carry set when it is not.
partition_select_valid                  ; $B69D
        cmp #$00
        bne loc_B6A4
        lda cur_partition
loc_B6A4
        pha
        tax
        lda part_type,x                 ; partition type
        beq psv_bad
        cmp #$06                        ; types 1-5 only
        bcs psv_bad
        pla
        jsr partition_select
        clc
loc_B6B4
        rts
psv_bad                                 ; $B6B5
        pla
        sec
        rts

; Advance Y to the next ':' ',' or '='.  Out: Z set when it is a ':'.
find_separator                          ; $B6B8
        lda cmd_buf,y
        cmp #$3A
        beq loc_B6CE
        cmp #$2C
        beq loc_B6CC
        cmp #$3D
        beq loc_B6CC
        iny
        cpy cmd_len
        bcc find_separator
loc_B6CC
        ora #$00
loc_B6CE
        rts

; Out: Z set when the character at index Y is a digit.
is_digit                                ; $B6CF
        lda cmd_buf,y
        cmp #$30
        bcc loc_B6DD
        cmp #$3A
        bcs loc_B6CC
        cmp cmd_buf,y
loc_B6DD
        rts

; Find the first ':'.  Out: Y = index behind it, Z set if none.
find_colon                              ; $B6DE
        ldy #$00
        ldx #$00
        lda #$3A
        jmp scan_for_char

; Parse a command of the form X[n]:name - exactly one name, error 34
; when there is none.
parse_one_name                          ; $B6E7
        jsr find_colon
        bne parse_names
syntax_34                               ; $B6EC
        lda #$34                        ; error 34
        jmp cmd_error

; Parse the names of a command (name[,name..][=name[,name..]]) into the
; file tables and build the syntax image in syntax_image, which is checked
; against the command's mask.
parse_names                             ; $B6F1
        dey
        dey
        sty file_name_pos
        txa
        bne syntax_34

parse_after_colon                       ; $B6F9
        lda #$3D                        ; is there an '='?
        jsr scan_for_char
        txa
        beq loc_B703
        lda #$40                        ; bit 6: two groups of names
loc_B703
        ora #$21
        sta syntax_image
        inx
        stx param_count
        stx file_count
        lda wildcard_count              ; wildcards in the first group
        beq loc_B721
        lda #$80
        ora syntax_image
        sta syntax_image
        lda #$00
        sta wildcard_count
loc_B721
        tya
        beq parse_check_syntax
        sta file_name_pos,x
        lda param_count
        sta parse_index
        lda #$8D                        ; scan the rest (no terminator)
        jsr scan_for_char
        inx
        stx file_count
        dex
        lda wildcard_count
        beq loc_B73E
        lda #$08
loc_B73E
        cpx param_count
        beq loc_B745
        ora #$04
loc_B745
        ora #$03
        eor syntax_image
        sta syntax_image
parse_check_syntax                      ; $B74D
        lda syntax_image
        ldx cmd_index
        and cmd_syntax_masks,x          ; forbidden combination for this command?
        bne syntax_30_img
        rts
syntax_30_img                           ; $B759
        sta cmd_error_code
        lda #$30                        ; error 30
        jmp cmd_error

; Scan the command for character A from index Y, recording the start
; of each comma separated name in file_name_pos+1+X and wildcard use in file_type_flags.
; Out: Y = index behind the character (0 = not found).
scan_for_char                           ; $B761
        sta scan_char
sfc_loop                                ; $B764
        cpy cmd_len
        bcs sfc_end
        lda (cmdbuf_ptr),y
        iny
        cmp scan_char
        beq loc_B799
        cmp #$2A                        ; count wildcards
        beq loc_B778
        cmp #$3F
        bne loc_B77B
loc_B778
        inc wildcard_count
loc_B77B
        cmp #$2C                        ; comma: next name
        bne sfc_loop
        tya
        sta name2_index,x
        lda wildcard_count
        and #$7F
        beq loc_B792
        lda #$80
        sta file_type_flags,x
        sta wildcard_count
loc_B792
        inx
        cpx #$05                        ; at most five names
        bcc sfc_loop
sfc_end                                 ; $B797
        ldy #$00
loc_B799
        lda cmd_len
        sta name2_index,x
        lda wildcard_count
        and #$7F
        beq loc_B7AA
        lda #$80
        sta file_type_flags,x
loc_B7AA
        tya
        rts

; Determine the command length: trailing carriage returns are dropped
; (not for U0 burst commands, whose data are binary).  Then clear the
; parser state.  Error 32 when the line is too long.
cmd_trim                                ; $B7AC
        ldy cmdbuf_ptr
        beq cmd_set_len
        dey
        beq loc_B7E5
        lda cmd_buf                     ; U0: binary data, keep everything
        cmp #$55
        bne loc_B7C1
        lda cmd_buf+1
        cmp #$30
        beq loc_B7C5
loc_B7C1
        lda cmd_buf,y
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B7C5
        lda #$00
        cmp #$0D                        ; drop a trailing carriage return
        beq cmd_set_len
        dey
        lda cmd_buf
        cmp #$55
        bne loc_B7DA
        lda cmd_buf+1
        cmp #$30
        beq loc_B7DE
loc_B7DA
        lda cmd_buf,y
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_B7DE
        lda #$00
        cmp #$0D
        beq cmd_set_len
        iny
loc_B7E5
        iny
cmd_set_len                             ; $B7E6
        sty cmd_len
        cpy #$FF
        ldy #$FF
        bcc parse_reset
        sty cmd_index
        lda #$32                        ; error 32
        jmp cmd_error

; Clear the parser variables and file tables.
parse_reset                             ; $B7F6
        ldy #$00
        tya
        sta cmdbuf_ptr
        sta record_len
        sta file_type
        sta type_option
        sta name_index
        sta parse_index
        sta param_count
        sta file_count
        sta wildcard_count
        sta cmd_error_code
        ldx #$05
loc_B817
        sta bus_vector+1,x
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

; Resolve partition and path of the first name only; error 74 if the
; partition is not usable.
resolve_first_name                      ; $B833
        jsr names_single
        bcc loc_B842
error_74                                ; $B838
        lda #$74                        ; error 74
        jmp cmd_error

; Resolve partition and path of every name; error 74 on failure.
resolve_names                           ; $B83D
        jsr resolve_all
        bcs error_74
loc_B842
        rts

names_single                            ; $B843
        lda file_count
        sta param_count
        lda #$01
        sta file_count
        sta parse_index

resolve_all                             ; $B851
        ldx #$00
loc_B853
        stx name_index
        jsr resolve_name
        ldx name_index
        inx
        cpx file_count
        bcc loc_B853
        lda file_partition
        jmp partition_select_valid

; Work out the partition of name X: a decimal number in front of its
; ':' (default: the current partition, or that of the first name), with
; an optional /path/ in between.
resolve_name                            ; $B866
        lda cur_partition               ; first name defaults to the current partition
        cpx #$00
        beq loc_B870
        lda file_partition
loc_B870
        sta file_partition,x
        lda file_name_pos,x
        sta file_name_start,x
        inx
        ldy file_name_pos,x
        sty tmp0
        tax
        tay
rn_find_colon                           ; $B881
        lda cmd_buf,x
        cmp #$3A
        beq rn_partition_prefix
        cmp #$3D
        beq rn_rts
        cmp #$2C
        beq rn_rts
        inx
        cpx tmp0
        bcc rn_find_colon
rn_rts                                  ; $B895
        rts
rn_partition_prefix                     ; $B896
        lda cmd_buf,y                   ; '>' / '<' in front of the name
        cmp #$3E
        beq rn_rts
        cmp #$3C
        beq rn_rts
        inx
        txa
        pha
        ldx name_index
        sta file_name_start,x
        tay
        dey
        beq rn_default_part
        dey
        lda cmd_buf,y
        cmp #$2F                        ; path in front of the ':'?
        bne rn_digits
rn_find_path                            ; $B8B5
        lda cmd_buf,y
        cmp #$2F
        bne loc_B8C2
        tya
        sta file_name_start,x
        lda #$2F
loc_B8C2
        cmp #$3D
        beq loc_B8CF
        cmp #$2C
        beq loc_B8CF
        dey
        cpy #$FF
        bne rn_find_path
loc_B8CF
        ldy file_name_start,x
        beq rn_default_part
        dey
rn_digits                               ; $B8D5
        jsr is_digit                    ; digits in front: partition number
        bne rn_default_part
loc_B8DA
        dey
        cpy #$FF
        beq loc_B8E4
        jsr is_digit
        beq loc_B8DA
loc_B8E4
        iny
        jsr parse_byte_decimal
        tay
        bne rn_store
rn_default_part                         ; $B8EB
        lda cur_partition
rn_store                                ; $B8EE
        ldx name_index
        sta file_partition,x
        pla
        sta file_name_pos,x
        rts

; Take the option behind the last '=' (as in '$=P' or ',S'): look the
; letter up in the file type / partition type initials.
parse_type_option                       ; $B8F8
        ldy #$00
        lda param_count
        cmp file_count
        beq pto_store
        dec file_count
        ldy file_count

sub_B908
        lda file_name_pos,y
        tay
        lda (cmdbuf_ptr),y
        ldy cur_partition               ; partition 0: partition types
        beq pto_partition_types
        ldy #$06
        cmp #$42                        ; 'B'
        beq pto_store
        dey
pto_find                                ; $B91A
        cmp type_names_1,y
        beq pto_store
        dey
        bne pto_find
pto_store                               ; $B922
        tya
        sta type_option
        rts
pto_partition_types                     ; $B927
        ldy #$07
loc_B929
        cmp txt_C299,y
        beq pto_store
        dey
        bne loc_B929
        beq pto_store

; ==========================================================================
; C - CP change partition (number in decimal, or binary after a shifted
; P), CD change directory, otherwise copy / concatenate files (copy_files).
; ==========================================================================
cmd_copy                                ; $B933
        lda cmd_buf+1
        cmp #$50                        ; CP
        beq cp_decimal
        cmp #$D0                        ; C + shifted P: binary partition number follows
        beq cp_binary
        cmp #$44                        ; CD
        beq change_directory
        jmp copy_files                  ; copy
cp_binary                               ; $B945
        lda cmd_buf+2
        jmp change_partition
cp_decimal                              ; $B94B
        lda cmd_len                     ; 'CP' alone: report the current default
        cmp #$02
        bne cp_parse
        lda default_partition
        sta track
        jmp cp_report
cp_parse                                ; $B959
        ldy #$02
        jsr parse_byte_decimal

; Make partition A the default partition.  Error 77 if it does not exist
; or is the system partition.  Reports 02, PARTITION SELECTED.
change_partition                        ; $B95E
        tax
        pha
        sta track
        lda part_type,x                 ; partition type
        beq cp_illegal
        cmp #$FF
        bne cp_store
cp_illegal                              ; $B96B
        lda #$77                        ; error 77 SELECTED PARTITION ILLEGAL
        jmp jt_dos_error
cp_store                                ; $B970
        pla
        jsr cfg_set_default_partition   ; store as the default partition
cp_report                               ; $B974
        ldy #$00
        lda #$02                        ; message 02
        jmp cmd_status_y

; CD: change the current directory of a native partition.  'CD//' or
; 'CD/' alone selects the root, a left arrow the parent directory,
; otherwise the path is resolved and its last element looked up.
change_directory                        ; $B97B
        jsr find_colon
        beq cd_short_form
        dey
        dey
        sty file_name_pos
        jsr resolve_first_name
        jsr partition_is_native         ; native partitions only
        bne cd_syntax
        ldy file_name_start
        cpy file_name_pos
        bne cd_resolve
        iny
        cpy cmd_len
        bne cd_resolve
        dey
        lda cmd_buf,y                   ; left arrow: parent
        cmp #$5F
        beq cd_parent
        cmp #$2F                        ; '/': root
        bne cd_resolve
cd_root                                 ; $B9A6
        jsr dir_set_root
cd_ok                                   ; $B9A9
        jmp cmd_ok
cd_parent                               ; $B9AC
        jsr header_read
        lda sys_buf+34                  ; parent pointer in the header, 0 = already root
        beq cd_ok
        ldy sys_buf+35
        jmp cd_store
cd_short_form                           ; $B9BA
        lda cmd_len
        cmp #$03
        bne cd_slash_form
        jsr partition_is_native
        bne cd_syntax
        lda cmd_buf+2
        cmp #$5F
        beq cd_parent
        cmp #$2F
        beq cd_root
cd_slash_form                           ; $B9D0
        ldx #$00
        ldy #$02
        lda #$2F
        jsr scan_for_char
        bne cd_with_partition
cd_syntax                               ; $B9DB
        jmp syntax_error_30
cd_with_partition                       ; $B9DE
        dey
        sty file_name_start
        jsr parse_partition_back
        lda cur_partition
        sta file_partition
        jsr partition_is_native
        bne cd_syntax
        lda #$00
        sta file_name_pos
cd_resolve                              ; $B9F5
        lda #$01
        sta file_count
        lda #$00
        jsr resolve_path
        lda file_name_pos
        bne cd_lookup
        lda dir_hdr_track
        ldy dir_hdr_sector
cd_store                                ; $BA0A
        jsr dir_set_current
        jmp cmd_ok
cd_lookup                               ; $BA10
        jsr dir_search                  ; look the directory up
        ldy file_sector
        lda file_track                  ; found: its header track / sector
        bne cd_store

; Error 39 FILE NOT FOUND (directory).
error_39                                ; $BA1B
        lda #$39
        jmp cmd_error

; Resolve the /path/ in front of name A: starting from the current
; directory (or the root after a leading '/'), look up each component as
; a DIR entry and make it the working directory.  Native partitions only.
resolve_path                            ; $BA20
        sta path_file
        jsr dir_setup
        jsr partition_is_native         ; native only
        bne rp_rts
        ldx path_file
        lda file_name_start,x           ; no path in front of the name?
        cmp file_name_pos,x
        bne rp_walk
rp_rts                                  ; $BA36
        rts
rp_walk                                 ; $BA37
        sta path_index
        lda search_type_a               ; preserve the search state
        pha
        lda search_type_b
        pha
        lda file_type_flags,x
        pha
        lda file_name_pos,x
        pha
        lda type_option
        pha
        lda file_track,x
        pha
        lda sec_addr
        pha
        lda #$06                        ; search for type 6 = DIR
        sta type_option
        sta search_type_a
        sta search_type_b
rp_next_char                            ; $BA60
        inc path_index
        ldx path_index
        cpx cmd_len
        bcs rp_restore
        lda cmd_buf,x
        cmp #$3A
        beq rp_restore
        cmp #$2F                        ; '/': leading slash means start at the root
        bne rp_component
        lda #$01
        sta dir_hdr_track
        sta dir_hdr_sector
        lda #$22                        ; root directory starts at sector 34
        sta dir_first_sector
        bne rp_next_char
rp_component                            ; $BA84
        txa
        ldy path_file
        sta file_name_pos,y
rp_find_end                             ; $BA8B
        inx
        cpx cmd_len
        bcs rp_search
        lda cmd_buf,x                   ; end of this component
        cmp #$2F
        bne rp_find_end
rp_search                               ; $BA97
        lda cmd_len
        pha
        stx path_index
        stx cmd_len
        lda #$00
        sta file_track,y
        jsr require_partition_ready
        jsr dir_find_first              ; look it up
        beq rp_enter
        jmp error_39
rp_enter                                ; $BAAF
        pla
        sta cmd_len
        ldy path_file
        lda file_track,y                ; enter it: its header becomes the directory header
        sta dir_hdr_track
        lda file_sector,y
        sta dir_hdr_sector
        clc
        adc #$01
        sta dir_first_sector
        jmp rp_next_char
rp_restore                              ; $BACA
        ldx path_file
        pla
        sta sec_addr
        pla
        sta file_track,x
        pla
        sta type_option
        pla
        sta file_name_pos,x
        pla
        sta file_type_flags,x
        pla
        sta search_type_b
        pla
        sta search_type_a
        rts

; Parse a decimal number of up to three digits at command index Y.
; Out: A = value (error 30 if above 255 or too long), Y behind it.
parse_byte_decimal                      ; $BAE9
        php
        sei
        tya
        pha
        ldx #$00
pbd_count                               ; $BAEF
        lda cmd_buf,y
        cmp #$30
        bcc loc_BB02
        cmp #$3A
        bcs loc_BB02
        cpy cmd_len
        bcs loc_BB02
        iny
        inx
        bne pbd_count
loc_BB02
        dex
        cpx #$03
        bcc loc_BB0A
pbd_syntax                              ; $BB07
        jmp syntax_error_30
loc_BB0A
        pla
        tay
        lda #$00
        sta block_abs+2
pbd_digit                               ; $BB11
        lda cmd_buf,y
        and #$0F
        sta block_abs+1
        beq loc_BB2C
        clc
        lda block_abs+2
pbd_add                                 ; $BB1F
        adc dec_weights_2,x
        bcs pbd_syntax
        dec block_abs+1
        bne pbd_add
        sta block_abs+2
loc_BB2C
        iny
        dex
        bpl pbd_digit
        lda block_abs+2
        plp
        rts

; Decimal weights 1, 10, 100.
dec_weights_2                           ; $BB35
        !byte $01,$0A,$64               ; $BB35

; ==========================================================================
; '/' - 1581 style sub-partitions, only for 1581 emulation partitions.
;   /0:name               select the partition file as the working area
;   /0                    back to the whole disk
;   /0:name,ts ll,C       create one: start track, sector, length lo/hi
; ==========================================================================
cmd_slash                               ; $BB38
        lda #$01
        sta file_name_pos
        lda cmd_len
        sta name2_index
        jsr resolve_first_name
        jsr partition_type              ; 1581 and 1581 CP/M partitions only
        cmp #$04
        beq sl_ready
        cmp #$05
        beq sl_ready
        jmp syntax_error_31
sl_ready                                ; $BB53
        jsr partition_check_ready
        lda file_name_pos               ; no name: back to the whole disk
        cmp cmd_len
        beq sl_root
        jsr dir_search_all
        lda file_track
        beq sl_not_found
        jsr sl_name_length
        bcc sl_select
        lda #$63                        ; error 63
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sl_error_62                             ; $BB6D
        lda #$62
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sl_error_30                             ; $BB70
        lda #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
sl_error_77                             ; $BB73
        lda #$77
        jsr cmd_error
sl_not_found                            ; $BB78
        jsr sl_name_length
        bcc sl_error_62
        ldx name_end
        lda cmd_buf+6,x                 ; ',C' behind the parameters = create
        cmp #$43
        bne sl_error_30
        jmp sl_create
sl_select                               ; $BB8A
        lda file_type_flags
        and #$07                        ; must be a type 5 entry
        cmp #$05
        bne sl_error_62
        jsr entry_get_range
sl_check_range                          ; $BB96
        jsr check_track_sector
        jsr range_next_block
        bne sl_check_range
        bcc sl_error_77
        ldy #$02                        ; must start on sector 0
        lda (dir_ptr),y
        bne sl_error_77
        dey                             ; and span at least three tracks
        lda track
        tax
        sbc (dir_ptr),y
        cmp #$02
        beq sl_error_77
        bcc sl_error_77
        lda (dir_ptr),y
        pha
        txa
        tay
        pla
        jsr dir_set_current
        jmp sl_reinit
sl_root                                 ; $BBBE
        jsr dir_reset_default
sl_reinit                               ; $BBC1
        jsr channels_free_partition
        jsr partition_init
        lda first_track                 ; report first and last track
        sta track
        ldy last_track_plus1
        dey
        sty sector
        lda #$02
        ldy #$00
        jmp cmd_status

; Check that the whole block range is free and does not touch the
; directory track (error 67).
sl_check_free                           ; $BBD9
        jsr sl_get_params
scf_loop                                ; $BBDC
        jsr check_track_sector
        lda track                       ; directory track 40 is not allowed
        cmp #$28
        beq error_67
        jsr bam_test_block              ; block in use?
        beq error_67
        jsr range_next_block
        bne scf_loop
        rts
error_67                                ; $BBF0
        lda #$67
        jmp jt_dos_error

; Out: carry clear when four parameter bytes follow the name.
sl_name_length                          ; $BBF5
        ldx #$01
        jsr name_measure
        lda cmd_len
        sec
        sbc name_end
        cmp #$04
        rts

; Fetch start track, sector and block count from behind the name.
; Error 77 when the count is zero.
sl_get_params                           ; $BC03
        ldy name_end
        iny
        lda cmd_buf,y
        sta track
        iny
        lda cmd_buf,y
        sta sector
        iny
        lda cmd_buf,y
        sta range_count_lo
        iny
        lda cmd_buf,y
        sta range_count_hi
        clc
        lda range_count_lo
        adc range_count_hi
        beq sgp_illegal
        jmp check_track_sector
sgp_illegal                             ; $BC2C
        lda #$77
        jsr cmd_error

; Create the partition file: directory entry of type 5 (CBM) and all
; blocks of the range allocated.
sl_create                               ; $BC31
        jsr sl_check_free
        lda #$05                        ; file type 5
        sta file_type
        lda #$12
        sta sec_addr
        jsr sl_get_params
        jsr channel_open_write          ; create the entry
        jsr dir_create_entry
        jsr sl_get_params
slc_allocate                            ; $BC49
        jsr check_track_sector
        lda track
        jsr bam_alloc_block
        jsr range_next_block
        bne slc_allocate
        jsr sl_get_params
        ldx channel                     ; block count into the entry
        lda range_count_lo
        sta chan_blocks_lo,x
        lda range_count_hi
        sta chan_blocks_hi,x
        lda #$00
        jsr buffer_put_byte_chk
        lda #$12
        sta sec_addr
        jsr close_channel               ; close the internal channel
        jmp cmd_done

; Step track/sector to the next block of a contiguous range and count
; down range_count_lo/range_count_hi.  Out: Z set when the range is finished, carry set
; after a track change.
range_next_block                        ; $BC76
        lda range_count_lo
        bne rnb_step
        lda range_count_hi
        beq loc_BC9E
        dec range_count_hi
rnb_step                                ; $BC83
        dec range_count_lo
        inc sector                      ; next sector
        lda sectors_per_track
        cmp sector
        bne loc_BC9E
        lda #$00
        sta sector
        lda track                       ; running into the directory track
        cmp dir_hdr_track
        beq rnb_error_67
        inc track
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
loc_BC9E
        clc
        lda range_count_hi
        ora range_count_lo
        rts
rnb_error_67                            ; $BCA6
        lda #$67
        jmp jt_dos_error

; Load start track/sector and block count of a partition file from its
; directory entry.
entry_get_range                         ; $BCAB
        ldy #$01
        lda (dir_ptr),y
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        ldy #$1C
        lda (dir_ptr),y
        sta range_count_lo
        iny
        lda (dir_ptr),y
        sta range_count_hi
        rts

; Mark every block of the range as allocated.
range_allocate                          ; $BCC4
        jsr check_track_sector
        jsr bam_alloc_block
        jsr range_next_block
        bne range_allocate
        rts

; ==========================================================================
; M - MD make directory, otherwise the memory commands (cmd_memory).
; ==========================================================================
cmd_m                                   ; $BCD0
        lda cmd_buf+1
        cmp #$44                        ; MD
        beq make_directory
m_memory                                ; $BCD7
        jmp cmd_memory

; MD: create a subdirectory on a native partition.  Finds two adjacent
; free blocks (header + first directory block), creates the DIR entry
; and writes the new header with its back pointers to the parent.
make_directory                          ; $BCDA
        jsr parse_single_file
        bne m_memory
        jsr require_partition_ready
        jsr alloc_first_block           ; find a free block
        lda track
        sta file_track
        lda sector
        sta file_sector
md_find_pair                            ; $BCEF
        lda track
        sta md_track
        lda sector
        sta md_sector
        jsr alloc_native_search         ; and the next free one
        lda sector
        pha
        lda track
        pha
        cmp md_track
        bne md_retry
        ldx md_sector                   ; directly behind the first?
        inx
        cpx sector
        beq md_have_pair
md_retry                                ; $BD0F
        lda md_track
        sta track
        lda md_sector
        sta sector
        jsr bam_free_block              ; no: give the first one back and go on
        pla
        tax
        sta track
        pla
        sta sector
        cpx file_track
        bne md_find_pair
        cmp file_sector
        bne md_find_pair
        jsr bam_free_block
        lda #$65                        ; error 65: no adjacent pair anywhere
        jmp cmd_error
md_have_pair                            ; $BD35
        pla
        pla
        lda #$00
        sta file_track
        jsr resolve_path
        lda dir_hdr_sector
        pha
        lda dir_hdr_track
        pha
        jsr dir_search
        lda file_track
        beq md_create
        lda #$63                        ; error 63: name exists
        jmp cmd_error
md_create                               ; $BD54
        lda #$06                        ; file type 6 = DIR
        sta file_type
        lda md_track
        sta track
        lda md_sector
        sta sector
        jsr dir_create_entry
        ldx channel
        lda #$02                        ; two blocks
        sta chan_blocks_lo,x
        lda #$00
        sta chan_blocks_hi,x
        jsr close_update_entry
        jsr bam_flush
        ldx md_sector
        stx dir_hdr_sector
        inx
        stx dir_first_sector
        lda md_track
        sta dir_hdr_track
        jsr build_dir_header            ; build the header block
        pla                             ; back pointers: parent header and our entry there
        sta sys_buf+34
        pla
        sta sys_buf+35
        lda file_dir_track
        sta sys_buf+36
        lda file_dir_sector
        sta sys_buf+37
        lda file_dir_index
        sta sys_buf+38
        jsr header_write
        jsr build_empty_dir_block       ; empty first directory block
        jmp dirblock_write

; ==========================================================================
; R - RD remove directory, otherwise rename (rename_dispatch).
; ==========================================================================
cmd_rename                              ; $BDAE
        lda cmd_buf+1
        cmp #$44                        ; RD
        beq remove_directory
r_rename                                ; $BDB5
        jmp rename_dispatch

; RD: the directory must be empty; it is then deleted like a file.
remove_directory                        ; $BDB8
        jsr parse_single_file
        bne r_rename
        lda file_name_start
        pha
        ldx file_name_pos
        dex
        stx file_name_start
        lda #$2F                        ; turn 'name' into the path 'name/' to enter it
        sta cmd_buf,x
        lda #$00
        jsr resolve_path
        pla
        sta file_name_start
        lda #$00
        sta free_entry_offset
        jsr dir_first_entry             ; any entry in it?
        beq rd_empty
        ldy #$00
        sty track
        lda #$01                        ; not empty: 01 with 0 files scratched
        jmp cmd_status_y
rd_empty                                ; $BDE9
        ldx file_name_pos
        dex
        lda #$3A
        sta cmd_buf,x                   ; restore the ':' and scratch the DIR entry
        jmp scr_start

; Parse a command with a single name and resolve its partition.
; Out: Z set when the partition is native.
parse_single_file                       ; $BDF5
        lda #$03                        ; command index 3 (enables directory deletion)
        sta cmd_index
        jsr parse_one_name
        jsr resolve_first_name
        jmp partition_is_native

; ==========================================================================
; G - 'GEOS' (hands over to geos_boot_check) and G-P get partition info.
; ==========================================================================
cmd_g                                   ; $BE03
        ldx #$01
g_cmp_geos                              ; $BE05
        lda cmd_buf,x
        cmp txt_eos-1,x
        bne g_get_partition
        inx
        cpx #$04
        bcc g_cmp_geos
        ldx #$01
        jsr geos_boot_check
        jmp cmd_ok

; Rest of the word GEOS.
txt_eos                                 ; $BE1A
        !text "EOS"                     ; $BE1A

; G-P [number]: return the 30-byte entry of the partition (default: the
; current one) from the partition directory, with the partition number
; in the third byte, as the command channel reply.
g_get_partition                         ; $BE1D
        lda cmd_buf+1
        cmp #$2D
        bne g_syntax
        lda cmd_buf+2
        cmp #$50
        beq gp_number
g_syntax                                ; $BE2B
        jmp syntax_error_31
gp_number                               ; $BE2E
        lda cmd_len
        cmp #$04
        bcc gp_current
        lda cmd_buf+3
        cmp #$FF
        bne gp_read
gp_current                              ; $BE3B
        lda cur_partition
gp_read                                 ; $BE3E
        pha
        lsr                             ; 8 entries per block of the partition directory
        lsr
        lsr
        jsr system_block_read
        bcc gp_copy
        lda #$78                        ; job error $78
        jmp jt_job_error
gp_copy                                 ; $BE4C
        pla
        pha
        and #$07                        ; entry offset: 32 * (n mod 8) + 2
        asl
        asl
        asl
        asl
        asl
        clc
        adc #$02
        sta data_ptr
        ldy #$00
        lda (data_ptr),y
        sta chan_data+31
gp_copy_loop                            ; $BE61
        lda (data_ptr),y
        sta msg_buf,y
        iny
        cpy #$1E
        bcc gp_copy_loop
        pla                             ; partition number
        ldy #$02
        sta msg_buf,y
        lda #$1D                        ; 30 bytes
        clc
        adc #$00
        sta errchan_last_index
        jsr errbuf_ptr_reset
        inc errbuf_ptr
        lda #$88
        sta chan_status+31
        rts

; Error 74 DRIVE NOT READY unless the current partition is initialised;
; then switch the activity LED on.
require_partition_ready                 ; $BE84
        lda #$00
        sta tmp0
        jsr partition_check_ready
        beq rpr_led
        lda #$74                        ; error 74
        jmp cmd_error
rpr_led                                 ; $BE92
        jmp led_activity_on

; Search the directory of every partition named in the command for
; the file names belonging to it.
search_all_names                        ; $BE95
        ldx file_count
        dex
san_loop                                ; $BE99
        stx name_loop
        lda file_partition,x
        beq san_next
        jsr toggle_other_partitions
        jsr partition_select
        lda name_loop
        jsr dir_search_path
        jsr toggle_other_partitions
san_next                                ; $BEB0
        dex
        bpl san_loop
        rts

; XOR the partition number of name name_loop into those of all other
; names, so that names on the same partition read as 0 (and back again
; when called a second time).
toggle_other_partitions                 ; $BEB4
        ldx name_loop
        lda file_partition,x
        pha
        ldy file_count
        dey
top_loop                                ; $BEBF
        pla
        pha
        eor file_partition,y
        sta file_partition,y
        dey
        bpl top_loop
        pla
        sta file_partition,x
        rts

; Look up every name of the command in the directory (after resolving
; the path of the first name).  Results go to the per-name tables
; file_track / file_sector (start block), file_dir_track / file_dir_sector / file_dir_index (entry place).
dir_search_all                          ; $BECF
        lda #$00

; As dir_search_all, resolving the path of name A.
dir_search_path                         ; $BED1
        pha
        jsr require_partition_ready
        pla
        jsr resolve_path

; Search the current directory for all names not yet found.
dir_search                              ; $BED9
        jsr require_partition_ready
        lda #$00                        ; search for used entries
        sta free_entry_offset
        jsr dir_first_entry             ; first entry
        bne dsr_compare
dsr_rts                                 ; $BEE6
        rts
dsr_next_entry                          ; $BEE7
        jsr dir_next_entry
        beq loc_BEFC
dsr_compare                             ; $BEEC
        jsr entry_match_names           ; compare with the pending names
        lda search_done                 ; everything found?
        beq loc_BEF5
        rts
loc_BEF5
        lda match_index
        bmi dsr_next_entry
        bpl dsr_compare
loc_BEFC
        lda search_done
        beq dsr_rts
        rts

; Continue the search behind the last match.  Out: N set = no more.
dir_search_next                         ; $BF02
        jsr dir_resume_entry
        beq dff_none
        bne dff_check

; Resolve the path of name 0, then find the first match.
dir_find_first_path0                    ; $BF09
        lda #$00

; Resolve the path of name A, then find the first match.
dir_find_first_path                     ; $BF0B
        pha
        lda #$00
        sta free_entry_offset
        pla
        jsr resolve_path

; Find the first entry that matches a name and passes the filters:
; date/time not before filter_date_from / not after filter_date_to when enabled, and the
; requested file type.  Out: N set when nothing matches.
dir_find_first                          ; $BF15
        lda #$00
        sta free_entry_offset
        jsr dir_first_entry
        bne dff_check
        sta search_done
dff_none                                ; $BF22
        lda #$FF
        rts

dff_next                                ; $BF25
        jsr dir_next_entry
        beq dff_none
dff_check                               ; $BF2A
        jsr entry_match_names
        ldx match_index
        bpl dff_date_filters
        lda search_done
        beq dff_next
        bne dff_rts
dff_date_filters                        ; $BF39
        bit search_type_a               ; 'not before' date filter
        bpl dff_before_filter
        ldx #$00
        ldy #$17                        ; date bytes at offset $17 of the entry
loc_BF42
        lda (dir_ptr),y
        cmp filter_date_from,x
        bcc dff_before_filter
        bne dff_next
        inx
        iny
        cpy #$1C
        bcc loc_BF42
dff_before_filter                       ; $BF51
        bit search_type_b               ; 'not after' date filter
        bpl dff_type_filter
        ldx #$00
        ldy #$17
loc_BF5A
        lda (dir_ptr),y
        cmp filter_date_to,x
        bcc dff_next
        bne dff_type_filter
        inx
        iny
        cpy #$1C
        bcc loc_BF5A
dff_type_filter                         ; $BF69
        ldx match_index
        lda type_option                 ; type filter
        beq dff_rts
        lda file_type_flags,x
        and #$07
        cmp type_option
        bne dff_next
dff_rts                                 ; $BF7B
        rts

; Compare the current directory entry with every pending name of the
; current partition.  '?' matches any character, '*' anything up to the
; end; text after a '*' is compared against the end of the name.
; On a match the entry's data are copied to the tables of that name.
entry_match_names                       ; $BF7C
        ldx #$FF
        stx match_index
        inx
        stx wildcard_count
        jsr names_pending
        beq emn_try
loc_BF8A
        rts
emn_next_name                           ; $BF8B
        jsr np_next
        bne loc_BF8A
emn_try                                 ; $BF90
        lda file_partition,x            ; name belongs to the current partition?
        cmp cur_partition
        bne emn_next_name
        lda file_name_pos,x
        tax
        jsr name_measure
        ldy #$03                        ; names start at offset 3 of an entry
        bne emn_loop
emn_char                                ; $BFA3
        lda cmd_buf,x
        cmp (dir_ptr),y
        beq loc_BFB4
        cmp #$3F                        ; '?' matches anything but the padding
        bne emn_next_name
        lda (dir_ptr),y
        cmp #$A0
        beq emn_next_name
loc_BFB4
        inx
        iny
emn_loop                                ; $BFB6
        cpx name_end
        bcs emn_name_end
        lda cmd_buf,x                   ; '*': rest matches
        cmp #$2A
        bne emn_char
        jmp emn_star_tail
emn_name_end                            ; $BFC5
        cpy #$13                        ; command name ended: entry name must end too
        bcs emn_matched
        lda (dir_ptr),y
        cmp #$A0
        bne emn_next_name
emn_matched                             ; $BFCF
        ldx parse_index
        stx match_index
        lda file_type_flags,x
        and #$80
        sta wildcard_count
        lda entry_offset                ; note where the entry lives
        sta file_dir_index,x
        lda track
        sta file_dir_track,x
        lda sector
        sta file_dir_sector,x
        ldy #$00                        ; type byte
        lda (dir_ptr),y
        iny
        pha
        and #$40                        ; lock bit
        sta tmp0
        pla
        and #$DF
        bmi loc_BFFE                    ; bit 7 clear = not closed
        ora #$20
loc_BFFE
        and #$27
        ora tmp0
        sta tmp0
        lda #$80
        and file_type_flags,x
        ora tmp0
        sta file_type_flags,x
        lda (dir_ptr),y                 ; start track / sector
        bne loc_C019
        cmp cur_partition
        bne loc_C019
        lda #$01
loc_C019
        sta file_track,x
        iny
        lda (dir_ptr),y
        sta file_sector,x
        lda record_len
        bne names_pending
        ldy #$15                        ; record length of a REL file
        lda (dir_ptr),y
        sta record_len

; Out: search_done = 0 while a name is still unresolved (wildcard names stay
; pending), $FF when everything was found.
names_pending                           ; $C02E
        lda #$FF
        sta search_done
        lda file_count
        sta parse_index

np_next                                 ; $C039
        dec parse_index
        bpl loc_C03F
        rts
loc_C03F
        ldx parse_index
        lda file_type_flags,x           ; wildcard names never count as resolved
        bmi np_more
        lda file_track,x
        bne np_next
np_more                                 ; $C04C
        lda #$00
        sta search_done
        rts

; '*' followed by more text: compare the tail backwards.
emn_star_tail                           ; $C052
        stx $5C
        ldx name_end
        dex
        cpx $5C
        beq loc_C076
        ldy #$13
loc_C05E
        dey                             ; last character of the entry name
        lda (dir_ptr),y
        cmp #$A0
        beq loc_C05E
est_char                                ; $C065
        lda cmd_buf,x
        cmp (dir_ptr),y
        beq loc_C070
        cmp #$3F
        bne loc_C079
loc_C070
        dey
        dex
        cpx $5C
        bne est_char
loc_C076
        jmp emn_matched
loc_C079
        jmp emn_next_name

; Open the current directory and position on its first entry.
; In: free_entry_offset = 0 search used entries, 1 look for a free entry.
; Out: Z set when the end of the directory was reached.
dir_first_entry                         ; $C07C
        ldy #$00
        sty free_entry_track
        dey
        sty match_index
        sty dir_link
        lda dir_hdr_track               ; directory starts at the header track, first sector
        sta track
        lda dir_first_sector
        sta sector
        jsr open_internal_read
dir_block_start                         ; $C095
        lda dir_link
        bne loc_C09B
        rts
loc_C09B
        lda #$07                        ; 8 entries per block
        sta dir_entries_left
        lda #$00                        ; byte 0 of the block: link track
        jsr buffer_peek
        sta dir_link
dir_entry_check                         ; $C0A8
        jsr buffer_get_ptr
        dec dir_entries_left
        ldy #$00
        lda (dir_ptr),y                 ; type byte 0 = free entry
        bne dfe_used
        lda free_entry_track
        bne dir_next_entry
        jsr header_get_for_sa           ; remember the first free entry
        lda cur_partition
        sta free_entry_part
        lda track
        sta free_entry_track
        lda sector
        sta free_entry_sector
        lda dir_ptr
        ldx free_entry_offset
        sta free_entry_offset
        beq dir_next_entry
        rts
dfe_used                                ; $C0D7
        ldx #$01
        cpx free_entry_offset
        bne dir_note_entry
        beq dir_next_entry

; Re-read the directory block of the entry noted in entry_track-entry_offset and
; continue with the entry after it.
dir_resume_entry                        ; $C0E0
        lda entry_track
        sta track
        lda entry_sector
        sta sector
        jsr open_internal_read
        lda entry_offset
        jsr buffer_set_ptr

; Advance to the next entry (8 per block), reading the next directory
; block when necessary.  The first free entry seen is remembered.
dir_next_entry                          ; $C0F3
        lda #$FF
        sta match_index
        lda dir_entries_left
        bmi dne_next_block
        lda #$20                        ; next entry: 32 bytes on
        jsr buffer_ptr_add
        jmp dir_entry_check
dne_next_block                          ; $C105
        jsr file_first_block            ; next directory block
        jmp dir_block_start

; Remember block and offset of the current entry in entry_track-entry_offset.
dir_note_entry                          ; $C10B
        lda dir_ptr
        sta entry_offset
        jsr header_get_for_sa
        lda sector
        sta entry_sector
        lda track
        sta entry_track
        rts

; Copy the name at command index X into buffer Y and pad it with
; shifted spaces to A characters.
name_to_buffer_padded                   ; $C11E
        pha
        jsr name_measure
        jsr name_to_buffer
        pla
        sec
        sbc name_len
        tax
        beq loc_C137
        bcc loc_C137
        lda #$A0                        ; pad with shifted space
ntb_pad                                 ; $C131
        sta (dir_ptr),y
        iny
        dex
        bne ntb_pad
loc_C137
        rts

; Copy the name at command index X into buffer Y.
name_to_buffer                          ; $C138
        tya
        asl
        tay
        lda buf_ptrs,y
        sta dir_ptr
        lda buf_ptrs+1,y
        sta dir_ptr+1
        ldy #$00
ntb_copy                                ; $C147
        lda cmd_buf,x
        sta (dir_ptr),y
        iny
        beq loc_C155
        inx
        cpx name_end
        bcc ntb_copy
loc_C155
        rts

; Find the end of the name starting at index X (',' or '=' or 16
; characters).  Out: name_end = end index, name_len = length.
name_measure                            ; $C156
        lda #$00
        sta name_len
        txa
        pha
nm_loop                                 ; $C15D
        lda cmd_buf,x
        cmp #$2C
        beq nm_done
        cmp #$3D
        beq nm_done
        inc name_len
        inx
        lda #$0F                        ; at most 16 characters
        cmp name_len
        bcc nm_done
        cpx cmd_len
        bcc nm_loop
nm_done                                 ; $C177
        stx name_end
        pla
        tax
        rts

; Build the next directory line, preserving the caller's channel.
listing_next_line                       ; $C17D
        lda sec_addr
        pha
        lda channel
        pha
        jsr listing_build_line
        pla
        sta channel
        pla
        sta sec_addr
        rts

; Build one line of the listing in line_buf: block count, quoted name,
; file type (with '*' for unclosed and '<' for locked files) and the
; entry's date and time.  The partition directory shows partition
; number and partition type instead.  Out: carry clear = no more
; entries, the 'BLOCKS FREE.' line was built.
listing_build_line                      ; $C18D
        lda #$11
        sta sec_addr
        jsr channel_find_read
        jsr buffer_get_ptr
        lda match_index
        bpl lbl_entry
        jsr listing_blocks_free         ; no more entries: last line
        clc
        rts
lbl_entry                               ; $C1A1
        ldx #$18
        ldy #$1D
        bit listing_mode                ; partition directory?
        bpl loc_C1AE
        lda #$00
        beq loc_C1B0
loc_C1AE
        lda (dir_ptr),y                 ; block count high
loc_C1B0
        sta line_number_hi
        beq loc_C1B7
        ldx #$16
loc_C1B7
        dey
        bit listing_mode
        bpl loc_C1D1
        lda dir_ptr                     ; partition number from entry position
        lsr
        lsr
        lsr
        lsr
        lsr
        sta line_number_lo
        lda sector
        asl
        asl
        asl
        clc
        adc line_number_lo
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C1D1
        lda (dir_ptr),y
        sta line_number_lo
        cpx #$16
        beq lbl_type
        cmp #$0A                        ; indent by the number of digits
        bcc lbl_type
        dex
        cmp #$64
        bcc lbl_type
        dex
lbl_type                                ; $C1E4
        jsr listing_clear_line
        lda (dir_ptr),y
        bit listing_mode
        bmi loc_C1FB
        pha
        asl
        bpl loc_C1F7
        lda #$3C                        ; '<' marks a locked file
        sta $2FE1,x
loc_C1F7
        pla
        jmp loc_C206
loc_C1FB
        cmp #$FF                        ; partition type $FF = system
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
        lda type_names_3,y              ; three letters of the type
        sta line_buf,x
        dex
        lda type_names_2,y
        sta line_buf,x
        dex
        lda type_names_1,y
        sta line_buf,x
        dex
        dex
        bcs lbl_name
        lda #$2A                        ; '*' marks an unclosed file
        sta $2FE1,x
lbl_name                                ; $C226
        lda #$A0
        sta line_buf,x
        dex
        ldy #$12                        ; name, back to front
loc_C22E
        lda (dir_ptr),y
        sta line_buf,x
        dex
        dey
        cpy #$03
        bcs loc_C22E
        lda #$22                        ; opening quote
        sta line_buf,x
lbl_find_end                            ; $C23E
        inx
        cpx #$20
        bcs lbl_close_quote
        lda line_buf,x
        cmp #$22
        beq lbl_close_quote
        cmp #$A0
        bne lbl_find_end
lbl_close_quote                         ; $C24E
        lda #$22                        ; closing quote behind the name
        sta line_buf,x
loc_C253
        inx
        cpx #$20
        bcs lbl_time
        lda #$7F                        ; unshift what follows the name
        and line_buf,x
        sta line_buf,x
        bpl loc_C253
lbl_time                                ; $C262
        ldx #$04                        ; date and time bytes of the entry
        ldy #$1B
loc_C266
        lda (dir_ptr),y
        sta entry_date,x
        dey
        dex
        bpl loc_C266
        lda entry_date+3                ; convert the hour to 12 hour form
        cmp #$0C
        bcc loc_C27E
        sbc #$0C
        sta entry_date+3
        lda #$80                        ; PM
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_C27E
        lda #$00
        sta entry_pm
        lda entry_date+3
        bne loc_C28D
        lda #$0C
        sta entry_date+3
loc_C28D
        jsr dff_next                    ; position on the next matching entry
        sec
        rts

; Type names by column: DEL SEQ PRG USR REL CBM DIR, then the
; partition types SYS NAT 41 71 81 C81 PRN FOR.
type_names_1                            ; $C292
        !text "DSPURCD"                 ; $C292
txt_C299
        !text "SN478CPF"                ; $C299
type_names_2                            ; $C2A1
        !text "EERSEBIYA1118RO"         ; $C2A1
type_names_3                            ; $C2B0
        !text "LQGRLMRST   1NR"         ; $C2B0

; Fill the line buffer with spaces.
listing_clear_line                      ; $C2BF
        ldy #$1B
        lda #$20
loc_C2C3
        sta $2FDF,y
        dey
        bne loc_C2C3
        rts

; Header shown for the partition directory: name 'CMD HD', ID 'HD',
; DOS type '1H'.
part_dir_header                         ; $C2CA
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $C2CA
        !byte $20,$20,$20,$20,$20,$20,$20,$20 ; $C2D2
        !byte $A0,$A0,$48,$44,$A0,$31,$48 ; $C2DA

; Build the header line: reverse-on, quoted disk name, ID and DOS type
; from the header block (or part_dir_header for the partition directory).
listing_header                          ; $C2E1
        bit listing_mode
        bpl loc_C2F3
        ldx #$17
loc_C2E8
        lda part_dir_header,x
        sta sys_buf+4,x
        dex
        bpl loc_C2E8
        bmi lh_build
loc_C2F3
        jsr partition_check_ready
        jsr header_read
lh_build                                ; $C2F9
        jsr listing_clear_line
        lda #$FF
        sta tmp0
        lda #$00
        sta line_number_lo
        sta line_number_hi
        lda #$22
        sta dir_ptr+1
        ldy cur_partition
        cpy #$FF
        beq loc_C31E
        lda part_type,y                 ; native / 1581: disk name at offset 4
        cmp #$01
        beq loc_C31E
        cmp #$04
        bcc loc_C321
loc_C31E
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction  1541 / 1571: at offset $90
loc_C321
        lda #$90
        sta dir_ptr
        ldy #$00
lh_copy_name                            ; $C327
        lda (dir_ptr),y
        cmp #$A0
        bne loc_C32F
        lda #$20
loc_C32F
        sta $2FE2,y
        iny
        cpy #$17
        bcc lh_copy_name
        ldy #$FF
        lda #$04
        sta dir_ptr
        lda #$12                        ; reverse on
        sta line_buf
        lda #$22
        sta $2FE1
        sta $2FF2
        lda #$20
        sta $2FF3
        rts

; Build the 'BLOCKS FREE.' line.
listing_blocks_free                     ; $C350
        jsr listing_clear_line
        ldy #$0B
loc_C355
        lda txt_blocks_free,y
        sta line_buf,y
        dey
        bpl loc_C355
        jmp blocks_free_get

; Text of the last directory line.
txt_blocks_free                         ; $C361
        !text "BLOCKS FREE."            ; $C361

; Delete the current directory entry: type byte 0, block written back.
dir_delete_entry                        ; $C36D
        ldy #$00
        tya
        sta (dir_ptr),y
        jsr block_write_next            ; write the block
        jmp job_wait

; Open track/sector for reading on the internal channel 17 as a SEQ file
; (open_internal_type: file type in A).
open_internal_read                      ; $C378
        lda #$01

open_internal_type                      ; $C37A
        sta file_type
        lda #$11
        sta sec_addr
        jsr channel_open_read
        lda #$02
        jmp buffer_set_ptr

; Open the internal write channel 18.
open_internal_write                     ; $C389
        lda #$12
        sta sec_addr
        jmp channel_open_new

; Append a new block to the directory: allocate it, link it from the
; current last block and clear it.
dir_add_block                           ; $C390
        jsr header_get_for_sa
        jsr alloc_next_dir_block        ; next free block
        lda #$00
        jsr buffer_set_ptr
        lda track                       ; link it from the old last block
        jsr buffer_put_byte_chk
        lda sector
        jsr buffer_put_byte_chk
        jsr channel_block_write         ; write the old block
        jsr job_wait
        lda #$00
        jsr buffer_set_ptr
dab_clear                               ; $C3B0
        jsr buffer_put_byte_chk
        bne dab_clear
        jsr buffer_put_byte_chk
        lda #$FF                        ; link 0 / $FF marks the new last block
        jmp buffer_put_byte_chk

; Create a directory entry for the new file: take the free entry found
; by the search (or extend the directory), fill in type, start block,
; name and - for REL files - side sector and record length.  When the
; directory itself grew, the block count in the parent's DIR entry is
; increased.
dir_create_entry                        ; $C3BD
        lda sec_addr
        pha
        lda channel
        pha
        lda sector
        pha
        lda track
        pha
        lda #$00
        sta file_dir_track
        lda #$11
        sta sec_addr
        jsr header_get_for_sa
        lda file_type
        pha
        lda file_partition              ; free entry known for this partition?
        cmp free_entry_part
        beq dce_same_part
        ldx #$01
        stx free_entry_offset
        jsr dir_first_entry
        beq dce_new_block
        bne dce_fill
dce_same_part                           ; $C3ED
        lda free_entry_track
        beq dce_search_free
        cmp track
        bne dce_load_free
        lda sector
        cmp free_entry_sector
        beq dce_fill
dce_load_free                           ; $C3FD
        lda free_entry_track
        sta track
        lda free_entry_sector
        sta sector
        jsr buffer_block_read
        jmp dce_fill
dce_search_free                         ; $C40D
        lda #$01
        sta free_entry_offset
        jsr dir_next_entry
        bne dce_fill
dce_new_block                           ; $C417
        jsr dir_add_block               ; none: add a directory block
        sec
        ror file_dir_track
        lda sector
        sta free_entry_sector
        lda track
        sta free_entry_track
        lda #$02
        sta free_entry_offset
dce_fill                                ; $C42D
        lda free_entry_offset
        jsr buffer_set_ptr
        pla
        sta file_type
        cmp #$04                        ; REL files are born closed
        bne loc_C43D
        ora #$80
loc_C43D
        jsr buffer_put_byte_chk
        pla
        sta file_track
        jsr buffer_put_byte_chk
        pla
        sta file_sector
        jsr buffer_put_byte_chk
        jsr active_buffer
        tay
        lda file_name_pos
        tax
        lda #$10                        ; name, padded to 16
        jsr name_to_buffer_padded
        ldy #$10
        lda #$00
dce_clear                               ; $C45F
        sta (dir_ptr),y
        iny
        cpy #$1B
        bcc dce_clear
        lda file_type
        cmp #$04
        bne dce_write
        ldy #$10
        lda side_track                  ; side sector track / sector, record length
        sta (dir_ptr),y
        iny
        lda side_sector
        sta (dir_ptr),y
        iny
        lda record_len
        sta (dir_ptr),y
dce_write                               ; $C480
        jsr buffer_block_write
        bit file_dir_track
        bpl dce_done
        jsr partition_is_native
        bne dce_done
        lda dir_hdr_track
        cmp #$01
        bne dce_parent_count
        cmp dir_hdr_sector
        beq dce_done
dce_parent_count                        ; $C499
        jsr parent_header_read
        lda sys_buf,x                   ; parent's entry must be a DIR entry pointing here
        cmp #$86
        bne dce_done
        lda sys_buf+1,x
        cmp dir_hdr_track
        bne dce_done
        lda sys_buf+2,x
        cmp dir_hdr_sector
        bne dce_done
        inc sys_buf+28,x                ; one more block in the directory
        bne loc_C4BB
        inc sys_buf+29,x
loc_C4BB
        jsr sysbuf_write
dce_done                                ; $C4BE
        pla
        sta channel
        tax
        pla
        sta sec_addr
        lda free_entry_track            ; remember the entry place for the channel
        sta file_dir_track
        sta chan_dir_track,x
        lda free_entry_sector
        sta file_dir_sector
        sta chan_dir_sector,x
        lda free_entry_offset
        sta file_dir_index
        sta chan_dir_offset,x
        lda file_type
        sta file_type_flags
        rts

; Start a directory listing on channel 0: load address $0401, the
; header line with the partition number as line number, then the first
; entry line.
listing_start                           ; $C4E7
        lda #$00
        sta sec_addr
        lda #$01
        jsr channel_alloc_read
        lda #$00
        jsr buffer_set_ptr
        ldx channel
        lda #$00
        sta chan_last_index,x
        jsr active_buffer
        tax
        lda #$00
        sta job_code_saved,x
        lda #$01                        ; load address $0401
        jsr buffer_put_byte_chk
        lda #$04
        jsr buffer_put_byte_chk
        lda #$01
        jsr buffer_put_byte_chk
        jsr buffer_put_byte_chk
        lda cur_partition               ; line number = partition number
        bne loc_C51E
        lda #$FF
loc_C51E
        jsr buffer_put_byte_chk
        lda #$00
        jsr buffer_put_byte_chk
        jsr listing_copy_line
        dec buf_ptrs,x
        dec buf_ptrs,x
        lda #$01
        sta listing_col
        lda #$00
        jsr buffer_put_byte_chk

; Append the next line to the listing buffer: link, block count, text.
listing_line                            ; $C537
        lda #$01
        jsr buffer_put_byte_chk
        jsr buffer_put_byte_chk
        jsr listing_next_line
        bcc listing_last_line
        lda line_number_lo              ; line number = block count
        jsr buffer_put_byte_chk
        lda line_number_hi
        jsr buffer_put_byte_chk
        jsr listing_copy_line
        bit listing_mode                ; long listing: add date and time
        bvc loc_C55B
        jsr listing_add_time
loc_C55B
        lda #$00
        jsr buffer_put_byte_chk
        bne listing_line
listing_ready                           ; $C562
        lda #$00
        sta buf_ptrs,x
        lda #$88                        ; status: ready, last buffer
        ldy channel
        sta dir_listing_flag
        sta chan_status,y
        lda bus_data
        rts
listing_last_line                       ; $C573
        bit listing_mode
        bpl loc_C582
        jsr buffer_put_byte_chk
        dec buf_ptrs,x
        dec buf_ptrs,x
        jmp lll_end
loc_C582
        lda line_number_lo
        jsr buffer_put_byte_chk
        lda line_number_hi
        jsr buffer_put_byte_chk
        jsr listing_copy_line
lll_end                                 ; $C591
        dec buf_ptrs,x
        dec buf_ptrs,x
        lda #$00
        jsr buffer_put_byte_chk
        jsr buffer_put_byte_chk
        jsr buffer_put_byte_chk
        lda buf_ptrs,x                  ; index of the last byte
        sec
        sbc #$01
        ldy channel
        sta chan_last_index,y
        jmp listing_ready

; Copy the 27-character line buffer to the channel buffer.
listing_copy_line                       ; $C5AD
        ldy #$00
loc_C5AF
        lda line_buf,y
        jsr buffer_put_byte_chk
        iny
        cpy #$1B
        bne loc_C5AF
        rts

; Long listing ('$=T'): append date and time to the line, padding the
; line to a fixed width; several entries share one screen line group.
listing_add_time                        ; $C5BB
        lda #$1F
        sta listing_width
loc_C5C0
        dec buf_ptrs,x
        dec listing_width
loc_C5C5
        lda (buf_ptrs,x)
        cmp #$20
        beq loc_C5C0
        bit listing_long
        bmi loc_C5DB
        dec buf_ptrs,x
        dec listing_width
        cmp #$3C
        beq loc_C5C5
        bne lat_write
loc_C5DB
        jsr ttt_put
        cmp #$3C
        beq loc_C5E5
        jsr ttt_space
loc_C5E5
        jsr ttt_space
lat_write                               ; $C5E8
        jsr time_to_text
lat_pad                                 ; $C5EB
        lda #$29
        bit listing_long
        bpl loc_C5F4
        lda #$3F
loc_C5F4
        cmp listing_width
        beq lat_count
        lda #$01
        jsr ttt_put
        jmp lat_pad
lat_count                               ; $C601
        inc listing_col
        lda #$06
        bit listing_long
        bpl loc_C60D
        lda #$04
loc_C60D
        cmp listing_col
        bne loc_C61B
lat_fill                                ; $C612
        lda #$01
        jsr buffer_put_byte_chk
        bne lat_fill
        dec buf_ptrs,x
loc_C61B
        rts

; Append the entry's date and time as text: mm/dd/yy hh.mm xM
; (short form without the year).
time_to_text                            ; $C61C
        ldy #$01
ttt_field                               ; $C61E
        jsr ttt_two_digits
        iny
        cpy #$03
        bne loc_C638
        bit listing_long
        bpl loc_C638
        ldy #$00
        jsr ttt_two_digits
        jsr ttt_space
        jsr ttt_space
        ldy #$03
loc_C638
        cpy #$05
        bcc ttt_field
        lda #$20
        jsr ttt_put
        lda #$41
        bit entry_pm                    ; A or P
        bpl loc_C64A
        lda #$50
loc_C64A
        jsr ttt_put
        bit listing_long
        bpl loc_C657
        lda #$4D                        ; M
        jsr ttt_put
loc_C657
        rts

; Append separator Y and field Y of entry_date as two decimal digits.
ttt_two_digits                          ; $C658
        lda date_separators,y
        jsr ttt_put
        lda entry_date,y
        jsr binary_split_tens
        pha
        lda tmp0
        jsr ttt_digit
        pla

ttt_digit                               ; $C66B
        ora #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
ttt_space                               ; $C66E
        lda #$20

ttt_put                                 ; $C670
        jsr buffer_put_byte_chk
        inc listing_width
        rts

; Separators in front of month, day, year, hour and minute.
date_separators                         ; $C677
        !text "/ / ."                   ; $C677

; Out: line_number_lo/line_number_hi = number of free blocks of the current partition.
blocks_free_get                         ; $C67C
        txa
        pha
        tya
        pha
        jsr bam_select_checked          ; count the free blocks
        lda bam_free_lo,x
        sta line_number_lo
        lda bam_free_hi,x
        sta line_number_hi
        pla
        tay
        pla
        tax
        rts

; ==========================================================================
; OPEN of a data channel: the command buffer holds the file name string.
;   '*' on channel 0   reload the last program of the partition
;   '$...'             directory (listing on channel 0, raw otherwise)
;   '#...'             direct access buffer
;   name[,type][,mode] or name,L,reclen
; ==========================================================================
open_file                               ; $C694
        lda sec_addr                    ; keep the secondary address
        sta open_sa
        jsr cmd_trim                    ; length of the name string
        stx cmd_index
        ldx cmd_buf
        lda open_sa
        bne open_chk_dollar
        cpx #$2A                        ; '*' on channel 0
        bne open_chk_dollar
        jsr bam_select_slot
        lda last_prg_track,x            ; last program of this partition
        beq open_star_init
        sta track
        lda last_prg_sector,x
        sta sector
        lda cur_partition
        sta file_partition
        lda #$02                        ; as PRG
        sta file_type_flags
        jsr led_activity_on
        jsr channel_open_read           ; open it for reading
        lda #$04
open_set_type                           ; $C6CB
        ldx channel
        sta chan_file_type,y
        jmp cmd_done
open_chk_dollar                         ; $C6D3
        cpx #$24                        ; '$'
        bne open_chk_hash
        lda open_sa
        bne open_dir_as_file
        jmp open_listing                ; channel 0: directory listing

; '$' on another channel than 0: the directory blocks are read as a
; sequential file.
open_dir_as_file                        ; $C6DE
        jsr find_colon
        bne loc_C6E9
        jsr parse_partition_led
        jmp odf_open
loc_C6E9
        dey
        dey
        sty file_name_pos
        jsr resolve_first_name
        lda #$00
        jsr resolve_path
odf_open                                ; $C6F6
        lda dir_hdr_track               ; open the directory header block
        sta track
        lda dir_hdr_sector
        sta sector
        jsr channel_open_read
        lda #$02
        jmp open_set_type
open_chk_hash                           ; $C708
        cpx #$23                        ; '#'
        bne open_named
        jmp open_direct_channel
open_star_init                          ; $C70F
        lda #$02                        ; no last program: fall back to the first PRG
        sta type_option
        jsr partition_init

; Parse the name and the ,type ,mode options, look the name up and
; decide between read, write, append, modify and relative access.
open_named                              ; $C717
        jsr find_colon
        bne loc_C720
        ldx #$00
        beq opn_scan
loc_C720
        txa
        beq loc_C728
        lda #$30                        ; error 30
        jmp cmd_error
loc_C728
        dey
        beq opn_scan
        dey
opn_scan                                ; $C72C
        sty file_name_pos
        lda #$8D
        jsr scan_for_char
        inx
        stx file_count
        jsr resolve_first_name
        jsr require_partition_ready
        jsr dir_find_first_path0        ; look the name up
        ldx #$00
        stx record_len
        stx open_mode
        stx file_type
        inx
        cpx param_count
        bcs opn_defaults
        jsr parse_mode_type             ; first option
        inx
        cpx param_count
        bcs opn_defaults
        cpy #$04                        ; type L: next field is the record length
        beq opn_record_len
        jsr parse_mode_type             ; second option
opn_defaults                            ; $C762
        ldx open_sa
        stx sec_addr
        cpx #$02                        ; channels 0 and 1: LOAD and SAVE
        bcs opn_type
        stx open_mode
        lda file_type
        bne opn_mode
        lda #$02                        ; default type PRG
        sta file_type
opn_type                                ; $C777
        lda file_type
        bne opn_mode
        lda file_type_flags             ; otherwise the type of the file found
        and #$07
        sta file_type
        lda file_track
        bne opn_mode
        lda #$01                        ; or SEQ for a new one
        sta file_type
opn_mode                                ; $C78E
        lda open_mode
        cmp #$01                        ; mode 1 = write
        beq open_write
        jmp open_existing
opn_record_len                          ; $C798
        ldy file_name_pos,x
        lda cmd_buf,y
        sta record_len
        lda file_track
        bne opn_defaults
        lda #$01
        sta open_mode
        bne opn_defaults

; Open for writing.  An existing unclosed entry is deleted first; an
; existing closed file needs '@' (else error 63), a wildcard is error 33.
open_write                              ; $C7AD
        lda file_type_flags
        and #$80
        tax
        bne opw_conflict
        lda #$20                        ; unclosed leftover entry: delete it
        bit file_type_flags
        beq opw_exists
        jsr dir_delete_entry
        jmp open_create
opw_exists                              ; $C7C2
        lda file_track
        bne opw_conflict
        jmp open_create
opw_conflict                            ; $C7CA
        lda cmd_buf
        cmp #$40                        ; '@'
        beq open_replace
        txa
        bne opw_error_33
        lda #$63                        ; error 63 FILE EXISTS
        jmp cmd_error
opw_error_33                            ; $C7D9
        lda #$33                        ; error 33
        jmp cmd_error

; '@' save with replace: write into a fresh chain, remember it in the
; old entry (replace flag and new start block at offset $1A) so that
; CLOSE can swap the chains.
open_replace                            ; $C7DE
        lda file_type_flags
        and #$07
        cmp file_type
        bne error_64
        cmp #$04                        ; REL files cannot be replaced
        beq error_64
        jsr channel_open_new
        lda channel
        sta write_channel
        lda #$11
        sta sec_addr
        jsr channel_find_read
        lda entry_offset
        jsr buffer_set_ptr
        ldy #$00
        lda (dir_ptr),y                 ; set the replace flag in the old entry
        ora #$20
        sta (dir_ptr),y
        ldy #$1A                        ; new start block into the entry
        lda track
        sta (dir_ptr),y
        iny
        lda sector
        sta (dir_ptr),y
        ldx write_channel
        lda file_dir_track
        sta chan_dir_track,x
        lda file_dir_sector
        sta chan_dir_sector,x
        lda file_dir_index
        sta chan_dir_offset,x
        jsr header_get_for_sa
        jsr buffer_block_write
        jmp open_note_last

; Open an existing file for read, append or modify.  Error 62 if it is
; missing, 60 if it is open for writing, 64 on a type mismatch.
open_existing                           ; $C832
        lda file_track
        bne ope_found
        lda #$62                        ; error 62 FILE NOT FOUND
        jmp cmd_error
ope_found                               ; $C83C
        lda open_mode
        cmp #$03                        ; mode 3 = modify may open unclosed files
        beq ope_type_check
        lda #$20
        bit file_type_flags
        beq ope_type_check
        lda #$60                        ; error 60 WRITE FILE OPEN
        jmp cmd_error
ope_type_check                          ; $C84F
        lda file_type_flags
        and #$07
        cmp file_type
        beq ope_open
error_64                                ; $C859
        lda #$64
        jmp cmd_error
ope_open                                ; $C85E
        ldy #$00
        sty parse_index
        ldx open_mode
        cpx #$02                        ; mode 2 = append
        bne ope_read
        cmp #$04
        beq error_64
        lda (dir_ptr),y                 ; re-open the entry: clear the closed bit
        and #$4F
        sta (dir_ptr),y
        lda sec_addr
        pha
        lda #$11
        sta sec_addr
        jsr header_get_for_sa
        jsr buffer_block_write
        pla
        sta sec_addr
ope_read                                ; $C884
        jsr open_read_entry
        lda open_mode
        cmp #$02
        bne open_note_last
        jsr append_seek_end             ; append: go to the end of the file
        jmp cmd_done

; Take side sector and record length from the entry (error 50 if a
; given record length differs) and open the file's first block.
open_read_entry                         ; $C894
        ldy #$13
        lda (dir_ptr),y
        sta side_track
        iny
        lda (dir_ptr),y
        sta side_sector
        iny
        lda (dir_ptr),y
        ldx record_len
        sta record_len
        txa
        beq ore_open
        cmp record_len
        beq ore_open
        lda #$50                        ; error 50 RECORD NOT PRESENT
        jsr cmd_error
ore_open                                ; $C8B7
        ldx parse_index
        lda file_track,x
        sta track
        lda file_sector,x
        sta sector
        jsr channel_open_read           ; open the first block
        ldy channel
        ldx parse_index
        lda file_dir_track,x            ; note the entry place for the channel
        sta chan_dir_track,y
        lda file_dir_sector,x
        sta chan_dir_sector,y
        lda file_dir_index,x
        sta chan_dir_offset,y
        rts

; Create a new file: channel, first block and directory entry.
open_create                             ; $C8DF
        jsr channel_open_new
        jsr dir_create_entry

; For LOAD/SAVE channels remember the file's start block as the 'last
; program' of the partition (for '*').
open_note_last                          ; $C8E5
        lda sec_addr
        cmp #$02
        bcs open_done
        jsr header_get_active
        jsr bam_select_slot
        lda track
        sta last_prg_track,x
        lda sector
        sta last_prg_sector,x
open_done                               ; $C8FB
        jmp cmd_done

; Classify the option letter behind a comma: mode R W A M sets open_mode,
; file type D S P U L C sets file_type.
parse_mode_type                         ; $C8FE
        ldy file_name_pos,x
        lda cmd_buf,y
        ldy #$04
pmt_mode                                ; $C906
        dey
        bmi pmt_type
        cmp mode_chars,y
        bne pmt_mode
        sty open_mode
pmt_type                                ; $C911
        ldy #$06
pmt_type_loop                           ; $C913
        dey
        bmi pmt_rts
        cmp type_chars,y
        bne pmt_type_loop
        sty file_type
pmt_rts                                 ; $C91E
        rts

; Mode letters R W A M followed by the type letters D S P U L C.
mode_chars                              ; $C91F
        !text "RWAM"                    ; $C91F
type_chars                              ; $C923
        !text "DSPULC"                  ; $C923

; Append: read through the file to its last block and position the
; write pointer behind the last byte (starting a new block if full).
append_seek_end                         ; $C929
        jsr channel_read_link           ; follow the links to the last block
        lda track
        beq ase_at_end
        jsr file_first_block
        jmp append_seek_end
ase_at_end                              ; $C936
        ldx channel                     ; the last block is counted again when written
        lda chan_blocks_lo,x
        bne loc_C940
        dec chan_blocks_hi,x
loc_C940
        dec chan_blocks_lo,x
        ldx sector                      ; index behind the last byte
        inx
        txa
        bne ase_set_ptr
        lda #$00
        jsr buffer_set_ptr
        jsr file_buffer_full            ; block full: start a new one
        lda #$02
ase_set_ptr                             ; $C953
        jsr buffer_set_ptr
        ldx channel
        lda #$01                        ; status: ready to listen
        sta chan_status,x
        lda #$80                        ; mark the channel as open for writing
        ora channel
        ldx sec_addr
        sta sa_channel,x
        rts

; OPEN of '$' on channel 0: directory listing.  Forms: '$', '$n',
; '$n:pattern', '$=P' partition directory, '$=T' listing with date and
; time; behind '$=T:pattern' the options '=<date' (not after), '=>date'
; (not before), '=L' long format and '=N' are accepted.
open_listing                            ; $C967
        lda #$0C
        sta cmd_index
        ldy #$01                        ; pattern starts behind the '$'
        sty listing_mode
        ldx cmd_len
        dex
        beq ol_all_files
        jsr find_separator
        beq ol_pattern
        ldy #$01
        lda cmd_buf+1
        cmp #$3D
        bne loc_C998
        lda cmd_buf+2                   ; '$=T' or '$=P'
        cmp #$54
        beq ol_option
        cmp #$50
        bne loc_C998
ol_option                               ; $C98F
        ldy #$03
        sty listing_mode
        cpy cmd_len
        beq ol_all_files
loc_C998
        dey
ol_digits                               ; $C999
        iny
        jsr is_digit
        beq ol_digits
        cpy cmd_len
        bne ol_pattern
        ldy listing_mode                ; partition number behind the '$'
        jsr parse_partition_num
ol_all_files                            ; $C9A9
        lda cur_partition
        sta file_partition
        inc param_count
        inc file_count
        ldy listing_mode
        lda #$2A                        ; no pattern: use '*'
        sta cmd_buf,y
        sty file_name_pos
        sty file_name_start
        iny
        sty cmd_len
        sty name2_index
        lda #$80
        sta file_type_flags
        bmi ol_options
ol_pattern                              ; $C9D0
        jsr find_colon
        bne loc_C9DD
        jsr parse_reset
        ldy listing_mode
        iny
        iny
loc_C9DD
        dey
        dey
        sty file_name_pos
        jsr parse_after_colon
        jsr resolve_names
ol_options                              ; $C9E8
        lda cmd_buf+1
        cmp #$3D
        bne loc_CA3E
        lda cmd_buf+2
        cmp #$50
        beq ol_partition_dir
        cmp #$54
        bne loc_CA3E
        lda #$40                        ; bit 6: with date and time
        sta listing_mode
        lsr listing_long
        ldy param_count
ol_time_opts                            ; $CA05
        cpy file_count
        bcs ol_start
        ldx file_name_pos,y
        lda cmd_buf,x
        cmp #$3C                        ; '<' date: not after
        bne ol_opt_after
        ror search_type_a
        clc
        jsr parse_date_time
ol_opt_after                            ; $CA1B
        cmp #$3E                        ; '>' date: not before
        bne ol_opt_long
        ror search_type_b
        sec
        jsr parse_date_time
ol_opt_long                             ; $CA26
        cmp #$4C                        ; L: long date format
        bne ol_opt_n
        ror listing_long
ol_opt_n                                ; $CA2D
        cmp #$4E                        ; N: plain listing
        bne ol_opt_next
        lda #$00
        sta listing_mode
ol_opt_next                             ; $CA36
        iny
        bne ol_time_opts
        beq ol_start
ol_partition_dir                        ; $CA3B
        lda #$80                        ; bit 7: partition directory
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_CA3E
        lda #$00
        sta listing_mode
ol_start                                ; $CA43
        bit listing_mode
        bpl ol_type
        lda #$00                        ; partition directory lives in partition 0
        tay
loc_CA4B
        sta file_partition,y
        iny
        cpy param_count
        bcc loc_CA4B
        jsr partition_select
ol_type                                 ; $CA57
        lda #$00
        sta type_option
        ldy param_count
        cpy file_count
        beq ol_build
        jsr sub_B908
ol_build                                ; $CA67
        jsr require_partition_ready
        lda #$00
        jsr resolve_path
        jsr listing_header              ; header line
        jsr dir_find_first              ; first matching entry
        jsr listing_start               ; first lines of the listing
        jsr buffer_get_byte
        ldx channel
        sta chan_data,x
        lda #$04                        ; channel type: directory
        sta chan_file_type,x
        lda #$00
        sta cmdbuf_ptr
        rts

; Parse a date/time option 'mm/dd/yy hh:mm xM' at command index X into
; the search filter (carry clear: filter_date_from not-after, set: filter_date_to).
parse_date_time                         ; $CA8A
        pha
        tya
        pha
        lda #$04
        bcc loc_CA93
        lda #$09
loc_CA93
        pha
        ldy #$00
        stx tmp1
pdt_field                               ; $CA98
        ldx tmp1
        txa
        clc
        adc date_field_offsets,y
        tax
        jsr parse_two_digits
        sta entry_date,y
        iny
        cpy #$05
        bcc pdt_field
        lda entry_date+3                ; 12 o'clock is hour 0
        sbc #$0C
        bne pdt_ampm
        sta entry_date+3
pdt_ampm                                ; $CAB5
        inx
        inx
        lda cmd_buf,x
        and #$7F
        cmp #$41                        ; 'A'M?
        beq pdt_store
        lda entry_date+3                ; PM: add 12
        clc
        adc #$0C
        sta entry_date+3
pdt_store                               ; $CAC9
        pla
        tay
        ldx #$04
loc_CACD
        lda entry_date,x
        sta filter_date_from,y
        dey
        dex
        bpl loc_CACD
        pla
        tay
        pla
        rts

; Out: A = two ASCII digits at command index X as a binary number.
parse_two_digits                        ; $CADB
        lda cmd_buf,x
        and #$0F
        asl
        sta tmp0
        asl
        asl
        adc tmp0
        sta tmp0
        inx
        lda cmd_buf,x
        and #$0F
        adc tmp0
        rts

; Offsets of year, month, day, hour and minute within the option text.
date_field_offsets                      ; $CAF2
        !byte $07,$01,$04,$0A,$0D       ; $CAF2

; Open a read channel on track/sector: allocate channel and buffer, read
; the first block.  For REL files also load the side sector and set up
; the record pointers.
channel_open_read                       ; $CAF7
        lda #$01
        jsr channel_alloc_read
        jsr channel_reset_buffers
        lda file_type
        pha
        asl                             ; file type * 2 into the channel
        sta chan_file_type,x
        jsr channel_read_first          ; read the first block, track/sector = its link
        ldx channel
        lda track
        bne cor_type
        lda sector                      ; single block: sector byte = index of last byte
        sta chan_last_index,x
cor_type                                ; $CB15
        pla
        cmp #$04                        ; REL?
        bne cor_first_byte
        ldy sec_addr
        lda sa_channel,y
        ora #$40
        sta sa_channel,y
        lda record_len                  ; record length
        sta chan_record_len,x
        jsr buffer_alloc                ; buffer for the side sector
        bpl cor_rel
        jmp error_70_free
cor_rel                                 ; $CB32
        ldx channel
        sta chan_side_buf,x
        ldy side_track
        sty track
        ldy side_sector
        sty sector
        jsr header_set
        jsr side_read                   ; read the side sector
        jsr job_wait
        lda #$02
        jsr side_set_ptr
        ldx channel
        ldy #$00
        lda (dir_ptr),y
        sec                             ; $FE in byte 2 marks a super side sector
        sbc #$FE
        beq cor_side_kind
        lda #$20
cor_side_kind                           ; $CB5C
        sta chan_rel_flags,x
        bne rel_open_finish
        lda side_track                  ; its place
        sta chan_super_track,x
        lda side_sector
        sta chan_super_sector,x
        lda #$FF
        sta chan_side_group,x
rel_open_finish                         ; $CB72
        ldx channel
        lda #$02                        ; first record starts at index 2
        sta chan_record_ptr,x
        lda #$00
        jsr buffer_set_ptr
        jsr rel_first_byte              ; position on record 1
        jmp header_get_active
cor_first_byte                          ; $CB84
        jsr errbuf_get_byte
        ldx channel
        sta chan_data,x
        lda #$88                        ; status: ready to talk
        sta chan_status,x
        rts

; Reset the buffer pointers of the channel to 2 and clear its block
; count and end index.
channel_reset_buffers                   ; $CB92
        ldx channel
        lda chan_buf_a,x
        asl
        bmi crb_second
        tay
        lda #$02
        sta buf_ptrs,y
crb_second                              ; $CBA0
        lda chan_buf_b,x
        ora #$80
        sta chan_buf_b,x
        asl
        bmi crb_counts
        tay
        lda #$02
        sta buf_ptrs,y
crb_counts                              ; $CBB1
        lda #$00
        sta chan_last_index,x
        sta chan_blocks_lo,x
        sta chan_blocks_hi,x
        rts

; Allocate the first block for a new file, then channel_open_write.
channel_open_new                        ; $CBBD
        jsr alloc_first_block

; Open a write channel on track/sector.  For a new REL file the side
; sector (and on native partitions the super side sector) is created
; and the first data block initialised with empty records.
channel_open_write                      ; $CBC0
        lda #$01
        jsr channel_alloc_write
        jsr header_set_active
        jsr channel_reset_buffers
        ldx channel
        lda file_type
        pha
        asl
        sta chan_file_type,x
        pla
        cmp #$04
        beq cow_rel
        lda #$01                        ; status: ready to listen
        sta chan_status,x
        rts
cow_rel                                 ; $CBE0
        ldy sec_addr
        lda sa_channel,y
        and #$3F
        ora #$40
        sta sa_channel,y
        lda record_len
        sta chan_record_len,x
        jsr buffer_alloc
        bpl cow_rel_side
        jmp error_70_free
cow_rel_side                            ; $CBFA
        pha
        jsr partition_type              ; native and 1581: use a super side sector
        cmp #$01
        beq loc_CC06
        cmp #$04
        bcc loc_CC09
loc_CC06
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_CC09
        lda #$20
        ldx channel
        sta chan_rel_flags,x
        pla
        sta chan_side_buf,x
        jsr buffer_clear
        jsr alloc_next_block            ; block for the side sector
        lda track
        sta side_track
        lda sector
        sta side_sector
        ldx channel
        lda chan_side_buf,x
        jsr header_set
        lda #$00
        jsr side_set_position
        lda #$00
        jsr side_put_byte
        lda #$11                        ; side sector number 0, $11 = next free index (?)
        jsr side_put_byte
        lda #$00
        jsr side_put_byte
        lda record_len                  ; record length
        jsr side_put_byte
        lda track
        jsr side_put_byte
        lda sector
        jsr side_put_byte
        lda #$10                        ; data block pointers start at offset $10
        jsr side_set_position
        jsr header_get_active
        lda track
        jsr side_put_byte
        lda sector
        jsr side_put_byte
        jsr side_write                  ; write the side sector
        jsr job_wait
        jsr rel_has_no_super
        bne cow_rel_first_block
        jsr rel_new_super_side
cow_rel_first_block                     ; $CC70
        lda #$02
        jsr buffer_set_ptr
        ldx channel
        sec
        lda #$00
        sbc chan_record_len,x
        sta chan_record_ptr,x
        jsr rel_init_block              ; fill the first data block with empty records
        jsr block_set_last
        jsr block_write_next
        jsr job_wait
        jsr bam_flush                   ; write the BAM back
        jmp rel_open_finish

; Create the super side sector of a REL file and move the first side
; sector group to a fresh block.
rel_new_super_side                      ; $CC92
        ldx channel
        lda chan_side_buf,x
        jsr buffer_clear
        jsr side_set_position
        lda side_track
        jsr side_put_byte
        lda side_sector
        jsr side_put_byte
        lda #$FE                        ; $FE marks the super side sector
        jsr side_put_byte
        lda side_track
        jsr side_put_byte
        lda side_sector
        jsr side_put_byte
        jsr alloc_next_block            ; new block for the side sector itself
        ldx channel
        lda track
        sta chan_super_track,x
        sta side_track
        lda sector
        sta chan_super_sector,x
        sta side_sector
        lda #$FF
        sta chan_side_group,x
        jsr super_write
        jmp header_get_active

; Store A in the side sector buffer of the channel and advance.
side_put_byte                           ; $CCDA
        pha
        ldx channel
        lda chan_side_buf,x
        jmp buffer_put_at

; ==========================================================================
; CLOSE (secondary address $Ex).  Channel 0 ends a LOAD or listing,
; 15 closes every file, others close that one file.
; ==========================================================================
close_handler                           ; $CCE3
        lda sec_addr
        bne close_chk_cmd               ; channel 0
        lda #$00
        sta dir_listing_flag
        jsr channel_free
close_free_internal                     ; $CCEF
        jmp internal_channels_free
close_chk_cmd                           ; $CCF2
        cmp #$0F                        ; 15: close everything
        beq close_all
        jsr close_channel
        lda sec_addr
        cmp #$02
        bcc close_free_internal
        lda cmd_error_code              ; report a pending error
        bne close_finish
close_ok                                ; $CD04
        jmp cmd_ok
close_finish                            ; $CD07
        jmp cmd_finish
close_all                               ; $CD0A
        lda #$0E
        sta sec_addr
close_all_loop                          ; $CD0E
        jsr close_channel
        dec sec_addr
        bpl close_all_loop
        lda cmd_error_code
        beq close_ok
        bne close_finish

; Close the file of secondary address sec_addr: write the last block,
; update the directory entry and the BAM, free channel and buffers.
close_channel                           ; $CD1C
        ldx sec_addr
        lda sa_channel,x
        cmp #$FF
        bne clc_open
        rts
clc_open                                ; $CD26
        and #$3F
        sta channel
        tax
        lda chan_partition,x
        jsr partition_select
        jsr channel_file_type           ; file type
        cmp #$07                        ; direct access: nothing to write
        beq clc_flush_bam
        cmp #$04                        ; REL
        beq close_rel
        jsr channel_find_write          ; open for writing?
        bcs clc_free
        jsr close_write_last            ; write the last block
        jsr close_update_entry          ; update the directory entry
clc_flush_bam                           ; $CD47
        jsr bam_write_if_loaded         ; write the BAM
clc_free                                ; $CD4A
        jmp channel_free

; Close a REL file: compute its block count from the side sector
; position and update the entry if the file was extended.
close_rel                               ; $CD4D
        jsr buffer_flush_if_dirty
        jsr buffers_swap
        jsr rel_seek_end
        ldx rel_side_num
        stx tmp4
        jsr rel_has_no_super
        beq clr_super
        inc tmp4
        lda #$00
        sta tmp1
        sta tmp2
        lda rel_side_index
        sec
        sbc #$0E
        sta tmp3
        jsr rel_count_blocks
        ldx channel
        lda tmp1
        sta chan_blocks_lo,x
        lda tmp2
        sta chan_blocks_hi,x
clr_entry                               ; $CD7D
        lda #$40                        ; file was extended?
        jsr chan_flag_test
        beq clr_free
        jsr close_update_entry
clr_free                                ; $CD87
        jmp channel_free
clr_super                               ; $CD8A
        lda rel_side_index
        sec
        sbc #$0E
        sta tmp3
        lda rel_group
        sta rel_ptr
        jsr rel_count_super
        ldx #$00
        lda #$02
        jsr acc_add_ax
        ldx channel
        lda acc24
        sta chan_blocks_lo,x
        lda acc24+1
        sta chan_blocks_hi,x
        jmp clr_entry

; Write the last data block of a sequential file: an empty file gets a
; single carriage return; the link bytes become 0 / index of last byte.
close_write_last                        ; $CDAF
        ldx channel
        lda chan_blocks_lo,x
        ora chan_blocks_hi,x
        bne cwl_length
        jsr buffer_get_ptr
        cmp #$02
        bne cwl_length
        lda #$0D                        ; empty file: one carriage return
        jsr buffer_put_byte_chk
cwl_length                              ; $CDC5
        jsr buffer_get_ptr
        cmp #$02
        bne cwl_store
        ldx channel
        lda chan_blocks_lo,x
        bne loc_CDD6
        dec chan_blocks_hi,x
loc_CDD6
        dec chan_blocks_lo,x
        lda #$00
cwl_store                               ; $CDDB
        sec
        sbc #$01
        pha
        lda #$00                        ; link: track 0
        jsr buffer_set_ptr
        jsr buffer_put_byte_chk
        pla                             ; index of the last byte
        jsr buffer_put_byte_chk
        jsr channel_block_write         ; write the block
        jmp job_wait

; Update the directory entry on close: set the closed bit, store the
; block count and the time stamp.  For save-with-replace the new chain
; takes the place of the old one, which is freed.
close_update_entry                      ; $CDF1
        lda sec_addr
        pha
        ldx channel
        lda chan_dir_track,x
        sta track
        lda chan_dir_sector,x
        sta sector
        jsr sysbuf_read_ts              ; read the directory block
        ldy channel
        ldx chan_dir_offset,y
        lda sys_buf,x
        and #$20                        ; replace flag?
        bne cue_replace
        lda #$80                        ; no: just set the closed bit
        ora sys_buf,x
        and #$8F
        sta sys_buf,x
        bne cue_counts
cue_replace                             ; $CE1B
        lda chan_file_type,y
        and #$0F
        cmp #$08
        beq cue_counts
        lda sys_buf,x
        and #$8F
        sta sys_buf,x
        lda sys_buf+1,x                 ; old chain
        sta track
        lda sys_buf+2,x
        sta sector
        lda sys_buf+26,x                ; new chain noted at offset $1A
        bne cue_swap
        sta track
        lda sys_buf+27,x
        sta sector
        lda #$67                        ; error 67 if it is missing
        jmp jt_dos_error
cue_swap                                ; $CE47
        sta sys_buf+1,x
        lda sys_buf+27,x
        sta sys_buf+2,x
        lda #$00
        sta sys_buf+26,x
        sta sys_buf+27,x
        jsr free_chain                  ; free the old chain
cue_counts                              ; $CE5B
        pla
        sta sec_addr
        jsr channel_find_write
        ldy channel
        ldx chan_dir_offset,y
        lda chan_blocks_lo,y            ; block count
        sta sys_buf+28,x
        lda chan_blocks_hi,y
        sta sys_buf+29,x
        jsr dir_time_stamp              ; time stamp
        ldy channel
        lda chan_dir_track,y
        sta track
        lda chan_dir_sector,y
        sta sector
        jmp sysbuf_write_ts             ; write the directory block

; Read the next byte of the internal read channel 17 into bus_data;
; eoi_flag becomes 0 at the end of the file.
internal_get_byte                       ; $CE84
        lda #$11
        sta sec_addr
        jsr channel_get_byte
        sta bus_data
        ldx channel
        lda chan_status,x               ; bit 3 clear: last byte
        and #$08
        sta eoi_flag
        bne igb_rts
        jsr channel_file_type
        beq igb_rts
        lda #$80
        jsr chan_flag_set
igb_rts                                 ; $CEA2
        rts

; Out: A = next byte of the channel of secondary address sec_addr.
channel_get_byte                        ; $CEA3
        jsr channel_find_read
        jsr led_activity_on
        jsr channel_file_type
        bne cgb_seq
        jsr talk_rel_file
        jmp cgb_done
cgb_seq                                 ; $CEB4
        jsr talk_seq_file
cgb_done                                ; $CEB7
        ldx channel
        lda chan_data,x
        rts

; Write bus_data to the internal write channel 18 through the sink that
; belongs to its file type.
internal_put_byte                       ; $CEBD
        ldx #$12
        stx sec_addr
        jsr channel_find_write
        jsr led_activity_on
        jsr channel_file_type
        bcc ipb_dispatch
        lda #$20                        ; flag REL data written (?)
        jsr chan_flag_clear
ipb_dispatch                            ; $CED1
        lda sec_addr
        cmp #$0F
        bne ipb_file
        jmp listen_cmd_channel
ipb_file                                ; $CEDA
        jsr channel_file_type
        bcs ipb_rel_or_direct
        jmp listen_seq_file
ipb_rel_or_direct                       ; $CEE2
        bne ipb_direct
        jmp listen_rel_file
ipb_direct                              ; $CEE7
        jmp listen_direct

; Store A in the active buffer of the current channel and advance the
; pointer.  Out: Z set when the buffer became full.  Error 61 if the
; channel has no buffer.
buffer_put_byte_chk                     ; $CEEA
        pha
        jsr active_buffer
        bpl buffer_put_at
        pla
        lda #$61                        ; error 61 FILE NOT OPEN
        jmp cmd_error
buffer_put_at                           ; $CEF6
        asl
        tax
        pla
        sta (buf_ptrs,x)
        inc buf_ptrs,x
        rts

; Out: A = next byte from the active buffer of the current channel.
; After the last valid byte the pointer wraps to 0.
buffer_get_byte                         ; $CEFE
        ldx channel
        lda chan_buf_a,x
        bpl bgb_have_buf
        lda chan_buf_b,x
bgb_have_buf                            ; $CF08
        and #$BF
        asl
        tax
        ldy channel
        lda chan_last_index,y           ; last block of the file?
        beq bgb_plain
        lda (buf_ptrs,x)
        pha
        lda buf_ptrs,x
        cmp chan_last_index,y
        bne loc_CF21
        lda #$FF                        ; last byte read: wrap the pointer
        sta buf_ptrs,x
loc_CF21
        pla
        inc buf_ptrs,x
        rts
bgb_plain                               ; $CF25
        lda (buf_ptrs,x)
        inc buf_ptrs,x
        rts

; Unreferenced: store a byte and start a new block when full.
dead_put_and_extend                     ; $CF2A
        jsr buffer_put_byte_chk
        beq loc_CF30
        rts
loc_CF30
        jsr alloc_next_block
        lda #$00
        jsr buffer_set_ptr
        lda track
        jsr buffer_put_byte_chk
        lda sector
        jsr buffer_put_byte_chk
        jsr channel_block_write
        jsr buffers_swap
        jsr header_set_active
        lda #$02
        jmp buffer_set_ptr

; Relative files: turn the record number (chan_blocks_lo/chan_blocks_hi) and byte
; position rel_byte_pos into a place in the file - side sector group rel_group
; (with a super side sector), side sector rel_side_num, pointer index rel_side_index
; and offset in the data block rel_block_offset.
rel_locate_record                       ; $CF50
        jsr rel_record_offset
        jsr divide_by_254               ; 254 data bytes per block
        lda factor24                    ; remainder = offset in the block
        sta rel_block_offset
        jsr divide_by_120               ; 120 block pointers per side sector
        inc rel_block_offset            ; data start at index 2
        inc rel_block_offset
        jsr rel_has_no_super
        beq rlr_super
        lda acc24
        sta rel_side_num
        lda factor24                    ; pointer index: 2 * n + $10
        asl
        clc
        adc #$10
        sta rel_side_index
        rts
rlr_super                               ; $CF73
        lda factor24
        asl
        clc
        adc #$10
        sta rel_side_index
        jsr divide_by_6                 ; 6 side sectors per group
        lda factor24
        sta rel_side_num
        lda acc24
        sta rel_group
        rts

; Out: acc24-acc24+2 = (record number - 1) * record length + rel_byte_pos.
rel_record_offset                       ; $CF88
        jsr acc_clear
        sta factor24+2
        ldx channel
        lda chan_blocks_lo,x
        sta factor24
        lda chan_blocks_hi,x
        sta factor24+1
        bne loc_CF9F
        lda factor24
        beq rro_multiply
loc_CF9F
        lda factor24                    ; record numbers start at 1
        sec
        sbc #$01
        sta factor24
        bcs rro_multiply
        dec factor24+1
rro_multiply                            ; $CFAA
        lda chan_record_len,x           ; multiply by the record length
        sta tmp0
rro_mul_loop                            ; $CFAF
        lsr tmp0
        bcc loc_CFB6
        jsr acc_add_factor
loc_CFB6
        jsr factor_shift_left
        lda tmp0
        bne rro_mul_loop
        lda rel_byte_pos                ; plus the byte position
        clc
        adc acc24
        sta acc24
        bcc loc_CFCC
        inc acc24+1
        bne loc_CFCC
        inc acc24+2
loc_CFCC
        rts

; Divide acc24-acc24+2 by 254 (data bytes per block), 120 (blocks per side
; sector) or 6 (side sectors per group).  Remainder in factor24.
divide_by_254                           ; $CFCD
        lda #$FE
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
divide_by_120                           ; $CFD0
        lda #$78
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
divide_by_6                             ; $CFD3
        lda #$06
divide_24                               ; $CFD5
        sta tmp0
        lda #$00
        sta factor24
        sta factor24+1
        ldx #$18
div_loop                                ; $CFDF
        asl acc24
        rol acc24+1
        rol acc24+2
        rol factor24
        rol factor24+1
        lda factor24
        sec
        sbc tmp0
        tay
        lda factor24+1
        sbc #$00
        bcc loc_CFFB
        inc acc24
        sta factor24+1
        sty factor24
loc_CFFB
        dex
        bne div_loop
        rts

; Clear the 24-bit accumulator acc24-acc24+2.
acc_clear                               ; $CFFF
        lda #$00
        sta acc24
        sta acc24+1
        sta acc24+2
        rts

; Unreferenced: shift the factor left twice.
acc_shift_twice                         ; $D008
        jsr factor_shift_left

; Shift the 24-bit factor factor24-factor24+2 left.
factor_shift_left                       ; $D00B
        clc
        rol factor24
        rol factor24+1
        rol factor24+2
        rts

; Add the factor factor24-factor24+2 to the accumulator acc24-acc24+2.
acc_add_factor                          ; $D013
        clc
        ldx #$FD
loc_D016
        lda $8E,x
        adc $93,x
        sta $8E,x
        inx
        bne loc_D016
        rts

; Store track/sector as the link of the active buffer and mark it dirty.
block_set_link                          ; $D020
        jsr buffer_start_ptr
        lda track
        sta (dir_ptr),y
        iny
        lda sector
        sta (dir_ptr),y
        jmp buffer_mark_dirty

; Out: track/sector = link bytes of the active buffer.
block_get_link                          ; $D02F
        jsr buffer_start_ptr
        lda (dir_ptr),y
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        rts

; Mark the active buffer as the last block: link track 0, sector byte
; = index of the last byte used.
block_set_last                          ; $D03C
        jsr buffer_start_ptr
        lda #$00
        sta (dir_ptr),y
        iny
        ldx channel
        lda chan_record_ptr,x
        tax
        dex
        txa
        sta (dir_ptr),y
        rts

; Point dir_ptr/dir_ptr+1 at the start of the active buffer.  Out: Y = 0.
buffer_start_ptr                        ; $D04F
        jsr active_buffer
        asl
        tax
        lda buf_ptrs+1,x
        sta dir_ptr+1
        lda #$00
        sta dir_ptr
        ldy #$00
        rts

; Copy A bytes from buffer Y to buffer X.
buffer_copy                             ; $D05F
        pha
        lda #$00
        sta tmp0
        sta tmp2
        tya
        clc
        adc #$03
        sta tmp1
        txa
        clc
        adc #$03
        sta tmp3
        pla
        tay
        dey
loc_D075
        lda (tmp0),y
        sta (tmp2),y
        dey
        bpl loc_D075
        rts

; Clear buffer A.
buffer_clear                            ; $D07D
        tay
        clc
        adc #$03
        sta tmp1
        lda #$00
        sta tmp0
        tay
loc_D088
        sta (tmp0),y
        iny
        bne loc_D088
        rts

; Out: A = number of the side sector held in the buffer.
side_get_number                         ; $D08E
        lda #$00
        jsr side_set_ptr
        ldy #$02
        lda (dir_ptr),y
        rts

; Point dir_ptr/dir_ptr+1 at offset A of the side sector buffer.
side_set_ptr                            ; $D098
        sta dir_ptr
        ldx channel
        lda chan_side_buf,x
        tax
        clc
        adc #$03
        sta dir_ptr+1
        rts

; Set the side sector buffer pointer (and dir_ptr/dir_ptr+1) to offset A.
side_set_position                       ; $D0A6
        pha
        jsr side_set_ptr
        pha
        txa
        asl
        tax
        pla
        sta buf_ptrs+1,x
        pla
        sta buf_ptrs,x
        rts

; Make the side sector entry for the wanted record current.
; Out: V set when the record's block does not exist.
rel_seek_block                          ; $D0B5
        jsr side_test
        bmi rsb_fail
        bvc rsb_ok
        ldx channel
        lda chan_side_buf,x
        jsr indirect_read
        jsr side_test
        bpl rsb_ok
rsb_fail                                ; $D0C9
        jsr rel_seek_end                ; not there: position on the end instead
        bit flag_constants
        rts
rsb_ok                                  ; $D0D0
        lda rel_side_index
        jsr side_set_position
        bit dat_D521
        rts

; Read (indirect_write: write) the block whose address is at (dir_ptr),Y into
; buffer A.
indirect_read                           ; $D0D9
        sta buf_num
        lda #$80                        ; job $80 read
        bne indirect_job
indirect_write                          ; $D0DF
        sta buf_num
        lda #$90                        ; job $90 write
indirect_job                            ; $D0E3
        sta job_code
        lda (dir_ptr),y
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        lda buf_num
        jsr header_set
        ldx buf_num
        jmp job_queue_55

; Out: A = pointer of the side sector buffer.
side_get_position                       ; $D0F8
        ldx channel
        lda chan_side_buf,x
        jmp buffer_get_ptr_a
ssc_add_120                             ; $D100
        lda #$78
        jsr add_to_count

; Add the data blocks addressed by X side sectors plus the current
; one to the count in tmp1/tmp2.
rel_count_blocks                        ; $D105
        dex
        bpl ssc_add_120
        lda tmp3
        lsr
        jsr add_to_count
        lda tmp4

add_to_count                            ; $D110
        clc
        adc tmp1
        sta tmp1
        bcc loc_D119
        inc tmp2
loc_D119
        rts

; Block count of a file with a super side sector, from group rel_ptr,
; side sector tmp4 and index tmp3.
rel_count_super                         ; $D11A
        jsr acc_clear
        jsr factor_clear
        ldy rel_ptr
rcs_groups                              ; $D122
        dey
        bmi loc_D12F
        ldx #$02
        lda #$D6                        ; $2D6 = 726 blocks per group (6 * 121)
        jsr acc_add_ax
        jmp rcs_groups
loc_D12F
        ldy tmp4
rcs_sides                               ; $D131
        dey
        bmi loc_D13E
        ldx #$00
        lda #$79                        ; $79 = 121 blocks per side sector incl. itself
        jsr acc_add_ax
        jmp rcs_sides
loc_D13E
        lda tmp3
        lsr
        ldx #$00
        jmp acc_add_ax

factor_clear                            ; $D146
        ldx #$00
        stx factor24
        stx factor24+1
        stx factor24+2
        rts

; Add A (low) / X (high) to the accumulator.
acc_add_ax                              ; $D14F
        stx factor24+1
        sta factor24
        jmp acc_add_factor

; Test whether the side sector / entry for the wanted record exists.
; Result in N and V (set from the constants at flag_constants).
side_test                               ; $D156
        jsr rel_has_no_super
        bne sst_normal
        lda rel_group
        jsr side_group_select
        beq sst_normal
        bit dat_D522
        rts
sst_normal                              ; $D167
        jsr side_get_number
        cmp rel_side_num
        bne sst_other_side
        ldy rel_side_index
        lda (dir_ptr),y
        beq loc_D178
        bit dat_D521
        rts
loc_D178
        bit dat_D523
        rts
sst_other_side                          ; $D17C
        lda rel_side_num
        cmp #$06
        bcs sst_missing
        asl
        tay
        lda #$04
        sta dir_ptr
        lda (dir_ptr),y
        bne loc_D190
sst_missing                             ; $D18C
        bit dat_D522
        rts
loc_D190
        bit flag_constants
        rts

; Step to the next record of a relative file for reading: load its
; first byte and find the end of its data.
rel_next_record                         ; $D194
        lda #$20                        ; clear 'record full'
        jsr chan_flag_clear
        lda #$80                        ; beyond the end?
        jsr chan_flag_test
        bne rnr_empty
        ldx channel
        inc chan_blocks_lo,x            ; next record number
        bne loc_D1AA
        inc chan_blocks_hi,x
loc_D1AA
        ldx channel
        lda chan_record_ptr,x
        beq rnr_no_record
        jsr buffer_get_ptr
        ldx channel
        cmp chan_record_ptr,x
        bcc loc_D1BE
        jsr rel_next_block              ; record starts in the next block
loc_D1BE
        ldx channel
        lda chan_record_ptr,x
        jsr buffer_set_ptr
        lda (buf_ptrs,x)
        sta bus_data
        lda #$20
        jsr chan_flag_clear
        jsr rel_next_record_ptr

rnr_set                                 ; $D1D2
        pha
        bcc rnr_store
        lda #$00
        jsr buffer_peek
        bne rnr_store
        pla
        cmp #$02
        beq rnr_end_of_block
rnr_no_record                           ; $D1E1
        lda #$80                        ; flag: record not present
        jsr chan_flag_set
rnr_empty                               ; $D1E6
        jsr channel_buf_index
        lda buf_ptrs,x
        sta chan_last_index,y
        lda #$0D                        ; an empty record reads as a carriage return
        sta bus_data
        rts
rnr_end_of_block                        ; $D1F3
        jsr rel_set_next_ptr
        ldx channel
        lda #$00
        sta chan_record_ptr,x
        rts
rnr_store                               ; $D1FE
        pla

; Set the pointer of the following record and find the record's end.
rel_set_next_ptr                        ; $D1FF
        ldx channel
        sta chan_record_ptr,x
        jmp rel_find_record_end

; Move on to the next data block of a relative file, writing the
; current one if it was changed and reading ahead.
rel_next_block                          ; $D207
        jsr channel_read_link
        jsr active_buffer_flags
        bvc loc_D225                    ; buffer modified: write it first
        jsr block_write_next
        jsr buffers_swap
        lda #$02
        jsr buffer_set_ptr
        jsr buffer_job_is_write
        bne rnb_read_ahead
        jsr block_read_next
        jmp job_wait
loc_D225
        jsr buffers_swap
        jsr buffer_job_is_write
        bne rnb_read_ahead
        jsr block_read_next
        jsr job_wait
rnb_read_ahead                          ; $D233
        jsr channel_read_link
        lda track
        beq loc_D243
        jsr buffers_swap
        jsr block_read_next
        jmp buffers_swap
loc_D243
        rts

; Store bus_data in the current record.  Sets the 'record full' flag when
; the record's last byte was written.
rel_put_byte                            ; $D244
        jsr buffer_mark_dirty
        jsr active_buffer
        asl
        tax
        lda bus_data
        sta (buf_ptrs,x)
        ldy buf_ptrs,x
        iny
        bne loc_D25E
        ldy channel
        lda chan_record_ptr,y
        beq rpb_record_full
        ldy #$02
loc_D25E
        tya
        ldy channel
        cmp chan_record_ptr,y
        bne rpb_advance
rpb_record_full                         ; $D266
        lda #$20
        jmp chan_flag_set
rpb_advance                             ; $D26B
        inc buf_ptrs,x
        bne loc_D27A
        lda rel_flags                   ; flag: block boundary crossed
        ora #$10
        sta rel_flags
        jmp rel_next_block
loc_D27A
        rts

; Byte sink of relative files: store the byte; at the end of the
; transfer pad the record and advance.  Writing beyond the end of the
; file extends it.  Overflow of the record gives error 51.
rel_write_byte                          ; $D27B
        lda #$A0                        ; new position pending or beyond the end?
        jsr chan_flag_test
        bne rwb_new_position
rwb_put                                 ; $D282
        lda bus_data
        jsr rel_put_byte
        lda eoi_flag                    ; last byte of the transfer?
        beq rwb_finish
        rts
rwb_end_record                          ; $D28C
        lda #$20
        jsr chan_flag_test
        beq rwb_finish
        lda #$51                        ; error 51 after the record is completed
        sta cmd_error_code
rwb_finish                              ; $D298
        jsr rel_pad_record
        jsr rel_first_byte
        lda cmd_error_code
        beq loc_D2A6
        jmp cmd_error
loc_D2A6
        jmp status_ok
rwb_new_position                        ; $D2A9
        and #$80
        bne rwb_extend
        lda eoi_flag
        beq rwb_end_record
        rts
rwb_extend                              ; $D2B2
        lda bus_data
        pha
        jsr rel_extend                  ; extend the file to this record
        pla
        sta bus_data
        lda #$80
        jsr chan_flag_clear
        jmp rwb_put

; Fill the rest of the record with zero bytes.
rel_pad_record                          ; $D2C3
        lda #$20
        jsr chan_flag_test
        bne loc_D2D4
        lda #$00
        sta bus_data
        jsr rel_put_byte
        jmp rel_pad_record
loc_D2D4
        rts

; Mark the active buffer as modified.
buffer_mark_dirty                       ; $D2D5
        lda #$40
        jsr chan_flag_set
        jsr active_buffer_flags
        ora #$40
        ldx buf_table_index
        sta chan_buf_a,x
        rts

; Mark the active buffer as unmodified.
buffer_mark_clean                       ; $D2E5
        jsr active_buffer_flags
        and #$BF
        ldx buf_table_index
        sta chan_buf_a,x
        rts

; Byte source of relative files: next byte of the current record;
; the last byte is sent with EOI and the next record is prepared.
rel_read_byte                           ; $D2F0
        lda #$80                        ; record not present?
        jsr chan_flag_test
        bne rel_no_record
        jsr channel_buf_index
        lda buf_ptrs,x
        cmp chan_last_index,y           ; last byte of the record?
        beq rel_first_byte
        inc buf_ptrs,x
        bne loc_D313
        lda rel_flags
        ora #$10
        sta rel_flags
        jsr rel_next_block
rrb_load                                ; $D310
        jsr channel_buf_index
loc_D313
        lda (buf_ptrs,x)
rrb_store                               ; $D315
        sta chan_data,y
        lda #$89                        ; status: more to come
        sta chan_status,y
        lda buf_ptrs,x
        cmp chan_last_index,y
        beq rrb_last
        rts
rrb_last                                ; $D325
        lda #$81                        ; status: last byte
        sta chan_status,y
        rts

rel_first_byte                          ; $D32B
        jsr rel_next_record
        jsr channel_buf_index
        lda bus_data
        jmp rrb_store

; Record does not exist: answer with a carriage return and error 50.
rel_no_record                           ; $D336
        ldx channel
        lda #$0D
        sta chan_data,x
        lda #$81
        sta chan_status,x
        lda #$50                        ; error 50 RECORD NOT PRESENT
        jsr cmd_error

; Find the last non-zero byte of the current record (it may span two
; blocks) and store its index as the end of data.
rel_find_record_end                     ; $D347
        ldx channel
        lda chan_record_ptr,x
        sta rel_end_index
        dec rel_end_index
        cmp #$02
        bne loc_D358
        lda #$FF                        ; record ends in the previous block
        sta rel_end_index
loc_D358
        lda chan_record_len,x
        sta rel_work
        jsr buffer_get_ptr
        ldx channel
        cmp rel_end_index
        bcc rfe_this_block
        beq rfe_this_block
        jsr buffers_swap
        jsr rel_scan_back
        bcc loc_D378
        ldx channel
        sta chan_last_index,x
        jmp buffers_swap
loc_D378
        jsr buffers_swap
        lda #$FF
        sta rel_end_index
rfe_this_block                          ; $D37F
        jsr rel_scan_back
        bcs rfe_store
        jsr buffer_get_ptr
rfe_store                               ; $D387
        ldx channel
        sta chan_last_index,x
        rts

; Scan backwards from index rel_end_index for a non-zero byte.
; Out: carry set and A = index if found.
rel_scan_back                           ; $D38D
        jsr buffer_start_ptr
        ldy rel_end_index
rsk_loop                                ; $D392
        lda (dir_ptr),y
        bne loc_D3A3
        dey
        cpy #$02
        bcc loc_D39F
        dec rel_work
        bne rsk_loop
loc_D39F
        dec rel_work
        clc
        rts
loc_D3A3
        tya
        sec
        rts

; Position the side sector pointers on the last data block of the
; file.  Error 67 if the side sector chain is damaged.
rel_seek_end                            ; $D3A6
        jsr rel_has_no_super
        bne loc_D3AE
        jsr super_find_last_group
loc_D3AE
        jsr side_get_number
        sta rel_side_num
        lda #$04
        sta dir_ptr
        ldy #$0A                        ; search the side sector table from the end
        bne rse_find
rse_prev                                ; $D3BB
        dey
        dey
        bmi error_67_rel
rse_find                                ; $D3BF
        lda (dir_ptr),y
        beq rse_prev
        tya
        lsr
        cmp rel_side_num
        beq rse_last_entry
        sta rel_side_num
        ldx channel
        lda chan_side_buf,x
        jsr indirect_read
rse_last_entry                          ; $D3D3
        ldy #$00
        sty dir_ptr
        lda (dir_ptr),y
        bne error_67_rel
        iny
        lda (dir_ptr),y
        tay
        dey
        sty rel_side_index
        tya
        jmp side_set_position
error_67_rel                            ; $D3E6
        lda #$67                        ; error 67
        jsr jt_dos_error

; ==========================================================================
; P - position a relative file: 'P' channel, record low, record high,
; byte position.  Error 50 when the record does not exist yet (which is
; how a program extends the file), 51 when the position is too large.
; ==========================================================================
cmd_position                            ; $D3EB
        jsr cmd_trim
        lda cmd_buf+1                   ; channel
        sta sec_addr
        jsr channel_find_read
        bcc pos_channel_ok
        lda #$70                        ; error 70 NO CHANNEL
        jsr cmd_error
pos_channel_ok                          ; $D3FD
        lda #$A0
        jsr chan_flag_clear
        jsr channel_file_type
        beq pos_set
        lda #$64                        ; error 64: not a relative file
        jsr cmd_error
pos_set                                 ; $D40C
        lda cmd_buf+2                   ; record number
        sta chan_blocks_lo,x
        lda cmd_buf+3
        sta chan_blocks_hi,x
        ldx channel
        lda #$89
        sta chan_status,x
        lda cmd_buf+4                   ; position inside the record, 1 based
        beq pos_seek
        sec
        sbc #$01
        beq pos_seek
        cmp chan_record_len,x
        bcc pos_seek
        lda #$51                        ; error 51: beyond the record length
        sta cmd_error_code
        lda #$00
pos_seek                                ; $D435
        sta rel_byte_pos
        jsr rel_locate_record
        jsr rel_seek_block
        bvc pos_found
        lda #$80                        ; flag: record not present
        jsr chan_flag_set
        jmp rel_no_record
pos_found                               ; $D447
        jsr rel_load_record
        lda #$80
        jsr chan_flag_test
        beq loc_D454
        jmp rel_no_record
loc_D454
        jmp cmd_done

; Load the data block of the wanted record and set up reading at the
; requested position.
rel_load_record                         ; $D457
        jsr rel_read_block
        lda rel_block_offset
        jsr buffer_set_ptr
        ldx channel
        lda chan_record_len,x
        sec
        sbc rel_byte_pos
        bcs rlr_end
        jmp error_67_rel
rlr_end                                 ; $D46C
        clc
        adc rel_block_offset
        bcc loc_D474
        adc #$01
        sec
loc_D474
        jsr rnr_set
        jmp rrb_load

; Unreferenced: error 51 OVERFLOW IN RECORD.
dead_error_51                           ; $D47A
        lda #$51
        jsr cmd_error

; Make sure the data block named by the side sector entry is in one of
; the channel's two buffers.
rel_read_block                          ; $D47F
        lda dir_ptr
        sta rel_ptr
        lda dir_ptr+1
        sta $89
        jsr rel_block_cached
        beq loc_D4AE
        jsr buffer_flush_if_dirty
        jsr block_get_link
        lda track
        beq rrb_fetch
        jsr buffers_swap
        jsr rel_block_cached
        bne rrb_fetch
        jsr block_get_link
        lda track
        beq loc_D4AE
        jsr buffers_swap
        jsr block_read_next
        jmp buffers_swap
loc_D4AE
        rts
rrb_fetch                               ; $D4AF
        ldy #$00
        lda (rel_ptr),y
        sta track
        iny
        lda (rel_ptr),y
        sta sector
        jmp channel_read_ahead

; Out: Z set when the active buffer already holds the wanted block.
rel_block_cached                        ; $D4BD
        jsr header_get_active
        ldy #$00
        lda (rel_ptr),y
        cmp track
        beq loc_D4C9
        rts
loc_D4C9
        iny
        lda (rel_ptr),y
        cmp sector
        bne loc_D4E1
        lda rel_flags
        and #$10
        beq loc_D4E1
        lda rel_flags
        and #$EF
        sta rel_flags
        eor #$10
loc_D4E1
        rts

; Initialise a data block with empty records: every record starts
; with $FF followed by zeros.
rel_init_block                          ; $D4E2
        jsr buffer_start_ptr
        ldy #$02
        lda #$00
loc_D4E9
        sta (dir_ptr),y
        iny
        bne loc_D4E9
        jsr rel_next_record_ptr
rib_mark                                ; $D4F1
        sta chan_record_ptr,x
        tay
        lda #$FF                        ; $FF marks an empty record
        sta (dir_ptr),y
        jsr rel_next_record_ptr
        bcc rib_mark
        bne loc_D505
        lda #$00
        sta chan_record_ptr,x
loc_D505
        rts

; Out: A = buffer index of the record after the current one, carry
; set when it lies in the next block.
rel_next_record_ptr                     ; $D506
        ldx channel
        lda chan_record_ptr,x
        sec
        beq rnp_wrap
        clc
        adc chan_record_len,x
        bcc loc_D51F
        bne rnp_wrap
        lda #$02
        bit dat_D524
        rts
rnp_wrap                                ; $D51C
        adc #$01
        sec
loc_D51F
        rts

; Constants tested with BIT to return flag combinations.
flag_constants                          ; $D520
        !byte $7F                       ; $D520
dat_D521
        !byte $3F                       ; $D521
dat_D522
        !byte $FF                       ; $D522
dat_D523
        !byte $BF                       ; $D523
dat_D524
        !byte $00                       ; $D524

; Extend a relative file up to the wanted record: add data blocks
; (and side sectors) one by one, each filled with empty records.
; Error 52 FILE TOO LONG when the partition has not enough free blocks.
rel_extend                              ; $D525
        jsr rel_end_position
        jsr rel_locate_record
rel_extend_to                           ; $D52B
        jsr blocks_free_get             ; free blocks on the partition
        ldy channel
        ldx chan_record_len,y
        dex
        txa
        clc
        adc rel_block_offset
        bcc loc_D546
        inc rel_side_index
        inc rel_side_index
        bne loc_D546
        inc rel_side_num
        lda #$10
        sta rel_side_index
loc_D546
        lda rel_end_index
        clc
        adc #$02
        jsr side_set_position
        lda rel_side_num
        cmp #$06
        bcc rex_count
        jsr rel_has_no_super
        bne error_52
        sta rel_side_num
        inc rel_group
        bne rex_count
error_52                                ; $D560
        lda #$52                        ; error 52 FILE TOO LONG
        jsr cmd_error
rex_count                               ; $D565
        lda rel_side_index
        sec
        sbc rel_end_index
        bcs loc_D56F
        sbc #$0F
        clc
loc_D56F
        pha
        jsr rel_has_no_super
        beq loc_D593
        pla
        sta tmp3
        lda rel_side_num
        sbc work_count
        sta tmp4
        ldx #$00
        stx tmp1
        stx tmp2
        tax
        jsr rel_count_blocks
        lda tmp2
        bne loc_D5BB
        ldx tmp1
        dex
        bne loc_D5BB
        beq loc_D5B9
loc_D593
        pla
        sta tmp3
        lda rel_side_num
        sbc work_count
        bcs loc_D5A0
        inc rel_ptr
        adc #$06
loc_D5A0
        sta tmp4
        lda rel_group
        sec
        sbc rel_ptr
        sta rel_ptr
        jsr rel_count_super
        lda acc24+1
        bne loc_D5BB
        ldx acc24
        bne loc_D5B6
        rts
loc_D5B6
        dex
        bne loc_D5BB
loc_D5B9
        inc rel_work
loc_D5BB
        cmp line_number_hi              ; enough free blocks?
        bcc rex_add
        bne error_52
        lda line_number_lo
        cmp tmp1
        bcc error_52
rex_add                                 ; $D5C9
        lda #$01
        jsr buffer_peek
        clc
        adc #$01
        ldx channel
        sta chan_record_ptr,x
        jsr alloc_next_block            ; allocate the next data block
        jsr block_set_link
        lda rel_work
        bne rex_last_block
        jsr block_write_next            ; write the current block
rex_next_block                          ; $D5E3
        jsr buffers_swap
        jsr header_set_active
        jsr alloc_next_block
        jsr block_set_link
        jsr rel_init_block              ; fill the new block with empty records
        jmp rex_link
rex_last_block                          ; $D5F5
        jsr buffers_swap
        jsr header_set_active
        jsr rel_init_block
        jsr block_set_last
rex_link                                ; $D601
        jsr block_write_next
        jsr block_get_link
        lda track
        pha
        lda sector
        pha
        jsr header_get_active
        lda sector
        pha
        lda track
        pha
        jsr side_get_position
        tax
        bne loc_D626
        jsr rel_new_side_sector         ; side sector full: add one
        lda #$10
        jsr side_set_position
        inc work_count
loc_D626
        pla                             ; enter the block in the side sector
        jsr side_put_byte
        pla
        jsr side_put_byte
        pla
        sta sector
        pla
        sta track
        beq rex_done
        jsr rel_has_no_super
        bne loc_D642
        lda rel_end_group
        cmp rel_group
        bcc rex_next_block
loc_D642
        lda work_count
        cmp rel_side_num
        bne rex_next_block
        jsr side_get_position
        cmp rel_side_index
        bcc rex_next_block
        beq rex_last_block
rex_done                                ; $D651
        jsr side_get_position
        pha
        lda #$00
        jsr side_set_ptr
        lda #$00
        tay
        sta (dir_ptr),y
        iny
        pla
        sec
        sbc #$01
        sta (dir_ptr),y
        jsr side_write                  ; write the side sector
        jsr job_wait
        jsr bam_flush                   ; write the BAM
        jsr rel_locate_record
        jsr buffers_swap
        jsr rel_seek_block
        bvs rex_not_present
        jmp rel_load_record
rex_not_present                         ; $D67D
        lda #$80
        jsr chan_flag_set
        lda #$50                        ; error 50
        jsr cmd_error

; Note the current end position of the file in work_count-rel_end_group.
rel_end_position                        ; $D687
        jsr rel_seek_end
        jsr rel_read_block
        jsr rel_has_no_super
        bne loc_D699
        lda rel_group
        sta rel_end_group
        sta rel_ptr
loc_D699
        lda rel_side_index
        sta rel_end_index
        lda rel_side_num
        sta work_count
        lda #$00
        sta rel_work
        sta rel_byte_pos
        rts

; Add a side sector: allocate it, enter it in all side sectors of the
; group (or start a new group in the super side sector).
rel_new_side_sector                     ; $D6A8
        jsr alloc_next_block
        jsr buffers_swap
        jsr buffer_flush_if_dirty
        jsr active_buffer
        pha
        jsr buffer_clear
        ldx channel
        lda chan_side_buf,x
        tay
        pla
        tax
        jsr rel_has_no_super
        bne rns_chain
        jmp rns_new_group
rns_chain                               ; $D6C8
        lda #$10                        ; copy the 16 header bytes to the new side sector
        jsr buffer_copy
        lda #$00
        jsr side_set_ptr
        ldy #$02
        lda (dir_ptr),y
        pha
        lda #$00
        jsr buffer_set_ptr
        pla                             ; next side sector number
        clc
        adc #$01
        sta (dir_ptr),y
        asl
        adc #$04
        sta rel_ptr
        tay
        sec
        sbc #$02
        sta $89
rns_fill                                ; $D6ED
        lda track
        sta rel_end_index
        sta (dir_ptr),y
        iny
        lda sector
        sta rel_work
        sta (dir_ptr),y
        ldy #$00
        tya
        sta (dir_ptr),y
        iny
        lda #$11                        ; $11: only the header is used so far (?)
        sta (dir_ptr),y
        lda #$10
        jsr buffer_set_ptr
        jsr block_write_flush           ; write the new side sector
        jsr job_wait
        ldx channel
        lda chan_side_buf,x
        pha
        jsr active_buffer_flags
        ldx channel
        sta chan_side_buf,x
        pla
        ldx buf_table_index
        sta chan_buf_a,x
        lda #$00
        jsr buffer_set_ptr
        ldy #$00
        lda track
        sta (dir_ptr),y
        iny
        lda sector
        sta (dir_ptr),y
        jsr rel_has_no_super
        bne rns_update
        lda work_count
        cmp #$FF
        bne rns_update
        lda sector
        pha
        lda track
        pha
        jsr block_write_next
        jsr job_wait
        jsr buffers_swap
        jsr super_read
        inc rel_end_group
        lda rel_end_group
        asl
        clc
        adc #$03
        jsr side_set_position
        pla
        jsr side_put_byte
        pla
        jsr side_put_byte
        jsr super_write
        lda rel_end_group
        pha
        jmp sgs_load
rns_update_prev                         ; $D76C
        jsr active_buffer
        ldx channel
        jsr indirect_read
        lda #$00
        jsr buffer_set_ptr
rns_update                              ; $D779
        dec $89
        dec $89
        ldy rel_ptr
        lda rel_end_index
        sta (dir_ptr),y
        iny
        lda rel_work
        sta (dir_ptr),y
        jsr block_write_next            ; update the earlier side sectors of the group
        jsr job_wait
        ldy $89
        cpy #$03
        bcs rns_update_prev
        jmp buffers_swap
rns_new_group                           ; $D797
        lda work_count
        cmp #$05                        ; sixth side sector of a group: start a new group
        bcs loc_D7A0
        jmp rns_chain
loc_D7A0
        lda #$FF
        sta work_count
        lda #$00
        jsr buffer_set_ptr
        ldy #$02
        sta (dir_ptr),y
        ldx channel
        lda chan_record_len,x
        iny
        sta (dir_ptr),y
        iny
        beq loc_D7BB
        jmp rns_fill
loc_D7BB
        jmp rns_chain

; Out: Z set when the REL file of the current channel uses a super
; side sector.
rel_has_no_super                        ; $D7BE
        stx $2BF8
        ldx channel
        lda chan_rel_flags,x
        ldx $2BF8
        and #$20                        ; bit 5 set = no super side sector
        rts

; Make sure the super side sector is the block in the side buffer.
super_ensure_loaded                     ; $D7CC
        ldx channel
        lda #$FE                        ; $FE = super side sector is loaded
        cmp chan_side_group,x
        bne super_read
        rts

; Read (super_write: write) the super side sector.
super_read                              ; $D7D6
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write the super side sector.
super_write                             ; $D7D9
        lda #$90
        pha
        ldx channel
        lda chan_super_track,x          ; its track / sector
        sta track
        lda chan_super_sector,x
        sta sector
        lda #$FF                        ; side buffer is in transit
        sta chan_side_group,x
        lda chan_side_buf,x
        sta buf_num
        jsr header_set
        pla
        jsr job_for_buf_num
        ldx channel
        lda #$FE
        sta chan_side_group,x
        rts

; Find the last used side sector group, searching the super side
; sector downwards from group 90.
super_find_last_group                   ; $D801
        lda #$5A                        ; start with group 90
        sta rel_group
        jsr side_group_select
        bne sflg_loop
        rts
sflg_loop                               ; $D80C
        dec rel_group
        lda rel_group
        jsr side_group_load
        bne sflg_loop
        rts

; Make side sector group A current.  Out: Z set on success.
side_group_select                       ; $D818
        ldx channel
        cmp chan_side_group,x
        bne loc_D820
        rts
loc_D820
        pha
        jsr super_ensure_loaded
sgs_load                                ; $D824
        lda #$03
        jsr side_set_ptr
        pla

; Load the first side sector of group A through the super side
; sector.  Out: A = 0, or $FF when the group does not exist.
side_group_load                         ; $D82A
        tax
        asl
        tay
        lda (dir_ptr),y                 ; group table of the super side sector
        bne sgl_read
        ora #$FF
        rts
sgl_read                                ; $D834
        sta track
        iny
        lda (dir_ptr),y
        sta sector
        txa
        pha
        lda #$FF
        ldx channel
        sta chan_side_group,x
        lda chan_side_buf,x
        sta buf_num
        jsr header_set
        lda #$80
        jsr job_for_buf_num
        ldx channel
        pla
        sta chan_side_group,x
        lda #$00
        rts

; Read the block in the header of the active buffer and return its
; link in track/sector.
channel_read_first                      ; $D85A
        jsr header_set_active
        jsr channel_block_read
        jsr job_wait
        jsr buffer_get_byte
        sta track
        jsr buffer_get_byte
        sta sector
        rts

; Read the wanted block, then read its successor into the second
; buffer (read ahead).
channel_read_ahead                      ; $D86E
        jsr channel_read_first
        lda track
        bne cra_second
        rts
cra_second                              ; $D876
        jsr buffers_swap
        jsr header_set_active
        jsr channel_block_read
        jmp buffers_swap

; Queue a read (channel_block_write: write) of the active buffer's block; a data
; block of a sequential file is counted.
channel_block_read                      ; $D882
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write the active buffer.
channel_block_write                     ; $D885
        lda #$90
        sta job_code
        jsr active_buffer
        tax
        jsr job_checked
        txa
        pha
        asl
        tax
        lda #$00
        sta buf_ptrs,x
        jsr channel_file_type
        cmp #$04                        ; REL blocks are not counted here
        bcs cbx_done
        inc chan_blocks_lo,x
        bne cbx_done
        inc chan_blocks_hi,x
cbx_done                                ; $D8A7
        pla
        tax
        rts

; Read (buffer_block_write: write) block track/sector with buffer buf_num.
buffer_block_read                       ; $D8AA
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Write block track/sector from buffer buf_num.
buffer_block_write                      ; $D8AD
        lda #$90
        sta job_code
        lda buf_num
        jsr header_set
        ldx buf_num
        jmp job_queue_55

; Queue job job_code for buffer X after checking its header against the
; partition geometry: error 66 for an illegal block, and for writes
; error 73 when the partition's DOS version byte is foreign.
job_checked                             ; $D8BB
        lda job_code

; As job_checked with the job code in A.
job_checked_a                           ; $D8BD
        pha
        stx buf_num
        bit job_no_check                ; bit 6 of job_no_check: skip the checks
        bvc jck_check
        jmp jck_queue
jck_check                               ; $D8C8
        txa
        asl
        tax
        lda job_sector,x
        sta job_code
        lda job_track,x                 ; track 0 is never legal
        beq jck_illegal
        tax
        jsr track_limits
        lda buf_num
        asl
        tax
        lda last_track_plus1            ; above the last track?
        beq jck_write
        cmp job_track,x
        beq jck_illegal
        bcc jck_illegal
jck_write                               ; $D8E9
        pla
        pha
        cmp #$90                        ; only writes are checked further
        bne jck_queue
        jsr bam_ensure_loaded
        lda bam_dos_version,x
        jsr dos_version_check           ; DOS version byte acceptable?
        bne error_73_version
        lda sectors_per_track
        beq jck_queue
        cmp job_code                    ; sector within the track?
        beq jck_illegal
        bcs jck_queue
jck_illegal                             ; $D905
        jsr job_header_to_ts
error_66                                ; $D908
        lda #$66                        ; error 66 ILLEGAL BLOCK
        jmp jt_dos_error

; Copy the header of buffer buf_num to track/sector.
job_header_to_ts                        ; $D90D
        lda buf_num
        asl
        tax
        lda job_track,x
        sta track
        lda job_sector,x
        sta sector
        rts

; Check track/sector against the geometry of the current partition.
; Error 66 ILLEGAL BLOCK if it is out of range.  X is preserved.
check_track_sector                      ; $D91C
        txa
        pha
        ldx track
        jsr track_limits
        lda track
        beq error_66
        lda last_track_plus1
        beq cts_low
        cmp track
        beq error_66
        bcc error_66
cts_low                                 ; $D932
        lda track
        cmp first_track
        bcc error_66
        lda sectors_per_track
        beq cts_ok
        cmp sector
        beq error_66
        bcc error_66
cts_ok                                  ; $D944
        pla
        tax
        rts
error_73_version                        ; $D947
        jsr job_header_to_ts
        lda #$73                        ; error 73
        jmp jt_dos_error
jck_queue                               ; $D94F
        ldx buf_num
        pla
        sta job_code
        jmp jt_do_job

; Unreferenced entries: A = $80 read / $90 write for buffer buf_num.
dead_job_read                           ; $D957
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Unreferenced: write variant.
dead_job_write                          ; $D95A
        lda #$90

; Queue job A for buffer buf_num.
job_for_buf_num                         ; $D95C
        ldx buf_num
        sta job_code
job_queue_55                            ; $D960
        lda job_code
        jsr job_checked_a

; Run the job stored in slot X and wait for it; errors do not return.
job_wait                                ; $D965
        lda job_queue,x
        jsr jt_do_job
        clc
        pha
        lda #$00                        ; re-enable the geometry check
        sta job_no_check
        pla
        rts

; Store track/sector as the header of the active buffer (header_set: of
; buffer A).  Out: A = X = 0.
header_set_active                       ; $D973
        jsr active_buffer

; Store track/sector as the header of buffer A.
header_set                              ; $D976
        asl
        tay
        lda track
        sta job_track,y
        lda sector
        sta job_sector,y
        lda #$00
        tax
        rts

; Find the read channel of sec_addr, then header_get_active.
header_get_for_sa                       ; $D986
        jsr channel_find_read

; Out: track/sector = header of the active buffer, buf_num = its number.
header_get_active                       ; $D989
        jsr active_buffer
        sta buf_num
        asl
        tay
        lda job_track,y
        sta track
        lda job_sector,y
        sta sector
        rts

; Write the active buffer (header already set).
block_write_flush                       ; $D99B
        lda #$90
        sta job_code
        bne blk_set_header

; Read (block_write_next: write) the block track/sector with the active buffer.
block_read_next                         ; $D9A1
        lda #$80
        sta job_code
        bne blk_set_header

; Write block track/sector from the active buffer and clear its dirty
; flag.
block_write_next                        ; $D9A7
        lda #$90
        sta job_code
        bne blk_clear_dirty
block_read_keep                         ; $D9AD
        lda #$80
        sta job_code
        bne blk_clear_dirty

; Write (side_read: read) the side sector buffer of the channel.
side_write                              ; $D9B3
        lda #$90
        sta job_code
        bne side_job

; Read the side sector buffer.
side_read                               ; $D9B9
        lda #$80
side_job                                ; $D9BB
        sta job_code
        ldx channel
        lda chan_side_buf,x
        tax
        bpl blk_queue
blk_set_header                          ; $D9C5
        jsr header_set_active
        jsr active_buffer
        tax
        lda #$00
        sta job_code_saved,x            ; forget the previous job of this buffer
blk_clear_dirty                         ; $D9D1
        jsr buffer_mark_clean
        jsr active_buffer
        tax
blk_queue                               ; $D9D8
        jmp job_checked

; Out: track/sector = link bytes at the start of the active buffer.
channel_read_link                       ; $D9DB
        lda #$00
        jsr buffer_set_ptr
        jsr buffer_get_byte
        sta track
        jsr buffer_get_byte
        sta sector
        rts

; Set (chan_flag_clear: clear) the bits A in the channel's flag byte chan_file_type.
chan_flag_set                           ; $D9EB
        ldx channel
        ora chan_file_type,x
        bne chan_flag_store

; Clear the bits A in the channel's flag byte.
chan_flag_clear                         ; $D9F2
        ldx channel
        eor #$FF
        and chan_file_type,x
chan_flag_store                         ; $D9F9
        sta chan_file_type,x
        rts

; Out: A = flag byte of the channel AND A.
chan_flag_test                          ; $D9FD
        ldx channel
        and chan_file_type,x
        rts

; Out: Z set when the last job of the active buffer was a write.
buffer_job_is_write                     ; $DA03
        jsr active_buffer
        tax
        lda job_code_saved,x
        and #$FE
        cmp #$90
        rts

; Is the file of the current directory entry open on any channel?
; Out: carry clear when it is.
file_is_open                            ; $DA0F
        ldx #$00
fio_loop                                ; $DA11
        stx tmp2
        lda sa_channel,x                ; every secondary address 0-15
        cmp #$FF
        bne fio_compare
fio_next                                ; $DA1A
        ldx tmp2
        inx
        cpx #$10
        bcc fio_loop
        rts
fio_compare                             ; $DA22
        stx tmp2
        and #$3F
        tay
        ldx match_index
        lda chan_file_type,y            ; same entry and partition?
        cmp file_type_flags,x
        bne fio_next
        lda chan_partition,y
        cmp file_partition,x
        bne fio_next
        lda chan_dir_track,y
        cmp file_dir_track,x
        bne fio_next
        lda chan_dir_sector,y
        cmp file_dir_sector,x
        bne fio_next
        lda chan_dir_offset,y
        cmp file_dir_index,x
        bne fio_next
        clc
        rts

; Write the active buffer if it is marked dirty.
buffer_flush_if_dirty                   ; $DA54
        jsr active_buffer_flags
        bvc bfd_rts
        jsr block_write_next
        jsr job_wait
bfd_rts                                 ; $DA5F
        rts

; Find the channel of secondary address sec_addr for reading and make it
; (and its partition) current.  Out: carry set when it is not open.
channel_find_read                       ; $DA60
        lda sec_addr
        cmp #$13                        ; internal channels 17/18 are used as they are
        bcc cfr_cmd
        and #$0F
cfr_cmd                                 ; $DA68
        cmp #$0F
        bne cfr_lookup
        lda #$10                        ; 15 -> error channel slot 16 for reading
cfr_lookup                              ; $DA6E
        tax
        sec
        lda sa_channel,x
        bmi csl_rts

; Make channel A current and select the partition its file is on.
channel_select                          ; $DA75
        and #$3F
        sta channel
        tax
        cmp #$1F                        ; command and error channel: default partition
        beq csl_cmd_part
        cmp #$1E
        bne csl_file_part
csl_cmd_part                            ; $DA82
        lda cmd_partition
        jmp csl_set_part
csl_file_part                           ; $DA88
        lda chan_partition,x
csl_set_part                            ; $DA8B
        jsr partition_select
        lda channel
        clc
csl_rts                                 ; $DA91
        rts

; As channel_find_read for writing.  Out: carry set when it is not open for
; writing.
channel_find_write                      ; $DA92
        lda sec_addr
        cmp #$13
        bcc loc_DA9A
        and #$0F
loc_DA9A
        tax
        lda sa_channel,x
        tay
        asl                             ; bit 7 = write, bit 6 = direct/REL: both directions
        bcc loc_DAA8
        bmi cfw_fail
cfw_ok                                  ; $DAA4
        tya
        jmp channel_select
loc_DAA8
        bmi cfw_ok
cfw_fail                                ; $DAAA
        sec
        rts

; Out: A = file type of the current channel (compared with 4 = REL).
channel_file_type                       ; $DAAC
        ldx channel
        lda chan_file_type,x
        lsr
        and #$07
        cmp #$04
        rts

; Out: X = 2 * active buffer number, Y = channel.
channel_buf_index                       ; $DAB7
        jsr active_buffer
        asl
        tax
        ldy channel
        rts

; Allocate a channel for writing with A buffers (channel_alloc_read: for
; reading).  Error 70 when no channel or buffer is free.
channel_alloc_write                     ; $DABF
        sec
        bcs channel_alloc

; Allocate a channel for reading with A buffers.
channel_alloc_read                      ; $DAC2
        clc
channel_alloc                           ; $DAC3
        php
        sta tmp0
        jsr channel_free
        jsr channel_find_unused
        lda cur_partition               ; file belongs to the current partition
        sta chan_partition,x
        txa
        ldx sec_addr
        plp
        bcc loc_DADA
        ora #$80
loc_DADA
        sta sa_channel,x
        and #$3F
        tay
        jsr channel_clear_bufs
        dec tmp0
        bmi cal_rts
        jsr buffer_alloc
        bpl cal_second_buf
error_70_free                           ; $DAEC
        jsr channel_clear_bufs
        lda #$70                        ; error 70 NO CHANNEL
        jmp cmd_error
cal_second_buf                          ; $DAF4
        sta chan_buf_a,y
        dec tmp0
        bmi cal_rts
        jsr buffer_alloc
        bmi error_70_free
        sta chan_buf_b,y
cal_rts                                 ; $DB03
        rts

; Free the channel of secondary address sec_addr and its buffers.  The
; command channel is never freed.
channel_free                            ; $DB04
        lda sec_addr
        cmp #$0F                        ; never free the command channel
        bne chf_do
chf_rts                                 ; $DB0A
        rts
chf_do                                  ; $DB0B
        tax
        lda sa_channel,x
        cmp #$FF
        beq chf_rts
        and #$3F
        sta channel
        lda #$FF
        sta sa_channel,x
        ldx channel
        lda #$00
        sta chan_status,x
        jmp channel_clear_bufs

; Free every channel (0-14) that belongs to the current partition.
channels_free_partition                 ; $DB26
        lda #$0E
        sta sec_addr
cfp_loop                                ; $DB2A
        ldx sec_addr
        lda sa_channel,x
        cmp #$FF
        beq cfp_next
        and #$3F
        sta channel
        tax
        lda chan_partition,x
        cmp cur_partition
        bne cfp_next
        jsr channel_free
cfp_next                                ; $DB43
        dec sec_addr
        bpl cfp_loop
        rts

; Out: A = X = channel = lowest channel index not in use.  Error 70 when
; all 32 are taken.
channel_find_unused                     ; $DB48
        lda #$00
        sta channel
cfu_scan                                ; $DB4C
        ldx #$12
loc_DB4E
        lda sa_channel,x
        and #$3F
        cmp channel
        beq cfu_taken
        dex
        bpl loc_DB4E
        lda channel
        tax
        rts
cfu_taken                               ; $DB5E
        inc channel
        lda channel
        cmp #$20
        bcc cfu_scan
        lda #$70                        ; error 70
        jmp cmd_error

; Free the internal channels 17 and 18.
internal_channels_free                  ; $DB6B
        lda #$11
        sta sec_addr
        jsr channel_free
        lda #$12
        sta sec_addr
        jmp channel_free

; Double buffering: swap the roles of the channel's two buffers.
; The first call allocates the second buffer and reads ahead.
buffers_swap                            ; $DB79
        ldx channel
        lda chan_buf_a,x
        bmi loc_DB83
        lda chan_buf_b,x
loc_DB83
        cmp #$FF                        ; second buffer already there?
        beq bsw_get_second
        lda chan_buf_a,x
        eor #$80
        sta chan_buf_a,x
        pha
        lda chan_buf_b,x
        eor #$80
        sta chan_buf_b,x
        tay
        pla
        bpl loc_DB9D
        tya
loc_DB9D
        and #$BF
        tax
        jmp job_wait
bsw_get_second                          ; $DBA3
        lda chan_buf_a,x
        bpl loc_DBAB
        lda chan_buf_b,x
loc_DBAB
        and #$BF
        tay
        jsr buffer_alloc                ; no: allocate it
        bpl bsw_store
        lda #$70
        jmp cmd_error
bsw_store                               ; $DBB8
        ldx channel
        ora #$80
        ldy chan_buf_a,x
        bpl loc_DBC6
        sta chan_buf_a,x
        bmi bsw_read_ahead
loc_DBC6
        sta chan_buf_b,x
bsw_read_ahead                          ; $DBC9
        lda track
        pha
        lda sector
        pha
        lda #$01
        sta tmp2
        lda chan_buf_a,x
        bpl loc_DBDB
        lda chan_buf_b,x
loc_DBDB
        and #$BF
        tay
        clc
        adc #$03
        sta tmp3
        ldy #$00
        lda (tmp2),y                    ; link sector of the current block
        sta sector
        lda #$00
        sta tmp2
        lda chan_buf_a,x
        bpl loc_DBF5
        lda chan_buf_b,x
loc_DBF5
        and #$BF
        tay
        clc
        adc #$03
        sta tmp3
        ldy #$00
        lda (tmp2),y                    ; link track, 0 = last block
        sta track
        beq bsw_last
        jsr channel_file_type
        beq bsw_swap_read
        jsr buffer_job_is_write
        bne bsw_swap_read
        jsr buffers_toggle
        jmp bsw_restore
bsw_swap_read                           ; $DC15
        ldx channel
        lda chan_buf_a,x
        eor #$80
        sta chan_buf_a,x
        lda chan_buf_b,x
        eor #$80
        sta chan_buf_b,x
        jsr block_read_next             ; read the next block ahead
bsw_restore                             ; $DC2A
        pla
        sta sector
        pla
        sta track
        jmp bsw_wait
bsw_last                                ; $DC33
        pla
        sta sector
        pla
        sta track
        jsr buffers_toggle
bsw_wait                                ; $DC3C
        jsr active_buffer
        tax
        jmp job_wait

; Unreferenced: error 70.
dead_error_70                           ; $DC43
        lda #$70
        jmp cmd_error

; Toggle the active/inactive marks of the two buffers.
buffers_toggle                          ; $DC48
        ldx channel
        lda chan_buf_a,x
        eor #$80
        sta chan_buf_a,x
        lda chan_buf_b,x
        eor #$80
        sta chan_buf_b,x
        rts

; Add A to the pointer of the active buffer.
buffer_ptr_add                          ; $DC5B
        sta tmp0
        jsr buffer_get_ptr
        clc
        adc tmp0
        sta buf_ptrs,x
        sta dir_ptr
        rts

; Mark the channel as owning no buffers.
channel_clear_bufs                      ; $DC68
        ldx channel
        lda #$FF
        sta chan_buf_a,x
        sta chan_buf_b,x
        sta chan_side_buf,x
        rts

; Allocate a free buffer.  Out: A = X = buffer number (N set if
; none); its job slot is cleared and its pointer set to 2.  Y kept.
buffer_alloc                            ; $DC76
        tya
        pha
        jsr buffer_find_free
        bmi bal_done
bal_wait                                ; $DC7D
        lda job_queue,x                 ; wait for a pending job of that buffer
        bmi bal_wait
        lda #$00
        sta job_queue,x
        sta job_code_saved,x
        txa
        asl
        tay
        lda #$02                        ; pointer behind the link bytes
        sta buf_ptrs,y
bal_done                                ; $DC90
        pla
        tay
        txa
        rts

; Out: X = buf_wanted = highest free buffer number, negative if none.
buffer_find_free                        ; $DC94
        lda #$1E                        ; buffers $1D down to 0
        sta buf_wanted
bff_loop                                ; $DC98
        dec buf_wanted
        bmi bff_done
        jsr buffer_in_use
        beq bff_loop
bff_done                                ; $DCA1
        lda buf_wanted
        tax
        rts

; Out: Z set when buffer buf_wanted is used by some channel.
buffer_in_use                           ; $DCA5
        ldx #$1F
biu_loop                                ; $DCA7
        lda chan_buf_a,x
        and #$1F
        cmp buf_wanted
        beq biu_rts
        lda chan_buf_b,x
        and #$1F
        cmp buf_wanted
        beq biu_rts
        lda chan_side_buf,x
        and #$1F
        cmp buf_wanted
        beq biu_rts
        dex
        bpl biu_loop
biu_rts                                 ; $DCC5
        rts

; Set the pointer of the active buffer to A (also in dir_ptr/dir_ptr+1).
buffer_set_ptr                          ; $DCC6
        sta tmp0
        jsr active_buffer
        asl
        tax
        lda tmp0
        sta buf_ptrs,x
        jmp bgp_load

; Out: dir_ptr/dir_ptr+1 and A = pointer of the active buffer.
buffer_get_ptr                          ; $DCD4
        jsr active_buffer
buffer_get_ptr_a                        ; $DCD7
        asl
        tax
bgp_load                                ; $DCD9
        lda buf_ptrs+1,x
        sta dir_ptr+1
        lda buf_ptrs,x
        sta dir_ptr
        rts

; Out: A = byte at offset A of the active buffer.
buffer_peek                             ; $DCE2
        sta tmp2
        jsr active_buffer
        tax
        clc
        adc #$03
        sta tmp3
        ldy #$00
        lda (tmp2),y
        rts

; Out: A = number of the active buffer of channel channel.
active_buffer                           ; $DCF2
        ldx channel
        lda chan_buf_a,x
        bpl acb_mask
        lda chan_buf_b,x
acb_mask                                ; $DCFC
        and #$BF
        rts

; Out: A = active buffer number, V = its dirty flag, buf_table_index = index of
; its table entry.
active_buffer_flags                     ; $DCFF
        ldx channel
        stx buf_table_index
        lda chan_buf_a,x
        bpl abf_store
        txa
        clc
        adc #$20
        sta buf_table_index
        lda chan_buf_b,x
abf_store                               ; $DD11
        sta tmp1
        and #$1F
        bit tmp1
        rts

; Unreferenced: is there an inactive buffer?
dead_buffer_test                        ; $DD18
        ldx channel
        lda chan_buf_a,x
        bmi loc_DD22
        lda chan_buf_b,x
loc_DD22
        cmp #$FF
        rts

; Unreferenced: store A as the inactive buffer.
dead_buffer_set                         ; $DD25
        ldx channel
        ora #$80
        ldy chan_buf_a,x
        bpl loc_DD32
        sta chan_buf_a,x
        rts
loc_DD32
        sta chan_buf_b,x
        rts

; ==========================================================================
; U - user commands.  U1-U9 and U: (or UA-UJ) jump through the table at
; user_vec_ptr/user_vec_ptr+1; U0 followed by a command byte is the burst command set.
; ==========================================================================
cmd_user                                ; $DD36
        lda cmd_buf+1
        cmp #$30                        ; U0?
        beq user_u0
        and #$0F                        ; U1-U9, U: or UA-UJ: index * 2
        asl
        tay
        dey
        lda (user_vec_ptr),y            ; vector from the user table
        sta call_vector+1
        dey
        lda (user_vec_ptr),y
        sta call_vector
        jmp user_call
user_u0                                 ; $DD4E
        lda cmd_len                     ; U0 with a command byte = burst
        cmp #$03
        bcs burst_command

; Point the user command vector at the built-in table.
user_table_reset                        ; $DD54
        lda #<user_vectors
        sta user_vec_ptr
        lda #>user_vectors
        sta user_vec_ptr+1

; Burst command slots without a function.
burst_rts                               ; $DD5C
        rts

; U0 burst command.  The bus mode is taken from the partition type
; (burst_mode: $00 native, $80 1581, $40 1541/1571) and the low five bits of
; the command byte select the handler from burst_cmd_tab.
burst_command                           ; $DD5D
        sei
        jsr partition_type              ; bus mode from the partition type
        cmp #$01
        beq bc_native
        cmp #$04
        beq bc_1581
        cmp #$05
        beq bc_1581
        cmp #$03
        beq bc_1541
        cmp #$02
        beq bc_1541
        jmp syntax_error_31
bc_native                               ; $DD78
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
bc_1581                                 ; $DD7B
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
bc_1541                                 ; $DD7E
        lda #$40
bc_dispatch                             ; $DD80
        sta burst_mode
        jsr led_activity_on             ; LED on
        lda #$00
        sta burst_last_clk
        lda cmd_buf+2                   ; burst command byte
        sta burst_cmd
        and #$1F                        ; low five bits select the handler
        asl
        tax
        lda burst_cmd_tab,x
        sta call_vector
        lda burst_cmd_tab+1,x
        sta call_vector+1
user_call                               ; $DD9D
        jsr user_jump
        jmp cmd_done                    ; back: command complete

; Jump through call_vector/call_vector+1.
user_jump                               ; $DDA3
        jmp (call_vector)

; User command vectors U1..U9, U: - block read, block write, six
; entries into buffer RAM at $0500, the NMI routine and the reset.
user_vectors                            ; $DDA6
        !word user_u1                   ; $DDA6
        !word user_u2                   ; $DDA8
        !word $0500                     ; $DDAA
        !word $0503                     ; $DDAC
        !word $0506                     ; $DDAE
        !word $0509                     ; $DDB0
        !word $050C                     ; $DDB2
        !word $050F                     ; $DDB4
        !word nmi_ui_command            ; $DDB6
        !word soft_reset                ; $DDB8

; Burst command handlers, indexed by the low five bits of the command
; byte.
burst_cmd_tab                           ; $DDBA
        !word burst_read                ; $DDBA
        !word burst_cmd_illegal         ; $DDBC
        !word burst_write               ; $DDBE
        !word burst_write_illegal       ; $DDC0
        !word burst_inquire_disk        ; $DDC2
        !word burst_cmd_illegal         ; $DDC4
        !word burst_format              ; $DDC6
        !word burst_format              ; $DDC8
        !word burst_interleave          ; $DDCA
        !word burst_interleave          ; $DDCC
        !word burst_query_format        ; $DDCE
        !word burst_cmd_illegal         ; $DDD0
        !word burst_inquire_status      ; $DDD2
        !word burst_cmd_illegal         ; $DDD4
        !word burst_syntax_e            ; $DDD6
        !word burst_syntax_e            ; $DDD8
        !word burst_read                ; $DDDA
        !word burst_cmd_illegal         ; $DDDC
        !word burst_write               ; $DDDE
        !word burst_write_illegal       ; $DDE0
        !word burst_inquire_disk        ; $DDE2
        !word burst_cmd_illegal         ; $DDE4
        !word burst_format              ; $DDE6
        !word burst_format              ; $DDE8
        !word burst_rts                 ; $DDEA
        !word burst_rts                 ; $DDEC
        !word burst_query_format        ; $DDEE
        !word burst_cmd_illegal         ; $DDF0
        !word burst_dump_cache          ; $DDF2
        !word burst_dump_cache          ; $DDF4
        !word burst_chgutl              ; $DDF6
        !word burst_fastload            ; $DDF8

; Command executed at power-up: run the utility COPYRIGHT CMD 89.
txt_boot_file                           ; $DDFA
        !text "&COPYRIGHT CMD 89"       ; $DDFA

; Error exit while the boot file is being loaded: restore the normal
; error vectors and continue the start-up.
boot_load_failed                        ; $DE0B
        ldx stack_save
        txs
        jsr boot_unhook_errors
        jsr internal_channels_free
        jmp startup_done

; Power-up: try to load and run the utility file 'COPYRIGHT CMD 89'
; from the default partition (the CMD counterpart of the 1581 auto-boot
; file).  Errors are caught by boot_load_failed.
boot_autoexec                           ; $DE17
        jsr boot_hook_errors
        ldx #$00
bae_copy                                ; $DE1C
        lda txt_boot_file,x
        sta cmd_buf,x
        inx
        cpx #$11
        bcc bae_copy
        stx cmd_len

; ==========================================================================
; & - utility loader, as in the 1581.  The file consists of blocks of
; load address (2), length (1), data and a checksum byte; after the last
; block the first load address is called.  Error 39 if the file is
; missing, 50 on a checksum error, 51 if the file ends early.
; ==========================================================================
cmd_utility                             ; $DE29
        ldy #$01
        sty file_name_pos
        jsr resolve_first_name          ; resolve the name
        jsr dir_search_all              ; find the file
        lda file_track
        bne utl_open
        lda #$39                        ; error 39 FILE NOT FOUND
        jmp cmd_error
utl_open                                ; $DE3E
        lda #$FF
        sta work_count
        lda file_sector
        sta sector
        lda file_track
        sta track
        lda #$03                        ; open as USR file
        jsr open_internal_type
utl_block                               ; $DE51
        lda #$00                        ; checksum = 0
        sta utl_checksum_val
        jsr utl_get_byte                ; load address low
        sta rel_work
        jsr utl_checksum
        jsr utl_get_byte                ; load address high
        sta rel_ptr
        jsr utl_checksum
        jsr utl_get_byte                ; length of the block
        sta utl_count_val
        jsr utl_checksum
        lda work_count                  ; first block: keep its load address for the call
        beq utl_data
        lda rel_ptr
        pha
        lda rel_work
        pha
utl_data                                ; $DE79
        jsr utl_get_byte                ; data byte
        ldy #$00
        sty work_count
        sta (rel_work),y
        jsr utl_checksum
        inc rel_work
        bne utl_count
        inc rel_ptr
utl_count                               ; $DE8B
        dec utl_count_val
        bne utl_data
        jsr internal_get_byte           ; checksum byte
        lda utl_checksum_val
        cmp bus_data
        bne utl_error_50
        lda eoi_flag                    ; more blocks until the end of the file
        bne utl_block
        jsr internal_channels_free
        pla                             ; start address
        sta rel_work
        pla
        sta rel_ptr
        jmp (rel_work)                  ; run the utility
utl_error_50                            ; $DEAA
        lda #$50                        ; error 50: checksum
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
utl_error_51                            ; $DEAD
        lda #$51                        ; error 51: file too short
utl_fail                                ; $DEAF
        pha
        jsr header_get_active           ; track/sector of the block for the message
        pla
        jmp jt_dos_error

; Next byte of the utility file; error 51 at a premature end.
utl_get_byte                            ; $DEB7
        jsr internal_get_byte
        lda eoi_flag
        beq utl_error_51
        lda bus_data
        rts

; Add A to the checksum with end-around carry.
utl_checksum                            ; $DEC1
        clc
        adc utl_checksum_val
        adc #$00
        sta utl_checksum_val
        rts

; Save the DOS error and job error vectors and point both at boot_load_failed.
boot_hook_errors                        ; $DECB
        lda jt_job_error+1
        sta saved_job_error_vec
        lda jt_job_error+2
        sta saved_job_error_vec+1
        lda jt_dos_error+1
        sta saved_dos_error_vec
        lda jt_dos_error+2
        sta saved_dos_error_vec+1
        ldx #$36
        jsr error_vector_set_boot
        ldx #$33

; Set jump table slot X to boot_load_failed.
error_vector_set_boot                   ; $DEEA
        lda #<boot_load_failed
        ldy #>boot_load_failed

; Set the target of the jump table slot at offset X to A (low) / Y
; (high).  The table is in write-protected RAM.
jump_vector_set                         ; $DEEE
        pha
        jsr ram_unprotect
        pla
        sta jt_cmd_block+1,x
        tya
        sta jt_cmd_block+2,x
        jmp ram_protect

; Restore the saved error vectors.
boot_unhook_errors                      ; $DEFD
        ldx #$36
        lda saved_job_error_vec
        ldy saved_job_error_vec+1
        jsr jump_vector_set
        ldx #$33
        lda saved_dos_error_vec
        ldy saved_dos_error_vec+1
        jmp jump_vector_set

; ==========================================================================
; Job error (jump table slot jt_job_error).  In: A = job status (2-15, mapped
; to a DOS error by job_error_map) or a DOS error number, X = buffer whose
; header gives track and sector.
; ==========================================================================
job_error                               ; $DF13
        cmp #$10
        bcs jer_report
        tay
        lda job_error_map,y             ; job status -> DOS error number
jer_report                              ; $DF1B
        pha
        txa
        sta buf_num
        asl
        tay
        lda job_track,y                 ; track / sector of the failing job
        sta track
        lda job_sector,y
        sta sector
        lda cmd_index                   ; error outside a command: re-initialise the partition
        cmp #$00
        bne jer_dos_error
        lda #$FF
        sta cmd_index
        jsr partition_init
jer_dos_error                           ; $DF3A
        pla

; ==========================================================================
; DOS error (jump table slot jt_dos_error).  In: A = error number, track/sector
; = track and sector.  Builds the message, restores the stack and drops
; the channel that was being served, then returns to the idle loop.
; ==========================================================================
dos_error                               ; $DF3B
        jsr status_set                  ; build the message text
error_abort                             ; $DF3E
        ldx stack_save                  ; throw away the call stack
        txs
        jsr cmdbuf_ptr_reset
        jsr internal_channels_free      ; free the internal channels
        jsr led_error_on                ; error LED
        lda sec_addr_raw
        and #$0F
        sta sec_addr
        cmp #$0F                        ; command channel: nothing to drop
        beq eab_exit
        bit bus_role
        bvs eab_listener
        bpl eab_idle
        jsr channel_find_read
        jmp eab_channel
eab_listener                            ; $DF60
        jsr channel_find_write
        jmp eab_channel
eab_idle                                ; $DF66
        tax
        lda sa_channel,x
        cmp #$FF
        beq eab_exit
        jsr channel_select
eab_channel                             ; $DF71
        jsr bam_select_slot
        lda #$00                        ; BAM cache no longer dirty
        sta bam_dirty,x
        jsr channel_file_type           ; sequential file: free its channel
        bcs eab_exit
        jsr channel_free
eab_exit                                ; $DF81
        jmp jt_idle_loop                ; back to the idle loop

; DOS error numbers for job status 0-15.
job_error_map                           ; $DF84
        !byte $00,$00,$40,$41,$66,$44,$45,$46 ; $DF84
        !byte $26,$47,$76,$42,$43,$76,$48,$74 ; $DF8C

; Syntax error entries 30-34, chained with BIT skips: build the message
; and abort the command.
syntax_error_30                         ; $DF94
        lda #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
syntax_error_31                         ; $DF97
        lda #$31
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
syntax_error_32                         ; $DF9A
        lda #$32
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
syntax_error_33                         ; $DF9D
        lda #$33
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
syntax_error_34                         ; $DFA0
        lda #$34
syntax_error_report                     ; $DFA2
        jsr status_set_no_ts
        jmp error_abort

; Set the status to 00, OK,00,00 and switch the error LED off.
status_ok                               ; $DFA8
        jsr led_error_off
        lda #$00

; Set the status message for error A with track and sector 00.
status_set_no_ts                        ; $DFAD
        pha
        lda #$00
        sta track
        sta sector
        pla

; Build the status message 'nn, TEXT,ttt,sss' for error A in the
; message buffer.  For errors 40-4F the SCSI ID and LUN of the failing
; job are inserted, for error 40 also its block address in hex.
; X and Y are preserved.
status_set                              ; $DFB5
        sta tmp0
        txa
        pha
        tya
        pha
        lda tmp0
        ldx #$00
sts_find                                ; $DFBF
        cmp error_numbers,x             ; find the error number
        beq sts_found
        inx
        bne sts_find
sts_found                               ; $DFC7
        pha
        txa
        asl
        tax
        lda error_text_ptrs+1,x         ; its message text
        sta errbuf_ptr+1
        lda error_text_ptrs,x
        sta errbuf_ptr
        pla
        pha
        ldx #$00
        jsr status_put_hex              ; error number as two digits
        lda msg_buf                     ; first character is also the first byte to send
        sta chan_data+31
        jsr status_put_comma
        ldy #$00
sts_text                                ; $DFE7
        lda (errbuf_ptr),y              ; copy the text
        beq sts_numbers
        jsr status_put_char
        iny
        bne sts_text
sts_numbers                             ; $DFF1
        pla
        tay
        and #$F0                        ; errors $40-$4F: SCSI details
        cmp #$40
        bne sts_track_sector
        tya
        pha
        ldy buf_num
        lda job_scsi_id,y               ; SCSI ID
dat_E000
        jsr status_put_digit_sp
        lda job_scsi_lun,y              ; LUN
        jsr status_put_digit_sp
        pla
        cmp #$40
        bne sts_track_sector
        lda job_block_hi,y              ; block address, three bytes
        jsr status_put_hex_sp
        lda job_block_mid,y
        jsr status_put_hex_sp
        lda job_block_lo,y
        jsr status_put_hex_sp
sts_track_sector                        ; $E020
        lda track                       ; track
        jsr status_put_decimal
        lda sector                      ; sector
        jsr status_put_decimal
        dex
        txa
        clc                             ; length of the message
        adc #$00
        sta errchan_last_index
        jsr errbuf_ptr_reset            ; reset the read pointer
        inc errbuf_ptr
        lda #$88                        ; error channel: ready to talk
        sta chan_status+31
        pla
        tay
        pla
        tax
        rts

; Append a space and A as two hex digits.
status_put_hex_sp                       ; $E041
        jsr status_put_space
        jsr status_put_hex
        ldy buf_num
        rts

; Append a space and the low nibble of A as one hex digit.
status_put_digit_sp                     ; $E04A
        jsr status_put_space
        jsr status_put_nibble
        ldy buf_num
        rts

; Append A as two hex digits (also used for the BCD error number).
status_put_hex                          ; $E053
        pha
        lsr
        lsr
        lsr
        lsr
        jsr spn_y
        pla

status_put_nibble                       ; $E05C
        and #$0F

spn_y                                   ; $E05E
        tay

status_put_digit_y                      ; $E05F
        lda hex_digits,y
        jmp status_put_char

; Append a comma and A in decimal: two digits, three above 99.
status_put_decimal                      ; $E065
        pha
        jsr status_put_comma
        pla
        cmp #$64                        ; three digits above 99
        bcc spd_tens
        ldy #$64
        jsr spd_digit
spd_tens                                ; $E073
        ldy #$0A
        jsr spd_digit
        ldy #$01

spd_digit                               ; $E07A
        sty tmp0
        ldy #$00
spd_sub                                 ; $E07E
        cmp tmp0
        bcc spd_out
        sbc tmp0
        iny
        bne spd_sub
spd_out                                 ; $E087
        pha
        jsr status_put_digit_y
        pla
        rts

; Append a space.
status_put_space                        ; $E08D
        pha
        lda #$20
        sta msg_buf,x
        inx
        pla
        rts

; Append a comma (status_put_char: the character in A).
status_put_comma                        ; $E096
        lda #$2C

; Append the character in A.
status_put_char                         ; $E098
        sta msg_buf,x
        inx
        rts

; Digits for hex output.
hex_digits                              ; $E09D
        !text "0123456789ABCDEF"        ; $E09D

; Error numbers (BCD) in the order of the message pointer table.
error_numbers                           ; $E0AD
        !byte $00,$52,$50,$51,$26,$30,$31,$32,$33,$34 ; $E0AD
        !byte $60,$63,$64,$65,$66,$67,$61,$39,$62,$01 ; $E0B7
        !byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$02 ; $E0C1
        !byte $38,$40,$41,$42,$43,$44,$45,$46,$47,$48 ; $E0CB

; Message text of each error number.
error_text_ptrs                         ; $E0D5
        !word msg_ok                    ; $E0D5
        !word msg_file_too_long         ; $E0D7
        !word msg_record_not_present    ; $E0D9
        !word msg_overflow_in_record    ; $E0DB
        !word msg_write_protect_on      ; $E0DD
        !word msg_syntax_error          ; $E0DF
        !word msg_syntax_error          ; $E0E1
        !word msg_syntax_error          ; $E0E3
        !word msg_syntax_error          ; $E0E5
        !word msg_syntax_error          ; $E0E7
        !word msg_write_file_open       ; $E0E9
        !word msg_file_exists           ; $E0EB
        !word msg_file_type_mismatch    ; $E0ED
        !word msg_no_block              ; $E0EF
        !word msg_illegal_block         ; $E0F1
        !word msg_illegal_block         ; $E0F3
        !word msg_file_not_open         ; $E0F5
        !word msg_file_not_found        ; $E0F7
        !word msg_file_not_found        ; $E0F9
        !word msg_files_scratched       ; $E0FB
        !word msg_no_channel            ; $E0FD
        !word msg_directory_error       ; $E0FF
        !word msg_partition_full        ; $E101
        !word msg_dos_version           ; $E103
        !word msg_drive_not_ready       ; $E105
        !word msg_format_error          ; $E107
        !word msg_hardware_error        ; $E109
        !word msg_partition_illegal     ; $E10B
        !word msg_system_error          ; $E10D
        !word msg_partition_selected    ; $E10F
        !word msg_directory_not_found   ; $E111
        !word msg_scsi_error            ; $E113
        !word msg_status_error          ; $E115
        !word msg_status_error          ; $E117
        !word msg_status_error          ; $E119
        !word msg_controller_error      ; $E11B
        !word msg_controller_error      ; $E11D
        !word msg_controller_error      ; $E11F
        !word msg_controller_error      ; $E121
        !word msg_illegal_job           ; $E123
msg_ok                                  ; $E125
        !text " OK"                     ; $E125
        !byte $00                       ; $E128
msg_file_too_long                       ; $E129
        !text "FILE TOO LONG"           ; $E129
        !byte $00                       ; $E136
msg_record_not_present                  ; $E137
        !text "RECORD NOT PRESENT"      ; $E137
        !byte $00                       ; $E149
msg_overflow_in_record                  ; $E14A
        !text "OVERFLOW IN RECORD"      ; $E14A
        !byte $00                       ; $E15C
msg_write_protect_on                    ; $E15D
        !text "WRITE PROTECT ON"        ; $E15D
        !byte $00                       ; $E16D
msg_syntax_error                        ; $E16E
        !text "SYNTAX ERROR"            ; $E16E
        !byte $00                       ; $E17A
msg_write_file_open                     ; $E17B
        !text "WRITE FILE OPEN"         ; $E17B
        !byte $00                       ; $E18A
msg_file_exists                         ; $E18B
        !text "FILE EXISTS"             ; $E18B
        !byte $00                       ; $E196
msg_file_type_mismatch                  ; $E197
        !text "FILE TYPE MISMATCH"      ; $E197
        !byte $00                       ; $E1A9
msg_no_block                            ; $E1AA
        !text "NO BLOCK"                ; $E1AA
        !byte $00                       ; $E1B2
msg_illegal_block                       ; $E1B3
        !text "ILLEGAL BLOCK"           ; $E1B3
        !byte $00                       ; $E1C0
msg_file_not_open                       ; $E1C1
        !text "FILE NOT OPEN"           ; $E1C1
        !byte $00                       ; $E1CE
msg_file_not_found                      ; $E1CF
        !text "FILE NOT FOUND"          ; $E1CF
        !byte $00                       ; $E1DD
msg_files_scratched                     ; $E1DE
        !text " FILES SCRATCHED"        ; $E1DE
        !byte $00                       ; $E1EE
msg_no_channel                          ; $E1EF
        !text "NO CHANNEL"              ; $E1EF
        !byte $00                       ; $E1F9
msg_directory_error                     ; $E1FA
        !text "DIRECTORY ERROR"         ; $E1FA
        !byte $00                       ; $E209
msg_partition_full                      ; $E20A
        !text "PARTITION FULL"          ; $E20A
        !byte $00                       ; $E218
msg_dos_version                         ; $E219
        !text "CMD HD DOS V1.92"        ; $E219
        !byte $00                       ; $E229
msg_drive_not_ready                     ; $E22A
        !text "DRIVE NOT READY"         ; $E22A
        !byte $00                       ; $E239
msg_format_error                        ; $E23A
        !text "FORMAT ERROR"            ; $E23A
        !byte $00                       ; $E246
msg_hardware_error                      ; $E247
        !text "HARDWARE ERROR"          ; $E247
        !byte $00                       ; $E255
msg_partition_illegal                   ; $E256
        !text "SELECTED PARTITION ILLEGAL" ; $E256
        !byte $00                       ; $E270
msg_system_error                        ; $E271
        !text "SYSTEM ERROR"            ; $E271
        !byte $00                       ; $E27D
msg_partition_selected                  ; $E27E
        !text "PARTITION SELECTED"      ; $E27E
        !byte $00                       ; $E290
msg_scsi_error                          ; $E291
        !text "SCSI ERROR"              ; $E291
        !byte $00                       ; $E29B
msg_status_error                        ; $E29C
        !text "STATUS ERROR"            ; $E29C
        !byte $00                       ; $E2A8
msg_controller_error                    ; $E2A9
        !text "CONTROLLER ERROR"        ; $E2A9
        !byte $00                       ; $E2B9
msg_illegal_job                         ; $E2BA
        !text "ILLEGAL JOB"             ; $E2BA
        !byte $00                       ; $E2C5
msg_directory_not_found                 ; $E2C6
        !text "DIRECTORY NOT FOUND"     ; $E2C6
        !byte $00                       ; $E2D9
burst_done                              ; $E2DA
        jmp cmd_done

; Burst command $1F: fast load.  'U0' $1F name sends the whole
; program file through the fast serial bus, each block preceded by a
; status byte (and the byte count for the last block).  Refused unless
; burst mode is enabled.
burst_fastload                          ; $E2DD
        lda bus_role                    ; burst mode enabled?
        and #$04
        beq burst_done
        ldy #$03
        jsr find_separator
        beq loc_E2EC
        ldy #$04
loc_E2EC
        cpy #$04
        bcc loc_E2F1
        dey
loc_E2F1
        sty file_name_pos
        lda cmd_len
        sta name2_index
        lda cmd_buf+3                   ; '*': last program
        cmp #$2A
        bne bfl_lookup
        jsr bam_select_slot
        lda last_prg_track,x
        beq bfl_lookup
        ldy last_prg_sector,x
        jmp bfl_send
bfl_lookup                              ; $E30E
        jsr names_single
        bcs bfl_not_ready
        jsr partition_check_ready       ; partition ready?
        bne bfl_not_ready
        lda #$01
        sta param_count
        sta file_count
        jsr dir_search_all
        lda file_track
        beq bfl_not_found
        lda file_type_flags             ; must be a PRG file
        and #$03
        cmp #$02
        beq bfl_found
        bit burst_cmd                   ; unless bit 7 of the command allows any type
        bmi bfl_found
bfl_not_ready                           ; $E335
        lda #$0F                        ; status $0F: drive not ready
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
bfl_not_found                           ; $E338
        lda #$02                        ; status 2: file not found
bfl_fail                                ; $E33A
        pha
        jsr burst_send_status_byte
        pla
        cmp #$0F
        beq loc_E346
        lda #$62                        ; error 62 / 74
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E346
        lda #$74
        jmp cmd_error
bfl_found                               ; $E34B
        jsr bam_select_slot
        lda file_sector
        tay
        sta last_prg_sector,x           ; remember it as the last program
        lda file_track
        sta last_prg_track,x
bfl_send                                ; $E35B
        sta track
        sty sector
        lda #$02                        ; first block: skip the load address (?)
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
bfl_block                               ; $E362
        lda #$00
        sta bit_count
        ldx #$00
        lda #$AA                        ; job $AA: read
        jsr burst_job_buf0
        jsr burst_sr_output             ; shift register to output
        ldy #$01
        lda (data_ptr),y
        sta sector
        dey
        lda (data_ptr),y
        sta track
        bne bfl_full_block
        lda #$1F                        ; status $1F: last block follows
        jsr jt_burst_send_byte
        ldx sector                      ; number of bytes in it
        dex
        txa
        sec
        sbc bit_count
        jmp bfl_data
bfl_full_block                          ; $E38C
        ldx #$FE                        ; 254 bytes, status 0
        lda #$00
bfl_data                                ; $E390
        jsr jt_burst_send_byte
        ldy #$02
bfl_byte                                ; $E395
        lda (data_ptr),y
        jsr jt_burst_send_byte
        iny
        dex
        bne bfl_byte
        jsr burst_sr_input              ; shift register back to input
        lda track
        bne bfl_block
        jmp cmd_done

; Run job A for buffer X with header track/sector; on an error send
; status 2 to the host and raise the job error.
burst_job_buf0                          ; $E3A8
        pha
        txa
        jsr header_set
        pla
        jsr job_run
        cmp #$02
        bcs bjb_error
        rts
bjb_error                               ; $E3B6
        pha
        lda #$02
        jsr burst_send_status_byte
        pla
        jmp job_error

; Merge the job result A into the burst status byte burst_status.
burst_status_set                        ; $E3C0
        sta burst_result
        lda burst_status
        bit burst_mode                  ; 1581 mode: status layout differs
        bpl bss_other
        and #$80
        ora #$20
        ora burst_result
        and burst_status_and
        ora burst_status_or
bss_store                               ; $E3D5
        sta burst_status
        lda burst_result
        rts
bss_other                               ; $E3DB
        and #$F0
        ora burst_result
        jmp bss_store

; Run job A and report its result as burst status.
burst_job                               ; $E3E3
        jsr job_run
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction

; Burst command without a function here: status $4F.
burst_cmd_illegal                       ; $E3E7
        lda #$4F

; Record status A; on an error (unless the command's 'ignore error'
; bit is set) send the status byte and raise the job error.
burst_status_report                     ; $E3E9
        jsr burst_status_set
        cmp #$02
        bcc burst_status_send
        bit burst_cmd                   ; bit 6 of the command: ignore errors
        bvs burst_status_send
        jsr burst_status_send
bsr_job_error                           ; $E3F7
        lda burst_result
        and #$0F
        ldx #$00
        jmp jt_job_error

; Send the burst status byte to the host.
burst_status_send                       ; $E401
        lda burst_status
        bit burst_mode
        bvc burst_send_status_byte
        and #$0F
        bne bsd_merge
        lda #$01
bsd_merge                               ; $E40E
        ora burst_status

; Send A as a single byte over the fast serial bus.
burst_send_status_byte                  ; $E410
        pha
        jsr burst_sr_output
        pla
        jsr jt_burst_send_byte
        jmp burst_sr_input

; Jump table slot jt_burst_send_byte: send A over the fast serial bus after the
; host has toggled CLK.  ATN or a parallel request aborts.
burst_send_byte_hs                      ; $E41B
        pha
bsb_wait                                ; $E41C
        bit ppi_pb                      ; parallel request aborts
        bmi burst_atn_abort
        lda via1_prb                    ; ATN aborts
        bmi burst_atn_abort
        and #$04                        ; wait for a CLK edge from the host
        cmp burst_last_clk
        beq bsb_wait
        sta burst_last_clk
        pla
        sta via1_sr                     ; byte into the shift register
        lda #$04                        ; wait until it is out
bsb_sr_wait                             ; $E434
        bit via1_ifr
        beq bsb_sr_wait
        rts
burst_atn_abort                         ; $E43A
        jmp jt_atn_service

; Jump table slot jt_burst_get_byte: toggle CLK to request a byte and receive
; it through the shift register.
burst_recv_byte_hs                      ; $E43D
        bit via1_sr
        lda via1_prb                    ; toggle CLK: ready for a byte
        eor #$08
        sta via1_prb
        lda #$04
brb_wait                                ; $E44A
        bit ppi_pb
        bmi burst_atn_abort
        bit via1_prb
        bmi burst_atn_abort
        bit via1_ifr                    ; byte arrived?
        beq brb_wait
        lda via1_sr
        rts

; Wait until the host toggles CLK.
burst_wait_clk_toggle                   ; $E45D
        bit ppi_pb
        bmi burst_atn_abort
        lda via1_prb
        bmi burst_atn_abort
        and #$04
        cmp burst_last_clk
        beq burst_wait_clk_toggle
        sta burst_last_clk
        rts

; Send one or two pages (burst_send_2_pages) or X pages (burst_send_pages) starting at
; (data_ptr) over the fast serial bus.
burst_send_1_page                       ; $E470
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_send_2_pages                      ; $E473
        ldx #$02
burst_send_pages                        ; $E475
        ldy #$00
        jsr burst_sr_output
bsp_byte                                ; $E47A
        lda (data_ptr),y
        jsr jt_burst_send_byte
        iny
        bne bsp_byte
        dex
        beq loc_E48A
        inc data_ptr+1
        jmp bsp_byte
loc_E48A
        jmp burst_sr_input

; Receive one or two pages (burst_recv_2_pages) or X pages (burst_recv_pages) to (data_ptr).
burst_recv_1_page                       ; $E48D
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_recv_2_pages                      ; $E490
        ldx #$02
burst_recv_pages                        ; $E492
        ldy #$00
        jsr burst_sr_input
brp_byte                                ; $E497
        jsr jt_burst_get_byte
        sta (data_ptr),y
        iny
        bne brp_byte
        dex
        beq loc_E4A7
        inc data_ptr+1
        jmp brp_byte
loc_E4A7
        jmp serial_clk_release

; Set the side flag, then the job header from the command's track
; and sector bytes.
burst_setup_side                        ; $E4AA
        jsr burst_set_side

burst_setup_ts                          ; $E4AD
        lda cmd_buf+3
        sta track
        lda cmd_buf+4
        sta sector

burst_set_header0                       ; $E4B7
        lda #$00
        jsr header_set
        lda #$00
        rts

; Take the side from bit 4 of the command byte.
burst_set_side                          ; $E4BF
        lda burst_cmd
        and #$10
        ldx #$00
        sta job_side,x
        rts

; Burst commands 0 / $10: read sectors.  'U0' cmd track sector count.
; Each sector is sent with a leading status byte.
burst_read                              ; $E4C9
        bit burst_mode
        bmi brd_1581
brd_1541_loop                           ; $E4CE
        lda #$20                        ; bit 5: no transfer, just seek (?)
        bit burst_cmd
        bne loc_E4E0
        jsr burst_setup_ts
        lda #$80                        ; job $80: read
        jsr burst_job
        bit burst_cmd
        bmi loc_E4E3
loc_E4E0
        jsr burst_send_1_page
loc_E4E3
        jsr burst_next_sector_1541
        jmp brd_1541_loop
brd_1581                                ; $E4E9
        bit burst_cmd
        bmi brd_1581_logical
brd_1581_physical                       ; $E4ED
        jsr burst_setup_side
        lda #$B2                        ; job $B2: read physical sector
        jsr burst_job
        jsr burst_send_2_pages
        jsr burst_next_sector_1581
        jmp brd_1581_physical
brd_1581_logical                        ; $E4FE
        bit burst_status_or
        bmi brd_illegal
brd_1581_loop                           ; $E502
        jsr burst_setup_ts
        lda #$80
        jsr burst_job
        jsr burst_send_1_page
        jsr burst_next_sector_1581
        jmp brd_1581_loop
brd_illegal                             ; $E513
        lda #$8D                        ; status $0D / $0B
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dat_E516
        lda #$0B
burst_report_a                          ; $E518
        jmp burst_status_report

; Burst commands 2 / $12: write sectors.  The data are received
; first, then written; status after each sector.
burst_write                             ; $E51B
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_write_illegal                     ; $E51E
        lda #$4F
        sta burst_result
        bit burst_mode
        bmi bwr_1581
        bit burst_cmd
        bmi bwr_1541_write
bwr_1541_loop                           ; $E52C
        lda #$00                        ; receive the sector into buffer 0
        sta data_ptr
        lda #$03
        sta data_ptr+1
        jsr burst_recv_1_page
bwr_1541_write                          ; $E537
        lda #$20
        bit burst_cmd
        bne loc_E54F
        lda burst_result
        cmp #$02
        bcs burst_report_a
        jsr burst_setup_ts
        lda #$90                        ; job $90: write
        jsr burst_job
        jsr burst_wait_clk_toggle
loc_E54F
        jsr burst_next_sector_1541
        jmp bwr_1541_loop
bwr_1581                                ; $E555
        bit burst_cmd
        bmi bwr_1581_logical
bwr_1581_physical                       ; $E559
        jsr data_ptr_cache
        jsr burst_recv_2_pages
        lda burst_result
        cmp #$02
        bcs burst_report_a
        jsr burst_setup_side
        lda #$B4                        ; job $B4: write physical sector
        jsr burst_job
        jsr burst_wait_clk_toggle
        jsr burst_next_sector_1581
        jmp bwr_1581_physical
bwr_1581_logical                        ; $E577
        lda #$00
        sta data_ptr
        lda #$03
        sta data_ptr+1
        jsr burst_recv_1_page
        lda burst_result
        cmp #$02
        bcs burst_report_a
        jsr burst_setup_ts
        lda #$90
        jsr burst_job
        jsr burst_wait_clk_toggle
        jsr burst_next_sector_1581
        jmp bwr_1581_logical

; Burst command 4: inquire disk (log in).
burst_inquire_disk                      ; $E59A
        lda burst_cmd
        lsr
        bcc bid_restore
        jmp burst_cmd_illegal
bid_restore                             ; $E5A2
        lda #$00
        sta burst_status
        ldx #$00
        lda #$C0                        ; job $C0: restore
        jmp burst_job

; Burst command $0C: inquire status - send the status byte, or with
; the write bit set store a new status (and change masks).
burst_inquire_status                    ; $E5AD
        lda #$20
        bit burst_cmd
        bpl bis_write
        jmp burst_status_send
bis_write                               ; $E5B6
        beq loc_E5C2
        lda cmd_buf+4
        sta burst_status_or
        lda cmd_buf+5
        sta burst_status_and
loc_E5C2
        lda cmd_buf+3
        sta burst_status
        rts

; Burst command $0A / $1A: query disk format - returns the status and
; the track's sector layout (10 sectors of 512 bytes per track).
burst_query_format                      ; $E5C8
        jsr burst_inquire_disk
        bit burst_mode
        bmi bqf_1581
        rts
bqf_1581                                ; $E5D1
        bit burst_cmd
        bpl bqf_report
        jsr burst_setup_side
        lda #$01
        sta job_sector
        lda #$A8                        ; job $A8: seek
        jsr job_run
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
bqf_report                              ; $E5E3
        lda #$00
        jsr burst_status_report
        jsr burst_sr_output
        lda #$0A                        ; 10 sectors per track
        jsr jt_burst_send_byte
        bit burst_cmd
        bpl loc_E5F8
        lda cmd_buf+3
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
loc_E5F8
        lda #$00
        jsr jt_burst_send_byte
        lda #$01                        ; first sector 1
        jsr jt_burst_send_byte
        lda #$0A                        ; last sector 10
        jsr jt_burst_send_byte
        lda #$01
        jsr jt_burst_send_byte
        lda burst_cmd
        and #$20
        beq loc_E61D
        ldx #$01                        ; optional sector table 1-10
bqf_sector_table                        ; $E614
        txa
        jsr jt_burst_send_byte
        inx
        cpx #$0B
        bcc bqf_sector_table
loc_E61D
        rts

; Burst commands 6 / 7: format.  On 1541-type partitions this becomes
; the DOS command 'N0:CMD HD,89'; on 1581 partitions the MFM format
; parameters are checked against format_param_min/format_param_max, defaulted from format_param_defaults,
; and every sector is written with the fill byte.
burst_format                            ; $E61E
        lda #$01
        bit burst_cmd
        beq bfm_check
        lda #$4F                        ; status $4F
        jsr burst_status_set
        jmp bsr_job_error
bfm_check                               ; $E62C
        bit burst_mode
        bmi bfm_1581
        bit cmd_buf+3
        bmi bfm_illegal
        lda #$01
        jmp burst_status_set
bfm_illegal                             ; $E63B
        jmp burst_syntax_6
bfm_1581                                ; $E63E
        bmi bfm_physical
        ldx #$00
bfm_copy_cmd                            ; $E642
        lda txt_format_cmd,x
        sta cmd_buf,x
        inx
        cpx #$0C
        bcc bfm_copy_cmd
        stx cmd_len                     ; length of the command
        ldx #$01
        stx file_name_pos
        lda #$0A
        sta name2_index
        dex
        jmp jt_cmd_new                  ; hand over to the N command

; DOS command used for a burst format.
txt_format_cmd                          ; $E65D
        !text "N0:CMD HD"               ; $E65D
txt_E666
        !text ",89"                     ; $E666

; Burst format parameters 3-8: defaults, minimum and maximum.
format_param_defaults                   ; $E669
        !byte $02,$4F,$0A               ; $E669
dat_E66C
        !byte $00,$E5,$01               ; $E66C
format_param_min                        ; $E66F
        !byte $02,$00,$0A               ; $E66F
dat_E672
        !byte $00,$00,$01               ; $E672
format_param_max                        ; $E675
        !byte $02,$4F,$0A,$4F,$00,$01   ; $E675

; Burst command not available on this partition type: status $0E
; (or 6) and a syntax error.
burst_syntax_e                          ; $E67B
        lda #$0E
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_syntax_6                          ; $E67E
        lda #$06
        jsr burst_status_set
        jmp syntax_error_31
bfm_physical                            ; $E686
        ldx #$03
bfm_check_params                        ; $E688
        cpx cmd_len
        beq bfm_defaults
        lda cmd_buf,x
        cmp dat_E66C,x
        bcc burst_syntax_e
        cmp dat_E672,x
        bcc loc_E69B
        bne burst_syntax_e
loc_E69B
        inx
        bne bfm_check_params
bfm_defaults                            ; $E69E
        cpx #$09
        bcs bfm_fill
        lda txt_E666,x
        sta cmd_buf,x
        inx
        bne bfm_defaults
bfm_fill                                ; $E6AB
        ldx #$00
        lda cmd_buf+7                   ; fill byte
loc_E6B0
        sta block_cache,x
        sta $5100,x
        inx
        bne loc_E6B0
        lda burst_cmd
        and #$EF
        sta burst_cmd
bfm_sector                              ; $E6BF
        lda cmd_buf+6
        sta track
        lda cmd_buf+8
        sta sector
        jsr burst_set_side
        jsr burst_set_header0
        lda #$B4                        ; job $B4: write physical sector
        jsr job_run
        cmp #$02
        bcc loc_E6DB
        jmp burst_syntax_6
loc_E6DB
        inc cmd_buf+8                   ; sectors 1-10
        lda cmd_buf+8
        cmp #$0B
        bcc bfm_sector
        lda #$01
        sta cmd_buf+8
        lda burst_cmd                   ; other side
        eor #$10
        sta burst_cmd
        and #$10
        bne bfm_sector
        inc cmd_buf+6                   ; next track
        lda cmd_buf+6
        cmp cmd_buf+4
        bcc bfm_sector
        beq bfm_sector
        lda #$00
        jmp burst_status_set

; Burst commands $1C / $1D (dump track cache): nothing to do, report OK.
burst_dump_cache                        ; $E706
        bit burst_mode
        bmi loc_E70C
        rts
loc_E70C
        lda #$00
        jmp burst_status_report

; Burst command $1E: 'U0>' utilities.  B0/B1 disable/enable burst mode,
; S sector interleave, R retry count, T V M accepted and ignored,
; MR/MW read/write drive memory pages, a number 4-30 = new device
; number.
burst_chgutl                            ; $E711
        sei
        ldx cmd_buf+4
        lda cmd_len
        cmp #$04
        bcs bcu_letter
bcu_syntax                              ; $E71B
        jmp syntax_error_31
bcu_letter                              ; $E71E
        lda cmd_buf+3
        cmp #$42                        ; B
        bne bcu_s
        txa
        cmp #$30
        beq bcu_set_burst
        cmp #$31
        bne bcu_syntax
bcu_set_burst                           ; $E72E
        pha                             ; bit 2 of bus_role: burst mode allowed
        lda bus_role
        and #$FB
        sta bus_role
        pla
        and #$01
        asl
        asl
        ora bus_role
        sta bus_role
        rts
bcu_s                                   ; $E73F
        cmp #$53                        ; S: sector interleave
        bne bcu_r
        stx burst_interleave_s
        rts
bcu_r                                   ; $E746
        cmp #$52                        ; R: retries
        bne bcu_ignored
        stx burst_retries
        rts
bcu_ignored                             ; $E74D
        cmp #$54                        ; T, V, M: no function
        beq loc_E759
        cmp #$56
        beq loc_E759
        cmp #$4D
        bne bcu_device
loc_E759
        rts
bcu_device                              ; $E75A
        cmp #$4D
        beq bcu_memory
        cmp #$04                        ; device number 4-30
        bcc bcu_syntax
        cmp #$1F
        bcs bcu_syntax
        ora #$40                        ; new TALK and LISTEN addresses
        sta talk_addr
        eor #$60
        sta listen_addr
        rts
bcu_memory                              ; $E76F
        lda #$00
        sta burst_last_clk
        sta data_ptr
        lda cmd_buf+5
        sta data_ptr+1
        cpx #$57                        ; MW
        beq bcu_mem_write
        cpx #$52                        ; MR
        bne bcu_syntax
        ldx cmd_buf+6
        jmp burst_send_pages
bcu_mem_write                           ; $E788
        ldx cmd_buf+6
        jmp burst_recv_pages

; Burst commands 8 / 9: set or read back the sector interleave
; (1541-type partitions only).
burst_interleave                        ; $E78E
        bit burst_mode
        bvs loc_E796
loc_E793
        jmp burst_syntax_e
loc_E796
        bit burst_cmd
        bmi bil_report
        lda cmd_len
        cmp #$04
        bcc loc_E793
        lda cmd_buf+3
        sta sector_interleave
        rts
bil_report                              ; $E7A7
        lda sector_interleave
        jmp burst_send_status_byte

; Count down the sector counter of the command and step to the next
; sector, 1581 geometry (40 logical sectors per track, or 10 per side).
burst_next_sector_1581                  ; $E7AD
        dec cmd_buf+5
        bne bns_step
        pla
        pla
        rts
bns_step                                ; $E7B5
        inc cmd_buf+4
        lda cmd_buf+4
        bit burst_cmd
        bpl bns_physical
        cmp #$28                        ; 40 logical sectors per track
        bcc loc_E7CB
        lda #$00
        sta cmd_buf+4
loc_E7C8
        inc cmd_buf+3
loc_E7CB
        rts
bns_physical                            ; $E7CC
        cmp #$0B                        ; 10 physical sectors, then the other side
        bcc loc_E7CB
        lda #$01
        sta cmd_buf+4
        lda burst_cmd
        eor #$10
        sta burst_cmd
        and #$10
        beq loc_E7C8
        rts

; Same for 1541-type partitions (interleave and zone wrap) and native
; partitions (plain increment).
burst_next_sector_1541                  ; $E7E0
        dec cmd_buf+5
        bne bn4_step
        pla
        pla
        rts
bn4_step                                ; $E7E8
        bit burst_mode
        bvc bn4_native
        ldx #$00
        lda cmd_buf+3
loc_E7F2
        cmp zone_first_track,x          ; speed zone of the track
        bcc loc_E7FA
        inx
        bne loc_E7F2
loc_E7FA
        dex
        lda cmd_buf+4
        clc
        adc sector_interleave           ; add the interleave, wrap at the zone's sector count
        cmp zone_sectors,x
        bcc loc_E80A
        sbc zone_sectors,x
loc_E80A
        sta cmd_buf+4
        rts
bn4_native                              ; $E80E
        inc cmd_buf+4
        bne loc_E81B
        inc cmd_buf+3
        bne loc_E81B
        inc cmd_buf+3
loc_E81B
        rts

; ==========================================================================
; Job queue (jump table slot jt_do_job): run job A for buffer X and wait;
; a failure goes straight to the job error handler.
; ==========================================================================
job_run_or_error                        ; $E81C
        jsr job_run
        bcs jre_fail
        rts
jre_fail                                ; $E822
        jmp jt_job_error

; Jump table slot jt_do_job_status: run job A for buffer X and wait.  Failed jobs
; are repeated up to the retry count.  Out: A = status, carry set and
; A >= 2 on error.  X and Y are preserved.
job_run                                 ; $E825
        php
        sei
        cpx #$20                        ; 32 job slots
        bcc jrn_queue
        lda #$0E                        ; status $0E: illegal job slot
        plp
        cmp #$02
        rts
jrn_queue                               ; $E831
        sta job_queue,x
        sta job_code_saved,x            ; keep the code for retries
        lda job_retries
        and #$3F
        sta job_retries_left
jrn_execute                             ; $E83E
        tya
        pha
        txa
        pha
        jsr job_scan                    ; run the queue
        pla
        tax
        pla
        tay
        lda job_queue,x                 ; status below 2 = success
        cmp #$02
        bcs jrn_retry
jrn_done                                ; $E84F
        plp
        cmp #$02
        rts
jrn_retry                               ; $E853
        dec job_retries_left            ; retries left?
        bmi jrn_done
        lda job_code_saved,x
        sta job_queue,x
        jmp jrn_execute

; Jump table slot jt_run_jobs: execute every pending job (slots with bit 7
; set).  Also called from the timer interrupt.
job_scan                                ; $E860
        php
        sei
        jsr job_import_classic
        ldx #$00
jsc_slot                                ; $E867
        lda job_queue,x
        bpl jsc_next                    ; bit 7 set = job pending
        sta job_current
        stx job_buffer
        lsr                             ; odd job codes are illegal
        lda #$C2                        ; result $C2
        bcs jsc_finish
        jsr job_dispatch
jsc_finish                              ; $E879
        jsr job_finish                  ; store the status
        jsr job_export_classic
        ldx job_buffer
jsc_next                                ; $E882
        inx
        cpx #$20
        bcc jsc_slot
        jsr led_update
        plp
        rts

; On emulation partitions take over jobs that a host program wrote
; into the classic queue locations: $00-$04 with headers at $06 for
; 1541/1571, $02-$0C with headers at $0B for 1581.
job_import_classic                      ; $E88C
        jsr partition_type
        ldx #$00
        cmp #$01
        beq jic_clear                   ; native: no classic queue
        cmp #$04
        bcc jic_1541
        cmp #$06
        bcs jic_clear
jic_1581                                ; $E89D
        lda $02,x
        bpl jic_1581_next
        sta job_queue,x
        txa
        asl
        tay
        lda $000B,y
        sta job_track,y
        lda $000C,y
        sta job_sector,y
jic_1581_next                           ; $E8B2
        inx
        cpx #$0B
        bcc jic_1581
        bcs jic_clear
jic_1541                                ; $E8B9
        lda $00,x
        bpl jic_1541_next
        sta job_queue,x
        txa
        asl
        tay
        lda $0006,y
        sta job_track,y
        lda $0007,y
        sta job_sector,y
jic_1541_next                           ; $E8CE
        inx
        cpx #$05
        bcc jic_1541
jic_clear                               ; $E8D3
        ldx #$0A
loc_E8D5
        lda $00,x
        and #$7F
        sta $00,x
        dex
        bpl loc_E8D5
        rts

; Copy the status of the finished job back to the classic location.
job_export_classic                      ; $E8DF
        jsr partition_type
        ldx job_buffer
        cmp #$01
        beq jec_rts
        cmp #$04
        bcc jec_1541
        cmp #$06
        bcs jec_rts
        lda job_queue,x
        sta $02,x
        rts
jec_1541                                ; $E8F6
        lda job_queue,x
        sta $00,x
jec_rts                                 ; $E8FA
        rts

; Drive the LED bits of the control latch from panel_state; the error LED
; blinks.
led_update                              ; $E8FB
        lda #$02
        and panel_state                 ; bit 1: error LED blinking
        beq led_write
        dec led_blink_timer             ; blink timer
        bne led_blink_bit
        lda #$19
        sta led_blink_timer
        lda ctl_latch
        eor #$02
        sta ctl_latch
led_blink_bit                           ; $E913
        lda #$02
led_write                               ; $E915
        ora #$20
        and ctl_latch
        eor panel_state
        eor #$DF
        and #$EF
        sta ctl_latch
        rts

; Look the job code up in job_codes and jump to its handler.
; Out: A = result; $C1 for an unknown code.
job_dispatch                            ; $E924
        ldx #$2A
        lda job_current
jdp_find                                ; $E929
        cmp job_codes,x
        beq jdp_found
        dex
        bpl jdp_find
        lda #$C1                        ; result $C1: unknown job
        rts
jdp_found                               ; $E934
        txa
        asl
        tax
        lda job_handlers,x
        sta job_vector
        lda job_handlers+1,x
        sta job_vector+1
        jmp (job_vector)

; Job codes, with the names used in the CMD HD User's Manual (p. 9-65):
; $80 READ, $90 WRITE, $82 CTRL RESET, $94/$96 ACTIV ON/OFF, $98/$9A ERR
; ON/OFF, $A4 PHYS->BUF0 / $A6 BUF0->PHYS (physical sector via $0300),
; $AA/$AC READ/WRT_LOG_NQ (no copy to the job buffer), $B2/$B4
; READ/WRT_PHYS_NQ, $B6 WRT_PROT (status 8 when protected), $C0 BUMP,
; $CC/$CE RD/WRT_LOG_ADDR (to/from a target address), $D0 JUMP, $E0 EXEC,
; $EC/$EE READ/WRT_MULTI, $F2 SCSI RESET, $F4 UNIT RDY, $F6 REZERO UNIT,
; $F8/$FA START/STOP UNIT, $FC/$FE RD/WRT_PHYS_MULTI.
; The manual lists $84-$8E, $92, $9C, $9E, $A0, $A2, $A8, $B0, $B8, $F0
; and $F4 as 'not implemented (returns OK)'.  In this version $A8, $B8
; and $F4 do have handlers (SCSI seek and test unit ready).
job_codes                               ; $E944
        !byte $80,$90,$A0,$B0,$C0,$D0,$E0,$F0 ; $E944
        !byte $82,$84,$86,$88,$8A,$8C,$8E,$92 ; $E94C
        !byte $94,$96,$98,$9A,$9C,$9E,$A2,$A4 ; $E954
        !byte $A6,$A8,$AA,$AC,$B2,$B4,$B6,$B8 ; $E95C
        !byte $CC,$CE,$EC,$EE,$F2,$F4,$F6,$F8 ; $E964
        !byte $FA,$FC,$FE               ; $E96C

; Handlers in the order of job_codes.
job_handlers                            ; $E96F
        !word job_read                  ; $E96F
        !word job_write                 ; $E971
        !word job_verify                ; $E973
        !word job_no_op                 ; $E975
        !word job_restore               ; $E977
        !word job_execute               ; $E979
        !word job_execute               ; $E97B
        !word job_buffer_only           ; $E97D
        !word job_reset                 ; $E97F
        !word job_no_op                 ; $E981
        !word job_no_op                 ; $E983
        !word job_no_op                 ; $E985
        !word job_no_op                 ; $E987
        !word job_no_op                 ; $E989
        !word job_no_op                 ; $E98B
        !word job_no_op                 ; $E98D
        !word led_activity_on           ; $E98F
        !word led_activity_off          ; $E991
        !word led_error_on              ; $E993
        !word led_error_off             ; $E995
        !word job_no_op                 ; $E997
        !word job_no_op                 ; $E999
        !word job_no_op                 ; $E99B
        !word job_read_boot             ; $E99D
        !word job_write_boot            ; $E99F
        !word job_seek                  ; $E9A1
        !word job_read_cached           ; $E9A3
        !word job_write_half            ; $E9A5
        !word job_read_physical         ; $E9A7
        !word job_write_physical        ; $E9A9
        !word job_write_protect         ; $E9AB
        !word job_seek_track            ; $E9AD
        !word job_read_to_ptr           ; $E9AF
        !word job_write_from_ptr        ; $E9B1
        !word job_read_blocks_raw       ; $E9B3
        !word job_write_blocks_raw      ; $E9B5
        !word job_scsi_reset            ; $E9B7
        !word job_test_ready            ; $E9B9
        !word job_rezero                ; $E9BB
        !word job_unit_start            ; $E9BD
        !word job_unit_stop             ; $E9BF
        !word job_read_blocks           ; $E9C1
        !word job_write_blocks          ; $E9C3

; Translate without the partition type conversion (job_to_block is the
; normal entry).
job_to_block_raw                        ; $E9C5
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction

; Jump table slot jt_job_to_block: convert the job's track and sector into a
; block offset inside the current partition (by partition type), check
; it against the partition size, add the partition start and map the
; result to a physical device.  Out: carry set and A = $C0 when the
; block is illegal.
job_to_block                            ; $E9C7
        clc
        ror addr_raw_flag
        jsr job_fetch_header

jtb_convert                             ; $E9CE
        jsr job_partition
        jsr ts_convert
        bcc jtb_check_size
jtb_illegal                             ; $E9D6
        lda #$C0                        ; result $C0: illegal block
        sec
        rts

jtb_check_size                          ; $E9DA
        ldy job_part_num
        lda block_offset_hi             ; offset must be below the partition size
        cmp part_size_hi,y
        bcc jtb_add_start
        bne jtb_illegal
        lda block_offset_lo
        cmp part_size_lo,y
        bcs jtb_illegal
jtb_add_start                           ; $E9EF
        clc                             ; add the partition start
        lda block_offset_lo
        adc part_start_lo,y
        sta block_abs+2
        lda block_offset_hi
        adc part_start_mid,y
        sta block_abs+1
        lda #$00
        adc part_start_hi,y
        sta block_abs

; Find the SCSI device that holds absolute block block_abs-block_abs+2 and
; store device ID, LUN and the block address on that device in the
; job's tables.
block_to_device                         ; $EA0A
        ldy #$FF
btd_next                                ; $EA0C
        iny                             ; find the device whose range contains the block
        lda block_abs
        cmp cfg_dev_start_hi,y
        bcc btd_found
        bne btd_next
        lda block_abs+1
        cmp cfg_dev_start_mid,y
        bcc btd_found
        bne btd_next
        lda block_abs+2
        cmp cfg_dev_start_lo,y
        bcs btd_next
btd_found                               ; $EA29
        dey
        lda cfg_device_tab,y            ; bit 7: device not present
        bmi jtb_illegal
        ldx job_buffer
        jsr device_set_id
        sec                             ; block address relative to the device
        lda block_abs+2
        sbc cfg_dev_start_lo,y
        sta job_block_lo,x
        lda block_abs+1
        sbc cfg_dev_start_mid,y
        sta job_block_mid,x
        lda block_abs
        sbc cfg_dev_start_hi,y
        sta job_block_hi,x

; Point buf_ptr/buf_ptr+1 at the buffer of the job (page 3 + buffer number).
job_buffer_ptr                          ; $EA51
        lda #$00
        sta buf_ptr
        lda job_buffer
        clc
        adc #$03
        sta buf_ptr+1
        clc
jbp_rts                                 ; $EA5E
        rts

; Split device descriptor A into SCSI ID (bits 4-6) and LUN (bits 0-2).
device_set_id                           ; $EA5F
        pha
        and #$07
        sta job_scsi_lun,x
        pla
        lsr
        lsr
        lsr
        lsr
        and #$07
        sta job_scsi_id,x
        rts

; Out: X = job buffer, Y = current partition.
job_partition                           ; $EA70
        ldx job_buffer
        lda cur_partition
        sta job_part_num
        tay
        rts

; Fetch track, sector and side of the job into the work variables.
job_fetch_header                        ; $EA7B
        lda job_buffer
        asl
        tax
        lda job_track,x
        sta job_cur_track
        lda job_sector,x
        sta job_cur_sector
        lda job_side,x
        sta job_cur_side
        rts

; Convert track/sector to a sector offset with the routine for the
; partition's type.
ts_convert                              ; $EA93
        ldy job_part_num
        lda part_type,y                 ; partition type
        beq jbp_rts
        cmp #$FF                        ; $FF = system partition
        bne tsc_dispatch
        lda #$00
tsc_dispatch                            ; $EAA1
        asl
        tax
        lda ts_convert_tab,x
        sta job_vector
        lda ts_convert_tab+1,x
        sta job_vector+1
        bit addr_raw_flag               ; bit 7 of addr_raw_flag: raw / physical addressing
        jmp (job_vector)

; Converters by partition type 0-7: system, native, 1541, 1571, 1581,
; 1581 CP/M, system, system.
ts_convert_tab                          ; $EAB3
        !word ts_system                 ; $EAB3
        !word ts_native                 ; $EAB5
        !word ts_1541                   ; $EAB7
        !word ts_1571                   ; $EAB9
        !word ts_1581                   ; $EABB
        !word ts_1581_cpm               ; $EABD
        !word ts_system                 ; $EABF
        !word ts_system                 ; $EAC1

; 1541/1571 speed zones: first track of each zone (both sides).
zone_first_track                        ; $EAC3
        !byte $01,$12,$19,$1F,$24,$35,$3C,$42 ; $EAC3
        !byte $47                       ; $EACB

; Sector offset of each zone start, high byte.
zone_offset_hi                          ; $EACC
        !byte $00,$01,$01,$02,$02,$04,$04,$05 ; $EACC

; Sector offset of each zone start, low byte.
zone_offset_lo                          ; $EAD4
        !byte $00,$65,$EA,$56,$AB,$10,$95,$01 ; $EAD4

; Sectors per track in each zone: 21, 19, 18, 17.
zone_sectors                            ; $EADC
        !byte $15,$13,$12,$11,$15,$13,$12,$11 ; $EADC

; System partition: track = offset high, sector = offset low.
ts_system                               ; $EAE4
        bmi ts_raw
        lda job_cur_track
ts_native_calc                          ; $EAE9
        jsr ts_store
        jmp ts_halve
ts_raw                                  ; $EAEF
        lda job_cur_track

ts_store                                ; $EAF2
        sta block_offset_hi
        lda job_cur_sector
        sta block_offset_lo
        clc
        rts

; Native: (track - 1) * 256 + sector.
ts_native                               ; $EAFD
        bmi ts_raw
        ldx job_cur_track
        beq ts_illegal
        dex
        txa
        jmp ts_native_calc

; 1541: tracks 1-35 with zoned sector counts.
ts_1541                                 ; $EB09
        bmi ts_illegal
        lda job_cur_track
        beq ts_illegal
        cmp #$24
        bcc ts_zoned
ts_illegal                              ; $EB14
        sec
        rts

; 1571: tracks 1-70.
ts_1571                                 ; $EB16
        bmi ts_illegal
        lda job_cur_track
        beq ts_illegal
        cmp #$47
        bcs ts_illegal
ts_zoned                                ; $EB21
        ldx #$00
tsz_find                                ; $EB23
        cmp zone_first_track,x          ; find the zone of the track
        bcc tsz_calc
        inx
        bne tsz_find
tsz_calc                                ; $EB2B
        dex
        lda zone_sectors,x              ; sector must exist in this zone
        cmp job_cur_sector
        beq ts_illegal
        bcc ts_illegal
        sta mul_count
        txa
        pha
        lda job_cur_track               ; tracks into the zone * sectors per track
        sec
        sbc zone_first_track,x
        jsr sum_multiply
        pla
        tay
        ldx zone_offset_hi,y            ; plus the offset of the zone
        lda zone_offset_lo,y
        ldy #$00
        jsr sum_add_axy
        lda job_cur_sector
        jmp ts_add_sector

; 1581 CP/M: a read of track 1 sector 0 is redirected to 40/5 (?),
; otherwise as 1581.
ts_1581_cpm                             ; $EB58
        bmi ts_1581_physical
        lda job_current
        cmp #$80
        bne ts_1581_calc
        lda job_cur_track
        cmp #$01
        bne ts_1581_calc
        lda job_cur_sector
        bne ts_1581_calc
        lda #$28
        sta job_cur_track
        lda #$05
        sta job_cur_sector
        bne ts_1581_calc

; 1581: (track - 1) * 40 + sector; physical addressing uses 20
; sectors per cylinder.
ts_1581                                 ; $EB79
        bmi ts_1581_physical
ts_1581_calc                            ; $EB7B
        lda #$28
        sta mul_count
        ldx job_cur_track
        beq ts_illegal_2
        dex
        txa
        jsr sum_multiply
        lda job_cur_sector
        cmp #$28
        bcs ts_illegal_2
ts_add_sector                           ; $EB91
        jsr ts_add_and_store
ts_halve                                ; $EB94
        lsr block_offset_hi             ; two 256-byte sectors per 512-byte block
        ror block_offset_lo
        ror half_block_flag             ; bit 7 of half_block_flag: second half
        clc
        rts
ts_illegal_2                            ; $EB9F
        sec
        rts
ts_1581_physical                        ; $EBA1
        lda job_cur_track
        cmp #$50
        bcs ts_illegal_2
        lda #$14                        ; 20 sectors per cylinder
        sta mul_count
        lda job_cur_track
        jsr sum_multiply
        ldx job_cur_sector
        dex
        txa
        cmp #$0A                        ; sectors 1-10
        bcs ts_illegal_2
        ldx job_cur_side                ; second side
        beq ts_add_and_store
        clc
        adc #$0A

ts_add_and_store                        ; $EBC4
        jsr sum_add_a
        lda block_abs+2
        sta block_offset_lo
        lda block_abs+1
        sta block_offset_hi
        clc
        rts

; Clear the 24-bit sum block_abs-block_abs+2.
sum_clear                               ; $EBD5
        lda #$00
        sta block_abs+2
        sta block_abs+1
        sta block_abs
        rts

; Add A (sum_add_axy: A, X, Y as low/middle/high) to the sum.
sum_add_a                               ; $EBE1
        ldx #$00
        ldy #$00

; Add the 24-bit value A / X / Y to the sum.
sum_add_axy                             ; $EBE5
        clc
        pha
        adc block_abs+2
        sta block_abs+2
        txa
        adc block_abs+1
        sta block_abs+1
        tya
        adc block_abs
        sta block_abs
sum_rts                                 ; $EBFB
        pla
        rts

; Sum = A * mul_count.
sum_multiply                            ; $EBFD
        ldx #$00
        ldy #$00
        pha
        jsr sum_clear
        lda mul_count
        beq sum_rts
        pla
smu_loop                                ; $EC0B
        jsr sum_add_axy
        dec mul_count
        bne smu_loop
        rts

; Store the job result.  A SCSI CHECK CONDITION is resolved with
; REQUEST SENSE; a recovered error counts as success.  The result is
; mapped to a job status by scsi_result_codes/job_status_codes and on failure the sense
; data are kept in the job's block address fields for the message.
job_finish                              ; $EC14
        cmp #$02                        ; status 2 = CHECK CONDITION
        bne jfn_map
        jsr scsi_request_sense
        cmp #$00
        bne jfn_map
        lda scsi_sense+2                ; sense key
        and #$0F
        cmp #$01                        ; 1 = recovered error
        beq jfn_ok
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
jfn_ok                                  ; $EC2B
        lda #$00
jfn_map                                 ; $EC2D
        ldx #$00
jfn_find                                ; $EC2F
        cmp scsi_result_codes,x
        beq jfn_found
        inx
        cpx #$0B
        bcc jfn_find
        lda #$0D                        ; unknown: job status $0D
        bne jfn_store
jfn_found                               ; $EC3D
        lda job_status_codes,x
jfn_store                               ; $EC40
        ldx job_buffer
        cmp #$00
        beq jfn_set
        pha
        lda scsi_sense                  ; keep the sense data for the message
        sta job_block_hi,x
        lda scsi_sense+2
        sta job_block_mid,x
        lda scsi_sense+12
        sta job_block_lo,x
        pla
jfn_set                                 ; $EC5B
        sta job_queue,x
        rts

; Internal result codes ...
scsi_result_codes                       ; $EC5E
        !byte $00,$02,$08,$10,$18,$85,$86,$87 ; $EC5E
        !byte $C0,$C1,$C3               ; $EC66

; ... and the job status each one becomes.
job_status_codes                        ; $EC69
        !byte $00,$02,$03,$0B,$0C,$05,$06,$07 ; $EC69
        !byte $04,$0E,$08               ; $EC71

; Job $82 reset: start the 20 ms timer that drives the job queue,
; invalidate the block cache and build the parity table.
job_reset                               ; $EC74
        lda #$20                        ; timer 1 = $4E20 cycles
        sta $8006
        lda #$4E
        sta $8007
        sta $8005
        lda via1_acr                    ; free running
        ora #$40
        sta via1_acr
        lda #$FF                        ; cache holds nothing
        sta cache_scsi_id
        lda #$19
        sta led_blink_timer
        lda #$01
        sta job_retries
        jsr parity_table_build
        lda #$00
        rts

; Jobs $CC / $CE: read / write one sector to or from the address in
; the job's pointer tables instead of its buffer.
job_read_to_ptr                         ; $EC9E
        jsr job_to_block
        bcs jrc_rts
        jsr job_data_ptr
        jmp jrd_cached

; Job $CE: write from an arbitrary address.
job_write_from_ptr                      ; $ECA9
        jsr job_to_block
        bcs jrc_rts
        jsr job_data_ptr
        jmp jwr_cached

; Point buf_ptr/buf_ptr+1 at the address given for the job.
job_data_ptr                            ; $ECB4
        ldx job_buffer
        lda job_ptr_lo,x
        sta buf_ptr
        lda job_ptr_hi,x
        sta buf_ptr+1
        rts

; Job $AA: read the 512-byte disk block of the sector into the block
; cache without copying it to the buffer.
job_read_cached                         ; $ECC2
        jsr job_to_block
        bcs jrc_rts
        jsr cache_test
        beq jrc_hit

jrc_read                                ; $ECCC
        lda #$28                        ; $28 = READ(10)
jrc_command                             ; $ECCE
        jsr block_transfer
        bne jrc_rts
jrc_hit                                 ; $ECD3
        jsr data_ptr_half
        lda #$00
jrc_rts                                 ; $ECD8
        rts

; Job $AC: write the cached half block back, preserving the other
; half through the work buffer.
job_write_half                          ; $ECD9
        jsr job_to_block
        bcs jrc_rts
        jsr data_ptr_half
        jsr cache_test
        beq jwh_write
        ldy #$00
jwh_save                                ; $ECE8
        lda (data_ptr),y
        sta work_block,y
        iny
        bne jwh_save
        jsr jrc_read
        cmp #$00
        bne jrc_rts
        ldy #$00
jwh_restore                             ; $ECF9
        lda work_block,y
        sta (data_ptr),y
        iny
        bne jwh_restore
jwh_write                               ; $ED01
        lda #$2A                        ; $2A = WRITE(10)
        bne jrc_command

; Job $80 read: fetch the 512-byte block (unless it is the one in the
; cache) and copy the wanted 256-byte half to the job's buffer.
job_read                                ; $ED05
        jsr job_to_block
        bcs jrd_rts
jrd_cached                              ; $ED0A
        jsr cache_test
        beq jrd_copy
        lda #$28
        jsr block_transfer
        bne jrd_rts
jrd_copy                                ; $ED16
        jsr data_ptr_half
jrd_loop                                ; $ED19
        lda (data_ptr),y
        sta (buf_ptr),y
        iny
        bne jrd_loop

; Jobs without a function on a hard disk: report success.
job_no_op                               ; $ED20
        lda #$00
jrd_rts                                 ; $ED22
        rts

; Job $90 write: merge the buffer into the cached 512-byte block and
; write the block.
job_write                               ; $ED23
        jsr job_to_block
        bcs jvf_rts

jwr_cached                              ; $ED28
        jsr cache_test
        beq jwr_copy
        lda #$28
        jsr block_transfer
        bne jvf_rts

jwr_copy                                ; $ED34
        jsr data_ptr_half
jwr_loop                                ; $ED37
        lda (buf_ptr),y
        sta (data_ptr),y
        iny
        bne jwr_loop
        lda #$2A
        jmp block_transfer

; Job $A0 verify: only checks the block address.
job_verify                              ; $ED43
        jsr job_to_block
        bcs jvf_rts
        lda #$00
jvf_rts                                 ; $ED4A
        rts

; Job $B8: seek to the track of the job.
job_seek_track                          ; $ED4B
        jsr job_fetch_header
        lda #$00
        sta job_cur_sector
        lsr addr_raw_flag
        jsr jtb_convert
        bcc jsk_command
jsk_rts                                 ; $ED5B
        rts

; Job $A8: SCSI SEEK to the job's block.
job_seek                                ; $ED5C
        jsr job_to_block_raw
        bcs jsk_rts
jsk_command                             ; $ED61
        lda #$2B                        ; $2B = SEEK(10)
        ldy #$00
        jmp scsi_command_10

; Job $C0 restore: seek to the first block of the partition.
job_restore                             ; $ED68
        jsr job_partition
        lda #$00
        sta block_offset_hi
        sta block_offset_lo
        jsr jtb_check_size
        bcc jsk_command
        rts

; Jobs $D0 / $E0: execute the code in the job's buffer.
job_execute                             ; $ED79
        jsr job_buffer_ptr
        jmp (buf_ptr)                   ; run the buffer

; Job $F0: set up the buffer pointer only.
job_buffer_only                         ; $ED7F
        jsr job_buffer_ptr
        lda #$00
        rts

; Jobs $A4 / $A6: read / write one block with buffer 0 ($0300).
job_read_boot                           ; $ED85
        jsr job_ptr_buffer0_page
        jmp job_read_blocks

job_ptr_buffer0_page                    ; $ED8B
        ldx job_buffer
        lda #$03
        sta job_ptr_hi,x
        lda #$00
        sta job_ptr_lo,x
        lda #$01
        sta job_block_count,x
        rts

; Job $A6: write variant.
job_write_boot                          ; $ED9E
        jsr job_ptr_buffer0_page

; Jobs $EC / $EE and $FC / $FE: transfer job_block_count whole 512-byte blocks
; to or from the job's target address.  As coded, $EC/$EE take an
; absolute block address from the header and side fields, while $FC/$FE
; address a block inside the current partition without track/sector
; conversion.  The manual names them the other way round ($EC/$EE
; 'system blocks', $FC/$FE 'physical blocks').
job_write_blocks_raw                    ; $EDA1
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
job_read_blocks_raw                     ; $EDA4
        ldy #$28
        sec
        bcs job_blocks

job_write_blocks                        ; $EDA9
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
job_read_blocks                         ; $EDAC
        ldy #$28
        clc
job_blocks                              ; $EDAF
        ldx job_buffer
        lda job_ptr_hi,x
        pha
        lda job_ptr_lo,x
        pha
        tya
        pha
        lda job_block_count,x
        pha
        bcc jbl_translate
        lda job_side,x
        sta block_abs+2
        txa
        asl
        tax
        lda job_sector,x
        sta block_abs+1
        lda job_track,x
        sta block_abs
        jsr block_to_device
        jmp jbl_check
jbl_translate                           ; $EDDD
        jsr job_to_block_raw
jbl_check                               ; $EDE0
        bcc jbl_go
        pla
        pla
        pla
        pla
        lda #$C0                        ; result $C0
        rts
jbl_go                                  ; $EDE9
        pla
        tay
        pla
        sec
        jsr cdb_build_10
        pla
        sta data_ptr
        pla
        sta data_ptr+1
        jmp scsi_run

; Jobs $B2 / $B4: read / write a whole 512-byte block via the cache
; buffer at block_cache (1581 physical sectors).
job_read_physical                       ; $EDF9
        jsr job_to_block_raw
        bcs jph_rts
        lda #$28
        bne jph_command

job_write_physical                      ; $EE02
        jsr job_to_block_raw
        bcs jph_rts
        lda #$2A
jph_command                             ; $EE09
        jsr block_transfer
        bne jph_rts
        jsr data_ptr_cache
        lda #$00
jph_rts                                 ; $EE13
        rts

; Jobs $F8 / $FA: SCSI START STOP UNIT (start / stop).
job_unit_start                          ; $EE14
        ldy #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
job_unit_stop                           ; $EE17
        ldy #$00
        lda #$00
        ldx job_buffer
        sta job_block_hi,x
        sta job_block_mid,x
        sta job_block_lo,x
        lda #$1B                        ; $1B = START STOP UNIT
        jmp cdb6_run_block

; LED control: error LED on / activity on / error off / activity off,
; chained with BIT skips.  led_error_on also notes error 50 as pending (?).
led_error_on                            ; $EE2C
        lda #$50
        sta cmd_error_code
        lda #$32
        sta led_blink_timer
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_geos_on                             ; $EE39
        lda #$40
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_activity_on                         ; $EE3C
        lda #$01
        ora panel_state
        bne led_store

led_error_off                           ; $EE42
        lda #$00
        sta cmd_error_code
        lda #$FD
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_geos_off                            ; $EE4A
        lda #$BF
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_activity_off                        ; $EE4D
        lda #$FE
        and panel_state
led_store                               ; $EE51
        sta panel_state
led_ok                                  ; $EE53
        lda #$00
        rts

; Job $B6: detect write protect - status $C3 when protected.
job_write_protect                       ; $EE56
        lda #$80
        and panel_state
        beq led_ok
        lda #$C3                        ; result $C3
        rts

; Data pointer = block cache at block_cache.
data_ptr_cache                          ; $EE5F
        ldy #$00
        sty data_ptr
        lda #$50
        sta data_ptr+1
        rts

; Data pointer = the half of the block cache that holds the sector
; (block_cache or $5100).
data_ptr_half                           ; $EE68
        ldy #$00
        sty data_ptr
        lda #$50
        sta data_ptr+1
        bit half_block_flag             ; second half of the block?
        bpl dph_rts
        inc data_ptr+1
dph_rts                                 ; $EE77
        rts

; Out: Z set when the job's device and block are the ones in the
; block cache.
cache_test                              ; $EE78
        ldx job_buffer
        lda job_scsi_id,x
        cmp cache_scsi_id
        bne cht_rts
        lda job_scsi_lun,x
        cmp cache_scsi_id+1
        bne cht_rts
        lda job_block_hi,x
        cmp cache_scsi_id+2
        bne cht_rts
        lda job_block_mid,x
        cmp cache_scsi_id+3
        bne cht_rts
        lda job_block_lo,x
        cmp cache_scsi_id+4
cht_rts                                 ; $EEA1
        rts

; Build a 6-byte command block: opcode A, length/flag Y, LUN, and
; with carry set the job's block address.
cdb_build_6                             ; $EEA2
        php
        pha
        jsr cdb_clear
        pla
        sta scsi_cdb
        lda #$00
        ldx job_buffer
        sty scsi_cdb+4
        plp
        bcc cb6_lun
        lda job_block_lo,x
        sta scsi_cdb+3
        lda job_block_mid,x
        sta scsi_cdb+2
        lda job_block_hi,x
cb6_lun                                 ; $EEC5
        sta scsi_cdb+1
        lda job_scsi_lun,x              ; LUN into bits 5-7 of byte 1
        asl
        asl
        asl
        asl
        asl
        ora scsi_cdb+1
        sta scsi_cdb+1
        rts

; Clear the command block area and reset the SCSI pointers.
cdb_clear                               ; $EED7
        lda #$00
        ldx #$4F
cdc_loop                                ; $EEDB
        sta scsi_cdb,x
        dex
        bpl cdc_loop

; Reset the pointers for command, status and message bytes and the
; data pointer (block cache).
scsi_ptrs_reset                         ; $EEE1
        ldx #$FF
        stx scsi_status
        stx scsi_message
        lda #$00                        ; command bytes come from scsi_cdb
        sta scsi_cmd_ptr
        lda #$2A
        sta scsi_cmd_ptr+1
        lda #$10                        ; status byte goes to scsi_status
        sta scsi_status_ptr
        lda #$2A
        sta scsi_status_ptr+1
        lda #$30                        ; message byte goes to scsi_message
        sta scsi_msg_ptr
        lda #$2A
        sta scsi_msg_ptr+1
        lda #$00
        sta data_ptr
        lda #$50
        sta data_ptr+1
        rts

; Run 10-byte command A (READ $28 / WRITE $2A) for one block and note
; the block as cached.
block_transfer                          ; $EF0A
        ldx #$FF                        ; invalidate the cache during the transfer
        stx cache_scsi_id
        ldy #$01
        jsr scsi_command_10
        bne btr_done

; Remember device and block of the job as the cache contents.
cache_note                              ; $EF16
        ldx job_buffer
        lda job_scsi_id,x
        sta cache_scsi_id
        lda job_scsi_lun,x
        sta cache_scsi_id+1
        lda job_block_hi,x
        sta cache_scsi_id+2
        lda job_block_mid,x
        sta cache_scsi_id+3
        lda job_block_lo,x
        sta cache_scsi_id+4
        lda #$00
btr_done                                ; $EF39
        jmp srn_status

; Build and run a 10-byte command A with transfer length Y.
scsi_command_10                         ; $EF3C
        jsr cdb_build_10
        jmp scsi_run

; Build a 10-byte command block: opcode A, block address, length Y.
cdb_build_10                            ; $EF42
        pha
        jsr cdb_clear
        pla
        ldx job_buffer
        sta scsi_cdb
        sty scsi_cdb+8
        lda job_block_lo,x
        sta scsi_cdb+5
        lda job_block_mid,x
        sta scsi_cdb+4
        lda job_block_hi,x
        sta scsi_cdb+3
        lda job_scsi_lun,x
        asl
        asl
        asl
        asl
        asl
        ora scsi_cdb+1
        sta scsi_cdb+1
        rts

; Jobs $F6 / $F4: REZERO UNIT / TEST UNIT READY.
job_rezero                              ; $EF71
        lda #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
job_test_ready                          ; $EF74
        lda #$00
        ldy #$00
        clc
        bcc cdb6_run
dead_cdb_entry                          ; $EF7B
        ldy #$01
cdb6_run_block                          ; $EF7D
        sec
cdb6_run                                ; $EF7E
        jsr cdb_build_6

; Run the prepared command: refuse writes when write protected
; (result $C3), select the device (result $85 if it does not answer),
; serve the bus phases and return the status byte.
; Out: A = scsi_status, Z set on GOOD.
scsi_run                                ; $EF81
        lda scsi_cdb
        cmp #$0A                        ; $0A / $2A: write commands
        beq srn_write_check
        cmp #$2A
        bne srn_select
srn_write_check                         ; $EF8C
        lda #$80                        ; write protected?
        and panel_state
        beq srn_select
        lda #$C3
        jmp srn_status
srn_select                              ; $EF97
        ldx job_buffer
        lda job_scsi_id,x
        jsr scsi_select
        bne srn_phases
        lda #$85                        ; result $85: selection failed
        jmp srn_status

srn_phases                              ; $EFA7
        jsr scsi_phase_loop
        cmp #$00
        bne srn_status
        lda scsi_status
srn_status                              ; $EFB1
        sta scsi_status
        cmp #$00
        rts

; REQUEST SENSE into scsi_sense.
scsi_request_sense                      ; $EFB7
        lda #$03                        ; $03 = REQUEST SENSE, 27 bytes
        ldy #$1B
        clc
        jsr cdb_build_6
        lda #$11
        sta data_ptr
        lda #$2A
        sta data_ptr+1
        jmp scsi_run
scsi_parity_idle                        ; $EFCA
        lda ctl_latch
        and #$EF
        sta ctl_latch

; Serve the SCSI bus until the target drops BSY: on each REQ branch on
; the phase lines to data out, data in, command, status or message in.
; Port B of VIA #2 (confirmed by the schematic): b7 REQ, b6 ACK IN,
; b5 BSY, b4 SEL OUT, b3 BDIRIN (data bus direction), b2 I/O, b1 MSG,
; b0 C/D.  ACK is generated by the CA2 handshake output.
scsi_phase_loop                         ; $EFD2
        lda #$20
spl_wait                                ; $EFD4
        bit via2_prb                    ; previous ACK still pending?
        bvs spl_wait
        bmi spl_request                 ; REQ?
        bne spl_wait                    ; BSY gone: command complete
        jsr scsi_bus_release
        lda #$00
        rts
spl_request                             ; $EFE3
        beq spl_lost_busy
        lda via2_prb                    ; phase lines
        and #$07
        cmp #$00
        bne spl_chk_data_in
        jmp scsi_data_out
spl_chk_data_in                         ; $EFF1
        cmp #$04
        bne spl_chk_command
        jmp scsi_data_in
spl_chk_command                         ; $EFF8
        cmp #$01
        bne spl_chk_status
        jmp scsi_command_out
spl_chk_status                          ; $EFFF
        cmp #$05
        bne spl_chk_message
        jmp scsi_status_in
spl_chk_message                         ; $F006
        cmp #$07
        bne spl_bad_phase
        jmp scsi_message_in
spl_bad_phase                           ; $F00D
        lda #$87                        ; result $87 / $86: unexpected phase / bus lost
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
spl_lost_busy                           ; $F010
        lda #$86
spl_abort                               ; $F012
        pha
        jsr job_scsi_reset
        pla
        rts

; DATA OUT phase: send bytes from (data_ptr) with automatic handshake.
; Data are inverted on the bus; the parity bit goes to bit 4 of the
; control latch, looked up in parity_table.
scsi_data_out                           ; $F018
        ldy data_ptr
        lda #$00
        sta data_ptr
        lda #$FF                        ; data lines to output
        sta via2_ddra
        lda #$A0
        sta via2_prb
sdo_byte                                ; $F028
        lda via2_prb                    ; still DATA OUT with REQ?
        cmp #$A0
        bne sdx_end
        lda (data_ptr),y
        eor #$FF                        ; data are inverted on the bus
        tax
        lda ctl_latch                   ; parity bit
        and #$EF
        ora parity_table,x
        sta ctl_latch
        stx via2_pra
        iny
        bne sdo_byte
        inc data_ptr+1
        jmp sdo_byte
sdx_end                                 ; $F04A
        sty data_ptr
        jmp scsi_parity_idle

; DATA IN phase: receive bytes to (data_ptr).
scsi_data_in                            ; $F04F
        ldy data_ptr
        lda #$00
        sta data_ptr
        sta via2_ddra                   ; data lines to input
        lda #$AC
        sta via2_prb
sdi_byte                                ; $F05D
        lda via2_prb
        cmp #$AC
        bne sdx_end
        lda via2_pra
        eor #$FF
        sta (data_ptr),y
        iny
        bne sdi_byte
        inc data_ptr+1
        jmp sdi_byte

; COMMAND phase: send the command block byte by byte.
scsi_command_out                        ; $F073
        ora #$20
        ldy #$FF
        sty via2_ddra
        iny
        sta via2_prb
        sta scsi_phase
sco_wait                                ; $F081
        bit via2_prb
        bvs sco_wait
        lda scsi_phase
sco_req                                 ; $F089
        cmp via2_prb
        beq sco_req
        ora #$80
        cmp via2_prb
        bne scsi_phase_done
        lda (scsi_cmd_ptr),y
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora parity_table,x
        sta ctl_latch
        stx via2_pra
        inc scsi_cmd_ptr
        bne sco_wait
        inc scsi_cmd_ptr+1
        jmp sco_wait
scsi_phase_done                         ; $F0B1
        jmp scsi_parity_idle

; STATUS phase: read the status byte.
scsi_status_in                          ; $F0B4
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta scsi_phase
ssi_wait                                ; $F0C1
        bit via2_prb
        bvs ssi_wait
        lda scsi_phase
ssi_req                                 ; $F0C9
        cmp via2_prb
        beq ssi_req
        ora #$80
        cmp via2_prb
        bne scsi_phase_done
        lda via2_pra
        eor #$FF
        sta (scsi_status_ptr),y
        inc scsi_status_ptr
        bne ssi_wait
        inc scsi_status_ptr+1
        jmp ssi_wait

; MESSAGE IN phase: read the message byte.
scsi_message_in                         ; $F0E5
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta scsi_phase
smi_wait                                ; $F0F2
        bit via2_prb
        bvs smi_wait
        lda scsi_phase
smi_req                                 ; $F0FA
        cmp via2_prb
        beq smi_req
        ora #$80
        cmp via2_prb
        bne scsi_phase_done
        lda via2_pra
        eor #$FF
        sta (scsi_msg_ptr),y
        inc scsi_msg_ptr
        bne smi_wait
        inc scsi_msg_ptr+1
        jmp smi_wait

; Release the SCSI bus: data lines input, control lines idle.
scsi_bus_release                        ; $F116
        lda #$DB                        ; handshake lines to manual
        sta via2_pcr
        lda #$00
        sta via2_ddra
        lda #$08
        sta via2_prb
        lda ppi_pc                      ; SCSI ATN, RST and BSY outputs off
        and #$E3
        sta ppi_pc
        lda ctl_latch
        and #$EF
        sta ctl_latch
        rts

; Job $F2: pulse the SCSI RST OUT line (8255 port C bit 3).
job_scsi_reset                          ; $F136
        jsr scsi_bus_release
        lda ppi_pc                      ; SCSI RST OUT
        ora #$08
        sta ppi_pc
        ldx #$28
jsr_delay                               ; $F143
        dex
        bne jsr_delay
        and #$F7
        sta ppi_pc
        lda #$00
        rts

; Select SCSI device A: wait for a free bus, put the target's and our
; own ID bit on the data lines, assert SEL and wait for BSY.
; Out: Z set when the device does not respond.
scsi_select                             ; $F14E
        php
        sei
        tax
ssl_wait_free                           ; $F151
        lda #$20                        ; wait for BSY to clear
        and via2_prb
        beq loc_F15A
        bne ssl_wait_free
loc_F15A
        sec                             ; bit mask of the target ID
ssl_id_bit                              ; $F15B
        rol
        dex
        bpl ssl_id_bit
        ldx #$FF
        stx via2_ddra
        ora cfg_own_id_mask             ; plus our own ID
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora parity_table,x
        sta ctl_latch
        stx via2_pra
        lda #$00
        sta via2_prb
        lda #$FB                        ; assert SEL
        ldx #$10
        sta via2_pcr
        stx via2_prb
        ldx #$00
        ldy #$00
ssl_wait_busy                           ; $F18B
        lda via2_prb                    ; wait for the target's BSY
        and #$20
        bne ssl_end
        dex
        bne ssl_wait_busy
        dey
        bne ssl_wait_busy
        lda #$DB
        sta via2_pcr
        ldx #$54
loc_F19F
        dex
        bne loc_F19F
        lda via2_prb
        and #$20
ssl_end                                 ; $F1A7
        ldx #$08                        ; release SEL
        stx via2_prb
        ldx #$DB
        stx via2_pcr
        plp
        tax
        bne ssl_rts
        jsr scsi_bus_release
        ldx #$00
ssl_rts                                 ; $F1BA
        rts

; Build the 256-byte parity table at parity_table from the nibble table.
parity_table_build                      ; $F1BB
        php
        sei
        jsr ram_unprotect_save
        ldx #$00
ptb_loop                                ; $F1C2
        txa
        sta block_abs+2
        lsr
        lsr
        lsr
        lsr
        eor block_abs+2
        and #$0F
        tay
        lda parity_nibbles,y
        sta parity_table,x
        inx
        bne ptb_loop
        jsr ram_protect_restore
        plp
        rts

; Parity bit ($10) for each value of high nibble XOR low nibble.
parity_nibbles                          ; $F1DE
        !byte $10,$00,$00,$10,$00,$10,$10,$00 ; $F1DE
        !byte $00,$10,$10,$00,$10,$00,$00,$10 ; $F1E6

; The drive acting as bus controller: pull ATN and send LISTEN for
; device A (ctl_send_atn_byte: send byte A under ATN).
ctl_send_listen                         ; $F1EE
        ora #$20

ctl_send_atn_byte                       ; $F1F0
        pha
        sei
        jsr serial_data_release         ; release DATA
        lda #$00
        sta via1_prb
        lda #$7A                        ; DDR $7A: ATN OUT (bit 6) becomes an output
        sta via1_ddrb
        pla

; Send secondary address byte A under ATN.
ctl_send_secondary                      ; $F200
        sei
        pha
        jsr serial_clk_assert           ; pull CLK
        jsr serial_data_release
        jsr delay_long_x
        lda #$00
        sta ctl_eoi
        pla

; Send byte A to the addressed device, standard serial protocol.
; Bit 7 of ctl_eoi = signal EOI.  Out: carry set when nobody answers.
ctl_send_byte                           ; $F211
        sei
        sta ctl_shift
        jsr serial_data_release
        lda via1_prb                    ; does a device answer with DATA?
        and #$01
        beq csb_no_device
        jsr serial_clk_release          ; release CLK: ready to send
        bit ctl_eoi                     ; EOI wanted: wait for the listener's pulse
        bpl csb_ready
        jsr ctl_wait_data_high
        jsr ctl_wait_data_low
csb_ready                               ; $F22D
        jsr ctl_wait_data_high
        txa
        pha
        jsr serial_clk_assert
        ldx #$08                        ; 8 bits
csb_bit                                 ; $F237
        lda #$14
loc_F239
        sbc #$01
        bne loc_F239
        ror ctl_shift                   ; next bit, LSB first
        bcs csb_one
        jsr serial_data_assert
        jmp csb_clock
csb_one                                 ; $F248
        jsr serial_data_release
csb_clock                               ; $F24B
        jsr serial_clk_release          ; release CLK: bit valid
        lda #$14
loc_F250
        sbc #$01
        bne loc_F250
        lda via1_prb                    ; pull CLK, release DATA
        and #$FD
        ora #$08
        sta via1_prb
        dex
        bne csb_bit
        jsr ctl_wait_data_low           ; wait for the acknowledge
        pla
        tax
        clc
        rts
csb_no_device                           ; $F268
        jsr ctl_release_bus
        sec
        rts

; Send UNLISTEN and release the bus.
ctl_unlisten                            ; $F26D
        lda #$3F                        ; $3F = UNLISTEN
        jsr ctl_send_atn_byte

ctl_release_bus                         ; $F272
        jsr ctl_atn_release
        lda #$14
loc_F277
        sbc #$01
        bne loc_F277
        jsr serial_clk_release
        jsr serial_data_release
        clc
        rts

; Send $6F (command channel) and release ATN.
ctl_open_cmd_channel                    ; $F283
        lda #$6F                        ; $6F: channel 15
        jsr ctl_send_secondary

ctl_atn_release                         ; $F288
        lda via1_prb                    ; release ATN, set ATN acknowledge
        ora #$50
        sta via1_prb
        lda #$3A                        ; DDR back to normal
        sta via1_ddrb
ctl_rts                                 ; $F295
        rts

; Tell the device that currently has number A to change its device
; number: send it 'M-W' $77 $00 $02 followed by this drive's old
; LISTEN and TALK addresses, so the two drives trade numbers.
other_drive_renumber                    ; $F296
        jsr ctl_send_listen
        bcs ctl_rts
        jsr ctl_open_cmd_channel
        bcs ctl_rts
        ldx #$00
odr_send                                ; $F2A2
        lda txt_mw_device,x             ; 'M-W' $77 $00 $02
        jsr ctl_send_byte
        inx
        cpx #$06
        bcc odr_send
        lda listen_addr                 ; new LISTEN address for the other drive
        jsr ctl_send_byte
        lda #$80                        ; last byte with EOI
        sta ctl_eoi
        lda talk_addr
        jsr ctl_send_byte
        jmp ctl_unlisten

; M-W to listen_addr, two bytes: the 1541-family device address locations.
txt_mw_device                           ; $F2BF
        !byte $4D,$2D,$57,$77,$00,$02   ; $F2BF

; Delay, A and X preserved.
delay_long_x                            ; $F2C5
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

; Carry out a device number change: undo an active swap, then apply
; the pending request (8 or 9) and light the matching SWAP LED.
swap_apply                              ; $F2D2
        lda cfg_device                  ; bit 7: a swap is active
        bpl swa_request
        and #$7F
        sec
        sbc swap_request
        bne swa_restore
        sta swap_request
swa_restore                             ; $F2E2
        lda panel_state                 ; both SWAP LEDs off
        and #$FB
        and #$F7
        sta panel_state
        lda cfg_default_device          ; back to the default device number
        jsr device_number_set
swa_request                             ; $F2F0
        ldx swap_request                ; swap request pending?
        beq swa_rts
        cpx #$08
        bne swa_nine
        lda #$04                        ; SW8 LED
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
swa_nine                                ; $F2FC
        lda #$08                        ; SW9 LED
        ora panel_state
        sta panel_state
        txa
        ora #$80                        ; bit 7 marks the number as swapped

; Make A the active device number: store it, renumber the other
; drive on the bus and set the LISTEN / TALK addresses.
device_number_set                       ; $F305
        jsr cfg_set_device
        and #$7F
        pha
        jsr other_drive_renumber        ; renumber the drive that had it
        pla
        ora #$20
        sta listen_addr
        eor #$60
        sta talk_addr
swa_rts                                 ; $F317
        rts

; Front panel service, called from the idle loop.  WRITE PROTECT
; button: short press toggles write protect, long press enters the dial
; mode.  SWAP 8 / SWAP 9 buttons and the S-8 / S-9 / S-D commands change
; the device number while the bus is idle.
panel_poll                              ; $F318
        php
        sei
        lda #$08                        ; WRITE PROTECT button, port B bit 3 (active low)
        and ppi_pb
        bne pnl_requests
        jsr button_held                 ; short or long press?
        bcs pnl_dial_mode
        lda #$80                        ; toggle write protect
        eor panel_state
        sta panel_state
        lda #$00
        sta wp_by_software
        jmp pnl_wait_release
pnl_requests                            ; $F334
        bit swap_default                ; S-D pending?
        bmi pnl_do_swap
        lda swap_request                ; S-8 / S-9 pending?
        beq pnl_swap_buttons
        ora #$80
        cmp cfg_device
        beq pnl_wait_release
        bne pnl_do_swap
pnl_swap_buttons                        ; $F347
        lda #$02                        ; SWAP 8 button, port B bit 1
        and ppi_pb
        beq pnl_swap8
        lda #$04                        ; SWAP 9 button, port B bit 2
        and ppi_pb
        bne pnl_done
        lda #$09
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
pnl_swap8                               ; $F358
        lda #$08
        sta swap_request
pnl_do_swap                             ; $F35D
        jsr bus_is_idle                 ; only while the bus is idle
        bne pnl_wait_release
        jsr swap_apply
pnl_wait_release                        ; $F365
        cli
        jsr panel_wait_release
        jsr delay_panel
pnl_done                                ; $F36C
        lda #$00
        sta swap_default
        sta swap_request
        plp
        rts

; Front Panel Partition Selection (FPPS) mode, as the manual calls it:
; entered by holding WRITE PROTECT for about two seconds.  SWAP 8 steps
; the hundreds, SWAP 9 the tens and WRITE PROTECT the ones digit of a
; partition number, shown on the GEOS / SWAP 8 / SWAP 9 / WRITE PROTECT
; lamps.  Holding WRITE PROTECT again leaves the mode and makes that
; partition the current default.
pnl_dial_mode                           ; $F376
        lda panel_state                 ; not while the drive is busy
        bit pnl_const_1+1               ; BIT with the constant 1 in the operand below
        bne pnl_wait_release
        pha
        lda #$00                        ; all digits 0
        sta tmp0
        sta tmp1
        sta tmp2
        sta tmp3
pnl_const_1                             ; $F388
        lda #$01
        sta panel_state
        cli
        pha
dial_wait_release                       ; $F38E
        jsr panel_wait_release
dial_restore                            ; $F391
        pla
        sta panel_state
dial_blink                              ; $F394
        ldx #$FA
dial_poll                               ; $F396
        lda ppi_pb                      ; any button down?
        and #$0E
        eor #$0E
        bne dial_button
        jsr delay_long_x
        dex
        bne dial_poll
        lda panel_state                 ; blink the activity LED
        eor #$01
        sta panel_state
        jmp dial_blink
dial_button                             ; $F3AE
        ldx #$01
        stx panel_state
        pha
        jsr button_held                 ; long press ends the mode
        pla
        bcs dial_finish
        lsr                             ; button number -> digit position
        cmp #$04
        bcc dial_digit
        lda #$03
dial_digit                              ; $F3C0
        tax
        cpx tmp3                        ; same digit again: increment
        stx tmp3
        bne dial_limit
        inc $4F,x
dial_limit                              ; $F3C9
        lda $4F,x
        cmp dat_F423,x                  ; wrap at the digit's limit
        bcs dial_wrap
        jsr dial_value
        bcc dial_show
dial_wrap                               ; $F3D5
        lda #$00
        sta $4F,x
dial_show                               ; $F3D9
        ldy $4F,x
        lda dial_led_patterns,y         ; show the digit
        ora #$01
        pha
        cpx #$03
        bne dial_wait_release
        jsr pwr_loop
        beq dial_restore
dial_finish                             ; $F3EA
        pla
        sta panel_state
        jsr panel_wait_release
        plp
        jsr dial_value                  ; value
        bne dial_select
        lda default_partition           ; zero: keep the default partition
dial_select                             ; $F3F9
        jmp change_partition            ; select the partition

; Out: A = 100 * tmp0 + 10 * tmp1 + tmp2, carry set on overflow.
dial_value                              ; $F3FC
        lda #$00
        clc
        ldy tmp0
dvl_hundreds                            ; $F401
        dey
        bmi dvl_tens_start
        adc #$64
        bne dvl_hundreds
dvl_tens_start                          ; $F408
        ldy tmp1
dvl_tens                                ; $F40A
        dey
        bmi dvl_units
        adc #$0A
        bcs dvl_rts
        bcc dvl_tens
dvl_units                               ; $F413
        adc tmp2
        bcs dvl_rts
        cmp #$FF
dvl_rts                                 ; $F419
        rts

; LED patterns for the digits 0-9.
dial_led_patterns                       ; $F41A
        !byte $00,$80,$08,$88,$04,$84,$0C,$8C ; $F41A
        !byte $40                       ; $F422
dat_F423
        !byte $C0                       ; $F423

; Digit limits: hundreds 0-2, tens and units 0-9.
dial_digit_limits                       ; $F424
        !byte $03,$0A,$0A               ; $F424

; Out: carry set when the WRITE PROTECT button stays down for the
; whole delay (long press), clear when it was released.
button_held                             ; $F427
        ldy #$1E
bhd_loop                                ; $F429
        jsr delay_panel
        lda #$08                        ; button released?
        and ppi_pb
        bne bhd_released
        dey
        bne bhd_loop
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
bhd_released                            ; $F438
        clc
        rts

; Wait until the DATA input reads asserted.
ctl_wait_data_low                       ; $F43A
        lda via1_prb
        ror
        bcc ctl_wait_data_low
        rts

; Wait until the DATA input reads released.
ctl_wait_data_high                      ; $F441
        lda via1_prb
        ror
        bcs ctl_wait_data_high
        rts

; Out: Z set when the drive is not busy and CLK and DATA are both
; released.
bus_is_idle                             ; $F448
        lda #$01
        and panel_state
        bne bii_rts
        lda #$F0                        ; release CLK and DATA and look at the bus
        and via1_prb
        sta via1_prb
        lda via1_prb
        and #$05
bii_rts                                 ; $F45B
        rts

; Delay for button debouncing.
delay_panel                             ; $F45C
        ldx #$4B
dpn_loop                                ; $F45E
        jsr delay_long_x
        dex
        bne dpn_loop
        rts

; Wait until all three buttons are released.
panel_wait_release                      ; $F465
        jsr delay_panel

pwr_loop                                ; $F468
        lda ppi_pb                      ; all three buttons up?
        and #$0E
        eor #$0E
        bne pwr_loop
        rts

; ==========================================================================
; RESET.  Entered through the 6502 reset vector once the boot ROM has
; loaded this image.  Sets the stack to $8F, takes the device number and
; default partition from the configuration block, clears the directory
; pointer tables and falls into the soft reset.
; ==========================================================================
reset                                   ; $F472
        sei
        cld
        ldx #$8F                        ; stack pointer $8F
        txs
        jsr altmap_set
        lda cfg_default_device          ; configured device number
        jsr cfg_set_device
        lda cfg_default_part_boot       ; configured default partition
        jsr cfg_set_default_partition
        jsr ram_unprotect
        lda #$00
        sta panel_state
        tax
rst_clear_tables                        ; $F48E
        sta part_dir_track,x            ; clear the per-partition directory pointers
        sta part_dir_sector,x
        inx
        bne rst_clear_tables

; Soft reset (also the U: / UJ command): initialise both VIAs and the
; 8255, clear RAM cmd_buf-$7FFF and continue with the warm start.
soft_reset                              ; $F497
        sei
        cld
        lda #$DB                        ; VIA #2: handshake lines
        sta via2_pcr
        lda #$08
        sta via2_prb
        lda #$18                        ; port B bits 3 and 4 are outputs
        sta via2_ddrb
        lda #$00                        ; data lines input
        sta via2_ddra
        lda #$00
        sta via2_sr
        lda #$7F                        ; no VIA #2 interrupts
        sta via2_ier
        sta via2_ifr
        lda #$FF
        sta via1_pra_nh
        lda #$3A                        ; VIA #1 DDRA
        sta via1_ddra
        lda #$D5                        ; serial lines idle
        sta via1_prb
        lda #$3A                        ; VIA #1 DDRB
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
        lda #$0C                        ; shift register: input
        sta via1_acr
        lda #$C6                        ; enable timer 1, shift register and ATN interrupts
        sta via1_ier
        lda #$92                        ; 8255: port A input, port C idle - through the stub at cfg_ppi_stub
        ldx #$E2
        jsr cfg_ppi_stub
        lda #$02                        ; clear cmd_buf-$7FFF
        sta $01
        ldy #$00
        sty $00
        tya
rst_clear_ram                           ; $F4FF
        sta ($00),y
        iny
        bne rst_clear_ram
        inc $01
        ldx $01
        cpx #$80
        bcc rst_clear_ram
        lda #$80                        ; cold start flag
        sta boot_flag

; Warm start (jump table slot jt_warm_start): clear zero page and stack,
; refresh the jump table, set up the channel tables, reset the SCSI
; layer, initialise the default partition, run the auto-boot file on a
; cold start and report 73, CMD HD DOS V1.92.
warm_start                              ; $F511
        sei
        ldy panel_state
        ldx #$00
        txa
wst_clear_zp                            ; $F517
        sta $00,x
        sta $0100,x
        inx
        bne wst_clear_zp
        sty panel_state
        ldx #$8F                        ; stack pointer $8F
        txs
        stx stack_save
        jsr jump_table_refresh          ; default jump table
        lda default_partition           ; default partition for the command channel
        sta cmd_partition
        jsr partition_select
        jsr tables_init
        ldy #$32
wst_delay                               ; $F537
        jsr delay_long_x
        dey
        bne wst_delay
        ldx #$00                        ; job $82: reset the SCSI layer
        lda #$82
        jsr job_run_or_error
        ldy #$00
wst_delay2                              ; $F546
        dex
        bne wst_delay2
        dey
        bne wst_delay2
        jsr partition_init              ; initialise the default partition
        bit boot_flag                   ; cold start: try the auto-boot file
        bpl startup_done
        jmp boot_autoexec
startup_done                            ; $F557
        lda #$73                        ; 73, CMD HD DOS V1.92
        jsr status_set_no_ts
        jsr serial_read_port
        jmp jt_idle_loop                ; to the idle loop

; Initialise the channel tables: everything free, secondary address 15
; = command channel $1E (write), 16 = error channel $1F; buffer pointers
; to the start of each buffer; bus addresses and defaults.
tables_init                             ; $F562
        lda #$FF
        ldx #$00
tin_sa                                  ; $F566
        sta sa_channel,x
        inx
        cpx #$13
        bcc tin_sa
        ldx #$00
tin_channels                            ; $F570
        sta chan_buf_a,x
        sta chan_buf_b,x
        sta chan_side_buf,x
        inx
        cpx #$20
        bcc tin_channels
        lda #$1E                        ; secondary address 15 -> channel $1E, write
        ora #$80
        sta sa_channel+15
        lda #$1F                        ; 16 -> channel $1F: error channel
        sta sa_channel+16
        lda #$01                        ; command channel ready to listen
        sta chan_status+30
        lda #$1E
        sta chan_buf_a+30
        lda #$88                        ; error channel ready to talk
        sta chan_status+31
        lda #$1F
        sta chan_buf_a+31
        ldx #$00
        ldy #$03                        ; buffers start at page 3
tin_buf_ptrs                            ; $F5A2
        lda #$00
        sta buf_ptrs,x
        inx
        tya
        sta buf_ptrs,x
        iny
        inx
        cpx #$40
        bcc tin_buf_ptrs
        jsr cmdbuf_ptr_reset
        jsr errbuf_ptr_reset
        jsr user_table_reset
        jsr bus_addresses_set
        lda #$02                        ; two retries
        sta job_retries
        lda #$04                        ; burst mode allowed
        sta bus_role
        lda #$01
        sta burst_interleave_s
        lda #$02
        sta burst_retries
        lda #$05                        ; sector interleave 5
        sta sector_interleave
        lda #$00
        sta swap_default
        sta swap_request
        sta burst_status_or
        lda #$FF
        sta burst_status_and
        sta evict_partition
        rts

; Command buffer pointer = cmd_buf.
cmdbuf_ptr_reset                        ; $F5E4
        lda #$00
        sta cmdbuf_ptr
        lda #$02
        sta cmdbuf_ptr+1
        rts

; Message buffer pointer = msg_buf.
errbuf_ptr_reset                        ; $F5ED
        lda #$00
        sta errbuf_ptr
        lda #$23
        sta errbuf_ptr+1
        rts

; Derive the LISTEN and TALK addresses from the device number.
bus_addresses_set                       ; $F5F6
        lda cfg_device                  ; swapped number active?
        bmi bas_store
        lda cfg_default_device
bas_store                               ; $F5FE
        and #$1F
        ora #$20                        ; LISTEN = $20 + device
        sta listen_addr
        eor #$60                        ; TALK = $40 + device
        sta talk_addr
        rts

; Copy the 31 default targets from jump_table_defaults into the jump table.
jump_table_refresh                      ; $F609
        php
        sei
        jsr ram_unprotect
        ldx #$00
        ldy #$00
jtr_loop                                ; $F612
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
        bcc jtr_loop
        jsr ram_protect
        plp
        rts

; Read the whole partition directory (32 blocks) into the partition
; table.  No caller inside this image.  HD-TOOLS does not call it either
; (it only uses M-R and M-W), so it is most likely code shared with the
; boot ROM.
partition_table_load                    ; $F62C
        ldx #$00
        jsr job_wait_slot
        lda #$00
        sta job_block_count
loc_F636
        jsr system_block_read
        bcs loc_F649
        jsr partition_table_copy
        inc job_block_count
        lda job_block_count
        cmp #$20
        bcc loc_F636
        clc
loc_F649
        rts

; Read block A of the system area (job $AA, slot 0).
; Out: carry set on error.
system_block_read                       ; $F64A
        clc
        adc sys_start_lo                ; plus the start of the system area
        sta job_sector
        lda #$00
        tax
        adc sys_start_hi
        sta job_track
        lda #$AA                        ; job $AA
        jmp system_job

; Copy type, size and start address of the eight entries of one
; partition directory block into the partition table.  No caller here.
partition_table_copy                    ; $F65F
        jsr ram_unprotect
        lda job_block_count
        asl
        asl                             ; 8 bytes of table per directory block
        asl
        tax
        lda #$02
        sta data_ptr
loc_F66D
        ldy #$00
ptc_entry                               ; $F66F
        lda (data_ptr),y                ; partition type
        sta part_type,x
        ldy #$1C                        ; size
        lda (data_ptr),y
        sta part_size_hi,x
        iny
        lda (data_ptr),y
        sta part_size_lo,x
        ldy #$13                        ; start address
        lda (data_ptr),y
        sta part_start_hi,x
        iny
        lda (data_ptr),y
        sta part_start_mid,x
        iny
        lda (data_ptr),y
        sta part_start_lo,x
        inx
        lda data_ptr
        clc
        adc #$20
        sta data_ptr
        bcc loc_F66D
        jmp ram_protect

; Read the configuration block of the system area to block_cache with a
; direct job.  Out: carry set on error.
config_block_read                       ; $F6A1
        jsr job_wait_slot
        lda #$50
        sta job_ptr_hi,x
        txa
        asl
        tax
        lda #$00
        sta job_track,x
        lda #$02
        sta job_sector,x
        txa
        lsr
        tax
        lda #$01
        sta job_block_count,x
        lda #$00
        sta job_ptr_lo,x
        lda #$FC                        ; job $FC: read blocks
        jmp system_job

; Read the configuration block, check its 'CMD HD  ' signature and
; copy it to cfg_device_tab.  No caller inside this image.
config_block_load                       ; $F6C8
        jsr config_block_read
        bcc loc_F6CE
        rts
loc_F6CE
        txa
        pha
        ldx #$0F                        ; compare the 16 signature bytes
loc_F6D2
        lda $51F0,x
        cmp config_signature,x
        bne cbl_fail
        dex
        bpl loc_F6D2
cbl_copy                                ; $F6DD
        jsr ram_unprotect               ; copy the block to the protected page
        ldx #$00
loc_F6E2
        lda $5100,x
        sta cfg_device_tab,x
        inx
        bne loc_F6E2
        jsr ram_protect
        clc
cbl_bad                                 ; $F6EF
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
cbl_fail                                ; $F6F0
        sec
        pla
        tax
        rts

; Signature at the end of the configuration block: the text followed
; by eight bytes of code (STA ppi_ctrl / STX ppi_pc / NOP / RTS), which the
; DOS calls at cfg_ppi_stub.
config_signature                        ; $F6F4
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $F6F4
        !byte $8D,$03,$88,$8E,$02,$88,$EA,$60 ; $F6FC

; Run job A in slot X with partition 0 selected, then restore the
; current partition.  Out: carry set when the job failed.
system_job                              ; $F704
        php
        sei
        sta job_queue,x
        lda cur_partition               ; remember the current partition
        pha
        lda #$00                        ; partition 0 = system
        jsr cfg_set_cur_partition
        jsr ram_unprotect
        lda job_queue,x
        jsr job_run
        pla
        jsr cfg_set_cur_partition
        jsr ram_protect
        lda job_queue,x
        plp
        cmp #$02
        rts

; Wait until the job in slot X has finished.
job_wait_slot                           ; $F726
        pha
        php
        cli
jws_loop                                ; $F729
        lda job_queue,x
        bmi jws_loop
        plp
        pla
        rts

; Write-protect the upper RAM again (control latch bit 5 low).
ram_protect                             ; $F730
        pha
        lda ctl_latch
        and #$DF
        sta ctl_latch
        pla
        rts

; Allow writes to the protected RAM (control latch bit 5 high).
ram_unprotect                           ; $F73B
        pha
        lda ctl_latch
        ora #$20
        sta ctl_latch
        pla
        rts

; Restore the control latch saved by ram_unprotect_save.
ram_protect_restore                     ; $F746
        pha
        lda latch_saved
        sta ctl_latch
        pla
        rts

; Save the control latch and allow writes to the protected RAM.
ram_unprotect_save                      ; $F74F
        pha
        lda ctl_latch
        sta latch_saved
        jsr ram_unprotect
        pla
        rts

; Set / clear the ALTMAP line (8255 port C bit 1), which selects the
; alternate memory map.
altmap_set                              ; $F75B
        pha
        lda ppi_pc
        ora #$02
        sta ppi_pc
        pla
        rts

; Clear the ALTMAP line.
altmap_clear                            ; $F766
        pha
        lda ppi_pc
        and #$FD
        sta ppi_pc
        pla
        rts

; Setters for bytes of the protected configuration page.
cfg_set_e0                              ; $F771
        jsr ram_unprotect_save
        sta cfg_geos_entry
        jmp ram_protect_restore

; No caller inside this image.
cfg_set_default_device                  ; $F77A
        jsr ram_unprotect_save
        sta cfg_default_device
        jmp ram_protect_restore

; No caller inside this image.
cfg_set_e2                              ; $F783
        jsr ram_unprotect_save
        sta cfg_default_part_boot
        jmp ram_protect_restore

; Store A as the default partition.
cfg_set_default_partition               ; $F78C
        jsr ram_unprotect_save
        sta default_partition
        jmp ram_protect_restore

; Store A as the active device number.
cfg_set_device                          ; $F795
        jsr ram_unprotect_save
        sta cfg_device
        jmp ram_protect_restore

; Store A as the current partition number.
cfg_set_cur_partition                   ; $F79E
        jsr ram_unprotect_save
        sta cur_partition
        jmp ram_protect_restore

; 'GEOS' command helper: take entry X of a table in the configuration
; block, load the blocks it names to the address it gives, checksum
; them and compare with the stored sum; on success record the entry in
; cfg_geos_entry.  Purpose not fully established (?).
geos_boot_check                         ; $F7A7
        txa                             ; entry size 64
        asl
        asl
        asl
        asl
        asl
        asl
        pha
        ldx #$00
        jsr config_block_read
        bcs gbc_fail
        pla
        pha
        tax
        lda block_cache,x
        sta work_block
        lda $5001,x
        sta $5201
        lda $5003,x
        sta $5204
        lda $5002,x
        sta $5205
        lda #$00
        sta $5202
        sta $5203
        jsr gbc_load_and_sum
        bcs gbc_fail
        pla
        pha
        tax
        lda $5202                       ; checksum must match
        cmp $5005,x
        bne gbc_fail
        lda $5203
        cmp $5004,x
        bne gbc_fail
        pla
        jsr cfg_set_e0                  ; record the entry
        clc
        rts
gbc_fail                                ; $F7F7
        pla
        sec
        rts

; Load the blocks with a direct job and add up all bytes.
gbc_load_and_sum                        ; $F7FA
        sei
        lda work_block
        sta jiffy_nibble
        lda #$00
        sta $6B
        ldx #$00
        lda $5205
        lsr
        sta job_track,x
        lda $5204
        ror
        sta job_sector,x
        lda $5201
        lsr
        sta job_block_count,x
        lda $6B
        sta job_ptr_lo,x
        lda jiffy_nibble
        sta job_ptr_hi,x
        lda #$FC                        ; job $FC: read blocks
        jsr system_job
        bcs gbs_rts
        ldx $5201
        ldy #$00
gbs_page                                ; $F831
        lda $5202
gbs_byte                                ; $F834
        clc
        adc ($6B),y
        bcc loc_F83C
        inc $5203
loc_F83C
        iny
        bne gbs_byte
        sta $5202
        inc jiffy_nibble
        lda jiffy_nibble                ; pages wrap from $C0 to $40 with ALTMAP switched off
        cmp #$C0
        bne gbs_next
        lda #$40
        sta jiffy_nibble
        jsr altmap_clear
gbs_next                                ; $F851
        dex
        bne gbs_page
        clc
gbs_rts                                 ; $F855
        rts

; ==========================================================================
; Idle loop (jump table slot jt_idle_loop).  Executes a pending command, then
; waits for ATN or a parallel request; meanwhile the activity LED
; follows open files and pending jobs and the front panel is polled.
; ==========================================================================
idle_loop                               ; $F856
        sei
        jsr par_release                 ; end a parallel transaction
        lda #$10                        ; serial lines: ATN acknowledge only
        sta via1_prb
        lda #$00                        ; command pending?
        cmp cmd_pending
        beq idl_wait
        sta cmd_pending
        cli
        jsr cmd_execute                 ; execute it
        jsr burst_sr_input
idl_wait                                ; $F86E
        cli
        bit via1_prb                    ; ATN?
        bmi idl_attention
        bit ppi_pb                      ; parallel request?
        bpl idl_housekeeping
idl_attention                           ; $F879
        jmp jt_atn_service
idl_housekeeping                        ; $F87C
        sei
        ldy #$00
        ldx #$0E                        ; count open files
idl_count_open                          ; $F881
        lda sa_channel,x
        cmp #$FF
        beq loc_F889
        iny
loc_F889
        dex
        bpl idl_count_open
        ldx #$1F                        ; count pending jobs
idl_count_jobs                          ; $F88E
        lda job_queue,x
        bpl loc_F893
        iny
loc_F893
        dex
        bpl idl_count_jobs
        tya
        beq idl_led_off
        jsr led_activity_on             ; something active: LED on
        jmp idl_panel
idl_led_off                             ; $F89F
        jsr led_activity_off
idl_panel                               ; $F8A2
        jsr panel_poll                  ; front panel
        jmp idl_wait

; ==========================================================================
; IRQ handler.  ATN edge: note it.  Shift register: a burst host has
; clocked a byte.  Timer 1 (20 ms) or BRK: run the job queue.
; ==========================================================================
irq_handler                             ; $F8A8
        pha
        tya
        pha
        txa
        pha
        ldx via1_ifr                    ; interrupt flags
        txa                             ; CA1: ATN edge
        and #$02
        beq irq_chk_sr
        sta via1_ifr
        lda #$40                        ; bit 6 of atn_state: ATN pending
        ora atn_state
        sta atn_state
irq_chk_sr                              ; $F8C0
        txa
        and #$04                        ; shift register
        beq irq_chk_timer
        sta via1_ifr
        and bus_role                    ; burst mode allowed?
        beq irq_chk_timer
        lda #$80                        ; bit 7 of bus_protocol: burst host
        ora bus_protocol
        sta bus_protocol
irq_chk_timer                           ; $F8D4
        txa
        and #$40                        ; timer 1
        beq irq_chk_brk
        sta via1_ifr
        jsr jt_run_jobs                 ; run the job queue
irq_chk_brk                             ; $F8DF
        tsx                             ; BRK flag in the stacked status?
        lda $0104,x
        and #$10
        beq irq_exit
        jsr jt_run_jobs
irq_exit                                ; $F8EA
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
; jump_table_refresh copies these words into the operands of the JMPs on every warm
; start, undoing any run-time patch made through jump_vector_set.
; --------------------------------------------------------------------------
jump_table_defaults                     ; $FE00
        !word cmd_block                 ; $FE00
        !word cmd_copy                  ; $FE02
        !word cmd_g                     ; $FE04
        !word cmd_initialize            ; $FE06
        !word cmd_m                     ; $FE08
        !word cmd_new                   ; $FE0A
        !word cmd_position              ; $FE0C
        !word cmd_rename                ; $FE0E
        !word cmd_scratch               ; $FE10
        !word cmd_time                  ; $FE12
        !word cmd_user                  ; $FE14
        !word cmd_validate              ; $FE16
        !word cmd_slash                 ; $FE18
        !word cmd_utility               ; $FE1A
        !word warm_start                ; $FE1C
        !word jump_vector_set           ; $FE1E
        !word idle_loop                 ; $FE20
        !word dos_error                 ; $FE22
        !word job_error                 ; $FE24
        !word irq_handler               ; $FE26
        !word atn_service               ; $FE28
        !word listen_handler            ; $FE2A
        !word talk_handler              ; $FE2C
        !word burst_recv_byte_hs        ; $FE2E
        !word burst_send_byte_hs        ; $FE30
        !word job_run_or_error          ; $FE32
        !word job_run                   ; $FE34
        !word job_scan                  ; $FE36
        !word job_to_block              ; $FE38
        !word cmd_lock                  ; $FE3A
        !word cmd_write_protect         ; $FE3C
free_space_2                            ; $FE3E
        !fill 98, $00                   ; $FE3E-$FE9F

; Second copy of the copyright text.  Not referenced by the DOS itself,
; but HD-TOOLS V1.12 reads three bytes at $FEA0 with M-R before it does
; anything else, apparently to recognise a CMD HD ('CMD').
copyright_msg_2                         ; $FEA0
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $FEA0
free_space_3                            ; $FEEA
        !fill 22, $00                   ; $FEEA-$FEFF

; ==========================================================================
; Public jump table: 31 x JMP.  The DOS reaches its own major services
; through these slots, so they can be re-vectored at run time (jump_vector_set
; patches a slot; the image lives in write-protected RAM).  The command
; dispatcher cmd_execute jumps to $FF00+offset using the offset table cmd_jump_offsets.
; ==========================================================================
jt_cmd_block                            ; $FF00
        jmp cmd_block                   ; 'B'  block commands (B-R B-W B-A B-F B-P B-E)
jt_cmd_copy                             ; $FF03
        jmp cmd_copy                    ; 'C'  copy / change partition / change directory
jt_cmd_g                                ; $FF06
        jmp cmd_g                       ; 'G'  G-P get partition info, GEOS
jt_cmd_initialize                       ; $FF09
        jmp cmd_initialize              ; 'I'  initialize
jt_cmd_m                                ; $FF0C
        jmp cmd_m                       ; 'M'  M-R M-W M-E, MD make directory
jt_cmd_new                              ; $FF0F
        jmp cmd_new                     ; 'N'  new (format partition)
jt_cmd_position                         ; $FF12
        jmp cmd_position                ; 'P'  position (relative files)
jt_cmd_rename                           ; $FF15
        jmp cmd_rename                  ; 'R'  rename, RD remove directory
jt_cmd_scratch                          ; $FF18
        jmp cmd_scratch                 ; 'S'  scratch
jt_cmd_time                             ; $FF1B
        jmp cmd_time                    ; 'T'  time: T-R / T-W
jt_cmd_user                             ; $FF1E
        jmp cmd_user                    ; 'U'  user commands, U0 burst commands
jt_cmd_validate                         ; $FF21
        jmp cmd_validate                ; 'V'  validate
jt_cmd_slash                            ; $FF24
        jmp cmd_slash                   ; '/'  1581 sub-partition select / create
jt_cmd_utility                          ; $FF27
        jmp cmd_utility                 ; '&'  utility loader
jt_warm_start                           ; $FF2A
        jmp warm_start                  ; warm start
jt_set_vector                           ; $FF2D
        jmp jump_vector_set             ; patch jump-table slot X with address A (lo) / Y (hi)
jt_idle_loop                            ; $FF30
        jmp idle_loop                   ; idle loop
jt_dos_error                            ; $FF33
        jmp dos_error                   ; report DOS error A and abort the command
jt_job_error                            ; $FF36
        jmp job_error                   ; report job error A of job X and abort the command
jt_irq                                  ; $FF39
        jmp irq_handler                 ; IRQ / BRK handler (target of the IRQ vector)
jt_atn_service                          ; $FF3C
        jmp atn_service                 ; serial bus ATN service
jt_listen                               ; $FF3F
        jmp listen_handler              ; addressed as listener: receive data
jt_talk                                 ; $FF42
        jmp talk_handler                ; addressed as talker: send data
jt_burst_get_byte                       ; $FF45
        jmp burst_recv_byte_hs
jt_burst_send_byte                      ; $FF48
        jmp burst_send_byte_hs
jt_do_job                               ; $FF4B
        jmp job_run_or_error            ; run job A for buffer X, job error on failure
jt_do_job_status                        ; $FF4E
        jmp job_run                     ; run job A for buffer X, return status
jt_run_jobs                             ; $FF51
        jmp job_scan                    ; execute all pending jobs
jt_job_to_block                         ; $FF54
        jmp job_to_block                ; convert the job's track/sector into a block address
jt_cmd_lock                             ; $FF57
        jmp cmd_lock                    ; 'L'  lock / unlock file
jt_cmd_write_protect                    ; $FF5A
        jmp cmd_write_protect           ; 'W'  W-0 / W-1 software write protect
free_space_4                            ; $FF5D
        !fill 157, $00                  ; $FF5D-$FFF9

; --------------------------------------------------------------------------
; 6502 hardware vectors
; --------------------------------------------------------------------------
hw_vectors                              ; $FFFA
        !word nmi_ui_command            ; $FFFA  NMI
        !word reset                     ; $FFFC  RESET
        !word jt_irq                    ; $FFFE  IRQ/BRK (through the jump table)
