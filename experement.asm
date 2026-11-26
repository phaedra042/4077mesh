;------------------------------------------------------------------------------
; I/O and the RAM windows between the I/O chips
;------------------------------------------------------------------------------
via1_prb       = $8000    ; VIA #1 port B = serial bus (schematic U10): b0 DATA IN, b1 DATA OUT, b2 CLK IN, b3 CLK OUT, b4 ATN ACK, b5 FST DIR, b6 ATN OUT (used as controller), b7 ATN IN. CA1 = ATN, CB1 = FST CLK, CB2 = FST DATA
via1_ddrb      = $8002    ; VIA #1 DDRB ($3A: b1, b3, b4, b5 are outputs; $7A adds b6 ATN OUT while we are bus controller)
via1_ddra      = $8003    ; VIA #1 DDRA = $3A like DDRB. Port A is the AUX serial port: PA0 AUX DATA IN, PA1 AUX DATA OUT, PA2 AUX CLK IN, PA3 AUX CLK OUT, PA4 AUX ATN OUT (outputs: PA1, 3, 4 and PA5 SB RESET ENA), PA6 SB RESET IN, PA7 AUX ATN in
via1_t2cl      = $8008                  ; VIA #1 timer 2 counter low
via1_t2ch      = $8009                  ; VIA #1 timer 2 counter high
via1_sr        = $800A                  ; VIA #1 shift register: fast-serial (burst) data byte
via1_acr       = $800B                  ; VIA #1 ACR: bits 2-4 select shift-in ($0C) / shift-out ($14) mode
via1_pcr       = $800C                  ; VIA #1 PCR
via1_ifr       = $800D                  ; VIA #1 IFR: b1 CA1 = ATN edge, b2 shift register done, b6 timer 1
via1_ier       = $800E                  ; VIA #1 IER
via1_pra_nh    = $800F    ; VIA #1 port A (no handshake) = AUX port, see via1_ddra. Written $FF at reset (all lines released) and never used again in v1.92
part_type      = $8200                  ; partition table: type per partition (0 not created,1 native,2 1541,3 1571,4 1581,5 1581 CP/M,6 print buffer,7 foreign,$FF system)
part_size_hi   = $8300                  ; partition table: size in 512-byte blocks, middle byte (entry byte 28; G-P bytes 27-29 = hi,mid,lo)
via2_prb       = $8400    ; VIA #2 port B = SCSI control (schematic U9): b0 C/D, b1 MSG, b2 I/O (the bus phase), b3 BDIR (data bus direction), b4 SEL OUT, b5 BSY, b6 ACK IN, b7 REQ
via2_pra       = $8401    ; VIA #2 port A = SCSI data bus DB0-DB7 through the 74F245 transceiver; CA1 = SCSI RST in, CA2 = ACK strobe (hardware handshake), CB2 = FORCE
via2_ddrb      = $8402                  ; VIA #2 DDRB
via2_ddra      = $8403                  ; VIA #2 DDRA: $00 = data bus input, $FF = output
via2_sr        = $840A                  ; VIA #2 shift register
via2_pcr       = $840C                  ; VIA #2 PCR: CA2/CB2 handshake outputs
via2_ifr       = $840D                  ; VIA #2 IFR
via2_ier       = $840E                  ; VIA #2 IER
part_size_lo   = $8600                  ; partition table: size in 512-byte blocks, low byte (entry byte 29)
part_start_hi  = $8700                  ; partition table: start block, high byte (entry byte 19; 512-byte blocks)
ppi_pa         = $8800    ; 8255 port A = PD0-PD7 of the parallel port J4 (14-pin DIN)
ppi_pb         = $8801    ; 8255 port B (inputs): b0 PRDY IN, b1 SWAP 8 button, b2 SWAP 9 button, b3 WRITE PROTECT button (buttons active low), b4 SEL IN (SCSI), b5 PEXT IN, b6 PCLK IN, b7 PATN (parallel ATN)
ppi_pc         = $8802    ; 8255 port C (outputs): b0 ROMOS, b1 ALTMAP (alternate memory map), b2 ATN OUT (SCSI), b3 RST OUT (SCSI), b4 BSY OUT (SCSI), b5 PEXT OUT, b6 PCLK OUT, b7 PRDY OUT
ppi_ctrl       = $8803                  ; 8255 control word: $92 = port A input, $82 = port A output
part_start_mid = $8A00                  ; partition table: start block, middle byte (entry byte 20)
part_start_lo  = $8B00                  ; partition table: start block, low byte (entry byte 21)
rtc_regs       = $8C00                  ; RTC 72421 register 0 (seconds, units); registers follow as BCD digits
rtc_hour10     = $8C05                  ; RTC register 5: hours tens (+ AM/PM bit)
rtc_weekday    = $8C0C                  ; RTC register 12: day of week
rtc_ctrl_d     = $8C0D                  ; RTC control register D (HOLD / BUSY)
ctl_latch      = $8F00                  ; control latch: b5 = write enable for the protected RAM, low bits drive the LEDs

;------------------------------------------------------------------------------
; SYMBOLIC NAMES for the zero page and RAM variables (inferred from the code).
; Names marked by usage: arrays are indexed by buffer/channel/partition number.
;------------------------------------------------------------------------------
; ---- zero page ----
jobq_base          = $00           ; CBM-style job queue emulation area $00-$1F (1541: $00-$04, 1581: $02-$1x); host-visible job codes
job_code           = $20           ; Job code / status per buffer #0-31 ($20..$3F): bit7 = pending, <2 = OK after completion
chan_scan_idx      = $41           ; Scratch: buffer/channel index while searching for a free one
chan_alt_idx       = $44           ; Scratch: channel index (+$20 when the second buffer of a channel is current)
bus_flags          = $46           ; IEC state: b7 = we are TALKER, b6 = we are LISTENER, b2 = burst-capable host
drive_flags        = $49           ; b7 write-protect, b6 ?, b1 error-LED blink, b0 activity LED
tmp_cmd_char       = $4A           ; Scratch: first character of the DOS command
cmd_pending        = $4B           ; Non-zero when a complete command was received on channel 15 (idle loop parses it)
burst_cmd          = $4C           ; Burst-command byte received from the host (b5 = 'no data phase', b4 = 'extended', b0 = 'verify')
panel_count        = $4F           ; Front-panel button auto-repeat counters ($4F..$52)
tmp_a              = $50           ; General scratch / 16-bit scratch pointer lo ($50/$51), also jmp ($0050) vector
tmp_b              = $51           ; General scratch / pointer hi
tmp_c              = $52           ; General scratch
tmp_d              = $53           ; General scratch
tmp_e              = $54           ; General scratch
job_cmd_tmp        = $55           ; Job command byte under construction ($80 = read, $90 = write)
cmd_len            = $56           ; Length of the command in the command buffer ($0200)
dev_unit_tmp       = $57           ; Reset-initialised to 1
bam_ptr            = $58           ; Pointer ($58/$59) into the BAM cache buffer
bam_ptr_hi         = $59           ; High byte of bam_ptr
cur_track          = $5A           ; Current track (job track / link track)
cur_sector         = $5B           ; Current sector (job sector / link sector)
tmp_len            = $5C           ; Scratch (name length compare)
saved_sp           = $5E           ; Stack pointer saved at warm start, restored after errors
iec_tmp_a          = $60           ; Serial fast-protocol scratch
dev_unit_tmp2      = $61           ; Reset-initialised to 2
ucmd_tbl_ptr       = $62           ; Pointer to the U-command vector table (U1..UJ)
ucmd_tbl_ptr_hi    = $63           ; High byte of ucmd_tbl_ptr
ucmd_vector        = $64           ; Vector of the selected U command (jmp ($0064))
ucmd_vector_hi     = $65           ; High byte of ucmd_vector
buf_ptr_a          = $66           ; Pointer ($66/$67) to the job buffer data
buf_ptr_a_hi       = $67           ; High byte of buf_ptr_a
buf_ptr_b          = $68           ; Pointer ($68/$69) to the 512-byte SCSI sector buffer / source buffer
buf_ptr_b_hi       = $69           ; High byte of buf_ptr_b
burst_status       = $6A           ; Burst status / command byte being returned to the host
tmp_6b             = $6B           ; Scratch
tmp_6c             = $6C           ; Scratch (high nibble in fast-serial send)
clk_phase          = $6E           ; Last sampled CLK state for burst byte handshake
iec_tmp_b          = $6F           ; Serial fast-protocol scratch
burst_count_hi     = $70           ; Burst: sector count hi
burst_count_lo     = $71           ; Burst: sector count lo
listen_addr        = $77           ; Our LISTEN address ($20+dev)
talk_addr          = $78           ; Our TALK address ($40+dev)
cur_chan           = $80           ; Current channel / buffer-set number (0-31)
eoi_flag           = $81           ; b7 set = EOI received / last byte
cur_sa             = $82           ; Current secondary address (0-15; 15 = command channel)
cur_atn_byte       = $83           ; Last byte received under ATN
iec_byte           = $84           ; Byte being shifted over the serial bus / last data byte
tmp_85             = $85           ; Scratch
tmp_86             = $86           ; Scratch (side-sector / REL math)
tmp_87             = $87           ; Scratch
tmp_88             = $88           ; Scratch pointer lo / REL math
tmp_89             = $89           ; Scratch pointer hi
tmp_8a             = $8A           ; Scratch
calc_a             = $8B           ; 24-bit math accumulator lo ($8B-$8D)
calc_b             = $8C           ; 24-bit math accumulator mid
calc_c             = $8D           ; 24-bit math accumulator hi
calc_sum           = $8E           ; 24-bit sum ($8E-$90) for REL record offsets
rel_offset_lo      = $90           ; REL file record offset lo ($90-$92)
rel_offset_mid     = $91           ; REL file record offset mid
rel_offset_hi      = $92           ; REL file record offset hi
dir_ptr            = $94           ; Pointer ($94/$95) into the current channel buffer / directory entry
dir_ptr_hi         = $95           ; High byte of dir_ptr
bit_count          = $96           ; Serial bit counter
loop_idx           = $97           ; Loop index (parsed filename pattern #)
rel_rec_tmp        = $98           ; REL scratch
rel_side_no        = $99           ; REL: side-sector number
rel_side_off       = $9A           ; REL: offset in side sector
rel_rec_off        = $9B           ; REL: record byte offset
cur_buf_idx        = $9C           ; Buffer number of the active channel
tmp_9d             = $9D           ; Scratch (Y save in validate)
buf_ptr_tbl        = $A0           ; Per-buffer pointer table: word at $A0+2*buf = current byte pointer
buf_ptr_tbl_hi     = $A1           ; High-byte side of buf_ptr_tbl
cmdbuf_ptr         = $DC           ; Command buffer fill pointer ($DC low, $DD = $02 high)
cmdbuf_ptr_hi      = $DD           ; High byte of command buffer pointer ($02)
errmsg_ptr         = $DE           ; Pointer ($DE/$DF) to the error message being sent
errmsg_ptr_hi      = $DF           ; High byte of errmsg_ptr
scsi_ptr_a         = $E0           ; Pointers set up for SCSI cdb/status buffers ($E0-$E5)
vec_tmp            = $E8           ; Temp indirect jump vector ($E8/$E9)
vec_tmp_hi         = $E9           ; High byte of vec_tmp
; ---- RAM ----
stack_base         = $0100         ; CPU stack page
cmd_buf            = $0200         ; Command / filename buffer (up to 255 chars)
burst_buf          = $0300         ; 256-byte burst transfer buffer
user_code          = $0500         ; User-code area (U3..UA jump targets $0500,$0503,...)
dirblk_buf         = $2200         ; Directory / header sector buffer 22xx (also error message buffer $2300)
dirblk_buf1        = $2201         ; second byte
errmsg_buf         = $2300         ; Error message text buffer (also RTC time string)
job_track          = $2800         ; Per-buffer job track (index 2*buf)
job_sector         = $2801         ; Per-buffer job sector (index 2*buf)
job_track_b30      = $283C         ; Buffer 30 (internal BAM buffer): track
job_sector_b30     = $283D         ; Buffer 30: sector
job_track_b31      = $283E         ; Buffer 31 (internal directory buffer): track
job_sector_b31     = $283F         ; Buffer 31: sector
job_ext            = $2840         ; Per-buffer job extension byte (high block byte / flags, index buf)
job_bufaddr_hi     = $2860         ; Per-buffer job data address hi
job_bufhi_b30      = $287E         ; Buffer 30 job buffer address hi
job_bufaddr_lo     = $2880         ; Per-buffer job data address lo
job_buflo_b30      = $289E         ; Buffer 30 job buffer address lo
job_count          = $28A0         ; Per-buffer job sector count
job_count_b30      = $28BE         ; Buffer 30 job count
job_lba4           = $28C0         ; Per-job SCSI block address byte 4
job_lba3           = $28E0         ; Per-job SCSI block address byte 3
job_lba2           = $2900         ; Per-job SCSI block address byte 2
job_lba1           = $2920         ; Per-job SCSI block address byte 1
job_lba0           = $2940         ; Per-job SCSI block address byte 0
job_status         = $2960         ; Per-buffer job completion status
scsi_cdb           = $2A00         ; SCSI command descriptor block being built ($2A00-$2A0F)
scsi_status        = $2A10         ; SCSI status / sense result buffer
scsi_sense         = $2A30         ; SCSI sense data
cache_lba4         = $2A50         ; LBA currently cached in the 512-byte sector buffer ($2A50-$2A54)
job_tmp_55         = $2A55         ; Job executor scratch
job_opcode         = $2A56         ; Job opcode being executed
job_buf_no         = $2A57         ; Buffer number of the job being executed
job_trk_lo         = $2A58         ; Job track (copy)
job_sec_lo         = $2A59         ; Job sector (copy)
blk_hi             = $2A5A         ; Computed block number hi (partition relative)
blk_lo             = $2A5B         ; Computed block number lo
job_dir_flag       = $2A5C         ; b7 = job is read(0)/write(1) direction flag
half_flag          = $2A5D         ; b7 = second 256-byte half of the 512-byte block
job_part           = $2A5E         ; Partition used by the job
job_flags_tmp      = $2A5F         ; Job flags copy
led_timer          = $2A60         ; LED blink timer
led_period         = $2A61         ; LED blink period
led_period_tmp     = $2A62         ; LED blink period working copy
lba_b2             = $2A63         ; 24-bit absolute block number hi
lba_b1             = $2A64         ; 24-bit absolute block number mid
lba_b0             = $2A65         ; 24-bit absolute block number lo
lba_tmp            = $2A66         ; Scratch loop counter
par_flags          = $2A67         ; Parallel-transfer flags
rtc_buf            = $2B00         ; Time buffer: weekday,month,day,year,hour,min,sec...
bam_part           = $2B30         ; BAM cache slot -> partition number ($2B30-$2B3F, 16 slots)
bam_dirty          = $2B40         ; BAM cache slot dirty flag
bam_free_lo        = $2B50         ; BAM cache slot: free blocks lo
bam_free_hi        = $2B60         ; BAM cache slot: free blocks hi
bam_dosver         = $2B70         ; BAM cache slot: DOS version byte
bam_sec_idx        = $2B80         ; BAM cache slot: BAM sector currently held (0-15, $FF none)
bam_state          = $2B90         ; BAM cache slot: state ($FF = bad)
tmp_ctr            = $2BA0         ; Scratch counter
bam_slot           = $2BA1         ; Current BAM cache slot
bam_rw             = $2BA2         ; b7: 1 = write BAM back, 0 = read
disk_id1           = $2BA3         ; Disk ID char 1
disk_id2           = $2BA4         ; Disk ID char 2
blk_cnt_lo         = $2BA5         ; Block-command count lo
blk_cnt_hi         = $2BA6         ; Block-command count hi
hdr_track          = $2BA7         ; Header block track of the current partition/directory
hdr_sector         = $2BA8         ; Header block sector
dir1_sector        = $2BA9         ; First directory block sector
ts_year            = $2BAA         ; Parsed time-stamp field 0 (year)
ts_month           = $2BAB         ; Parsed time-stamp field 1
ts_day             = $2BAC         ; Parsed time-stamp field 2
ts_hour            = $2BAD         ; Parsed time-stamp field 3
ts_min             = $2BAE         ; Parsed time-stamp field 4
dir_mode_ext       = $2BB0         ; b7 = extended (long) directory listing
dir_line_flag      = $2BB1         ; Directory listing line counter/flag
dir_col            = $2BB2         ; Directory line column counter
dir_mode           = $2BB3         ; b7 = partition listing, b6 = ... (listing mode flags)
filter_flags       = $2BB4         ; Date/time filter flags
filter_flags2      = $2BB5         ; more filter flags
ent_track          = $2BB6         ; Directory entry location: track
ent_sector         = $2BB7         ; Directory entry location: sector
ent_offset         = $2BB8         ; Directory entry location: byte offset within sector
last_part          = $2BB9         ; Last partition used (directory)
dir_scan_tmp       = $2BBA         ; Directory scan scratch
dir_first_flag     = $2BBC         ; First-search flag for directory scan
swap_idx           = $2BBD         ; Name swap index
found_state        = $2BBE         ; Directory search match state
match_type         = $2BBF         ; Match type of current entry ($FF none)
dir_blk_flag       = $2BC0         ; Directory block scan flag
dir_ent_ctr        = $2BC1         ; Entries left in directory block
name_len           = $2BC2         ; Length of the filename being copied
blocks_free_lo     = $2BC3         ; Blocks free (lo) for the directory trailer
blocks_free_hi     = $2BC4         ; Blocks free (hi)
dir_load_flag      = $2BC5         ; Non-zero while a directory ($) is being loaded
geo_dir_track      = $2BC6         ; Geometry: directory/BAM track of the partition
geo_first_track    = $2BC7         ; Geometry: first track
geo_end_track      = $2BC8         ; Geometry: last track + 1
geo_secs_per_trk   = $2BC9         ; Geometry: sectors per track of the current track
move_tmp_trk       = $2BCA         ; Scratch track
move_tmp_sec       = $2BCB         ; Scratch sector
dir_cd_tmp         = $2BCC         ; Scratch (change directory)
dir_cd_tmp2        = $2BCD         ; Scratch
saved_job_err_vec  = $2BCE         ; Saved job-error vector ($2BCE/$2BCF)
saved_dos_err_vec  = $2BD0         ; Saved dos-error vector ($2BD0/$2BD1)
checksum           = $2BD2         ; Running checksum (utility loader)
ser_byte_tmp       = $2BD4         ; Serial-master byte
ser_state          = $2BD5         ; Serial-master state
default_part       = $2BD6         ; Default partition at power on / reset
iec_state          = $2BD7         ; b7 = bus active, b6 = ATN edge seen
xfer_mode          = $2BD8         ; b7 = burst protocol, b6 = JiffyDOS protocol; $61 = sector stream mode
first_boot         = $2BDA         ; b7 = just powered on
ctl_latch_save     = $2BDB         ; Saved control latch image
disp_vec           = $2BDC         ; Temp dispatch vector ($2BDC/$2BDD)
pending_err        = $2BDE         ; Error code waiting to be reported when the command ends ($50 etc.)
job_flag_df        = $2BDF         ; b6 = job in progress for this buffer
burst_tmp          = $2BE1         ; Burst status temp
cmd_class          = $2BE2         ; Command class / parse flags
syntax_flags       = $2BE3         ; Parsed command syntax flags
cmd_flag_e4        = $2BE4         ; Parser flag
parse_char         = $2BE5         ; Current separator character in parser
swap_request       = $2BE6   ; Pending SWAP 8 (8) or SWAP 9 (9) request from the front panel
panel_flags        = $2BE7         ; Front panel state flags
burst_mode         = $2BE8         ; b7 = 1581 burst, b6 = 1571 burst
interleave         = $2BE9         ; Sector interleave (burst format), default 5
file_idx           = $2BEA         ; Index of the current file spec
file_count         = $2BEB         ; Number of file specs in the command
file_cur           = $2BEC         ; Current file spec being processed
file_type          = $2BED         ; Current file type (0 DEL, 1 SEQ, 2 PRG, 3 USR, 4 REL, 5 CBM, 6 DIR)
file_type_chr      = $2BEE         ; Index of file-type letter in the command
name_end           = $2BEF         ; Offset of the end of the current name
rw_mode            = $2BF0         ; Access mode R/W/A/M index
rel_rec_len        = $2BF3         ; REL record length
rel_ss_track       = $2BF4         ; REL first side-sector track
rel_ss_sector      = $2BF5         ; REL first side-sector sector
rel_ss_idx         = $2BF6         ; REL current side-sector index
status_bits        = $2BF7         ; Flags reported on channel 15
d7_x_save          = $2BF8         ; X register save
panel_wp           = $2BF9         ; Write-protect (front panel) flag
lookup_tmp         = $2BFA         ; Scratch for buffer/partition lookup
par_mode           = $2BFB         ; b6 = parallel (ppi) bus in use
talk_vec           = $2BFC         ; Selected talker handler (jmp ($2BFC))
byte_vec           = $2BFE         ; Selected byte-send handler (jmp ($2BFE))
name_start         = $2C00         ; Per-spec start offset into command buffer (up to 8 specs)
name_end_tbl       = $2C08         ; Per-spec end offset
spec_part          = $2C10         ; Per-spec partition number
spec_type          = $2C18         ; Per-spec file type / flags
spec_trk           = $2C20         ; Per-spec result track
spec_sec           = $2C28         ; Per-spec result sector
spec_aux1          = $2C30         ; Per-spec aux (track)
spec_aux2          = $2C38         ; Per-spec aux (sector)
spec_aux3          = $2C40         ; Per-spec aux
sa_chan            = $2C48         ; Secondary address (0-18) -> channel number, $FF = free
chan_buf           = $2C68         ; Channel -> primary buffer number (bit7: spare, bit6: dirty)
chan_buf2          = $2C88         ; Channel -> secondary buffer number
chan_dirbuf        = $2CA8         ; Channel -> directory-entry buffer number
chan_part          = $2CC8         ; Channel -> partition number
chan_dir_track     = $2CE8         ; Channel -> directory entry track
chan_dir_sector    = $2D08         ; Channel -> directory entry sector
chan_dir_index     = $2D28         ; Channel -> directory entry index (offset)
chan_blk_lo        = $2D48         ; Channel -> blocks counter lo
chan_blk_hi        = $2D68         ; Channel -> blocks counter hi
chan_state         = $2D88         ; Channel -> type & status flags (bits 1-3 = channel type)
chan_flags         = $2DA8         ; Channel -> read/write flags ($08 = writing, $80 = active)
chan_byte          = $2DC8         ; Channel -> next byte to send / last byte received
chan_last          = $2DE8         ; Channel -> last byte pointer in buffer
chan_recsize       = $2E08         ; Channel -> record size
chan_rel_end       = $2E28         ; Channel -> REL record end pointer
chan_ss_cache      = $2E48         ; Channel -> side-sector cache index
chan_ss_sec        = $2E68         ; Channel -> side-sector sector
chan_ss_trk        = $2E88         ; Channel -> side-sector track
chan_rel_flags     = $2EA8         ; Channel -> REL flags (b5 = relative)
bam_aux            = $2FC0         ; BAM cache slot auxiliary
dir_line           = $2FE0         ; Directory line buffer ($2FE0..)
sector_buf         = $5000         ; 512-byte SCSI sector buffer
part_hdr_id        = $51F0         ; Partition table header ID area
sector_buf2        = $5200         ; Second 256-byte half / copy buffer
lun_lo             = $9038         ; per-LUN limit lo ($9038)
lun_mid            = $9070         ; per-LUN limit mid ($9070)
lun_hi             = $90A8         ; per-LUN limit hi ($90A8)
cfg_0              = $90E0         ; Configuration byte 0
cfg_device         = $90E1         ; Device number
cfg_dev2           = $90E2         ; Second configuration (devnum)
cfg_def_part       = $90E3         ; Default partition
cfg_devflags       = $90E4         ; Device-number-change flags (b7 = software change)
cfg_scsi_id        = $90E5         ; SCSI target ID mask
cfg_sys_track      = $90E6         ; System partition track
cfg_sys_sector     = $90E7         ; System partition sector
cur_part           = $90E8         ; Currently selected partition number
part_dir_track     = $9100         ; Per-partition current-directory track
part_dir_sector    = $9200         ; Per-partition current-directory sector
parity_tbl         = $9300         ; Parity helper table ($9300-$93FF)

; ===========================================================================
; PRINT SPOOLER (new code, not in the original v1.92)
; Intercepts device 4 (printer) traffic on the main serial bus, stores it in the first type 6 (print
; buffer) partition and, while the drive is idle, plays it back out of the aux port (VIA1 port A).
; ===========================================================================
sp_dev             = $04     ; device number intercepted (LISTEN = $20 + this)
sp_ptr             = $72     ; ZP: pointer into the spool buffers ($72/$73)
sp_zb              = $74     ; ZP: relative block number lo/hi ($74/$75)
sp_t0              = $76     ; ZP: scratch
sp_t1              = $79     ; ZP: scratch
sp_t2              = $7A     ; ZP: scratch
sp_wbuf            = $3800   ; 512 byte write buffer (the tail block)
sp_rbuf            = $3A00   ; 512 byte read buffer (the head block when it is not the tail block)
sp_hbuf            = $3C00   ; 512 byte header block image
sp_stat            = $3E00   ; b7 ready, b6 write buffer dirty, b5 read buffer valid, b3 header dirty, b0 init tried
sp_retry           = $3E01   ; 16 bit init retry counter
sp_base            = $3E04   ; 24 bit absolute start block of the spool partition
sp_size            = $3E07   ; partition size in 512 byte blocks
sp_tblk            = $3E09   ; tail (write) block, relative to the partition
sp_toff            = $3E0B   ; tail offset in the block (0-511)
sp_hblk            = $3E0D   ; head (read) block
sp_hoff            = $3E0F   ; head offset in the block
sp_lsn             = $3E11   ; b7 set: this ATN burst addressed the spooler (device 4)
sp_aux             = $3E12   ; b7 set: a LISTEN session is open on the aux port
sp_rsa             = $3E13   ; secondary address of the aux session
sp_dec             = $3E14   ; stream decoder state (0 data, 1 after $FF, 2 expecting SA, 3 expecting EOI byte)
sp_rblk            = $3E15   ; block held in the read buffer
sp_wd              = $3E17   ; idle flush delay counter
sp_cnt             = $3E18   ; bytes left in this idle burst
sp_eoi             = $3E19   ; EOI flag of the byte being sent
sp_sav             = $3E1A   ; saved SCSI status
aux_din            = $01     ; PA0 AUX DATA IN
aux_dout           = $02     ; PA1 AUX DATA OUT
aux_cin            = $04     ; PA2 AUX CLK IN
aux_cout           = $08     ; PA3 AUX CLK OUT
aux_atn            = $10     ; PA4 AUX ATN OUT
sp_xs              = $3E1B   ; saved X in sp_put
sp_sa              = $3E1C   ; secondary address byte being recorded
sp_by              = $3E1D   ; byte being played
sp_bo              = $3E1E   ; 16 bit back-off counter after a printer failure

;------------------------------------------------------------------------------
; The original file is a PRG whose two-byte load address is $2000; the image
; itself executes at $9400-$FFFF.  Assemble as a plain binary to reproduce the
; original file byte for byte (drop the !word line to get the bare image).

;------------------------------------------------------------------------------
        !to "hdos_v1.92_symbolic.prg", plain

* = $93FE
        !word $2000                      ; PRG load address header of the original file


; ==========================================================================
; Start of the image ($9400).  The DOS begins with its copyright text; the
; first executable byte is the serial-bus ATN service at atn_service.
; ==========================================================================
; ---------------------------------------------------------------------------
; UNREFERENCED DATA ($93FE-$9449, 76 bytes)
; The first two bytes ($2000) are only the PRG load address of the original file and are not part of the
; ROM image. The text that follows is the copyright notice. No instruction or table ever reads it; it is
; there so the notice shows up in a ROM dump. A second copy sits at copyright_msg_2 ($FEA0).
; ---------------------------------------------------------------------------
copyright_msg                           ; $9400
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $9400

; --- atn_service: ATN handler: receive LISTEN/TALK/SECONDARY/UNLISTEN/UNTALK bytes and dispatch (via jt_atn_service)
; ATN service. The IEC bus ATN line was pulled (VIA1 CA1 edge via irq_handler, or the parallel
; cable's ATN on PB7). The host is sending a LISTEN/TALK/secondary address. We read command
; bytes until ATN is released, then run the listener or talker handler we were addressed as.
atn_service
        sei                      ; no interrupts while the bus is being handled
        cld
        ldx saved_sp             ; forget whatever the caller was doing: reset the stack to the saved top
        txs
        lda #$80                 ; $80 = "bus active" marker
        sta eoi_flag             ; assume EOI until a byte proves otherwise
        sta iec_state            ; iec_state b7: bus active, b6 cleared (ATN edge consumed)
        and xfer_mode            ; clear fast-protocol (burst/Jiffy) bits from xfer_mode, keep b7 as set above
        sta xfer_mode
        lda #$00
        jsr sp_atn_clear         ; SPOOLER: = STA par_mode (default to the serial bus) plus clearing the spooler flag
        lda bus_flags
        and #$3F                 ; ATN resets talker/listener: clear b7 (talk) and b6 (listen)
        sta bus_flags
        lda #$02                 ; $02 = CA1 flag, acknowledge the ATN edge in the VIA
        sta via1_ifr
        jsr sr_mode_in           ; shift register back to its normal (input) mode
        bit ppi_pb               ; PB7 on the 8255 = ATN from the parallel cable
        bpl atn_serial_atn_check
        jmp atn_par_atn_start
atn_serial_atn_check
        bit via1_prb             ; PB7 of VIA1 = ATN in; clear means ATN is already gone
        bpl atn_atn_released
        lda #$02                 ; DATA out low: tell the host we are present and listening
        sta via1_prb
atn_wait_clk_low
        lda via1_prb             ; wait for the host to pull CLK (ready to send)
        bpl atn_atn_released
        and #$04
        bne atn_wait_clk_low
atn_get_command_byte             ; get one byte sent under ATN
        jsr bus_get_atn_byte
atn_test_unlisten
        cmp #$3F                 ; $3F = UNLISTEN
        bne atn_test_untalk
        lda #$BF                 ; mask to clear bit 6 (listener) in bus_flags
        bne atn_clear_role
atn_test_untalk
        cmp #$5F                 ; $5F = UNTALK
        bne atn_test_talk_addr
        lda #$7F                 ; mask to clear bit 7 (talker) in bus_flags
atn_clear_role
        and bus_flags
        sta bus_flags
        lda #$00
        sta xfer_mode
        jmp atn_wait_atn_end     ; not a command for a data transfer, just wait for ATN to go away
atn_test_talk_addr
        cmp talk_addr            ; is this TALK + our device number?
        bne atn_test_listen_addr
        lda #$80                 ; $80 = become talker
        bne atn_set_role
atn_test_listen_addr
        jmp sp_atn_hook          ; SPOOLER: our own LISTEN, or device 4 when a print buffer is ready
        nop
atn_test_listen_ours
        lda #$40                 ; $40 = become listener
atn_set_role
        ora bus_flags            ; set the role bit...
        sta bus_flags
        ora #$3F                 ; ...and make sure the other role is cleared (never both at once)
        and bus_flags
        sta bus_flags
        lda cfg_def_part         ; every time we are addressed the default partition is selected again
        sta default_part
        jmp atn_more_atn_check
atn_test_secondary               ; not ours: maybe a secondary address ($60-$7F = data, $E0 = close, $F0 = open)
        tax
        and #$60                 ; top three bits must be 011 for a secondary address
        cmp #$60
        bne atn_not_our_address  ; not a secondary: another device was addressed
        stx cur_atn_byte         ; keep the raw byte for the open/close handlers
        txa
        and #$0F                 ; low nibble = channel (secondary address 0-15)
        sta cur_sa
        txa
        and #$F0                 ; high nibble tells open/close/data
        jmp sp_atn_sa            ; SPOOLER: record the SA for device 4, otherwise $E0 = CLOSE as before
        nop
atn_do_close
        cli
        jsr close_handler        ; CLOSE is done now, with interrupts enabled because it may take a while
        sei
atn_more_atn_check
        bit par_mode             ; parallel cable active? (par_mode b6)
        bvc atn_serial_more_atn
        bit ppi_pb               ; more ATN bytes coming on the parallel cable?
        bmi atn_get_command_byte
        bpl atn_atn_released
atn_serial_more_atn
        bit via1_prb             ; more ATN bytes coming on the serial bus?
        bmi atn_get_command_byte
atn_atn_released                 ; ATN has been released: turn the line around
        ldx #$00
        stx iec_state            ; bus is idle again
        lda via1_prb
        ora #$10                 ; ATN acknowledge line high (bit 4)
        sta via1_prb
        bit bus_flags            ; were we addressed as listener (bit 6)?
        bvc atn_test_talker
        bit xfer_mode            ; burst-capable host: switch the shift register to receive first
        bpl atn_do_listen
        jsr burst_listen_start
atn_do_listen
        jsr sp_listen_dispatch   ; SPOOLER: receive the data bytes (device 4 goes to the spooler)
        jmp atn_exit_to_idle
atn_test_talker                  ; are we the talker (bit 7)?
        bit bus_flags
        bpl atn_exit_to_idle
        bit par_mode             ; parallel cable: set port A to output before we send
        bvc atn_serial_talk_turnaround
        jsr par_port_output
        jmp atn_do_talk
atn_serial_talk_turnaround
        jsr bus_data_out_off     ; serial: release DATA, take CLK (the talker must hold CLK to send)
        jsr bus_clk_out_on
        jsr delay_short          ; short delay for the host to notice
atn_do_talk
        jsr jt_talk              ; send data bytes until the host stops us
        jsr delay_short
atn_exit_to_idle                 ; back to idle: release the parallel bus and put the shift register back
        jsr par_bus_release
        jsr sr_mode_in
        jmp jt_idle_loop
atn_not_our_address              ; another device was addressed. Stay off the bus.
        bit par_mode
        bvs atn_par_release_lines
        bit xfer_mode
        bvc atn_release_lines
        lda bus_flags            ; if we were talker or listener before, keep waiting and do not release
        and #$C0
        bne atn_wait_atn_end
atn_release_lines
        lda #$00                 ; release all lines so the other device can use the bus
        sta via1_prb
atn_wait_atn_end                 ; wait for ATN to go away
        bit par_mode
        bvs atn_wait_atn_end_par
atn_wait_atn_end_serial
        bit via1_prb
        bpl atn_atn_released
        bmi atn_wait_atn_end_serial
atn_par_release_lines            ; parallel: release the handshake outputs on port C
        lda ppi_pc
        ora #$E0
        sta ppi_pc
atn_wait_atn_end_par             ; wait for the parallel ATN to drop
        bit ppi_pb
        bpl atn_atn_released
        bmi atn_wait_atn_end_par
atn_par_atn_start                ; parallel cable ATN detected. Short settling delay first.
        ldx #$0A
atn_par_settle_delay
        dex
        bne atn_par_settle_delay
        lda #$40                 ; b6 of par_mode marks parallel operation
        sta par_mode
        lda ppi_pc               ; port C handshake outputs: PC7 off, PC6/PC5 on
        and #$7F
        ora #$60
        sta ppi_pc
        tax
        lda #$92                 ; $92 = 8255 mode 0, port A input, port B input, port C upper out
        sta ppi_ctrl
        stx ppi_pc
        jsr par_get_atn_byte
        jmp atn_test_unlisten

; --- par_send_byte: Parallel (8255) cable: send the byte for channel X to the host with handshake
; Send one byte from the channel buffer (chan_byte) to the host over the 8255 parallel
; cable. PB7 = ATN (abort), PB6 = host busy. PC7/PC6 are our data-ready strobes.
par_send_byte
        bit ppi_pb               ; ATN asserted by host: abort and go back to the ATN service
        bmi par_atn_abort
        bvs par_send_byte        ; wait until the host is ready for the next byte
        lda chan_byte,x          ; byte to send
        sta ppi_pa               ; put it on port A
        lda chan_flags,x
        and #$08                 ; chan_flags b3 set means this is the last byte (EOI): skip the extra strobe
        bne par_send_signal_data_ready
        lda ppi_pc               ; normal byte: pulse PC6 low, PC7 high before the data-ready strobe
        and #$BF
        sta ppi_pc
        ora #$80
        sta ppi_pc
        ldy #$28                 ; short delay so the host sees the pulse
par_send_strobe_delay
        dey
        bne par_send_strobe_delay
par_send_signal_data_ready
        lda ppi_pc               ; data-ready: PC7 and PC6 both high
        ora #$C0
        sta ppi_pc
        and #$7F                 ; PC7 low = data valid
par_send_wait_host_ack
        bit ppi_pb               ; wait for the host to acknowledge (PB6 goes high)
        bmi par_atn_abort
        bvc par_send_wait_host_ack
        sta ppi_pc               ; release the strobe
        rts
par_atn_abort                    ; ATN seen while handshaking: restart the ATN service
        jmp atn_service

; --- par_recv_byte: Parallel cable: receive one byte from the host with handshake
; Receive one byte from the host over the parallel cable into iec_byte.
par_recv_byte
        bit ppi_pb
        bmi par_atn_abort
        bvs par_recv_byte
        ldy ppi_pa               ; read the byte from port A
        sty iec_byte
        lda ppi_pc
        ora #$80                 ; acknowledge: PC7 high
        sta ppi_pc
        lda #$01                 ; bit mask for PB0 (PRDY IN), used as the EOI flag
par_recv_wait_host_strobe
        bit ppi_pb
        bmi par_atn_abort
        bne par_recv_flag_eoi    ; host asserted EOI with this byte
        bvc par_recv_wait_host_strobe
        lda ppi_pc
        and #$7F
        sta ppi_pc
        tya
        rts
par_recv_flag_eoi
        lda #$00                 ; EOI: eoi_flag = 0 (convention: $00 = last byte)
        sta eoi_flag
        beq par_recv_wait_host_strobe

; --- par_bus_release: Switch the 8255 to input and release the parallel handshake lines
; Release the parallel handshake lines (all outputs high, port A back to input).
par_bus_release
        php
        sei
        lda ppi_pc
        ora #$E0
        and #$7F
        tay
        ldx #$92                 ; $92 = port A input
        stx ppi_ctrl
        sta ppi_pc
        ora #$80
        bit ppi_pb
        bmi par_rel_atn_during_release ; ATN came in while releasing, finish by restarting the ATN service
        sta ppi_pc
        bit ppi_pb
        bpl par_rel_release_done
par_rel_atn_during_release
        sty ppi_pc
        jmp atn_service
par_rel_release_done
        plp
        rts

; --- par_port_output: Set 8255 port A to output mode
; Switch the 8255 so port A drives the data lines.
par_port_output
        lda ppi_pc
        ldx #$82                 ; $82 = mode 0, port A output
        stx ppi_ctrl
        sta ppi_pc
        rts

; --- bus_get_atn_byte: Read a byte under ATN (serial or parallel, depending on par_mode)
bus_get_atn_byte
        bit par_mode
        bvc getatn_serial_get_byte

; --- par_get_atn_byte: Read an ATN-time byte over the parallel cable
; Read one command byte under ATN from the parallel cable (8255 port A).
par_get_atn_byte
        lda ppi_pc               ; PC7 high = we are not ready yet
        ora #$80
        sta ppi_pc
getatn_wait_host_data            ; wait for the host to present a byte (PB6 low = valid)
        bit ppi_pb
        bpl getatn_par_atn_gone  ; ATN dropped while waiting
        bvs getatn_wait_host_data
        ldy ppi_pa               ; byte from port A
        sty iec_byte
        lda #$01
        bit ppi_pb               ; PB0 (PRDY IN) set: this byte is an address (LISTEN/TALK), not data
        beq getatn_ack_atn_byte
        cpy talk_addr            ; only accept addresses meant for this device
        beq getatn_ack_atn_byte
        cpy listen_addr
        beq getatn_ack_atn_byte
        jmp atn_par_release_lines ; someone else's address: release the lines and wait
getatn_ack_atn_byte
        lda ppi_pc               ; PC7 low = byte accepted
        and #$7F
        sta ppi_pc
getatn_wait_host_release         ; wait for the host to release the strobe
        bit ppi_pb
        bpl getatn_par_atn_gone
        bvc getatn_wait_host_release
        tya
        bit bus_flags            ; are we the listener already?
        bvc getatn_to_secondary_handling
        cmp #$60                 ; secondary $60 over the parallel cable is turned into $61 below
        bne getatn_to_secondary_handling
        sta par_mode             ; par_mode = $60: remember that this transfer is parallel
        lda #$61                 ; $61 makes the stream-file code treat this as a fast sector load
        sta iec_byte
getatn_to_secondary_handling
        jmp getatn_finish_atn_byte
getatn_par_atn_gone
        jmp atn_atn_released
; Serial version of the same thing: read one byte under ATN with the standard IEC
; handshake (talker releases CLK, we release DATA, 8 bits clocked on CLK edges, EOI by timeout).
getatn_serial_get_byte
        lda #$08                 ; eight bits to come
        sta bit_count
getatn_wait_talker_clk_released  ; wait until the talker releases CLK (it is ready to send)
        jsr bus_read_clk
        bne getatn_wait_talker_clk_released
        jsr bus_data_out_off     ; release DATA: we are ready for data
        lda #$01
getatn_wait_data_released        ; wait for DATA to be released by all listeners
        bit via1_prb
        bne getatn_wait_data_released
        ldx #$0A                 ; timeout counter for the EOI test
getatn_eoi_timeout_loop
        jsr bus_poll_atn         ; keep polling ATN while we wait
        dex
        beq getatn_eoi_acknowledge
        jsr bus_read_stable      ; read CLK in a stable way
        and #$04                 ; CLK high again before the timeout: no EOI, go on with the bits
        beq getatn_eoi_timeout_loop
        bne getatn_bit_loop_start ; always taken
getatn_eoi_acknowledge           ; CLK stayed low for > 200us: the talker signals EOI. Acknowledge it by pulsing DATA.
        jsr bus_data_out_on      ; DATA low...
        ldx #$18                 ; ...for about 60us
getatn_eoi_ack_delay
        dex
        bne getatn_eoi_ack_delay
        jsr bus_data_out_off     ; ...then release it again
getatn_wait_clk_after_eoi
        jsr bus_read_clk         ; wait for the talker to continue (CLK high)
        beq getatn_wait_clk_after_eoi
        lda #$00                 ; eoi_flag = 0 means this is the last byte
        sta eoi_flag
getatn_bit_loop_start
        ldx #$1A                 ; per-bit timeout counter
getatn_wait_clk_bit
        lda via1_prb             ; sample the bus
        tay
        and #$04                 ; CLK still asserted? (bit 2)
        beq getatn_shift_in_bit  ; CLK went away: the bit is valid, shift it in
        dex                      ; count down while waiting for the bit
        bne getatn_wait_clk_bit
        lda #$3F                 ; timed out waiting for the next bit. Check for a fast-protocol request.
        bit xfer_mode            ; test xfer_mode flags (b7 burst, b6 Jiffy)
        bmi getatn_reset_timeout ; burst already active: just keep waiting
        bvs getatn_check_fast_protocol_addr ; Jiffy already detected: check whether the address is ours
        bne getatn_reset_timeout ; any other flag set (A and mode <> 0): keep waiting
        ldx bit_count            ; first bit of the byte?
        cpx #$01
        beq getatn_check_fast_protocol_addr ; yes: the host is probing, check the address now
        ldx #$01                 ; not yet a probe: mark it as a candidate (xfer_mode = 1) and wait again
        stx xfer_mode
        dex
        beq getatn_wait_clk_bit
getatn_check_fast_protocol_addr  ; a probe only counts if the address received so far is ours
        lda iec_byte             ; iec_byte has the high 7 bits of the address shifted in so far
        lsr                      ; drop the unfinished bit
        cmp listen_addr          ; our listen address?
        beq getatn_fast_protocol_ack
        cmp talk_addr            ; our talk address?
        bne getatn_reset_timeout
getatn_fast_protocol_ack
        lda #$40                 ; $40 = Jiffy-style fast protocol is accepted
        sta xfer_mode
        ldx #$1E                 ; acknowledge by pulsing DATA...
        jsr bus_data_out_on      ; ...low for a short time...
getatn_fast_ack_delay
        dex
        bne getatn_fast_ack_delay
        jsr bus_data_out_off     ; ...then released
getatn_reset_timeout
        ldx #$00                 ; reset the timeout and carry on with the bits
        beq getatn_wait_clk_bit
getatn_shift_in_bit
        tya                      ; data bit comes in on bit 0 of the sampled PRB (inverted bus)
        eor #$01                 ; invert it
        lsr                      ; move it into carry
        ror iec_byte             ; shift it into the byte, LSB first
getatn_wait_clk_release_after_bit
        jsr bus_read_clk         ; wait for the talker to release CLK
        beq getatn_wait_clk_release_after_bit
        dec bit_count            ; next bit
        bne getatn_bit_loop_start
        jsr bus_data_out_on      ; byte complete: DATA low = byte received
        lda iec_byte             ; the finished byte
        bne getatn_finish_atn_byte ; non-zero byte: normal path
        lda #$80                 ; byte $00: keep only the burst bit of xfer_mode
        and xfer_mode
        sta xfer_mode
        lda #$00                 ; return $00
getatn_finish_atn_byte
        bit xfer_mode            ; burst mode already active?
        bmi getatn_byte_done
        cmp #$61                 ; secondary address $61 (talk to channel 1, fast sector load)?
        bne getatn_byte_done
        bit bus_flags            ; only if we are the talker
        bpl getatn_byte_done
        sta xfer_mode            ; xfer_mode = $61: sector streaming mode
        lda #$60                 ; and pretend it was the normal secondary $60
        sta iec_byte
getatn_byte_done
        rts

; --- bus_read_clk: Read VIA1 PRB and isolate CLK IN (bit 2)
; Read PRB and isolate CLK IN (bit 2). Z set = CLK low (released).
bus_read_clk
        jsr bus_poll_atn         ; also checks ATN
        and #$04
        rts

; --- bus_wait_data_high: Wait until DATA IN is high (polling ATN)
; Wait until DATA IN is high (bit 0 after ror). ATN is polled each time.
bus_wait_data_high
        jsr bus_poll_atn
        ror                      ; bit 0 into carry
        bcc bus_wait_data_high
        rts

; --- bus_wait_data_low: Wait until DATA IN is low (polling ATN)
; Wait until DATA IN is low.
bus_wait_data_low
        jsr bus_poll_atn
        ror
        bcs bus_wait_data_low
        rts

; --- bus_poll_atn: Read the bus; jump to ATN service if ATN asserted
; Poll the bus. Returns the PRB value in A. If ATN is asserted while the bus was idle the ATN
; service is started; if ATN has just been released it jumps to the release handler.
bus_poll_atn
        bit iec_state            ; bus active?
        bpl poll_idle_check_atn
        lda via1_prb             ; ATN still low? (bit 7)
        bpl poll_atn_released_exit ; ATN gone: finish the ATN sequence
poll_no_atn_return
        rts
poll_idle_check_atn
        lda via1_prb             ; bus idle: has someone pulled ATN?
        bpl poll_no_atn_return
        jmp jt_atn_service       ; yes, run the ATN service
poll_atn_released_exit
        jmp atn_atn_released

; --- bus_data_out_off: Release DATA OUT (clear PRB bit 1)
; Release DATA OUT (PB1 low).
bus_data_out_off
        lda via1_prb
        and #$FD
        sta via1_prb
        rts

; --- bus_data_out_on: Assert DATA OUT (set PRB bit 1)
; Pull DATA OUT (PB1 high).
bus_data_out_on
        lda via1_prb
        ora #$02
        sta via1_prb
        rts

; --- bus_clk_out_off: Release CLK OUT (clear PRB bit 3)
; Release CLK OUT (PB3 low).
bus_clk_out_off
        lda via1_prb
        and #$F7
        sta via1_prb
        rts

; --- bus_clk_out_on: Assert CLK OUT (set PRB bit 3)
; Pull CLK OUT (PB3 high).
bus_clk_out_on
        lda via1_prb
        ora #$08
        sta via1_prb
        rts

; --- bus_read_stable: Read VIA1 PRB until two consecutive reads agree
; Read PB until two reads give the same value (the bus may be changing).
bus_read_stable
        lda via1_prb
        cmp via1_prb
        bne bus_read_stable
        rts

; --- burst_listen_start: Prepare the VIA1 shift register for a burst transfer, wait for the byte
; Wait for the burst talker to release CLK, then clock one byte in on the shift register.
burst_listen_start
        jsr bus_read_clk         ; CLK still asserted?
        bne burst_listen_start
        jsr sr_mode_out          ; prepare the shift register for shift-in
        lda #$00
        sta via1_sr              ; a write to SR starts the shift
        lda #$04                 ; IFR bit 2 = shift register complete
burst_start_wait_sr_done
        bit via1_ifr
        beq burst_start_wait_sr_done

; --- sr_mode_in: VIA1 SR: shift-in mode under external clock, fast-serial direction = input
; Shift register: shift in under external clock (CB1), for receiving burst bytes.
sr_mode_in
        php
        sei
        lda via1_acr
        and #$E3                 ; clear mode bits 2-4
        sta via1_acr
        ora #$0C
        sta via1_acr             ; mode 011 = shift in under external clock
        lda via1_prb
        and #$DF                 ; PB5 low = fast-serial direction input
        sta via1_prb
        bit via1_sr              ; reading SR clears the flag and starts a shift
        plp
        rts

; UNREACHABLE: 2 byte alternate entry (BCC to sr_mode_in), never used.
; --- sr_mode_in_alt: (unreferenced alternate entry of sr_mode_in)
sr_mode_in_alt
        bcc sr_mode_in

; --- sr_mode_out: VIA1 SR: shift-out mode, fast-serial direction = output
; Shift register: shift out under external clock, for sending burst bytes.
sr_mode_out
        php
        sei
        lda via1_prb
        ora #$20                 ; PB5 high = fast-serial direction output
        sta via1_prb
        lda via1_acr
        and #$E3
        sta via1_acr
        ora #$14                 ; mode 111 = shift out under external clock
        sta via1_acr
        plp
        rts

; --- delay_short: Short fixed delay preserving A and X
; Fixed timing delays used by the bus code. They keep A and X.
delay_short
        txa                      ; save X in A
        nop
        ldx #$0C                 ; about 12 loop passes
        bne delay_delay_loop

; --- delay_long: Longer fixed delay preserving A and X
delay_long
        txa
        ldx #$1D                 ; about 29 loop passes
delay_delay_loop
        dex
        bne delay_delay_loop
        tax
        rts
; Burst talker, last byte of a block: signal EOI by releasing CLK and waiting for the listener's
; DATA handshake, the same way the standard protocol does.
burst_talk_send_eoi_signal
        bit via1_prb
        bmi burst_talk_atn_abort
        jsr bus_clk_out_off      ; release CLK: "ready to send"
        jsr bus_wait_data_low    ; listener pulls DATA...
        jsr bus_wait_data_high   ; ...and releases it again
        lda #$01
        bne burst_talk_wait_data_ack

; --- burst_talk_byte: Send the channel byte using the burst (shift-register) protocol
; Send one byte to the host with the VIA1 shift register (fast serial). The byte is clocked out
; on CB1/CB2 by the shift register while the handshake is done on CLK/DATA.
burst_talk_byte
        lda chan_flags,x         ; b3 of the channel flags = this is the last byte
        and #$08
        beq burst_talk_send_eoi_signal ; last byte: use the slow EOI handshake first
        lda via1_prb
        and #$01                 ; check DATA IN
        beq burst_talk_send_eoi_signal
        ora #$10                 ; ATN acknowledge line high
        sta via1_prb
        and #$01                 ; bit 0 mask for the DATA test
burst_talk_wait_data_ack
        bit via1_prb             ; wait until the host pulls DATA (ready)
        bmi burst_talk_atn_abort
        bne burst_talk_wait_data_ack
        lda #$38                 ; CLK out and DATA out high, ready to shift
        sta via1_prb
        lda via1_acr             ; set the shift register to shift out
        and #$E3
        sta via1_acr
        ora #$14                 ; mode 101 = shift out under T2 control
        sta via1_acr
        lda chan_byte,x          ; byte to send
        sta via1_t2ch            ; the T2 high byte is the shift rate
        sta via1_sr              ; writing SR starts the transfer
        lda #$04                 ; IFR bit 2 = shift complete
burst_talk_wait_shift_done
        bit via1_ifr
        beq burst_talk_wait_shift_done
        lda via1_acr             ; switch the shift register mode back
        eor #$18
        sta via1_acr
        lda #$18
        sta via1_prb             ; bus lines back to idle
        lda #$01                 ; bit 0 = DATA IN
burst_talk_wait_listener_ack
        bit via1_prb             ; wait for the listener to acknowledge the byte
        bmi burst_talk_atn_abort
        beq burst_talk_wait_listener_ack
        rts
burst_talk_atn_abort             ; ATN while sending: restart the ATN service
        jmp jt_atn_service

; --- jiffy_talk_byte: Send the channel byte using the nibble-table fast protocol
; Send the channel byte with the JiffyDOS-style nibble protocol. Four bits are sent on each
; CLK/DATA clock pair using jiffy_send_nibbles to convert a nibble into a bus pattern.
jiffy_talk_byte
        jsr jiffy_talk_prepare
        and #$02                 ; bit 1 = DATA from the host, the last handshake
        beq jiffy_talk_done
        lda iec_tmp_a            ; a last bus pattern is written after the byte
        ora #$0D
        jsr bus_write_wait
jiffy_talk_done
        rts

; --- jiffy_talk_prepare: Prepare the bus and tables for a fast-protocol byte send
; Get the bus ready for a fast-protocol byte: build the two idle patterns in iec_tmp_a and iec_tmp_b.
jiffy_talk_prepare
        lda via1_prb
        and #$7D                 ; keep only the output bits we own
        sta iec_tmp_b
        and #$71
        sta iec_tmp_a
        lda chan_flags,x         ; EOI (last byte) flag
        and #$08
        bne jiffy_prep_load_byte
        lda iec_tmp_a
        ora #$03                 ; not the last byte: second pattern differs by DATA and CLK
        sta iec_tmp_b
jiffy_prep_load_byte
        lda chan_byte,x          ; byte to send
        ldx iec_tmp_a
        bit via1_prb             ; ATN check
        bmi jiffy_prep_atn_abort
        stx via1_prb
        ldy #$FF                 ; Y = $FF so the next byte index wraps to 0
        bne jiffy_send_send_byte_nibbles
jiffy_prep_atn_abort
        jmp jt_atn_service

; --- jiffy_send_buf_byte: Send the byte at ($68),Y via the fast nibble protocol
; Send the byte(s) at ($68),Y with the fast nibble protocol. Y is the first offset; the loop
; runs until Y wraps, so a whole page is sent. Timing between the VIA writes matters: the host
; reads the bus at fixed cycle counts, do not change the order or add instructions here.
jiffy_send_buf_byte
        lda via1_prb
        and #$70                 ; keep our output bits
        sta iec_tmp_a
        ora #$0D
        sta iec_tmp_b
        ora #$02                 ; CLK/DATA both high: start of byte
        sta via1_prb
        eor #$0D
        sta via1_prb
        ldx #$0E                 ; wait about 40us for the host to be ready
jiffy_send_startup_delay
        dex
        bne jiffy_send_startup_delay
jiffy_send_next_buffer_byte
        lda (buf_ptr_b),y        ; next byte of the buffer
jiffy_send_send_byte_nibbles
        tax                      ; split the byte into two nibbles
        lsr
        lsr
        lsr
        lsr
        sta tmp_6c               ; high nibble kept in tmp_6c
        txa
        and #$0F                 ; low nibble first
        tax
        lda jiffy_send_nibbles,x ; convert the nibble into the bus pattern
        ldx iec_tmp_a
        jsr cyc_delay_12
        stx via1_prb
        bit via1_prb
jiffy_send_wait_clock_edge
        cpx via1_prb             ; wait for the host to change the bus (its clock edge)
        beq jiffy_send_wait_clock_edge
        pha
        pla
        nop
        sta via1_prb
        asl
        ora #$10
        and #$1F
        pha
        pla
        bit $00                  ; BIT $00: 3 cycle delay
        sta via1_prb
        ldx tmp_6c
        lda jiffy_send_nibbles,x ; now the high nibble
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
        ldx #$00                 ; X = 0 for the last pattern index
        iny
        sta via1_prb
        bne jiffy_send_next_buffer_byte ; loop until Y wraps (256 bytes)
        lda iec_tmp_b,x
        jsr cyc_delay_none

; --- bus_write_wait: Write PRB and wait until the bus matches
; Write A to the bus and wait until the bus reads back the same value.
bus_write_wait
        sta via1_prb
bus_write_wait_wait_bus_match
        bit via1_prb
        cmp via1_prb
        bcc jiffy_prep_atn_abort ; ATN was asserted
        bne bus_write_wait_wait_bus_match
        rts

; --- cyc_delay_12: Fixed 12-cycle timing delay
; Delays that waste cycles with a BIT on a harmless address.
cyc_delay_12
        bit timing_dummy

; --- cyc_delay_8: Fixed 8-cycle timing delay
cyc_delay_8
        bit timing_dummy
        bit timing_dummy

; --- cyc_delay_none: RTS used as a timing stub
cyc_delay_none
        rts
; --- jiffy_send_nibbles: Fast-protocol nibble -> bus pattern table (send)
; Lookup table: nibble value -> pattern to put on CLK/DATA/ATN-ack, send direction.
jiffy_send_nibbles
        !byte $1F,$17,$1D,$15,$1B,$13,$19,$11 ; $990C
        !byte $1E,$16,$1C,$14,$1A,$12,$18,$10 ; $9914
; --- jiffy_recv_nibbles: Fast-protocol bus pattern -> nibble table (receive)
; Lookup table: pattern seen on the bus -> nibble, receive direction.
jiffy_recv_nibbles
        !byte $00,$80,$20,$A0,$40,$C0,$60,$E0 ; $991C
        !byte $10,$90,$30,$B0,$50,$D0,$70,$F0 ; $9924

; --- burst_listen_byte: Receive a byte with the burst (shift-register) protocol
; Receive one byte with the VIA1 shift register (burst protocol).
burst_listen_byte
        bit via1_sr              ; clear any pending shift flag
        lda #$04
burst_listen_wait_clk_ready
        bit via1_prb             ; wait until the talker releases CLK
        bmi burst_listen_atn_abort
        bne burst_listen_wait_clk_ready
        ora #$10                 ; ATN acknowledge line high = ready
        sta via1_prb
        ldx #$80                 ; timeout counter for the EOI test
        lda #$04
burst_listen_wait_clk_or_eoi_timeout
        bit via1_prb             ; CLK edge arrives: the shift register will clock the byte in
        bmi burst_listen_atn_abort
        bne burst_listen_receive_shift_register
        dex
        bne burst_listen_wait_clk_or_eoi_timeout
        lda #$08                 ; timeout: the talker wants EOI, use the standard handshake
        sta bit_count
        jmp iec_listen_eoi_acknowledge
burst_listen_receive_shift_register
        ldx #$12                 ; bus value to restore when done
        lda #$04
burst_listen_wait_sr_complete
        bit via1_ifr             ; wait for the shift register to complete
        beq burst_listen_wait_sr_complete
burst_listen_read_sr_byte
        lda via1_sr              ; byte from SR
        stx via1_prb             ; restore bus lines
        sta iec_byte
        rts
burst_listen_atn_abort
        jmp jt_atn_service

; --- jiffy_listen_byte: Receive a byte with the nibble-table fast protocol
; Receive one byte with the nibble protocol: two bus reads (4 bits each) combined with the table.
jiffy_listen_byte
        lda #$14                 ; CLK/ATN-ack out, DATA released
        sta via1_prb
        and #$04
jiffy_listen_wait_clk_ready
        bit via1_prb             ; wait for the talker's clock
        bne jiffy_listen_wait_clk_ready
        jsr cyc_delay_12
        lda via1_prb             ; first two bits
        asl                      ; shifted into place
        jsr cyc_delay_8
        ora via1_prb             ; next two bits
        and #$0F                 ; 4-bit value
        tax
        ldy #$00
        jsr cyc_delay_none
        lda via1_prb
        asl
        jsr cyc_delay_8
        ora via1_prb
        and #$0F
        ora jiffy_recv_nibbles,x ; combine with the second nibble from the table
        sta iec_byte
        jsr cyc_delay_none
        lda via1_prb             ; final handshake read: DATA says last byte or not
        bit iec_byte
        bit iec_byte
        ora #$02
        sta via1_prb             ; DATA low = byte received
        bmi burst_listen_atn_abort
        and #$04                 ; CLK high at this moment means EOI was not signalled
        bne jiffy_listen_return_byte
        sty eoi_flag             ; EOI: eoi_flag = 0
jiffy_listen_return_byte
        lda iec_byte
        rts

; --- iec_talk_byte: Standard IEC: send the channel byte bit by bit
; Standard IEC talker: send the byte for channel X one bit at a time. CLK/DATA are
; handshaked by hand with fixed delays (the 1541 timings), 8 bits LSB first.
iec_talk_byte
        lda #$08
        sta bit_count            ; eight bits to send
        lda via1_prb
        and #$F7                 ; release CLK (it was asserted while ready)
        sta via1_prb
        lsr                      ; bit 0 (DATA in) to carry
        bcc iec_talk_wait_listener_ready ; DATA already high: the listener is ready, no wait needed
        jsr bus_wait_data_low    ; wait until the listener is ready for the first byte
        lda chan_flags,x
        and #$08                 ; last byte (EOI)? Then CLK is held for the EOI delay before sending
        bne iec_send_bits
iec_talk_wait_listener_ready
        jsr bus_wait_data_high
        jsr iec_send_bits
        ldx #$32                 ; about 50 polls for the listener to take the byte
iec_talk_wait_data_release_loop
        jsr bus_poll_atn
        and #$01                 ; DATA released again: byte accepted
        beq rts_stub
        dex
        bne iec_talk_wait_data_release_loop

; --- rts_stub: Plain RTS
rts_stub
        rts

; --- iec_send_bits: Standard IEC: shift 8 data bits out
; Shift the 8 data bits of chan_byte,X onto the bus. CLK is released with each bit.
iec_send_bits
        jsr bus_clk_out_on       ; CLK asserted: starting to send
        jsr delay_short
        jsr bus_wait_data_low    ; listeners must have DATA low before we start
        jsr rts_stub
iec_send_send_bit_loop
        jsr delay_short
        ror chan_byte,x          ; next bit of the byte into carry
        jsr rts_stub
        jsr bus_data_out_off
        bcs iec_send_output_bit  ; bit = 1: leave DATA released
        ora #$02                 ; bit = 0: pull DATA
iec_send_output_bit
        sta via1_prb             ; put the data bit on the bus
        jsr bus_clk_out_off      ; CLK released: the bit is valid
        jsr delay_short
        txa
        ldx #$0B                 ; hold the bit for about 60us
iec_send_bit_hold_delay
        dex
        bne iec_send_bit_hold_delay
        tax
        lda via1_prb             ; restore CLK asserted, DATA released
        ora #$08
        and #$FD
        sta via1_prb
        dec bit_count
        bne iec_send_send_bit_loop
        jmp bus_wait_data_high   ; wait until the listener acknowledges the byte

; --- iec_listen_byte: Standard IEC: receive a byte bit by bit
; Standard IEC listener: receive a byte into iec_byte (LSB first) with EOI detection.
iec_listen_byte
        bit via1_sr              ; clear any pending shift flag
        lda #$08
        sta bit_count
iec_listen_wait_talker_ready
        jsr bus_read_clk         ; wait until the talker releases CLK
        bne iec_listen_wait_talker_ready
        jsr bus_data_out_off     ; we are ready for data
        lda #$01
iec_listen_wait_data_free        ; wait for all listeners to release DATA
        bit via1_prb
        bmi iec_listen_atn_abort
        bne iec_listen_wait_data_free
        ldx #$14                 ; timeout counter ~200us for EOI
iec_listen_eoi_timeout_loop
        jsr bus_read_clk
        bne iec_listen_bit_loop  ; CLK went low again before the timeout: no EOI
        dex
        bne iec_listen_eoi_timeout_loop
iec_listen_eoi_acknowledge       ; CLK stayed high for too long: the talker is signalling EOI
        jsr bus_data_out_on      ; acknowledge by pulsing DATA
        jsr delay_long
        jsr bus_data_out_off
iec_listen_wait_clk_after_eoi
        jsr bus_read_clk
        beq iec_listen_wait_clk_after_eoi
        lda #$00                 ; EOI: eoi_flag = 0
        sta eoi_flag
iec_listen_bit_loop
        ldx via1_prb             ; read the bus
        lda #$04
        bit via1_ifr             ; has the shift register completed (fast host)?
        beq iec_listen_shift_in_bit ; no: normal bit-by-bit mode
        ldx #$12                 ; a burst byte arrived: restore the line state and read SR
        jmp burst_listen_read_sr_byte
iec_listen_shift_in_bit
        txa
        and #$04                 ; CLK high = data valid?
        bne iec_listen_bit_loop
        txa
        eor #$01                 ; invert (data lines are inverted)
        lsr                      ; bit 0 to carry
        ror iec_byte             ; shift in, LSB first
iec_listen_wait_clk_release_after_bit
        jsr bus_read_clk         ; wait for the talker to release CLK
        beq iec_listen_wait_clk_release_after_bit
        dec bit_count            ; 8 bits done?
        bne iec_listen_bit_loop
        jsr bus_data_out_on      ; DATA low: byte received
        lda iec_byte
iec_listen_done
        rts
iec_listen_atn_abort
        jmp jt_atn_service

; --- nmi_handler: NMI: ignore if the command buffer starts with '+'/'-', else warm start
; NMI. When the command buffer holds a command starting with '+' or '-' the NMI is ignored
; (a debugging hook); otherwise it does a warm start.
nmi_handler
        lda cmd_buf+2            ; second character of the command buffer
        cmp #$2B
        beq iec_listen_done
        cmp #$2D
        beq iec_listen_done
        jmp jt_warm_start
; --- stream_file_serial: Stream a file chain to the host over the serial bus (link-byte driven)
; Stream a file to a JiffyDOS-style host. The file's blocks are read one after another by
; following the link bytes in each block; each block's data bytes are sent with the fast
; protocol. The last block carries a byte count instead of a next sector.
stream_file_serial
        jsr bus_wait_data_low    ; wait for the host to be ready
        lda #$04
stream_ser_block_loop
        tax
        lda buf_ptr_b_hi         ; keep the buffer page across the send
        pha
        txa
        pha
        ldy #$01                 ; link bytes: Y = 1 is the sector, Y = 0 the track
        lda (buf_ptr_b),y
        sta cur_sector
        tax
        dey
        lda (buf_ptr_b),y
        sta cur_track
        bne stream_ser_send_block_data ; track <> 0: full block, send from byte 2 on
        pla                      ; last block: the sector byte is the number of the last used byte
        clc
        sbc cur_sector           ; compute the start offset so the loop ends at the last byte
        inx
        stx buf_ptr_b            ; new buffer start offset
        beq stream_ser_push_start_offset
        dec buf_ptr_b_hi
stream_ser_push_start_offset
        pha
stream_ser_send_block_data
        pla                      ; Y = start offset
        tay
        jsr jiffy_send_buf_byte  ; send the rest of the page
        pla
        sta buf_ptr_b_hi
        lda cur_track
        beq stream_file_last_block ; track 0 = no more blocks
        jsr stream_read_next     ; read the next block into the buffer
        lda #$02
        bne stream_ser_block_loop
; --- stream_file_last_block: Send the last partial block of a streamed file (serial)
; Last block sent. Copy what is left of the buffer to the job buffer so the caller has it.
stream_file_last_block
        sta buf_ptr_b
        jsr stream_delay_b
        jsr stream_delay_b
        jsr stream_delay_a
        ldy #$00
stream_last_copy_remainder_loop
        lda (buf_ptr_b),y        ; copy 256 bytes from the sector buffer to the job buffer
        sta (buf_ptr_a),y
        iny
        bne stream_last_copy_remainder_loop
        rts

; --- stream_delay_a: Streaming timing helper
; Timing helpers used between blocks.
stream_delay_a
        jsr bus_clk_out_on       ; CLK asserted for a moment so the host knows the block is done

; --- stream_delay_b: Streaming timing helper
stream_delay_b
        ldx #$28                 ; about 100us
stream_delay_delay_loop
        dex
        bne stream_delay_delay_loop
        jmp bus_clk_out_off

; --- stream_read_next: Read the next block of the streamed chain
; Read the block whose track/sector are in cur_track/cur_sector into the streaming buffer.
stream_read_next
        jsr ts_to_job_chan
        tya
        lsr
        tax
        lda #$AA                 ; $AA = read job, no wait for host
        jmp do_job
; --- stream_file_parallel: Stream a file chain to the host over the parallel cable
; Stream a file over the parallel cable. Same idea as the serial stream, but each byte goes to
; port A with a handshake, and the count of bytes is sent first.
stream_file_parallel
        lda #$04
stream_par_block_loop
        pha
        ldy #$01
        lda (buf_ptr_b),y        ; link bytes
        sta cur_sector
        tax
        dey
        lda (buf_ptr_b),y
        sta cur_track
        beq stream_par_last_block_count ; track = 0 means this is the last block
        pla
        pha
        eor #$FF                 ; negative offset gives how many bytes to send (256 - start)
        tax
        inx
        bne stream_par_send_block
stream_par_last_block_count      ; last block: count is the sector byte - 1 (link bytes not counted)
        dex
        pla
        pha
        cmp #$02                 ; start at offset 2?
        beq stream_par_send_block
        dex                      ; skip the two link bytes
        dex
stream_par_send_block
        pla
        jsr par_send_block       ; send the block
        lda cur_track
        beq stream_par_send_end_marker ; more blocks?
        jsr stream_read_next_par ; read the next block
        lda #$02
        bne stream_par_block_loop
stream_par_send_end_marker
        lda #$00                 ; after the last block send a $00 marker

; --- par_send_one: Send a single byte over the parallel cable
; Send the single byte in A over the parallel cable.
par_send_one
        bit ppi_pb               ; ATN asserted: abort
        bmi par_stream_atn_abort
        bvs stream_par_send_end_marker ; host busy: wait
        sta ppi_pa               ; put the byte on port A
        lda ppi_pc
        ora #$80
        sta ppi_pc               ; data-ready strobe
par_send_one_wait_host_ack
        bit ppi_pb               ; wait for the host acknowledge
        bmi par_stream_atn_abort
        bvc par_send_one_wait_host_ack
        and #$7F
        sta ppi_pc
        ldx #$28                 ; short settle delay
par_send_one_settle_delay
        dex
        bne par_send_one_settle_delay
        rts
par_stream_atn_abort
        jmp atn_service

; --- par_send_block: Send a block (X bytes from ($68),Y) over the parallel cable
; Send X bytes of the buffer at ($68),Y over the parallel cable. The first byte is the
; count, then the data bytes. The handshake alternates between two states so that
; each byte only needs one wait on PB6.
par_send_block
        tay
par_send_block_wait_host_ready_first
        bit ppi_pb
        bmi par_stream_atn_abort
        bvs par_send_block_wait_host_ready_first
        stx ppi_pa               ; first byte on the bus is the count
        lda ppi_pc
        ora #$80
        sta ppi_pc
par_send_block_wait_host_ack_first
        bit ppi_pb
        bmi par_stream_atn_abort
        bvc par_send_block_wait_host_ack_first
        lda (buf_ptr_b),y        ; first data byte
        sta ppi_pa
        lda ppi_pc
        and #$7F
        sta ppi_pc
        dex
        beq par_send_block_final_wait_busy ; X = 1: only one byte to send
par_send_block_next_byte
        iny
        lda (buf_ptr_b),y
par_send_block_wait_host_busy
        bit ppi_pb
        bvs par_send_block_wait_host_busy
        sta ppi_pa
        dex
        beq par_send_block_final_wait_ready
        iny
        lda (buf_ptr_b),y
par_send_block_wait_host_ready
        bit ppi_pb
        bvc par_send_block_wait_host_ready
        sta ppi_pa
        dex
        bne par_send_block_next_byte
par_send_block_final_wait_busy
        bit ppi_pb
        bvs par_send_block_final_wait_busy
par_send_block_final_wait_ready
        bit ppi_pb
        bvc par_send_block_final_wait_ready
        rts

; --- stream_read_next_par: Read next block (parallel streaming), job error on failure
; Read the next block for the parallel stream; if the job fails send $FF to the host first so
; it knows the transfer broke, then report the error.
stream_read_next_par
        jsr ts_to_job_chan
        tya
        lsr
        tax
        lda #$AA                 ; $AA = read job code
        jsr do_job_status
        bcs stream_next_par_send_error_marker
        rts
stream_next_par_send_error_marker
        pha
        txa
        pha
        lda #$FF                 ; $FF = error marker for the host
        jsr par_send_one
        pla
        tax
        pla
        jmp jt_job_error
; --- par_save_start: Start of a parallel-cable block save from the host
; Receive a file from the host over the parallel cable and write it block by block.
par_save_start
        lsr par_flags            ; clear the "first half of a 512-byte block pending" flag
        ldy #$00
        jsr par_set_buf_ptr
        lda #$04                 ; data starts after the 2 link bytes: first block uses offset 4?
        !byte $2C                ; BIT trick: skips the next LDA
; --- par_save_next_block: Receive the next block from the host (parallel)
par_save_next_block
        lda #$02                 ; following blocks start at offset 2 (after the link bytes)
        pha
        jsr par_recv_byte        ; the host first sends the byte count of this block
        tax                      ; X = number of bytes to receive
        pla
        tay
par_save_wait_host_busy_first    ; wait for the host to present the byte
        bit ppi_pb
        bvs par_save_wait_host_busy_first
        lda ppi_pa
        sta (buf_ptr_a),y        ; store into the channel buffer
        iny
        dex
        beq par_save_block_received_wait_ready
par_save_wait_host_ready         ; second state of the two-phase handshake
        bit ppi_pb
        bvc par_save_wait_host_ready
        lda ppi_pa
        sta (buf_ptr_a),y
        iny
        dex
        bne par_save_wait_host_busy_first
par_save_block_received_wait_ready ; block complete: wait for the host to finish
        bit ppi_pb
        bmi par_save_atn_abort
        bvc par_save_block_received_wait_ready
        jsr par_store_offset     ; remember how far the buffer is filled
par_save_block_received_wait_busy
        bit ppi_pb
        bmi par_save_atn_abort
        bvs par_save_block_received_wait_busy
        jsr alloc_next_block     ; reserve the next block on the disk
        jsr par_set_buf_ptr
        ldy #$00
        lda cur_track
        sta (buf_ptr_a),y        ; link track and sector into the first two bytes of the block
        iny
        lda cur_sector
        sta (buf_ptr_a),y
        iny
        jsr par_store_offset     ; buffer offset after the link bytes
        jsr par_write_block      ; write the finished block
        jmp par_save_next_block  ; and receive the next one
par_save_atn_abort               ; ATN: the host aborted the transfer
        jmp atn_service

; --- par_set_buf_ptr: Point ($66) at the channel's buffer
; Point ($66) at the channel's buffer page (buffer number + 3 = $03xx..).
par_set_buf_ptr
        ldx cur_chan
        lda chan_buf,x
        sta job_buf_no           ; remember the buffer number for the job table
        clc
        adc #$03                 ; buffers live at $0300 + 256 * n
        sta buf_ptr_a_hi
        lda #$00
        sta buf_ptr_a

; --- par_store_offset: Save the buffer offset for the channel
; Store the buffer offset Y in the per-buffer pointer table.
par_store_offset
        lda job_buf_no
        asl
        tax
        tya
        sta buf_ptr_tbl,x
        rts

; --- par_write_block: Convert block, write it (with 512-byte cache handling)
; Write the current block. The disk holds 512-byte blocks but the DOS blocks are 256 bytes, so
; two consecutive sectors are combined into one SCSI write when possible.
par_write_block
        jsr job_to_block         ; convert track/sector to an absolute block number
        bcc par_write_check_half ; ok
        jmp write_block_error    ; out of range: write block error
par_write_check_half
        bit half_flag            ; which half of the 512-byte block is this?
        bmi par_write_second_half ; second half
        lda job_buf_no           ; first half: is the sector right after the one in the job table?
        asl
        tax
        lda cur_track
        cmp job_track,x
        bne par_write_flush_block
        lda cur_sector
        sbc #$01                 ; compare with the previous sector (carry set here, so sbc #1 is sector - 1 - 0)
        cmp job_sector,x
        bne par_write_flush_block
        ror par_flags            ; remember that the first half is waiting (par_flags b7)
        jsr cache_set            ; note the block in the cache tag
        jsr set_buf_half         ; point at the matching half of the sector buffer
        ldy #$00
par_write_stash_first_half       ; copy the 256 bytes into both halves of the buffer
        lda (buf_ptr_a),y
        sta (buf_ptr_b),y
        sta sector_buf2,y
        iny
        bne par_write_stash_first_half
        jmp listen_flush_update_job_ts ; finish through the common update routine
par_write_second_half            ; second half: only valid if the first half is waiting
        bit par_flags
        bpl par_write_flush_block
        lsr par_flags
        jsr cache_hit            ; is the cached block still the same?
        beq par_write_flush_block
        ldy #$00
par_write_merge_halves
        lda sector_buf2,y        ; merge the saved first half back into the sector buffer
        sta sector_buf,y
        iny
        bne par_write_merge_halves
        jsr cache_set
par_write_flush_block            ; write the whole 512-byte block now
        jsr job_write_buf
        jmp listen_flush_update_job_ts

; --- cmd_validate: V command: rebuild the BAM from the directory
; V (Validate) command. Rebuilds the BAM of the partition from the directory: it clears the
; BAM, then follows every file's chain and marks its blocks allocated again.
cmd_validate
        jsr strip_partition_arg  ; ignore the partition number argument
        jsr init_partition       ; mount the partition
        jsr get_dir_track        ; remember the current directory so it can be restored afterwards
        pha
        jsr get_dir_sector
        pha
        jsr is_native            ; native partitions have sub-directories: start at the root
        bne validate_save_disk_name
        jsr set_dir_root_1       ; set_dir_root_1: root directory is track 1 / sector 1
        jsr set_header_loc       ; fill header/directory locations
validate_save_disk_name
        jsr bam_find_slot        ; keep the disk name, new_build_bam would erase it
        ldx #$00
        stx name_start
        ldy #$90                 ; name starts at offset $90 in the BAM buffer
validate_copy_name_loop
        lda (bam_ptr),y
        sta cmd_buf,x
        iny
        inx
        cpx #$10
        bcc validate_copy_name_loop
        stx cmd_len
        jsr new_build_bam        ; build an empty BAM (all blocks free, header and BAM blocks used)
        jsr read_header_blk      ; read the header block back
        ldx #$AD                 ; GEOS disk? compare 'GEOS format' at header offset $AD
validate_geos_sig_loop
        lda dirblk_buf,x
        cmp txt_geos_format-173,x
        bne validate_finish_validate
        inx
        cpx #$B8
        bcc validate_geos_sig_loop
        lda dirblk_buf+171       ; offset $AB/$AC = GEOS border sector track/sector
        beq validate_finish_validate
        sta cur_track
        sta hdr_track
        lda dirblk_buf+172       ; sector of the border block
        sta cur_sector
        sta dir1_sector
        jsr is_native            ; only 1541 and 1571 partitions carry the GEOS fields in the BAM
        cmp #$02
        beq validate_geos_is_1541_1571
        cmp #$03
        bne validate_geos_mark_and_scan
validate_geos_is_1541_1571
        jsr bam_find_slot
        ldy #$AB                 ; copy the GEOS info fields ($AB-$BC) into the BAM buffer
validate_geos_info_loop
        lda dirblk_buf,y
        sta (bam_ptr),y
        iny
        cpy #$BD
        bcc validate_geos_info_loop
validate_geos_mark_and_scan
        jsr validate_mark_chain  ; mark the border sector chain as used
        jsr validate_scan_dir    ; and walk the whole directory
validate_finish_validate
        jsr validate_scan_dir    ; normal (non GEOS) disk: just walk the directory
        lda hdr_track            ; finally mark the header/BAM blocks themselves
        sta cur_track
        lda hdr_sector
        sta cur_sector
        jsr validate_mark_chain
        jsr bam_write_if_dirty   ; write the BAM back if it changed
        pla                      ; restore the directory we started in
        tay
        pla
        jsr set_dir
        jmp cmd_complete

; --- validate_scan_dir: Validate: walk all directory entries
; Walk all directory entries of the current directory and mark each file's blocks in the BAM.
; For native partitions it follows sub-directories without recursion: when a directory has been
; scanned the header's parent pointer (offset 34-38) takes us back to the entry we left from.
validate_scan_dir
        lda #$00                 ; dir_first_flag = 0: first search
        sta dir_first_flag
        jsr dir_scan_open        ; open the directory chain and read the first block
        beq validate_scan_native_subdir_setup
        jmp validate_scan_check_entry_type ; got an entry: go and look at it
validate_scan_native_subdir_setup
        jsr set_header_loc
        jsr is_native            ; only native partitions have sub-directories
        bne validate_scan_done
        jsr read_header_blk      ; read the header of this directory
        lda dirblk_buf+34        ; offset 34/35 = track/sector of the parent directory header
        beq validate_scan_done   ; no parent: this is the root, finished
        ldy dirblk_buf+35
        jsr set_dir              ; go up to the parent
        jsr set_header_loc
        lda dirblk_buf+36        ; offsets 36-38 = position of the sub-directory's entry in the parent
        sta ent_track
        lda dirblk_buf+37
        sta ent_sector
        lda dirblk_buf+38
        sta ent_offset
        lsr                      ; top three bits of the offset byte hold the entry number (0-7)
        lsr
        lsr
        lsr
        lsr
        sec                      ; work out how many entries are left in this block
        sbc #$07
        eor #$FF
        sta dir_ent_ctr          ; dir_ent_ctr = entries remaining
        lda #$FF
        sta dir_blk_flag         ; a directory block is already loaded
        jmp validate_scan_next_entry ; continue with the next entry after the one we came from
validate_scan_done
        rts
validate_scan_process_file
        ldy #$01                 ; file entry: start/size information / save the first block of the file (entry bytes 1 and 2)
        lda (dir_ptr),y
        pha
        iny
        lda (dir_ptr),y
        pha
        ldy #$13                 ; offset $13 = REL side-sector/extra pointer track
        lda (dir_ptr),y          ; entry byte $13/$14: side sector (REL) or other extra chain
        beq validate_scan_maybe_recurse_subdir
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        iny
        lda (dir_ptr),y          ; and byte $15, the GEOS file structure
        pha
        iny
        lda (dir_ptr),y
        pha
        lda file_type            ; keep the file type across the chain walk
        pha
        jsr validate_mark_chain  ; mark all data blocks of the file
        pla
        sta file_type
        tay
        pla
        tax
        pla
        cmp #$01                 ; GEOS structure 1 = VLIR (variable length index records)
        bne validate_scan_maybe_recurse_subdir
        txa
        beq validate_scan_maybe_recurse_subdir
        cpy #$03                 ; only for USR files (type 3)
        bne validate_scan_maybe_recurse_subdir
        pla
        tax
        sta cur_sector
        pla
        sta cur_track
        pha
        txa
        pha
        jsr read_cur_blk         ; read the VLIR index block
        ldy #$02                 ; record entries start at offset 2, two bytes each
validate_scan_vlir_index_loop
        sty tmp_9d               ; remember the index position
        lda dirblk_buf,y
        beq validate_scan_vlir_next ; empty record: skip
        sta cur_track
        lda dirblk_buf1,y
        sta cur_sector
        jsr validate_mark_chain  ; mark this record's chain
        ldy tmp_9d
validate_scan_vlir_next
        iny                      ; next index entry (2 bytes)
        iny
        bne validate_scan_vlir_index_loop
validate_scan_maybe_recurse_subdir
        pla                      ; restore the file's start track/sector
        sta cur_sector
        pla
        sta cur_track
        jsr is_native            ; native partition and a DIR entry (type 6)?
        bne validate_scan_mark_chain_continue
        lda file_type            ; file type 6 = sub-directory
        cmp #$06
        bne validate_scan_mark_chain_continue
        lda cur_track            ; go into the sub-directory
        ldy cur_sector
        jsr set_dir
        jsr set_header_loc
        jsr read_header_blk
        lda ent_track            ; remember where we came from: store the parent entry position in the sub-directory header
        sta dirblk_buf+36
        lda ent_sector
        sta dirblk_buf+37
        lda ent_offset
        sta dirblk_buf+38
        jsr write_dirblk         ; write the header back
        jsr validate_mark_chain  ; mark the sub-directory header chain
        jmp validate_scan_dir    ; and scan the new directory
validate_scan_mark_chain_continue
        jsr validate_mark_chain
validate_scan_next_entry
        jsr dir_scan_reopen      ; re-read the directory block of the current entry and go to the next
        bne validate_scan_check_entry_type
        jmp validate_scan_native_subdir_setup ; ran off the end of the directory: go up to the parent
validate_scan_check_entry_type
        ldy #$00
        lda (dir_ptr),y          ; first byte of the entry = type and flags
        bmi validate_scan_closed_file_type ; bit 7 = file was closed properly
        jsr entry_clear          ; not closed (splat file): remove the entry
        jmp validate_scan_next_entry
validate_scan_closed_file_type
        and #$07                 ; low three bits = file type
        sta file_type
        cmp #$05                 ; type 5 = CBM (1581 style sub-partition, a block range)
        beq validate_scan_allocate_range_entry
        jmp validate_scan_process_file
validate_scan_allocate_range_entry
        jsr get_entry_range      ; first track/sector and block count of the range
        jsr alloc_range          ; allocate the whole range in the BAM
        jmp validate_scan_next_entry

; --- validate_mark_chain: Validate: follow a block chain marking each block allocated
; Follow a block chain starting at (cur_track,cur_sector) and mark every block as allocated in
; the BAM. Used by V and the file allocation paths.
validate_mark_chain
        jsr check_ts_legal       ; illegal track/sector? error 66
        jsr bam_allocate_block   ; allocate the first block
        jsr dir_open_chan        ; open the directory channel to get a buffer
mark_chain_follow_link_loop
        jsr read_link_from_buf   ; read the link of the current block
        lda cur_track
        bne mark_chain_allocate_and_read_next ; track 0 = last block
        jmp release_chan         ; free the channel and finish
mark_chain_allocate_and_read_next
        jsr bam_allocate_block   ; allocate the block the link points at
        jsr chain_read_first     ; read it
        jmp mark_chain_follow_link_loop
; --- txt_geos_format: 'GEOS format' signature compared in the header block
; Signature the GEOS formatter writes into the header block at offset $AD.
txt_geos_format
        !text "GEOS format"             ; $9E49

; --- talk_handler: TALK data handler: send bytes of the current channel to the host
; TALK data handler. Called by the ATN service after we have been addressed as talker. Keeps
; sending bytes of the current channel until the host stops it (ATN) or the channel ends.
talk_handler
        sei
        bit par_mode             ; parallel cable: no delay needed
        bvs talk_check_channel
        ldx #$64                 ; about 1ms wait so the host is ready
talk_settle_delay
        dex
        bne talk_settle_delay
talk_check_channel
        jsr get_chan_for_sa      ; find the channel for the secondary address
        bcs talk_no_data_return  ; no channel: nothing to send
        ldx cur_chan
        lda chan_flags,x         ; channel flags b7 = active (data available)
        bmi talk_channel_active
talk_no_data_return
        rts
talk_channel_active
        lda xfer_mode            ; special mode $61 = file streaming (sector load)
        cmp #$61
        bne talk_select_reader
        bit par_mode             ; parallel or serial streaming?
        bvc talk_stream_serial
        jmp stream_file_parallel
talk_stream_serial
        jmp stream_file_serial
talk_select_reader
        jsr sa_to_chan_type      ; X = channel type index
        lda cur_sa               ; SA 0 is LOAD
        bne talk_load_reader_vector
        lda dir_load_flag        ; a directory is loaded through SA 0
        beq talk_load_reader_vector
        ldx #$0C                 ; use the directory reader (entry 6)
talk_load_reader_vector
        lda talk_handler_tbl,x   ; fetch the byte reader for this channel type
        sta talk_vec
        lda talk_handler_tbl+1,x
        sta talk_vec+1
        bit par_mode             ; parallel cable: protocol entry 3
        bvc talk_select_protocol_from_mode
        ldx #$06
        bne talk_load_protocol_vector
talk_select_protocol_from_mode
        lda xfer_mode            ; the top two bits of xfer_mode choose the protocol
        and #$C0                 ; 0 = IEC, 1 = Jiffy, 2 = burst
        asl
        rol
        rol
        rol
        tax
talk_load_protocol_vector
        lda talk_proto_tbl,x     ; fetch the byte sender for this protocol
        sta byte_vec
        lda talk_proto_tbl+1,x
        sta byte_vec+1
talk_send_byte_loop
        ldx cur_chan
        lda chan_flags,x         ; channel finished? (b7 clear)
        bpl talk_no_data_return
        jsr call_byte_vec        ; send the byte to the host
        jsr call_talk_vec        ; then read the next byte from the channel
        jmp talk_send_byte_loop
; --- call_talk_vec: jmp ($2BFC): channel-type specific byte reader
; jmp (talk_vec): the reader chosen in talk_handler.
call_talk_vec
        jmp (talk_vec)
; --- talk_handler_tbl: Channel-type -> byte-reader table (error, seq/prg/usr, rel, direct, dir)
; Channel type -> routine that prepares the next byte: error channel, sequential/program/user,
; relative, direct access (#), directory.
talk_handler_tbl
        !word talk_err_chan_byte                  ; $9ECA
        !word talk_seq_byte                  ; $9ECC
        !word talk_seq_byte                  ; $9ECE
        !word talk_seq_byte                  ; $9ED0
        !word talk_rel_byte                  ; $9ED2
        !word talk_direct_byte                  ; $9ED4
        !word talk_dir_byte                  ; $9ED6
; --- talk_proto_tbl: Bus protocol -> byte-sender table (IEC, JiffyDOS, burst, parallel)
; Bus protocol -> routine that sends one byte: serial IEC, JiffyDOS-style, burst, parallel.
talk_proto_tbl
        !word iec_talk_byte                  ; $9ED8
        !word jiffy_talk_byte                  ; $9EDA
        !word burst_talk_byte                  ; $9EDC
        !word par_send_byte                  ; $9EDE

; --- sa_to_chan_type: Map the current secondary address to a channel-type index (X = 2*type)
; Map the secondary address to an index into talk_handler_tbl (two bytes per entry).
sa_to_chan_type
        lda cur_sa
        sec
        sbc #$0F                 ; SA 15 = command/error channel, index 0
        beq sa_type_type_done
        jsr chan_get_type        ; channel type of an open channel (state bits 1-3)
        cmp #$07                 ; type 7 (direct access) becomes entry 5
        bne sa_type_type_done
        lda #$05
sa_type_type_done
        asl
        tax
        rts

; --- talk_err_chan_byte: Next byte of the error-channel (15) message
; Return the next byte of the status (error) message. The message is at $2300; the pointer
; value $22FF means "message finished". After the final CR the status is reset to 00,OK.
talk_err_chan_byte
        lda errmsg_ptr
        cmp #$FF                 ; $22FF is the end marker
        bne talk_err_fetch_message_byte
        lda errmsg_ptr_hi
        cmp #$22
        bne talk_err_fetch_message_byte
        lda #$0D                 ; CR ends the message
        sta iec_byte
        jsr led_error_off        ; error is read: turn the error LED off
        lda #$00
        jsr set_error_no_ts      ; status back to 00,OK
        dec errmsg_ptr
        lda #$80                 ; flags: last byte
        bne talk_err_store_byte
talk_err_fetch_message_byte
        jsr talk_cmd_byte        ; fetch the next character of the message
        sta iec_byte
        bne talk_err_normal_byte_flags ; $00 terminator? then the message is over (send CR next time)
talk_err_reset_message_pointer
        lda #$FF                 ; point the pointer at the end marker
        sta errmsg_ptr
        lda #$22
        sta errmsg_ptr_hi
talk_err_normal_byte_flags
        lda #$88                 ; $88 = active, not last
talk_err_store_byte
        sta chan_flags+31        ; the error channel (channel 31) state and byte
        lda iec_byte
        sta chan_byte+31
        rts

; --- talk_seq_byte: Next byte of a sequential/program channel
; Next byte of a sequential, program or user file channel.
talk_seq_byte
        ldy cur_chan
        lda chan_flags,y
        and #$08                 ; flag b3 set = more bytes
        bne talk_seq_fetch_buffer_byte
        sta chan_flags,y         ; no: channel is finished
        rts
talk_seq_fetch_buffer_byte
        lda chan_buf,y           ; buffer number of the channel
        asl                      ; pointers are two bytes each
        tax
        lda (buf_ptr_tbl,x)      ; read the byte at the buffer pointer
        pha
        lda chan_last,y          ; pointer = last byte of the file?
        cmp buf_ptr_tbl,x
        bne talk_seq_advance_pointer
        lda #$00                 ; yes: reset the pointer
        sta buf_ptr_tbl,x
        lda #$80                 ; $80 = active, EOI (last byte)
        sta chan_flags,y
        bne talk_seq_store_byte
talk_seq_advance_pointer
        inc buf_ptr_tbl,x        ; next byte in the buffer
        bne talk_seq_store_byte  ; page boundary: read the next block of the file
        jsr chain_read_next
talk_seq_store_byte
        pla
        sta chan_byte,y
        rts

; --- chain_read_first: Read the first block of a chain
; Read the first block of a chain (the block link bytes are already in the buffer).
chain_read_first
        ldy cur_chan
        lda chan_buf,y
        asl
        tax
        lda #$00
        sta buf_ptr_tbl,x
        lda (buf_ptr_tbl,x)
        bne chain_read_next      ; link track non-zero: more blocks
        rts

; --- chain_read_next: Follow the link bytes to the next block
; Follow the link bytes in the buffer to read the next block into it.
chain_read_next
        inc buf_ptr_tbl,x        ; sector byte
        lda (buf_ptr_tbl,x)
        sta job_sector,x         ; put into the job table
        dec buf_ptr_tbl,x
        lda (buf_ptr_tbl,x)      ; track byte
        sta job_track,x
        txa
        lsr
        tax
        lda #$80                 ; $80 = read job
        jsr do_job               ; run it and wait
        txa
        asl
        tax
        lda (buf_ptr_tbl,x)      ; new link track
        sta cur_track
        php
        inc buf_ptr_tbl,x
        lda (buf_ptr_tbl,x)
        sta cur_sector           ; sector byte of the link
        inc buf_ptr_tbl,x
        plp                      ; restore Z from the track test above
        bne chain_next_skip_set_last ; not last block: nothing to record
        sta chan_last,y          ; last block: A holds the sector byte = index of the last data byte
chain_next_skip_set_last
        tya
        tax
        inc chan_blk_lo,x        ; count the block we just read (blocks read)
        bne chain_next_done
        inc chan_blk_hi,x
chain_next_done
        rts

; --- talk_rel_byte: REL file byte (jumps to the REL reader)
; REL file: the byte is fetched by the relative file code.
talk_rel_byte
        jmp rel_get_byte

; --- talk_dir_byte: Next byte of a directory/utility channel
; Directory ($) channel. The listing is built line by line in the buffer; when a line is
; used up the next line is produced.
talk_dir_byte
        ldy cur_chan
        lda chan_flags,y
        and #$08
        bne talk_dir_fetch_dir_byte
        sta chan_flags,y
        rts
talk_dir_fetch_dir_byte
        jsr chan_get_byte        ; next character of the current line
        pha
        bne talk_dir_store_byte  ; non-zero: normal character
        lda chan_last,y          ; zero = end of line. Is it the very end of the listing?
        beq talk_dir_next_dir_line ; more lines to come
        lda #$80                 ; $80: last byte
        sta chan_flags,y
        bne talk_dir_store_byte
talk_dir_next_dir_line
        lda #$00                 ; clear the line state and build the next line
        sta dir_line_flag
        jsr dir_list_line        ; format the next directory line
        ldy cur_chan
talk_dir_store_byte
        pla
        sta chan_byte,y
        rts

; --- talk_direct_byte: Next byte of a direct-access ('#') channel
; Direct access (#) channel: bytes come straight from the buffer; the pointer is wrapped at the
; buffer end.
talk_direct_byte
        ldy cur_chan
        lda chan_flags,y
        and #$08
        bne talk_direct_check_pointer
        lda #$89                 ; $89 = active, reading
        sta chan_flags,y
talk_direct_check_pointer
        lda chan_buf,y
        asl
        tax
        lda buf_ptr_tbl,x
        cmp chan_last,x          ; at the end of the buffer?
        bne direct_next_ptr
        lda #$00                 ; wrap around
        sta buf_ptr_tbl,x

; --- direct_next_ptr: Advance the direct-access pointer
; Advance the buffer pointer and fetch the next byte.
direct_next_ptr
        inc buf_ptr_tbl,x

; --- direct_fetch_byte: Fetch the direct-access byte and set EOI at end
; Fetch the byte; if it is the last one flag EOI.
direct_fetch_byte
        lda (buf_ptr_tbl,x)
        sta chan_byte,y
        lda buf_ptr_tbl,x
        cmp chan_last,y
        bne direct_fetch_done
        lda #$81                 ; $81 = last byte
        sta chan_flags,y
direct_fetch_done
        rts

; --- talk_cmd_byte: Fetch a byte from the command/status channel
; Fetch a byte of the status message; the pointer runs to the end marker $FF.
talk_cmd_byte
        ldy cur_chan
        lda chan_buf,y
        asl
        tax
        lda (buf_ptr_tbl,x)
        pha
        lda chan_last,y
        cmp buf_ptr_tbl,x
        bne talk_cmd_advance_pointer
        lda #$FF                 ; reached the end marker: set the pointer to $FF
        sta buf_ptr_tbl,x
talk_cmd_advance_pointer
        pla
        inc buf_ptr_tbl,x
        rts

; --- listen_handler: LISTEN data handler: accept bytes for the current channel (jt_listen)
; LISTEN data handler. Called after we were addressed as listener. For channel 15 the bytes
; are collected into the command buffer; for other channels they are written to the buffer
; of the file.
listen_handler
        sei
        lda cur_atn_byte         ; channel number and OPEN/CLOSE bits
        and #$8F                 ; mask out the open/close bits
        cmp #$0F                 ; SA 15 is the command channel
        bcs listen_command_channel_setup
        jsr get_chan_for_sa_rd   ; for a data channel find its entry (write channels only)
        bcc listen_data_channel  ; channel found
listen_no_channel_return
        rts
listen_command_channel_setup
        jsr cmdbuf_reset         ; command channel: clear the command buffer pointer
        lda #$1E                 ; channel number 30 is the internal command channel
        sta cur_chan
        ldx #$00                 ; clear the 256-byte command buffer
        txa
listen_clear_cmd_buf_loop
        sta cmd_buf,x
        inx
        bne listen_clear_cmd_buf_loop
        beq listen_load_writer_vector ; always taken
listen_data_channel
        lda par_mode             ; par_mode = $60 means the parallel fast file save
        cmp #$60
        bne listen_get_channel_type
        jmp par_save_start       ; let the parallel save routine take over
listen_get_channel_type
        jsr sa_to_chan_type      ; X = type index of the channel
listen_load_writer_vector
        lda listen_handler_tbl,x ; byte writer for this channel type
        sta talk_vec
        lda listen_handler_tbl+1,x
        sta talk_vec+1
        bit par_mode             ; parallel cable? use its protocol entry
        bvc listen_select_protocol_from_mode
        ldx #$06
        bne listen_load_protocol_vector
listen_select_protocol_from_mode
        lda xfer_mode            ; choose the protocol from xfer_mode
        and #$C0
        asl
        rol
        rol
        rol
        tax
listen_load_protocol_vector
        lda listen_proto_tbl,x
        sta byte_vec
        lda listen_proto_tbl+1,x
        sta byte_vec+1
listen_receive_loop              ; keep receiving until the host stops (ATN)
        ldx cur_chan
        lda chan_flags,x         ; channel active?
        lsr                      ; bit 0 = write channel
        bcs listen_receive_one_byte
        lda cur_atn_byte         ; OPEN of a new file ($Fx) is allowed even without a channel
        and #$F0
        cmp #$F0
        bne listen_no_channel_return
listen_receive_one_byte
        jsr call_byte_vec        ; receive a byte from the bus
        jsr call_listen_vec      ; store it
        jmp listen_receive_loop
; --- call_listen_vec: jmp ($2BFC): channel-type specific byte writer
; jmp (talk_vec): the writer chosen in listen_handler (the same vector as the reader).
call_listen_vec
        jmp (talk_vec)
; --- call_byte_vec: jmp ($2BFE): bus-protocol specific byte receiver
; jmp (byte_vec): the bus protocol routine chosen above.
call_byte_vec
        jmp (byte_vec)
; --- listen_handler_tbl: Channel-type -> byte-writer table
; Channel type -> routine that stores a byte for a write channel.
listen_handler_tbl
        !word listen_cmd_byte                  ; $A099
        !word listen_seq_byte                  ; $A09B
        !word listen_seq_byte                  ; $A09D
        !word listen_seq_byte                  ; $A09F
        !word listen_rel_byte                  ; $A0A1
        !word listen_direct_byte                  ; $A0A3
; --- listen_proto_tbl: Bus protocol -> byte-receiver table
; Bus protocol -> routine that receives one byte.
listen_proto_tbl
        !word iec_listen_byte                  ; $A0A5
        !word jiffy_listen_byte                  ; $A0A7
        !word burst_listen_byte                  ; $A0A9
        !word par_recv_byte                  ; $A0AB

; --- listen_cmd_byte: Store a received byte into the command buffer
; Store a byte of the command received on channel 15 in cmd_buf.
listen_cmd_byte
        ldx cmdbuf_ptr
        cpx #$FF                 ; $FF = buffer full, ignore more characters
        beq listen_cmd_check_eoi
        lda iec_byte
        sta cmd_buf,x
        inc cmdbuf_ptr           ; advance the fill pointer
listen_cmd_check_eoi
        bit eoi_flag             ; EOI means the command is complete
        bmi listen_cmd_done
        inc cmd_pending          ; not the last byte yet: remember that a command is pending
listen_cmd_done
        rts

; --- listen_seq_byte: Store a received byte into a write channel buffer
; Store a byte into the buffer of a sequential write channel.
listen_seq_byte
        ldy cur_chan
        lda chan_buf,y
        asl
        tax
        lda buf_ptr_tbl,x        ; pointer wrapped to 0: the buffer is full
        bne listen_seq_store_byte
        jsr listen_flush_block   ; write it out and start a new block
        ldx cur_chan
        lda chan_buf,x
        asl
        tax
listen_seq_store_byte
        lda iec_byte
        sta (buf_ptr_tbl,x)      ; store at the pointer
        inc buf_ptr_tbl,x
        rts

; --- listen_flush_block: Buffer full: allocate the next block and write the current one
; The buffer of a write channel is full. Allocate the next block, put its track/sector into the
; link bytes of the current block, and write the current block.
listen_flush_block
        jsr alloc_next_block     ; find a free block for the next sector
        ldx bam_slot             ; check the DOS version of the BAM against the partition type
        lda bam_dosver,x
        beq listen_flush_dosver_ok
        ldy cur_part
        ldx part_type,y
        cmp dosver_by_type,x     ; dosver_by_type has the letter for the partition type
        beq listen_flush_dosver_ok
        jsr restore_ts_from_job
        lda #$73
        jmp jt_dos_error
listen_flush_dosver_ok
        ldy cur_chan             ; buffer of the channel
        lda chan_buf,y
        sta job_buf_no
        asl                      ; each buffer has a 2-byte pointer
        tax
        lda cur_track            ; link track into byte 0
        sta (buf_ptr_tbl,x)
        inc buf_ptr_tbl,x        ; and move the pointer
        lda cur_sector           ; link sector into byte 1
        sta (buf_ptr_tbl,x)
        inc buf_ptr_tbl,x
        php                      ; do not let the IRQ job tick interfere while the 512-byte cache is used
        sei
        jsr job_to_block         ; get the absolute block number
        bcs write_block_error
        bit half_flag            ; second half of a 512-byte block?
        bmi listen_flush_write_plain_block
        lda job_buf_no
        asl
        tax
        lda cur_track            ; first half: is it the sector just before the one in the job table?
        cmp job_track,x
        bne listen_flush_write_plain_block
        lda cur_sector
        sbc #$01
        cmp job_sector,x
        bne listen_flush_write_plain_block
        jsr cache_set            ; remember the block in the cache tag
        jsr job_write_buf2       ; copy the buffer into the sector buffer (no write yet)
        jmp listen_flush_restore_irq
listen_flush_write_plain_block   ; write the whole 512-byte block now
        jsr job_write_buf
listen_flush_restore_irq
        plp
listen_flush_update_job_ts       ; update the job table with the new block
        lda job_buf_no
        asl
        tax
        lda cur_track
        sta job_track,x
        lda cur_sector
        sta job_sector,x
        ldx cur_chan
        inc chan_blk_lo,x        ; count the block written
        bne listen_flush_done
        inc chan_blk_hi,x
listen_flush_done
        rts
write_block_error                ; something is wrong with the block number: job error 4
        lda #$04
        ldx job_buf_no
        sta job_code,x
        jmp jt_job_error
; --- listen_rel_byte: REL file write byte (jumps to the REL writer)
; REL file: byte is handled by the REL writer.
listen_rel_byte
        jmp rel_write_byte

; UNREACHABLE: bare RTS stubs (listen_nop_a, listen_nop_b), not referenced by any table or branch.
listen_nop_a                     ; empty entries (no byte written for this channel type)
        rts

listen_nop_b
        rts

; --- listen_direct_byte: Store a received byte into a direct-access buffer
; Direct access write: store the received byte in the buffer, then fetch it back for the
; byte pointer handling.
listen_direct_byte
        lda iec_byte
        jsr buf_store_byte
        jmp direct_fetch_byte

; --- buf_store_byte: Store A at the current buffer pointer
; Store the byte in A at the current buffer pointer and advance the pointer.
buf_store_byte
        pha
        ldy cur_chan
        lda chan_buf,y
        asl
        tax
        pla
        sta (buf_ptr_tbl,x)
        inc buf_ptr_tbl,x
        rts

; --- read_header_blk: Read the partition header block ($80) into the directory-block buffer
; Block read/write helpers using the internal directory buffer (buffer 31, $2200). The two
; entries of each pair are the same code, the second loads the write job code with a BIT
; trick: LDA #$80 (read) or LDA #$90 (write).
read_header_blk
        lda #$80                 ; job $80 = read
        !byte $2C                ; BIT skips the next LDA
; --- write_header_blk: Write block (hdr_track,hdr_sector) (job $90)
write_header_blk
        lda #$90                 ; job $90 = write
        pha                      ; save the job code
        lda hdr_sector           ; sector of the partition header block
read_hdr_set_sector
        sta job_sector_b31       ; buffer 31 job table: sector
        lda hdr_track            ; track of the header block
read_hdr_set_track
        sta job_track_b31        ; buffer 31 job table: track
        ldx #$1F                 ; buffer 31 = directory block buffer
        pla
        jmp jt_do_job            ; execute the job

; --- read_dir1_blk: Read block (hdr_track,dir1_sector) (job $80)
; Same, for the first directory block of the partition.
read_dir1_blk
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- write_dir1_blk: Write block (hdr_track,dir1_sector) (job $90)
write_dir1_blk
        lda #$90
        pha
        lda dir1_sector
        jmp read_hdr_set_sector

; --- read_cur_blk: Read block (cur_track,cur_sector) into the directory-block buffer
; Same, for the block (cur_track, cur_sector).
read_cur_blk
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- write_cur_blk: Write block (cur_track,cur_sector) (job $90)
write_cur_blk
        lda #$90
        pha
        lda cur_sector
        sta job_sector_b31
        lda cur_track
        jmp read_hdr_set_track

; --- read_link_blk: Read the block referenced by the header's link pointer
; Read the directory block that the header's parent pointer refers to (native sub-directories).
read_link_blk
        jsr read_header_blk      ; header first
        lda dirblk_buf+36        ; offset 36-38 = parent entry location
        sta job_track_b31
        lda dirblk_buf+37
        sta job_sector_b31
        lda dirblk_buf+38
        pha                      ; keep the entry's byte offset for the caller
        lda #$80
        ldx #$1F
        jsr jt_do_job
        pla
        tax                      ; X = offset into the block
        rts

; --- write_dirblk: Write the directory-block buffer back ($90)
; Write the directory block buffer back to disk.
write_dirblk
        lda #$90
        ldx #$1F
        jmp jt_do_job
; --- bam_sync_read: Flush path entry for BAM cache (read direction)
; BAM cache. The BAM of up to 16 partitions is kept in RAM ($6000-$7FFF, 512 bytes each).
; bam_sync moves the cached BAM sector to or from the disk, depending on bam_rw.
bam_sync_read
        clc                      ; carry clear = read
        !byte $24                ; BIT trick: skip the next SEC
; --- bam_sync: Transfer the current BAM sector between cache and disk (type dependent)
bam_sync
        sec                      ; carry set = write
        ror bam_rw               ; bam_rw b7 = write flag
        ldx bam_slot
        lda #$00                 ; the BAM is clean after the transfer
        sta bam_dirty,x
        jsr get_part_type        ; partition type chooses the BAM layout
        asl
        tax
        lda bam_sync_tbl-2,x     ; types 1-5: native, 1541, 1571, 1581, 1581 CP/M
        sta disp_vec
        lda bam_sync_tbl-1,x
        sta disp_vec+1
        jmp (disp_vec)
; --- bam_sync_tbl: Partition type -> BAM transfer routine
; Partition type -> BAM transfer routine.
bam_sync_tbl
        !word bam_sync_native                  ; $A1F8
        !word bam_sync_1541                  ; $A1FA
        !word bam_sync_1571                  ; $A1FC
        !word bam_sync_1581                  ; $A1FE
        !word bam_sync_1581                  ; $A200

; --- bam_sync_1541: BAM transfer for a 1541-type partition
; 1541: BAM is in track 18 sector 0.
bam_sync_1541
        lda #$12                 ; track 18
        ldx #$00
        jmp bam_job

; --- bam_sync_1571: BAM transfer for a 1571-type partition
; 1571: BAM sectors are on track 18 (side 1) and track 53 (side 2).
bam_sync_1571
        jsr bam_sync_1541
        lda #$35                 ; track 53 = second side BAM
        ldx #$00
bam_job_next_page
        inc bam_ptr_hi           ; second BAM block goes in the next page of the cache slot
        jsr bam_job
        dec bam_ptr_hi
        rts

; --- bam_sync_1581: BAM transfer for a 1581-type partition (2 BAM blocks)
; 1581: header on the directory track, BAM in sectors 1 and 2 of that track.
bam_sync_1581
        jsr get_dir_track
        pha
        ldx #$01
        jsr bam_job
        pla
        ldx #$02
        bne bam_job_next_page

; --- bam_sync_native: BAM transfer for a native partition
; Native: each BAM block pair covers 16 tracks and lives on track 1 starting at sector 2.
bam_sync_native
        ldx bam_slot
        lda bam_sec_idx,x        ; index of the BAM sector held in this slot
        asl
        clc
        adc #$02                 ; sector = 2 * index + 2 (pairs of blocks)
        and #$FE
        tax
        lda #$01                 ; track 1
        jsr bam_job
        lda #$01
        ldx job_sector_b30       ; second block: sector + 1
        inx
        jmp bam_job_next_page

; --- bam_job: Issue the BAM read/write job for buffer slot
; Issue the BAM read ($CC) or write ($CE) job on buffer 30 for track A, sector X.
bam_job
        sta job_track_b30        ; track
        stx job_sector_b30       ; sector
        lda bam_ptr_hi           ; the BAM cache slot's page
        sta job_bufhi_b30
        lda #$00
        sta job_buflo_b30        ; data goes to offset 0 of the page
        lda #$01                 ; one block
        sta job_count_b30
        ldx #$1E                 ; buffer 30 is reserved for BAM transfers
        lda #$CC                 ; job $CC = read
        bit bam_rw               ; read or write?
        bpl bam_job_issue_job
        lda #$CE                 ; job $CE = write
bam_job_issue_job
        jsr jt_do_job
        ldx bam_slot
        rts

; --- bam_select_sector: Make sure the BAM sector for the current track is cached
; Make sure the BAM sector that holds the current track is in the cache slot.
bam_select_sector
        jsr bam_find_slot
        lda cur_track
        lsr                      ; 16 tracks per BAM sector
        lsr
        lsr
        lsr
        cmp bam_sec_idx,x
        bne bam_select_switch_sector ; already loaded?
        rts
bam_select_switch_sector
        pha
        lda bam_dirty,x          ; slot dirty? write it out before loading another sector
        beq bam_select_load_new_sector
        jsr bam_sync
bam_select_load_new_sector
        pla                      ; new sector index
        sta bam_sec_idx,x
        jmp bam_sync_read

; --- bam_load_if_needed: Load the BAM if the cache slot is empty
; Load the BAM if the cache slot does not hold anything yet.
bam_load_if_needed
        jsr bam_find_slot
        lda bam_sec_idx,x
        bpl bam_load_done        ; bit 7 clear = something is loaded
        jsr bam_invalidate_slot
bam_load_done
        rts

; --- bam_flush_reload: Flush the BAM slot if dirty and invalidate it
; Write the BAM slot back if it changed, then mark the slot empty.
bam_flush_reload
        jsr bam_find_slot
        lda bam_sec_idx,x
        beq bam_reload_done      ; index 0 = already empty
        lda bam_dirty,x
        beq bam_reload_invalidate
        jsr bam_sync
bam_reload_invalidate
        jsr bam_invalidate_slot
bam_reload_done
        rts

; --- bam_invalidate: Invalidate the current partition's BAM cache slot
; Invalidate the cache slot of the current partition.
bam_invalidate
        jsr bam_find_slot

; --- bam_invalidate_slot: Invalidate the BAM cache slot in X
; Invalidate the cache slot in X and reload sector 0.
bam_invalidate_slot
        lda #$00
        sta bam_sec_idx,x
        jmp bam_sync_read

; --- bam_next_sector: Advance to the next BAM sector (native: 16 sectors)
; Move on to the next BAM sector (native partitions have 16 of them).
bam_next_sector
        jsr bam_find_slot
        inc bam_sec_idx,x
        lda bam_sec_idx,x
        cmp #$10                 ; 16 sectors per BAM
        bcc bam_next_reload
        lda #$00
        sta bam_sec_idx,x
bam_next_reload
        jmp bam_sync_read

; --- bam_find_slot: Find / allocate the BAM cache slot for the current partition (X = slot)
; Find the BAM cache slot of the current partition. If it has none a free slot is taken; if all
; 16 are used, a slot of a partition with no open channel is stolen. Result: X = slot, bam_ptr
; points at its 512-byte buffer.
bam_find_slot
        lda cur_part             ; partition we want
        ldx #$0F
bam_find_slot_search_existing_loop ; search all 16 slots
        stx bam_slot
        cmp bam_part,x           ; a slot already belongs to this partition?
        beq bam_find_slot_set_bam_pointer
        dex
        bpl bam_find_slot_search_existing_loop
        pha                      ; keep the partition number
        ldx #$00
bam_find_slot_find_empty_slot_loop ; look for a free slot (partition 0 = empty)
        stx bam_slot
        lda bam_part,x
        beq bam_find_slot_init_new_slot
        inx
        cpx #$10
        bcc bam_find_slot_find_empty_slot_loop
        dex                      ; last slot
bam_find_slot_steal_slot_loop    ; all slots busy: steal one that no open channel uses
        stx bam_slot
        lda bam_part,x
        sta lookup_tmp
        jsr bam_slot_in_use      ; is the partition of this slot used by an open channel?
        bcc bam_find_slot_init_new_slot
        ldx bam_slot
        dex
        bpl bam_find_slot_steal_slot_loop
        lda #$70                 ; nothing can be stolen: error 70, no channel
        jmp jt_dos_error
bam_find_slot_init_new_slot      ; initialise the slot for the new partition
        ldx bam_slot
        pla
        sta bam_part,x
        lda #$00                 ; everything cleared
        sta bam_dirty,x
        sta bam_free_lo,x
        sta bam_free_hi,x
        sta bam_dosver,x
        sta bam_aux,x
        lda #$FF                 ; $FF = not loaded / unknown
        sta bam_sec_idx,x
        sta bam_state,x
bam_find_slot_set_bam_pointer
        txa                      ; BAM buffer = $6000 + 512 * slot
        asl
        clc
        adc #$60
        sta bam_ptr_hi
        lda #$00
        sta bam_ptr
        rts

; --- bam_slot_in_use: Is the BAM cache slot used by an open channel?
; C = 1 if the partition in lookup_tmp has an open channel.
bam_slot_in_use
        ldx #$00
bam_slot_use_scan_channels_loop
        lda sa_chan,x            ; channels not in use hold $FF
        cmp #$FF
        beq bam_slot_use_next_channel
        and #$1F
        tay
        lda chan_part,y          ; partition of the channel
        cmp lookup_tmp
        beq bam_slot_use_done
bam_slot_use_next_channel
        inx
        cpx #$13
        bcc bam_slot_use_scan_channels_loop
        clc                      ; no match: carry clear
bam_slot_use_done
        rts

; --- bam_write_if_dirty: Write the BAM back if modified
; Write the BAM back to disk if it has been changed.
bam_write_if_dirty
        jsr bam_find_slot
        lda bam_dirty,x
        beq bam_write_done
bam_write_now
        jmp bam_sync

; --- bam_write_if_loaded: Write the BAM back if loaded
; Write the BAM back to disk if a BAM sector is loaded.
bam_write_if_loaded
        jsr bam_find_slot
        lda bam_sec_idx,x
        bpl bam_write_now
bam_write_done
        rts

; --- bam_allocate_block: Mark block (cur_track,cur_sector) as used in the BAM
; Mark block (cur_track,cur_sector) as in use. Returns A = 0 (Z set) if it already was used.
; Sets error 72 (partition full) as a warning when only two blocks remain free.
bam_allocate_block
        jsr bam_locate_bit       ; find the BAM byte and bit; Z set = block already allocated
        beq bam_alloc_return_already_used
bam_alloc_store_bit
        sta (bam_ptr),y          ; store the byte with the bit cleared
        jsr bam_get_track_free   ; 1541/1571/1581 keep a per-track free counter in the BAM; carry set = native (none)
        bcs bam_alloc_update_free_count
        sec
        sbc #$01                 ; one block less free on this track
        sta (bam_ptr),y
bam_alloc_update_free_count
        jsr bam_mark_dirty       ; mark BAM modified; carry set = system area, not counted
        bcs bam_alloc_check_free_zero
        lda bam_free_lo,x        ; free blocks lo/hi of the partition, 16 bit decrement
        bne bam_alloc_dec_free_lo
        dec bam_free_hi,x
bam_alloc_dec_free_lo
        dec bam_free_lo,x
bam_alloc_check_free_zero
        lda bam_free_hi,x        ; free count < 3?
        bne bam_alloc_return_ok
        lda bam_free_lo,x
        cmp #$03
        bcs bam_alloc_return_ok
        lda #$72                 ; error 72 PARTITION FULL (soft: the command carries on)
        jsr set_error
bam_alloc_return_ok
        lda #$01                 ; A = 1 = block was free and is now allocated
bam_alloc_return_already_used
        rts

; --- bam_free_block: Mark block (cur_track,cur_sector) as free in the BAM
; Mark block (cur_track,cur_sector) as free. A = 0 (Z clear) if it already was free.
bam_free_block
        jsr bam_locate_bit
        bne bam_free_return_not_allocated ; already free: do nothing
        sta (bam_ptr),y          ; store the byte with the bit set
        jsr bam_get_track_free
        bcs bam_free_update_counts
        adc #$01                 ; one more block free on this track
        sta (bam_ptr),y
bam_free_update_counts
        jsr bam_mark_dirty
        bcs bam_free_return_ok   ; carry set: block does not count towards the free total
        inc bam_free_lo,x        ; 16 bit increment of the partition free count
        bne bam_free_return_ok
        inc bam_free_hi,x
bam_free_return_ok
        lda #$01
bam_free_return_not_allocated
        rts

; --- bam_mark_dirty: Mark BAM dirty / test for the directory-track special case
; Mark the BAM as changed. C = 1 if the block is in the system area (header/BAM blocks,
; which are not counted in the free-block total).
bam_mark_dirty
        jsr get_dir_track        ; directory/header track of the partition
        cmp cur_track
        bne bam_dirty_set_dirty  ; other track: counts normally
        lda part_type,x          ; same track as the directory: native partition?
        cmp #$01
        bne bam_dirty_set_carry_special ; 1541/1571/1581: the whole directory track is never counted
        lda cur_track            ; native: only track 1, sectors below $40 (the system area) are not counted
        cmp #$01
        bne bam_dirty_set_dirty
        lda cur_sector
        cmp #$40                 ; $40 = first sector available for data
        bcs bam_dirty_set_dirty
bam_dirty_set_carry_special
        sec
        !byte $24                ; BIT skips the CLC
bam_dirty_set_dirty
        clc
        ldx bam_slot
        lda #$01                 ; BAM slot is now dirty
        sta bam_dirty,x
        rts

; --- bam_find_free_in_track: Find a free sector on the track in cur_track
; Find the first free sector on track cur_track, starting at cur_sector. A = 0 if none.
bam_find_free_in_track
        ldx cur_track
        jsr get_geometry         ; sectors per track of this track
bam_findfree_check_sector_range
        lda geo_secs_per_trk
        beq bam_findfree_test_sector ; sector count 0 = native, no limit
        cmp cur_sector           ; ran past the last sector?
        bcc bam_findfree_none_free
        beq bam_findfree_none_free
bam_findfree_test_sector
        jsr bam_locate_bit       ; test the BAM bit
        bne bam_findfree_done    ; free: found
        inc cur_sector
        bne bam_findfree_check_sector_range
bam_findfree_none_free
        lda #$00
bam_findfree_done
        rts

; --- alloc_next_block: Allocate the next free block (interleave search from cur_track/cur_sector)
; Allocate the next block for a file. Starts at the previous block's track/sector, adds the
; interleave and searches for a free sector; if the track is full it moves to the nearest track
; with space, away from the directory track, then back the other way.
alloc_next_block
        jsr alloc_prep_a         ; native partitions have their own method
        bne alloc_next_set_file_passes
        jmp alloc_from_dir_start ; native: search from the start of the data area
alloc_next_set_file_passes
        lda #$03                 ; files may reverse the search direction 3 times
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
alloc_next_set_dir_passes        ; directories: only once
        lda #$01
        sta tmp_ctr              ; search pass counter
alloc_next_search_track_loop
        jsr bam_get_track_free   ; does this track have free blocks?
        bne alloc_next_apply_interleave
        ldx geo_dir_track        ; track of the directory/header
        cpx cur_track            ; are we on the directory track?
        beq alloc_next_partition_full ; yes and it is full: no more space
        bcs alloc_next_step_toward_first_track ; below the directory track: go down
        inc cur_track            ; above: go up
        lda cur_track
        cmp geo_end_track        ; past the last track?
        bcc alloc_next_search_track_loop
        dex                      ; turn around starting at the track below the directory
alloc_next_reverse_direction_pass
        stx cur_track
        dec tmp_ctr              ; one pass used up
        bne alloc_next_search_track_loop
        beq alloc_next_partition_full ; out of passes: partition full
alloc_next_step_toward_first_track
        dec cur_track            ; move towards track 1
        lda cur_track
        cmp geo_first_track      ; below the first track?
        bcs alloc_next_search_track_loop
        inx                      ; turn around at the track above the directory
        bne alloc_next_reverse_direction_pass
alloc_next_partition_full
        lda #$72                 ; error 72 PARTITION FULL
        jmp dos_error_00
alloc_next_apply_interleave
        ldx cur_track            ; found a track with space: add the interleave to the sector number
        jsr get_geometry
        jsr get_interleave
        clc
        adc cur_sector
        sta cur_sector           ; new sector
        lda cur_sector
        cmp geo_secs_per_trk     ; wrapped past the end of the track?
        bcc alloc_next_find_free_sector
        sbc geo_secs_per_trk
        sta cur_sector
alloc_next_find_free_sector
        jsr bam_find_free_in_track ; look for a free sector from here on
        bne alloc_next_allocate_found
alloc_next_retry_from_sector_zero ; none after this sector: search the track from sector 0
        lda #$00
        sta cur_sector
        jsr bam_find_free_in_track
        beq alloc_next_directory_error ; nothing at all: the BAM is inconsistent
alloc_next_allocate_found
        jmp bam_allocate_block   ; allocate the sector found
alloc_next_directory_error
        lda #$71                 ; error 71 DIRECTORY ERROR (free count and bitmap disagree)
        jmp jt_dos_error

; --- alloc_next_dir_block: Allocate next block on the directory track
; Allocate the next block of a directory.
alloc_next_dir_block
        jsr alloc_prep_b
        bne alloc_next_set_dir_passes
        jmp alloc_native_native_dir_block

; --- get_interleave: Return the sector interleave for the partition type
; Sector interleave to use for the partition type: 3 on track 18 of 1541/1571 partitions, 1
; everywhere else.
get_interleave
        jsr get_part_type
        cmp #$04
        bcc interleave_small_partition_types
        lda #$01                 ; 1581 and native partitions: interleave 1
        rts
interleave_small_partition_types
        lda #$01
        ldx cur_track
        cpx #$12                 ; track 18 is the directory track on 1541/1571
        bne interleave_done
        lda #$03
interleave_done
        rts

; --- alloc_first_block: Allocate the first free block of a file (outward from the directory track)
; Allocate the first block of a new file. The search starts at the directory track and works
; outward: one track below, one above, two below, two above...
alloc_first_block
        jsr alloc_prep_b
        bne alloc_first_search_from_dir_track
        jmp alloc_native_native_first_block
alloc_first_search_from_dir_track
        lda #$00
        sta tmp_ctr              ; distance from the directory track
        lda geo_dir_track
        sta cur_track
alloc_first_outward_loop
        inc tmp_ctr              ; next distance
        lda cur_track
        cmp geo_dir_track        ; below or above the dir track?
        bcc alloc_first_try_above_dir_track
        lda geo_dir_track
        sbc tmp_ctr              ; dir track - distance
        bcc alloc_first_try_above_dir_track
        sta cur_track
        cmp geo_first_track
        bcc alloc_first_try_above_dir_track
        jsr bam_get_track_free   ; any free blocks on that track?
        beq alloc_first_try_above_dir_track
        jmp alloc_next_retry_from_sector_zero ; yes, find a sector from 0
alloc_first_try_above_dir_track
        lda geo_dir_track        ; now try the same distance above the directory track
        clc
        adc tmp_ctr
        sta cur_track
        cmp geo_end_track
        bcs alloc_first_no_space_error ; past the last track: nothing left
        jsr bam_get_track_free
        beq alloc_first_outward_loop
        jmp alloc_next_retry_from_sector_zero
alloc_first_no_space_error
        lda #$67                 ; error 67 (no more room)
        jmp jt_dos_error

; --- alloc_prep_a: Allocation preparation (read link then check partition)
; Preparation for the allocators: find the buffer's track/sector (prep_a) and load the BAM,
; geometry and partition type (prep_b). Z = 1 if the partition is native.
alloc_prep_a
        jsr ts_from_buf

; --- alloc_prep_b: Allocation preparation: set geometry and partition type
alloc_prep_b
        jsr bam_load_if_needed   ; make sure the BAM is loaded
        jsr get_geometry         ; geometry of the current track
        jmp is_native
alloc_native_native_dir_block    ; native partition: dir blocks follow the header, file blocks start after the system area
        lda cur_track
        cmp #$01
        bne alloc_from_dir_start
        lda cur_sector
        cmp #$40
        bcs alloc_from_dir_start
        lda hdr_track            ; a header track is known: continue after it
        bne alloc_native_set_start_from_header
alloc_native_native_first_block
        lda hdr_track
        cmp #$01
        bne alloc_native_set_start_from_header
        cmp hdr_sector
        beq alloc_from_dir_scan_from_track1
alloc_native_set_start_from_header
        sta cur_track            ; start at the first block after the header
        lda dir1_sector
        sta cur_sector

; --- alloc_from_dir_start: Search for a free block starting from the system track
; Search the data area of a native partition for a free block, beginning at cur_track/cur_sector;
; falls back to track 1 sector $40 (the first data block) and gives error 72 if nothing is free.
alloc_from_dir_start
        jsr alloc_scan_tracks
        bne alloc_from_dir_mark_allocated
        lda #$01
alloc_from_dir_scan_from_track1
        sta cur_track
        lda #$40                 ; $40: first data sector on track 1
        sta cur_sector
        jsr alloc_scan_tracks
        bne alloc_from_dir_mark_allocated
        lda #$72
        jmp dos_error_00
alloc_from_dir_mark_allocated
        jmp bam_alloc_store_bit

; --- alloc_scan_tracks: Scan tracks and sectors for a free bit
; Scan the BAM bits from the current block onwards until a free one is found.
alloc_scan_tracks
        jsr bam_locate_native    ; point at the bit for the current block
alloc_scan_test_bit_loop
        jsr bam_test_bit_msb     ; test the bit (MSB first)
        bne alloc_scan_done
        inc cur_sector
        inx
        cpx #$08                 ; 8 bits per byte
        bcc alloc_scan_test_bit_loop
        ldx #$00
        iny
        cpy #$20                 ; 32 bytes per track entry
        bcc alloc_scan_test_bit_loop
        inc cur_track
        lda cur_track
        cmp geo_end_track        ; reached the last track?
        bne alloc_scan_tracks
alloc_scan_done
        rts

; --- bam_locate_bit: Locate the BAM bit for (cur_track,cur_sector) per partition type
; Locate the BAM bit of (cur_track,cur_sector). On return bam_ptr,Y = byte, X = bit number and the
; Z flag tells whether the block is allocated (Z = 1: allocated). A = byte with the bit toggled.
bam_locate_bit
        jsr get_part_type        ; partition type decides the BAM layout
        cmp #$04                 ; 1581 / CP/M: 6 bytes per track
        bcs bam_locate_locate_1581
        cmp #$01                 ; 1541/1571: 4 bytes per track
        bne bam_locate_locate_1541_1571

; --- bam_locate_native: Locate the BAM bit in a native partition (MSB-first track entries)
bam_locate_native
        jsr bam_check_valid      ; make sure the partition is ready
        jsr bam_select_sector    ; load the right BAM sector of the partition
        jsr bam_track_ptr_native ; point at the track's 32 byte entry
        jsr bam_bit_index        ; X = bit, Y = byte for the sector

; --- bam_test_bit_msb: Test BAM bit (MSB first)
; Native: the bit set means "free". Returns Z = 1 if the block is allocated; A = byte with the
; bit flipped (what to store to allocate or free it).
bam_test_bit_msb
        lda (bam_ptr),y          ; isolate the bit
        and bam_mask_msb,x       ; remember the flags
        php
        lda (bam_ptr),y          ; the byte again
        eor bam_mask_msb,x       ; toggle the bit
        plp                      ; restore Z from the AND
        rts
; --- bam_mask_msb: Bit masks, MSB first ($80..$01)
; Native BAM bit masks, bit 7 = lowest sector number in the byte.
bam_mask_msb
        !byte $80,$40,$20,$10,$08,$04,$02,$01 ; $A55D
bam_locate_locate_1581           ; 1581: track entry has a count byte and 5 bitmap bytes
        jsr bam_track_ptr_1581
bam_locate_locate_1581_index
        jsr bam_bit_index        ; skip the count byte
        iny
bam_locate_test_bit_lsb          ; 1541/1571/1581 use LSB first bit order
        lda (bam_ptr),y
        and bam_mask_lsb,x
        php
        lda (bam_ptr),y
        eor bam_mask_lsb,x
        plp
        rts
bam_locate_locate_1541_1571      ; 1541/1571 entry: 4 bytes per track, the first is the free count
        jsr bam_check_valid
        lda cur_track
        cmp #$24
        bcc locate_1541_low_track ; tracks 36+ are the second side of a 1571
        inc bam_ptr_hi           ; second side BAM lives in the next page
        lda cur_track
        sec
        sbc #$24                 ; track number on the second side
        sta bam_ptr              ; three bitmap bytes per track, no counter
        asl
        clc
        adc bam_ptr
        sta bam_ptr
        jsr bam_bit_index
        jmp bam_locate_test_bit_lsb
locate_1541_low_track            ; 1541 side 1: entry = track * 4
        lda cur_track
        asl
        asl
        sta bam_ptr
        jmp bam_locate_locate_1581_index

; --- bam_bit_index: X = bit index, Y = byte index for cur_sector
; X = bit number (sector AND 7), Y = byte index (sector / 8).
bam_bit_index
        lda cur_sector
        and #$07
        tax
        lda cur_sector
        lsr
        lsr
        lsr
        tay
        rts
; --- bam_mask_lsb: Bit masks, LSB first ($01..$80)
; 1541/1571/1581 bit masks, bit 0 = lowest sector number.
bam_mask_lsb
        !byte $01,$02,$04,$08,$10,$20,$40,$80 ; $A5AC

; --- bam_get_track_free: Get the free-count byte for cur_track (pointer in bam_ptr)
; Return the free-block counter byte of the track in A and bam_ptr (carry set: native, no counter).
bam_get_track_free
        jsr get_part_type
        cmp #$04                 ; 1581 / CP/M
        bcs bam_track_ptr_1581
        cmp #$01                 ; 1541 / 1571
        bne bam_get_free_track_ptr_1541_1571
        jsr bam_check_valid
        jsr bam_select_sector

; --- bam_track_ptr_native: Position bam_ptr at the 32-byte entry of the track (native)
bam_track_ptr_native
        lda cur_track            ; native BAM: 32 bytes per track
        asl                      ; times 32
        asl
        asl
        asl
        asl
        bcc bam_track_native_no_page_carry ; carry means the entry is in the next page
        inc bam_ptr_hi
bam_track_native_no_page_carry
        clc                      ; add the offset of this BAM sector
        adc bam_ptr
        sta bam_ptr
        ldy #$00                 ; bitmap starts at once
        sec                      ; carry set = native, no free counter in the entry
        rts

; --- bam_track_ptr_1581: Position bam_ptr at the 6-byte track entry (1581)
; 1581: 6 bytes per track. Tracks 41-80 are in the second BAM block.
bam_track_ptr_1581
        jsr bam_check_valid
        lda cur_track
        cmp #$29                 ; first half of the disk?
        bcc bam_track_1581_first_half
        inc bam_ptr_hi
        sbc #$28                 ; second BAM block: relative track
bam_track_1581_first_half
        asl                      ; track * 2
        sta bam_ptr
        asl                      ; track * 4, plus track * 2 gives track * 6
        clc
        adc bam_ptr
        adc #$0A                 ; +10: the BAM data starts at offset $10 for track 1
        sta bam_ptr
bam_read_count_byte              ; read the count byte
        ldy #$00
        lda (bam_ptr),y          ; count of free sectors on the track
        clc
        rts
bam_get_free_track_ptr_1541_1571 ; 1541/1571: counters of tracks 36+ are at $DD (offset in a separate area)
        jsr bam_check_valid
        lda cur_track
        cmp #$24
        bcc bam_get_free_track_under_36
        adc #$B8                 ; track + $B9 = $DD for track 36
        bne bam_get_free_store_pointer
bam_get_free_track_under_36
        asl                      ; track * 4
        asl
bam_get_free_store_pointer
        sta bam_ptr
        jmp bam_read_count_byte

; --- bam_check_valid: Select the BAM slot; error 74 if the partition is not ready
; Select the BAM slot; error 74 if the BAM of the partition is flagged as not usable.
bam_check_valid
        jsr bam_find_slot
        lda bam_state,x          ; bit 7 of the slot state = BAM bad
        bpl bam_check_done
        lda #$74
        jmp jt_dos_error
bam_check_done
        rts
; --- bam_count_free: Count free blocks of the partition
; Count the free blocks of the partition by going through the BAM; result in bam_free_lo/hi.
bam_count_free
        jsr bam_find_slot
        ldx #$01                 ; first track
        jsr get_geometry
        ldx bam_slot
        lda #$00
        sta bam_free_lo,x
        sta bam_free_hi,x
        jsr is_native            ; native partitions have to count bits
        beq bam_count_count_native
        lda cur_track
        pha
        ldx geo_first_track      ; first track - 1
        dex
        stx cur_track
bam_count_count_track_loop       ; loop over all tracks
        inc cur_track
        lda cur_track
        cmp geo_dir_track        ; the directory track does not count
        beq bam_count_count_track_loop
        cmp geo_end_track        ; past the last track?
        bcs bam_count_restore_non_native
        jsr bam_get_track_free   ; read the free count of this track
        lda (bam_ptr),y
        clc
        ldx bam_slot
        adc bam_free_lo,x        ; add to the partition total
        sta bam_free_lo,x
        bcc bam_count_count_track_loop
        inc bam_free_hi,x
        bne bam_count_count_track_loop
bam_count_restore_non_native
        pla
        sta cur_track
        ldx #$00
        rts
bam_count_count_native           ; native: count the set bits of every track entry
        lda cur_track
        pha
        jsr bam_flush_reload     ; start with a fresh BAM
        lda #$01
        sta cur_track            ; start at track 1
        lda #$20                 ; first entry is at $20 (32 bytes per track)
        sta bam_ptr
        ldy #$08                 ; skip the system area bytes in track 1
        !byte $2C                ; BIT skips the next LDY
bam_count_count_next_track_entry
        ldy #$00
        lda #$00
        sta tmp_ctr              ; per track counter
bam_count_count_byte_loop
        ldx #$08                 ; 8 bits per byte
        lda (bam_ptr),y
bam_count_count_bit_loop
        asl                      ; shift out the next bit, 1 = free
        bcc bam_count_next_bit
        inc tmp_ctr              ; count it
        beq bam_count_carry_into_hi
bam_count_next_bit
        dex
        bne bam_count_count_bit_loop
        iny
        cpy #$20                 ; 32 bytes per track
        bcc bam_count_count_byte_loop
        ldx bam_slot
        lda bam_free_lo,x
        clc
        adc tmp_ctr              ; add the track's count to the total
        sta bam_free_lo,x
        bcc bam_count_next_track
bam_count_carry_into_hi
        ldx bam_slot
        inc bam_free_hi,x
bam_count_next_track
        inc cur_track
        lda cur_track
        cmp geo_end_track
        beq bam_count_done_native
        lda bam_ptr              ; next 32 byte entry
        clc
        adc #$20
        sta bam_ptr
        bne bam_count_count_next_track_entry ; crossed into the second page of the BAM sector
        inc bam_ptr_hi
        lda bam_ptr_hi
        and #$01                 ; odd page: still the same 512-byte BAM
        bne bam_count_count_next_track_entry
        jsr bam_next_sector      ; BAM sector used up, read the next one
        lda bam_sec_idx,x
        bne bam_count_count_next_track_entry
bam_count_done_native
        pla
        sta cur_track
        ldx #$00
        rts

; --- cmd_new: N command: format (create) a partition/disk
; N (New) command: format a partition. "N0:name,id" writes a new header, directory and BAM.
; Without an ID only the BAM and directory are cleared (quick format).
cmd_new
        jsr require_colon        ; colon is required
        jsr resolve_specs        ; resolve the partition and path
        jsr led_on               ; activity LED
        jsr get_part_type        ; partition type
        beq cmd_new_illegal_partition ; type 0 = not created
        cmp #$06                 ; only types 1-5 can be formatted
        bcc cmd_new_type_ok
cmd_new_illegal_partition
        lda #$77                 ; error 77 SELECTED PARTITION ILLEGAL
        jmp dos_error
cmd_new_type_ok
        jsr bam_find_slot        ; BAM cache slot of this partition
        lda #$00                 ; the BAM is no longer valid
        sta bam_state,x
        jsr release_part_chans   ; close all channels of the partition
        ldx name_start+1         ; offset of the ID after the name
        cpx cmd_len              ; is an ID given?
        beq cmd_new_no_id_given
        lda cmd_buf,x            ; ID characters
        sta disk_id1
        lda cmd_buf+1,x
        sta disk_id2
        jsr get_dir_track        ; directory track of the partition
        bne cmd_new_geometry_setup ; set: ok
        txa
        jsr set_default_dir      ; no directory yet: set the default one for the type
        jmp cmd_new_geometry_setup
cmd_new_no_id_given
        jsr init_partition       ; no ID: mount the existing partition
        jsr get_dir_track        ; there has to be a directory
        bne cmd_new_geometry_setup
        lda #$73                 ; error 73 (not formatted yet)
        jmp dos_error_00
cmd_new_geometry_setup
        ldx #$01                 ; geometry of track 1
        jsr get_geometry
        jsr is_native            ; native?
        bne cmd_new_non_native_check
        lda #$01                 ; native: the header must be at track 1 sector 1
        cmp hdr_track
        bne cmd_new_no_format_needed
        cmp hdr_sector
        beq cmd_new_write_new_header
cmd_new_no_format_needed
        rts
cmd_new_non_native_check         ; 1541/1571/1581 types
        cmp #$04                 ; types 2 and 3 (1541, 1571) have no separate header block
        bcc cmd_new_clear_dir_and_bam
cmd_new_write_new_header
        jsr new_write_header     ; build the header block in the buffer
        jsr write_header_blk     ; and write it
cmd_new_clear_dir_and_bam
        jsr new_clear_dir        ; clear the first directory block
        jsr write_dir1_blk       ; write it
        jsr new_build_bam        ; build an empty BAM
        jsr bam_write_if_dirty   ; write the BAM
        jmp init_partition       ; then mount the new partition

; --- new_write_header: Write the header sector
; Build the header block; for a native partition also store its own location (offset 32/33)
; and DOS version 'H' (format id "1H").
new_write_header
        jsr new_build_header
        jsr is_native
        bne new_header_done      ; only native partitions
        lda hdr_track
        sta dirblk_buf+32
        lda hdr_sector
        sta dirblk_buf+33
        lda #$48                 ; 'H' = native DOS version
        ldx #$31                 ; '1'
        tay
        jmp new_header_store_version_info ; common tail

; --- new_build_header: Build the header block (name, ID, DOS version)
; Build the partition header block in dirblk_buf: link to the first directory block (bytes 0/1),
; DOS version, disk name (16 chars padded with $A0, offset 4), ID (offset 22/23) and the format
; characters "3D" at offset 25/26 (1581 style).
new_build_header
        jsr clear_dirblk
        lda hdr_track
        sta dirblk_buf           ; link track = header track
        lda dir1_sector
        sta dirblk_buf1          ; link sector = first directory sector
        ldx #$18                 ; fill name area ($A0 = shifted space)
        lda #$A0
new_header_clear_name_loop
        sta dirblk_buf+4,x
        dex
        bpl new_header_clear_name_loop
        ldx name_start           ; the name starts at name_start in the command
        ldy #$00
new_header_copy_name_loop
        lda cmd_buf,x
        cmp #$2C                 ; a comma ends the name
        beq new_header_fill_id
        sta dirblk_buf+4,y
        inx
        cpx cmd_len              ; end of the command?
        bcs new_header_fill_id
        iny
        cpy #$10                 ; max 16 characters
        bcc new_header_copy_name_loop
new_header_fill_id
        lda disk_id1             ; disk ID
        sta dirblk_buf+22
        lda disk_id2
        sta dirblk_buf+23
        lda #$44                 ; $44 'D' = DOS version of the 1581-style format
        ldx #$33                 ; '3'
        ldy #$44                 ; 'D'
new_header_store_version_info
        sta dirblk_buf+2         ; offset 2 = DOS version
        stx dirblk_buf+25        ; offset 25/26 = format id characters
        sty dirblk_buf+26
new_header_done
        rts

; --- clear_dirblk: Clear the directory-block buffer
; Clear the 256 byte directory buffer ($2200).
clear_dirblk
        lda #$00
        tax
clear_dirblk_clear_loop
        sta dirblk_buf,x
        inx
        bne clear_dirblk_clear_loop
        rts

; --- new_clear_dir: Clear the first directory block
; Clear the first directory block: all entries zero, link = $00/$FF (the only block).
new_clear_dir
        jsr read_dir1_blk
        ldx #$00
new_cleardir_clear_entries_loop
        lda #$00
        sta dirblk_buf,x         ; entry bytes 0, 1 and 2 (link, file type) of each entry
        sta dirblk_buf1,x
        sta dirblk_buf+2,x
        txa
        clc
        adc #$20                 ; 32 bytes per directory entry
        tax
        bne new_cleardir_clear_entries_loop
        beq dirblk_init_set_link_end

; --- dirblk_init_link: Clear the buffer and set link = $00/$FF
; Clear the buffer and set the link to track 0, sector $FF (last block, all of it used).
dirblk_init_link
        jsr clear_dirblk
dirblk_init_set_link_end
        lda #$FF                 ; $FF = whole block is the last in the chain
        sta dirblk_buf1
        rts

; --- new_build_bam: Build the empty BAM for the partition type
; Build an empty BAM for the partition in the current slot.
new_build_bam
        jsr bam_find_slot
        jsr clear_bam_buf        ; clear the 512-byte cache buffer
        ldx bam_slot
        lda #$01                 ; dirty so it gets written
        sta bam_dirty,x
        jsr get_part_type        ; partition type selects the builder
        asl
        tax
        lda new_bam_tbl-2,x
        sta disp_vec
        lda new_bam_tbl-1,x
        sta disp_vec+1
        jmp (disp_vec)
; --- new_bam_tbl: Partition type -> BAM initialiser
new_bam_tbl
        !word new_bam_native                  ; $A803
        !word new_bam_1541                  ; $A805
        !word new_bam_1571                  ; $A807
        !word new_bam_1581                  ; $A809
        !word new_bam_1581                  ; $A80B

; --- new_bam_native: Initial BAM for a native partition (16 BAM sectors, DOS version 'H')
; Native: header of the BAM block, then 16 BAM sectors of $FF (every block free).
new_bam_native
        ldy #$02
        lda #$48                 ; $48 = 'H', DOS version
        sta (bam_ptr),y
        iny
        eor #$FF                 ; bit-inverted version byte follows
        sta (bam_ptr),y
        iny
        jsr bam_put_diskid       ; disk ID
        lda #$C0                 ; $C0 = I/O flags (verify on, check header CRC)
        sta (bam_ptr),y
        ldy #$08                 ; offset 8 = number of the last track
        ldx geo_end_track
        dex
        txa
        sta (bam_ptr),y          ; (end track - 1)
        ldy #$24                 ; offset $24: constant $1F
        lda #$1F
        sta (bam_ptr),y
        iny
        lda #$00
        ldx bam_slot
        sta bam_sec_idx,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
new_bam_native_write_bam_sector_loop
        ldy #$00
        lda #$FF                 ; all blocks free
        jsr fill_page_x2         ; fill both pages of the 512-byte sector
        jsr bam_sync             ; write the BAM sector
        inc bam_sec_idx,x        ; next BAM sector
        lda bam_sec_idx,x
        cmp #$10                 ; 16 BAM sectors
        bcc new_bam_native_write_bam_sector_loop
        lda geo_end_track        ; free blocks = (tracks - 2) * 256 + $C0
        sbc #$02
        sta bam_free_hi,x
        lda #$C0
        sta bam_free_lo,x
        rts

; --- new_bam_1581: Initial BAM for a 1581-type partition
; 1581: every track has 40 sectors, all free to begin with.
new_bam_1581
        lda geo_first_track
        sta cur_track
new_bam_1581_track_entry_loop
        jsr bam_track_ptr_1581
        lda #$28                 ; $28 = 40 free sectors
        sta (bam_ptr),y
        lda #$FF
new_bam_1581_fill_free_bits
        iny
        sta (bam_ptr),y          ; 5 bitmap bytes, all set
        cpy #$05
        bcc new_bam_1581_fill_free_bits
        inc cur_track
        lda cur_track
        cmp geo_end_track
        bcc new_bam_1581_track_entry_loop
        lda hdr_track            ; the directory track: header, two BAM blocks and the first directory block are used
        sta cur_track
        jsr bam_track_ptr_1581
        lda #$24                 ; $24 = 36 free sectors
        sta (bam_ptr),y
        iny
        lda #$F0                 ; $F0 = sectors 0-3 used
        sta (bam_ptr),y
        jsr bam_find_slot        ; BAM header of the first BAM block (link to the second, version, ID)
        lda hdr_track
        ldx #$02
        jsr new_bam_hdr
        inc bam_ptr_hi           ; second BAM block
        lda #$00                 ; link = 0/$FF: last BAM block
        ldx #$FF
        jsr new_bam_hdr
        dec bam_ptr_hi
        jmp bam_count_free

; --- new_bam_hdr: Write 1581 BAM header (track, link, version, ID)
; Write the 1581 BAM block header: link track A, link sector X, DOS version 'D', its inverted
; value, disk ID and flags $C0.
new_bam_hdr
        ldy #$00
        sta (bam_ptr),y
        iny
        txa
        sta (bam_ptr),y
        iny
        lda #$44
        sta (bam_ptr),y
        iny
        eor #$FF
        sta (bam_ptr),y
        iny
        jsr bam_put_diskid
        lda #$C0
        sta (bam_ptr),y
        rts

; --- new_bam_1541: Initial BAM for a 1541-type partition (header template, then count free)
; 1541: fill the header from templates, then count the free blocks.
new_bam_1541
        jsr bam_fill_header
        jmp bam_count_free

; --- bam_fill_header: Fill the BAM block header from the template tables
; Fill the 1541-style BAM block from the template tables bam_tmpl_*: for each of the 9 zones
; the track entry (free count and bitmap bytes) is repeated tmpl_count times.
bam_fill_header
        ldy #$00
        ldx #$00
bam_fill_header_template_group_loop
        lda bam_tmpl_count,x
        sta tmp_ctr
bam_fill_header_template_entry_loop
        lda bam_tmpl_b0,x
        sta (bam_ptr),y
        iny
        lda bam_tmpl_b1,x
        sta (bam_ptr),y
        iny
        lda bam_tmpl_b2,x
        sta (bam_ptr),y
        iny
        lda bam_tmpl_b3,x
        sta (bam_ptr),y
        iny
        dec tmp_ctr
        bne bam_fill_header_template_entry_loop
        inx
        cpx #$09
        bcc bam_fill_header_template_group_loop
        ldy #$90                 ; disk name goes to offset $90
        ldx name_start
bam_fill_header_copy_disk_name_loop
        lda cmd_buf,x
        cmp #$2C                 ; comma ends the name
        beq bam_fill_header_put_id
        sta (bam_ptr),y
        inx
        cpx cmd_len
        bcs bam_fill_header_put_id
        iny
        cpy #$A0                 ; 16 characters max
        bcc bam_fill_header_copy_disk_name_loop
bam_fill_header_put_id
        ldy #$A2                 ; disk ID at offset $A2

; --- bam_put_diskid: Write the disk ID bytes
bam_put_diskid
        lda disk_id1
        sta (bam_ptr),y
        iny
        lda disk_id2
        sta (bam_ptr),y
        iny
        rts

; --- new_bam_1571: Initial BAM for a 1571-type partition
; 1571: like 1541, plus the BAM of the second side.
new_bam_1571
        jsr bam_fill_header
        ldy #$03                 ; byte 3 = $80: double sided disk
        lda #$80
        sta (bam_ptr),y
        ldx #$01
        ldy #$DD                 ; free counts for the tracks 36-70 are stored at offset $DD
new_bam_1571_side2_count_loop
        lda bam_tmpl_count,x     ; use the template counts of tracks 1-35 (21, 17, 19, 18, 17 sectors)
        sta tmp_ctr
        lda bam_tmpl_b0,x
new_bam_1571_side2_count_fill
        sta (bam_ptr),y
        iny
        dec tmp_ctr
        bne new_bam_1571_side2_count_fill
        inx
        cpx #$06
        bcc new_bam_1571_side2_count_loop
        ldy #$EE                 ; track 53 (BAM track of side 2): $DD + 17 = $EE
        lda #$00                 ; no free blocks on track 53
        sta (bam_ptr),y
        inc bam_ptr_hi           ; bitmaps of side 2 are in the next page
        ldx #$01
        ldy #$00
new_bam_1571_side2_bitmap_group  ; bitmap bytes of tracks 36-70 follow the same pattern as tracks 1-35
        lda bam_tmpl_count,x
        sta tmp_ctr
new_bam_1571_side2_bitmap_entry
        lda bam_tmpl_b1,x
        sta (bam_ptr),y
        iny
        lda bam_tmpl_b2,x
        sta (bam_ptr),y
        iny
        lda bam_tmpl_b3,x
        sta (bam_ptr),y
        iny
        dec tmp_ctr
        bne new_bam_1571_side2_bitmap_entry
        inx
        cpx #$06
        bcc new_bam_1571_side2_bitmap_group
        ldy #$33                 ; clear the three unused bytes $33-$35
        lda #$00
new_bam_1571_clear_trailer_loop
        sta (bam_ptr),y
        iny
        cpy #$36
        bcc new_bam_1571_clear_trailer_loop
        jmp bam_count_free
; --- bam_tmpl_count: BAM header template: repeat counts
; Templates for the 1541 BAM block, one column per byte, 9 groups. Each group is repeated
; tmpl_count times:
;   1x header (link 18/1, DOS version 'A'), 17x tracks 1-17 (21 free, FF FF 1F),
;   1x track 18 (17 free, FC FF 07), 6x tracks 19-24 (19 free), 6x tracks 25-30 (18 free),
;   5x tracks 31-35 (17 free), 5x name area ($A0 padding), 1x format chars "2A", 1x padding.
bam_tmpl_count
        !byte $01,$11,$01,$06,$06,$05,$05,$01,$01 ; $A976
; --- bam_tmpl_b0: BAM header template: byte 0 of each entry
bam_tmpl_b0
        !byte $12,$15,$11,$13,$12,$11,$A0,$A0,$A0 ; $A97F
; --- bam_tmpl_b1: BAM header template: byte 1
bam_tmpl_b1
        !byte $01,$FF,$FC,$FF,$FF,$FF,$A0,$32,$A0 ; $A988
; --- bam_tmpl_b2: BAM header template: byte 2
bam_tmpl_b2
        !byte $41,$FF,$FF,$FF,$FF,$FF,$A0,$41,$A0 ; $A991
; --- bam_tmpl_b3: BAM header template: byte 3
bam_tmpl_b3
        !byte $00,$1F,$07,$07,$03,$01,$A0,$A0,$00 ; $A99A

; --- clear_bam_buf: Zero the 512-byte BAM cache buffer
; Clear the 512-byte BAM buffer.
clear_bam_buf
        lda #$00
        tay

; --- fill_page_x2: Fill two pages with A
; Fill two pages (512 bytes) at bam_ptr with A.
fill_page_x2
        sta (bam_ptr),y
        iny
        bne fill_page_x2
        inc bam_ptr_hi
fill_page_second_page_loop
        sta (bam_ptr),y
        iny
        bne fill_page_second_page_loop
        dec bam_ptr_hi
        rts

; --- cmd_block: B command: B-R B-W B-A B-F B-P B-E
; B command: B-R, B-W, B-A, B-F, B-P, B-E (and U1/U2 aliases). The letter after '-' is looked up
; in blk_cmd_chars and the routine is called through blk_cmd_tbl.
cmd_block
        ldy #$00
        ldx #$00
        lda #$2D                 ; find the '-'
        jsr find_char
        bne cmd_block_check_dash_position
cmd_block_invalid_command
        jmp err_31_invalid_cmd
block_syntax_error
        jmp err_30_syntax
cmd_block_check_dash_position
        txa                      ; X = 0 means a plain "B-" with nothing in front
        bne block_syntax_error
        ldx #$07                 ; 8 sub-commands
        lda cmd_buf,y
cmd_block_find_subcommand_loop
        cmp blk_cmd_chars,x      ; which letter?
        beq cmd_block_dispatch_subcommand
        dex
        bpl cmd_block_find_subcommand_loop
        bmi cmd_block_invalid_command
cmd_block_dispatch_subcommand
        txa
        ora #$80                 ; class = index with bit 7 set
        sta cmd_class
        jsr parse_blk_params     ; parse channel, track, sector parameters
        lda cmd_class
        asl
        tax
        lda blk_cmd_tbl+1,x      ; routine address from the table
        sta tmp_b
        lda blk_cmd_tbl,x
        sta tmp_a

; --- call_ptr50: jmp ($0050)
call_ptr50                       ; jump to the sub-command
        jmp (tmp_a)

; --- parse_blk_params: Parse channel and block parameters of a B-command
; Parse the numbers after the command letter. Up to 4 numbers (channel, partition?, track,
; sector) are stored in the spec tables (16 bit each: spec_trk high, spec_sec low).
parse_blk_params
        ldy #$00
        ldx #$00
        lda #$3A                 ; find the ':'
        jsr find_char
        bne parse_next_number
        ldy #$03                 ; no colon: numbers start after "B-X"

; --- parse_next_number: Skip separators and parse the next decimal number
; Skip separators (space, cursor right $1D, comma) and parse the next number.
parse_next_number
        lda cmd_buf,y
        cmp #$20
        beq parse_next_skip_separator
        cmp #$1D
        beq parse_next_skip_separator
        cmp #$2C
        bne parse_next_parse_number
parse_next_skip_separator
        iny
        cpy cmd_len
        bcc parse_next_number
        rts
parse_next_parse_number
        jsr parse_decimal        ; decimal number to binary
        inc file_idx             ; next parameter slot
        ldy file_cur
        cpx #$04                 ; max four parameters
        bcc parse_next_skip_separator
        bcs block_syntax_error

; --- parse_decimal: Parse a decimal number at ($0200),Y into the parameter tables
; Parse a decimal number at cmd_buf,Y (up to three digits) into spec_trk,X / spec_sec,X as a
; 16 bit value (high byte in spec_trk).
parse_decimal
        lda #$00
        sta tmp_a
        sta tmp_b
        sta tmp_d
        ldx #$FF
parse_decimal_read_digit_loop
        lda cmd_buf,y            ; digits are $30-$39
        cmp #$40
        bcs parse_decimal_convert_digits
        cmp #$30
        bcc parse_decimal_convert_digits
        and #$0F
        pha                      ; keep the digit value
        lda tmp_b                ; shift the digits: tmp_a = ones, tmp_b = tens, tmp_c = hundreds
        sta tmp_c
        lda tmp_a
        sta tmp_b
        pla
        sta tmp_a
        iny
        cpy cmd_len
        bcc parse_decimal_read_digit_loop
parse_decimal_convert_digits
        sty file_cur             ; remember the command pointer
        clc
        lda #$00
parse_decimal_next_digit_position
        inx
        cpx #$03
        bcs parse_decimal_store_result
        ldy tmp_a,x              ; digit * its power of ten by repeated addition
parse_decimal_add_power_loop
        dey
        bmi parse_decimal_next_digit_position
        adc pow10_tbl,x          ; add 1, 10 or 100
        bcc parse_decimal_add_power_loop
        clc
        inc tmp_d                ; carry into the high byte
        bne parse_decimal_add_power_loop
parse_decimal_store_result
        pha
        ldx file_idx
        lda tmp_d
        sta spec_trk,x
        pla
        sta spec_sec,x
        rts
; --- pow10_tbl: Powers of ten (1,10,100) for decimal parsing
; Powers of ten.
pow10_tbl
        !byte $01,$0A,$64               ; $AA74

; --- block_free: B-F: free a block in the BAM
; B-F: free a block in the BAM.
block_free
        jsr block_prep_ts        ; track and sector from the parameters
        jsr check_part_valid
        jsr bam_free_block       ; release the block
        jmp cmd_complete

; --- block_allocate: B-A: allocate a block in the BAM
; B-A: allocate a block. If the requested block is not free the error 65 NO BLOCK reports the
; next free block (track/sector in the error message), just like the 1541.
block_allocate
        jsr block_prep_ts
        jsr check_part_valid
        lda cur_sector           ; requested sector
        pha
        jsr bam_find_free_in_track ; search the track for a free sector from there
        beq block_alloc_cmd_drop_saved_sector ; none on this track
        pla
        cmp cur_sector           ; is the found sector the one requested?
        bne block_alloc_cmd_report_next_free_block
        jsr bam_allocate_block   ; yes: allocate it
        jmp cmd_complete
block_alloc_cmd_drop_saved_sector ; try the following tracks
        pla
block_alloc_cmd_try_next_track
        lda #$00
        sta cur_sector
        inc cur_track            ; next track
        beq block_alloc_cmd_report_no_blocks ; wrapped to 0: no more tracks
        lda geo_end_track        ; end track of the partition (0 = native, no limit)
        beq block_alloc_cmd_scan_track
        cmp cur_track
        bcc block_alloc_cmd_report_no_blocks
        beq block_alloc_cmd_report_no_blocks
block_alloc_cmd_scan_track
        jsr bam_find_free_in_track
        beq block_alloc_cmd_try_next_track
block_alloc_cmd_report_next_free_block
        lda #$65                 ; error 65 with the number of the next free block
        jsr jt_dos_error
block_alloc_cmd_report_no_blocks
        lda #$65                 ; error 65 with track 0 sector 0: nothing free
        jsr dos_error_00

; --- block_chan_find: Find the channel for a block command
; Find the channel for a block command and read its buffer.
block_chan_find
        jsr block_prep
        jmp read_chan_buf

; --- block_get_byte: Fetch the byte at the channel's buffer pointer
; Fetch the byte at the channel's buffer pointer.
block_get_byte
        jsr chan_buf_x2
        lda (buf_ptr_tbl,x)
        rts

; --- block_read_to_chan: B-R: read a block into the channel buffer
; B-R: read a block into the channel buffer and prepare to read it back.
block_read_to_chan
        jsr block_chan_find
        lda #$00
        jsr chan_set_ptr         ; buffer pointer to 0
        jsr block_get_byte
        sta chan_last,y          ; last = first byte (the first byte is the count of bytes to read)
        lda #$89                 ; $89 = active, reading
        sta chan_flags,y
        rts

; --- block_read_old: U1-style block read
; U1: block read with the old CBM behaviour (pointer set after the first byte).
block_read_old
        jsr block_read_to_chan
        jsr direct_next_ptr
        jmp cmd_complete

; --- u1_entry: U1: block read (direct access)
; U1: read a block into the buffer.
u1_entry
        pha                      ; dummy values so the common exit can pull them
        pha
        jmp u1_read_and_finish

; --- u1_parse: U1 with parameter parsing
; U1 with parameters: parse them first, then the same routine as B-R.
u1_parse
        jsr parse_blk_params
u1_read_and_finish
        jsr block_read_to_chan   ; read the block into the channel buffer
        lda chan_last,y          ; the first data byte is the length
        sta chan_byte,y
        lda #$FF                 ; $FF = pointer at the end, buffer is read as a normal file
        sta chan_last,y
        pla                      ; drop the dummy values
        pla
        jmp cmd_complete

; --- block_pointer: B-P: set the buffer pointer
; B-P: set the buffer pointer of a direct channel (the byte at the pointer is the count).
block_pointer
        jsr block_prep
        jsr chan_get_ptr         ; the current pointer
        tay
        dey
        cmp #$02                 ; pointer must be at least 2 (after link bytes)
        bcs block_pointer_pointer_ok
        ldy #$01
block_pointer_pointer_ok
        lda #$00                 ; pointer back to 0
        jsr chan_set_ptr
        tya
        jsr chan_put_byte        ; store the pointer value into byte 0
        txa
        pha
        jsr block_write_to_disk  ; write it to disk
        pla
        tax
        ldy cur_chan
        jmp block_fetch_byte_finish

; --- u2_entry: U2: block write (direct access)
; U2: write the channel buffer to a block.
u2_entry
        pha
        pha
        jmp u2_write_and_finish

; --- u2_parse: U2 with parameter parsing
; U2 with parameters.
u2_parse
        jsr parse_blk_params
u2_write_and_finish
        jsr block_prep
        jsr block_write_to_disk
        pla
        pla
        jmp cmd_complete

; --- block_write_to_disk: B-W / U2: write the channel buffer to disk with BAM special cases
; B-W / U2: write the channel's buffer to disk. If the block written is one of the BAM blocks of
; the partition, the BAM cache is updated with the new contents so the DOS stays in step.
block_write_to_disk
        jsr write_chan_buf       ; write the buffer
        jsr bam_find_slot        ; find the partition's BAM slot
        lda #$00
        jsr chan_set_ptr         ; buffer pointer to 0
        jsr is_native            ; native partition?
        ldx cur_track
        ldy cur_sector
        cmp #$06                 ; types 6 and above: no BAM
        bcs block_write_done
        cmp #$04                 ; 1581: BAM in sectors 1 and 2 of track 40
        bcs block_write_check_1581_track
        cmp #$02                 ; 1541?
        beq block_write_check_1541_bam_track
        bcs block_write_check_1571_bam_side2
        cpx #$01                 ; native: BAM at track 1, sectors 2-33 (two blocks per BAM sector)
        bne block_write_done
        cpy #$02
        bcc block_write_done
        cpy #$22                 ; sector range 2-$21
        bcs block_write_done
        dey                      ; sector - 2
        dey
        tya
        lsr                      ; which BAM sector does this belong to?
        ldx bam_slot
        cmp bam_sec_idx,x        ; only if that BAM sector is the one currently cached
        bne block_write_done
        tya
        lsr
        bcc block_write_copy_to_bam_cache ; first half
        bcs block_write_second_bam_page
block_write_done
        rts
block_write_check_1581_track
        cpx #$28                 ; 1581: track 40
        bne block_write_done_1581
        dey                      ; sector 1 = first BAM block
        beq block_write_copy_to_bam_cache
        dey                      ; sector 2 = second BAM block
        beq block_write_second_bam_page
block_write_done_1581
        rts
block_write_check_1571_bam_side2
        cpx #$35                 ; 1571: second side BAM at track 53 sector 0
        bne block_write_check_1541_bam_track
        tya
        beq block_write_second_bam_page
        rts
block_write_check_1541_bam_track
        cpx #$12                 ; 1541/1571: BAM at track 18 sector 0
        bne block_write_return_1541_bam
        tya
        beq block_write_copy_to_bam_cache
block_write_return_1541_bam
        rts
block_write_second_bam_page
        inc bam_ptr_hi           ; second 256 bytes of the BAM slot
block_write_copy_to_bam_cache
        ldy #$00
block_write_copy_loop
        lda (dir_ptr),y          ; copy the written block into the BAM cache
        sta (bam_ptr),y
        iny
        bne block_write_copy_loop
        rts

; --- block_execute: B-E: execute code in a buffer
; B-E: execute the code in the buffer of the channel. The buffer starts at $0300 + 256 * n.
block_execute
        jsr block_chan_find      ; find the channel
        lda #$00                 ; address low
        sta tmp_a
        lda cur_buf_idx          ; buffer number
        clc
        adc #$03                 ; +3 = page
        sta tmp_b
        jsr call_ptr50           ; call the buffer
        jmp cmd_complete

; --- block_pointer_set: Set the direct channel's pointer
; B-P (the old way): get the channel and set the buffer pointer from the second parameter.
block_pointer_set
        jsr block_get_chan_param
        lda cur_buf_idx
        asl
        tax
        lda spec_sec+1           ; new pointer
        sta buf_ptr_tbl,x
        jsr chan_buf_x2
block_fetch_byte_finish
        jsr direct_fetch_byte
        jmp cmd_complete

; --- block_get_chan_param: Parse the channel number of a block command
; Parse the channel number (first parameter, 0-14) of a block command.
block_get_chan_param
        lda spec_sec
        cmp #$0F                 ; channel numbers above 14 are illegal
        bcc block_chan_param_channel_ok
block_chan_param_no_channel_error
        lda #$70                 ; error 70 NO CHANNEL
        jmp dos_error_00
block_chan_param_channel_ok
        sta cur_sa
        jsr get_chan_for_sa
        bcs block_chan_param_no_channel_error
        jsr chan_cur_buf         ; buffer number of the channel
        sta cur_buf_idx
        ldx #$01
        rts

; --- block_prep: Get the channel then the track/sector parameters
; Get the channel and the track/sector parameters of a block command.
block_prep
        jsr block_get_chan_param
        !byte $2C                ; BIT skips the next LDX
; --- block_prep_ts: Get track/sector parameters of a block command
; Get the track/sector parameters: partition (first), track, sector.
block_prep_ts
        ldx #$00
        lda spec_sec+1,x         ; track
        sta cur_track
        lda spec_sec+2,x         ; sector
        sta cur_sector
        lda spec_sec,x           ; partition parameter must be 0
        bne block_prep_ts_drive_not_ready
        lda cur_part
        jsr set_part_from_spec
        jsr check_ts_legal
        jmp led_on
block_prep_ts_drive_not_ready
        lda #$74                 ; error 74 DRIVE NOT READY
        jmp dos_error_00
; --- blk_cmd_chars: Block command letters (A F R W E P and U1/U2 forms)
; Block command letters: A F R W E P, and U1 U2 (shifted R, W).
blk_cmd_chars
        !byte $41,$46,$52,$57,$45,$50,$D2,$D7 ; $AC09
; --- blk_cmd_tbl: Block command -> routine
; Block command -> routine.
blk_cmd_tbl
        !word block_allocate                  ; $AC11
        !word block_free                  ; $AC13
        !word block_read_old                  ; $AC15
        !word block_pointer                  ; $AC17
        !word block_execute                  ; $AC19
        !word block_pointer_set                  ; $AC1B
        !word u1_entry                  ; $AC1D
        !word u2_entry                  ; $AC1F
; C command (copy / concatenate): "C0:new=old1,old2,...". The files are read in turn and
; written to the new file. If the destination is also the first source the other files are
; appended to it.
cmd_copy_files
        jsr find_colon           ; find the colon
        bne cmd_copy_files_have_colon
        jmp cmd_invalid_31
cmd_copy_files_have_colon
        jsr parse_spec_list      ; parse the file specs
        jsr resolve_specs_ro     ; look the files up (read only)
        lda syntax_flags         ; syntax flags: bits show which wild cards and separators were used
        and #$55                 ; any of the "no =" patterns
        bne cmd_copy_files_check_syntax_flags
        ldx name_start
        lda cmd_buf,x
        cmp #$2A
        bne cmd_copy_files_check_syntax_flags ; '*' in the destination name is not allowed
cmd_copy_files_syntax_error
        jmp err_30_syntax
cmd_copy_files_check_syntax_flags
        lda syntax_flags         ; only certain pattern combinations are legal
        and #$D9
        bne cmd_copy_files_syntax_error
        jsr sort_specs_by_part   ; group the specs by partition
        jsr copy_check_types     ; check the file types are all copyable
        lda file_count
        cmp #$03                 ; at least 3 files (dest + 2 sources)
        bcc cmd_copy_files_copy_separate_files
        lda spec_part            ; do destination and first source name the same file? (partition, then directory entry)
        cmp spec_part+1
        bne cmd_copy_files_copy_separate_files
        lda spec_aux3
        cmp spec_aux3+1
        bne cmd_copy_files_copy_separate_files
        lda spec_aux2
        cmp spec_aux2+1
        bne cmd_copy_files_copy_separate_files
        lda spec_aux1
        cmp spec_aux1+1
        bne cmd_copy_files_copy_separate_files
        jsr find_empty_spec      ; find the destination spec slot
        lda #$01
        sta file_cur
        jsr copy_open_source     ; first source
        jsr chan_get_type        ; channel type of the source
        bcs cmd_copy_files_type_mismatch_error
        cmp #$02                 ; type 2 = ? write-type: not allowed
        bne cmd_copy_files_append_to_first_source
cmd_copy_files_type_mismatch_error
        lda #$64
        jsr dos_error_00
cmd_copy_files_append_to_first_source
        lda #$12                 ; the destination is the file to append to: re-use channel 18
        sta cur_sa
        lda sa_chan+17
        sta sa_chan+18
        lda #$FF
        sta sa_chan+17
        jsr file_read_seek_end   ; skip to the end of the file
        ldx #$02                 ; source files start at spec 2
        jsr copy_file_loop
        jmp cmd_complete
cmd_copy_files_copy_separate_files
        jsr copy_files_one
        jmp cmd_complete

; --- copy_files_one: C command: copy one file
; Copy files to a new file.
copy_files_one
        jsr check_spec_exists    ; error if the destination exists
        lda spec_part            ; select its partition
        jsr select_partition
        jsr dir_open_chan_wr     ; open the write channel
        jsr dir_add_entry        ; new directory entry
        ldx file_idx

; --- copy_file_loop: C: copy the files of one specification
; Copy the content of source file X to the destination channel.
copy_file_loop
        stx file_cur
        jsr copy_open_source     ; open the source file
        lda #$11                 ; channel 17 = source
        sta cur_sa
        jsr get_chan_for_sa
        jsr chan_get_type        ; REL source?
        bne copy_loop_init_copy
        jsr copy_rel_setup       ; REL: copy the record layout too
copy_loop_init_copy
        lda #$08                 ; $08 = so that the first byte is read as non-last
        sta eoi_flag
        jmp copy_loop_read_next_byte
copy_loop_copy_byte_loop         ; copy byte by byte until the source is finished
        jsr put_byte_to_dest
copy_loop_read_next_byte
        jsr get_next_byte
        lda #$80                 ; channel flag b7 = end of file
        jsr chan_state_test
        beq copy_loop_copy_byte_loop
        jsr chan_get_type
        beq copy_loop_next_source ; a type-0 channel does not need the last byte
        jsr put_byte_to_dest
copy_loop_next_source
        ldx file_cur             ; next source
        inx
        cpx file_count
        bcc copy_file_loop
        lda #$12                 ; channel 18 = destination: close it
        sta cur_sa
        jmp close_channel

; --- copy_open_source: C: open the source file
; Open source file number file_cur of the copy list for reading.
copy_open_source
        ldx file_cur
        lda spec_aux1,x          ; directory entry location of the file (track, sector, offset)
        sta cur_track
        lda spec_aux2,x
        sta cur_sector
        lda spec_part,x
        jsr select_partition     ; select its partition
        jsr dir_open_chan        ; open the directory channel at that block
        ldx file_cur
        lda spec_aux3,x
        jsr chan_set_ptr         ; point at the entry
        ldx file_cur
        lda spec_type,x          ; file type of the source
        and #$07
        sta file_type
        lda #$00
        sta rel_rec_len          ; REL record length unknown yet
        jsr open_existing_file_chan ; open the file itself
        ldy #$01                 ; data starts after the 2 link bytes
        jsr chan_get_type
        beq copy_open_set_pointer ; sequential file: pointer 1; others 2
        iny
copy_open_set_pointer
        tya
        jmp chan_set_ptr

; --- copy_rel_setup: C: handle REL file copy
; Copying a REL file: position the destination at the same record layout as the source.
copy_rel_setup
        jsr rel_first_side       ; side sector layout of the source
        jsr rel_is_rel
        bne copy_rel_save_side_info
        lda rel_ss_idx           ; native: keep the side sector index
        pha
copy_rel_save_side_info
        lda rel_side_off
        pha
        lda rel_side_no
        pha
        lda #$12                 ; channel 18 = destination
        sta cur_sa
        jsr get_chan_for_sa_rd
        jsr rel_seek             ; seek in the destination
        sta rel_rec_off
        pla
        sta rel_side_no
        pla
        sta rel_side_off
        jsr rel_is_rel
        bne copy_rel_finish
        pla
        sta rel_ss_idx
copy_rel_finish
        jmp rel_calc_side_offsets

; --- copy_check_types: C: verify no unsupported file types in the list
; Only types DEL..USR (0-4) can be copied; others give error 64 FILE TYPE MISMATCH.
copy_check_types
        ldx #$00
copy_types_check_loop
        lda spec_type,x
        and #$07
        cmp #$05                 ; type 5 = CBM partition entry, 6 = directory
        bcs copy_types_bad_type
        inx
        cpx file_count
        bcc copy_types_check_loop
        rts
copy_types_bad_type
        lda #$64
        jmp dos_error_00

; --- cmd_scratch: S command: scratch files. Also the software SWAP commands S-8 / S-9 (request swap_request = 8/9) and S-D (swap back to the default device number, panel_flags = $80), plus S-C
; S command. "S-C" sends a SCSI command, "S-8" and "S-9" ask for a device number swap, "S-D"
; swaps back to the default; anything else is a normal scratch.
cmd_scratch
        lda cmd_buf+1
        cmp #$2D                 ; '-'
        bne cmd_scratch_scratch_files
        lda cmd_buf+2
        cmp #$43                 ; 'C' (SCSI command)
        beq cmd_scsi_send
        cmp #$38                 ; '8'
        beq cmd_scratch_set_swap_target
        cmp #$39                 ; '9'
        beq cmd_scratch_set_swap_target
        cmp #$44                 ; 'D'
        bne cmd_scratch_scratch_files
        lda #$80                 ; swap-to-default request
        sta panel_flags
        rts
cmd_scratch_set_swap_target
        and #$0F                 ; 8 or 9
        sta swap_request         ; the panel/idle loop does the swap
        rts
cmd_scratch_scratch_files
        jmp cmd_scratch_files
cmd_scratch_bad_length
        jmp err_31_invalid_cmd
; --- cmd_scsi_send: S-C: send a raw SCSI command (S-C + target + buffer lo/hi + CDB bytes), status byte returned on channel 15
cmd_scsi_send
        lda cmd_len              ; S-C needs target, buffer address (2 bytes) and at least a 6 byte CDB
        cmp #$0C
        bcc cmd_scratch_bad_length
        sei                      ; no interrupts while the SCSI bus is used
        jsr load_scsi_cdb_from_cmd ; copy the CDB into scsi_cdb
        lda scsi_cdb
        cmp #$2F                 ; $2F = VERIFY(10): may need emulating
        beq scsi_send_emulate_verify
scsi_send_run_command
        jsr scsi_command
scsi_send_return_status
        lda scsi_status          ; SCSI status byte, returned on the error channel
        sta chan_byte+31         ; the single byte answer
        lda #$FF
        ldx #$23
        sta errmsg_ptr           ; error pointer = end of the message buffer
        stx errmsg_ptr_hi
        lda #$88                 ; $88 = active, last byte
        sta chan_flags+31
        rts
scsi_send_emulate_verify         ; VERIFY not supported by the drive? then verify by reading each block
        jsr scsi_probe_verify
        beq scsi_send_run_command
        lda #$28                 ; $28 = READ(10) instead
        sta scsi_cdb
        lda scsi_cdb+8           ; number of blocks to verify (bytes 7/8 of the CDB)
        sta errmsg_ptr
        lda scsi_cdb+7
        sta errmsg_ptr_hi
        lda #$00                 ; read one block at a time
        sta scsi_cdb+7
        lda #$01
        sta scsi_cdb+8
scsi_send_verify_read_loop
        jsr scsi_init_ptrs       ; reset the SCSI buffer pointers
        lda #$00
        sta buf_ptr_b
        lda #$52                 ; buffer at $5200 (second half of the sector buffer)
        sta buf_ptr_b_hi
        jsr scsi_command
        bne scsi_send_return_status
        inc scsi_cdb+5           ; next block number (32 bit increment)
        bne scsi_send_count_block
        inc scsi_cdb+4
        bne scsi_send_count_block
        inc scsi_cdb+3
scsi_send_count_block
        ldx errmsg_ptr           ; 16 bit block counter
        bne scsi_send_dec_remaining
        dec errmsg_ptr_hi
scsi_send_dec_remaining
        dec errmsg_ptr
        bne scsi_send_verify_read_loop
        ldx errmsg_ptr_hi
        bne scsi_send_verify_read_loop
        jmp scsi_send_return_status

; --- scsi_probe_verify: Run the SCSI VERIFY once with zero length to see whether the target supports it
; Issue VERIFY with a zero length. If the drive accepts it (status 0) VERIFY is supported.
scsi_probe_verify
        lda #$00
        sta scsi_cdb+7
        sta scsi_cdb+8
        jsr scsi_command
        pha
        jsr load_scsi_cdb_from_cmd
        pla
        rts

; --- load_scsi_cdb_from_cmd: Load the HD RAM buffer address and the CDB bytes from the S-C command
; Prepare the CDB from the S-C command: buffer address from bytes 4/5, CDB from byte 6 on.
load_scsi_cdb_from_cmd
        jsr scsi_clear_cdb
        lda cmd_buf+4
        sta buf_ptr_b
        lda cmd_buf+5
        sta buf_ptr_b_hi
        ldx #$06                 ; CDB starts at offset 6
        ldy #$00
copy_params_copy_cdb_loop
        lda cmd_buf,x
        sta scsi_cdb,y
        iny
        inx
        cpx cmd_len
        bcc copy_params_copy_cdb_loop
        rts

; --- scsi_command: Run the SCSI CDB for the command target
; Select the target (byte 3 of the command) and run the CDB.
scsi_command
        lda cmd_buf+3
        jsr scsi_select
        bne scsi_command_target_selected
        lda #$85                 ; $85 = no select / drive not there
        sta scsi_status
        rts
scsi_command_target_selected
        jsr scsi_wait_done
        lda scsi_status
        rts
; --- open_direct_chan: OPEN '#' direct-access channel
; OPEN "#": direct access channel. "#" takes any free buffer, "#n" asks for buffer n.
open_direct_chan
        ldx cmd_len              ; length 1 = just "#"
        dex
        bne open_direct_explicit_buffer
        lda #$01                 ; one buffer
        jsr alloc_chan
        jmp open_direct_finish_open
open_direct_no_channel_error
        lda #$70                 ; error 70 NO CHANNEL
        jmp dos_error_00
open_direct_explicit_buffer
        ldy #$01                 ; buffer number follows
        jsr parse_next_number
        lda spec_sec
        cmp #$1E                 ; buffer numbers 0-29 only
        bcs open_direct_no_channel_error
        sta chan_scan_idx
        jsr buf_in_use           ; is that buffer in use?
        beq open_direct_no_channel_error
        lda #$00                 ; no buffer to allocate, we assign our own
        jsr alloc_chan
        ldx cur_chan
        lda spec_sec
        sta chan_buf,x           ; use the buffer requested
        tax
        lda #$00
        sta job_code,x           ; clear the job state
        sta job_status,x
open_direct_finish_open
        ldx cur_sa
        lda sa_chan,x
        ora #$40                 ; bit 6 in sa_chan marks a direct channel
        sta sa_chan,x
        ldy cur_chan
        lda #$FF
        sta chan_last,y          ; $FF = no end limit
        lda #$89                 ; $89 = active, read
        sta chan_flags,y
        lda chan_buf,y
        sta chan_byte,y          ; first byte available
        asl
        tax
        lda #$01                 ; pointer starts at 1
        sta buf_ptr_tbl,x
        lda #$0E                 ; channel type 7 (direct)
        sta chan_state,y
        jmp cmd_complete

; --- check_part_valid: Check the partition is initialised and its BAM good
; Check that the partition is initialised and its BAM good; mounts it if not.
check_part_valid
        jsr get_part_type
        cmp #$FF                 ; system partition needs nothing
        bne check_part_valid_check_bam_state
        lda #$00
        rts
check_part_valid_check_bam_state
        jsr bam_find_slot
        lda bam_state,x          ; 0 = BAM ok
        beq check_part_valid_done
        jsr init_partition
        ldx bam_slot
        lda bam_state,x
check_part_valid_done
        rts

; --- cmd_initialize: I command: initialize the partition
; I command: initialise (mount) the partition. For 1581-type partitions the directory goes
; back to the root.
cmd_initialize
        jsr strip_partition_arg
        jsr get_part_type
        cmp #$04
        beq cmd_initialize_reset_dir
        cmp #$05
        bne cmd_initialize_do_init
cmd_initialize_reset_dir
        jsr set_default_dir
cmd_initialize_do_init
        jsr init_partition
        jmp cmd_complete

; --- init_partition: Mount a partition: read header, set directory and BAM
; Mount a partition: close its channels, read the BAM header, check the DOS version byte and
; read the disk ID, then count the free blocks.
init_partition
        jsr release_part_chans
        lda #$00
        sta status_bits
        jsr bam_find_slot
        lda #$FF                 ; $FF = BAM not valid yet
        sta bam_state,x
        jsr get_part_type
        beq init_partition_done  ; type 0 or system: nothing to do
        cmp #$FF
        beq init_partition_done
        cmp #$06                 ; types 6 and 7 cannot be mounted
        bcc init_partition_valid_type
init_partition_done
        rts
init_partition_valid_type
        jsr get_dir_track        ; no directory known yet: use the default
        bne init_partition_read_bam_header
        jsr set_default_dir
init_partition_read_bam_header
        jsr bam_invalidate       ; read the BAM block
        ldx bam_slot
        ldy #$02
        lda (bam_ptr),y          ; DOS version byte at offset 2
        sta bam_dosver,x
        jsr is_native            ; native and 1581: the inverted copy at offset 3 is checked
        beq init_partition_check_dos_version_byte
        cmp #$04                 ; 1541/1571: ID is at offset $A2
        bcc init_partition_read_id_at_a2
init_partition_check_dos_version_byte
        ldy #$03
        lda (bam_ptr),y
        eor #$FF
        ldx bam_slot
        cmp bam_dosver,x
        bne init_partition_done
        ldy #$04                 ; native/1581: disk ID is at offset 4
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
init_partition_read_id_at_a2
        ldy #$A2                 ; 1541/1571: disk ID at offset $A2
        lda (bam_ptr),y
        sta disk_id1
        iny
        lda (bam_ptr),y
        sta disk_id2
        ldx bam_slot
        lda #$00                 ; the BAM is valid now
        sta bam_state,x
        jsr set_header_loc       ; set up the header block location
        jmp bam_count_free       ; count free blocks

; --- check_dos_ver: Compare the DOS version byte against the type table
; Compare the DOS version byte (A) of a BAM with the expected one for the partition type.
; Z = 1 if OK. Version 0 is accepted.
check_dos_ver
        cmp #$00
        beq check_dos_ver_done
        pha
        jsr get_part_type
        tax
        pla
        cmp dosver_by_type,x
check_dos_ver_done
        rts
; --- dosver_by_type: DOS version letter by partition type ('H','A','A','D','D')
; DOS version letters: native 'H', 1541/1571 'A', 1581 'D'.
dosver_by_type
        !byte $00,$48,$41,$41,$44,$44   ; $AF79

; --- get_geometry: Set geometry (first/end track, sectors per track) for track X
; Set the geometry variables for the partition: directory track, first and end track
; (exclusive) and sectors per track of track X.
get_geometry
        stx geo_secs_per_trk     ; track to look at
        jsr get_dir_track        ; directory track of the partition
        sta geo_dir_track
        jsr is_native            ; native partitions: size decides
        beq get_geometry_native_or_system
        cmp #$03                 ; 1571?
        beq get_geometry_type_1571
        bcc get_geometry_type_1541 ; 1541?
        cmp #$06                 ; 1581 / 1581 CP/M
        bcc get_geometry_type_1581_partitioned
        cmp #$FF                 ; system partition
        beq get_geometry_system_partition
        rts
get_geometry_system_partition
        lda #$01                 ; system partition: root track 1
        sta geo_dir_track
        ldx #$00
get_geometry_native_or_system
        lda part_size_lo,x       ; native: tracks = size in 512-byte blocks / 128
        asl                      ; size * 2 (256 byte sectors)
        lda part_size_hi,x
        rol
        tax                      ; high byte = number of tracks
        inx                      ; tracks start at 1, end track is one more
        stx geo_end_track
        ldx #$01
        stx geo_first_track
        dex
        stx geo_secs_per_trk     ; 0 = unlimited sectors per track
        rts
get_geometry_type_1541           ; 1541: end track $24 (36)
        lda #$24
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
get_geometry_type_1571           ; 1571: end track $47 (71)
        lda #$47
        sta geo_end_track
        lda #$01
        sta geo_first_track
        lda geo_secs_per_trk     ; find the zone of the track in zone_start_trk
        ldx #$00
get_geometry_zone_search_loop
        cmp zone_start_trk,x
        bcc get_geometry_zone_found
        inx
        bne get_geometry_zone_search_loop
get_geometry_zone_found
        dex
        lda zone_sectors,x       ; sectors per track in that zone
        sta geo_secs_per_trk
        rts
get_geometry_type_1581_partitioned ; 1581: the directory sector variable holds the last track
        lda part_dir_sector,x
        sta geo_end_track
        lda geo_dir_track
        cmp #$28                 ; track 40 = whole-disk 1581: first track is 1
        bne get_geometry_store_first_track
        lda #$01
get_geometry_store_first_track
        sta geo_first_track
        lda #$28                 ; 40 sectors per track
        sta geo_secs_per_trk
        rts

; --- set_default_dir: Select the default directory of the partition type (track/sector)
; Select the default directory for the partition type. Native: root (1/1). 1581: track 40,
; last track $51. 1541/1571: track 18 and the last track in the "sector" field.
set_default_dir
        jsr is_native
        beq set_dir_root_1
        cmp #$04
        bcc set_default_dir_type_1541_1571
        lda #$28                 ; 1581: directory track 40
        ldy #$51                 ; end track + 1 = 81
        bne set_dir
set_default_dir_type_1541_1571
        cmp #$02
        bne set_default_dir_set_1571_end_track
        ldy #$24                 ; 1541: last track 36
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
set_default_dir_set_1571_end_track
        ldy #$47                 ; 1571: last track 71
        lda #$12                 ; directory track 18
        bne set_dir

; --- set_dir_root_1: Set directory to track 1 / sector 1
; Directory root of a native partition: track 1, sector 1.
set_dir_root_1
        lda #$01
        tay

; --- set_dir: Set current partition's directory (A = track, Y = sector)
; Store the current directory: track A, sector (or last track) Y for the current partition.
set_dir
        jsr ram_protect_on       ; the partition tables are in protected RAM
        ldx cur_part
        sta part_dir_track,x
        tya
        sta part_dir_sector,x
        jmp ram_protect_off

; --- select_partition: Select partition A and its directory
; Select partition A and its directory.
select_partition
        jsr cfg_set_part         ; store as current partition (in protected RAM)

; --- set_header_loc: Set header track/sector and first dir sector for the partition
; Work out where the header block and first directory block of the partition's current
; directory are: hdr_track/hdr_sector and dir1_sector.
set_header_loc
        jsr get_dir_track        ; directory track of the partition
        bne set_header_loc_have_dir_track
        jsr set_default_dir      ; none yet: use the default for the type
        jsr get_dir_track
set_header_loc_have_dir_track
        sta hdr_track            ; header track = directory track
        lda #$00
        sta hdr_sector           ; header sector 0 for the CBM-style types
        jsr is_native            ; native partitions keep header and directory in a different layout
        beq set_header_loc_native_header
        cmp #$04                 ; 1541/1571: first directory sector is 1
        bcc set_header_loc_set_1541_first_dir
        cmp #$06                 ; 1581: first directory sector is 3
        bcc set_header_loc_set_1581_first_dir
        cmp #$FF                 ; system partition ($FF): location is stored in the configuration
        bne set_header_loc_done
        lda cfg_sys_track
        sta hdr_track
        lda cfg_sys_sector
        sta hdr_sector
        sta dir1_sector
set_header_loc_done
        rts
set_header_loc_set_1581_first_dir
        lda #$03                 ; 1581: directory starts at sector 3
        sta dir1_sector
        rts
set_header_loc_set_1541_first_dir
        lda #$01                 ; 1541/1571: directory starts at sector 1
        sta dir1_sector
        rts
set_header_loc_native_header
        jsr get_dir_sector       ; native: the "directory sector" is the header sector
        sta hdr_sector
        cmp #$01                 ; the root header is track 1 sector 1: its directory starts at $22
        bne set_header_loc_set_dir1_sector
        cmp hdr_track
        bne set_header_loc_set_dir1_sector
        lda #$21                 ; $21 + 1 = $22: directory first block after the BAM
set_header_loc_set_dir1_sector
        clc
        adc #$01                 ; first directory block follows the header
        sta dir1_sector
        rts

; --- get_part_type: A = type of the current partition
; A = type of the current partition (X = partition number).
get_part_type
        ldx cur_part
        lda part_type,x
        rts

; --- is_native: Z = 1 if the current partition is native
; Z = 1 if the current partition is native.
is_native
        ldx cur_part
        lda part_type,x
        cmp #$01
        rts

; --- get_dir_track: A = current directory track of the partition
; A = directory track of the current partition.
get_dir_track
        ldx cur_part
        lda part_dir_track,x
        rts

; --- get_dir_sector: A = current directory sector of the partition
; A = directory sector of the current partition (for 1541/1571 this holds the last track).
get_dir_sector
        ldx cur_part
        lda part_dir_sector,x
        rts
; --- cmd_mem: M command: M-R / M-W / M-E
; M command: M-R, M-W, M-E. Reading and writing work directly on the 6502 address space of the
; HD; this is how the helper programs poke the configuration RAM.
cmd_mem
        lda cmd_buf+1
        cmp #$2D                 ; "M-"
        bne cmd_invalid_31
        lda cmd_buf+3            ; address low
        sta tmp_a                ; ...
        lda cmd_buf+4            ; address high
        sta tmp_b
        ldy #$00
        lda cmd_buf+2
        cmp #$52                 ; R
        beq cmd_mem_memory_read
        cmp #$57                 ; W
        beq cmd_mem_memory_write_loop
        cmp #$45                 ; E
        bne cmd_invalid_31
        lda tmp_b                ; address high byte of the target
        cmp #$80                 ; addresses $80xx-$FExx (hardware and ROM) are not allowed to be executed...
        bcc cmd_mem_check_user_signature
        cmp #$FF
        bcs cmd_mem_check_user_signature
        rts                      ; ...so just return
cmd_mem_check_user_signature
        cmp #$06                 ; a jump to $0600 may be JiffyDOS's uploaded @L program: compare it against a signature
        bne cmd_mem_execute_at_address
        lda tmp_a                ; only if the address low byte is 0 ($0600)
        bne cmd_mem_execute_at_address
        ldy #$07                 ; compare 8 bytes at $0608 with memexec_signature
cmd_mem_compare_signature_loop
        lda $0608,y
        cmp memexec_signature,y
        bne cmd_mem_execute_at_address
        dey
        bpl cmd_mem_compare_signature_loop
        jmp cmd_l_toggle_lock_flag ; signature matched: this is JiffyDOS's @L (lock/unlock) upload, do the toggle ourselves
cmd_mem_execute_at_address
        ldy #$00                 ; otherwise execute at the address
        lda #$45
        cmp #$45
        jmp (tmp_a)              ; the code at the address is called (it returns with RTS)
cmd_mem_memory_read              ; M-R: first byte
        lda (tmp_a),y            ; byte at the address
        sta iec_byte
        lda cmd_len              ; command length: more than 6 = a count is given
        cmp #$06
        bcc cmd_mem_read_single_byte
        ldx cmd_buf+5            ; count byte
        dex                      ; count - 1 more bytes
        beq cmd_mem_read_single_byte
        txa
        clc
        adc tmp_a
        inc tmp_a                ; point at the next byte for the following reads
        sta chan_last+31         ; chan_last of the status channel: end of the data
        lda tmp_a
        sta errmsg_ptr           ; status channel pointer = the memory address (read through the error channel)
        lda tmp_b
        sta errmsg_ptr_hi
        jmp talk_err_normal_byte_flags ; set the flags as the error channel talker does
cmd_mem_read_single_byte
        jsr get_chan_for_sa      ; only one byte: read it as the status
        jmp talk_err_reset_message_pointer
cmd_invalid_31
        lda #$31
        jmp dos_error_00
cmd_mem_memory_write_loop        ; M-W: bytes start at cmd_buf+6
        lda cmd_buf+6,y
        sta (tmp_a),y
        iny
        cpy cmd_buf+5            ; count in cmd_buf+5
        bcc cmd_mem_memory_write_loop
        rts
; 8 bytes the M-E check compares at $0608. They are part of the drive-side @L (lock/unlock file) program that
; the JiffyDOS kernal uploads with M-W to $0600 and starts with M-E $0600 (JiffyDOS kernal $F398 and $F3BA):
; the program is 1541 code (LDX #$00 / STX $F9 / JSR $D586 = a 1541 ROM routine), which the HD cannot run, so
; it recognises the upload and does the lock toggle itself.
memexec_signature
        !byte $06,$A2,$00,$86,$F9,$20,$86,$D5 ; $B125
; --- cmd_rename_misc: R- commands: R-P (rename a partition) and R-H (rename a directory header)
; R- commands: R-H rename the header (disk name) of the directory; R-P rename a partition
; (name is changed in the partition table entry, partition 0 = system area).
cmd_rename_misc
        lda cmd_buf+1            ; "R-"
        cmp #$2D
        bne cmd_rename_rename_common
        lda cmd_buf+2            ; 'H'
        cmp #$48
        bne cmd_rename_test_partition_rename
        jsr prep_spec_cmd        ; parse/resolve the single spec
        lda #$00
        jsr change_directory     ; change to the directory in the path
        jsr read_header_blk      ; read the header block
        jsr is_native
        beq cmd_rename_native_header_offset ; native header: name at offset 4
        cmp #$04
        bcc cmd_rename_old_header_offset ; 1541/1571: name at offset $90
cmd_rename_native_header_offset
        ldy #$04                 ; offset 4 = native and 1581
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_rename_old_header_offset
        ldy #$90                 ; offset $90 = 1541/1571
        lda #$10                 ; 16 characters
        sta tmp_a
        ldx name_start           ; name comes from the command
cmd_rename_copy_name_loop
        cpx cmd_len              ; end of the given name? pad with $A0 (shifted space)
        bcs cmd_rename_pad_char
        lda cmd_buf,x
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_rename_pad_char
        lda #$A0
        sta dirblk_buf,y         ; store the name in the header
        inx
        iny
        dec tmp_a
        bne cmd_rename_copy_name_loop
        jsr write_header_blk     ; write the block back
        jmp cmd_complete
cmd_rename_test_partition_rename
        cmp #$50                 ; 'P' = rename a partition
cmd_rename_rename_common
        php                      ; remember which one
        jsr require_colon        ; "R-P:newname=oldname"
        jsr resolve_specs_ro
        plp
        bne cmd_rename_rename_entry ; not R-P: normal file rename
        lda #$00                 ; R-P: work on partition 0 (the partition table)
        sta spec_part
        jsr select_partition
        lda name_start           ; keep the new name in the first spec
        sta name_end_tbl
cmd_rename_rename_entry
        lda spec_part            ; the old name spec
        sta spec_part+1
        lda name_start+1
        sta name_end_tbl+1
        jsr find_entry_first     ; find the entry
        jsr check_spec_exists    ; must exist
        lda spec_aux1+1          ; its directory block
        sta cur_track
        lda spec_aux2+1
        sta cur_sector
        jsr job_read_chan_buf          ; read the block
        jsr job_wait
        lda spec_aux3+1          ; offset of the name in the entry (3 bytes later)
        clc
        adc #$03
        jsr chan_set_ptr         ; point at the name
        jsr chan_cur_buf
        tay                      ; Y = buffer index
        ldx name_start           ; copy 16 characters of the new name
        lda #$10
        jsr name_pad_copy
        jsr job_write_chan_buf_clean         ; write the entry back
        jsr job_wait
        jmp cmd_complete

; --- find_empty_spec: Find a free file spec slot; error 62 if none
; Find a free spec slot: the target of a rename or copy must not exist yet; error 62 if the
; source was not found.
find_empty_spec
        lda spec_type+1          ; file type of the second spec
        and #$07
        sta file_type
        ldx file_count           ; search backwards
find_empty_spec_check_spec_loop
        dex
        cpx file_idx
        bcc find_empty_spec_slot_found
        lda spec_trk,x           ; a spec with track = 0 was not found
        bne find_empty_spec_check_spec_loop
        lda #$62                 ; error 62 FILE NOT FOUND
        jmp dos_error_00
find_empty_spec_slot_found
        rts

; --- check_spec_exists: Error 63 if the destination exists
; Error 63 FILE EXISTS if any of the destination specs was found.
check_spec_exists
        jsr find_empty_spec
check_exists_check_loop
        lda spec_trk,x           ; track <> 0 means the file exists
        beq check_exists_next_slot
        lda #$63
        jmp dos_error_00
check_exists_next_slot
        dex
        bpl check_exists_check_loop
        rts

; --- cmd_l: L command: lock/unlock file
; L command: toggle the lock flag of a file.
cmd_l
        jsr prep_spec_cmd
        jsr check_part_valid     ; partition ok
        jsr find_entry_first     ; find the entry
        lda spec_trk             ; not found: just close
        beq cmd_l_release_and_exit
cmd_l_toggle_lock_flag           ; read the directory block of the entry
        ldx ent_track
        ldy ent_sector
        lda ent_offset
        pha
        stx cur_track
        sty cur_sector
        jsr read_cur_blk         ; read it
        pla                      ; offset of the entry
        tax
        lda dirblk_buf,x         ; file type byte
        eor #$40                 ; toggle bit 6 = locked
        sta dirblk_buf,x
        jsr write_cur_blk        ; write it back
cmd_l_release_and_exit
        jmp release_dir_chans

; --- cmd_w: W command: write protect (W0/W1)
; W command: W-0 releases the software write protect, W-1 sets it (drive_flags b7).
cmd_w
        lda cmd_buf+1
        cmp #$2D
        bne cmd_w_invalid
        lda cmd_buf+2
        cmp #$30                 ; '0'
        beq cmd_w_w0_release
        cmp #$31                 ; '1'
        beq cmd_w_w1_protect
cmd_w_invalid
        jmp err_31_invalid_cmd
cmd_w_w0_release
        lda #$80                 ; $80 = write protect flag
        bit panel_wp             ; panel_wp tells whether the protect was set by software
        beq cmd_w_done_release
        lda #$7F                 ; clear bit 7 of drive_flags
        and drive_flags
        sta drive_flags
        lda #$00
        sta panel_wp
cmd_w_done_release
        rts
cmd_w_w1_protect
        lda #$80                 ; W-1: set the flag
        bit drive_flags
        bne cmd_w_done_protect
        sta panel_wp
        ora drive_flags
        sta drive_flags
cmd_w_done_protect
        rts
; S command, plain scratch: "S0:name1,name2,...". Every matching, unlocked, closed file is
; removed and its blocks freed. The number of files scratched is returned as error 01.
cmd_scratch_files
        jsr require_colon        ; colon required
        jsr get_file_type_arg    ; optional file type argument
        jsr resolve_specs_ro     ; resolve the specs
scratch_main_restart_spec_scan
        ldx #$00                 ; count of scratched files
        stx tmp_85
scratch_main_spec_loop
        stx swap_idx             ; current spec
        lda spec_part,x          ; partition 0 means no more specs
        bne scratch_main_select_spec_partition
        jmp scratch_main_report_scratched ; end: report the result
scratch_main_select_spec_partition
        jsr swap_spec_parts      ; combine all specs of this partition
        jsr select_partition
        jsr reset_dir_search     ; start a fresh directory search
        lda swap_idx
        jsr find_entry_in_part   ; find the first matching entry
        bpl scratch_main_check_entry_scratchable
        jmp scratch_main_spec_done
scratch_main_check_entry_scratchable
        jsr find_file_open       ; is the file open on a channel?
        bcc scratch_main_next_matching_entry ; yes: skip it
        ldy #$00                 ; entry type byte
        lda (dir_ptr),y
        sta blk_cnt_hi
        and #$40                 ; bit 6 = locked
        bne scratch_main_next_matching_entry
        lda blk_cnt_hi
        and #$07                 ; file type
        cmp #$06                 ; DIR (type 6) is only removed by RD
        bne scratch_main_delete_entry
        lda cmd_class            ; RD sets cmd_class 3
        cmp #$03
        bne scratch_main_next_matching_entry
scratch_main_delete_entry
        jsr entry_clear          ; clear the directory entry
        lda blk_cnt_hi
        and #$07
        cmp #$05                 ; type 5 = CBM partition entry: free its blocks
        bne scratch_main_free_side_sector_chain
        iny                      ; first track/sector of the range
        lda (dir_ptr),y
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        ldy #$1C                 ; number of blocks at offset $1C/$1D
        lda (dir_ptr),y
        sta blk_cnt_hi
        iny
        lda (dir_ptr),y
        sta blk_cnt_lo
scratch_main_free_cbm_range_loop ; free all blocks of the range
        jsr check_ts_legal
        jsr bam_free_block
        jsr next_block_in_range
        bne scratch_main_free_cbm_range_loop
        jsr bam_write_if_dirty
        jmp scratch_main_count_scratched
scratch_main_free_side_sector_chain ; ordinary file: free the side-sector chain first
        ldy #$13                 ; offset $13/$14 = side sector (REL)
        lda (dir_ptr),y
        beq scratch_main_free_data_chain
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        jsr free_chain
scratch_main_free_data_chain     ; then the data chain
        ldx match_type
        lda #$20                 ; spec_type bit 5: no data chain
        and spec_type,x
        bne scratch_main_count_scratched
        lda spec_trk,x
        sta cur_track
        lda spec_sec,x
        sta cur_sector
        jsr free_chain
scratch_main_count_scratched
        inc tmp_85               ; count the file
scratch_main_next_matching_entry
        jsr find_next_entry      ; next match
        bmi scratch_main_spec_done
        jmp scratch_main_check_entry_scratchable
scratch_main_spec_done           ; next spec
        jsr swap_spec_parts
        ldx swap_idx
        inx
        cpx file_count
        bcs scratch_main_report_scratched
        jmp scratch_main_spec_loop
scratch_main_report_scratched    ; result: number of files scratched as error 01 with the count in the track field
        lda tmp_85
        sta cur_track
        ldy #$00
        lda #$01
        jmp cmd_status_ts

; --- free_chain: Free a block chain
; Free a chain of blocks, starting with (cur_track,cur_sector), by following the link bytes.
free_chain
        jsr bam_free_block       ; free this block
        lda cur_track
        sta job_track_b31        ; read it to get the link
        lda cur_sector
        sta job_sector_b31
        ldx #$1F
        lda #$AA                 ; $AA = read
        jsr do_job
        ldy #$01
        lda (buf_ptr_b),y        ; next sector
        sta cur_sector
        dey
        lda (buf_ptr_b),y
        sta cur_track            ; next track
        bne free_chain           ; 0 = last block
        jsr bam_write_if_dirty   ; write the BAM
        jmp release_chan

; --- cmd_time: T command: T-RA/T-RB/T-RD/T-WA.. read/write the RTC
; T command: T-RA, T-RB, T-RD read the real time clock (ASCII, BCD, decimal); T-WA, T-WB, T-WD
; set it.
cmd_time
        sei                      ; no interrupts while the clock is read or set
        lda cmd_buf+1            ; "T-"
        cmp #$2D
        bne cmd_time_invalid_command
        lda cmd_buf+2            ; 'R' = read
        cmp #$52
        beq cmd_time_read_command
        cmp #$57                 ; 'W' = write
        bne cmd_time_invalid_command
        jmp cmd_time_write_command
cmd_time_invalid_command
        jmp err_31_invalid_cmd
; --- rtc_reg_map: RTC register order table
; Where each of the 12 RTC digit registers goes in the ASCII time string (index into the message).
rtc_reg_map
        !byte $15,$14,$12,$11,$0F,$0E,$09,$08 ; $B36B
        !byte $06,$05,$0C,$0B           ; $B373
; --- day_chr1: Day-of-week text: first letters S M T W T F S
; Day-of-week names, one column per character: SUN MON TUE WED THU FRI SAT (letter 4 is a
; period or an S for "TUES"/"THURS" style names).
day_chr1
        !text "SMTWTFS"                 ; $B377
; --- day_chr2: Day-of-week text: second letters
day_chr2
        !text "UOUEHRA"                 ; $B37E
; --- day_chr3: Day-of-week text: third letters
day_chr3
        !text "NNEDUIT"                 ; $B385
; --- day_chr4: Day-of-week text: fourth letters
day_chr4
        !text "..S.R.."                 ; $B38C
; --- time_template: Time stamp template (' / /  :  :  M')
; Template of the T-RA answer: "WED. 11/19/26 01:27:00 PM" without the filled digits.
time_template
        !text "       /  /     :  :    M" ; $B393
cmd_time_read_command            ; read command
        lda cmd_buf+3            ; 'A' = ASCII
        cmp #$41
        beq cmd_time_read_ascii_time
        cmp #$42                 ; 'B' = BCD
        bne cmd_time_test_rd
        jmp cmd_time_read_bcd_time
cmd_time_test_rd
        cmp #$44                 ; 'D' = decimal
        bne cmd_time_invalid_command
        jmp cmd_time_read_decimal_time
cmd_time_read_ascii_time
        ldx #$18                 ; copy the 25 character template into the message buffer
cmd_time_copy_template_loop
        lda time_template,x
        sta errmsg_buf,x
        dex
        bpl cmd_time_copy_template_loop
        jsr rtc_hold             ; latch the clock registers (HOLD)
        lda rtc_weekday          ; day of week 0-6
        and #$07
        tax
        lda day_chr1,x           ; first letter of the day name; also the first byte the channel returns
        sta chan_byte+31
        sta errmsg_buf
        lda day_chr2,x
        sta errmsg_buf+1
        lda day_chr3,x
        sta errmsg_buf+2
        lda day_chr4,x
        sta errmsg_buf+3
        ldx #$0B                 ; 12 digit registers
cmd_time_fill_digits_loop
        lda rtc_regs,x           ; register nibble
        and rtc_mask_tbl,x       ; mask to the valid bits
        ora #$30                 ; make it an ASCII digit
        ldy rtc_reg_map,x        ; position in the string
        sta errmsg_buf,y
        dex
        bpl cmd_time_fill_digits_loop
        ldy #$17                 ; AM/PM character goes to position $17
        lda rtc_hour10           ; bit 2 of the hour-tens register = PM
        and #$04
        bne cmd_time_store_am_pm
        lda #$41                 ; 'A'
        !byte $2C                ; BIT skips the next LDA
cmd_time_store_am_pm
        lda #$50                 ; 'P'
        sta errmsg_buf,y         ; the string has "M" after it already
        iny
cmd_time_set_message_length
        tya                      ; length of the message
        clc
        adc #$00
        sta chan_last+31         ; last byte pointer of the status channel
        jsr errmsg_reset         ; reset the message pointer
        inc errmsg_ptr
        lda #$88                 ; $88 = active, last byte
        sta chan_flags+31
rtc_release_hold                 ; release the clock (HOLD off)
        lda #$00
        sta rtc_ctrl_d
        rts
cmd_time_read_bcd_time           ; T-RB: raw BCD bytes
        jsr rtc_read_bcd
        ldy #$01
cmd_time_copy_bcd_loop
        lda rtc_buf,y
        sta errmsg_buf,y
        iny
        cpy #$08
        bcc cmd_time_copy_bcd_loop
        dey
        jmp cmd_time_set_message_length
cmd_time_read_decimal_time       ; T-RD: BCD converted to binary decimal bytes
        jsr rtc_read_bcd
        ldy #$01
cmd_time_convert_loop
        lda rtc_buf,y
        jsr bcd_to_bin
        sta errmsg_buf,y
        iny
        cpy #$08
        bcc cmd_time_convert_loop
        dey
        jmp cmd_time_set_message_length

; --- rtc_read_bcd: Read the RTC into rtc_buf
; Read the clock into rtc_buf (weekday + 7 BCD bytes).
rtc_read_bcd
        jsr rtc_read
        lda rtc_buf
        sta chan_byte+31
        sta errmsg_buf
        rts

; --- bcd_to_bin: Convert BCD in A to binary
; Convert a BCD value in A to binary.
bcd_to_bin
        pha
        and #$0F
        sta tmp_a
        pla
        and #$F0
        lsr
        pha
        clc
        adc tmp_a
        sta tmp_a
        pla
        lsr
        lsr
        clc
        adc tmp_a
        rts

; --- bin_to_dec: Convert binary A to tens ($50) / units
; Divide A by 10: A = remainder, tmp_a = quotient.
bin_to_dec
        pha
        lda #$00
        sta tmp_a
        pla
bin_to_dec_divide_loop
        cmp #$0A
        bcc bin_to_dec_done
        sbc #$0A
        inc tmp_a
        bne bin_to_dec_divide_loop
bin_to_dec_done
        rts
cmd_time_write_command           ; T-W
        lda cmd_buf+3
        cmp #$41
        beq cmd_time_write_ascii_time
        cmp #$42
        bne cmd_time_test_wb
        jmp cmd_time_write_bcd_time
cmd_time_test_wb
        cmp #$44
        bne cmd_time_invalid
        jmp cmd_time_write_decimal_time
cmd_time_invalid
        jmp err_31_invalid_cmd
cmd_time_write_ascii_time        ; T-WA ASCII: string must be at least 25 chars
        lda cmd_len
        cmp #$1D
        bcc cmd_time_bad_time_string
        ldx #$06                 ; find the day name from the first two letters
cmd_time_find_day_loop
        lda cmd_buf+4
        cmp day_chr1,x
        bne cmd_time_next_day
        lda cmd_buf+5
        cmp day_chr2,x
        beq cmd_time_set_day_and_digits
cmd_time_next_day
        dex
        bpl cmd_time_find_day_loop
cmd_time_bad_time_string
        jmp err_31_invalid_cmd
cmd_time_set_day_and_digits      ; set weekday and the digits
        txa
        jsr rtc_hold
        sta rtc_weekday          ; day of week register
        ldx #$0B
cmd_time_store_digits_loop
        ldy rtc_reg_map,x        ; position of the digit in the string
        lda cmd_buf+4,y          ; take the digit characters
        and rtc_mask_tbl,x       ; mask the valid bits
        sta rtc_regs,x
        dex
        bpl cmd_time_store_digits_loop
        lda cmd_buf+27           ; "AM/PM" character: bit 4 differs for 'P' ($50) and 'A' ($41)
        and #$10
        jmp cmd_time_set_pm_bit
cmd_time_write_bcd_time          ; T-WB: bytes in BCD
        jsr rtc_set_weekday      ; weekday
        ldy #$05
        ldx #$0B
cmd_time_store_bcd_loop
        lda cmd_buf,y
        pha
        lsr                      ; high nibble
        lsr
        lsr
        lsr
        and rtc_mask_tbl,x
        sta rtc_regs,x
        pla
        dex
        and rtc_mask_tbl,x       ; low nibble
        sta rtc_regs,x
        iny
        dex
        bpl cmd_time_store_bcd_loop
cmd_time_read_am_pm_flag         ; AM/PM flag byte
        lda cmd_buf,y
cmd_time_set_pm_bit
        beq cmd_time_store_hour_flag ; zero = AM
        lda #$04                 ; set the PM bit
cmd_time_store_hour_flag
        ora rtc_hour10
        sta rtc_hour10
        jmp rtc_release_hold
cmd_time_write_decimal_time      ; T-WD: decimal bytes
        jsr rtc_set_weekday
        ldx #$0B
        ldy #$05
cmd_time_store_decimal_loop
        lda cmd_buf,y
        jsr bin_to_dec           ; convert decimal to tens/units
        pha
        lda tmp_a
        and rtc_mask_tbl,x
        sta rtc_regs,x
        pla
        dex
        and rtc_mask_tbl,x
        sta rtc_regs,x
        dex
        iny
        cpy #$0B
        bcc cmd_time_store_decimal_loop
        jmp cmd_time_read_am_pm_flag

; --- rtc_set_weekday: Set the day of week
; Store the weekday (byte 4 of the command, 0-6).
rtc_set_weekday
        lda cmd_len
        cmp #$0C
        bcc rtc_weekday_invalid  ; need at least 12 characters
        lda cmd_buf+4
        cmp #$07                 ; weekday must be < 7
        bcc rtc_weekday_store_weekday
rtc_weekday_invalid
        jmp err_31_invalid_cmd
rtc_weekday_store_weekday
        jsr rtc_hold
        sta rtc_weekday
        rts
; --- rtc_mask_tbl: RTC digit masks
; Valid bits of each of the 12 RTC registers.
rtc_mask_tbl
        !byte $0F,$07,$0F,$07,$0F,$03,$0F,$03 ; $B550
        !byte $0F,$01,$0F,$0F,$07       ; $B558

; --- rtc_read: Read all RTC registers (BCD) into rtc_buf
; Read all RTC registers into rtc_buf: [0] weekday, [1..6] year, month, day, hour, minute, second
; as BCD, [7] PM flag.
rtc_read
        php
        sei
        jsr rtc_hold             ; latch the clock
        lda rtc_weekday
        and #$07
        sta rtc_buf
        ldx #$0B
        ldy #$01
rtc_read_read_pair_loop
        lda rtc_regs,x           ; register (high digit)
        and rtc_mask_tbl,x
        asl                      ; shift into the high nibble
        asl
        asl
        asl
        sta tmp_a
        dex
        lda rtc_regs,x           ; low digit
        and rtc_mask_tbl,x
        clc
        sed                      ; decimal mode makes this a BCD add of the two nibbles
        adc tmp_a
        cld
        sta rtc_buf,y
        iny
        dex
        bpl rtc_read_read_pair_loop
        lda rtc_hour10
        and #$04
        sta rtc_buf,y
        lda #$00
        sta rtc_ctrl_d
        plp
        rts
; RTC busy (the clock was updating): release HOLD, wait about 300 cycles and try again.
rtc_hold_release_and_retry
        sta rtc_ctrl_d
        ldx #$4C                 ; delay loop
rtc_hold_retry_delay
        dex
        bne rtc_hold_retry_delay
        !byte $24                ; BIT skips the PHA below when entering from the retry path
; --- rtc_hold: Latch the RTC (HOLD) and wait until not busy
; Set HOLD on the 72421 clock chip and wait until BUSY is clear.
rtc_hold
        pha
        lda #$01
        sta rtc_ctrl_d           ; control register D, bit 0 = HOLD
        lda rtc_ctrl_d
        and #$02                 ; bit 1 = BUSY
        bne rtc_hold_release_and_retry
        pla
        rts

; --- rtc_format_ascii: Format the RTC reading as ASCII text
; Convert the RTC time to the date format used in directory entries (year, month, day, hour,
; minute as binary numbers) into dirblk_buf at offset 23+X.
rtc_format_ascii
        txa
        pha
        jsr rtc_read             ; read the clock
        ldy #$01
        pla
        pha
        tax
rtc_format_convert_loop
        lda rtc_buf,y            ; BCD to binary
        jsr bcd_to_bin
        sta dirblk_buf+23,x      ; store in the entry
        inx
        iny
        cpy #$06
        bcc rtc_format_convert_loop
        pla
        tax
        lda dirblk_buf+26,x      ; hour: 12 hour clock, 12 becomes 0
        sbc #$0C
        bne rtc_format_check_pm
        sta dirblk_buf+26,x
rtc_format_check_pm
        lda rtc_buf+7            ; PM flag
        beq rtc_format_done
        lda #$0C                 ; add 12 for PM
        clc
        adc dirblk_buf+26,x
        sta dirblk_buf+26,x
rtc_format_done
        rts
; --- cmd_letters: Command letter list 'VI/MBUP&CRSNTGLW'
; Command letters, in the order of cmd_offset_tbl: V I / M B U P & C R S N T G L W.
cmd_letters
        !text "VI/MBUP&CRSNTGLW"        ; $B5E8
; Per-command mask of the syntax bits that are not allowed (used while parsing the specs).
cmd_syntax_mask_tbl
        !byte $FF,$FF,$FF,$9E,$FF,$FF,$FF,$FF ; $B5F8
        !byte $51,$DD,$1C,$9E,$18       ; $B600
; --- cmd_offset_tbl: Command letter -> low byte of the $FFxx jump table slot
; Low byte of the jump table slot ($FFxx) for each command letter.
cmd_offset_tbl
        !byte $21,$09,$24,$0C,$00,$1E,$12,$27 ; $B605
        !byte $03,$15,$18,$0F,$1B,$06,$57,$5A ; $B60D

; --- parse_command: Parse the command in the command buffer and dispatch it
; Parse the command in the command buffer and run it.
parse_command
        lda default_part         ; a new command always starts in the default partition
        jsr select_partition
        lda #$00                 ; clear the date filters
        sta filter_flags
        sta filter_flags2
        jsr status_ok            ; status back to 00,OK
        lda cur_atn_byte         ; channel byte
        and #$8F                 ; mask the open/close bits
        bpl parse_command_normal_command ; bit 7 clear: a command on the command channel
        eor #$8F                 ; $8F: channel 15
        beq parse_command_normal_command
        jmp cmd_open_file        ; anything else with the high bit set = OPEN with a file name
parse_command_normal_command
        jsr trim_command         ; trim trailing CR and spaces, Y = command length - 1
        lda (cmdbuf_ptr),y       ; first character of the command
        ldx #$0F
parse_command_find_command_letter
        cmp cmd_letters,x        ; look it up
        beq dispatch_command
        dex
        bpl parse_command_find_command_letter
        jmp err_31_invalid_cmd   ; unknown letter: error 31
; --- dispatch_command: Jump to the command routine via the $FF jump table
; Jump to the command routine through the $FF jump table (so the commands can be replaced).
dispatch_command
        stx cmd_class            ; command class = index of the letter
        lda cmd_offset_tbl,x     ; low byte of the slot
        sta tmp_a
        lda #$FF                 ; high byte $FF
        sta tmp_b
        jmp (tmp_a)
; --- cmd_complete: Command finished: report a pending error else status 00
; Called at the end of every command: if an error is pending (such as the record-not-present
; $50 set by the P command) report it, otherwise status 00.
cmd_complete
        lda pending_err
        beq cmd_status_ok
        jmp dos_error_00
; --- cmd_status_ok: Report 00,OK
; Report 00,OK.
cmd_status_ok
        lda #$00
        tay
        sty cur_track
; --- cmd_status_ts: Report status A with track Y... (sector = Y)
; Report status A with sector = Y.
cmd_status_ts
        sty cur_sector
; --- cmd_status_set: Set the status A and reset the command state
; Set the status message and clean up after a command.
cmd_status_set
        jsr set_error            ; build the message
        jsr cmdbuf_reset         ; reset the command buffer
        jsr led_error_off        ; error LED off
cmd_status_set_release_dirs_exit
        jmp release_dir_chans    ; close the directory channels

; --- dos_error_00: Raise DOS error A with track/sector = 0
; Raise DOS error A with track and sector 0.
dos_error_00
        ldy #$00
        sty cur_track
        sty cur_sector
        jmp jt_dos_error

; --- strip_partition_arg: Strip the partition prefix from the command
; Skip the partition number in a command such as "I1" or "V1".
strip_partition_arg
        ldy #$00
        jsr find_separator       ; find the first separator

; --- skip_digits: Skip digits and spaces backwards
; Walk back over a partition number (digits and spaces).
skip_digits
        dey
        jsr is_digit_or_sep
        bne skip_digits_done
skip_digits_skip_back_loop
        dey
        jsr is_digit_or_sep
        beq skip_digits_skip_back_loop ; continue until we leave the digits
        iny                      ; Y at the first digit
        jsr parse_partition_num  ; parse it
skip_digits_done
        jmp led_on               ; activity LED on

; --- parse_partition_num: Parse the partition number ('0'-'255')
; Parse a partition number (0-255) at cmd_buf,Y.
parse_partition_num
        jsr parse_num_0_255

; --- set_part_from_spec: Select the partition given by the spec; error 74 if illegal
; Select the partition number A; error 74 DRIVE NOT READY if it does not exist.
set_part_from_spec
        jsr check_part_ok
        bcc check_part_ok_done_valid
        lda #$74
        jmp dos_error_00

; --- check_part_ok: Validate partition number A (C = 1 if invalid)
; Validate partition number A. A = 0 means the current partition. C = 1 if the partition is
; not usable: not created (type 0) or a print buffer / foreign partition (type 6, 7).
check_part_ok
        cmp #$00                 ; 0 = current partition
        bne check_part_ok_test_type
        lda cur_part
check_part_ok_test_type
        pha
        tax
        lda part_type,x          ; type of the partition
        beq check_part_ok_invalid_partition ; 0 = not created
        cmp #$06                 ; 6 and above can not be selected for file access
        bcs check_part_ok_invalid_partition
        pla
        jsr select_partition     ; make it the current partition
        clc
check_part_ok_done_valid
        rts
check_part_ok_invalid_partition
        pla
        sec
        rts

; --- find_separator: Scan for ':' ',' '=' in the command
; Look for ':' starting at cmd_buf,Y. Stops with Z set (not found) at ',' or '='.
find_separator
        lda cmd_buf,y
        cmp #$3A                 ; ':'
        beq find_separator_found
        cmp #$2C                 ; ','
        beq find_separator_not_found
        cmp #$3D                 ; '='
        beq find_separator_not_found
        iny
        cpy cmd_len
        bcc find_separator
find_separator_not_found
        ora #$00                 ; not found: Z set, A unchanged
find_separator_found
        rts

; --- is_digit_or_sep: Test a command character
; Test cmd_buf,Y: Z = 1 for a digit ($30-$39), also used for separators.
is_digit_or_sep
        lda cmd_buf,y
        cmp #$30
        bcc is_digit_sep_done
        cmp #$3A
        bcs find_separator_not_found
        cmp cmd_buf,y
is_digit_sep_done
        rts

; --- find_colon: Find ':' in the command (X,Y = 0)
; Find the ':' of a command from the start of the command (X = Y = 0).
find_colon
        ldy #$00
        ldx #$00
        lda #$3A
        jmp find_char

; --- require_colon: Find ':' else error 34 (SYNTAX ERROR)
; Find ':' else error 34 (no file name).
require_colon
        jsr find_colon
        bne parse_spec_list
require_colon_no_colon_error
        lda #$34                 ; error 34 SYNTAX ERROR
        jmp dos_error_00

; --- parse_spec_list: Parse the list of file specs after ':'
; Parse the file specs after the colon: "S0:name1,name2".
parse_spec_list
        dey                      ; back to before the ':'
        dey
        sty name_start           ; spec 0 starts here
        txa
        bne require_colon_no_colon_error ; X <> 0 means more than one colon: error

; --- parse_spec_equal: Parse a spec list with '=' separators
; Parse a spec list with '=' separators like "C0:new=old1,old2". name_start[] / name_end_tbl[] get
; the start and end offsets of each spec; syntax_flags bits describe the shape of the command
; (which side had wildcards, commas...), checked against cmd_syntax_mask_tbl for the command.
parse_spec_equal
        lda #$3D                 ; '='
        jsr find_char
        txa
        beq parse_spec_equal_compose_flags ; no '=' in the command
        lda #$40                 ; bit 6 = there is a '='
parse_spec_equal_compose_flags
        ora #$21                 ; base flags
        sta syntax_flags
        inx
        stx file_idx
        stx file_count
        lda cmd_flag_e4          ; wildcards found in the first part?
        beq parse_spec_equal_parse_sources
        lda #$80                 ; bit 7 = wildcards on the left side
        ora syntax_flags
        sta syntax_flags
        lda #$00
        sta cmd_flag_e4
parse_spec_equal_parse_sources   ; source list (after '=')
        tya
        beq parse_spec_equal_validate_flags
        sta name_start,x         ; start of the first source
        lda file_idx
        sta file_cur
        lda #$8D                 ; $8D = shifted CR: search to the end
        jsr find_char
        inx
        stx file_count
        dex
        lda cmd_flag_e4          ; wildcards in the source list?
        beq parse_spec_equal_check_count
        lda #$08
parse_spec_equal_check_count
        cpx file_idx             ; more than one source?
        beq parse_spec_equal_merge_flags
        ora #$04                 ; bit 2 = more than one source
parse_spec_equal_merge_flags
        ora #$03                 ; bit 0, 1 always set for a source list
        eor syntax_flags
        sta syntax_flags
parse_spec_equal_validate_flags
        lda syntax_flags         ; compare with what this command allows
        ldx cmd_class
        and cmd_syntax_mask_tbl,x ; disallowed bits
        bne parse_spec_equal_syntax_mismatch
        rts
parse_spec_equal_syntax_mismatch
        sta pending_err          ; keep the offending flags in pending_err
        lda #$30                 ; error 30 SYNTAX ERROR
        jmp dos_error_00

; --- find_char: Find character A in the command buffer
; Find the character A in the command, from Y on. It splits the command into specs at commas:
; name_start+1,X receives the offset after each comma and cmd_flag_e4 notes wildcards ('*' or
; '?'). X = spec number. Returns Y = the position after the character (0 = not found).
find_char
        sta parse_char           ; the character to look for
find_char_scan_loop
        cpy cmd_len              ; end of the command?
        bcs find_char_not_found
        lda (cmdbuf_ptr),y       ; next character
        iny
        cmp parse_char           ; found it
        beq find_char_store_end
        cmp #$2A                 ; '*'
        beq find_char_note_wildcard
        cmp #$3F                 ; '?'
        bne find_char_check_comma
find_char_note_wildcard
        inc cmd_flag_e4          ; a wildcard was seen
find_char_check_comma
        cmp #$2C                 ; comma: start of the next spec
        bne find_char_scan_loop
        tya
        sta name_start+1,x       ; store its start offset
        lda cmd_flag_e4
        and #$7F                 ; any wildcard in this spec?
        beq find_char_next_spec
        lda #$80
        sta spec_type,x          ; spec_type b7 = wildcard flag
        sta cmd_flag_e4
find_char_next_spec
        inx
        cpx #$05                 ; only five specs
        bcc find_char_scan_loop
find_char_not_found
        ldy #$00                 ; not found: Y = 0
find_char_store_end
        lda cmd_len              ; end of the command = end of the last spec
        sta name_start+1,x
        lda cmd_flag_e4
        and #$7F
        beq find_char_done
        lda #$80
        sta spec_type,x
find_char_done
        tya                      ; return Y
        rts

; --- trim_command: Strip trailing CR and spaces from the command, set Y/length
; Remove trailing CRs from the command and set cmd_len. A "U0" command keeps its raw bytes
; (burst commands may contain arbitrary bytes).
trim_command
        ldy cmdbuf_ptr           ; number of characters received
        beq trim_command_store_length ; none
        dey
        beq trim_command_include_last_char ; only one character
        lda cmd_buf              ; U0?
        cmp #$55                 ; 'U'
        bne trim_command_load_last_char
        lda cmd_buf+1
        cmp #$30                 ; '0'
        beq trim_command_no_char_u0
trim_command_load_last_char
        lda cmd_buf,y            ; last character of the command
        !byte $2C                ; BIT skips the next LDA
trim_command_no_char_u0
        lda #$00                 ; U0: pretend the last character is not a CR
        cmp #$0D                 ; CR?
        beq trim_command_store_length
        dey                      ; second last character
        lda cmd_buf
        cmp #$55
        bne trim_command_load_prev_char
        lda cmd_buf+1
        cmp #$30
        beq trim_command_no_prev_u0
trim_command_load_prev_char
        lda cmd_buf,y
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
trim_command_no_prev_u0
        lda #$00
        cmp #$0D
        beq trim_command_store_length
        iny                      ; keep both characters
trim_command_include_last_char
        iny
trim_command_store_length
        sty cmd_len              ; command length
        cpy #$FF                 ; too long?
        ldy #$FF                 ; Y = $FF for the class variable
        bcc clear_parse_state
        sty cmd_class            ; class = $FF
        lda #$32                 ; error 32 SYNTAX ERROR (line too long)
        jmp dos_error_00

; --- clear_parse_state: Clear all parser variables
; Reset the parser state: names, specs, flags.
clear_parse_state
        ldy #$00
        tya
        sta cmdbuf_ptr           ; buffer pointer back to the start
        sta rel_rec_len          ; REL record length
        sta file_type
        sta file_type_chr        ; file type letter index
        sta loop_idx             ; loop index
        sta file_cur
        sta file_idx
        sta file_count
        sta cmd_flag_e4
        sta pending_err          ; no pending error
        ldx #$05                 ; clear the first 5 entries of all spec tables
clear_parse_clear_spec_tables_loop
        sta byte_vec+1,x
        sta spec_sec+7,x
        sta spec_aux1+7,x
        sta spec_aux2+7,x
        sta name_end_tbl+7,x
        sta spec_part+7,x
        sta spec_type+7,x
        sta spec_trk+7,x
        dex
        bne clear_parse_clear_spec_tables_loop
        rts

; --- resolve_specs: Resolve partition/directory of all specs
; Resolve every spec (partition and path) for a command that modifies files.
resolve_specs
        jsr resolve_one_spec
        bcc resolve_specs_done
resolve_specs_drive_not_ready
        lda #$74
        jmp dos_error_00

; --- resolve_specs_ro: Resolve specs for a read-only command
; Same for read-only commands.
resolve_specs_ro
        jsr resolve_loop
        bcs resolve_specs_drive_not_ready
resolve_specs_done
        rts

; --- resolve_one_spec: Resolve a single spec
; Resolve a single spec: the one after file_count.
resolve_one_spec
        lda file_count
        sta file_idx
        lda #$01
        sta file_count
        sta file_cur

; --- resolve_loop: Loop over all specs
; Resolve all specs of the command.
resolve_loop
        ldx #$00
resolve_loop_spec_loop
        stx loop_idx             ; one spec at a time
        jsr resolve_spec
        ldx loop_idx
        inx
        cpx file_count
        bcc resolve_loop_spec_loop
        lda spec_part            ; check the first partition
        jmp check_part_ok

; --- resolve_spec: Resolve the partition/path of spec X
; Split spec X into partition, path and name. The syntax is "[partition][path/]name" where a
; partition number is written before a colon ("1:name") or a path "//dir/name" is given. The
; result: spec_part = partition, name_start / name_end_tbl = name range.
resolve_spec
        lda cur_part             ; default partition = current
        cpx #$00
        beq resolve_spec_store_default_part ; the first spec uses the current partition...
        lda spec_part            ; ...the others default to the first spec's
resolve_spec_store_default_part
        sta spec_part,x
        lda name_start,x         ; name range starts as the spec's start
        sta name_end_tbl,x
        inx
        ldy name_start,x         ; end of the spec
        sty tmp_a
        tax
        tay
resolve_spec_scan_spec_loop
        lda cmd_buf,x            ; scan the spec for ':'
        cmp #$3A                 ; ':' found: partition prefix
        beq resolve_spec_parse_partition_and_path
        cmp #$3D                 ; '=' / ','
        beq resolve_spec_done
        cmp #$2C
        beq resolve_spec_done
        inx
        cpx tmp_a
        bcc resolve_spec_scan_spec_loop
resolve_spec_done
        rts
resolve_spec_parse_partition_and_path
        lda cmd_buf,y            ; first character of the spec
        cmp #$3E                 ; '>' or '<' means a date filter, not a name
        beq resolve_spec_done
        cmp #$3C
        beq resolve_spec_done
        inx                      ; X = position after the colon
        txa
        pha
        ldx loop_idx
        sta name_end_tbl,x       ; name starts after the colon
        tay
        dey                      ; look at the character before the colon
        beq resolve_spec_use_current_partition
        dey
        lda cmd_buf,y
        cmp #$2F                 ; '/' means the path is in front
        bne resolve_spec_check_partition_prefix
resolve_spec_find_last_slash_loop ; find the last '/' of the path
        lda cmd_buf,y
        cmp #$2F
        bne resolve_spec_check_separator
        tya
        sta name_end_tbl,x
        lda #$2F
resolve_spec_check_separator
        cmp #$3D                 ; stop at '=' or ','
        beq resolve_spec_no_slash_found
        cmp #$2C
        beq resolve_spec_no_slash_found
        dey
        cpy #$FF                 ; no more characters
        bne resolve_spec_find_last_slash_loop
resolve_spec_no_slash_found
        ldy name_end_tbl,x       ; path/name split position
        beq resolve_spec_use_current_partition
        dey
resolve_spec_check_partition_prefix
        jsr is_digit_or_sep      ; digits before the colon?
        bne resolve_spec_use_current_partition
resolve_spec_skip_digits_loop    ; walk back over the digits
        dey
        cpy #$FF
        beq resolve_spec_parse_partition_number
        jsr is_digit_or_sep
        beq resolve_spec_skip_digits_loop
resolve_spec_parse_partition_number
        iny
        jsr parse_num_0_255      ; read the partition number
        tay
        bne resolve_spec_store_partition ; 0 = current partition
resolve_spec_use_current_partition
        lda cur_part             ; current partition
resolve_spec_store_partition
        ldx loop_idx
        sta spec_part,x          ; store the partition
        pla
        sta name_start,x         ; name starts after the colon
        rts

; --- get_file_type_arg: Get the file-type letter for the current spec
; Get the file-type letter given in the spec (P, S, U, R, D...) as an index.
get_file_type_arg
        ldy #$00                 ; first spec if there is only one
        lda file_idx
        cmp file_count
        beq type_filter_store_type_char
        dec file_count           ; the type spec is the last one
        ldy file_count

type_filter_from_spec
        lda name_start,y
        tay
        lda (cmdbuf_ptr),y       ; first character of the spec
        ldy cur_part             ; partition 0 lists partitions: different type letters
        beq type_filter_compare_partition_types
        ldy #$06                 ; 'B' is allowed as a file type letter
        cmp #$42
        beq type_filter_store_type_char
        dey
type_filter_file_type_loop
        cmp ftype_chr1,y         ; look up the type letter
        beq type_filter_store_type_char
        dey
        bne type_filter_file_type_loop
type_filter_store_type_char
        tya
        sta file_type_chr        ; index of the type, 0 = none
        rts
type_filter_compare_partition_types
        ldy #$07                 ; partition 0: partition type letters
type_filter_partition_type_loop
        cmp ptype_chr1,y
        beq type_filter_store_type_char
        dey
        bne type_filter_partition_type_loop
        beq type_filter_store_type_char

; --- cmd_c: C command: CP (change default partition), CD (change directory), otherwise copy files
; C command. "CP" selects the default partition (also "CP"+shifted-P with a binary number),
; "CD" changes directory in a native partition, anything else is a file copy.
cmd_c
        lda cmd_buf+1
        cmp #$50                 ; 'P'
        beq cmd_c_cp_command
        cmp #$D0                 ; shifted P ($D0): the partition number follows as a binary byte
        beq cmd_c_cp_shifted
        cmp #$44                 ; 'D'
        beq cmd_c_cd_command
        jmp cmd_copy_files       ; everything else: copy files
cmd_c_cp_shifted
        lda cmd_buf+2            ; binary partition number
        jmp cmd_c_cp_set_partition
cmd_c_cp_command
        lda cmd_len              ; "CP" alone reports the current default
        cmp #$02
        bne cmd_c_cp_with_number
        lda cfg_def_part         ; default partition (stored in protected RAM)
        sta cur_track
        jmp cmd_c_cp_report
cmd_c_cp_with_number
        ldy #$02                 ; decimal number after "CP"
        jsr parse_num_0_255
cmd_c_cp_set_partition
        tax                      ; partition number
        pha
        sta cur_track            ; returned as the "track" of the status message
        lda part_type,x          ; partition must exist
        beq cmd_c_cp_illegal_partition
        cmp #$FF                 ; and must not be the system partition
        bne cmd_c_cp_select
cmd_c_cp_illegal_partition
        lda #$77                 ; error 77 SELECTED PARTITION ILLEGAL
        jmp jt_dos_error
cmd_c_cp_select
        pla
        jsr cfg_set_def_part     ; make it the default, kept in protected RAM
cmd_c_cp_report
        ldy #$00
        lda #$02                 ; status 02 PARTITION SELECTED
        jmp cmd_status_ts
cmd_c_cd_command                 ; CD: needs a colon unless it is a short form
        jsr find_colon
        beq cmd_c_cd_no_colon
        dey
        dey
        sty name_start           ; name starts before the colon
        jsr resolve_specs
        jsr is_native            ; only native partitions have sub-directories
        bne cd_syntax_error
        ldy name_end_tbl         ; name range empty?
        cpy name_start
        bne cmd_c_cd_change_directory
        iny
        cpy cmd_len
        bne cmd_c_cd_change_directory
        dey
        lda cmd_buf,y            ; a lone '_' (left arrow) = parent directory
        cmp #$5F
        beq cmd_c_cd_to_parent
        cmp #$2F                 ; a lone '/' = root
        bne cmd_c_cd_change_directory
cmd_c_cd_to_root
        jsr set_dir_root_1       ; root directory is track 1 / sector 1
cmd_c_cd_done
        jmp cmd_status_ok
cmd_c_cd_to_parent
        jsr read_header_blk      ; parent: read the header, offset 34/35 = parent header
        lda dirblk_buf+34
        beq cmd_c_cd_done        ; no parent: already the root
        ldy dirblk_buf+35
        jmp cd_set_directory
cmd_c_cd_no_colon
        lda cmd_len              ; "CD" without colon and only 3 characters: "CD_" or "CD/"
        cmp #$03
        bne cmd_c_cd_with_path
        jsr is_native
        bne cd_syntax_error
        lda cmd_buf+2
        cmp #$5F
        beq cmd_c_cd_to_parent
        cmp #$2F
        beq cmd_c_cd_to_root
cmd_c_cd_with_path
        ldx #$00                 ; otherwise look for a '/' path in the command
        ldy #$02
        lda #$2F
        jsr find_char
        bne cmd_c_cd_path_found
cd_syntax_error
        jmp err_30_syntax
cmd_c_cd_path_found
        dey
        sty name_end_tbl
        jsr skip_digits          ; skip back over the partition number
        lda cur_part             ; path is in the current partition
        sta spec_part
        jsr is_native
        bne cd_syntax_error
        lda #$00
        sta name_start
cmd_c_cd_change_directory        ; name starts at offset 0 of the path
        lda #$01                 ; one spec
        sta file_count
        lda #$00
        jsr change_directory     ; walk the path
        lda name_start           ; no name left: stay in the directory reached
        bne cmd_c_cd_find_entry
        lda hdr_track            ; header of the directory reached
        ldy hdr_sector
cd_set_directory
        jsr set_dir
        jmp cmd_status_ok
cmd_c_cd_find_entry              ; look up the name
        jsr find_entry_loop
        ldy spec_sec             ; sector and track of the entry
        lda spec_trk
        bne cd_set_directory     ; found: go there
cd_dir_not_found
        lda #$39                 ; error 39 (directory not found)
        jmp dos_error_00

; --- change_directory: Change to a sub-directory by path
; Walk the path in the spec: each component between '/' is looked up in the current directory
; and becomes the current directory. A leading '/' goes back to the root first.
change_directory
        sta dir_cd_tmp2
        jsr set_header_loc       ; find the current header
        jsr is_native            ; native partitions only
        bne change_dir_done
        ldx dir_cd_tmp2
        lda name_end_tbl,x       ; name range of the spec
        cmp name_start,x
        bne change_dir_walk_path
change_dir_done
        rts
change_dir_walk_path
        sta dir_cd_tmp           ; position in the path
        lda filter_flags         ; the state is saved on the stack
        pha
        lda filter_flags2
        pha
        lda spec_type,x
        pha
        lda name_start,x
        pha
        lda file_type_chr
        pha
        lda spec_trk,x
        pha
        lda cur_sa
        pha
        lda #$06                 ; only directories (type 6) may be entered
        sta file_type_chr
        sta filter_flags
        sta filter_flags2
change_dir_next_path_char
        inc dir_cd_tmp           ; next character of the path
        ldx dir_cd_tmp
        cpx cmd_len
        bcs change_dir_restore_state
        lda cmd_buf,x            ; ':' ends the path
        cmp #$3A
        beq change_dir_restore_state
        cmp #$2F                 ; '/'?
        bne change_dir_component_start
        lda #$01                 ; a '/' at the start means the root: header at 1/1, directory from $22
        sta hdr_track
        sta hdr_sector
        lda #$22
        sta dir1_sector
        bne change_dir_next_path_char
change_dir_component_start       ; start of a component name
        txa
        ldy dir_cd_tmp2
        sta name_start,y
change_dir_find_component_end
        inx                      ; find the end of the component
        cpx cmd_len
        bcs change_dir_lookup_component
        lda cmd_buf,x
        cmp #$2F
        bne change_dir_find_component_end
change_dir_lookup_component
        lda cmd_len              ; limit the search to this component
        pha
        stx dir_cd_tmp
        stx cmd_len
        lda #$00                 ; forget the previous result
        sta spec_trk,y
        jsr reset_dir_search     ; start a new directory search
        jsr find_entry_init      ; find the first entry matching
        beq change_dir_enter_component ; found: enter it
        jmp cd_dir_not_found
change_dir_enter_component       ; restore the full command length
        pla
        sta cmd_len
        ldy dir_cd_tmp2
        lda spec_trk,y           ; header block of the sub-directory
        sta hdr_track
        lda spec_sec,y
        sta hdr_sector
        clc
        adc #$01
        sta dir1_sector          ; its first directory block follows
        jmp change_dir_next_path_char
change_dir_restore_state         ; restore the saved state
        ldx dir_cd_tmp2
        pla
        sta cur_sa
        pla
        sta spec_trk,x
        pla
        sta file_type_chr
        pla
        sta name_start,x
        pla
        sta spec_type,x
        pla
        sta filter_flags2
        pla
        sta filter_flags
        rts

; --- parse_num_0_255: Parse a decimal number 0-255
; Parse a decimal number of up to 3 digits (0-255) at cmd_buf,Y. Error 30 if it is too big.
parse_num_0_255
        php
        sei
        tya
        pha
        ldx #$00
parse_num_count_digits_loop
        lda cmd_buf,y            ; count the digits
        cmp #$30
        bcc parse_num_check_length
        cmp #$3A
        bcs parse_num_check_length
        cpy cmd_len              ; end of the command
        bcs parse_num_check_length
        iny
        inx
        bne parse_num_count_digits_loop
parse_num_check_length
        dex                      ; X = digits - 1
        cpx #$03                 ; more than 3 digits
        bcc parse_num_convert
parse_num_syntax_error
        jmp err_30_syntax
parse_num_convert
        pla                      ; rewind to the start
        tay
        lda #$00
        sta lba_b0               ; result
parse_num_digit_loop
        lda cmd_buf,y
        and #$0F                 ; digit value
        sta lba_b1
        beq parse_num_next_digit ; 0 adds nothing
        clc
        lda lba_b0
parse_num_add_power_loop
        adc pow10_tbl2,x         ; add 1, 10 or 100 per digit step
        bcs parse_num_syntax_error ; overflow: more than 255
        dec lba_b1
        bne parse_num_add_power_loop
        sta lba_b0
parse_num_next_digit
        iny
        dex
        bpl parse_num_digit_loop
        lda lba_b0
        plp
        rts
; --- pow10_tbl2: Powers of ten (1,10,100)
; Powers of ten.
pow10_tbl2
        !byte $01,$0A,$64               ; $BB35

; --- cmd_slash: '/' command: change directory by path
; '/' command (1581 style): "/0:name" selects a sub-partition by name; "/" alone goes back to
; the whole disk. "/0:name,C..." creates a sub-partition.
cmd_slash
        lda #$01                 ; the name starts after the '/'
        sta name_start
        lda cmd_len
        sta name_start+1
        jsr resolve_specs        ; resolve the partition
        jsr get_part_type
        cmp #$04                 ; only 1581 and 1581 CP/M partitions have sub-partitions
        beq cmd_slash_type_ok
        cmp #$05
        beq cmd_slash_type_ok
        jmp err_31_invalid_cmd   ; otherwise invalid command
cmd_slash_type_ok
        jsr check_part_valid
        lda name_start           ; name given?
        cmp cmd_len
        beq cmd_slash_use_default_dir ; no: back to the root of the partition
        jsr find_entry_first     ; find the entry
        lda spec_trk
        beq cmd_slash_entry_not_found ; not found: maybe create it
        jsr spec_arg_count       ; more arguments after the name?
        bcc cmd_slash_entry_found_check_type
        lda #$63                 ; error 63 FILE EXISTS
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_slash_err_file_not_found
        lda #$62                 ; error 62 FILE NOT FOUND
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_slash_err_syntax
        lda #$30                 ; error 30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_slash_err_partition_illegal
        lda #$77                 ; error 77
        jsr dos_error_00
cmd_slash_entry_not_found
        jsr spec_arg_count       ; are there creation arguments?
        bcc cmd_slash_err_file_not_found
        ldx name_end             ; offset of the end of the name
        lda cmd_buf+6,x          ; first argument must be 'C' (create)
        cmp #$43
        bne cmd_slash_err_syntax
        jmp create_sub_create_subpartition ; create the sub-partition
cmd_slash_entry_found_check_type
        lda spec_type            ; the entry type
        and #$07
        cmp #$05                 ; only type 5 (CBM) entries are sub-partitions
        bne cmd_slash_err_file_not_found
        jsr get_entry_range      ; get its track/sector/size
cmd_slash_verify_range_loop
        jsr check_ts_legal       ; every block of the range must be legal
        jsr next_block_in_range
        bne cmd_slash_verify_range_loop
        bcc cmd_slash_err_partition_illegal ; range empty
        ldy #$02                 ; byte 2 of the entry
        lda (dir_ptr),y
        bne cmd_slash_err_partition_illegal
        dey
        lda cur_track
        tax
        sbc (dir_ptr),y          ; size of the range, minimum 3 tracks
        cmp #$02
        beq cmd_slash_err_partition_illegal
        bcc cmd_slash_err_partition_illegal
        lda (dir_ptr),y
        pha                      ; (first track, last track)
        txa
        tay
        pla
        jsr set_dir              ; set the directory to the sub-partition
        jmp cmd_slash_reinit_partition
cmd_slash_use_default_dir
        jsr set_default_dir      ; whole disk again
cmd_slash_reinit_partition
        jsr release_part_chans   ; close the channels
        jsr init_partition       ; mount it
        lda geo_first_track      ; the first track
        sta cur_track
        ldy geo_end_track        ; end track - 1 = last track
        dey
        sty cur_sector
        lda #$02                 ; status 02 PARTITION SELECTED with first/last track
        ldy #$00
        jmp cmd_status_set

; --- verify_range_free: Verify that every block of the (track,sector,count) range is still free in the BAM
; Check that the whole (track,sector,count) range is still free; error 67 otherwise.
verify_range_free
        jsr parse_block_range    ; get the range from the command
verify_range_check_block_loop
        jsr check_ts_legal
        lda cur_track
        cmp #$28                 ; track 40 holds the system area
        beq verify_range_illegal_block_error
        jsr bam_locate_bit       ; is the block free?
        beq verify_range_illegal_block_error
        jsr next_block_in_range
        bne verify_range_check_block_loop
        rts                      ; all checked
verify_range_illegal_block_error
        lda #$67                 ; error 67 ILLEGAL SYSTEM T OR S
        jmp jt_dos_error

; --- spec_arg_count: Number of arguments after the file spec
; C = 0 if the spec is followed by enough bytes for a block range.
spec_arg_count
        ldx #$01
        jsr name_find_end
        lda cmd_len
        sec
        sbc name_end
        cmp #$04                 ; 4 bytes (track, sector, count hi, count lo)
        rts

; --- parse_block_range: Parse track/sector and count for a block copy
; Get track, sector and block count (the 4 bytes after the name) for a sub-partition range.
parse_block_range
        ldy name_end
        iny
        lda cmd_buf,y
        sta cur_track
        iny
        lda cmd_buf,y
        sta cur_sector
        iny
        lda cmd_buf,y
        sta blk_cnt_hi
        iny
        lda cmd_buf,y
        sta blk_cnt_lo
        clc
        lda blk_cnt_hi           ; zero block count?
        adc blk_cnt_lo
        beq parse_range_zero_count_error
        jmp check_ts_legal
parse_range_zero_count_error
        lda #$77                 ; error 77
        jsr dos_error_00
; Create a sub-partition: reserve the range in the BAM, add a directory entry of type 5.
create_sub_create_subpartition
        jsr verify_range_free
        lda #$05                 ; type 5 = CBM
        sta file_type
        lda #$12                 ; channel 18
        sta cur_sa
        jsr parse_block_range
        jsr open_write_chan      ; open it for writing
        jsr dir_add_entry        ; add the entry
        jsr parse_block_range
create_sub_allocate_range_loop   ; allocate all blocks of the range
        jsr check_ts_legal
        lda cur_track
        jsr bam_allocate_block
        jsr next_block_in_range
        bne create_sub_allocate_range_loop
        jsr parse_block_range
        ldx cur_chan             ; block count in the channel's counters
        lda blk_cnt_hi
        sta chan_blk_lo,x
        lda blk_cnt_lo
        sta chan_blk_hi,x
        lda #$00
        jsr chan_put_byte        ; data byte 0 so the entry gets written
        lda #$12
        sta cur_sa
        jsr close_channel        ; close = write the directory entry
        jmp cmd_complete

; --- next_block_in_range: Advance (track,sector) through a block range
; Step to the next block of a (track,sector,count) range, counting the block count down.
; Returns Z = 1 when the range is used up. Error 67 if the range runs off the partition.
next_block_in_range
        lda blk_cnt_hi
        bne next_range_advance_sector
        lda blk_cnt_lo
        beq next_range_check_remaining
        dec blk_cnt_lo
next_range_advance_sector
        dec blk_cnt_hi
        inc cur_sector           ; next sector
        lda geo_secs_per_trk     ; sectors per track
        cmp cur_sector
        bne next_range_check_remaining
        lda #$00
        sta cur_sector
        lda cur_track
        cmp hdr_track            ; stop at the directory/header track
        beq next_range_track_overflow_error
        inc cur_track            ; next track, sector 0
        sec
        !byte $24                ; BIT skips the CLC below
next_range_check_remaining
        clc
        lda blk_cnt_lo           ; Z = 1 when both count bytes are zero
        ora blk_cnt_hi
        rts
next_range_track_overflow_error
        lda #$67
        jmp jt_dos_error

; --- get_entry_range: Read the start/size of the current directory entry
; Load track/sector (entry bytes 1, 2) and the block count (bytes $1C, $1D) of the entry at dir_ptr.
get_entry_range
        ldy #$01
        lda (dir_ptr),y
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        ldy #$1C
        lda (dir_ptr),y
        sta blk_cnt_hi
        iny
        lda (dir_ptr),y
        sta blk_cnt_lo
        rts

; --- alloc_range: Allocate all blocks of the entry
; Allocate all the blocks of the range described by the directory entry.
alloc_range
        jsr check_ts_legal
        jsr bam_allocate_block
        jsr next_block_in_range
        bne alloc_range
        rts

; --- cmd_m: M command: M-R/M-W/M-E, also MD (make directory)
; M command: "MD:name" makes a directory (native partitions); everything else is M-R/M-W/M-E.
cmd_m
        lda cmd_buf+1            ; second character: 'D' = make directory
        cmp #$44
        beq cmd_m_make_directory
cmd_m_memory_command
        jmp cmd_mem
cmd_m_make_directory
        jsr prep_spec_cmd
        bne cmd_m_memory_command ; not native: not a valid MD, treat as a memory command
        jsr reset_dir_search
        jsr alloc_first_block    ; get the first free block for the header
        lda cur_track
        sta spec_trk
        lda cur_sector
        sta spec_sec
cmd_m_allocate_header_pair_loop  ; the header and its first directory block must be next to each other: allocate a second / block and check that it is the next sector of the same track, otherwise try again
        lda cur_track
        sta move_tmp_trk
        lda cur_sector
        sta move_tmp_sec
        jsr alloc_from_dir_start ; allocate another free block
        lda cur_sector
        pha
        lda cur_track
        pha
        cmp move_tmp_trk         ; different track: not adjacent
        bne cmd_m_pair_not_adjacent
        ldx move_tmp_sec         ; sector of the header + 1
        inx
        cpx cur_sector
        beq cmd_m_pair_found     ; adjacent: done
cmd_m_pair_not_adjacent
        lda move_tmp_trk
        sta cur_track
        lda move_tmp_sec
        sta cur_sector
        jsr bam_free_block       ; give the first block back and take the one we just got as the new header block
        pla
        tax
        sta cur_track
        pla
        sta cur_sector
        cpx spec_trk             ; back at the first block we started with: nothing else free
        bne cmd_m_allocate_header_pair_loop
        cmp spec_sec
        bne cmd_m_allocate_header_pair_loop
        jsr bam_free_block
        lda #$65                 ; error 65 NO BLOCK
        jmp dos_error_00
cmd_m_pair_found
        pla
        pla
        lda #$00
        sta spec_trk
        jsr change_directory     ; go to the directory the new name is made in
        lda hdr_sector           ; remember the parent's header location
        pha
        lda hdr_track
        pha
        jsr find_entry_loop      ; does the name already exist?
        lda spec_trk
        beq cmd_m_name_available
        lda #$63                 ; error 63 FILE EXISTS
        jmp dos_error_00
cmd_m_name_available
        lda #$06                 ; file type 6 = DIR
        sta file_type
        lda move_tmp_trk
        sta cur_track
        lda move_tmp_sec
        sta cur_sector
        jsr dir_add_entry        ; add the directory entry
        ldx cur_chan
        lda #$02                 ; a directory entry for a new directory counts 2 blocks (header + first dir block)
        sta chan_blk_lo,x
        lda #$00
        sta chan_blk_hi,x
        jsr close_update_dir     ; close writes the entry
        jsr bam_write_if_dirty
        ldx move_tmp_sec         ; new header = the first of the two blocks
        stx hdr_sector
        inx
        stx dir1_sector          ; its directory block is the next one
        lda move_tmp_trk
        sta hdr_track
        jsr new_write_header     ; build and write the new header
        pla
        sta dirblk_buf+34        ; the header remembers its parent: track and sector of the parent header (offsets 34/35)
        pla
        sta dirblk_buf+35
        lda spec_aux1            ; and the position of its entry in the parent directory (offsets 36-38)
        sta dirblk_buf+36
        lda spec_aux2
        sta dirblk_buf+37
        lda spec_aux3
        sta dirblk_buf+38
        jsr write_header_blk     ; write the header
        jsr dirblk_init_link     ; an empty first directory block
        jmp write_dir1_blk       ; and write it

; --- cmd_rename: R command: rename / RD remove directory
; R command: "RD:name" removes an empty directory, everything else goes to the rename code.
cmd_rename
        lda cmd_buf+1
        cmp #$44                 ; 'D'
        beq cmd_r_remove_directory
cmd_r_rename_misc
        jmp cmd_rename_misc
cmd_r_remove_directory
        jsr prep_spec_cmd        ; native partition?
        bne cmd_r_rename_misc
        lda name_end_tbl         ; take the name from the end of the path
        pha
        ldx name_start
        dex
        stx name_end_tbl
        lda #$2F                 ; temporarily end the path before the name with a '/'
        sta cmd_buf,x
        lda #$00
        jsr change_directory     ; go to the directory
        pla
        sta name_end_tbl
        lda #$00                 ; search it
        sta dir_first_flag
        jsr dir_scan_open        ; any entries left?
        beq cmd_r_scratch_directory ; no: the directory is empty
        ldy #$00
        sty cur_track
        lda #$01
        jmp cmd_status_ts        ; error 01 with track 0: not empty (reported as FILES SCRATCHED 00)
cmd_r_scratch_directory
        ldx name_start           ; put a ':' in front of the name again
        dex
        lda #$3A
        sta cmd_buf,x
        jmp scratch_main_restart_spec_scan ; scratch the directory entry (cmd_class 3 allows type 6)

; --- prep_spec_cmd: Standard preparation: parse and resolve the single spec
; Common preparation for MD and RD: class 3, parse, resolve the specs, Z = 1 if native.
prep_spec_cmd
        lda #$03
        sta cmd_class
        jsr require_colon
        jsr resolve_specs
        jmp is_native

; --- cmd_g: G command: G-P (get partition info) and 'GEOS' query
; G command. "G-P" (partition info: 30 bytes of the partition table entry) and "G"+"EOS" which
; selects the system partition's "EOS" area.
cmd_g
        ldx #$01                 ; compare the three letters with 'EOS'
cmd_g_check_geos_loop
        lda cmd_buf,x
        cmp txt_eos-1,x
        bne cmd_g_test_get_partition
        inx
        cpx #$04
        bcc cmd_g_check_geos_loop
        ldx #$01
        jsr select_system_part   ; select the system partition
        jmp cmd_status_ok        ; status 00
; --- txt_eos: 'EOS' signature
txt_eos
        !text "EOS"                     ; $BE1A
cmd_g_test_get_partition         ; "G-P"
        lda cmd_buf+1
        cmp #$2D
        bne cmd_g_invalid
        lda cmd_buf+2
        cmp #$50
        beq cmd_g_get_partition_info
cmd_g_invalid
        jmp err_31_invalid_cmd
cmd_g_get_partition_info
        lda cmd_len              ; a partition number was given?
        cmp #$04
        bcc cmd_g_use_current_partition
        lda cmd_buf+3            ; $FF means the current partition
        cmp #$FF
        bne cmd_g_read_table_block
cmd_g_use_current_partition
        lda cur_part
cmd_g_read_table_block
        pha                      ; partition number
        lsr                      ; eight entries per 256 byte block: block = number / 8
        lsr
        lsr
        jsr read_sys_block       ; read that block of the partition table
        bcc cmd_g_copy_entry
        lda #$78                 ; error 78 SYSTEM ERROR
        jmp jt_job_error
cmd_g_copy_entry
        pla
        pha
        and #$07                 ; entry = (number mod 8) * 32 + 2
        asl
        asl
        asl
        asl
        asl
        clc
        adc #$02
        sta buf_ptr_b            ; entry address in the block
        ldy #$00
        lda (buf_ptr_b),y        ; partition type (first byte) is returned as the first byte of the status channel
        sta chan_byte+31
cmd_g_copy_entry_loop
        lda (buf_ptr_b),y        ; 30 bytes of the entry go to the message buffer
        sta errmsg_buf,y
        iny
        cpy #$1E
        bcc cmd_g_copy_entry_loop
        pla
        ldy #$02                 ; byte 2 is the partition number
        sta errmsg_buf,y
        lda #$1D                 ; 30 bytes
        clc
        adc #$00
        sta chan_last+31
        jsr errmsg_reset         ; reset the message pointer: the host reads the 30 bytes on channel 15
        inc errmsg_ptr           ; and skip the first byte, which was put into chan_byte
        lda #$88                 ; $88 = active, last byte
        sta chan_flags+31
        rts

; --- reset_dir_search: Reset the directory search state
; Start of a directory search: the partition must be valid.
reset_dir_search
        lda #$00
        sta tmp_a
        jsr check_part_valid     ; error 74 DRIVE NOT READY otherwise
        beq reset_dir_search_done
        lda #$74
        jmp dos_error_00
reset_dir_search_done
        jmp led_on

; --- sort_specs_by_part: Reorder the specs so same-partition entries are adjacent
; Handle every spec's partition in turn so specs on the same partition are processed together.
sort_specs_by_part
        ldx file_count
        dex
sort_specs_spec_loop
        stx swap_idx
        lda spec_part,x
        beq sort_specs_next_spec
        jsr swap_spec_parts
        jsr select_partition
        lda swap_idx
        jsr find_entry_part
        jsr swap_spec_parts
sort_specs_next_spec
        dex
        bpl sort_specs_spec_loop
        rts

; --- swap_spec_parts: Swap partition numbers of specs
; Swap the partition number of spec swap_idx with the one of the others (xor swap).
swap_spec_parts
        ldx swap_idx
        lda spec_part,x
        pha
        ldy file_count
        dey
swap_specs_xor_swap_loop
        pla
        pha
        eor spec_part,y
        sta spec_part,y
        dey
        bpl swap_specs_xor_swap_loop
        pla
        sta spec_part,x
        rts

; --- find_entry_first: Find the first matching directory entry (partition 0)
; Find the first entry matching the specs in the current partition (or partition A).
find_entry_first
        lda #$00

; --- find_entry_part: Find the first matching directory entry in partition A
find_entry_part
        pha
        jsr reset_dir_search
        pla
        jsr change_directory

; --- find_entry_loop: Directory search loop
; Directory search loop: reads entries until one matches a spec or the directory ends.
find_entry_loop
        jsr reset_dir_search
        lda #$00
        sta dir_first_flag
        jsr dir_scan_open
        bne find_entry_loop_match_entry
find_entry_loop_done
        rts
find_entry_loop_next_entry
        jsr dir_scan_next
        beq find_entry_loop_end_of_dir
find_entry_loop_match_entry      ; compare the entry with all specs
        jsr match_entry_against_specs
        lda found_state          ; found_state <> 0: a file has been found for the last spec, return
        beq find_entry_loop_check_match_type
        rts
find_entry_loop_check_match_type
        lda match_type           ; match type: bit 7 = not matched
        bmi find_entry_loop_next_entry
        bpl find_entry_loop_match_entry
find_entry_loop_end_of_dir
        lda found_state
        beq find_entry_loop_done
        rts

; --- find_next_entry: Continue directory search
; Continue the search after the last match.
find_next_entry
        jsr dir_scan_reopen
        beq find_entry_init_no_more_entries
        bne find_entry_cont_test_entry

; --- find_entry_next_part: Search from first block for partition 0
find_entry_next_part
        lda #$00

; --- find_entry_in_part: Directory search in partition A
find_entry_in_part
        pha
        lda #$00
        sta dir_first_flag
        pla
        jsr change_directory

; --- find_entry_init: Initialise a directory search
; Initialise a directory search and return the first matching entry.
find_entry_init
        lda #$00
        sta dir_first_flag
        jsr dir_scan_open
        bne find_entry_cont_test_entry
        sta found_state
find_entry_init_no_more_entries
        lda #$FF
        rts

; --- find_entry_cont: Directory search continuation
; Return the next entry that matches a spec (and passes the date and type filters).
find_entry_cont
        jsr dir_scan_next
        beq find_entry_init_no_more_entries
find_entry_cont_test_entry
        jsr match_entry_against_specs
        ldx match_type
        bpl find_entry_cont_check_after_filter
        lda found_state
        beq find_entry_cont
        bne find_entry_cont_done
find_entry_cont_check_after_filter
        bit filter_flags         ; filter: files dated after the given date
        bpl find_entry_cont_check_before_filter
        ldx #$00
        ldy #$17                 ; date field of the entry starts at offset $17
find_entry_cont_compare_after_loop
        lda (dir_ptr),y          ; compare year, month, day, hour, minute with the date given
        cmp rtc_buf+8,x
        bcc find_entry_cont_check_before_filter
        bne find_entry_cont
        inx
        iny
        cpy #$1C
        bcc find_entry_cont_compare_after_loop
find_entry_cont_check_before_filter
        bit filter_flags2        ; filter: files dated before the given date
        bpl find_entry_cont_check_type_filter
        ldx #$00
        ldy #$17
find_entry_cont_compare_before_loop
        lda (dir_ptr),y
        cmp rtc_buf+13,x
        bcc find_entry_cont
        bne find_entry_cont_check_type_filter
        inx
        iny
        cpy #$1C
        bcc find_entry_cont_compare_before_loop
find_entry_cont_check_type_filter
        ldx match_type           ; file type letter filter
        lda file_type_chr
        beq find_entry_cont_done
        lda spec_type,x          ; file type of the entry
        and #$07
        cmp file_type_chr
        bne find_entry_cont
find_entry_cont_done
        rts

; --- match_entry_against_specs: Compare the directory entry with the file specs
; Compare the directory entry at dir_ptr with every spec of this partition. Wildcards: '?'
; matches any character, '*' matches the rest of the name (or a suffix). On a match the entry
; location and its track/sector are stored in the spec tables.
match_entry_against_specs
        ldx #$FF                 ; match_type = $FF: nothing matched
        stx match_type
        inx
        stx cmd_flag_e4          ; no wildcard seen
        jsr spec_scan_init       ; start with the last spec
        beq match_entry_compare_spec
match_entry_done
        rts                      ; X = spec number
match_entry_next_spec
        jsr spec_scan_next
        bne match_entry_done
match_entry_compare_spec
        lda spec_part,x          ; only specs of the current partition
        cmp cur_part
        bne match_entry_next_spec
        lda name_start,x         ; start of the name in the command
        tax
        jsr name_find_end        ; find its end
        ldy #$03                 ; file name starts at offset 3 in the entry
        bne match_entry_check_name_end
match_entry_compare_char_loop
        lda cmd_buf,x            ; character of the pattern
        cmp (dir_ptr),y          ; equal to the name character?
        beq match_entry_next_char
        cmp #$3F                 ; '?' matches anything...
        bne match_entry_next_spec
        lda (dir_ptr),y
        cmp #$A0                 ; ...except a shifted space ($A0), which is padding
        beq match_entry_next_spec
match_entry_next_char
        inx
        iny
match_entry_check_name_end
        cpx name_end             ; end of the pattern?
        bcs match_entry_check_name_padding
        lda cmd_buf,x
        cmp #$2A                 ; '*' matches the rest of the name
        bne match_entry_compare_char_loop
        jmp match_wildcard_suffix ; compare the end of the pattern with the end of the name
match_entry_check_name_padding
        cpy #$13                 ; name is 16 characters long (offsets 3-18)
        bcs match_entry_match_found
        lda (dir_ptr),y
        cmp #$A0                 ; rest of the name must be padding
        bne match_entry_next_spec
match_entry_match_found
        ldx file_cur             ; a spec matched: file_cur
        stx match_type
        lda spec_type,x          ; remember if this spec used a wildcard
        and #$80
        sta cmd_flag_e4
        lda ent_offset           ; entry location: offset, track, sector
        sta spec_aux3,x
        lda cur_track
        sta spec_aux1,x
        lda cur_sector
        sta spec_aux2,x
        ldy #$00                 ; file type byte of the entry
        lda (dir_ptr),y
        iny
        pha                      ; keep the lock bit (bit 6) as flag in spec_type
        and #$40
        sta tmp_a
        pla
        and #$DF                 ; a closed file has bit 7 set; a splat file (not closed) gets bit 5 set
        bmi match_entry_build_entry_flags
        ora #$20
match_entry_build_entry_flags
        and #$27                 ; keep the type bits and the flags
        ora tmp_a
        sta tmp_a
        lda #$80                 ; bit 7 stays as the wildcard flag
        and spec_type,x
        ora tmp_a
        sta spec_type,x
        lda (dir_ptr),y          ; first block of the file (entry bytes 1 and 2)
        bne match_entry_store_spec_result
        cmp cur_part             ; track 0 would mean "not found": use track 1 if it really is partition 0
        bne match_entry_store_spec_result
        lda #$01
match_entry_store_spec_result
        sta spec_trk,x
        iny
        lda (dir_ptr),y
        sta spec_sec,x
        lda rel_rec_len          ; first REL record length seen (entry byte $15)
        bne spec_scan_init
        ldy #$15
        lda (dir_ptr),y
        sta rel_rec_len

; --- spec_scan_init: Start scanning the specs for the current partition
; Start with the last spec; found_state = $FF means "all specs found".
spec_scan_init
        lda #$FF
        sta found_state
        lda file_count
        sta file_cur

; --- spec_scan_next: Next unmatched spec
; Next spec that has not been matched yet. found_state = 0 if there still is one.
spec_scan_next
        dec file_cur             ; spec below zero: done
        bpl spec_scan_next_check_spec_slot
        rts
spec_scan_next_check_spec_slot
        ldx file_cur
        lda spec_type,x          ; bit 7 = wildcard spec (can match several files)
        bmi spec_scan_next_mark_unmatched
        lda spec_trk,x           ; a track <> 0 means it was found already
        bne spec_scan_next
spec_scan_next_mark_unmatched
        lda #$00
        sta found_state
        rts
; '*' wildcard: the part of the pattern after the star must match the end of the name.
match_wildcard_suffix
        stx tmp_len
        ldx name_end
        dex
        cpx tmp_len
        beq match_wild_suffix_matched
        ldy #$13                 ; find the last used character of the name
match_wild_skip_padding_loop
        dey
        lda (dir_ptr),y
        cmp #$A0
        beq match_wild_skip_padding_loop
match_wild_compare_suffix_loop
        lda cmd_buf,x
        cmp (dir_ptr),y
        beq match_wild_next_suffix_char
        cmp #$3F                 ; '?' again matches anything
        bne match_wild_suffix_mismatch
match_wild_next_suffix_char
        dey
        dex
        cpx tmp_len
        bne match_wild_compare_suffix_loop
match_wild_suffix_matched
        jmp match_entry_match_found
match_wild_suffix_mismatch
        jmp match_entry_next_spec

; --- dir_scan_open: Open the directory chain and read the first block
; Open the directory of the partition and look for the first entry. dir_blk_flag holds the
; link track of the block just read (0 = last block). Free entries are noted in dir_scan_tmp so
; a new file can use the first free slot.
dir_scan_open
        ldy #$00
        sty dir_scan_tmp         ; no free slot found yet
        dey
        sty match_type           ; nothing matched
        sty dir_blk_flag
        lda hdr_track            ; first directory block
        sta cur_track
        lda dir1_sector
        sta cur_sector
        jsr dir_open_chan        ; open the directory channel (channel 17)
dir_scan_open_check_block_loaded
        lda dir_blk_flag         ; any block left?
        bne dir_scan_open_start_block
        rts
dir_scan_open_start_block
        lda #$07                 ; 8 entries per block
        sta dir_ent_ctr
        lda #$00                 ; link track of the block
        jsr chan_get_byte_at
        sta dir_blk_flag         ; remember the link
dir_scan_open_examine_entry
        jsr chan_get_ptr         ; entry pointer
        dec dir_ent_ctr
        ldy #$00
        lda (dir_ptr),y          ; first byte of the entry = file type
        bne dir_scan_open_entry_in_use ; used entry
        lda dir_scan_tmp         ; free slot already noted?
        bne dir_scan_next
        jsr ts_from_chan         ; remember where the free slot is
        lda cur_part
        sta last_part
        lda cur_track            ; track/sector/offset of the free slot
        sta dir_scan_tmp
        lda cur_sector
        sta dir_scan_tmp+1
        lda dir_ptr
        ldx dir_first_flag
        sta dir_first_flag
        beq dir_scan_next        ; first call: return the free slot
        rts
dir_scan_open_entry_in_use       ; entry is in use. dir_first_flag = 1 means "only look for a free slot".
        ldx #$01
        cpx dir_first_flag
        bne dir_scan_next_record_entry_position
        beq dir_scan_next

; --- dir_scan_reopen: Re-read the directory block holding the current entry
; Read the directory block holding the entry noted in ent_track/ent_sector/ent_offset again.
dir_scan_reopen
        lda ent_track
        sta cur_track
        lda ent_sector
        sta cur_sector
        jsr dir_open_chan
        lda ent_offset
        jsr chan_set_ptr

; --- dir_scan_next: Advance to the next directory entry (reads next block if needed)
; Advance to the next directory entry; at the end of a block follow the link to the next one.
dir_scan_next
        lda #$FF
        sta match_type
        lda dir_ent_ctr          ; entries left in this block?
        bmi dir_scan_next_next_block
        lda #$20                 ; 32 bytes per entry
        jsr chan_ptr_add
        jmp dir_scan_open_examine_entry
dir_scan_next_next_block
        jsr chain_read_first
        jmp dir_scan_open_check_block_loaded
dir_scan_next_record_entry_position
        lda dir_ptr              ; remember the entry's position
        sta ent_offset
        jsr ts_from_chan
        lda cur_sector
        sta ent_sector
        lda cur_track
        sta ent_track
        rts

; --- name_pad_copy: Copy the file name and pad with $A0
; Copy the name in the command at X (up to 16 characters) into the entry and pad it to 16 with $A0.
name_pad_copy
        pha
        jsr name_find_end
        jsr name_copy
        pla
        sec
        sbc name_len
        tax
        beq name_pad_done
        bcc name_pad_done
        lda #$A0
name_pad_pad_loop
        sta (dir_ptr),y
        iny
        dex
        bne name_pad_pad_loop
name_pad_done
        rts

; --- name_copy: Copy the name from the command buffer into the entry
; Copy the name from cmd_buf,X into the entry at the buffer of channel Y.
name_copy
        tya
        asl
        tay
        lda+2 buf_ptr_tbl,y
        sta dir_ptr
        lda+2 buf_ptr_tbl_hi,y
        sta dir_ptr_hi
        ldy #$00                 ; at most 256 bytes
name_copy_copy_char_loop
        lda cmd_buf,x
        sta (dir_ptr),y
        iny
        beq name_copy_done
        inx
        cpx name_end
        bcc name_copy_copy_char_loop
name_copy_done
        rts

; --- name_find_end: Find the end of the name ('=' ',' or length limit)
; Find the end of the name at cmd_buf,X: ',' '=' or 16 characters or the end of the command.
name_find_end
        lda #$00
        sta name_len
        txa
        pha
name_find_end_scan_loop
        lda cmd_buf,x
        cmp #$2C
        beq name_find_end_done
        cmp #$3D
        beq name_find_end_done
        inc name_len
        inx
        lda #$0F
        cmp name_len
        bcc name_find_end_done
        cpx cmd_len
        bcc name_find_end_scan_loop
name_find_end_done
        stx name_end
        pla
        tax
        rts

; --- dir_format_entry: Format one directory listing line for the current entry (saves and restores the caller's channel)
; Wrapper that saves and restores the current channel and secondary address.
dir_format_entry
        lda cur_sa
        pha
        lda cur_chan
        pha
        jsr dir_format_entry_line
        pla
        sta cur_chan
        pla
        sta cur_sa
        rts

; --- dir_format_entry_line: Build the listing line (blocks, type, name, date) for the current directory entry; on the last entry appends the trailer
dir_format_entry_line
        lda #$11                 ; use channel 17 (directory channel)
        sta cur_sa
        jsr get_chan_for_sa
        jsr chan_get_ptr         ; dir_ptr points at the entry
        lda match_type           ; match_type: $FF = no more entries
        bpl dir_entry_format_entry
        jsr dir_trailer          ; end of the listing: the BLOCKS FREE line
        clc
        rts
dir_entry_format_entry
        ldx #$18                 ; the line is built from the right; X = position of the last digit
        ldy #$1D                 ; blocks used: high byte at offset $1D
        bit dir_mode             ; partition listing: the entry number is shown as the "blocks" field
        bpl dir_entry_read_blocks_hi
        lda #$00
        beq dir_entry_store_blocks_hi
dir_entry_read_blocks_hi
        lda (dir_ptr),y          ; file size in blocks: high byte
dir_entry_store_blocks_hi
        sta blocks_free_hi
        beq dir_entry_blocks_lo_setup ; more than 255 blocks: the number takes more characters
        ldx #$16
dir_entry_blocks_lo_setup
        dey                      ; low byte at offset $1C
        bit dir_mode
        bpl dir_entry_read_blocks_lo
        lda dir_ptr              ; partition number = entry offset / 32 + 8 * block sector
        lsr
        lsr
        lsr
        lsr
        lsr
        sta blocks_free_lo
        lda cur_sector
        asl
        asl
        asl
        clc
        adc blocks_free_lo
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dir_entry_read_blocks_lo
        lda (dir_ptr),y          ; file size low byte
        sta blocks_free_lo
        cpx #$16                 ; number of digits: adjust the starting column
        beq dir_entry_clear_line_start
        cmp #$0A
        bcc dir_entry_clear_line_start
        dex
        cmp #$64
        bcc dir_entry_clear_line_start
        dex
dir_entry_clear_line_start
        jsr dirline_clear
        lda (dir_ptr),y          ; file type byte
        bit dir_mode
        bmi dir_entry_partition_type_index
        pha
        asl                      ; bit 6 = locked: show a '<' after the type
        bpl dir_entry_restore_type_byte
        lda #$3C                 ; '<'
        sta dir_line+1,x
dir_entry_restore_type_byte
        pla
        jmp dir_entry_format_type_name
dir_entry_partition_type_index
        cmp #$FF                 ; partition listing: type 0..7 index +7 into the type letters table
        bne dir_entry_add_partition_offset
        lda #$00                 ; system partition ($FF) uses index 0
dir_entry_add_partition_offset
        clc
        adc #$07
        sec                      ; carry = 1: don't add the '*' for unclosed files
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dir_entry_format_type_name
        and #$0F                 ; low three bits = file type
        tay
        lda ftype_chr3,y         ; three letters of the type
        sta dir_line,x
        dex
        lda ftype_chr2,y
        sta dir_line,x
        dex
        lda ftype_chr1,y
        sta dir_line,x
        dex
        dex
        bcs dir_entry_pad_before_name ; unclosed file: put a '*' before the type
        lda #$2A
        sta dir_line+1,x
dir_entry_pad_before_name
        lda #$A0                 ; quote mark position
        sta dir_line,x
        dex
        ldy #$12                 ; name: 16 characters from offset 3 to 18
dir_entry_copy_name_loop
        lda (dir_ptr),y
        sta dir_line,x
        dex
        dey
        cpy #$03
        bcs dir_entry_copy_name_loop
        lda #$22                 ; opening quote
        sta dir_line,x
dir_entry_find_name_end_loop     ; find the end of the name: the closing quote goes after the last non-padding character
        inx
        cpx #$20
        bcs dir_entry_close_quote
        lda dir_line,x
        cmp #$22
        beq dir_entry_close_quote
        cmp #$A0
        bne dir_entry_find_name_end_loop
dir_entry_close_quote
        lda #$22
        sta dir_line,x
dir_entry_strip_high_bit_loop    ; characters after the name are padding: clear bit 7
        inx
        cpx #$20
        bcs dir_entry_read_timestamp
        lda #$7F
        and dir_line,x
        sta dir_line,x
        bpl dir_entry_strip_high_bit_loop
dir_entry_read_timestamp         ; date/time of the entry: offsets $17-$1B
        ldx #$04
        ldy #$1B
dir_entry_timestamp_loop         ; year, month, day, hour, minute
        lda (dir_ptr),y
        sta ts_year,x
        dey
        dex
        bpl dir_entry_timestamp_loop
        lda ts_hour              ; 12 hour clock
        cmp #$0C
        bcc dir_entry_set_am
        sbc #$0C
        sta ts_hour
        lda #$80                 ; PM flag
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dir_entry_set_am
        lda #$00
        sta ts_min+1             ; ts_min+1 holds the AM/PM flag
        lda ts_hour
        bne dir_entry_fetch_next_entry
        lda #$0C
        sta ts_hour
dir_entry_fetch_next_entry
        jsr find_entry_cont      ; point at the next matching entry for the next call
        sec                      ; carry set = there was an entry
        rts
; --- ftype_chr1: File-type letters (first)
; File type letters: DEL SEQ PRG USR REL CBM DIR (first, second and third letters), then the
; partition type letters SYS NAT 41 71 81 C81 PRN FOR use the tail of the same tables.
ftype_chr1
        !text "DSPURCD"                 ; $C292
; --- ptype_chr1: Partition-type name letters ($=P listing): SYS NAT 41 71 81 C81 PRN FOR (first letter; 2nd/3rd are the tail of ftype_chr2/3)
ptype_chr1
        !text "SN478CPF"                ; $C299
; --- ftype_chr2: File-type letters (second)
ftype_chr2
        !text "EERSEBIYA1118RO"         ; $C2A1
; --- ftype_chr3: File-type letters (third)
ftype_chr3
        !text "LQGRLMRST   1NR"         ; $C2B0

; --- dirline_clear: Clear the directory line buffer with spaces
; Fill the directory line buffer with spaces.
dirline_clear
        ldy #$1B
        lda #$20
dirline_clear_clear_loop
        sta bam_aux+31,y
        dey
        bne dirline_clear_clear_loop
        rts
; --- dir_hdr_template: Directory header template ('CMD HD' ... 'HD',$A0,'1H')
; Header line of the partition listing: 'CMD HD' ... 'HD', then ID '1H'.
dir_hdr_template
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $C2CA
        !byte $20,$20,$20,$20,$20,$20,$20,$20 ; $C2D2
        !byte $A0,$A0,$48,$44,$A0,$31,$48 ; $C2DA

; --- dir_header_line: Build the directory header line (partition name, ID)
; Build the header line of a listing: reverse "disk name" and ID, like the first line of a
; CBM directory. The partition listing ($=P) has a fixed header instead.
dir_header_line
        bit dir_mode             ; partition listing mode
        bpl dir_header_read_real_header
        ldx #$17                 ; copy the template into the header buffer
dir_header_copy_template_loop
        lda dir_hdr_template,x
        sta dirblk_buf+4,x
        dex
        bpl dir_header_copy_template_loop
        bmi dir_header_build_header
dir_header_read_real_header
        jsr check_part_valid     ; disk header block of the partition
        jsr read_header_blk
dir_header_build_header
        jsr dirline_clear
        lda #$FF
        sta tmp_a
        lda #$00
        sta blocks_free_lo
        sta blocks_free_hi
        lda #$22
        sta dir_ptr_hi
        ldy cur_part             ; which partition?
        cpy #$FF                 ; system partition
        beq dir_header_native_or_system_offset
        lda part_type,y          ; type of the partition
        cmp #$01                 ; native: name at offset 4
        beq dir_header_native_or_system_offset
        cmp #$04                 ; 1541/1571: name at offset $90
        bcc dir_header_old_style_offset
dir_header_native_or_system_offset
        lda #$04
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dir_header_old_style_offset
        lda #$90
        sta dir_ptr              ; source of the name and ID
        ldy #$00
dir_header_copy_name_loop        ; 23 bytes: name, 2 shifted spaces, ID, and so on
        lda (dir_ptr),y
        cmp #$A0
        bne dir_header_store_char
        lda #$20                 ; $A0 padding is shown as a space
dir_header_store_char
        sta dir_line+2,y
        iny
        cpy #$17
        bcc dir_header_copy_name_loop
        ldy #$FF                 ; line number 0 is the drive number in a BASIC program line
        lda #$04
        sta dir_ptr              ; dir_ptr set to the next line
        lda #$12                 ; reverse-video on ($12)
        sta dir_line
        lda #$22
        sta dir_line+1
        sta dir_line+18          ; closing quote after the name
        lda #$20
        sta dir_line+19
        rts

; --- dir_trailer: Build the 'BLOCKS FREE.' trailer line
; Build the last line: BLOCKS FREE.
dir_trailer
        jsr dirline_clear
        ldy #$0B
dir_trailer_copy_text_loop
        lda txt_blocks_free,y
        sta dir_line,y
        dey
        bpl dir_trailer_copy_text_loop
        jmp dir_get_free         ; then the number of free blocks
; --- txt_blocks_free: 'BLOCKS FREE.'
txt_blocks_free
        !text "BLOCKS FREE."            ; $C361

; --- entry_clear: Clear the first byte of the directory entry (delete)
; Delete the directory entry at dir_ptr by clearing the file type byte, and write the block.
entry_clear
        ldy #$00
        tya
        sta (dir_ptr),y
        jsr job_write_chan_buf_clean
        jmp job_wait

; --- dir_open_chan: Open the directory channel ($11)
; Open the directory channel (channel 17) as a sequential channel and read the first block.
dir_open_chan
        lda #$01

; --- dir_open_type: Open channel with file type A
dir_open_type
        sta file_type
        lda #$11
        sta cur_sa
        jsr open_read_chan
        lda #$02                 ; skip the two link bytes
        jmp chan_set_ptr

; --- dir_open_chan_wr: Open the write channel ($12)
; Open the write channel for the directory (channel 18).
dir_open_chan_wr
        lda #$12
        sta cur_sa
        jmp open_write_chan_a

; --- dir_write_link: Write a new directory block link
; Chain a new block to the end of the directory: allocate it, put its link in the old last
; block, write that, then clear the new block (link $00/$FF).
dir_write_link
        jsr ts_from_chan         ; current block
        jsr alloc_next_dir_block ; allocate the next directory block
        lda #$00                 ; link goes into bytes 0 and 1
        jsr chan_set_ptr
        lda cur_track
        jsr chan_put_byte
        lda cur_sector
        jsr chan_put_byte
        jsr chan_write_job       ; write the old block
        jsr job_wait
        lda #$00                 ; fill the new block with zeroes
        jsr chan_set_ptr
dir_write_link_write_zero_fill
        jsr chan_put_byte
        bne dir_write_link_write_zero_fill
        jsr chan_put_byte        ; last byte of the link = $FF
        lda #$FF
        jmp chan_put_byte

; --- dir_add_entry: Find/create a directory entry slot for a new file
; Find a free entry slot in the directory for a new file and write its first bytes (type,
; first track and sector, name). If the directory is full a new block is chained on.
dir_add_entry
        lda cur_sa
        pha
        lda cur_chan
        pha
        lda cur_sector
        pha
        lda cur_track
        pha
        lda #$00
        sta spec_aux1
        lda #$11
        sta cur_sa
        jsr ts_from_chan
        lda file_type            ; file type to write
        pha
        lda spec_part            ; same partition as the previous search? Then the free slot noted earlier is valid
        cmp last_part
        beq dir_add_entry_same_partition
        ldx #$01                 ; dir_first_flag = 1: "look for a free slot only"
        stx dir_first_flag
        jsr dir_scan_open        ; search for a free slot
        beq dir_add_entry_extend_directory ; none: the directory is full, add a block
        bne dir_add_entry_set_slot_pointer
dir_add_entry_same_partition
        lda dir_scan_tmp         ; a free slot was found before
        beq dir_add_entry_rescan_from_start
        cmp cur_track            ; are we on that block?
        bne dir_add_entry_reload_dir_block
        lda cur_sector
        cmp dir_scan_tmp+1
        beq dir_add_entry_set_slot_pointer
dir_add_entry_reload_dir_block
        lda dir_scan_tmp         ; load the block with the free slot
        sta cur_track
        lda dir_scan_tmp+1
        sta cur_sector
        jsr read_chan_buf
        jmp dir_add_entry_set_slot_pointer
dir_add_entry_rescan_from_start
        lda #$01                 ; rescan from the start
        sta dir_first_flag
        jsr dir_scan_next        ; next entry
        bne dir_add_entry_set_slot_pointer
dir_add_entry_extend_directory
        jsr dir_write_link       ; extend the directory by one block
        sec
        ror spec_aux1            ; remember that the directory grew (spec_aux1 b7)
        lda cur_sector
        sta dir_scan_tmp+1
        lda cur_track
        sta dir_scan_tmp
        lda #$02                 ; first entry of the new block is at offset 2
        sta dir_first_flag
dir_add_entry_set_slot_pointer
        lda dir_first_flag
        jsr chan_set_ptr         ; position the pointer
        pla
        sta file_type
        cmp #$04                 ; REL files get bit 7 (closed) later
        bne dir_add_entry_put_type_byte
        ora #$80
dir_add_entry_put_type_byte
        jsr chan_put_byte        ; first byte: file type
        pla
        sta spec_trk             ; bytes 1/2: first track/sector
        jsr chan_put_byte
        pla
        sta spec_sec
        jsr chan_put_byte
        jsr chan_cur_buf         ; channel buffer
        tay
        lda name_start           ; name from the command
        tax
        lda #$10                 ; 16 characters
        jsr name_pad_copy
        ldy #$10                 ; clear the rest of the entry: offsets $10-$1A
        lda #$00
dir_add_entry_clear_entry_loop
        sta (dir_ptr),y
        iny
        cpy #$1B
        bcc dir_add_entry_clear_entry_loop
        lda file_type            ; REL files store the first side sector and the record length
        cmp #$04
        bne dir_add_entry_write_entry_block
        ldy #$10
        lda rel_ss_track
        sta (dir_ptr),y
        iny
        lda rel_ss_sector
        sta (dir_ptr),y
        iny
        lda rel_rec_len
        sta (dir_ptr),y
dir_add_entry_write_entry_block
        jsr write_chan_buf       ; write the directory block
        bit spec_aux1            ; did the directory grow?
        bpl dir_add_entry_record_entry_location
        jsr is_native            ; only native partitions keep a block count in the parent entry
        bne dir_add_entry_record_entry_location
        lda hdr_track            ; root directory has no parent
        cmp #$01
        bne dir_add_entry_update_parent_blockcount
        cmp hdr_sector
        beq dir_add_entry_record_entry_location
dir_add_entry_update_parent_blockcount
        jsr read_link_blk        ; read the block with the parent's entry
        lda dirblk_buf,x         ; is this the entry for our directory (type $86 = closed DIR)?
        cmp #$86
        bne dir_add_entry_record_entry_location
        lda dirblk_buf1,x
        cmp hdr_track            ; same header track and sector?
        bne dir_add_entry_record_entry_location
        lda dirblk_buf+2,x
        cmp hdr_sector
        bne dir_add_entry_record_entry_location
        inc dirblk_buf+28,x      ; add 1 to the block count of the sub-directory
        bne dir_add_entry_save_parent_block
        inc dirblk_buf+29,x
dir_add_entry_save_parent_block
        jsr write_dirblk         ; write the parent's directory block
dir_add_entry_record_entry_location
        pla                      ; restore the channel
        sta cur_chan
        tax
        pla
        sta cur_sa
        lda dir_scan_tmp         ; keep the entry position for the close
        sta spec_aux1
        sta chan_dir_track,x
        lda dir_scan_tmp+1
        sta spec_aux2
        sta chan_dir_sector,x
        lda dir_first_flag
        sta spec_aux3
        sta chan_dir_index,x
        lda file_type
        sta spec_type
        rts

; --- dir_list_start: Start of the directory listing (load address and link bytes)
; Start a directory listing for LOAD "$". The result is a BASIC program: load address $0401,
; then one program line per entry (link, line number = blocks, text, 0).
dir_list_start
        lda #$00                 ; secondary address 0
        sta cur_sa
        lda #$01                 ; channel type 1
        jsr alloc_chan           ; allocate a channel and buffer
        lda #$00
        jsr chan_set_ptr         ; start at 0
        ldx cur_chan
        lda #$00
        sta chan_last,x          ; no last byte yet
        jsr chan_cur_buf
        tax
        lda #$00
        sta job_status,x         ; clear the job status
        lda #$01
        jsr chan_put_byte        ; load address low $01...
        lda #$04
        jsr chan_put_byte        ; ...high $04
        lda #$01                 ; first line's link (dummy, patched by the BASIC loader)
        jsr chan_put_byte
        jsr chan_put_byte
        lda cur_part             ; line number = partition number (0 = $FF)
        bne dir_list_start_partition_number_byte
        lda #$FF
dir_list_start_partition_number_byte
        jsr chan_put_byte
        lda #$00
        jsr chan_put_byte
        jsr dir_emit_line        ; header line text
        dec buf_ptr_tbl,x        ; back up over the two link bytes of the next line
        dec buf_ptr_tbl,x
        lda #$01
        sta dir_line_flag        ; line counter for the extended listing
        lda #$00
        jsr chan_put_byte

; --- dir_list_line: Produce one directory listing line
; One directory line: dummy link, then line number (blocks), then the text, then 0.
dir_list_line
        lda #$01                 ; link bytes (dummy)
        jsr chan_put_byte
        jsr chan_put_byte
        jsr dir_format_entry     ; build the next line; carry set = there is one
        bcc dir_list_line_end_of_directory
        lda blocks_free_lo       ; line number = block count
        jsr chan_put_byte
        lda blocks_free_hi
        jsr chan_put_byte
        jsr dir_emit_line        ; line text
        bit dir_mode             ; long listing mode (dir_mode b6)?
        bvc dir_list_line_end_line
        jsr dir_trim_line        ; trim the line and add the dates
dir_list_line_end_line
        lda #$00                 ; end of line
        jsr chan_put_byte
        bne dir_list_line
dir_list_line_finish_listing     ; finished: end of the listing
        lda #$00                 ; clear the pointer
        sta buf_ptr_tbl,x
        lda #$88                 ; $88 = active, last byte
        ldy cur_chan
        sta dir_load_flag        ; the directory is loaded: normal reading goes on in the buffer
        sta chan_flags,y
        lda iec_byte             ; return the first byte
        rts
dir_list_line_end_of_directory   ; no more entries
        bit dir_mode             ; partition listing has no BLOCKS FREE line
        bpl dir_list_line_emit_blocks_free
        jsr chan_put_byte
        dec buf_ptr_tbl,x
        dec buf_ptr_tbl,x
        jmp dir_list_line_write_end_marker
dir_list_line_emit_blocks_free   ; BLOCKS FREE. line
        lda blocks_free_lo
        jsr chan_put_byte
        lda blocks_free_hi
        jsr chan_put_byte
        jsr dir_emit_line
dir_list_line_write_end_marker   ; end of program: three zero bytes
        dec buf_ptr_tbl,x
        dec buf_ptr_tbl,x
        lda #$00
        jsr chan_put_byte
        jsr chan_put_byte
        jsr chan_put_byte
        lda buf_ptr_tbl,x        ; pointer to last byte
        sec
        sbc #$01
        ldy cur_chan
        sta chan_last,y
        jmp dir_list_line_finish_listing

; --- dir_emit_line: Send the directory line buffer to the channel
; Put the 27 bytes of the line buffer into the channel buffer.
dir_emit_line
        ldy #$00
dir_emit_emit_loop
        lda dir_line,y
        jsr chan_put_byte
        iny
        cpy #$1B
        bne dir_emit_emit_loop
        rts

; --- dir_trim_line: Trim the directory line (long listing)
; Long listing: remove trailing spaces and pad the line, then add the date fields. The name
; area is widened so dates fit; the number of lines per block is limited.
dir_trim_line
        lda #$1F
        sta dir_col
dir_trim_trim_trailing_spaces_loop ; remove trailing spaces
        dec buf_ptr_tbl,x
        dec dir_col
dir_trim_check_trailing_char
        lda (buf_ptr_tbl,x)
        cmp #$20
        beq dir_trim_trim_trailing_spaces_loop
        bit dir_mode_ext         ; extended listing?
        bmi dir_trim_extended_line
        dec buf_ptr_tbl,x
        dec dir_col
        cmp #$3C
        beq dir_trim_check_trailing_char
        bne dir_trim_add_date_fields
dir_trim_extended_line           ; extended: pad with two spaces
        jsr dir_char_out
        cmp #$3C
        beq dir_trim_second_space
        jsr dir_space_out
dir_trim_second_space
        jsr dir_space_out
dir_trim_add_date_fields
        jsr dir_date_fields      ; append the date and time
dir_trim_pad_to_width            ; pad out to the full width
        lda #$29                 ; normal width $29, extended $3F
        bit dir_mode_ext
        bpl compare_width
        lda #$3F
compare_width
        cmp dir_col
        beq dir_trim_count_line
        lda #$01
        jsr dir_char_out
        jmp dir_trim_pad_to_width
dir_trim_count_line
        inc dir_line_flag        ; count the lines in this block
        lda #$06                 ; 6 lines per block normally, 4 when extended
        bit dir_mode_ext
        bpl dir_trim_check_line_limit
        lda #$04
dir_trim_check_line_limit
        cmp dir_line_flag
        bne dir_trim_done
dir_trim_fill_rest_of_block      ; block full: fill the rest with zeros
        lda #$01
        jsr chan_put_byte
        bne dir_trim_fill_rest_of_block
        dec buf_ptr_tbl,x
dir_trim_done
        rts

; --- dir_date_fields: Build date/time text for the long listing
; Append the date and time to a long listing line: " mm/dd/yy hh:mm AM" (extended: with "M").
dir_date_fields
        ldy #$01
dir_date_date_field_loop         ; month and day, then the year
        jsr dir_date_one
        iny
        cpy #$03
        bne dir_date_check_field_limit
        bit dir_mode_ext         ; extended listing also shows the year first
        bpl dir_date_check_field_limit
        ldy #$00
        jsr dir_date_one
        jsr dir_space_out
        jsr dir_space_out
        ldy #$03
dir_date_check_field_limit
        cpy #$05
        bcc dir_date_date_field_loop
        lda #$20
        jsr dir_char_out
        lda #$41                 ; 'A' or 'P'
        bit ts_min+1
        bpl dir_date_put_am_pm
        lda #$50
dir_date_put_am_pm
        jsr dir_char_out
        bit dir_mode_ext
        bpl dir_date_done
        lda #$4D
        jsr dir_char_out
dir_date_done
        rts

; --- dir_date_one: Format one date/time field
; Output the separator for field Y and the two digits of that field.
dir_date_one
        lda date_template,y
        jsr dir_char_out
        lda ts_year,y
        jsr bin_to_dec
        pha
        lda tmp_a
        jsr dir_digit_out
        pla

; --- dir_digit_out: Output a digit character
; Output a digit (A + $30), a space, or any character A to the directory line.
dir_digit_out
        ora #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- dir_space_out: Output a space
dir_space_out
        lda #$20

; --- dir_char_out: Output a character to the directory channel and count it
dir_char_out
        jsr chan_put_byte
        inc dir_col
        rts
; --- date_template: Date/time separators ('/ / .')
date_template
        !text "/ / ."                   ; $C677

; --- dir_get_free: Get the free block count of the current partition
; Free blocks of the current partition (from the BAM slot) into blocks_free_lo/hi.
dir_get_free
        txa
        pha
        tya
        pha
        jsr bam_check_valid
        lda bam_free_lo,x
        sta blocks_free_lo
        lda bam_free_hi,x
        sta blocks_free_hi
        pla
        tay
        pla
        tax
        rts
; --- cmd_open_file: OPEN: parse the file name and open the file
; OPEN with a file name: the command channel buffer holds the name and optional mode, as in
; OPEN 2,8,2,"0:NAME,S,W". Handles "*" (last file), "$" (directory), "#" (direct) and files.
cmd_open_file
        lda cur_sa               ; secondary address of the OPEN
        sta tmp_cmd_char
        jsr trim_command         ; clean the name
        stx cmd_class
        ldx cmd_buf              ; first character of the name
        lda tmp_cmd_char
        bne open_file_test_directory_name ; SA 0 is LOAD
        cpx #$2A                 ; '*' = load the last file used
        bne open_file_test_directory_name
        jsr bam_find_slot        ; BAM slot holds the last file's track/sector (bam_aux)
        lda bam_aux,x
        beq open_file_star_without_last_file ; no last file yet
        sta cur_track
        lda bam_aux+16,x
        sta cur_sector
        lda cur_part
        sta spec_part
        lda #$02
        sta spec_type
        jsr led_on
        jsr open_read_chan       ; open it for reading
        lda #$04
open_file_set_state_and_done
        ldx cur_chan
        sta chan_state,y
        jmp cmd_complete
open_file_test_directory_name    ; '$' = directory
        cpx #$24
        bne open_file_test_direct_channel
        lda tmp_cmd_char         ; SA 0 gives a listing as a BASIC program
        bne open_file_open_dir_as_file
        jmp open_directory_listing ; SA 0: LOAD "$" gives a directory listing as a BASIC program
open_file_open_dir_as_file
        jsr find_colon           ; directory with a path or partition
        bne open_file_dir_path_given
        jsr strip_partition_arg
        jmp open_file_open_dir_chain
open_file_dir_path_given
        dey
        dey
        sty name_start           ; name starts before the colon
        jsr resolve_specs
        lda #$00
        jsr change_directory
open_file_open_dir_chain
        lda hdr_track
        sta cur_track
        lda hdr_sector
        sta cur_sector
        jsr open_read_chan
        lda #$02
        jmp open_file_set_state_and_done
open_file_test_direct_channel
        cpx #$23                 ; '#' = direct access channel
        bne open_file_parse_file_name
        jmp open_direct_chan
open_file_star_without_last_file ; "*" with no last file: start in this partition
        lda #$02
        sta file_type_chr
        jsr init_partition
open_file_parse_file_name
        jsr find_colon           ; find the colon in the file name
        bne open_file_colon_found
        ldx #$00                 ; no colon: name starts at the beginning
        beq open_file_resolve_file_name
open_file_colon_found
        txa
        beq open_file_skip_colon
        lda #$30                 ; error 30 SYNTAX ERROR
        jmp dos_error_00
open_file_skip_colon
        dey
        beq open_file_resolve_file_name
        dey
open_file_resolve_file_name
        sty name_start           ; name starts here
        lda #$8D                 ; name runs up to the end of the line (shifted CR)
        jsr find_char
        inx
        stx file_count
        jsr resolve_specs        ; resolve partition and path of the spec
        jsr reset_dir_search
        jsr find_entry_next_part ; look for the file in the directory
        ldx #$00
        stx rel_rec_len          ; clear: record length, access mode, type
        stx rw_mode
        stx file_type
        inx
        cpx file_idx             ; file_idx is the number of parameters after the name: type and mode letters
        bcs open_file_set_access_mode
        jsr parse_type_mode      ; first letter = type or mode
        inx
        cpx file_idx
        bcs open_file_set_access_mode
        cpy #$04                 ; ".." second spec is a REL record length when the type is REL
        beq open_file_rel_record_length
        jsr parse_type_mode      ; second letter
open_file_set_access_mode
        ldx tmp_cmd_char         ; the secondary address decides the access
        stx cur_sa
        cpx #$02                 ; SA 0 = read, SA 1 = write, others come from the mode
        bcs open_file_default_file_type
        stx rw_mode
        lda file_type
        bne open_file_check_mode
        lda #$02                 ; default type PRG
        sta file_type
open_file_default_file_type
        lda file_type
        bne open_file_check_mode
        lda spec_type            ; else use the type found in the directory
        and #$07
        sta file_type
        lda spec_trk             ; not found: SEQ
        bne open_file_check_mode
        lda #$01
        sta file_type
open_file_check_mode
        lda rw_mode              ; write mode?
        cmp #$01
        beq open_file_write_mode
        jmp open_file_read_or_append_mode
open_file_rel_record_length
        ldy name_start,x         ; the record length byte follows the type letter
        lda cmd_buf,y
        sta rel_rec_len
        lda spec_trk             ; file does not exist: write it (create REL)
        bne open_file_set_access_mode
        lda #$01
        sta rw_mode
        bne open_file_set_access_mode
open_file_write_mode             ; write mode: does the file exist?
        lda spec_type
        and #$80                 ; bit 7: wildcards used
        tax
        bne open_file_entry_exists
        lda #$20                 ; bit 5: a replacement is pending (splat file)
        bit spec_type
        beq open_file_check_existing_entry
        jsr entry_clear          ; remove the unfinished file
        jmp rel_reclen_create_new_file
open_file_check_existing_entry
        lda spec_trk             ; file not found: create it
        bne open_file_entry_exists
        jmp rel_reclen_create_new_file
open_file_entry_exists
        lda cmd_buf              ; "@0:NAME" means replace the file
        cmp #$40
        beq open_file_replace_existing
        txa                      ; wildcards in the name not allowed
        bne open_file_err_invalid_filename
        lda #$63                 ; error 63 FILE EXISTS
        jmp dos_error_00
open_file_err_invalid_filename
        lda #$33                 ; error 33 SYNTAX ERROR (invalid file name)
        jmp dos_error_00
open_file_replace_existing
        lda spec_type            ; replace: the type must be the same
        and #$07
        cmp file_type
        bne open_file_err_type_mismatch
        cmp #$04                 ; REL files can not be replaced
        beq open_file_err_type_mismatch
        jsr open_write_chan_a    ; open the new file on the write channel
        lda cur_chan
        sta job_flag_df+1        ; remember the new channel
        lda #$11                 ; channel 17 holds the old directory entry
        sta cur_sa
        jsr get_chan_for_sa
        lda ent_offset
        jsr chan_set_ptr
        ldy #$00                 ; mark the entry with bit 5: replacement in progress
        lda (dir_ptr),y
        ora #$20
        sta (dir_ptr),y
        ldy #$1A                 ; new first block goes into the entry bytes $1A/$1B until the file is closed
        lda cur_track
        sta (dir_ptr),y
        iny
        lda cur_sector
        sta (dir_ptr),y
        ldx job_flag_df+1        ; the new file's channel remembers the entry location
        lda spec_aux1
        sta chan_dir_track,x
        lda spec_aux2
        sta chan_dir_sector,x
        lda spec_aux3
        sta chan_dir_index,x
        jsr ts_from_chan
        jsr write_chan_buf
        jmp rel_reclen_finish_open
open_file_read_or_append_mode    ; read or append mode: the file must exist
        lda spec_trk
        bne open_file_check_write_open
        lda #$62                 ; error 62 FILE NOT FOUND
        jmp dos_error_00
open_file_check_write_open
        lda rw_mode              ; read mode with a replacement pending?
        cmp #$03
        beq open_file_check_file_type
        lda #$20
        bit spec_type
        beq open_file_check_file_type
        lda #$60                 ; error 60 WRITE FILE OPEN
        jmp dos_error_00
open_file_check_file_type
        lda spec_type            ; check the type
        and #$07
        cmp file_type
        beq open_file_open_existing
open_file_err_type_mismatch
        lda #$64                 ; error 64 FILE TYPE MISMATCH
        jmp dos_error_00
open_file_open_existing
        ldy #$00
        sty file_cur
        ldx rw_mode              ; append?
        cpx #$02
        bne open_file_after_append_prep
        cmp #$04                 ; REL files can not be appended
        beq open_file_err_type_mismatch
        lda (dir_ptr),y          ; remove the closed flag while appending
        and #$4F
        sta (dir_ptr),y
        lda cur_sa
        pha
        lda #$11
        sta cur_sa
        jsr ts_from_chan
        jsr write_chan_buf
        pla
        sta cur_sa
open_file_after_append_prep
        jsr open_existing_file_chan
        lda rw_mode
        cmp #$02
        bne rel_reclen_finish_open
        jsr file_read_seek_end   ; position at the end of the file
        jmp cmd_complete

; --- open_existing_file_chan: Read the REL side-sector/record-length fields of the entry and open the existing file for reading
; Open an existing file for reading. REL files also get their side sector and record length
; from the entry; error 50 if the record length in the command differs.
open_existing_file_chan
        ldy #$13                 ; entry offset $13/$14 = first side sector
        lda (dir_ptr),y
        sta rel_ss_track
        iny
        lda (dir_ptr),y
        sta rel_ss_sector
        iny                      ; entry offset $15 = record length
        lda (dir_ptr),y
        ldx rel_rec_len
        sta rel_rec_len
        txa
        beq rel_reclen_open_for_read
        cmp rel_rec_len
        beq rel_reclen_open_for_read
        lda #$50                 ; error 50 RECORD NOT PRESENT (different record length)
        jsr dos_error_00
rel_reclen_open_for_read
        ldx file_cur             ; first block of the file from the spec
        lda spec_trk,x
        sta cur_track
        lda spec_sec,x
        sta cur_sector
        jsr open_read_chan       ; open it
        ldy cur_chan
        ldx file_cur
        lda spec_aux1,x          ; remember the entry location for the close
        sta chan_dir_track,y
        lda spec_aux2,x
        sta chan_dir_sector,y
        lda spec_aux3,x
        sta chan_dir_index,y
        rts
; Create a new file: open a write channel and add the directory entry.
rel_reclen_create_new_file
        jsr open_write_chan_a
        jsr dir_add_entry
rel_reclen_finish_open
        lda cur_sa               ; channels 0 and 1 (LOAD and SAVE) update the "last file" for '*'
        cmp #$02
        bcs open_file_done
        jsr ts_from_buf
        jsr bam_find_slot        ; BAM slot holds the last file
        lda cur_track
        sta bam_aux,x
        lda cur_sector
        sta bam_aux+16,x
open_file_done
        jmp cmd_complete

; --- parse_type_mode: Parse file type and R/W/A/M mode letters
; Look at the letters after the file name: type D S P U L C, mode R W A M. rw_mode and
; file_type are set.
parse_type_mode
        ldy name_start,x
        lda cmd_buf,y
        ldy #$04
parse_type_mode_mode_loop
        dey
        bmi parse_type_mode_type_setup
        cmp rw_mode_chars,y
        bne parse_type_mode_mode_loop
        sty rw_mode
parse_type_mode_type_setup
        ldy #$06
parse_type_mode_type_loop
        dey
        bmi parse_type_mode_done
        cmp ftype_cmd_chars,y
        bne parse_type_mode_type_loop
        sty file_type
parse_type_mode_done
        rts
; --- rw_mode_chars: File access mode letters 'RWAM'
rw_mode_chars
        !text "RWAM"                    ; $C91F
; --- ftype_cmd_chars: File type letters 'DSPULC'
ftype_cmd_chars
        !text "DSPULC"                  ; $C923

; --- file_read_seek_end: Seek to the end of a sequential file for append
; Append: follow the chain to the last block and point at the end of the data.
file_read_seek_end
        jsr read_link_from_buf
        lda cur_track
        beq seek_end_reached_last_block ; last block reached
        jsr chain_read_first
        jmp file_read_seek_end
seek_end_reached_last_block
        ldx cur_chan
        lda chan_blk_lo,x        ; count the last block back out of the block count
        bne seek_end_adjust_block_count
        dec chan_blk_hi,x
seek_end_adjust_block_count
        dec chan_blk_lo,x
        ldx cur_sector           ; sector byte of the last block = last used byte
        inx
        txa                      ; a full block (offset wrapped to 0): start a new block
        bne seek_end_set_append_pointer
        lda #$00
        jsr chan_set_ptr
        jsr listen_flush_block   ; flush the full block
        lda #$02
seek_end_set_append_pointer
        jsr chan_set_ptr         ; position the pointer
        ldx cur_chan
        lda #$01                 ; write channel
        sta chan_flags,x
        lda #$80
        ora cur_chan
        ldx cur_sa
        sta sa_chan,x
        rts
; LOAD "$": make a directory listing. "$0:pat" selects partition and pattern, "$=T" is the long
; time listing, "$=P" the partition listing.
open_directory_listing
        lda #$0C                 ; class $0C
        sta cmd_class
        ldy #$01
        sty dir_mode             ; dir_mode b0 set
        ldx cmd_len
        dex                      ; "$" alone: default listing
        beq dir_listing_default_spec_all
        jsr find_separator
        beq dir_listing_parse_dir_spec
        ldy #$01
        lda cmd_buf+1            ; "$=": mode letters follow
        cmp #$3D
        bne dir_listing_skip_partition_digits_setup
        lda cmd_buf+2
        cmp #$54                 ; 'T' time listing
        beq dir_listing_mode_t_or_p
        cmp #$50                 ; 'P' partition listing
        bne dir_listing_skip_partition_digits_setup
dir_listing_mode_t_or_p
        ldy #$03                 ; mode 3
        sty dir_mode
        cpy cmd_len
        beq dir_listing_default_spec_all
dir_listing_skip_partition_digits_setup
        dey
dir_listing_skip_partition_digits_loop
        iny
        jsr is_digit_or_sep
        beq dir_listing_skip_partition_digits_loop
        cpy cmd_len
        bne dir_listing_parse_dir_spec
        ldy dir_mode
        jsr parse_partition_num
dir_listing_default_spec_all     ; "$" with no pattern: list everything ("*") in the current partition
        lda cur_part
        sta spec_part
        inc file_idx
        inc file_count
        ldy dir_mode
        lda #$2A                 ; patch the pattern "*" into the command
        sta cmd_buf,y
        sty name_start
        sty name_end_tbl
        iny
        sty cmd_len
        sty name_start+1
        lda #$80                 ; spec_type b7: wildcard
        sta spec_type
        bmi dir_listing_parse_dir_options
dir_listing_parse_dir_spec       ; "$0:pattern" form: separate the partition and the pattern
        jsr find_colon
        bne dir_listing_set_name_start
        jsr clear_parse_state
        ldy dir_mode
        iny
        iny
dir_listing_set_name_start
        dey
        dey
        sty name_start
        jsr parse_spec_equal     ; parse the pattern and resolve it for reading
        jsr resolve_specs_ro
dir_listing_parse_dir_options    ; "$=" options: P partition listing, T time listing with options
        lda cmd_buf+1
        cmp #$3D
        bne dir_listing_normal_listing_mode
        lda cmd_buf+2
        cmp #$50
        beq dir_listing_partition_listing_mode ; 'P'
        cmp #$54
        bne dir_listing_normal_listing_mode
        lda #$40                 ; dir_mode = $40: time listing
        sta dir_mode
        lsr dir_mode_ext         ; clear the extended flag
        ldy file_idx
dir_listing_option_loop          ; options are given as specs: "<date" before, ">date" after, "L" long, "N" no dates
        cpy file_count
        bcs dir_listing_select_partition_for_listing
        ldx name_start,y
        lda cmd_buf,x
        cmp #$3C                 ; '<' files older than the date
        bne dir_listing_test_after_date
        ror filter_flags         ; filter_flags b7
        clc
        jsr parse_timestamp      ; parse the date after the '<'
dir_listing_test_after_date
        cmp #$3E                 ; '>' files newer than the date
        bne dir_listing_test_long_flag
        ror filter_flags2
        sec
        jsr parse_timestamp
dir_listing_test_long_flag
        cmp #$4C                 ; 'L' = long (extended) listing
        bne dir_listing_test_no_date_flag
        ror dir_mode_ext
dir_listing_test_no_date_flag
        cmp #$4E                 ; 'N' = no date columns
        bne dir_listing_next_option
        lda #$00
        sta dir_mode
dir_listing_next_option
        iny
        bne dir_listing_option_loop
        beq dir_listing_select_partition_for_listing
dir_listing_partition_listing_mode
        lda #$80                 ; $80 = partition listing
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
dir_listing_normal_listing_mode
        lda #$00
        sta dir_mode
dir_listing_select_partition_for_listing
        bit dir_mode             ; partition listing: select partition 0 (the system)
        bpl dir_listing_set_type_filter
        lda #$00
        tay
dir_listing_clear_spec_parts_loop
        sta spec_part,y
        iny
        cpy file_idx
        bcc dir_listing_clear_spec_parts_loop
        jsr select_partition
dir_listing_set_type_filter
        lda #$00
        sta file_type_chr
        ldy file_idx
        cpy file_count
        beq dir_listing_start_listing
        jsr type_filter_from_spec
dir_listing_start_listing
        jsr reset_dir_search     ; go to the start of the directory
        lda #$00
        jsr change_directory
        jsr dir_header_line      ; header line of the listing
        jsr find_entry_init      ; look for the first matching entry
        jsr dir_list_start       ; build the start of the BASIC program
        jsr chan_get_byte        ; first data byte goes to the channel byte register
        ldx cur_chan
        sta chan_byte,x
        lda #$04                 ; channel type 1 (read), SA 0 gets its first byte already
        sta chan_state,x
        lda #$00
        sta cmdbuf_ptr
        rts

; --- parse_timestamp: Parse the date/time in the command (mm/dd/yy hh:mm)
; Parse a date in the command: "mm/dd/yy hh:mm AM|PM" fields at fixed offsets. The result goes
; to ts_year..ts_min and is copied to the filter date: C = 0 for "<" (rtc_buf+8) and C = 1 for
; ">" (rtc_buf+13).
parse_timestamp
        pha
        tya
        pha
        lda #$04
        bcc parse_ts_after_flag_offset
        lda #$09
parse_ts_after_flag_offset
        pha
        ldy #$00
        stx tmp_b                ; X = start of the date text
parse_ts_field_loop
        ldx tmp_b
        txa
        clc
        adc ts_field_offsets,y   ; add the offset of each field
        tax
        jsr dec2_to_bin          ; two decimal digits to binary
        sta ts_year,y
        iny
        cpy #$05
        bcc parse_ts_field_loop
        lda ts_hour              ; 12 AM is hour 0
        sbc #$0C
        bne parse_ts_check_am_pm
        sta ts_hour
parse_ts_check_am_pm
        inx
        inx
        lda cmd_buf,x            ; the character after the time: 'A' or 'P'
        and #$7F
        cmp #$41
        beq parse_ts_store_filter_date
        lda ts_hour              ; PM: add 12 hours
        clc
        adc #$0C
        sta ts_hour
parse_ts_store_filter_date
        pla                      ; copy the five fields into the filter date
        tay
        ldx #$04
parse_ts_copy_date_loop
        lda ts_year,x
        sta rtc_buf+8,y
        dey
        dex
        bpl parse_ts_copy_date_loop
        pla
        tay
        pla
        rts

; --- dec2_to_bin: Convert two decimal digits at ($0200),X to binary
; Two decimal digits at cmd_buf,X into binary (A = tens * 10 + units).
dec2_to_bin
        lda cmd_buf,x
        and #$0F
        asl
        sta tmp_a
        asl
        asl
        adc tmp_a
        sta tmp_a
        inx
        lda cmd_buf,x
        and #$0F
        adc tmp_a
        rts
; --- ts_field_offsets: Offsets of the date/time fields in the command
; Offsets of year, month, day, hour, minute in "mm/dd/yy hh:mm" (year is at 7).
ts_field_offsets
        !byte $07,$01,$04,$0A,$0D       ; $CAF2

; --- open_read_chan: Open a channel for reading (sets buffers, type)
; Open channel A for reading the file at (cur_track,cur_sector). Reads the first block, sets
; up the buffers. For REL files the side sector is read too.
open_read_chan
        lda #$01
        jsr alloc_chan           ; allocate a channel and buffer
        jsr chan_bufs_init       ; pointers start at offset 2 (after the link bytes)
        lda file_type
        pha
        asl                      ; file type, shifted into the channel state
        sta chan_state,x
        jsr read_link_bytes      ; read the link bytes of the first block
        ldx cur_chan
        lda cur_track
        bne open_read_chan_check_rel_type ; link track 0: the file has only one block
        lda cur_sector
        sta chan_last,x          ; then the sector byte is the last used byte
open_read_chan_check_rel_type
        pla
        cmp #$04                 ; REL file?
        bne open_read_chan_prime_first_byte
        ldy cur_sa               ; mark the SA as REL (bit 6)
        lda sa_chan,y
        ora #$40
        sta sa_chan,y
        lda rel_rec_len          ; record length
        sta chan_recsize,x
        jsr buf_alloc            ; a second buffer for the side sector
        bpl open_read_chan_rel_buffer_allocated
        jmp no_buffer_error
open_read_chan_rel_buffer_allocated
        ldx cur_chan
        sta chan_dirbuf,x
        ldy rel_ss_track         ; read the first side sector
        sty cur_track
        ldy rel_ss_sector
        sty cur_sector
        jsr ts_to_job
        jsr job_read_dir_buf
        jsr job_wait
        lda #$02                 ; offset 2
        jsr set_ent_ptr
        ldx cur_chan
        ldy #$00
        lda (dir_ptr),y          ; first byte of the side sector
        sec                      ; $FE = the current native side sector layout (256-byte)
        sbc #$FE
        beq open_read_chan_store_rel_flags
        lda #$20                 ; else the old CBM layout (flag $20)
open_read_chan_store_rel_flags
        sta chan_rel_flags,x
        bne rel_open_finish
        lda rel_ss_track         ; remember the side sector location
        sta chan_ss_trk,x
        lda rel_ss_sector
        sta chan_ss_sec,x
        lda #$FF                 ; $FF = nothing cached
        sta chan_ss_cache,x
rel_open_finish
        ldx cur_chan
        lda #$02                 ; REL: record end pointer
        sta chan_rel_end,x
        lda #$00                 ; position at the first record
        jsr chan_set_ptr
        jsr rel_next_rec_byte    ; read the first record into the buffer
        jmp ts_from_buf
open_read_chan_prime_first_byte
        jsr talk_cmd_byte        ; SEQ/PRG: prefetch the first byte
        ldx cur_chan
        sta chan_byte,x
        lda #$88                 ; $88 = active, with data
        sta chan_flags,x
        rts

; --- chan_bufs_init: Initialise the channel's buffer pointers
; Set the buffer pointers of the channel to 2 (after the link bytes) and clear its counters.
chan_bufs_init
        ldx cur_chan
        lda chan_buf,x
        asl
        bmi chan_bufs_init_second_buffer ; bit 7 set: spare buffer not used
        tay
        lda #$02
        sta+2 buf_ptr_tbl,y
chan_bufs_init_second_buffer
        lda chan_buf2,x
        ora #$80
        sta chan_buf2,x
        asl
        bmi chan_bufs_init_clear_counters
        tay
        lda #$02
        sta+2 buf_ptr_tbl,y
chan_bufs_init_clear_counters
        lda #$00
        sta chan_last,x
        sta chan_blk_lo,x
        sta chan_blk_hi,x
        rts

; --- open_write_chan_a: Open the write channel on the directory track
; Open a write channel on a freshly allocated first block.
open_write_chan_a
        jsr alloc_first_block

; --- open_write_chan: Open a channel for writing
; Open a write channel for the track/sector in cur_track/cur_sector.
open_write_chan
        lda #$01
        jsr alloc_chan_rd
        jsr ts_to_job_chan
        jsr chan_bufs_init
        ldx cur_chan
        lda file_type
        pha
        asl
        sta chan_state,x
        pla
        cmp #$04
        beq open_write_chan_rel_write_setup
        lda #$01                 ; flag 1 = write channel
        sta chan_flags,x
        rts
open_write_chan_rel_write_setup  ; REL file: allocate the side sector and set up the structures
        ldy cur_sa
        lda sa_chan,y
        and #$3F
        ora #$40
        sta sa_chan,y
        lda rel_rec_len
        sta chan_recsize,x
        jsr buf_alloc
        bpl open_write_chan_rel_buffer_ok
        jmp no_buffer_error
open_write_chan_rel_buffer_ok
        pha                      ; keep the buffer number of the side sector
        jsr get_part_type        ; native and 1541-style use different side sector layouts
        cmp #$01
        beq open_write_chan_side_flags_zero
        cmp #$04
        bcc open_write_chan_side_flags_set
open_write_chan_side_flags_zero
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
open_write_chan_side_flags_set
        lda #$20                 ; $20: old layout flag
        ldx cur_chan
        sta chan_rel_flags,x
        pla
        sta chan_dirbuf,x
        jsr clear_buf
        jsr alloc_next_block     ; a block for the side sector
        lda cur_track
        sta rel_ss_track
        lda cur_sector
        sta rel_ss_sector
        ldx cur_chan
        lda chan_dirbuf,x
        jsr ts_to_job
        lda #$00                 ; first byte = 0: link track
        jsr put_ent_ptr
        lda #$00
        jsr chan_put_byte_pha
        lda #$11                 ; link sector = $11
        jsr chan_put_byte_pha
        lda #$00                 ; side sector number 0
        jsr chan_put_byte_pha
        lda rel_rec_len          ; record length
        jsr chan_put_byte_pha
        lda cur_track            ; first side sector track/sector go into the list
        jsr chan_put_byte_pha
        lda cur_sector
        jsr chan_put_byte_pha
        lda #$10                 ; offset $10: list of side sector blocks
        jsr put_ent_ptr
        jsr ts_from_buf
        lda cur_track
        jsr chan_put_byte_pha
        lda cur_sector
        jsr chan_put_byte_pha
        jsr job_write_dir_buf         ; write the side sector
        jsr job_wait
        jsr rel_is_rel           ; REL?
        bne open_write_chan_rel_new_file_finish
        jsr write_first_block    ; native: write the first super side sector
open_write_chan_rel_new_file_finish
        lda #$02                 ; start of the data block
        jsr chan_set_ptr
        ldx cur_chan
        sec                      ; chan_rel_end = -record length: the first record starts at zero
        lda #$00
        sbc chan_recsize,x
        sta chan_rel_end,x
        jsr rel_new_record       ; new record
        jsr ent_put_end          ; update the directory entry's end pointer
        jsr job_write_chan_buf_clean
        jsr job_wait
        jsr bam_write_if_dirty
        jmp rel_open_finish

; --- write_first_block: Write the first block of a file
; Write the first super side sector of a native REL file ($FE layout).
write_first_block
        ldx cur_chan
        lda chan_dirbuf,x
        jsr clear_buf
        jsr put_ent_ptr
        lda rel_ss_track
        jsr chan_put_byte_pha
        lda rel_ss_sector
        jsr chan_put_byte_pha
        lda #$FE                 ; $FE = marker of the super side sector
        jsr chan_put_byte_pha
        lda rel_ss_track
        jsr chan_put_byte_pha
        lda rel_ss_sector
        jsr chan_put_byte_pha
        jsr alloc_next_block     ; a block for the first side sector
        ldx cur_chan
        lda cur_track
        sta chan_ss_trk,x
        sta rel_ss_track
        lda cur_sector
        sta chan_ss_sec,x
        sta rel_ss_sector
        lda #$FF                 ; nothing cached
        sta chan_ss_cache,x
        jsr ss_flush_write       ; write the side sector
        jmp ts_from_buf

; --- chan_put_byte_pha: Store a byte into the channel buffer (A kept)
; Store A in the channel's directory buffer (used by the REL setup code).
chan_put_byte_pha
        pha
        ldx cur_chan
        lda chan_dirbuf,x
        jmp chan_store_byte

; --- close_handler: CLOSE: close the channel and flush buffers
; CLOSE. SA 0 (load) just releases; SA 15 closes every channel; any other SA closes its channel.
close_handler
        lda cur_sa
        bne close_handler_close_one_channel ; SA 0?
        lda #$00
        sta dir_load_flag        ; a directory load is over
        jsr release_chan
close_handler_release_and_exit
        jmp release_dir_chans
close_handler_close_one_channel
        cmp #$0F                 ; CLOSE 15 closes all open files
        beq close_handler_close_all_channels
        jsr close_channel
        lda cur_sa
        cmp #$02
        bcc close_handler_release_and_exit
        lda pending_err          ; an error while closing?
        bne close_handler_pending_error_exit
close_handler_status_ok
        jmp cmd_status_ok
close_handler_pending_error_exit
        jmp cmd_status_set_release_dirs_exit
close_handler_close_all_channels
        lda #$0E                 ; from channel 14 down to 0
        sta cur_sa
close_handler_close_all_loop
        jsr close_channel
        dec cur_sa
        bpl close_handler_close_all_loop
        lda pending_err
        beq close_handler_status_ok
        bne close_handler_pending_error_exit

; --- close_channel: Close the channel for secondary address X
; Close the file open on the secondary address.
close_channel
        ldx cur_sa
        lda sa_chan,x
        cmp #$FF                 ; $FF = not open
        bne close_channel_channel_open
        rts
close_channel_channel_open
        and #$3F                 ; channel number
        sta cur_chan
        tax
        lda chan_part,x          ; its partition
        jsr select_partition
        jsr chan_get_type        ; channel type
        cmp #$07                 ; type 7 = direct access
        beq close_channel_write_bam
        cmp #$04                 ; REL file
        beq close_channel_close_rel
        jsr get_chan_for_sa_rd   ; a read channel needs only a release
        bcs close_channel_release
        jsr close_read_chan      ; a write channel: finish the file, then write the directory entry
        jsr close_update_dir
close_channel_write_bam
        jsr bam_write_if_loaded  ; write the BAM
close_channel_release
        jmp release_chan
close_channel_close_rel
        ; REL close: flush the record buffer, work out the file size in blocks from the side sectors
        ; and store it in the directory entry.
        jsr flush_if_dirty
        jsr swap_chan_bufs
        jsr rel_first_side       ; find the first side sector
        ldx rel_side_no
        stx tmp_e
        jsr rel_is_rel           ; which layout?
        beq close_rel_size_from_side_sectors
        inc tmp_e
        lda #$00
        sta tmp_b
        sta tmp_c
        lda rel_side_off         ; offset of the end of the used part of the last side sector
        sec
        sbc #$0E
        sta tmp_d
        jsr rel_add_blocks       ; add up the blocks for the full side sectors
        ldx cur_chan
        lda tmp_b
        sta chan_blk_lo,x
        lda tmp_c
        sta chan_blk_hi,x
close_rel_update_dir_if_written
        lda #$40
        jsr chan_state_test
        beq close_rel_release
        jsr close_update_dir
close_rel_release
        jmp release_chan
close_rel_size_from_side_sectors
        lda rel_side_off
        sec
        sbc #$0E
        sta tmp_d
        lda rel_ss_idx
        sta tmp_88
        jsr rel_calc_size
        ldx #$00
        lda #$02
        jsr rel_add_const
        ldx cur_chan
        lda calc_a
        sta chan_blk_lo,x
        lda calc_b
        sta chan_blk_hi,x
        jmp close_rel_update_dir_if_written

; --- close_read_chan: Finish a read channel
; Finish a read channel: for an unused channel the first byte becomes CR; the pointer of the
; last block is stored in the buffer link and the buffer written back (used by U and B).
close_read_chan
        ldx cur_chan
        lda chan_blk_lo,x
        ora chan_blk_hi,x
        bne close_read_check_pointer
        jsr chan_get_ptr
        cmp #$02
        bne close_read_check_pointer
        lda #$0D
        jsr chan_put_byte
close_read_check_pointer
        jsr chan_get_ptr
        cmp #$02
        bne close_read_write_last_pointer
        ldx cur_chan
        lda chan_blk_lo,x
        bne close_read_dec_block_lo
        dec chan_blk_hi,x
close_read_dec_block_lo
        dec chan_blk_lo,x
        lda #$00
close_read_write_last_pointer
        sec
        sbc #$01
        pha
        lda #$00
        jsr chan_set_ptr
        jsr chan_put_byte
        pla
        jsr chan_put_byte
        jsr chan_write_job
        jmp job_wait

; --- close_update_dir: Update the directory entry of the closed file
; Update the directory entry of a closed write channel: set the "closed" bit, finish a
; replace (the new first block takes the place of the old chain, which is freed), store the
; block count and the time stamp, and write the directory block.
close_update_dir
        lda cur_sa
        pha
        ldx cur_chan
        lda chan_dir_track,x     ; where the entry lives
        sta cur_track
        lda chan_dir_sector,x
        sta cur_sector
        jsr read_cur_blk         ; read that directory block
        ldy cur_chan
        ldx chan_dir_index,y
        lda dirblk_buf,x
        and #$20                 ; bit 5: replacement pending
        bne close_update_finish_replace
        lda #$80                 ; bit 7 = closed
        ora dirblk_buf,x
        and #$8F                 ; keep the type and lock bits
        sta dirblk_buf,x
        bne close_update_update_block_count
close_update_finish_replace
        lda chan_state,y         ; channel state 8 = still being written
        and #$0F
        cmp #$08
        beq close_update_update_block_count
        lda dirblk_buf,x         ; clear the pending flag
        and #$8F
        sta dirblk_buf,x
        lda dirblk_buf1,x        ; new first block (entry bytes 1, 2) is the old chain...
        sta cur_track
        lda dirblk_buf+2,x
        sta cur_sector
        lda dirblk_buf+26,x      ; ...and the new chain is at offset $1A/$1B
        bne close_update_install_new_chain
        sta cur_track
        lda dirblk_buf+27,x
        sta cur_sector
        lda #$67                 ; error 67: no new chain recorded
        jmp jt_dos_error
close_update_install_new_chain
        sta dirblk_buf1,x        ; swap them: the entry now points at the new chain
        lda dirblk_buf+27,x
        sta dirblk_buf+2,x
        lda #$00
        sta dirblk_buf+26,x
        sta dirblk_buf+27,x
        jsr free_chain           ; free the old chain
close_update_update_block_count
        pla
        sta cur_sa
        jsr get_chan_for_sa_rd
        ldy cur_chan
        ldx chan_dir_index,y
        lda chan_blk_lo,y
        sta dirblk_buf+28,x      ; block count into the entry ($1C/$1D)
        lda chan_blk_hi,y
        sta dirblk_buf+29,x
        jsr rtc_format_ascii     ; time stamp into the entry
        ldy cur_chan
        lda chan_dir_track,y
        sta cur_track
        lda chan_dir_sector,y
        sta cur_sector
        jmp write_cur_blk        ; write the directory block

; --- get_next_byte: Fetch the next byte from the channel (sets EOI)
; Fetch the next byte of the source channel 17 into iec_byte, with EOI in eoi_flag.
get_next_byte
        lda #$11
        sta cur_sa
        jsr channel_read_byte
        sta iec_byte
        ldx cur_chan
        lda chan_flags,x
        and #$08
        sta eoi_flag
        bne get_next_byte_done
        jsr chan_get_type
        beq get_next_byte_done
        lda #$80
        jsr chan_state_set
get_next_byte_done
        rts

; --- channel_read_byte: Fetch a byte from the channel buffer
; Read a byte from the channel of the current SA (sequential or REL).
channel_read_byte
        jsr get_chan_for_sa
        jsr led_on
        jsr chan_get_type
        bne chan_read_byte_seq_byte
        jsr talk_rel_byte
        jmp chan_read_byte_return_byte
chan_read_byte_seq_byte
        jsr talk_seq_byte
chan_read_byte_return_byte
        ldx cur_chan
        lda chan_byte,x
        rts

; --- put_byte_to_dest: Write iec_byte to the destination channel ($12) with the writer for its channel type
; Write iec_byte to the destination channel with the writer for its type.
put_byte_to_dest
        ldx #$12
        stx cur_sa
        jsr get_chan_for_sa_rd
        jsr led_on
        jsr chan_get_type
        bcc put_dest_dispatch_writer
        lda #$20                 ; clear bit 5
        jsr chan_state_clear
put_dest_dispatch_writer
        lda cur_sa
        cmp #$0F
        bne put_dest_check_rel
        jmp listen_cmd_byte
put_dest_check_rel
        jsr chan_get_type
        bcs put_dest_rel_or_direct
        jmp listen_seq_byte
put_dest_rel_or_direct
        bne put_dest_direct
        jmp listen_rel_byte
put_dest_direct
        jmp listen_direct_byte

; --- chan_put_byte: Store byte A into the current channel buffer (advances pointer)
; Store A at the buffer pointer of the current channel and advance it. Error 61 if the
; channel has no buffer.
chan_put_byte
        pha
        jsr chan_cur_buf
        bpl chan_store_byte
        pla
        lda #$61
        jmp dos_error_00
chan_store_byte
        asl
        tax
        pla
        sta (buf_ptr_tbl,x)
        inc buf_ptr_tbl,x
        rts

; --- chan_get_byte: Fetch a byte from the channel buffer; $FF if end
chan_get_byte
        ; Fetch the next byte of the channel's buffer. At the limit chan_last the pointer is set to $FF.
        ldx cur_chan
        lda chan_buf,x
        bpl chan_get_use_second_buffer
        lda chan_buf2,x
chan_get_use_second_buffer
        and #$BF
        asl
        tax
        ldy cur_chan
        lda chan_last,y
        beq chan_get_no_limit
        lda (buf_ptr_tbl,x)      ; read the byte at the pointer
        pha
        lda buf_ptr_tbl,x
        cmp chan_last,y          ; reached the last byte of the file?
        bne chan_get_restore_and_advance
        lda #$FF                 ; then make the next increment wrap to 0
        sta buf_ptr_tbl,x
chan_get_restore_and_advance
        pla
        inc buf_ptr_tbl,x
        rts
chan_get_no_limit
        lda (buf_ptr_tbl,x)
        inc buf_ptr_tbl,x
        rts

; ---------------------------------------------------------------------------
; UNREACHABLE CODE ($CF2A-$CF4F, 38 bytes), no caller and no table entry. No counterpart in CMD HD BOOTROM v2.80
; and no reference from the JiffyDOS kernal.
; Writes a byte and, when the buffer page is full, chains the next block and writes the old one. The write
; paths that need this (the listen byte writers) already do the same steps themselves, so this looks like
; an earlier version of that sequence that was left in the ROM.
; ---------------------------------------------------------------------------
; --- chan_put_byte_next: Store a byte, allocate next block on overflow
; Store a byte; when the buffer page is full (Z) chain the next block and write the old one.
chan_put_byte_next
        jsr chan_put_byte
        beq chan_put_next_allocate_next
        rts
chan_put_next_allocate_next
        jsr alloc_next_block     ; new block
        lda #$00
        jsr chan_set_ptr
        lda cur_track            ; link bytes into the old block
        jsr chan_put_byte
        lda cur_sector
        jsr chan_put_byte
        jsr chan_write_job       ; write the old block (in the background)
        jsr swap_chan_bufs       ; switch to the other buffer
        jsr ts_to_job_chan
        lda #$02
        jmp chan_set_ptr

; --- rel_calc_position: REL: compute side-sector/record position
; REL: work out where a record is: side sector number (rel_side_no), offset in the side
; sector (rel_side_off), and the byte offset in the data block (rel_rec_off).
rel_calc_position
        jsr rel_calc_record      ; record number * record length = byte position
        jsr rel_div_254          ; /254 = data block number (remainder = offset in the block)
        lda rel_offset_lo
        sta rel_rec_off
        jsr rel_div_120          ; /120 = side sector number (120 pointers per side sector)
        inc rel_rec_off          ; skip the two link bytes
        inc rel_rec_off
        jsr rel_is_rel
        beq rel_calc_pos_native_side_layout ; native layout has a different side sector size
        lda calc_a
        sta rel_side_no
        lda rel_offset_lo
        asl
        clc
        adc #$10                 ; side sector entries start at offset $10 and are two bytes each
        sta rel_side_off
        rts
rel_calc_pos_native_side_layout
        lda rel_offset_lo
        asl
        clc
        adc #$10
        sta rel_side_off
        jsr rel_div_6            ; native side sectors hold 6 groups
        lda rel_offset_lo
        sta rel_side_no
        lda calc_a
        sta rel_ss_idx
        rts

; --- rel_calc_record: REL: position within a record
; REL: (record number - 1) * record length + current offset, as a 24 bit value.
rel_calc_record
        jsr calc_clear
        sta rel_offset_hi
        ldx cur_chan
        lda chan_blk_lo,x
        sta rel_offset_lo
        lda chan_blk_hi,x
        sta rel_offset_mid
        bne rel_calc_rec_adjust_for_zero_based ; record number 0 stays 0
        lda rel_offset_lo
        beq rel_calc_rec_load_record_size
rel_calc_rec_adjust_for_zero_based
        lda rel_offset_lo
        sec
        sbc #$01
        sta rel_offset_lo
        bcs rel_calc_rec_load_record_size
        dec rel_offset_mid
rel_calc_rec_load_record_size    ; record length
        lda chan_recsize,x
        sta tmp_a
rel_calc_rec_multiply_loop
        lsr tmp_a                ; shift-and-add multiply of the record number by the record length
        bcc rel_calc_rec_shift_step
        jsr calc_add
rel_calc_rec_shift_step
        jsr calc_shift1
        lda tmp_a
        bne rel_calc_rec_multiply_loop
        lda rel_rec_tmp          ; add the byte offset in the record
        clc
        adc calc_a
        sta calc_a
        bcc rel_calc_rec_done
        inc calc_b
        bne rel_calc_rec_done
        inc calc_c
rel_calc_rec_done
        rts

; --- rel_div_254: REL: divide by 254
; 24 bit divide by 254, 120 or 6 (A set before the common code). The quotient is in calc_a..c,
; the remainder in rel_offset_lo/mid.
rel_div_254
        lda #$FE
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- rel_div_120: REL: divide by 120
rel_div_120
        lda #$78
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- rel_div_6: REL: divide by 6
rel_div_6
        lda #$06
        sta tmp_a
        lda #$00
        sta rel_offset_lo
        sta rel_offset_mid
        ldx #$18                 ; 24 bits
rel_div_divide_bit_loop
        asl calc_a
        rol calc_b
        rol calc_c
        rol rel_offset_lo
        rol rel_offset_mid
        lda rel_offset_lo
        sec
        sbc tmp_a
        tay
        lda rel_offset_mid
        sbc #$00
        bcc rel_div_next_bit
        inc calc_a
        sta rel_offset_mid
        sty rel_offset_lo
rel_div_next_bit
        dex
        bne rel_div_divide_bit_loop
        rts

; --- calc_clear: Clear the 24-bit accumulator
; 24 bit arithmetic helpers used by the REL code. calc_a/b/c and rel_offset_lo/mid/hi are
; three-byte numbers in zero page.
calc_clear
        lda #$00
        sta calc_a
        sta calc_b
        sta calc_c
        rts

; UNREACHABLE: 3 byte helper that shifts the 24 bit value twice (JSR calc_shift1, then falls into it), never called.
; --- calc_shift2: Shift 24-bit value left twice
calc_shift2
        jsr calc_shift1

; --- calc_shift1: Shift 24-bit value left
calc_shift1
        clc
        rol rel_offset_lo
        rol rel_offset_mid
        rol rel_offset_hi
        rts

; --- calc_add: 24-bit add
calc_add
        clc
        ldx #$FD
calc_add_add_loop
        lda calc_sum,x
        adc $93,x
        sta calc_sum,x
        inx
        bne calc_add_add_loop
        rts

; --- ent_put_ts: Store track/sector in the directory entry
; Store the current track/sector at the entry in the channel's directory buffer.
ent_put_ts
        jsr ent_ptr
        lda cur_track
        sta (dir_ptr),y
        iny
        lda cur_sector
        sta (dir_ptr),y
        jmp rel_set_dirty

; --- ent_get_ts: Load track/sector from the directory entry
ent_get_ts
        jsr ent_ptr
        lda (dir_ptr),y
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        rts

; --- ent_put_end: Store end-of-file pointer in the entry
; Store the end-of-record pointer in the entry (offsets 0 and 1 hold the last pointer).
ent_put_end
        jsr ent_ptr
        lda #$00
        sta (dir_ptr),y
        iny
        ldx cur_chan
        lda chan_rel_end,x
        tax
        dex
        txa
        sta (dir_ptr),y
        rts

; --- ent_ptr: Set dir_ptr to the channel's buffer page
; Point dir_ptr at the start of the channel's buffer page.
ent_ptr
        jsr chan_cur_buf
        asl
        tax
        lda buf_ptr_tbl_hi,x
        sta dir_ptr_hi
        lda #$00
        sta dir_ptr
        ldy #$00
        rts

; --- copy_buf_bytes: Copy Y bytes between buffers
; Copy Y bytes from the buffer in A to the buffer in X (both 256 byte job buffers at $03xx).
copy_buf_bytes
        pha
        lda #$00
        sta tmp_a
        sta tmp_c
        tya
        clc
        adc #$03
        sta tmp_b
        txa
        clc
        adc #$03
        sta tmp_d
        pla
        tay
        dey
copy_buf_copy_loop
        lda (tmp_a),y
        sta (tmp_c),y
        dey
        bpl copy_buf_copy_loop
        rts

; --- clear_buf: Clear a 256-byte buffer
; Fill the 256 byte buffer number A with zeroes.
clear_buf
        tay
        clc
        adc #$03
        sta tmp_b
        lda #$00
        sta tmp_a
        tay
clear_buf_clear_loop
        sta (tmp_a),y
        iny
        bne clear_buf_clear_loop
        rts

; --- get_ent_byte: Read entry byte 2 (file type)
; Return byte 2 of the channel's directory buffer (the side sector number).
get_ent_byte
        lda #$00
        jsr set_ent_ptr
        ldy #$02
        lda (dir_ptr),y
        rts

; --- set_ent_ptr: Set dir_ptr to the channel's directory buffer + A
; Set dir_ptr to the start of the channel's second buffer (the side sector) + A.
set_ent_ptr
        sta dir_ptr
        ldx cur_chan
        lda chan_dirbuf,x
        tax
        clc
        adc #$03
        sta dir_ptr_hi
        rts

; --- put_ent_ptr: Store dir_ptr into the pointer table
; Set the buffer pointer of the channel's second buffer to A.
put_ent_ptr
        pha
        jsr set_ent_ptr
        pha
        txa
        asl
        tax
        pla
        sta buf_ptr_tbl_hi,x
        pla
        sta buf_ptr_tbl,x
        rts

; --- rel_next_side: REL: select the side sector for the record
; REL: make sure the side sector with the record's pointer is in the buffer. Returns V = 1 if
; the record has no side sector (yet), V = 0 and dir_ptr at the pointer if found.
rel_next_side
        jsr rel_locate           ; where is the record's pointer?
        bmi rel_next_side_no_side_sector ; N set: not found at all
        bvc rel_next_side_side_sector_found ; V clear: in the sector already loaded
        ldx cur_chan
        lda chan_dirbuf,x
        jsr rel_read_block       ; else load the right side sector
        jsr rel_locate
        bpl rel_next_side_side_sector_found
rel_next_side_no_side_sector
        jsr rel_first_side       ; no side sector: V = 1 ("bit bit_set_v" sets V)
        bit bit_set_v
        rts
rel_next_side_side_sector_found
        lda rel_side_off         ; point at the record's pointer (track, sector)
        jsr put_ent_ptr
        bit bit_clr_nv
        rts

; --- rel_read_block: REL: read a block of the file
; Read (or write, at the second entry) the block named by the two bytes at dir_ptr/Y.
rel_read_block
        sta cur_buf_idx          ; job number = buffer number
        lda #$80                 ; $80 = read job
        bne rel_read_block_issue_job
        sta cur_buf_idx          ; (write entry, unused)
        lda #$90
rel_read_block_issue_job
        sta job_cmd_tmp
        lda (dir_ptr),y          ; track and sector from the pointer
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        lda cur_buf_idx
        jsr ts_to_job            ; set up the job
        ldx cur_buf_idx
        jmp job_issue_and_wait   ; and run it

; --- rel_chan_to_ptr: REL: dir_ptr from the channel
; dir_ptr from the channel's side sector buffer.
rel_chan_to_ptr
        ldx cur_chan
        lda chan_dirbuf,x
        jmp chan_ptr_from_buffer
rel_add_blocks_add_120_loop      ; 120 pointers per side sector
        lda #$78
        jsr rel_add

; --- rel_add_blocks: REL: accumulate block counts
; Accumulate the number of blocks of the side sectors: X side sectors of 120 blocks each, then
; tmp_d/2 more.
rel_add_blocks
        dex
        bpl rel_add_blocks_add_120_loop
        lda tmp_d
        lsr
        jsr rel_add
        lda tmp_e

; --- rel_add: REL: add A to the running size
rel_add
        clc
        adc tmp_b
        sta tmp_b
        bcc rel_add_done
        inc tmp_c
rel_add_done
        rts

; --- rel_calc_size: REL: compute file size from side sectors
; REL: file size in blocks from the number of side sectors and data blocks.
rel_calc_size
        jsr calc_clear
        jsr rel_clear
        ldy tmp_88
rel_calc_size_side_sector_loop
        dey
        bmi rel_calc_size_after_side_sectors
        ldx #$02                 ; every full side sector adds $D6 + 2*256 blocks (121 data blocks + ...)
        lda #$D6
        jsr rel_add_const
        jmp rel_calc_size_side_sector_loop
rel_calc_size_after_side_sectors
        ldy tmp_e
rel_calc_size_data_block_loop
        dey
        bmi rel_calc_size_final_partial
        ldx #$00
        lda #$79                 ; every data block adds 121
        jsr rel_add_const
        jmp rel_calc_size_data_block_loop
rel_calc_size_final_partial
        lda tmp_d
        lsr
        ldx #$00
        jmp rel_add_const

; --- rel_clear: REL: zero the three-byte counter
; Zero the 24 bit counter.
rel_clear
        ldx #$00
        stx rel_offset_lo
        stx rel_offset_mid
        stx rel_offset_hi
        rts

; --- rel_add_const: REL: add a constant
; Add the 16 bit constant X:A to calc_sum.
rel_add_const
        stx rel_offset_mid
        sta rel_offset_lo
        jmp calc_add

; --- rel_locate: REL: locate the record
; REL: find the record's pointer. Result flags: N set = not found, V set = the side sector must
; be loaded, both clear = pointer is in the current side sector. Empty pointer: N only.
rel_locate
        jsr rel_is_rel           ; native layout uses cached side sectors
        bne rel_locate_check_current_side
        lda rel_ss_idx           ; side sector index
        jsr ss_select
        beq rel_locate_check_current_side
        bit bit_set_nv
        rts
rel_locate_check_current_side
        jsr get_ent_byte         ; side sector number of the sector in the buffer
        cmp rel_side_no
        bne rel_locate_check_super_side
        ldy rel_side_off         ; offset of the pointer
        lda (dir_ptr),y
        beq rel_locate_slot_empty ; no pointer yet: an empty slot
        bit bit_clr_nv
        rts
rel_locate_slot_empty
        bit bit_set_n
        rts
rel_locate_check_super_side
        lda rel_side_no
        cmp #$06                 ; a record can be in one of at most 6 side sectors listed in the super side sector
        bcs rel_locate_not_found
        asl
        tay
        lda #$04                 ; the list of side sectors starts at offset 4
        sta dir_ptr
        lda (dir_ptr),y
        bne rel_locate_other_side_sector ; exists: it has to be loaded
rel_locate_not_found
        bit bit_set_nv
        rts
rel_locate_other_side_sector
        bit bit_set_v
        rts

; --- rel_advance: REL: advance to the next record
; REL: advance to the next record. Returns the first byte in iec_byte; CR at the end of data.
rel_advance
        lda #$20                 ; record is not full any more
        jsr chan_state_clear
        lda #$80                 ; already past the end?
        jsr chan_state_test
        bne rel_advance_return_cr
        ldx cur_chan
        inc chan_blk_lo,x        ; record counter + 1
        bne rel_advance_check_record_end
        inc chan_blk_hi,x
rel_advance_check_record_end
        ldx cur_chan
        lda chan_rel_end,x       ; record end pointer 0 = last record
        beq rel_advance_set_end_flag
        jsr chan_get_ptr
        ldx cur_chan
        cmp chan_rel_end,x       ; pointer already beyond the record end?
        bcc rel_advance_load_record_pointer
        jsr rel_write_block      ; next block of the file
rel_advance_load_record_pointer
        ldx cur_chan
        lda chan_rel_end,x
        jsr chan_set_ptr         ; set the pointer to the start of the record
        lda (buf_ptr_tbl,x)      ; first byte of the record
        sta iec_byte
        lda #$20
        jsr chan_state_clear
        jsr rel_limit_check

; --- rel_set_ptr: REL: set the buffer pointer for the record
; Set the buffer pointer for the record from the offset in A.
rel_set_ptr
        pha
        bcc rel_advance_pull_and_set_end ; C clear: a plain offset
        lda #$00
        jsr chan_get_byte_at     ; first byte of the buffer = link track
        bne rel_advance_pull_and_set_end ; nonzero: not the last block, so use the offset
        pla
        cmp #$02                 ; offset 2 = the start of the block
        beq rel_advance_finish_record
rel_advance_set_end_flag
        lda #$80                 ; past the last record: flag it
        jsr chan_state_set
rel_advance_return_cr
        jsr chan_buf_x2          ; use the first byte as CR
        lda buf_ptr_tbl,x
        sta chan_last,y
        lda #$0D                 ; CR is the filler returned
        sta iec_byte
        rts
rel_advance_finish_record
        jsr rel_set_end
        ldx cur_chan
        lda #$00
        sta chan_rel_end,x
        rts
rel_advance_pull_and_set_end
        pla

; --- rel_set_end: REL: set the end-of-record
; Set the record end (the offset of the end of the record in the buffer) and the limit.
rel_set_end
        ldx cur_chan
        sta chan_rel_end,x
        jmp rel_set_limit

; --- rel_write_block: REL: write the current block
; Write the record buffer if dirty and read the next block into the other buffer (double
; buffering).
rel_write_block
        jsr read_link_from_buf
        jsr chan_cur_buf2        ; current buffer + flags
        bvc rel_write_block_second_buffer_write
        jsr job_write_chan_buf_clean         ; write the current buffer
        jsr swap_chan_bufs       ; swap to the other buffer
        lda #$02
        jsr chan_set_ptr
        jsr chan_is_bad          ; is the buffer valid?
        bne rel_write_block_reread_next_block
        jsr job_read_chan_buf          ; read the next block of the file
        jmp job_wait
rel_write_block_second_buffer_write
        jsr swap_chan_bufs
        jsr chan_is_bad
        bne rel_write_block_reread_next_block
        jsr job_read_chan_buf
        jsr job_wait
rel_write_block_reread_next_block
        jsr read_link_from_buf
        lda cur_track
        beq rel_write_block_done
        jsr swap_chan_bufs
        jsr job_read_chan_buf
        jmp swap_chan_bufs
rel_write_block_done
        rts

; --- rel_put_byte: REL: put the byte into the record buffer
; Store iec_byte in the record. A full record sets state bit 5.
rel_put_byte
        jsr rel_set_dirty        ; mark the buffer dirty
        jsr chan_cur_buf
        asl
        tax
        lda iec_byte             ; store at the pointer
        sta (buf_ptr_tbl,x)
        ldy buf_ptr_tbl,x        ; offset after the byte
        iny
        bne rel_put_check_record_end ; crossed the page?
        ldy cur_chan
        lda chan_rel_end,y       ; end of the record?
        beq rel_put_mark_record_full
        ldy #$02
rel_put_check_record_end
        tya
        ldy cur_chan
        cmp chan_rel_end,y       ; reached the end of the record?
        bne rel_put_advance_pointer
rel_put_mark_record_full
        lda #$20                 ; record full
        jmp chan_state_set
rel_put_advance_pointer
        inc buf_ptr_tbl,x        ; move the pointer
        bne rel_put_done
        lda status_bits          ; status bit 4 = a block boundary has been crossed
        ora #$10
        sta status_bits
        jmp rel_write_block      ; write the old block and read the next
rel_put_done
        rts
; REL listen byte: a new record starts with the first byte after a position command.
rel_write_byte
        lda #$A0                 ; state bits 7 and 5 tell what we are doing
        jsr chan_state_test
        bne rel_put_check_eoi_state
rel_put_store_byte
        lda iec_byte
        jsr rel_put_byte
        lda eoi_flag             ; EOI: this is the last byte of the record
        beq rel_put_finish_record_write
        rts
rel_put_check_overflow
        lda #$20                 ; record was full (bit 5)
        jsr chan_state_test
        beq rel_put_finish_record_write
        lda #$51                 ; error 51 OVERFLOW IN RECORD
        sta pending_err
rel_put_finish_record_write
        jsr rel_pad_record       ; pad what is left of the record with zeroes
        jsr rel_next_rec_byte    ; prepare the next record
        lda pending_err
        beq rel_put_status_ok
        jmp dos_error_00
rel_put_status_ok
        jmp status_ok
rel_put_check_eoi_state
        and #$80                 ; position pending (bit 7)?
        bne rel_put_position_for_write
        lda eoi_flag
        beq rel_put_check_overflow
        rts
rel_put_position_for_write
        lda iec_byte             ; keep the byte over the positioning
        pha
        jsr rel_write_position   ; move to the position set with the P command
        pla
        sta iec_byte
        lda #$80                 ; position done
        jsr chan_state_clear
        jmp rel_put_store_byte

; --- rel_pad_record: REL: pad the record with zeros
; Fill the rest of the record with zeroes.
rel_pad_record
        lda #$20
        jsr chan_state_test
        bne rel_pad_done
        lda #$00
        sta iec_byte
        jsr rel_put_byte
        jmp rel_pad_record
rel_pad_done
        rts

; --- rel_set_dirty: Mark the channel buffer dirty
; Mark the record buffer as modified (state bit 6 and buffer flag bit 6).
rel_set_dirty
        lda #$40
        jsr chan_state_set
        jsr chan_cur_buf2
        ora #$40
        ldx chan_alt_idx
        sta chan_buf,x
        rts

; --- rel_clear_dirty: Clear the channel buffer dirty flag
; Clear the modified flag of the buffer.
rel_clear_dirty
        jsr chan_cur_buf2
        and #$BF
        ldx chan_alt_idx
        sta chan_buf,x
        rts
; --- rel_get_byte: REL: get the next byte of the record
; REL: next byte of the current record.
rel_get_byte
        lda #$80                 ; state bit 7: no record
        jsr chan_state_test
        bne rel_get_record_not_present
        jsr chan_buf_x2
        lda buf_ptr_tbl,x
        cmp chan_last,y          ; at the end of the data in the record?
        beq rel_next_rec_byte    ; then start the next record
        inc buf_ptr_tbl,x
        bne rel_get_fetch_byte
        lda status_bits          ; crossed a block boundary
        ora #$10
        sta status_bits
        jsr rel_write_block      ; get the next block
rel_get_reload_pointer
        jsr chan_buf_x2
rel_get_fetch_byte
        lda (buf_ptr_tbl,x)
rel_get_store_and_flag
        sta chan_byte,y          ; channel byte register
        lda #$89                 ; $89 = active, more data
        sta chan_flags,y
        lda buf_ptr_tbl,x
        cmp chan_last,y
        beq rel_get_set_last_flag
        rts
rel_get_set_last_flag
        lda #$81                 ; $81 = active, last byte of the record
        sta chan_flags,y
        rts

; --- rel_next_rec_byte: REL: read from the next record
; Read from the next record.
rel_next_rec_byte
        jsr rel_advance
        jsr chan_buf_x2
        lda iec_byte
        jmp rel_get_store_and_flag
rel_get_record_not_present       ; record not present: return CR with EOI and set error 50
        ldx cur_chan
        lda #$0D
        sta chan_byte,x
        lda #$81
        sta chan_flags,x
        lda #$50
        jsr dos_error_00
; --- rel_set_limit: REL: set the end-of-record limit
; REL: set the limit of the current record (the last data byte in the buffer).
rel_set_limit
        ldx cur_chan
        lda chan_rel_end,x
        sta tmp_86
        dec tmp_86
        cmp #$02                 ; a record starting at offset 2 has no previous byte: use $FF
        bne rel_set_limit_load_record_size
        lda #$FF
        sta tmp_86
rel_set_limit_load_record_size
        lda chan_recsize,x       ; record length
        sta tmp_87
        jsr chan_get_ptr         ; current buffer offset
        ldx cur_chan
        cmp tmp_86               ; does the record fit in the current block?
        bcc rel_set_limit_find_end_current
        beq rel_set_limit_find_end_current
        jsr swap_chan_bufs       ; no: look in the following block
        jsr rel_find_end         ; find the last non-zero byte of the record
        bcc rel_set_limit_swap_and_clear_limit
        ldx cur_chan
        sta chan_last,x
        jmp swap_chan_bufs
rel_set_limit_swap_and_clear_limit
        jsr swap_chan_bufs
        lda #$FF
        sta tmp_86
rel_set_limit_find_end_current
        jsr rel_find_end
        bcs rel_set_limit_store_last
        jsr chan_get_ptr
rel_set_limit_store_last
        ldx cur_chan
        sta chan_last,x
        rts

; --- rel_find_end: REL: find the end of data in the record
; REL: find the last byte that is not zero in the record (scanning back from the limit). A
; record shorter than its length ends at its last data byte; C = 1 if found.
rel_find_end
        jsr ent_ptr
        ldy tmp_86
rel_find_end_scan_back_loop      ; scan backwards
        lda (dir_ptr),y
        bne rel_find_end_data_found
        dey                      ; stop at offset 2 (block start)
        cpy #$02
        bcc rel_find_end_no_data
        dec tmp_87               ; never more than one record length
        bne rel_find_end_scan_back_loop
rel_find_end_no_data
        dec tmp_87
        clc
        rts
rel_find_end_data_found
        tya
        sec
        rts

; --- rel_first_side: REL: find the first side sector
; REL: find the first side sector of the file in the channel's directory buffer and read it.
rel_first_side
        jsr rel_is_rel
        bne rel_first_side_get_side_number
        jsr ss_init_scan         ; native layout: scan the cached side sectors first
rel_first_side_get_side_number
        jsr get_ent_byte
        sta rel_side_no
        lda #$04                 ; side sector pointers start at offset 4 of the super side sector
        sta dir_ptr
        ldy #$0A                 ; up to 6 side sectors
        bne rel_first_side_check_slot
rel_first_side_previous_slot     ; the table is read from the end for the last used one
        dey
        dey
        bmi rel_no_room_error    ; none found: no room error 67
rel_first_side_check_slot
        lda (dir_ptr),y          ; non-zero = this side sector exists
        beq rel_first_side_previous_slot
        tya                      ; side sector number
        lsr
        cmp rel_side_no          ; already loaded?
        beq rel_first_side_side_sector_loaded
        sta rel_side_no
        ldx cur_chan
        lda chan_dirbuf,x
        jsr rel_read_block
rel_first_side_side_sector_loaded
        ldy #$00                 ; first byte must be 0: the chain of side sectors ends here
        sty dir_ptr
        lda (dir_ptr),y
        bne rel_no_room_error
        iny
        lda (dir_ptr),y          ; second byte is the index of the last entry
        tay
        dey
        sty rel_side_off
        tya
        jmp put_ent_ptr
rel_no_room_error                ; error 67 ILLEGAL SYSTEM T OR S
        lda #$67
        jsr jt_dos_error

; --- cmd_position: P command: position (REL records)
; P command: position a REL channel: "P" + channel + record lo + record hi + offset.
cmd_position
        jsr trim_command
        lda cmd_buf+1            ; channel byte
        sta cur_sa
        jsr get_chan_for_sa
        bcc cmd_position_channel_ok ; channel not open: error 70
        lda #$70
        jsr dos_error_00
cmd_position_channel_ok
        lda #$A0                 ; clear the "past end" flags
        jsr chan_state_clear
        jsr chan_get_type        ; type 0 = REL expected
        beq cmd_position_store_record_number
        lda #$64                 ; error 64 FILE TYPE MISMATCH
        jsr dos_error_00
cmd_position_store_record_number
        lda cmd_buf+2            ; record number, low and high byte
        sta chan_blk_lo,x
        lda cmd_buf+3
        sta chan_blk_hi,x
        ldx cur_chan
        lda #$89                 ; $89 = ready for data
        sta chan_flags,x
        lda cmd_buf+4            ; offset in the record (0 = first byte)
        beq cmd_position_store_offset
        sec
        sbc #$01
        beq cmd_position_store_offset
        cmp chan_recsize,x       ; offset beyond the record length
        bcc cmd_position_store_offset
        lda #$51                 ; error 51 OVERFLOW IN RECORD
        sta pending_err
        lda #$00
cmd_position_store_offset
        sta rel_rec_tmp          ; offset (0-based)
        jsr rel_calc_position    ; where is the record in the side sectors
        jsr rel_next_side        ; load the side sector
        bvc cmd_position_position_record ; V clear = found
        lda #$80
        jsr chan_state_set       ; record does not exist yet: flag "not present"
        jmp rel_get_record_not_present
cmd_position_position_record
        jsr rel_pos_record       ; set the pointer
        lda #$80                 ; state bit 7: record not present
        jsr chan_state_test
        beq cmd_position_done
        jmp rel_get_record_not_present
cmd_position_done
        jmp cmd_complete

; --- rel_pos_record: REL: position to the record
; REL: position to the record found by rel_calc_position.
rel_pos_record
        jsr rel_find_side_sector
        lda rel_rec_off          ; offset of the record in its block
        jsr chan_set_ptr
        ldx cur_chan
        lda chan_recsize,x       ; record length minus offset-in-record
        sec
        sbc rel_rec_tmp
        bcs rel_pos_set_pointer  ; record does not fit in the block: error 67
        jmp rel_no_room_error
rel_pos_set_pointer
        clc
        adc rel_rec_off
        bcc rel_pos_finish       ; set the pointer
        adc #$01
        sec
rel_pos_finish
        jsr rel_set_ptr
        jmp rel_get_reload_pointer

; UNREACHABLE CODE ($D47A-$D47E, 5 bytes): nothing jumps here, the live code raises error 51 itself.
; Not referenced by CMD HD BOOTROM v2.80 or JiffyDOS either (too short to match by pattern).
; --- err_51_overflow: Error 51: overflow in record
err_51_overflow
        lda #$51
        jsr dos_error_00

; --- rel_find_side_sector: REL: find the side sector that covers the record
; REL: load the data block of the record, following the side sector pointers.
rel_find_side_sector
        lda dir_ptr              ; dir_ptr is the pointer to the block
        sta tmp_88
        lda dir_ptr_hi
        sta tmp_89
        jsr rel_chain_check      ; is the block already loaded?
        beq rel_find_side_done
        jsr flush_if_dirty
        jsr ent_get_ts           ; else look at the second buffer's block
        lda cur_track            ; nothing there
        beq rel_find_side_read_side_sector
        jsr swap_chan_bufs
        jsr rel_chain_check
        bne rel_find_side_read_side_sector
        jsr ent_get_ts           ; the other buffer holds the next block
        lda cur_track
        beq rel_find_side_done
        jsr swap_chan_bufs
        jsr job_read_chan_buf
        jmp swap_chan_bufs
rel_find_side_done
        rts
rel_find_side_read_side_sector
        ldy #$00                 ; read the block named by the pointer
        lda (tmp_88),y
        sta cur_track
        iny
        lda (tmp_88),y
        sta cur_sector
        jmp read_link_check

; --- rel_chain_check: REL: follow the side-sector chain
; REL: is the block at (tmp_88) the one already in the buffer? Z = 1 if yes.
rel_chain_check
        jsr ts_from_buf
        ldy #$00
        lda (tmp_88),y
        cmp cur_track
        beq rel_chain_check_sector
        rts
rel_chain_check_sector
        iny
        lda (tmp_88),y
        cmp cur_sector
        bne rel_chain_done
        lda status_bits          ; status bit 4 means "a block boundary has been crossed"
        and #$10
        beq rel_chain_done
        lda status_bits
        and #$EF
        sta status_bits
        eor #$10
rel_chain_done
        rts

; --- rel_new_record: REL: initialise a new record
; REL: clear the record buffer and write the $FF record start markers (an empty record starts
; with $FF).
rel_new_record
        jsr ent_ptr
        ldy #$02
        lda #$00
rel_new_record_clear_loop
        sta (dir_ptr),y
        iny
        bne rel_new_record_clear_loop
        jsr rel_limit_check
rel_new_record_mark_record_starts ; first byte of each record = $FF
        sta chan_rel_end,x
        tay
        lda #$FF
        sta (dir_ptr),y
        jsr rel_limit_check
        bcc rel_new_record_mark_record_starts
        bne rel_new_record_done
        lda #$00
        sta chan_rel_end,x
rel_new_record_done
        rts

; --- rel_limit_check: REL: check the record limit
; REL: find where the next record starts in the buffer. C = 1 and A = $02 when the record is
; at the very beginning of the next block.
rel_limit_check
        ldx cur_chan
        lda chan_rel_end,x
        sec
        beq rel_limit_end_overflow
        clc
        adc chan_recsize,x
        bcc rel_limit_done
        bne rel_limit_end_overflow
        lda #$02
        bit bit_zero
        rts
rel_limit_end_overflow
        adc #$01
        sec
rel_limit_done
        rts
; --- bit_set_v: BIT constant: sets V
; Constants for the BIT instruction: BIT bit_set_v sets V, bit_clr_nv clears N and V, and so on.
; Used to return a status in the processor flags without using a register.
bit_set_v
        !byte $7F                       ; $D520
; --- bit_clr_nv: BIT constant: clears N and V
bit_clr_nv
        !byte $3F                       ; $D521
; --- bit_set_nv: BIT constant: sets N and V
bit_set_nv
        !byte $FF                       ; $D522
; --- bit_set_n: BIT constant: sets N
bit_set_n
        !byte $BF                       ; $D523
; --- bit_zero: BIT constant: zero
bit_zero
        !byte $00                       ; $D524

; --- rel_write_position: REL: write position handling
; REL: prepare writing at a record: work out which side sectors and data blocks are needed,
; check that enough free blocks exist (error 52 FILE TOO LARGE otherwise), then allocate the new
; data blocks, link them and create the side sectors that are missing.
rel_write_position
        jsr rel_seek
        jsr rel_calc_position
rel_calc_side_offsets
        jsr dir_get_free         ; free blocks of the partition
        ldy cur_chan
        ldx chan_recsize,y       ; record length - 1 + offset
        dex
        txa
        clc
        adc rel_rec_off
        bcc rel_write_pos_store_side_pointer
        inc rel_side_off         ; crossed into the next side sector slot
        inc rel_side_off
        bne rel_write_pos_store_side_pointer
        inc rel_side_no
        lda #$10                 ; the first slot of a side sector is at offset $10
        sta rel_side_off
rel_write_pos_store_side_pointer
        lda tmp_86
        clc
        adc #$02
        jsr put_ent_ptr
        lda rel_side_no
        cmp #$06                 ; more than 6 side sectors per super side sector
        bcc rel_write_pos_compute_blocks_needed
        jsr rel_is_rel
        bne rel_write_pos_file_too_large_error
        sta rel_side_no
        inc rel_ss_idx           ; start another group of side sectors
        bne rel_write_pos_compute_blocks_needed
rel_write_pos_file_too_large_error
        lda #$52                 ; error 52 FILE TOO LARGE
        jsr dos_error_00
rel_write_pos_compute_blocks_needed
        lda rel_side_off         ; distance from the last pointer to the new one
        sec
        sbc tmp_86
        bcs check_rel_type
        sbc #$0F
        clc
check_rel_type
        pha
        jsr rel_is_rel
        beq rel_write_pos_native_blocks_needed
        pla
        sta tmp_d
        lda rel_side_no
        sbc tmp_85
        sta tmp_e
        ldx #$00
        stx tmp_b
        stx tmp_c
        tax
        jsr rel_add_blocks       ; add the block counts
        lda tmp_c
        bne rel_write_pos_check_free_space
        ldx tmp_b
        dex
        bne rel_write_pos_check_free_space
        beq rel_write_pos_count_single
rel_write_pos_native_blocks_needed
        pla
        sta tmp_d
        lda rel_side_no
        sbc tmp_85
        bcs rel_write_pos_store_block_count
        inc tmp_88
        adc #$06
rel_write_pos_store_block_count
        sta tmp_e
        lda rel_ss_idx
        sec
        sbc tmp_88
        sta tmp_88
        jsr rel_calc_size
        lda calc_b
        bne rel_write_pos_check_free_space
        ldx calc_a
        bne rel_write_pos_check_one_block
        rts
rel_write_pos_check_one_block
        dex
        bne rel_write_pos_check_free_space
rel_write_pos_count_single
        inc tmp_87
rel_write_pos_check_free_space
        cmp blocks_free_hi       ; enough free blocks?
        bcc rel_write_pos_allocate_expansion
        bne rel_write_pos_file_too_large_error ; no: error 52
        lda blocks_free_lo
        cmp tmp_b
        bcc rel_write_pos_file_too_large_error
rel_write_pos_allocate_expansion
        lda #$01                 ; allocate the next block for the record data
        jsr chan_get_byte_at     ; the first byte of the side sector tells how many entries exist
        clc
        adc #$01
        ldx cur_chan
        sta chan_rel_end,x
        jsr alloc_next_block     ; new block
        jsr ent_put_ts           ; its track/sector goes into the side sector
        lda tmp_87
        bne rel_write_pos_write_record_block
        jsr job_write_chan_buf_clean
rel_write_pos_allocate_data_block
        jsr swap_chan_bufs
        jsr ts_to_job_chan       ; a new data block for the next record
        jsr alloc_next_block
        jsr ent_put_ts
        jsr rel_new_record       ; clear it and set up its record markers
        jmp rel_write_pos_link_new_block
rel_write_pos_write_record_block
        jsr swap_chan_bufs
        jsr ts_to_job_chan
        jsr rel_new_record
        jsr ent_put_end
rel_write_pos_link_new_block
        jsr job_write_chan_buf_clean         ; write the old block
        jsr ent_get_ts
        lda cur_track
        pha                      ; keep the pointers while the block is linked
        lda cur_sector
        pha
        jsr ts_from_buf
        lda cur_sector
        pha
        lda cur_track
        pha
        jsr rel_chan_to_ptr      ; side sector entry?
        tax
        bne rel_write_pos_store_link
        jsr rel_create_side      ; none: create a new side sector
        lda #$10
        jsr put_ent_ptr
        inc tmp_85
rel_write_pos_store_link
        pla
        jsr chan_put_byte_pha    ; the link bytes of the previous block
        pla
        jsr chan_put_byte_pha
        pla
        sta cur_sector
        pla
        sta cur_track
        beq rel_write_pos_finish_expansion ; track 0 = nothing more to link
        jsr rel_is_rel           ; native: loop over the index
        bne rel_write_pos_check_expansion_done
        lda tmp_8a
        cmp rel_ss_idx
        bcc rel_write_pos_allocate_data_block
rel_write_pos_check_expansion_done
        lda tmp_85
        cmp rel_side_no
        bne rel_write_pos_allocate_data_block
        jsr rel_chan_to_ptr
        cmp rel_side_off
        bcc rel_write_pos_allocate_data_block
        beq rel_write_pos_write_record_block
rel_write_pos_finish_expansion
        jsr rel_chan_to_ptr      ; finish: the last side sector entry
        pha
        lda #$00
        jsr set_ent_ptr
        lda #$00
        tay
        sta (dir_ptr),y
        iny
        pla
        sec
        sbc #$01
        sta (dir_ptr),y
        jsr job_write_dir_buf         ; write the side sector
        jsr job_wait
        jsr bam_write_if_dirty   ; write the BAM
        jsr rel_calc_position
        jsr swap_chan_bufs
        jsr rel_next_side
        bvs rel_write_pos_record_not_present_error
        jmp rel_pos_record
rel_write_pos_record_not_present_error
        lda #$80
        jsr chan_state_set
        lda #$50
        jsr dos_error_00

; --- rel_seek: REL: seek to the record
; REL: seek to the first record: find the first side sector and the block of record 0.
rel_seek
        jsr rel_first_side
        jsr rel_find_side_sector
        jsr rel_is_rel
        bne rel_seek_store_position
        lda rel_ss_idx           ; native layout: the index of the current side sector group
        sta tmp_8a
        sta tmp_88
rel_seek_store_position
        lda rel_side_off         ; remember the pointer offset and side sector number
        sta tmp_86
        lda rel_side_no
        sta tmp_85
        lda #$00
        sta tmp_87
        sta rel_rec_tmp
        rts

; --- rel_create_side: REL: create a side sector
; REL: create a new side sector (when a file grows past the last one). Allocates a block, fills
; in the link to the previous side sector and to the next, copies the list of existing side
; sectors into it and records the new sector in all the others.
rel_create_side
        jsr alloc_next_block     ; block for the new side sector
        jsr swap_chan_bufs
        jsr flush_if_dirty       ; write the old one first
        jsr chan_cur_buf
        pha
        jsr clear_buf            ; clear the new buffer
        ldx cur_chan
        lda chan_dirbuf,x
        tay
        pla
        tax
        jsr rel_is_rel           ; which layout?
        bne rel_create_side_copy_old_side_header
        jmp rel_create_side_native_side_check
rel_create_side_copy_old_side_header
        lda #$10                 ; copy the 16 header bytes of the old side sector
        jsr copy_buf_bytes
        lda #$00
        jsr set_ent_ptr
        ldy #$02                 ; byte 2 is the side sector number: new number = old + 1
        lda (dir_ptr),y
        pha
        lda #$00
        jsr chan_set_ptr
        pla
        clc
        adc #$01
        sta (dir_ptr),y
        asl                      ; each side sector adds two bytes to the list of side sectors
        adc #$04
        sta tmp_88
        tay
        sec
        sbc #$02
        sta tmp_89
rel_create_side_link_side_sector
        lda cur_track            ; remember the new block's track/sector
        sta tmp_86
        sta (dir_ptr),y          ; put it in the list
        iny
        lda cur_sector
        sta tmp_87
        sta (dir_ptr),y
        ldy #$00                 ; link of this side sector: $00/$11 (last side sector, 17 bytes used)
        tya
        sta (dir_ptr),y
        iny
        lda #$11
        sta (dir_ptr),y
        lda #$10                 ; offset $10: first record pointer
        jsr chan_set_ptr
        jsr job_write_chan_buf          ; read the old side sectors so their lists can be updated
        jsr job_wait
        ldx cur_chan
        lda chan_dirbuf,x
        pha
        jsr chan_cur_buf2
        ldx cur_chan
        sta chan_dirbuf,x
        pla
        ldx chan_alt_idx
        sta chan_buf,x
        lda #$00
        jsr chan_set_ptr
        ldy #$00                 ; new side sector's own location goes into the second buffer
        lda cur_track
        sta (dir_ptr),y
        iny
        lda cur_sector
        sta (dir_ptr),y
        jsr rel_is_rel
        bne rel_create_side_store_side_link
        lda tmp_85               ; only for a native super side sector (index $FF)
        cmp #$FF
        bne rel_create_side_store_side_link
        lda cur_sector
        pha
        lda cur_track
        pha
        jsr job_write_chan_buf_clean         ; write the super side sector
        jsr job_wait
        jsr swap_chan_bufs
        jsr ss_flush_read
        inc tmp_8a               ; next side sector slot
        lda tmp_8a
        asl
        clc
        adc #$03
        jsr put_ent_ptr          ; pointer to the slot
        pla
        jsr chan_put_byte_pha
        pla
        jsr chan_put_byte_pha
        jsr ss_flush_write
        lda tmp_8a               ; go to the link handling
        pha
        jmp ss_point_at_links
rel_create_side_read_super_side  ; update the lists of the previous side sectors
        jsr chan_cur_buf
        ldx cur_chan
        jsr rel_read_block
        lda #$00
        jsr chan_set_ptr
rel_create_side_store_side_link
        dec tmp_89               ; two bytes less to update
        dec tmp_89
        ldy tmp_88               ; put the new side sector's location in
        lda tmp_86
        sta (dir_ptr),y
        iny
        lda tmp_87
        sta (dir_ptr),y
        jsr job_write_chan_buf_clean         ; write it back
        jsr job_wait
        ldy tmp_89
        cpy #$03                 ; more side sectors to update?
        bcs rel_create_side_read_super_side
        jmp swap_chan_bufs
rel_create_side_native_side_check
        lda tmp_85               ; native: more than 5 sectors need a super side sector
        cmp #$05
        bcs rel_create_side_init_super_side
        jmp rel_create_side_copy_old_side_header
rel_create_side_init_super_side
        lda #$FF                 ; $FF = super side sector
        sta tmp_85
        lda #$00
        jsr chan_set_ptr
        ldy #$02                 ; number of side sectors: 0
        sta (dir_ptr),y
        ldx cur_chan
        lda chan_recsize,x       ; record length
        iny
        sta (dir_ptr),y
        iny
        beq rel_create_side_back_to_copy
        jmp rel_create_side_link_side_sector
rel_create_side_back_to_copy
        jmp rel_create_side_copy_old_side_header

; --- rel_is_rel: Z = 0 if the channel is a relative file
; Z = 0 if the channel is a REL file with the native layout (chan_rel_flags bit 5).
rel_is_rel
        stx d7_x_save
        ldx cur_chan
        lda chan_rel_flags,x
        ldx d7_x_save
        and #$20
        rts

; --- ss_flush_check: Flush the side-sector cache if needed
; Flush the side sector cache (re-read if it was changed).
ss_flush_check
        ldx cur_chan
        lda #$FE
        cmp chan_ss_cache,x
        bne ss_flush_read
        rts

; --- ss_flush_read: Re-read the side sector
; Re-read ($80) or write ($90) the cached side sector. The entry for the write is the second.
ss_flush_read
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- ss_flush_write: Write the side sector
ss_flush_write
        lda #$90
        pha
        ldx cur_chan
        lda chan_ss_trk,x
        sta cur_track
        lda chan_ss_sec,x
        sta cur_sector
        lda #$FF                 ; $FF = invalid while the job runs
        sta chan_ss_cache,x
        lda chan_dirbuf,x
        sta cur_buf_idx
        jsr ts_to_job
        pla
        jsr job_run
        ldx cur_chan
        lda #$FE                 ; $FE = the cache holds a valid side sector
        sta chan_ss_cache,x
        rts

; --- ss_init_scan: Initialise the side-sector scan
; Search back from the last possible side sector for one that exists.
ss_init_scan
        lda #$5A                 ; start with a high index
        sta rel_ss_idx
        jsr ss_select
        bne ss_init_search_back_loop
        rts
ss_init_search_back_loop
        dec rel_ss_idx           ; step down until a side sector is found
        lda rel_ss_idx
        jsr ss_get_link
        bne ss_init_search_back_loop
        rts

; --- ss_select: Select side sector A
; Make side sector A the one in the buffer (reads it if it is not cached already).
ss_select
        ldx cur_chan
        cmp chan_ss_cache,x
        bne ss_select_different_side
        rts
ss_select_different_side
        pha
        jsr ss_flush_check
ss_point_at_links
        lda #$03
        jsr set_ent_ptr
        pla

; --- ss_get_link: Get link to side sector A
; Read the pointer to side sector A from the list at offset 3 of the super side sector; if
; it exists read it. Returns Z = 1 if the side sector was found.
ss_get_link
        tax
        asl
        tay
        lda (dir_ptr),y
        bne ss_get_link_side_sector_exists
        ora #$FF                 ; $FF: not found
        rts
ss_get_link_side_sector_exists
        sta cur_track
        iny
        lda (dir_ptr),y
        sta cur_sector
        txa
        pha
        lda #$FF                 ; invalidate the cache while the job runs
        ldx cur_chan
        sta chan_ss_cache,x
        lda chan_dirbuf,x
        sta cur_buf_idx
        jsr ts_to_job
        lda #$80                 ; read job
        jsr job_run
        ldx cur_chan
        pla
        sta chan_ss_cache,x
        lda #$00
        rts

; --- read_link_bytes: Read two link bytes from the channel buffer
; Read the first block of the channel and take its link bytes: cur_track/cur_sector.
read_link_bytes
        jsr ts_to_job_chan
        jsr chan_read_job
        jsr job_wait
        jsr chan_get_byte
        sta cur_track
        jsr chan_get_byte
        sta cur_sector
        rts
; --- read_link_check: Read the link bytes and test for the last block
; As above but also read the following block into the other buffer when there is one.
read_link_check
        jsr read_link_bytes
        lda cur_track
        bne read_link_check_read_next_block
        rts
read_link_check_read_next_block
        jsr swap_chan_bufs
        jsr ts_to_job_chan
        jsr chan_read_job
        jmp swap_chan_bufs

; --- chan_read_job: Issue the read job ($80) for the channel's buffer
; Issue a read ($80) or write ($90) job for the buffer of the channel. The two entries share
; the code by skipping the second LDA with a BIT. Write advances the block counter of
; sequential files.
chan_read_job
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- chan_write_job: Issue the write job ($90) for the channel's buffer
chan_write_job
        lda #$90
        sta job_cmd_tmp
        jsr chan_cur_buf
        tax
        jsr issue_job_cmd
        txa
        pha
        asl
        tax
        lda #$00
        sta buf_ptr_tbl,x
        jsr chan_get_type        ; only sequential channel types count the blocks
        cmp #$04
        bcs chan_write_job_done
        inc chan_blk_lo,x
        bne chan_write_job_done
        inc chan_blk_hi,x
chan_write_job_done
        pla
        tax
        rts

; --- read_chan_buf: Read the channel's buffer ($80)
; Same for the buffer in cur_buf_idx (one entry for read, the next for write).
read_chan_buf
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- write_chan_buf: Write the channel's buffer ($90)
write_chan_buf
        lda #$90
        sta job_cmd_tmp
        lda cur_buf_idx
        jsr ts_to_job
        ldx cur_buf_idx
        jmp job_issue_and_wait

; --- issue_job_cmd: Issue the job in job_cmd_tmp
; Issue the job in job_cmd_tmp. A write is checked against the BAM DOS version (error 73).
issue_job_cmd
        lda job_cmd_tmp

; --- issue_job: Issue the job A for buffer X, checking the track/sector
; Run job A on buffer X after checking that track/sector are legal for the partition
; (error 66 otherwise) and, for a write, that the DOS version matches.
issue_job
        pha
        stx cur_buf_idx
        bit job_flag_df          ; job_flag_df b6: job already checked
        bvc issue_job_check_track
        jmp issue_job_run_job
issue_job_check_track
        txa
        asl
        tax
        lda job_sector,x         ; job sector
        sta job_cmd_tmp
        lda job_track,x          ; job track
        beq issue_job_restore_and_report ; track 0: illegal
        tax
        jsr get_geometry         ; geometry of the track
        lda cur_buf_idx
        asl
        tax
        lda geo_end_track        ; end track = 0 means native (no limit)
        beq issue_job_check_write_ok
        cmp job_track,x          ; track beyond the partition?
        beq issue_job_restore_and_report
        bcc issue_job_restore_and_report
issue_job_check_write_ok
        pla                      ; for a write check the BAM
        pha
        cmp #$90                 ; $90 = write
        bne issue_job_run_job
        jsr bam_load_if_needed   ; the BAM of the partition has to be loaded
        lda bam_dosver,x         ; DOS version of the BAM
        jsr check_dos_ver
        bne issue_job_dos_version_mismatch
        lda geo_secs_per_trk     ; sectors per track
        beq issue_job_run_job
        cmp job_cmd_tmp          ; sector beyond the end of the track?
        beq issue_job_restore_and_report
        bcs issue_job_run_job
issue_job_restore_and_report
        jsr restore_ts_from_job  ; put the offending track/sector into the error message
illegal_ts_error
        lda #$66                 ; error 66 ILLEGAL TRACK OR SECTOR
        jmp jt_dos_error

; --- restore_ts_from_job: Restore cur_track/cur_sector from the job table
; Restore cur_track/cur_sector from the job table of buffer cur_buf_idx.
restore_ts_from_job
        lda cur_buf_idx
        asl
        tax
        lda job_track,x
        sta cur_track
        lda job_sector,x
        sta cur_sector
        rts

; --- check_ts_legal: Validate track/sector (error 66 if illegal)
; Check track and sector against the partition geometry. Error 66 if either is illegal.
check_ts_legal
        txa
        pha
        ldx cur_track
        jsr get_geometry
        lda cur_track
        beq illegal_ts_error
        lda geo_end_track
        beq check_ts_legal_check_first_track
        cmp cur_track
        beq illegal_ts_error
        bcc illegal_ts_error
check_ts_legal_check_first_track
        lda cur_track
        cmp geo_first_track
        bcc illegal_ts_error
        lda geo_secs_per_trk
        beq check_ts_legal_done
        cmp cur_sector
        beq illegal_ts_error
        bcc illegal_ts_error
check_ts_legal_done
        pla
        tax
        rts
issue_job_dos_version_mismatch   ; error 73 DOS MISMATCH
        jsr restore_ts_from_job
        lda #$73
        jmp jt_dos_error
issue_job_run_job                ; run the job through the jump table (so it can be hooked)
        ldx cur_buf_idx
        pla
        sta job_cmd_tmp
        jmp jt_do_job

; UNREACHABLE CODE ($D957-$D95F, the two 5-byte entries job_read_x80 and job_write_x90): never called.
; Not referenced by CMD HD BOOTROM v2.80 or JiffyDOS either.
; Everything goes through job_run, which is all these two wrap.
; --- job_read_x80: Run read job on the current buffer
; Job $80 read or $90 write on the buffer in cur_buf_idx.
job_read_x80
        lda #$80
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- job_write_x90: Run write job on the current buffer
job_write_x90
        lda #$90

; --- job_run: Run the job in A on buffer X
; Run job A on buffer cur_buf_idx and wait for the result.
job_run
        ldx cur_buf_idx
        sta job_cmd_tmp
job_issue_and_wait
        lda job_cmd_tmp
        jsr issue_job

; --- job_wait: Wait for the job of buffer X to finish
; Wait for the job of buffer X to finish and return its status.
job_wait
        lda job_code,x
        jsr jt_do_job
        clc
        pha
        lda #$00                 ; a new job may be issued again
        sta job_flag_df
        pla
        rts

; --- ts_to_job_chan: Copy track/sector into the job table of the channel's buffer
; Copy cur_track/cur_sector into the job table entry for the channel's buffer (or buffer A).
ts_to_job_chan
        jsr chan_cur_buf

; --- ts_to_job: Copy cur_track/cur_sector into the job table entry A
ts_to_job
        asl
        tay
        lda cur_track
        sta job_track,y
        lda cur_sector
        sta job_sector,y
        lda #$00
        tax
        rts

; --- ts_from_chan: Get track/sector from the job table (channel 17/18 open)
; Get track/sector from the job table into cur_track/cur_sector.
ts_from_chan
        jsr get_chan_for_sa

; --- ts_from_buf: Get track/sector of the channel's buffer from the job table
ts_from_buf
        jsr chan_cur_buf
        sta cur_buf_idx
        asl
        tay
        lda job_track,y
        sta cur_track
        lda job_sector,y
        sta cur_sector
        rts

; --- job_write_chan_buf: Write the channel's buffer to the block in its job table entry (job $90)
; Job helpers for the channel buffers. They all end in issue_job_cmd with the job code in
; job_cmd_tmp: the "prep" part sets up the job table entry, the "clean" part clears the
; buffer's modified flag.
job_write_chan_buf
        lda #$90                 ; $90 = write
        sta job_cmd_tmp
        bne prep_prepare_job

; --- job_read_chan_buf: Read the block in the channel's job table entry into its buffer (job $80)
job_read_chan_buf                      ; $80 = read
        lda #$80
        sta job_cmd_tmp
        bne prep_prepare_job

; --- job_write_chan_buf_clean: Write the channel's buffer ($90) and clear its modified flag
job_write_chan_buf_clean
        lda #$90                 ; $90 = write the buffer and mark it clean
        sta job_cmd_tmp
        bne prep_clear_dirty_and_issue
        lda #$80                 ; (dead code) $80
        sta job_cmd_tmp
        bne prep_clear_dirty_and_issue

; --- job_write_dir_buf: Write the channel's second buffer (side sector / directory entry buffer) ($90)
job_write_dir_buf
        lda #$90                 ; $90, using the channel's second buffer
        sta job_cmd_tmp
        bne prep_get_dir_buffer

; --- job_read_dir_buf: Read into the channel's second buffer ($80)
job_read_dir_buf
        lda #$80                 ; $80, using the channel's second buffer
prep_get_dir_buffer
        sta job_cmd_tmp
        ldx cur_chan             ; buffer number of the second buffer
        lda chan_dirbuf,x
        tax
        bpl prep_issue
prep_prepare_job
        jsr ts_to_job_chan       ; track/sector into the job table
        jsr chan_cur_buf
        tax
        lda #$00
        sta job_status,x         ; clear the job's status
prep_clear_dirty_and_issue
        jsr rel_clear_dirty
        jsr chan_cur_buf
        tax
prep_issue
        jmp issue_job_cmd

; --- read_link_from_buf: Read cur_track/cur_sector from the channel buffer (link bytes)
; Take cur_track/cur_sector from the first two bytes of the channel buffer (the link bytes).
read_link_from_buf
        lda #$00
        jsr chan_set_ptr
        jsr chan_get_byte
        sta cur_track
        jsr chan_get_byte
        sta cur_sector
        rts

; --- chan_state_set: Set bits A in the channel state
; Channel state bits: 7 = past end of record / no record, 6 = buffer modified, 5 = record
; full, 1-3 = channel type, 0 = write. Set, clear and test bits (mask in A).
chan_state_set
        ldx cur_chan
        ora chan_state,x
        bne chan_state_store_state

; --- chan_state_clear: Clear bits A in the channel state
chan_state_clear
        ldx cur_chan
        eor #$FF
        and chan_state,x
chan_state_store_state
        sta chan_state,x
        rts

; --- chan_state_test: Test bits A in the channel state
chan_state_test
        ldx cur_chan
        and chan_state,x
        rts

; --- chan_is_bad: Check whether the channel's job failed
; Z = 0 if the job of the channel's buffer failed (job status $90+ = error).
chan_is_bad
        jsr chan_cur_buf
        tax
        lda job_status,x
        and #$FE
        cmp #$90
        rts

; --- find_file_open: Search the open channels for the same file
; Is the file in directory entry match_type already open on a channel? Compares the channel's
; state, partition and directory entry location with the spec. C = 0 if it is.
find_file_open
        ldx #$00
find_file_open_channel_loop
        stx tmp_c
        lda sa_chan,x
        cmp #$FF
        bne find_file_open_compare_entry
find_file_open_next_channel
        ldx tmp_c
        inx
        cpx #$10
        bcc find_file_open_channel_loop
        rts
find_file_open_compare_entry
        stx tmp_c
        and #$3F
        tay
        ldx match_type
        lda chan_state,y         ; state (type)
        cmp spec_type,x
        bne find_file_open_next_channel
        lda chan_part,y          ; partition
        cmp spec_part,x
        bne find_file_open_next_channel
        lda chan_dir_track,y     ; directory entry track, sector and offset
        cmp spec_aux1,x
        bne find_file_open_next_channel
        lda chan_dir_sector,y
        cmp spec_aux2,x
        bne find_file_open_next_channel
        lda chan_dir_index,y
        cmp spec_aux3,x
        bne find_file_open_next_channel
        clc
        rts

; --- flush_if_dirty: Write the channel buffer if modified
; Write the channel's buffer if its modified flag is set.
flush_if_dirty
        jsr chan_cur_buf2
        bvc flush_dirty_done
        jsr job_write_chan_buf_clean
        jsr job_wait
flush_dirty_done
        rts

; --- get_chan_for_sa: Get the channel for the current secondary address (C = 1: none)
; Find the channel for the current secondary address and select its partition. SAs above 18
; wrap to 0-15; SA 15 is channel 16 internally. C = 1 if the SA is not open.
get_chan_for_sa
        lda cur_sa
        cmp #$13                 ; SA >= $13 wraps
        bcc get_chan_special_sa
        and #$0F
get_chan_special_sa
        cmp #$0F                 ; SA 15 = the command channel
        bne get_chan_lookup
        lda #$10
get_chan_lookup
        tax
        sec
        lda sa_chan,x            ; bit 7 clear = open
        bmi get_chan_return

; --- set_chan_part: Select the channel's partition and its directory
; Select the partition of channel A (channels 30 and 31 use the default partition).
set_chan_part
        and #$3F
        sta cur_chan
        tax
        cmp #$1F
        beq set_chan_part_use_default_partition
        cmp #$1E
        bne set_chan_part_use_channel_partition
set_chan_part_use_default_partition
        lda default_part
        jmp set_chan_part_select
set_chan_part_use_channel_partition
        lda chan_part,x
set_chan_part_select
        jsr select_partition
        lda cur_chan
        clc
get_chan_return
        rts

; --- get_chan_for_sa_rd: Like get_chan_for_sa, but only for read channels
; Like get_chan_for_sa but only for a channel open for reading or writing a file.
get_chan_for_sa_rd
        lda cur_sa
        cmp #$13
        bcc get_chan_rd_lookup
        and #$0F
get_chan_rd_lookup
        tax
        lda sa_chan,x
        tay
        asl
        bcc get_chan_rd_check_write
        bmi get_chan_rd_not_found
get_chan_rd_found
        tya
        jmp set_chan_part
get_chan_rd_check_write
        bmi get_chan_rd_found
get_chan_rd_not_found
        sec
        rts

; --- chan_get_type: A = channel type (state bits 1-3); Z set for sequential
; Channel type (state bits 1-3), Z = 1 for a sequential channel, C = 1 for REL and up.
chan_get_type
        ldx cur_chan
        lda chan_state,x
        lsr
        and #$07
        cmp #$04
        rts

; --- chan_buf_x2: X = 2*buffer number of the channel
; X = 2 * buffer number of the channel's current buffer, Y = channel.
chan_buf_x2
        jsr chan_cur_buf
        asl
        tax
        ldy cur_chan
        rts

; --- alloc_chan_rd: Allocate a read channel
; Allocate a read channel ($80 in sa_chan marks a write channel).
alloc_chan_rd
        sec
        bcs alloc_chan_common

; --- alloc_chan: Allocate buffers and a channel number for the secondary address
; Allocate the channel for the current secondary address and tmp_a buffers (1 or 2) for it.
alloc_chan
        clc
alloc_chan_common
        php                      ; free the SA if it was open
        sta tmp_a
        jsr release_chan
        jsr find_free_chan       ; take a free channel number
        lda cur_part
        sta chan_part,x
        txa
        ldx cur_sa
        plp
        bcc alloc_chan_store_sa_entry ; C set = write channel, mark the SA entry
        ora #$80
alloc_chan_store_sa_entry
        sta sa_chan,x
        and #$3F
        tay
        jsr chan_clear_bufs
        dec tmp_a                ; how many buffers wanted
        bmi alloc_chan_done
        jsr buf_alloc            ; get a buffer
        bpl alloc_chan_first_buffer_ok
no_buffer_error                  ; no buffer: error 70 NO CHANNEL
        jsr chan_clear_bufs
        lda #$70
        jmp dos_error_00
alloc_chan_first_buffer_ok
        sta chan_buf,y
        dec tmp_a
        bmi alloc_chan_done
        jsr buf_alloc
        bmi no_buffer_error
        sta chan_buf2,y
alloc_chan_done
        rts

; --- release_chan: Release the channel for the current secondary address
; Release the channel of the current secondary address and free its buffers (SA 15 is never
; released).
release_chan
        lda cur_sa
        cmp #$0F
        bne release_chan_release
release_chan_done
        rts
release_chan_release
        tax
        lda sa_chan,x
        cmp #$FF
        beq release_chan_done
        and #$3F
        sta cur_chan
        lda #$FF
        sta sa_chan,x
        ldx cur_chan
        lda #$00
        sta chan_flags,x
        jmp chan_clear_bufs

; --- release_part_chans: Release all channels of the current partition
; Release every channel that belongs to the current partition.
release_part_chans
        lda #$0E
        sta cur_sa
release_part_sa_loop
        ldx cur_sa
        lda sa_chan,x
        cmp #$FF
        beq release_part_next_sa
        and #$3F
        sta cur_chan
        tax
        lda chan_part,x
        cmp cur_part
        bne release_part_next_sa
        jsr release_chan
release_part_next_sa
        dec cur_sa
        bpl release_part_sa_loop
        rts

; --- find_free_chan: Find a free channel number
; Find a channel number not used by any secondary address.
find_free_chan
        lda #$00
        sta cur_chan
find_free_chan_try_number
        ldx #$12                 ; SA 0-18
find_free_chan_scan_sa_loop
        lda sa_chan,x
        and #$3F
        cmp cur_chan
        beq find_free_chan_next_number
        dex
        bpl find_free_chan_scan_sa_loop
        lda cur_chan
        tax
        rts
find_free_chan_next_number
        inc cur_chan
        lda cur_chan
        cmp #$20
        bcc find_free_chan_try_number
        lda #$70                 ; error 70 NO CHANNEL
        jmp dos_error_00

; --- release_dir_chans: Release the directory channels ($11,$12)
; Release the directory channels 17 and 18.
release_dir_chans
        lda #$11
        sta cur_sa
        jsr release_chan
        lda #$12
        sta cur_sa
        jmp release_chan

; --- swap_chan_bufs: Swap primary and secondary buffers of the channel
; Swap the channel's buffers: the primary and the secondary buffer exchange roles (bit 7
; marks the one currently in use). If the channel has no second buffer one is allocated. After
; the swap the next block of the file is read into the buffer that has just been given up
; (read-ahead), so the next block is ready while the first is being used.
swap_chan_bufs
        ldx cur_chan
        lda chan_buf,x
        bmi swap_bufs_check_second_buffer
        lda chan_buf2,x
swap_bufs_check_second_buffer
        cmp #$FF                 ; $FF = no second buffer
        beq swap_bufs_allocate_second
        lda chan_buf,x           ; toggle the "in use" bits of both buffers
        eor #$80
        sta chan_buf,x
        pha
        lda chan_buf2,x
        eor #$80
        sta chan_buf2,x
        tay
        pla
        bpl swap_bufs_use_primary
        tya
swap_bufs_use_primary
        and #$BF
        tax
        jmp job_wait             ; wait until the job of that buffer is finished
swap_bufs_allocate_second        ; allocate the second buffer
        lda chan_buf,x
        bpl swap_bufs_pick_current
        lda chan_buf2,x
swap_bufs_pick_current
        and #$BF
        tay
        jsr buf_alloc            ; get a free buffer
        bpl swap_bufs_buffer_allocated
        lda #$70                 ; error 70 NO CHANNEL
        jmp dos_error_00
swap_bufs_buffer_allocated
        ldx cur_chan
        ora #$80
        ldy chan_buf,x
        bpl swap_bufs_store_second
        sta chan_buf,x
        bmi swap_bufs_read_link_of_other
swap_bufs_store_second
        sta chan_buf2,x
swap_bufs_read_link_of_other
        lda cur_track            ; read the link bytes of the other buffer
        pha
        lda cur_sector
        pha
        lda #$01                 ; the link is at offset 0/1 of its page
        sta tmp_c
        lda chan_buf,x
        bpl swap_bufs_get_link_sector
        lda chan_buf2,x
swap_bufs_get_link_sector
        and #$BF
        tay
        clc
        adc #$03
        sta tmp_d
        ldy #$00
        lda (tmp_c),y
        sta cur_sector
        lda #$00
        sta tmp_c
        lda chan_buf,x
        bpl swap_bufs_get_link_track
        lda chan_buf2,x
swap_bufs_get_link_track
        and #$BF
        tay
        clc
        adc #$03
        sta tmp_d
        ldy #$00
        lda (tmp_c),y
        sta cur_track
        beq swap_bufs_last_block_flip ; track 0: this was the last block
        jsr chan_get_type        ; only for sequential files
        beq swap_bufs_flip_and_read_ahead
        jsr chan_is_bad          ; if the previous job failed do not read ahead
        bne swap_bufs_flip_and_read_ahead
        jsr swap_chan_bufs2
        jmp swap_bufs_restore_ts
swap_bufs_flip_and_read_ahead    ; swap and start reading the next block
        ldx cur_chan
        lda chan_buf,x
        eor #$80
        sta chan_buf,x
        lda chan_buf2,x
        eor #$80
        sta chan_buf2,x
        jsr job_read_chan_buf
swap_bufs_restore_ts
        pla
        sta cur_sector
        pla
        sta cur_track
        jmp swap_bufs_wait_job
swap_bufs_last_block_flip        ; last block: no read-ahead
        pla
        sta cur_sector
        pla
        sta cur_track
        jsr swap_chan_bufs2
swap_bufs_wait_job
        jsr chan_cur_buf
        tax
        jmp job_wait

; UNREACHABLE CODE ($DC43-$DC47, 5 bytes): never referenced. Error 70 is raised directly where it is needed.
; Not referenced by CMD HD BOOTROM v2.80 or JiffyDOS either.
; --- err_70_no_channel: Error 70: no channel
; Error 70 NO CHANNEL.
err_70_no_channel
        lda #$70
        jmp dos_error_00

; --- swap_chan_bufs2: Swap the channel buffers
; Swap the in-use flags of the two buffers without any job.
swap_chan_bufs2
        ldx cur_chan
        lda chan_buf,x
        eor #$80
        sta chan_buf,x
        lda chan_buf2,x
        eor #$80
        sta chan_buf2,x
        rts

; --- chan_ptr_add: dir_ptr = channel pointer + A
; dir_ptr = the channel's buffer pointer + A (the pointer is advanced as well).
chan_ptr_add
        sta tmp_a
        jsr chan_get_ptr
        clc
        adc tmp_a
        sta buf_ptr_tbl,x
        sta dir_ptr
        rts

; --- chan_clear_bufs: Clear the buffer assignments of the channel
; Forget the channel's buffers ($FF = none).
chan_clear_bufs
        ldx cur_chan
        lda #$FF
        sta chan_buf,x
        sta chan_buf2,x
        sta chan_dirbuf,x
        rts

; --- buf_alloc: Allocate a buffer (waits for the job to complete)
; Allocate a free buffer for a channel. Waits until any job on it is finished and clears it.
buf_alloc
        tya
        pha
        jsr buf_find_free
        bmi buf_alloc_done
buf_alloc_wait_buffer_idle       ; wait until the old job has completed (bit 7 clear)
        lda job_code,x
        bmi buf_alloc_wait_buffer_idle
        lda #$00
        sta job_code,x
        sta job_status,x
        txa
        asl
        tay
        lda #$02                 ; pointer starts at offset 2 (after link bytes)
        sta+2 buf_ptr_tbl,y
buf_alloc_done
        pla
        tay
        txa
        rts

; --- buf_find_free: Find a free buffer number (30 downwards)
; Find a free job buffer number: tries 29 down to 0 (30 and 31 are reserved for the BAM and
; directory). Result in A/X; N set if none is free.
buf_find_free
        lda #$1E
        sta chan_scan_idx
buf_find_free_search_loop
        dec chan_scan_idx
        bmi buf_find_free_done
        jsr buf_in_use
        beq buf_find_free_search_loop
buf_find_free_done
        lda chan_scan_idx
        tax
        rts

; --- buf_in_use: Is buffer $41 in use by any channel?
; Is buffer chan_scan_idx used by any of the 32 channels (first, second or directory buffer)?
; Z = 1 if it is in use.
buf_in_use
        ldx #$1F
buf_in_use_check_channel_loop
        lda chan_buf,x
        and #$1F
        cmp chan_scan_idx
        beq buf_in_use_done
        lda chan_buf2,x
        and #$1F
        cmp chan_scan_idx
        beq buf_in_use_done
        lda chan_dirbuf,x
        and #$1F
        cmp chan_scan_idx
        beq buf_in_use_done
        dex
        bpl buf_in_use_check_channel_loop
buf_in_use_done
        rts

; --- chan_set_ptr: Set the channel's buffer pointer lo = A
; Set the low byte of the current buffer's pointer to A; dir_ptr follows.
chan_set_ptr
        sta tmp_a
        jsr chan_cur_buf
        asl
        tax
        lda tmp_a
        sta buf_ptr_tbl,x
        jmp chan_get_ptr_load_high_byte

; --- chan_get_ptr: dir_ptr = channel's buffer pointer
; dir_ptr = the pointer of the channel's current buffer (also entered from rel_chan_to_ptr).
chan_get_ptr
        jsr chan_cur_buf
chan_ptr_from_buffer
        asl
        tax
chan_get_ptr_load_high_byte
        lda buf_ptr_tbl_hi,x
        sta dir_ptr_hi
        lda buf_ptr_tbl,x
        sta dir_ptr
        rts

; --- chan_get_byte_at: A = byte at offset A... of the channel's buffer
; A = the byte at offset A of the channel's current buffer.
chan_get_byte_at
        sta tmp_c
        jsr chan_cur_buf
        tax
        clc
        adc #$03
        sta tmp_d
        ldy #$00
        lda (tmp_c),y
        rts

; --- chan_cur_buf: A = current buffer number of channel (spare if bit7)
; A = number of the channel's current buffer (the flag bit 7 of chan_buf says which of the two
; buffers is the current one; bit 6 is the modified flag).
chan_cur_buf
        ldx cur_chan
        lda chan_buf,x
        bpl chan_cur_buf_mask_flags
        lda chan_buf2,x
chan_cur_buf_mask_flags
        and #$BF
        rts

; --- chan_cur_buf2: Current buffer number with dirty flag in V
; Same, also returns the modified flag in V and chan_alt_idx = index of the table entry.
chan_cur_buf2
        ldx cur_chan
        stx chan_alt_idx
        lda chan_buf,x
        bpl chan_cur_buf2_store_flags
        txa
        clc
        adc #$20
        sta chan_alt_idx
        lda chan_buf2,x
chan_cur_buf2_store_flags
        sta tmp_b
        and #$1F
        bit tmp_b
        rts

; ---------------------------------------------------------------------------
; UNREACHABLE CODE ($DD18-$DD35, 30 bytes): chan_has_buf and chan_set_buf have no callers (no counterpart in
; CMD HD BOOTROM v2.80, no reference from JiffyDOS). The buffer
; bookkeeping they would do is repeated inline elsewhere (alloc_chan, swap_chan_bufs).
; ---------------------------------------------------------------------------
; --- chan_has_buf: Z set if the channel has no buffers
; Z = 1 if the channel has no buffer at all.
chan_has_buf
        ldx cur_chan
        lda chan_buf,x
        bmi chan_has_buf_compare
        lda chan_buf2,x
chan_has_buf_compare
        cmp #$FF
        rts

; --- chan_set_buf: Mark the channel's buffer as secondary
; Mark buffer A as the channel's second buffer.
chan_set_buf
        ldx cur_chan
        ora #$80
        ldy chan_buf,x
        bpl chan_set_buf_store_second
        sta chan_buf,x
        rts
chan_set_buf_store_second
        sta chan_buf2,x
        rts

; --- cmd_user: U command: U1-UJ, U0 burst
; U command. U1/U2 are block read/write, U3-U8 jump to $0500, $0503 .. $050F (user code), UI
; and U9 reset through the NMI routine, UJ is the hard reset (see ucmd_tbl). "U0>" followed by
; a command byte is a burst command (as on the 1571 and 1581).
cmd_user
        lda cmd_buf+1            ; second character of the command
        cmp #$30                 ; '0': burst command or U0 utility
        beq cmd_user_u0_command
        and #$0F                 ; number of the U command: 1 = U1, ...
        asl
        tay
        dey                      ; index into the vector table
        lda (ucmd_tbl_ptr),y
        sta ucmd_vector_hi
        dey
        lda (ucmd_tbl_ptr),y
        sta ucmd_vector
        jmp cmd_user_run_ucmd
cmd_user_u0_command
        lda cmd_len
        cmp #$03
        bcs cmd_user_u0_burst_dispatch

; --- set_ucmd_table: Point ucmd_tbl_ptr at the U-command table
set_ucmd_table
        lda #<ucmd_tbl
        sta ucmd_tbl_ptr
        lda #>ucmd_tbl
        sta ucmd_tbl_ptr_hi

rts_nop
        rts
cmd_user_u0_burst_dispatch
        sei                      ; no interrupts while the burst bus is used
        jsr get_part_type        ; burst mode comes from the partition type
        cmp #$01
        beq cmd_user_burst_native
        cmp #$04
        beq cmd_user_burst_1581
        cmp #$05
        beq cmd_user_burst_1581
        cmp #$03
        beq cmd_user_burst_1571
        cmp #$02
        beq cmd_user_burst_1571
        jmp err_31_invalid_cmd
cmd_user_burst_native
        lda #$00                 ; native: no special burst mode
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_user_burst_1581
        lda #$80                 ; 1581 burst mode (bit 7)
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_user_burst_1571
        lda #$40                 ; 1571 burst mode (bit 6)
        sta burst_mode
        jsr led_on
        lda #$00
        sta clk_phase            ; CLK phase for the burst handshake
        lda cmd_buf+2            ; the burst command byte
        sta burst_cmd
        and #$1F                 ; low five bits select the routine
        asl
        tax
        lda burst_cmd_tbl,x
        sta ucmd_vector
        lda burst_cmd_tbl+1,x
        sta ucmd_vector_hi
cmd_user_run_ucmd
        jsr call_ucmd            ; run it through the vector
        jmp cmd_complete
; --- call_ucmd: Jump to the selected U-command routine
; Jump to the routine whose address is in ucmd_vector.
call_ucmd
        jmp (ucmd_vector)
; --- ucmd_tbl: U-command vectors (U1,U2,U3..UA ($0500..),UI,UJ)
; U command vectors: U1, U2, U3-U8 ($0500, $0503 ... $050F), U9/UI = NMI, UJ = reset.
ucmd_tbl
        !word u1_parse                  ; $DDA6
        !word u2_parse                  ; $DDA8
        !word $0500                     ; $DDAA
        !word $0503                     ; $DDAC
        !word $0506                     ; $DDAE
        !word $0509                     ; $DDB0
        !word $050C                     ; $DDB2
        !word $050F                     ; $DDB4
        !word nmi_handler                  ; $DDB6
        !word hw_init                  ; $DDB8
; --- burst_cmd_tbl: Burst command -> routine
; Burst commands, selected by the low 5 bits of the command byte: read, write, seek/status,
; format, interleave, inquire, set parameters... The upper 16 entries repeat the same set
; for the extended form with the extra bit.
burst_cmd_tbl
        !word burst_cmd_read                  ; $DDBA
        !word burst_cmd_default                  ; $DDBC
        !word burst_cmd_write_nv                  ; $DDBE
        !word burst_cmd_write                  ; $DDC0
        !word burst_cmd_seek                  ; $DDC2
        !word burst_cmd_default                  ; $DDC4
        !word burst_cmd_format                  ; $DDC6
        !word burst_cmd_format                  ; $DDC8
        !word burst_cmd_interleave                  ; $DDCA
        !word burst_cmd_interleave                  ; $DDCC
        !word burst_cmd_inquire                  ; $DDCE
        !word burst_cmd_default                  ; $DDD0
        !word burst_cmd_setparams                  ; $DDD2
        !word burst_cmd_default                  ; $DDD4
        !word burst_illegal                  ; $DDD6
        !word burst_illegal                  ; $DDD8
        !word burst_cmd_read                  ; $DDDA
        !word burst_cmd_default                  ; $DDDC
        !word burst_cmd_write_nv                  ; $DDDE
        !word burst_cmd_write                  ; $DDE0
        !word burst_cmd_seek                  ; $DDE2
        !word burst_cmd_default                  ; $DDE4
        !word burst_cmd_format                  ; $DDE6
        !word burst_cmd_format                  ; $DDE8
        !word rts_nop                  ; $DDEA
        !word rts_nop                  ; $DDEC
        !word burst_cmd_inquire                  ; $DDEE
        !word burst_cmd_default                  ; $DDF0
        !word burst_cmd_dummy                  ; $DDF2
        !word burst_cmd_dummy                  ; $DDF4
        !word burst_cmd_u0_misc                  ; $DDF6
        !word burst_cmd_load_file                  ; $DDF8
; --- util_signature: '&COPYRIGHT CMD 89' utility launch string
; File name of the boot utility: the HD loads "&COPYRIGHT CMD 89" at power on, when the
; file exists in the system partition.
util_signature
        !text "&COPYRIGHT CMD 89"       ; $DDFA

; --- utility_error_restart: Reset the stack, restore the vectors and warm start
; Error while loading the utility: forget it and continue without it.
utility_error_restart
        ldx saved_sp
        txs
        jsr vectors_restore
        jsr release_dir_chans
        jmp no_boot_utility
; --- utility_load_start: Load the utility ('&COPYRIGHT CMD 89')
; Load the utility named in util_signature (at power-up).
utility_load_start
        jsr vectors_patch
        ldx #$00
util_load_copy_signature_loop
        lda util_signature,x
        sta cmd_buf,x
        inx
        cpx #$11
        bcc util_load_copy_signature_loop
        stx cmd_len

; --- cmd_utility: & command: load and execute a utility
; & command: load and run a utility file. The file has blocks of: 2 bytes load address, 1
; byte length, data, 1 byte checksum. After the last block it jumps to the load address of
; the first block.
cmd_utility
        ldy #$01
        sty name_start
        jsr resolve_specs
        jsr find_entry_first
        lda spec_trk
        bne cmd_utility_file_found
        lda #$39                 ; error 39 FILE NOT FOUND
        jmp dos_error_00
cmd_utility_file_found
        lda #$FF                 ; $FF = first block marker
        sta tmp_85
        lda spec_sec
        sta cur_sector
        lda spec_trk
        sta cur_track
        lda #$03                 ; file type 3 = USR
        jsr dir_open_type
cmd_utility_block_loop
        lda #$00                 ; checksum of this block
        sta checksum
        jsr util_get_byte        ; load address low, high
        sta tmp_87
        jsr util_checksum
        jsr util_get_byte
        sta tmp_88
        jsr util_checksum
        jsr util_get_byte        ; length of the block
        sta checksum+1
        jsr util_checksum
        lda tmp_85               ; first block?
        beq cmd_utility_load_bytes_loop
        lda tmp_88
        pha                      ; remember its start address for the final jump
        lda tmp_87
        pha
cmd_utility_load_bytes_loop
        jsr util_get_byte        ; read a data byte
        ldy #$00
        sty tmp_85
        sta (tmp_87),y           ; store it in RAM
        jsr util_checksum
        inc tmp_87
        bne cmd_utility_block_done
        inc tmp_88
cmd_utility_block_done
        dec checksum+1           ; count down the length
        bne cmd_utility_load_bytes_loop
        jsr get_next_byte        ; then the checksum byte
        lda checksum             ; compare with our sum
        cmp iec_byte
        bne cmd_utility_error_bad_checksum
        lda eoi_flag             ; more blocks follow?
        bne cmd_utility_block_loop
        jsr release_dir_chans
        pla                      ; jump to the start address of the first block
        sta tmp_87
        pla
        sta tmp_88
        jmp (tmp_87)             ; jmp (tmp_87)
cmd_utility_error_bad_checksum
        lda #$50                 ; error 50 (checksum error)
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
cmd_utility_error_unexpected_eof
        lda #$51                 ; error 51 (file ends unexpectedly)
        pha
        jsr ts_from_buf
        pla
        jmp jt_dos_error

; --- util_get_byte: Fetch the next utility byte
; Next byte of the utility file; the file may not end here.
util_get_byte
        jsr get_next_byte
        lda eoi_flag
        beq cmd_utility_error_unexpected_eof
        lda iec_byte
        rts

; --- util_checksum: Add A to the utility checksum
; Add A to the checksum (end around carry).
util_checksum
        clc
        adc checksum
        adc #$00
        sta checksum
        rts

; --- vectors_patch: Patch the error vectors for the utility loader
; Replace the error routines (job_error, dos_error) in the jump table with the utility error
; handler so a failed load can be recovered. The old vectors are saved.
vectors_patch
        lda jt_job_error+1
        sta saved_job_err_vec
        lda jt_job_error+2
        sta saved_job_err_vec+1
        lda jt_dos_error+1
        sta saved_dos_err_vec
        lda jt_dos_error+2
        sta saved_dos_err_vec+1
        ldx #$36                 ; offset of the job_error jump table slot
        jsr vector_default
        ldx #$33                 ; offset of the dos_error slot

; --- vector_default: Install the default vector for slot X
; Point jump table slot X at the utility error handler.
vector_default
        lda #<utility_error_restart
        ldy #>utility_error_restart

; --- set_vector: Patch jump-table slot X with address A/Y (jt_set_vector)
; Set jump table slot X (offset from the first slot) to the address A (low), Y (high). The
; jump table is in write-protected RAM, so the protection is lifted for the write.
set_vector
        pha
        jsr ram_protect_on
        pla
        sta jt_cmd_block+1,x
        tya
        sta jt_cmd_block+2,x
        jmp ram_protect_off

; --- vectors_restore: Restore the original error vectors
; Put the original error vectors back.
vectors_restore
        ldx #$36
        lda saved_job_err_vec
        ldy saved_job_err_vec+1
        jsr set_vector
        ldx #$33
        lda saved_dos_err_vec
        ldy saved_dos_err_vec+1
        jmp set_vector

; --- job_error: Report job error A of job X and abort (jt_job_error)
; Job error: A = job code error ($02-$0F) or a DOS error number, X = job (buffer) number.
job_error
        cmp #$10                 ; an error code below $10 is a job error: map it
        bcs job_error_have_dos_code
        tay
        lda job_err_map,y
job_error_have_dos_code
        pha                      ; keep the DOS number
        txa
        sta cur_buf_idx          ; track/sector of the job go into the error message
        asl
        tay
        lda job_track,y
        sta cur_track
        lda job_sector,y
        sta cur_sector
        lda cmd_class            ; during mount a failed read triggers the mount
        cmp #$00
        bne job_error_report_error
        lda #$FF
        sta cmd_class
        jsr init_partition
job_error_report_error
        pla

; --- dos_error: Report DOS error A and abort the command (jt_dos_error)
; Report a DOS error and abort the command.
dos_error
        jsr set_error
; --- error_restart: Common error exit: reset stack and channels, send status
; Common error exit. Reset the stack, close the directory channels, light the error LED and
; leave through the idle loop so the host can read the error message.
error_restart
        ldx saved_sp             ; back to the stack position from the start of the command
        txs
        jsr cmdbuf_reset
        jsr release_dir_chans
        jsr led_error_on         ; error LED
        lda cur_atn_byte         ; secondary address the command came in on
        and #$0F
        sta cur_sa
        cmp #$0F                 ; channel 15
        beq error_restart_to_idle
        bit bus_flags            ; listener or talker?
        bvs error_restart_listener_channel
        bpl error_restart_talker_channel
        jsr get_chan_for_sa
        jmp error_restart_flush_bam
error_restart_listener_channel
        jsr get_chan_for_sa_rd
        jmp error_restart_flush_bam
error_restart_talker_channel
        tax                      ; SA of the failed command: is the channel open?
        lda sa_chan,x
        cmp #$FF
        beq error_restart_to_idle
        jsr set_chan_part
error_restart_flush_bam
        jsr bam_find_slot        ; the BAM of this partition may be half updated: mark it clean so it is reloaded
        lda #$00
        sta bam_dirty,x
        jsr chan_get_type        ; file channels (not REL...) are closed after an error
        bcs error_restart_to_idle
        jsr release_chan
error_restart_to_idle
        jmp jt_idle_loop
; --- job_err_map: Job error number -> DOS error number
; Job error number ($00-$0F) -> DOS error number: 02 -> 40, 03 -> 41, 04 -> 66, ...
job_err_map
        !byte $00,$00,$40,$41,$66,$44,$45,$46 ; $DF84
        !byte $26,$47,$76,$42,$43,$76,$48,$74 ; $DF8C
; --- err_30_syntax: Syntax error 30
; The syntax errors 30 to 34 share their code; each loads its number and falls through (the
; bytes $2C hide the next LDA).
err_30_syntax
        lda #$30
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- err_31_invalid_cmd: Syntax error 31 (invalid command)
err_31_invalid_cmd
        lda #$31
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- err_32_long_line: Syntax error 32 (line too long)
err_32_long_line
        lda #$32
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- err_33_bad_filename: Syntax error 33 (invalid file name)
err_33_bad_filename
        lda #$33
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- err_34_no_file: Syntax error 34 (no file given)
err_34_no_file
        lda #$34
        jsr set_error_no_ts      ; error without track/sector
        jmp error_restart

; --- status_ok: Report 00,OK
; Report status 00, OK.
status_ok
        jsr led_error_off
        lda #$00

; --- set_error_no_ts: Set error A with track/sector 0
; Set the error A with track and sector 0.
set_error_no_ts
        pha
        lda #$00
        sta cur_track
        sta cur_sector
        pla

; --- set_error: Build the error message for code A with track/sector
; Build the error message in errmsg_buf: "NN,TEXT,TT,SS". For the 4x SCSI errors the sense
; bytes and the block address of the job are added in hex.
set_error
        sta tmp_a
        txa
        pha
        tya
        pha
        lda tmp_a
        ldx #$00
set_error_find_code_loop         ; find the message number in the table
        cmp error_code_tbl,x
        beq set_error_build_message
        inx
        bne set_error_find_code_loop
set_error_build_message
        pha                      ; index * 2 = word index
        txa
        asl
        tax
        lda error_msg_tbl+1,x    ; pointer to the message text
        sta errmsg_ptr_hi
        lda error_msg_tbl,x
        sta errmsg_ptr
        pla
        pha
        ldx #$00                 ; number in hex digits ($00 for ok, as hex digits) at the start of the message
        jsr msg_put_hex_byte
        lda errmsg_buf           ; first character of the message is the first byte the host reads
        sta chan_byte+31
        jsr msg_put_comma        ; comma, then the text
        ldy #$00
set_error_copy_text_loop
        lda (errmsg_ptr),y
        beq set_error_check_scsi_error ; text ends with a zero
        jsr msg_put_char
        iny
        bne set_error_copy_text_loop
set_error_check_scsi_error
        pla
        tay
        and #$F0                 ; errors 40-4F carry SCSI details
        cmp #$40
        bne set_error_append_track_sector
        tya
        pha
        ldy cur_buf_idx
        lda job_lba4,y           ; sense/LBA bytes of the job's buffer
; --- timing_dummy: Address used by BIT instructions as a fixed timing delay
timing_dummy
        jsr msg_put_sp_hex
        lda job_lba3,y
        jsr msg_put_sp_hex
        pla
        cmp #$40
        bne set_error_append_track_sector
        lda job_lba2,y
        jsr msg_put_hex_ts
        lda job_lba1,y
        jsr msg_put_hex_ts
        lda job_lba0,y
        jsr msg_put_hex_ts
set_error_append_track_sector
        lda cur_track            ; track, then sector as decimal numbers
        jsr msg_put_decimal
        lda cur_sector
        jsr msg_put_decimal
        dex
        txa
        clc
        adc #$00
        sta chan_last+31         ; length of the message
        jsr errmsg_reset         ; reset the message pointer, so the host reads from the beginning
        inc errmsg_ptr
        lda #$88                 ; $88 = status channel active
        sta chan_flags+31
        pla
        tay
        pla
        tax
        rts

; --- msg_put_hex_ts: Add a ts digit in hex
; Message building helpers: hex digit, decimal number, space, comma, character. X is the
; position in the message buffer.
msg_put_hex_ts
        jsr msg_put_space
        jsr msg_put_hex_byte
        ldy cur_buf_idx
        rts

; --- msg_put_sp_hex: Add a space and a hex byte
msg_put_sp_hex
        jsr msg_put_space
        jsr msg_put_hex_lo
        ldy cur_buf_idx
        rts

; --- msg_put_hex_byte: Add two hex digits
msg_put_hex_byte
        pha
        lsr
        lsr
        lsr
        lsr
        jsr msg_put_hex_digit
        pla

; --- msg_put_hex_lo: Add a low hex digit
msg_put_hex_lo
        and #$0F

; --- msg_put_hex_digit: Add one hex digit
msg_put_hex_digit
        tay

; --- msg_put_digit: Add the digit character Y
msg_put_digit
        lda hex_digits,y
        jmp msg_put_char

; --- msg_put_decimal: Add the decimal number A
; Add A as up to three decimal digits (after a comma).
msg_put_decimal
        pha
        jsr msg_put_comma
        pla
        cmp #$64
        bcc msg_decimal_tens
        ldy #$64
        jsr msg_dec_digit
msg_decimal_tens
        ldy #$0A
        jsr msg_dec_digit
        ldy #$01

; --- msg_dec_digit: Add one decimal digit
msg_dec_digit
        sty tmp_a
        ldy #$00
msg_dec_digit_subtract_loop
        cmp tmp_a
        bcc msg_dec_digit_emit
        sbc tmp_a
        iny
        bne msg_dec_digit_subtract_loop
msg_dec_digit_emit
        pha
        jsr msg_put_digit
        pla
        rts

; --- msg_put_space: Add a space
msg_put_space
        pha
        lda #$20
        sta errmsg_buf,x
        inx
        pla
        rts

; --- msg_put_comma: Add a comma
msg_put_comma
        lda #$2C

; --- msg_put_char: Add the character A to the message
msg_put_char
        sta errmsg_buf,x
        inx
        rts
; --- hex_digits: '0123456789ABCDEF'
; Hex digits.
hex_digits
        !text "0123456789ABCDEF"        ; $E09D
; --- error_code_tbl: Error numbers in message order
; Error numbers in the order of the messages in error_msg_tbl.
error_code_tbl
        !byte $00,$52,$50,$51,$26,$30,$31,$32,$33,$34 ; $E0AD
        !byte $60,$63,$64,$65,$66,$67,$61,$39,$62,$01 ; $E0B7
        !byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$02 ; $E0C1
        !byte $38,$40,$41,$42,$43,$44,$45,$46,$47,$48 ; $E0CB
; --- error_msg_tbl: Error number -> message text pointer
; Message text pointer for each error number above.
error_msg_tbl
        !word msg_ok                  ; $E0D5
        !word msg_file_too_long                  ; $E0D7
        !word msg_record_not_present                  ; $E0D9
        !word msg_overflow_in_record                  ; $E0DB
        !word msg_write_protect_on                  ; $E0DD
        !word msg_syntax_error                  ; $E0DF
        !word msg_syntax_error                  ; $E0E1
        !word msg_syntax_error                  ; $E0E3
        !word msg_syntax_error                  ; $E0E5
        !word msg_syntax_error                  ; $E0E7
        !word msg_write_file_open                  ; $E0E9
        !word msg_file_exists                  ; $E0EB
        !word msg_file_type_mismatch                  ; $E0ED
        !word msg_no_block                  ; $E0EF
        !word msg_illegal_block                  ; $E0F1
        !word msg_illegal_block                  ; $E0F3
        !word msg_file_not_open                  ; $E0F5
        !word msg_file_not_found                  ; $E0F7
        !word msg_file_not_found                  ; $E0F9
        !word msg_files_scratched                  ; $E0FB
        !word msg_no_channel                  ; $E0FD
        !word msg_directory_error                  ; $E0FF
        !word msg_partition_full                  ; $E101
        !word msg_dos_version                  ; $E103
        !word msg_drive_not_ready                  ; $E105
        !word msg_format_error                  ; $E107
        !word msg_hardware_error                  ; $E109
        !word msg_sel_part_illegal                  ; $E10B
        !word msg_system_error                  ; $E10D
        !word msg_partition_selected                  ; $E10F
        !word msg_dir_not_found                  ; $E111
        !word msg_scsi_error                  ; $E113
        !word msg_status_error                  ; $E115
        !word msg_status_error                  ; $E117
        !word msg_status_error                  ; $E119
        !word msg_controller_error                  ; $E11B
        !word msg_controller_error                  ; $E11D
        !word msg_controller_error                  ; $E11F
        !word msg_controller_error                  ; $E121
        !word msg_illegal_job                  ; $E123
; --- msg_ok: ' OK' [error 00]
; Error message texts (zero terminated). The number is added in front, the track and sector
; behind (see set_error).
msg_ok
        !text " OK"                     ; $E125
        !byte $00                       ; $E128
; --- msg_file_too_long: 'FILE TOO LONG' [error 52]
msg_file_too_long
        !text "FILE TOO LONG"           ; $E129
        !byte $00                       ; $E136
; --- msg_record_not_present: 'RECORD NOT PRESENT' [error 50]
msg_record_not_present
        !text "RECORD NOT PRESENT"      ; $E137
        !byte $00                       ; $E149
; --- msg_overflow_in_record: 'OVERFLOW IN RECORD' [error 51]
msg_overflow_in_record
        !text "OVERFLOW IN RECORD"      ; $E14A
        !byte $00                       ; $E15C
; --- msg_write_protect_on: 'WRITE PROTECT ON' [error 26]
msg_write_protect_on
        !text "WRITE PROTECT ON"        ; $E15D
        !byte $00                       ; $E16D
; --- msg_syntax_error: 'SYNTAX ERROR' [error 30-34]
msg_syntax_error
        !text "SYNTAX ERROR"            ; $E16E
        !byte $00                       ; $E17A
; --- msg_write_file_open: 'WRITE FILE OPEN' [error 60]
msg_write_file_open
        !text "WRITE FILE OPEN"         ; $E17B
        !byte $00                       ; $E18A
; --- msg_file_exists: 'FILE EXISTS' [error 63]
msg_file_exists
        !text "FILE EXISTS"             ; $E18B
        !byte $00                       ; $E196
; --- msg_file_type_mismatch: 'FILE TYPE MISMATCH' [error 64]
msg_file_type_mismatch
        !text "FILE TYPE MISMATCH"      ; $E197
        !byte $00                       ; $E1A9
; --- msg_no_block: 'NO BLOCK' [error 65]
msg_no_block
        !text "NO BLOCK"                ; $E1AA
        !byte $00                       ; $E1B2
; --- msg_illegal_block: 'ILLEGAL BLOCK' [error 66, 67]
msg_illegal_block
        !text "ILLEGAL BLOCK"           ; $E1B3
        !byte $00                       ; $E1C0
; --- msg_file_not_open: 'FILE NOT OPEN' [error 61]
msg_file_not_open
        !text "FILE NOT OPEN"           ; $E1C1
        !byte $00                       ; $E1CE
; --- msg_file_not_found: 'FILE NOT FOUND' [error 62 (and 39)]
msg_file_not_found
        !text "FILE NOT FOUND"          ; $E1CF
        !byte $00                       ; $E1DD
; --- msg_files_scratched: ' FILES SCRATCHED' [error 01]
msg_files_scratched
        !text " FILES SCRATCHED"        ; $E1DE
        !byte $00                       ; $E1EE
; --- msg_no_channel: 'NO CHANNEL' [error 70]
msg_no_channel
        !text "NO CHANNEL"              ; $E1EF
        !byte $00                       ; $E1F9
; --- msg_directory_error: 'DIRECTORY ERROR' [error 71]
msg_directory_error
        !text "DIRECTORY ERROR"         ; $E1FA
        !byte $00                       ; $E209
; --- msg_partition_full: 'PARTITION FULL' [error 72]
msg_partition_full
        !text "PARTITION FULL"          ; $E20A
        !byte $00                       ; $E218
; --- msg_dos_version: 'CMD HD DOS V1.92' [error 73]
msg_dos_version
        !text "CMD HD DOS V1.92"        ; $E219
        !byte $00                       ; $E229
; --- msg_drive_not_ready: 'DRIVE NOT READY' [error 74]
msg_drive_not_ready
        !text "DRIVE NOT READY"         ; $E22A
        !byte $00                       ; $E239
; --- msg_format_error: 'FORMAT ERROR' [error 75]
msg_format_error
        !text "FORMAT ERROR"            ; $E23A
        !byte $00                       ; $E246
; --- msg_hardware_error: 'HARDWARE ERROR' [error 76]
msg_hardware_error
        !text "HARDWARE ERROR"          ; $E247
        !byte $00                       ; $E255
; --- msg_sel_part_illegal: 'SELECTED PARTITION ILLEGAL' [error 77]
msg_sel_part_illegal
        !text "SELECTED PARTITION ILLEGAL" ; $E256
        !byte $00                       ; $E270
; --- msg_system_error: 'SYSTEM ERROR' [error 78]
msg_system_error
        !text "SYSTEM ERROR"            ; $E271
        !byte $00                       ; $E27D
; --- msg_partition_selected: 'PARTITION SELECTED' [error 02]
msg_partition_selected
        !text "PARTITION SELECTED"      ; $E27E
        !byte $00                       ; $E290
; --- msg_scsi_error: 'SCSI ERROR' [error 40]
msg_scsi_error
        !text "SCSI ERROR"              ; $E291
        !byte $00                       ; $E29B
; --- msg_status_error: 'STATUS ERROR' [error 41-43]
msg_status_error
        !text "STATUS ERROR"            ; $E29C
        !byte $00                       ; $E2A8
; --- msg_controller_error: 'CONTROLLER ERROR' [error 44-47]
msg_controller_error
        !text "CONTROLLER ERROR"        ; $E2A9
        !byte $00                       ; $E2B9
; --- msg_illegal_job: 'ILLEGAL JOB' [error 48]
msg_illegal_job
        !text "ILLEGAL JOB"             ; $E2BA
        !byte $00                       ; $E2C5
; --- msg_dir_not_found: 'DIRECTORY NOT FOUND' [error 38]
msg_dir_not_found
        !text "DIRECTORY NOT FOUND"     ; $E2C6
        !byte $00                       ; $E2D9
; The host is not burst capable: nothing to do.
burst_load_no_host
        jmp cmd_complete

; --- burst_cmd_load_file: Burst fast load: find the named file (or '*' = last file) and stream its blocks to the host with the burst protocol
; Burst fast load, U0>$1F + name: finds the file (or "*" = last loaded) and sends it to the
; host with the burst protocol: a status byte, then for each block the byte count and the data,
; and the track/sector link of the next block.
burst_cmd_load_file
        lda bus_flags            ; bus_flags b2: burst capable host
        and #$04
        beq burst_load_no_host
        ldy #$03                 ; file name starts after "U0>" + command byte
        jsr find_separator
        beq burst_load_name_offset
        ldy #$04
burst_load_name_offset
        cpy #$04
        bcc burst_load_store_name_range
        dey
burst_load_store_name_range
        sty name_start
        lda cmd_len
        sta name_start+1
        lda cmd_buf+3
        cmp #$2A                 ; "*" = the last file loaded
        bne burst_load_lookup_by_name
        jsr bam_find_slot
        lda bam_aux,x            ; bam_aux holds its track and sector
        beq burst_load_lookup_by_name
        ldy bam_aux+16,x
        jmp burst_load_start_transfer
burst_load_lookup_by_name
        jsr resolve_one_spec     ; resolve the spec of the single name
        bcs burst_load_fail_not_ready_status
        jsr check_part_valid     ; the partition must be ready
        bne burst_load_fail_not_ready_status
        lda #$01
        sta file_idx
        sta file_count
        jsr find_entry_first     ; find the file
        lda spec_trk             ; not found
        beq burst_load_fail_not_found_status
        lda spec_type            ; only PRG files (type 2), unless extended command bit 7 is set
        and #$03
        cmp #$02
        beq burst_load_remember_file
        bit burst_cmd
        bmi burst_load_remember_file
burst_load_fail_not_ready_status
        lda #$0F                 ; status $0F = drive not ready
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_load_fail_not_found_status
        lda #$02                 ; status $02 = file not found
        pha
        jsr burst_send_byte      ; send the status to the host first
        pla
        cmp #$0F
        beq burst_load_error_drive_not_ready
        lda #$62                 ; then error 62 FILE NOT FOUND...
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_load_error_drive_not_ready
        lda #$74                 ; ...or error 74 DRIVE NOT READY
        jmp dos_error_00
burst_load_remember_file
        jsr bam_find_slot        ; remember the file as "last loaded"
        lda spec_sec
        tay
        sta bam_aux+16,x
        lda spec_trk
        sta bam_aux,x
burst_load_start_transfer
        sta cur_track            ; start the transfer at the first block
        sty cur_sector
        lda #$02                 ; status $02 = ok, start
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_load_next_block            ; following blocks send status $00
        lda #$00
        sta bit_count            ; bit_count = 0 (1 = EOI sent in the last block)
        ldx #$00
        lda #$AA                 ; $AA = read job
        jsr burst_job_check      ; read the block (or fail with a burst error status)
        jsr sr_mode_out          ; shift register to output
        ldy #$01
        lda (buf_ptr_b),y        ; the link bytes: sector first, then track
        sta cur_sector
        dey
        lda (buf_ptr_b),y
        sta cur_track
        bne burst_load_full_block ; track <> 0: another block follows
        lda #$1F                 ; status $1F: last block (the sector byte says how many bytes it has)
        jsr jt_burst_send_byte
        ldx cur_sector           ; bytes in the last block = sector - 1 - 1 (not counting the link bytes)
        dex
        txa
        sec
        sbc bit_count
        jmp burst_load_send_block_length
burst_load_full_block
        ldx #$FE                 ; full block: $FE (254) data bytes
        lda #$00                 ; status byte $00
burst_load_send_block_length     ; send the status byte
        jsr jt_burst_send_byte
        ldy #$02                 ; data starts at offset 2
burst_load_send_data_loop
        lda (buf_ptr_b),y
        jsr jt_burst_send_byte   ; send each byte with the burst protocol (through the jump table)
        iny
        dex
        bne burst_load_send_data_loop
        jsr sr_mode_in           ; back to shift-in mode
        lda cur_track            ; more blocks?
        bne burst_load_next_block
        jmp cmd_complete

; --- burst_job_check: Run the job and abort the burst on error
; Run job A for track/sector X with the burst status: a failure sends status 2 to the host and
; reports the error.
burst_job_check
        pha
        txa
        jsr ts_to_job
        pla
        jsr do_job_status
        cmp #$02                 ; status 0 or 1 = good
        bcs burst_jobcheck_job_failed
        rts
burst_jobcheck_job_failed
        pha
        lda #$02
        jsr burst_send_byte      ; tell the host it failed
        pla
        jmp job_error

; --- burst_status_build: Build the burst status byte
; Build the burst status byte for the host: in 1581 mode the bits are taken from the count
; registers, in 1571 mode the low nibble is the error number.
burst_status_build
        sta burst_tmp
        lda burst_status
        bit burst_mode
        bpl burst_status_build_status_non_1581
        and #$80                 ; bit 7 stays
        ora #$20                 ; bit 5 = always set
        ora burst_tmp
        and burst_count_hi
        ora burst_count_lo
burst_status_build_store_status
        sta burst_status
        lda burst_tmp
        rts
burst_status_build_status_non_1581
        and #$F0                 ; 1571: keep the upper nibble, error number in the lower
        ora burst_tmp
        jmp burst_status_build_store_status

; --- burst_run_job: Run the job A, then continue
; Run job A, then fall through (the BIT skips the next LDA).
burst_run_job
        jsr do_job_status
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- burst_cmd_default: Burst: report status
; "Default" burst command: just report the status.
burst_cmd_default
        lda #$4F                 ; $4F: drive ready and OK

; --- burst_send_status: Burst: send the status byte (job error → error)
; Send the status of a burst command (the job result in A). A real error also raises a DOS
; error unless the extended command bit asks for a status only.
burst_send_status
        jsr burst_status_build
        cmp #$02                 ; status 0 and 1 mean success
        bcc burst_status_out
        bit burst_cmd            ; V (bit 6 of the burst command): status only
        bvs burst_status_out
        jsr burst_status_out
burst_send_status_raise_job_error
        lda burst_tmp
        and #$0F
        ldx #$00
        jmp jt_job_error

; --- burst_status_out: Burst: return the status
burst_status_out
        lda burst_status         ; status byte for the host
        bit burst_mode
        bvc burst_send_byte      ; 1571 mode: error number must not be zero
        and #$0F
        bne burst_status_out_status_ready
        lda #$01
burst_status_out_status_ready
        ora burst_status

; --- burst_send_byte: Send A to the host with the burst protocol (VIA SR out)
; Send A to the host as a burst byte (switches the shift register around the transfer).
burst_send_byte
        pha
        jsr sr_mode_out
        pla
        jsr jt_burst_send_byte
        jmp sr_mode_in

; --- burst_send_byte_raw: Send A: wait for CLK, write the shift register
; Send A with the shift register: wait until CLK changes (the host clocks the bytes), put the
; byte in the shift register and wait for it to be shifted out. ATN aborts.
burst_send_byte_raw
        pha
burst_send_raw_wait_clk_change
        bit ppi_pb               ; ATN on the parallel cable
        bmi burst_atn_abort
        lda via1_prb
        bmi burst_atn_abort      ; ATN on the serial bus
        and #$04
        cmp clk_phase            ; CLK is toggled by the host for every byte
        beq burst_send_raw_wait_clk_change
        sta clk_phase
        pla
        sta via1_sr              ; writing SR starts the shift
        lda #$04
burst_send_raw_wait_sr_done
        bit via1_ifr             ; IFR bit 2 = shift register done
        beq burst_send_raw_wait_sr_done
        rts
burst_atn_abort
        jmp jt_atn_service

; --- burst_get_byte_raw: Receive a byte with the burst protocol
; Receive a byte with the shift register: toggle CLK to ask for it and wait for the shift.
burst_get_byte_raw
        bit via1_sr
        lda via1_prb
        eor #$08                 ; toggle our CLK out (PB3)
        sta via1_prb
        lda #$04
burst_get_raw_wait_sr_byte
        bit ppi_pb
        bmi burst_atn_abort
        bit via1_prb
        bmi burst_atn_abort
        bit via1_ifr
        beq burst_get_raw_wait_sr_byte
        lda via1_sr
        rts

; --- burst_wait_clk: Wait for CLK to change
; Wait until the host changes CLK.
burst_wait_clk
        bit ppi_pb
        bmi burst_atn_abort
        lda via1_prb
        bmi burst_atn_abort
        and #$04
        cmp clk_phase
        beq burst_wait_clk
        sta clk_phase
        rts

; --- burst_send_256: Send 256 bytes from ($68) to the host
; Send 256 or 512 bytes from ($68) with the burst protocol.
burst_send_256
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- burst_send_512: Send 512 bytes from ($68) to the host
burst_send_512
        ldx #$02
burst_send_n_send_pages
        ldy #$00
        jsr sr_mode_out
burst_send_n_send_loop
        lda (buf_ptr_b),y
        jsr jt_burst_send_byte
        iny
        bne burst_send_n_send_loop
        dex
        beq burst_send_n_done
        inc buf_ptr_b_hi
        jmp burst_send_n_send_loop
burst_send_n_done
        jmp sr_mode_in

; --- burst_recv_256: Receive 256 bytes into ($68)
; Receive 256 or 512 bytes into ($68) with the burst protocol, then release CLK.
burst_recv_256
        ldx #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- burst_recv_512: Receive 512 bytes into ($68)
burst_recv_512
        ldx #$02
burst_recv_n_recv_pages
        ldy #$00
        jsr sr_mode_in
burst_recv_n_recv_loop
        jsr jt_burst_get_byte
        sta (buf_ptr_b),y
        iny
        bne burst_recv_n_recv_loop
        dex
        beq burst_recv_n_done
        inc buf_ptr_b_hi
        jmp burst_recv_n_recv_loop
burst_recv_n_done
        jmp bus_clk_out_off

; --- burst_get_ts_from_cmd: Load track/sector from the burst command and set the job
; Get the extension bit and the track/sector from the burst command bytes 3 and 4.
burst_get_ts_from_cmd
        jsr burst_get_ext

; --- burst_get_ts: Burst: copy track/sector from the command bytes
burst_get_ts
        lda cmd_buf+3
        sta cur_track
        lda cmd_buf+4
        sta cur_sector

; --- burst_set_ts: Set the job track/sector and return A=0
; Put the track/sector into the job table (buffer 0).
burst_set_ts
        lda #$00
        jsr ts_to_job
        lda #$00
        rts

; --- burst_get_ext: Burst: copy the extension flag
; Burst command bit 4 = "extended" (the 1581 second side / bank): saved with the job.
burst_get_ext
        lda burst_cmd
        and #$10
        ldx #$00
        sta job_ext,x
        rts

; --- burst_cmd_read: Burst: read sector(s)
; Burst read: sends sectors to the host until the host stops. 1571 mode: one 256 byte sector
; per step, track/sector advance automatically. 1581 mode: 512 byte blocks (job $B2) or counted
; 256 byte sectors.
burst_cmd_read
        bit burst_mode
        bmi burst_read_read_1581_mode
burst_read_read_loop
        lda #$20                 ; bit 5 of the command = no data phase, only send what is already in the buffer
        bit burst_cmd
        bne burst_read_send_sector
        jsr burst_get_ts
        lda #$80                 ; $80 = read job
        jsr burst_run_job
        bit burst_cmd            ; bit 7 of the command = continue without reading
        bmi burst_read_next_track_sector
burst_read_send_sector
        jsr burst_send_256
burst_read_next_track_sector
        jsr burst_next_ts
        jmp burst_read_read_loop ; next track/sector
burst_read_read_1581_mode
        bit burst_cmd
        bmi burst_read_read_with_count
burst_read_read_512_loop
        jsr burst_get_ts_from_cmd
        lda #$B2                 ; $B2 = read a 512 byte block
        jsr burst_run_job
        jsr burst_send_512
        jsr burst_next_sector
        jmp burst_read_read_512_loop
burst_read_read_with_count
        bit burst_count_lo       ; the count in burst_count_lo/hi decides when to stop
        bmi burst_read_finish_status_8d
burst_read_read_count_loop
        jsr burst_get_ts
        lda #$80
        jsr burst_run_job
        jsr burst_send_256
        jsr burst_next_sector
        jmp burst_read_read_count_loop
burst_read_finish_status_8d
        lda #$8D                 ; status $8D = finished
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_read_finish_status_0b
        lda #$0B                 ; status $0B = done
burst_read_send_final_status
        jmp burst_send_status

; --- burst_cmd_write_nv: Burst: write sector(s), no verify
; Burst write (no verify, with verify): receives sectors from the host and writes them.
burst_cmd_write_nv
        lda #$00
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- burst_cmd_write: Burst: write sector(s) with verify
burst_cmd_write
        lda #$4F                 ; $4F = verify requested: status after the write
        sta burst_tmp
        bit burst_mode
        bmi burst_write_write_1581_mode
        bit burst_cmd            ; bit 7: write the data already in the buffer
        bmi burst_write_write_sector
burst_write_receive_sector
        lda #$00                 ; data goes to the first buffer at $0300
        sta buf_ptr_b
        lda #$03
        sta buf_ptr_b_hi
        jsr burst_recv_256       ; receive 256 bytes
burst_write_write_sector
        lda #$20
        bit burst_cmd
        bne burst_write_next_track_sector
        lda burst_tmp
        cmp #$02
        bcs burst_read_send_final_status
        jsr burst_get_ts
        lda #$90                 ; $90 = write job
        jsr burst_run_job
        jsr burst_wait_clk       ; wait for the host's CLK before the next sector
burst_write_next_track_sector
        jsr burst_next_ts
        jmp burst_write_receive_sector
burst_write_write_1581_mode
        bit burst_cmd
        bmi burst_write_write_count_mode
burst_write_write_512_loop
        jsr set_buf_sector
        jsr burst_recv_512
        lda burst_tmp
        cmp #$02
        bcs burst_read_send_final_status
        jsr burst_get_ts_from_cmd
        lda #$B4                 ; $B4 = write a 512 byte block
        jsr burst_run_job
        jsr burst_wait_clk
        jsr burst_next_sector
        jmp burst_write_write_512_loop
burst_write_write_count_mode
        lda #$00
        sta buf_ptr_b
        lda #$03
        sta buf_ptr_b_hi
        jsr burst_recv_256
        lda burst_tmp
        cmp #$02
        bcs burst_read_send_final_status
        jsr burst_get_ts
        lda #$90
        jsr burst_run_job
        jsr burst_wait_clk
        jsr burst_next_sector
        jmp burst_write_write_count_mode

; --- burst_cmd_seek: Burst: seek / query status
; Burst seek: query the status (job $C0 = bump/check the drive).
burst_cmd_seek
        lda burst_cmd            ; bit 0: extended status, just report the status instead
        lsr
        bcc burst_seek_query_status
        jmp burst_cmd_default
burst_seek_query_status
        lda #$00
        sta burst_status
        ldx #$00
        lda #$C0
        jmp burst_run_job

; --- burst_cmd_setparams: Burst: set parameters
; Burst "set parameters": store the status byte and the count that read and write use.
burst_cmd_setparams
        lda #$20
        bit burst_cmd
        bpl burst_setparams_check_set_flag
        jmp burst_status_out
burst_setparams_check_set_flag
        beq burst_setparams_store_status_byte
        lda cmd_buf+4
        sta burst_count_lo
        lda cmd_buf+5
        sta burst_count_hi
burst_setparams_store_status_byte
        lda cmd_buf+3
        sta burst_status
        rts

; --- burst_cmd_inquire: Burst: inquire disk / read header
; Burst inquire: send drive information. The 1581 form returns 10 bytes of data about the
; disk (sector size 512...).
burst_cmd_inquire
        jsr burst_cmd_seek
        bit burst_mode
        bmi burst_inquire_inquire_1581
        rts
burst_inquire_inquire_1581
        bit burst_cmd
        bpl burst_inquire_no_job_status
        jsr burst_get_ts_from_cmd
        lda #$01
        sta job_sector
        lda #$A8                 ; $A8 = read the header
        jsr do_job_status
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_inquire_no_job_status
        lda #$00
        jsr burst_send_status
        jsr sr_mode_out
        lda #$0A                 ; $0A = number of bytes to follow
        jsr jt_burst_send_byte
        bit burst_cmd
        bpl burst_inquire_send_zero
        lda cmd_buf+3
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_inquire_send_zero
        lda #$00
        jsr jt_burst_send_byte
        lda #$01
        jsr jt_burst_send_byte
        lda #$0A
        jsr jt_burst_send_byte
        lda #$01
        jsr jt_burst_send_byte
        lda burst_cmd
        and #$20
        beq burst_inquire_done
        ldx #$01
burst_inquire_send_info_loop
        txa
        jsr jt_burst_send_byte
        inx
        cpx #$0B
        bcc burst_inquire_send_info_loop
burst_inquire_done
        rts

; --- burst_cmd_format: Burst: format the partition (N0:CMD HD,89)
; Burst format. 1581 mode: check the parameters in the command and format with the new
; command. Other modes answer with a status only.
burst_cmd_format
        lda #$01
        bit burst_cmd            ; bit 0: unsupported variant
        beq burst_format_check_mode
        lda #$4F                 ; status $4F
        jsr burst_status_build
        jmp burst_send_status_raise_job_error
burst_format_check_mode
        bit burst_mode
        bmi burst_format_check_1581_params
        bit cmd_buf+3            ; bit 7 of the first parameter: not allowed
        bmi burst_format_bad_param_status
        lda #$01
        jmp burst_status_build
burst_format_bad_param_status
        jmp burst_illegal_status
burst_format_check_1581_params
        bmi burst_format_validate_params ; this branch is always taken (N set from BIT burst_mode)
        ; ----- LOGICALLY DEAD CODE ($E642-$E668, 39 bytes including fmt_cmd and fmt_cmd_id) -----
        ; The BMI above is always taken (it tests N, set by the BIT in the code before this routine), so the
        ; code that follows can never run. It would copy "N0:CMD HD" and ",89" into the command buffer and call
        ; the NEW command for a burst format. The text it reads (fmt_cmd, fmt_cmd_id) is dead with it.
        ldx #$00
burst_format_build_new_command_unused ; (never reached) would build "N0:CMD HD,89" and format
        lda fmt_cmd,x
        sta cmd_buf,x
        inx
        cpx #$0C
        bcc burst_format_build_new_command_unused
        stx cmd_len
        ldx #$01
        stx name_start
        lda #$0A
        sta name_start+1
        dex
        jmp jt_cmd_new
; --- fmt_cmd: 'N0:CMD HD' (format command used by burst format)
; Command text of the burst format: "N0:CMD HD".
fmt_cmd
        !text "N0:CMD HD"               ; $E65D
; --- fmt_cmd_id: ',89' (format ID)
; ID: ",89".
fmt_cmd_id
        !text ",89"                     ; $E666
        ; Defaults used by the burst format ("N0:CMD HD" id ",89", sectors 1-10 per side).
        !byte $02,$4F,$0A               ; $E669
; --- fmt_limits_lo: Burst format parameter lower limits
; Limits of the parameters of a burst format command (lower, upper bounds).
fmt_limits_lo
        !byte $00,$E5,$01               ; $E66C
        !byte $02,$00,$0A               ; $E66F
; --- fmt_limits_hi: Burst format parameter upper limits
fmt_limits_hi
        !byte $00,$00,$01               ; $E672
        !byte $02,$4F,$0A,$4F,$00,$01   ; $E675

; --- burst_illegal: Burst: illegal command, syntax error
; Burst: illegal command. Status $0E (or $06 for a parameter error) and syntax error 31.
burst_illegal
        lda #$0E
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
burst_illegal_status
        lda #$06
        jsr burst_status_build
        jmp err_31_invalid_cmd
burst_format_validate_params     ; check the parameters of the format command against fmt_limits_lo/hi
        ldx #$03
burst_format_param_loop
        cpx cmd_len
        beq burst_format_default_id_loop
        lda cmd_buf,x            ; a parameter below its lower limit
        cmp fmt_limits_lo,x
        bcc burst_illegal
        cmp fmt_limits_hi,x      ; above its upper limit
        bcc burst_format_next_param
        bne burst_illegal
burst_format_next_param
        inx
        bne burst_format_param_loop
burst_format_default_id_loop     ; fill in the default ID if none was given
        cpx #$09
        bcs burst_format_fill_sector_buffer
        lda fmt_cmd_id,x
        sta cmd_buf,x
        inx
        bne burst_format_default_id_loop
burst_format_fill_sector_buffer  ; a data pattern byte (byte 7) fills a 512 byte buffer
        ldx #$00
        lda cmd_buf+7
burst_format_fill_loop
        sta sector_buf,x
        sta sector_buf+256,x
        inx
        bne burst_format_fill_loop
        lda burst_cmd            ; clear the "second side" bit
        and #$EF
        sta burst_cmd
burst_format_format_sector_loop
        lda cmd_buf+6            ; track from the command
        sta cur_track
        lda cmd_buf+8            ; sector from the command
        sta cur_sector
        jsr burst_get_ext        ; extension bit
        jsr burst_set_ts
        lda #$B4                 ; $B4 = write a 512 byte block
        jsr do_job_status
        cmp #$02                 ; status 0 or 1 = ok
        bcc burst_format_next_format_sector
        jmp burst_illegal_status
burst_format_next_format_sector
        inc cmd_buf+8            ; next sector of the track: 1..10
        lda cmd_buf+8
        cmp #$0B
        bcc burst_format_format_sector_loop
        lda #$01                 ; back to sector 1 for the other side of the track
        sta cmd_buf+8
        lda burst_cmd            ; toggle the side bit (burst_cmd b4)
        eor #$10                 ; then continue
        sta burst_cmd
        and #$10
        bne burst_format_format_sector_loop
        inc cmd_buf+6            ; next track
        lda cmd_buf+6
        cmp cmd_buf+4            ; up to the last track in the command
        bcc burst_format_format_sector_loop
        beq burst_format_format_sector_loop
        lda #$00
        jmp burst_status_build

; --- burst_cmd_dummy: Burst: ignore
; "Do nothing" burst commands: only the 1581 mode answers with a status.
burst_cmd_dummy
        bit burst_mode
        bmi burst_dummy_send_ok_status
        rts
burst_dummy_send_ok_status
        lda #$00
        jmp burst_send_status

; --- burst_cmd_u0_misc: U0> utility commands: B (burst on/off), S, R, T/V, M (memory read/write over the burst bus) and a new device number ($04-$1E)
; U0> utility commands (burst command $1E):
;   U0>B0 / U0>B1  switch burst capable host off / on (bus_flags b2)
;   U0>S, U0>R     store a parameter byte
;   U0>T, U0>V     ignored
;   U0>M R/W       read or write memory pages with the burst protocol
;   U0>n           change the device number to n ($04-$1E)
burst_cmd_u0_misc
        sei
        ldx cmd_buf+4            ; parameter byte
        lda cmd_len              ; the command must have 4+ characters
        cmp #$04
        bcs u0_misc_dispatch_subcommand
u0_invalid
        jmp err_31_invalid_cmd
u0_misc_dispatch_subcommand
        lda cmd_buf+3
        cmp #$42                 ; 'B'
        bne u0_misc_test_s
        txa
        cmp #$30                 ; '0' = off
        beq u0_misc_set_burst_flag
        cmp #$31                 ; '1' = on
        bne u0_invalid
u0_misc_set_burst_flag
        pha
        lda bus_flags            ; bus_flags b2 = burst host
        and #$FB
        sta bus_flags
        pla
        and #$01
        asl
        asl
        ora bus_flags
        sta bus_flags
        rts
u0_misc_test_s
        cmp #$53
        bne u0_misc_test_r
        stx dev_unit_tmp         ; 'S': parameter 1
        rts
u0_misc_test_r
        cmp #$52                 ; 'R': parameter 2
        bne u0_misc_test_t_v
        stx dev_unit_tmp2
        rts
u0_misc_test_t_v
        cmp #$54                 ; 'T' and 'V' are ignored
        beq u0_misc_ignore_return
        cmp #$56
        beq u0_misc_ignore_return
        cmp #$4D                 ; 'M' = memory
        bne u0_misc_test_device_number
u0_misc_ignore_return
        rts
u0_misc_test_device_number
        cmp #$4D
        beq u0_misc_memory_command
        cmp #$04                 ; a device number from $04 to $1E
        bcc u0_invalid
        cmp #$1F
        bcs u0_invalid
        ora #$40                 ; talk address = $40 + n
        sta talk_addr
        eor #$60                 ; listen address = $20 + n
        sta listen_addr
        rts
u0_misc_memory_command           ; U0>MR / MW: pages to send or receive
        lda #$00
        sta clk_phase            ; buffer pointer: address high byte from the command, low byte 0
        sta buf_ptr_b
        lda cmd_buf+5
        sta buf_ptr_b_hi
        cpx #$57                 ; 'W'rite or 'R'ead
        beq u0_misc_memory_write
        cpx #$52
        bne u0_invalid
        ldx cmd_buf+6            ; page count
        jmp burst_send_n_send_pages
u0_misc_memory_write
        ldx cmd_buf+6
        jmp burst_recv_n_recv_pages

; --- burst_cmd_interleave: Burst: set interleave
; Burst: set or read the sector interleave (1571 mode only).
burst_cmd_interleave
        bit burst_mode
        bvs burst_interleave_check_read_or_write
burst_interleave_illegal
        jmp burst_illegal
burst_interleave_check_read_or_write
        bit burst_cmd            ; bit 7: read it back
        bmi burst_interleave_send_interleave
        lda cmd_len
        cmp #$04
        bcc burst_interleave_illegal
        lda cmd_buf+3
        sta interleave           ; set the interleave (default 5)
        rts
burst_interleave_send_interleave
        lda interleave
        jmp burst_send_byte

; --- burst_next_sector: Burst: next sector/track (1581 geometry)
; Burst: next sector for the counted 1581 read/write. Counts the sectors down. When the count
; has run out the caller (a JSR) is dropped by pulling its return address and the command ends.
burst_next_sector
        dec cmd_buf+5            ; count - 1
        bne burst_next_sector_increment_sector
        pla                      ; done: drop two return addresses
        pla
        rts
burst_next_sector_increment_sector
        inc cmd_buf+4
        lda cmd_buf+4
        bit burst_cmd
        bpl burst_next_sector_check_sector_limit
        cmp #$28                 ; 40 sectors per track for the 512 byte mode
        bcc burst_next_sector_done
        lda #$00
        sta cmd_buf+4
burst_next_sector_next_track
        inc cmd_buf+3
burst_next_sector_done
        rts
burst_next_sector_check_sector_limit
        cmp #$0B                 ; 10 sectors per side for the 256 byte mode
        bcc burst_next_sector_done
        lda #$01
        sta cmd_buf+4
        lda burst_cmd
        eor #$10                 ; toggle the side
        sta burst_cmd
        and #$10
        beq burst_next_sector_next_track
        rts

; --- burst_next_ts: Burst: next track/sector
; Burst: next track/sector in 1571 mode (zones, interleave) or sequential in other modes.
burst_next_ts
        dec cmd_buf+5
        bne burst_next_ts_compute_next
        pla
        pla
        rts
burst_next_ts_compute_next
        bit burst_mode
        bvc burst_next_ts_increment_native
        ldx #$00
        lda cmd_buf+3
burst_next_ts_zone_search_loop
        cmp zone_start_trk,x     ; find the zone of the track
        bcc burst_next_ts_zone_found
        inx
        bne burst_next_ts_zone_search_loop
burst_next_ts_zone_found
        dex
        lda cmd_buf+4
        clc                      ; sector + interleave
        adc interleave
        cmp zone_sectors,x       ; wrap at the end of the track
        bcc burst_next_ts_store_sector
        sbc zone_sectors,x
burst_next_ts_store_sector
        sta cmd_buf+4
        rts
burst_next_ts_increment_native   ; native: just count up
        inc cmd_buf+4
        bne burst_next_ts_done
        inc cmd_buf+3
        bne burst_next_ts_done
        inc cmd_buf+3
burst_next_ts_done
        rts

; --- do_job: Run job A for buffer X, job error on failure (jt_do_job)
; Run job A on buffer X; if it fails report the error through jt_job_error.
do_job
        jsr do_job_status
        bcs do_job_report_error
        rts
do_job_report_error
        jmp jt_job_error

; --- do_job_status: Run job A for buffer X, return the status (jt_do_job_status)
; Run job A on buffer X and return the status in A. The job is queued and run_jobs is called
; up to led_period times until the job is done (status < 2).
do_job_status
        php                      ; no interrupts while the job queue is handled
        sei
        cpx #$20                 ; buffers 32 and up are not valid
        bcc do_job_status_queue_job
        lda #$0E                 ; error $0E = illegal job
        plp
        cmp #$02
        rts
do_job_status_queue_job
        sta job_code,x           ; job code and its status
        sta job_status,x
        lda led_period           ; retry count from the LED period setting
        and #$3F
        sta led_period_tmp
do_job_status_run_loop
        tya
        pha
        txa
        pha
        jsr run_jobs             ; run all queued jobs
        pla
        tax
        pla
        tay
        lda job_code,x           ; status < 2: done
        cmp #$02
        bcs do_job_status_retry
do_job_status_finish
        plp
        cmp #$02
        rts
do_job_status_retry
        dec led_period_tmp       ; try again?
        bmi do_job_status_finish
        lda job_status,x         ; restore the job code from the saved status
        sta job_code,x
        jmp do_job_status_run_loop

; --- run_jobs: Execute all pending jobs (jt_run_jobs)
; Run all queued jobs: for every buffer with bit 7 set in its job code the handler for the
; opcode is called. The result is written back as job status, and exported to the host queue.
run_jobs
        php
        sei
        jsr jobs_import          ; take over jobs from the host queue
        ldx #$00
run_jobs_job_loop
        lda job_code,x
        bpl run_jobs_next_job
        sta job_opcode           ; current job code and buffer
        stx job_buf_no
        lsr                      ; odd job codes are illegal
        lda #$C2                 ; $C2 = illegal job code
        bcs run_jobs_post_result
        jsr job_dispatch
run_jobs_post_result
        jsr job_post_status      ; convert the SCSI result into a job status
        jsr job_export_status    ; and into the host's job queue
        ldx job_buf_no
run_jobs_next_job
        inx
        cpx #$20
        bcc run_jobs_job_loop
        jsr led_update
        plp
        rts

; --- jobs_import: Import host job queue entries into the job table
; Import jobs from the host job queue ($00-$1F) that were put there by programs written for a
; 1541 (jobs $00-$04, track/sector at $06...) or a 1581 (jobs $02..., track/sector at $0B...).
jobs_import
        jsr get_part_type
        ldx #$00
        cmp #$01                 ; native partitions have no job queue
        beq jobs_import_clear_pending_bits
        cmp #$04                 ; 1541/1571 style queue
        bcc jobs_import_import_1541_queue
        cmp #$06                 ; 1581 style
        bcs jobs_import_clear_pending_bits
jobs_import_import_1581_queue
        lda jobq_base+2,x        ; bit 7 = job pending
        bpl jobs_import_next_1581
        sta job_code,x
        txa
        asl
        tay
        lda+2 jobq_base+11,y     ; track and sector of the job
        sta job_track,y
        lda+2 jobq_base+12,y
        sta job_sector,y
jobs_import_next_1581
        inx
        cpx #$0B                 ; 11 jobs in the 1581 queue
        bcc jobs_import_import_1581_queue
        bcs jobs_import_clear_pending_bits
jobs_import_import_1541_queue
        lda jobq_base,x
        bpl jobs_import_next_1541
        sta job_code,x
        txa
        asl
        tay
        lda+2 jobq_base+6,y
        sta job_track,y
        lda+2 jobq_base+7,y
        sta job_sector,y
jobs_import_next_1541
        inx
        cpx #$05                 ; 5 jobs in the 1541 queue
        bcc jobs_import_import_1541_queue
jobs_import_clear_pending_bits   ; all pending bits are cleared when taken over
        ldx #$0A
jobs_import_clear_loop
        lda jobq_base,x
        and #$7F
        sta jobq_base,x
        dex
        bpl jobs_import_clear_loop
        rts

; --- job_export_status: Export the job result to the host job queue
; Copy the result of the finished job back to the host job queue.
job_export_status
        jsr get_part_type
        ldx job_buf_no
        cmp #$01
        beq job_export_done
        cmp #$04
        bcc job_export_export_1541
        cmp #$06
        bcs job_export_done
        lda job_code,x
        sta jobq_base+2,x
        rts
job_export_export_1541
        lda job_code,x
        sta jobq_base,x
job_export_done
        rts

; --- led_update: Update the error LED / blink the activity LED
; Update the error LED: when the error flag (drive_flags b1) is set it blinks about every 25
; calls, otherwise the latch follows the activity bits.
led_update
        lda #$02
        and drive_flags
        beq led_update_set_latch
        dec led_timer            ; blink timer
        bne led_update_blink_state
        lda #$19
        sta led_timer
        lda ctl_latch            ; toggle the error LED bit of the control latch
        eor #$02
        sta ctl_latch
led_update_blink_state
        lda #$02
led_update_set_latch
        ora #$20                 ; keep the RAM write-enable bit
        and ctl_latch
        eor drive_flags
        eor #$DF
        and #$EF
        sta ctl_latch
        rts

; --- job_dispatch: Dispatch job opcode via tbl_E96F
; Dispatch the job opcode: the opcode is looked up in job_opcode_tbl and the handler is called
; through job_handler_tbl. Unknown opcodes give job error $C1.
job_dispatch
        ldx #$2A                 ; 43 known opcodes
        lda job_opcode
job_dispatch_find_opcode_loop
        cmp job_opcode_tbl,x
        beq job_dispatch_call_handler
        dex
        bpl job_dispatch_find_opcode_loop
        lda #$C1                 ; $C1 = unknown job
        rts
job_dispatch_call_handler
        txa
        asl
        tax
        lda job_handler_tbl,x
        sta vec_tmp
        lda job_handler_tbl+1,x
        sta vec_tmp_hi
        jmp (vec_tmp)
; --- job_opcode_tbl: Job opcodes ($80,$90,$A0.. $F0 and extended) in handler order
; Job opcodes: $80 read, $90 write, $A0 verify, $B0 seek, $C0 bump, $D0 jump, $E0 execute, $F0
; and the rest of the extended codes (1581 and burst style).
job_opcode_tbl
        !byte $80,$90,$A0,$B0,$C0,$D0,$E0,$F0 ; $E944
        !byte $82,$84,$86,$88,$8A,$8C,$8E,$92 ; $E94C
        !byte $94,$96,$98,$9A,$9C,$9E,$A2,$A4 ; $E954
        !byte $A6,$A8,$AA,$AC,$B2,$B4,$B6,$B8 ; $E95C
        !byte $CC,$CE,$EC,$EE,$F2,$F4,$F6,$F8 ; $E964
        !byte $FA,$FC,$FE               ; $E96C
; --- job_handler_tbl: Job opcode -> handler routine
; Job opcode -> handler routine.
job_handler_tbl
        !word job_read                  ; $E96F
        !word job_write                  ; $E971
        !word job_verify                  ; $E973
        !word job_ok                  ; $E975
        !word job_check_range                  ; $E977
        ; $D0 and $E0 (jump / execute): run the code in the job buffer.
        !word job_exec_buffer                  ; $E979
        !word job_exec_buffer                  ; $E97B
        !word job_exec_nop                  ; $E97D
        ; $82: initialise the SCSI interface and the timer.
        !word job_init_scsi                  ; $E97F
        !word job_ok                  ; $E981
        !word job_ok                  ; $E983
        !word job_ok                  ; $E985
        !word job_ok                  ; $E987
        !word job_ok                  ; $E989
        !word job_ok                  ; $E98B
        !word job_ok                  ; $E98D
        ; Opcodes $EC/$EE/$F2/$F4: LED on, off, error LED on, off (used by the host to blink the lamps).
        !word led_on                  ; $E98F
        !word led_off                  ; $E991
        !word led_error_on                  ; $E993
        !word led_error_off                  ; $E995
        !word job_ok                  ; $E997
        !word job_ok                  ; $E999
        !word job_ok                  ; $E99B
        ; $F6 onwards: raw SCSI commands, read/write/verify with the 6 and 10 byte CDBs, mode sense,
        ; inquiry, write protect check, read of the partition information.
        !word job_scsi_cmd_a                  ; $E99D
        !word job_scsi_cmd_b                  ; $E99F
        !word job_seek                  ; $E9A1
        !word job_verify_x28                  ; $E9A3
        !word job_write_verify                  ; $E9A5
        !word job_scsi_read                  ; $E9A7
        !word job_scsi_write                  ; $E9A9
        !word job_wp_check                  ; $E9AB
        !word job_seek_param                  ; $E9AD
        !word job_read_part_info                  ; $E9AF
        !word job_read_part_info2                  ; $E9B1
        !word job_scsi_read_10                  ; $E9B3
        !word job_scsi_write_10                  ; $E9B5
        !word scsi_reset_pulse                  ; $E9B7
        !word scsi_write_cmd                  ; $E9B9
        !word scsi_read_cmd                  ; $E9BB
        !word job_mode_sense                  ; $E9BD
        !word job_inquiry                  ; $E9BF
        !word job_scsi_read_10b                  ; $E9C1
        !word job_scsi_write_10b                  ; $E9C3

; --- job_to_block_write: Convert job track/sector to a block address (write)
; Convert the job's track/sector into a block number: the entry with SEC marks a write (the
; BIT hides the CLC of the second entry). job_dir_flag b7 remembers the direction.
job_to_block_write
        sec
        !byte $24                       ; BIT zp opcode: skips the following 1-byte instruction
; --- job_to_block: Convert job track/sector to a block address (jt_job_to_block)
job_to_block
        clc
        ror job_dir_flag         ; keep the direction flag in b7
        jsr job_load_params      ; get track, sector and extension of the job

; --- job_to_block_a: Block address conversion, range check (error $C0 on overflow)
; Common part: partition of the job, convert for the partition type, then check the range.
job_to_block_a
        jsr job_part_setup
        jsr job_convert_dispatch
        bcc check_block_range    ; C clear: conversion ok
block_out_of_range
        lda #$C0                 ; $C0 = block out of range
        sec
        rts

; --- check_block_range: Check the block number against the partition size
; Check that the block number is inside the partition and add the partition's start block to
; get the absolute 24 bit block number on the SCSI disk.
check_block_range
        ldy job_part
        lda blk_hi               ; block hi against the partition size
        cmp part_size_hi,y
        bcc check_block_range_add_partition_start
        bne block_out_of_range
        lda blk_lo               ; block lo
        cmp part_size_lo,y
        bcs block_out_of_range
check_block_range_add_partition_start
        clc                      ; absolute block = partition start + block
        lda blk_lo
        adc part_start_lo,y
        sta lba_b0
        lda blk_hi
        adc part_start_mid,y
        sta lba_b1
        lda #$00
        adc part_start_hi,y
        sta lba_b2

; --- find_lun: Find the logical unit holding the absolute block
; Find which SCSI unit holds the absolute block. lun_lo/mid/hi hold the first block of each
; unit; the table at $9000 gives the SCSI target and logical unit for it.
find_lun
        ldy #$FF
find_lun_lun_search_loop         ; search through the units
        iny
        lda lba_b2
        cmp lun_lo,y             ; the unit starts above this block: stop
        bcc find_lun_lun_found
        bne find_lun_lun_search_loop
        lda lba_b1
        cmp lun_mid,y
        bcc find_lun_lun_found
        bne find_lun_lun_search_loop
        lda lba_b0
        cmp lun_hi,y
        bcs find_lun_lun_search_loop
find_lun_lun_found
        dey                      ; the previous unit holds the block
        lda $9000,y              ; SCSI target ID/LUN of the unit ($9000 table; bit 7 = unit not available)
        bmi block_out_of_range   ; not available: block out of range
        ldx job_buf_no
        jsr job_split_nibbles    ; split the target and LUN fields into the job's CDB fields
        sec                      ; block number within the unit = absolute block - start of the unit
        lda lba_b0
        sbc lun_hi,y
        sta job_lba0,x
        lda lba_b1
        sbc lun_mid,y
        sta job_lba1,x
        lda lba_b2
        sbc lun_lo,y
        sta job_lba2,x

; --- job_buf_ptr_66: Set ($66) to the job's buffer ($03xx)
; ($66) points at the job's buffer: $0300 + 256 * buffer number.
job_buf_ptr_66
        lda #$00
        sta buf_ptr_a
        lda job_buf_no
        clc
        adc #$03
        sta buf_ptr_a_hi
        clc
job_ptr_done
        rts

; --- job_split_nibbles: Split a byte into two 3-bit fields (LBA 4/3)
; Split the SCSI address byte into the job fields: low 3 bits = target ID (job_lba3), bits
; 4-6 = logical unit (job_lba4).
job_split_nibbles
        pha
        and #$07
        sta job_lba3,x
        pla
        lsr
        lsr
        lsr
        lsr
        and #$07
        sta job_lba4,x
        rts

; --- job_part_setup: Fetch X = job buffer, Y = job partition
; X = job buffer number, Y = partition of the job.
job_part_setup
        ldx job_buf_no
        lda cur_part
        sta job_part
        tay
        rts

; --- job_load_params: Load the job's track/sector/ext into scratch
; Load the job's track, sector and extension byte into the work variables.
job_load_params
        lda job_buf_no
        asl
        tax
        lda job_track,x
        sta job_trk_lo
        lda job_sector,x
        sta job_sec_lo
        lda job_ext,x
        sta job_flags_tmp
        rts

; --- job_convert_dispatch: Dispatch the block conversion for the partition type
; Convert track/sector to a block number with the routine for the partition type
; (conv_handler_tbl). The N flag tells the routine which direction the job has.
job_convert_dispatch
        ldy job_part
        lda part_type,y          ; type 0: nothing to convert
        beq job_ptr_done
        cmp #$FF                 ; $FF = system partition
        bne job_convert_set_type_index
        lda #$00
job_convert_set_type_index
        asl
        tax
        lda conv_handler_tbl,x
        sta vec_tmp
        lda conv_handler_tbl+1,x
        sta vec_tmp_hi
        bit job_dir_flag         ; N = job_dir_flag b7
        jmp (vec_tmp)
; --- conv_handler_tbl: Partition type -> track/sector-to-block converter
; Partition type -> conversion routine. Types 6 and 7 (print buffer, foreign) use the same
; raw conversion as the system partition.
conv_handler_tbl
        !word conv_system                  ; $EAB3
        !word conv_native                  ; $EAB5
        !word conv_1541                  ; $EAB7
        !word conv_1571                  ; $EAB9
        !word conv_1581                  ; $EABB
        !word conv_1581_cpm                  ; $EABD
        !word conv_system                  ; $EABF
        !word conv_system                  ; $EAC1
; --- zone_start_trk: 1541/1571 zone start tracks
; 1541/1571 zones: first track of each zone, number of 256 byte sectors before each zone
; (16 bit, hi/lo), and sectors per track.
zone_start_trk
        !byte $01,$12,$19,$1F,$24,$35,$3C,$42 ; $EAC3
        !byte $47                       ; $EACB
; --- zone_base_hi: Sectors before each zone (hi)
zone_base_hi
        !byte $00,$01,$01,$02,$02,$04,$04,$05 ; $EACC
; --- zone_base_lo: Sectors before each zone (lo)
zone_base_lo
        !byte $00,$65,$EA,$56,$AB,$10,$95,$01 ; $EAD4
; --- zone_sectors: Sectors per track in each zone
zone_sectors
        !byte $15,$13,$12,$11,$15,$13,$12,$11 ; $EADC

; --- conv_system: Convert for a system partition: block = track,sector
; System / raw partitions: track = high byte of the block number, sector = low byte. N set
; means the job already has a 512 byte block address.
conv_system
        bmi conv_direct_block
        lda job_trk_lo
conv_store_and_halve
        jsr conv_store           ; store the 256-byte sector number
        jmp conv_halve_to_512    ; and halve it into a 512-byte block address
conv_direct_block
        lda job_trk_lo           ; direct 512-byte block address

; --- conv_store: Store the block number
; Store the block number in blk_hi/blk_lo.
conv_store
        sta blk_hi
        lda job_sec_lo
        sta blk_lo
        clc
        rts

; --- conv_native: Convert track/sector to a block for a native partition
; Native: block = (track - 1) * 256 + sector.
conv_native
        bmi conv_direct_block
        ldx job_trk_lo
        beq conv_illegal
        dex                      ; tracks start at 1
        txa
        jmp conv_store_and_halve

; --- conv_1541: Convert track/sector to a block for a 1541 partition
; 1541: tracks 1-35 only. The BIT flag N set (a 512 byte job) is illegal.
conv_1541
        bmi conv_illegal
        lda job_trk_lo
        beq conv_illegal
        cmp #$24                 ; 35 tracks
        bcc conv_1571_zone_lookup
conv_illegal
        sec
        rts

; --- conv_1571: Convert track/sector to a block for a 1571 partition
; 1571: tracks 1-70.
conv_1571
        bmi conv_illegal
        lda job_trk_lo
        beq conv_illegal
        cmp #$47                 ; 70 tracks
        bcs conv_illegal
conv_1571_zone_lookup            ; find the zone of the track
        ldx #$00
conv_1571_zone_loop
        cmp zone_start_trk,x
        bcc conv_1571_zone_found
        inx
        bne conv_1571_zone_loop
conv_1571_zone_found
        dex
        lda zone_sectors,x       ; sectors per track in the zone
        cmp job_sec_lo           ; sector number must be below that
        beq conv_illegal
        bcc conv_illegal
        sta lba_tmp              ; multiply by the track's offset into the zone
        txa
        pha
        lda job_trk_lo
        sec
        sbc zone_start_trk,x
        jsr conv_mul             ; (track - first track of zone) * sectors per track
        pla
        tay
        ldx zone_base_hi,y       ; plus the number of sectors before the zone
        lda zone_base_lo,y
        ldy #$00
        jsr conv_add
        lda job_sec_lo           ; plus the sector
        jmp conv_1581_finish_add

; --- conv_1581_cpm: Convert for a 1581 CP/M partition
; 1581 CP/M: a read of track 1 sector 0 (the boot block) is translated to track 40 sector 5.
conv_1581_cpm
        bmi conv_1581_burst_layout
        lda job_opcode           ; job $80 = read
        cmp #$80
        bne conv_1581_linear
        lda job_trk_lo
        cmp #$01
        bne conv_1581_linear
        lda job_sec_lo
        bne conv_1581_linear
        lda #$28                 ; boot block: 40/5
        sta job_trk_lo
        lda #$05
        sta job_sec_lo
        bne conv_1581_linear

; --- conv_1581: Convert track/sector to a block for a 1581 partition
; 1581: block = (track - 1) * 40 + sector.
conv_1581
        bmi conv_1581_burst_layout
conv_1581_linear
        lda #$28                 ; 40 sectors per track
        sta lba_tmp
        ldx job_trk_lo
        beq conv_error
        dex
        txa
        jsr conv_mul
        lda job_sec_lo
        cmp #$28                 ; sector must be below 40
        bcs conv_error
conv_1581_finish_add
        jsr conv_finish
; 256 byte sector number -> 512 byte block: divide by two; the remainder goes into half_flag
; (which half of the 512 byte block).
conv_halve_to_512
        lsr blk_hi
        ror blk_lo
        ror half_flag
        clc
        rts
conv_error
        sec
        rts
; Burst layout of the 1581: 80 tracks of 2 * 10 sectors of 512 bytes (track * 20 + sector - 1
; + 10 for the second side).
conv_1581_burst_layout
        lda job_trk_lo
        cmp #$50                 ; 80 tracks
        bcs conv_error
        lda #$14                 ; 20 blocks per track
        sta lba_tmp
        lda job_trk_lo
        jsr conv_mul
        ldx job_sec_lo
        dex
        txa
        cmp #$0A                 ; sector 1-10
        bcs conv_error
        ldx job_flags_tmp        ; second side flag
        beq conv_finish
        clc
        adc #$0A

; --- conv_finish: Finish the conversion: block = accumulated value
; Finish the 1581 conversion: block = accumulated value.
conv_finish
        jsr conv_add_a
        lda lba_b0
        sta blk_lo
        lda lba_b1
        sta blk_hi
        clc
        rts

; --- conv_clear: Clear the accumulated block number
; Accumulator for the block calculation: clear, add A, add A/X/Y, multiply.
conv_clear
        lda #$00
        sta lba_b0
        sta lba_b1
        sta lba_b2
        rts

; --- conv_add_a: Add A to the accumulated block number
conv_add_a
        ldx #$00
        ldy #$00

; --- conv_add: Add A/X/Y to the accumulated block number
conv_add
        clc
        pha
        adc lba_b0
        sta lba_b0
        txa
        adc lba_b1
        sta lba_b1
        tya
        adc lba_b2
        sta lba_b2
conv_add_pull_and_return
        pla
        rts

; --- conv_mul: Multiply by repeated addition
; lba = A * lba_tmp (by repeated addition).
conv_mul
        ldx #$00
        ldy #$00
        pha
        jsr conv_clear
        lda lba_tmp
        beq conv_add_pull_and_return
        pla
conv_mul_add_loop
        jsr conv_add
        dec lba_tmp
        bne conv_mul_add_loop
        rts

; --- job_post_status: Convert the SCSI result into a job status
; Convert the SCSI result in A into a job status. Status 2 (check condition) is looked at more
; closely with REQUEST SENSE: sense key 1 (recovered error) counts as success.
job_post_status
        cmp #$02
        bne job_post_map_status
        jsr scsi_inquiry         ; get the sense data
        cmp #$00
        bne job_post_map_status
        lda scsi_status+3        ; sense key
        and #$0F
        cmp #$01                 ; 1 = recovered error: ok
        beq job_post_recovered_error_ok
        lda #$02
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
job_post_recovered_error_ok
        lda #$00
job_post_map_status
        ldx #$00
job_post_map_loop
        cmp scsi_status_tbl,x    ; look the status up in scsi_status_tbl
        beq job_post_map_found
        inx
        cpx #$0B
        bcc job_post_map_loop
        lda #$0D                 ; unknown status: job error $0D
        bne job_post_store_status
job_post_map_found
        lda job_error_tbl,x      ; job error number of the CBM job queue
job_post_store_status
        ldx job_buf_no
        cmp #$00                 ; keep the SCSI sense bytes for the error message
        beq job_post_save_job_code
        pha
        lda scsi_status+1
        sta job_lba2,x
        lda scsi_status+3
        sta job_lba1,x
        lda scsi_status+13
        sta job_lba0,x
        pla
job_post_save_job_code
        sta job_code,x           ; job result
        rts
; --- scsi_status_tbl: SCSI sense code values
; SCSI status / sense value -> CBM job error number.
scsi_status_tbl
        !byte $00,$02,$08,$10,$18,$85,$86,$87 ; $EC5E
        !byte $C0,$C1,$C3               ; $EC66
; --- job_error_tbl: Matching CBM job error codes
job_error_tbl
        !byte $00,$02,$03,$0B,$0C,$05,$06,$07 ; $EC69
        !byte $04,$0E,$08               ; $EC71

; --- job_init_scsi: Job: initialise the SCSI interface (bump)
; Job $82: initialise. Starts the 20 ms timer of VIA1 ($4E20 cycles) that drives the job
; queue, forgets the cached sector and sets the LED timers.
job_init_scsi
        lda #$20                 ; timer 1 latch low
        sta $8006
        lda #$4E                 ; timer 1 latch high
        sta $8007
        sta $8005                ; start the timer
        lda via1_acr
        ora #$40                 ; ACR bit 6: free-running
        sta via1_acr
        lda #$FF
        sta cache_lba4           ; $FF = no sector cached
        lda #$19
        sta led_timer
        lda #$01
        sta led_period
        jsr build_parity_table
        lda #$00
        rts

; --- job_read_part_info: Job: read to the job buffer
; Jobs $A6/$A8: read or write the SCSI block of the job into/from the job buffer (used to
; read the partition table).
job_read_part_info
        jsr job_to_block
        bcs job_error_return
        jsr job_set_buf_ptr
        jmp job_read_after_convert

; --- job_read_part_info2: Job: read to buffer then return
job_read_part_info2
        jsr job_to_block
        bcs job_error_return
        jsr job_set_buf_ptr
        jmp job_write_buf

; --- job_set_buf_ptr: Set ($66) to the job's buffer
; ($66) = the buffer address stored in the job table.
job_set_buf_ptr
        ldx job_buf_no
        lda job_bufaddr_lo,x
        sta buf_ptr_a
        lda job_bufaddr_hi,x
        sta buf_ptr_a_hi
        rts

; --- job_verify_x28: Job: verify with SCSI READ
; Job: verify by reading the block from the disk (SCSI READ(10)). Skips the read when the
; wanted block is the one already in the sector buffer.
job_verify_x28
        jsr job_to_block
        bcs job_error_return
        jsr cache_hit            ; is the block already in the sector buffer?
        beq job_verify28_buffer_ready

; --- job_verify_x28_b: Job: verify second half
job_verify_x28_b
        lda #$28                 ; $28 = READ(10)
issue_scsi_command
        jsr scsi_rw_cmd
        bne job_error_return
job_verify28_buffer_ready
        jsr set_buf_half
        lda #$00
job_error_return
        rts

; --- job_write_verify: Job: write then verify
; Job: write a 256 byte sector. Because the disk has 512 byte blocks the block is first read
; (so the other half is kept), the half is replaced, then the block is written ($2A =
; WRITE(10)).
job_write_verify
        jsr job_to_block
        bcs job_error_return
        jsr set_buf_half         ; point at the right half of the sector buffer
        jsr cache_hit            ; is the block in the buffer already?
        beq job_write_verify_write_command
        ldy #$00                 ; save the new data
job_write_verify_save_buffer_loop
        lda (buf_ptr_b),y
        sta sector_buf2,y
        iny
        bne job_write_verify_save_buffer_loop
        jsr job_verify_x28_b     ; read the block from the disk
        cmp #$00
        bne job_error_return
        ldy #$00
job_write_verify_restore_buffer_loop
        lda sector_buf2,y        ; put the new data back into its half
        sta (buf_ptr_b),y
        iny
        bne job_write_verify_restore_buffer_loop
job_write_verify_write_command
        lda #$2A                 ; $2A = WRITE(10)
        bne issue_scsi_command

; --- job_read: Job: read block
; Job $80: read a 256 byte sector. The whole 512 byte block is read into the sector buffer
; (unless it is cached) and the right half is copied into the job buffer.
job_read
        jsr job_to_block
        bcs job_read_done
job_read_after_convert
        jsr cache_hit            ; cached?
        beq job_read_copy_from_cache
        lda #$28                 ; $28 = READ(10)
        jsr scsi_rw_cmd
        bne job_read_done
job_read_copy_from_cache
        jsr set_buf_half         ; point at the right half
job_read_copy_loop
        lda (buf_ptr_b),y        ; copy the 256 bytes to the job buffer at ($66)
        sta (buf_ptr_a),y
        iny
        bne job_read_copy_loop

; --- job_ok: Job: nothing to do, return OK
; Job: nothing to do, report success (also used for the verify and bump codes).
job_ok
        lda #$00
job_read_done
        rts

; --- job_write: Job: write block
; Job $90: write a 256 byte sector (see job_write_verify for the half handling).
job_write
        jsr job_to_block
        bcs job_done_rts

; --- job_write_buf: Write the job buffer to the SCSI sector buffer and issue a write
; Write the job buffer into the right half of the sector buffer and write the block.
job_write_buf
        jsr cache_hit
        beq job_write_buf2
        lda #$28                 ; first read the whole block unless cached, so the other half stays unchanged
        jsr scsi_rw_cmd
        bne job_done_rts

; --- job_write_buf2: Copy the job buffer into the sector buffer
job_write_buf2
        jsr set_buf_half
job_write_buf2_copy_loop
        lda (buf_ptr_a),y
        sta (buf_ptr_b),y
        iny
        bne job_write_buf2_copy_loop
        lda #$2A                 ; $2A = WRITE(10)
        jmp scsi_rw_cmd

; --- job_verify: Job: verify (no-op)
; Job $A0: verify. Nothing is checked, just the block range.
job_verify
        jsr job_to_block
        bcs job_done_rts
        lda #$00
job_done_rts
        rts

; --- job_seek_param: Job: seek with parameter handling
; Job: seek with the sector set to 0.
job_seek_param
        jsr job_load_params
        lda #$00
        sta job_sec_lo
        lsr job_dir_flag
        jsr job_to_block_a
        bcc job_seek_issue_seek
job_seek_param_return
        rts

; --- job_seek: Job: seek
; Job $B0: seek (SCSI SEEK(10), opcode $2B).
job_seek
        jsr job_to_block_write
        bcs job_seek_param_return
job_seek_issue_seek
        lda #$2B
        ldy #$00
        jmp scsi_issue

; --- job_check_range: Job: range-check the block
; Job $C0 (bump): check that block 0 of the partition exists.
job_check_range
        jsr job_part_setup
        lda #$00
        sta blk_hi
        sta blk_lo
        jsr check_block_range
        bcc job_seek_issue_seek
        rts

; --- job_exec_buffer: Job: execute code in the job buffer
; Jobs $D0/$E0: execute the code in the job buffer (the buffer's page is $03xx...).
job_exec_buffer
        jsr job_buf_ptr_66
        jmp (buf_ptr_a)

; --- job_exec_nop: Job: execute (no code)
job_exec_nop
        jsr job_buf_ptr_66
        lda #$00
        rts

; --- job_scsi_cmd_a: Job: SCSI command with a short data phase
; Raw SCSI jobs: READ(10) and WRITE(10) of 512 byte blocks into the buffer at the address in
; the job table. "b" variants use the track/sector bytes as the block address directly
; (carry clear), the others convert track/sector as usual.
job_scsi_cmd_a
        jsr job_setup_3
        jmp job_scsi_read_10b

; --- job_setup_3: Set up the job: buffer $0300, count 1
; Set the job buffer to $0300 and one block.
job_setup_3
        ldx job_buf_no
        lda #$03
        sta job_bufaddr_hi,x
        lda #$00
        sta job_bufaddr_lo,x
        lda #$01
        sta job_count,x
        rts

; --- job_scsi_cmd_b: Job: SCSI command variant
job_scsi_cmd_b
        jsr job_setup_3

; --- job_scsi_write_10: Job: SCSI WRITE(10)
job_scsi_write_10
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- job_scsi_read_10: Job: SCSI READ(10)
job_scsi_read_10
        ldy #$28
        sec
        bcs scsi_rw10_common_setup ; carry set: convert

; --- job_scsi_write_10b: Job: SCSI WRITE(10), alternate
job_scsi_write_10b
        ldy #$2A
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- job_scsi_read_10b: Job: SCSI READ(10), alternate
job_scsi_read_10b
        ldy #$28
        clc
scsi_rw10_common_setup           ; keep the buffer address, opcode and count over the conversion
        ldx job_buf_no
        lda job_bufaddr_hi,x
        pha
        lda job_bufaddr_lo,x
        pha
        tya
        pha
        lda job_count,x          ; block count
        pha
        bcc scsi_rw10_use_job_to_block
        lda job_ext,x            ; raw address: ext = low byte, sector = middle, track = high
        sta lba_b0
        txa
        asl
        tax
        lda job_sector,x
        sta lba_b1
        lda job_track,x
        sta lba_b2
        jsr find_lun             ; find the SCSI unit for it
        jmp scsi_rw10_check_conversion
scsi_rw10_use_job_to_block
        jsr job_to_block_write   ; convert track/sector to a block
scsi_rw10_check_conversion
        bcc scsi_rw10_issue_command
        pla
        pla
        pla
        pla
        lda #$C0                 ; $C0 = block out of range
        rts
scsi_rw10_issue_command
        pla
        tay
        pla
        sec
        jsr scsi_cdb_lba         ; build the 10 byte CDB with the length
        pla
        sta buf_ptr_b            ; the buffer address back into ($68)
        pla
        sta buf_ptr_b_hi
        jmp scsi_issue_cdb       ; run the command

; --- job_scsi_read: Job: SCSI read to the sector buffer
; Jobs $F6/$F8: read or write the 512 byte sector buffer directly.
job_scsi_read
        jsr job_to_block_write
        bcs job_scsi_rw_done
        lda #$28
        bne job_scsi_rw_issue

; --- job_scsi_write: Job: SCSI write from the sector buffer
job_scsi_write
        jsr job_to_block_write
        bcs job_scsi_rw_done
        lda #$2A
job_scsi_rw_issue
        jsr scsi_rw_cmd
        bne job_scsi_rw_done
        jsr set_buf_sector
        lda #$00
job_scsi_rw_done
        rts

; --- job_mode_sense: Job: SCSI MODE SENSE
; Jobs $FE/$FC: SCSI MODE SENSE (6) and INQUIRY.
job_mode_sense
        ldy #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- job_inquiry: Job: SCSI INQUIRY
job_inquiry
        ldy #$00
        lda #$00
        ldx job_buf_no
        sta job_lba2,x
        sta job_lba1,x
        sta job_lba0,x
        lda #$1B                 ; $1B: MODE SENSE or INQUIRY with the LBA clear
        jmp scsi_cmd_with_lba_flag

; --- led_error_on: Flash the error LED
; LED control via the control latch and drive_flags. led_error_on sets the error flag and
; starts the blink timer, led_error_off clears the error and the pending error code, the
; "geos" entry switches the GEOS lamp ($40), led_on and led_off drive the activity lamp.
led_error_on
        lda #$50                 ; pending error $50
        sta pending_err
        lda #$32                 ; blink every $32 timer ticks
        sta led_timer
        lda #$02                 ; b1 = error flag
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_geos_on
        lda #$40
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- led_on: Turn the activity LED on
led_on
        lda #$01
        ora drive_flags
        bne led_on_store_flags

; --- led_error_off: Clear the error LED and its counter
led_error_off
        lda #$00
        sta pending_err
        lda #$FD
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
led_geos_off
        lda #$BF
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- led_off: Turn the activity LED off
led_off
        lda #$FE
        and drive_flags
led_on_store_flags
        sta drive_flags
return_zero
        lda #$00
        rts

; --- job_wp_check: Job: check write protect (C3 if set)
; Job $F8: report error $C3 (write protect) if the drive is write protected (b7).
job_wp_check
        lda #$80
        and drive_flags
        beq return_zero
        lda #$C3
        rts

; --- set_buf_sector: Set ($68) to the 512-byte sector buffer
; Point ($68) at the 512 byte sector buffer at $5000.
set_buf_sector
        ldy #$00
        sty buf_ptr_b
        lda #$50
        sta buf_ptr_b_hi
        rts

; --- set_buf_half: Set ($68) to the proper half of the sector buffer
; Point ($68) at the half of the sector buffer ($5000 or $5100) that holds the sector.
set_buf_half
        ldy #$00
        sty buf_ptr_b
        lda #$50
        sta buf_ptr_b_hi
        bit half_flag
        bpl set_buf_half_done
        inc buf_ptr_b_hi
set_buf_half_done
        rts

; --- cache_hit: Does the cached sector match the requested block? (Z = 1: yes)
; Z = 1 if the 512 byte block of the job is the one already in the sector buffer. The tag is
; the 5 byte block address in cache_lba4.
cache_hit
        ldx job_buf_no
        lda job_lba4,x
        cmp cache_lba4
        bne cache_hit_done
        lda job_lba3,x
        cmp cache_lba4+1
        bne cache_hit_done
        lda job_lba2,x
        cmp cache_lba4+2
        bne cache_hit_done
        lda job_lba1,x
        cmp cache_lba4+3
        bne cache_hit_done
        lda job_lba0,x
        cmp cache_lba4+4
cache_hit_done
        rts

; --- scsi_build_cdb: Build the SCSI command descriptor block
; Build the 6 byte SCSI CDB: opcode in A, Y = length. For the 10 byte form (carry set) the
; block address comes from the job, otherwise the LUN and the length are all there is.
scsi_build_cdb
        php
        pha
        jsr scsi_clear_cdb
        pla
        sta scsi_cdb
        lda #$00
        ldx job_buf_no
        sty scsi_cdb+4           ; byte 4 = transfer length
        plp
        bcc scsi_build_cdb_store_lba_hi
        lda job_lba0,x           ; block address bytes of the job
        sta scsi_cdb+3
        lda job_lba1,x
        sta scsi_cdb+2
        lda job_lba2,x
scsi_build_cdb_store_lba_hi
        sta scsi_cdb+1
        lda job_lba3,x           ; the logical unit goes into the upper three bits of byte 1
        asl
        asl
        asl
        asl
        asl
        ora scsi_cdb+1
        sta scsi_cdb+1
        rts

; --- scsi_clear_cdb: Clear the SCSI CDB area ($2A00-$2A4F)
; Clear the CDB area ($2A00-$2A4F).
scsi_clear_cdb
        lda #$00
        ldx #$4F
scsi_clear_cdb_clear_loop
        sta scsi_cdb,x
        dex
        bpl scsi_clear_cdb_clear_loop

; --- scsi_init_ptrs: Initialise the SCSI buffer pointers
; Set up the SCSI buffers: CDB at $2A00, status at $2A10, sense at $2A30, data at $5000.
scsi_init_ptrs
        ldx #$FF
        stx scsi_status
        stx scsi_sense
        lda #$00
        sta scsi_ptr_a
        lda #$2A
        sta scsi_ptr_a+1
        lda #$10
        sta scsi_ptr_a+2
        lda #$2A
        sta scsi_ptr_a+3
        lda #$30
        sta scsi_ptr_a+4
        lda #$2A
        sta scsi_ptr_a+5
        lda #$00
        sta buf_ptr_b
        lda #$50
        sta buf_ptr_b_hi
        rts

; --- scsi_rw_cmd: Issue a SCSI read/write (A = opcode)
; Issue a SCSI read or write for the sector buffer; on success remember the block as
; cached. The cache tag is invalidated while the command runs.
scsi_rw_cmd
        ldx #$FF
        stx cache_lba4           ; nothing cached while the command is running
        ldy #$01
        jsr scsi_issue
        bne scsi_finish

; --- cache_set: Remember the job's block as the cached block
; Remember the job's block as the block held in the sector buffer.
cache_set
        ldx job_buf_no
        lda job_lba4,x
        sta cache_lba4
        lda job_lba3,x
        sta cache_lba4+1
        lda job_lba2,x
        sta cache_lba4+2
        lda job_lba1,x
        sta cache_lba4+3
        lda job_lba0,x
        sta cache_lba4+4
        lda #$00
scsi_finish
        jmp scsi_store_status

; --- scsi_issue: Issue the SCSI command in A
; Issue the SCSI command A for the job: build the CDB and run it.
scsi_issue
        jsr scsi_cdb_lba
        jmp scsi_issue_cdb

; --- scsi_cdb_lba: Fill the CDB with the block address and length
; Build the 10 byte CDB: opcode in A, transfer length (blocks) in Y, the block address of the
; job (24 bit) in bytes 3-5 and the logical unit in the upper bits of byte 1.
scsi_cdb_lba
        pha
        jsr scsi_clear_cdb
        pla
        ldx job_buf_no
        sta scsi_cdb
        sty scsi_cdb+8           ; number of blocks
        lda job_lba0,x
        sta scsi_cdb+5
        lda job_lba1,x
        sta scsi_cdb+4
        lda job_lba2,x
        sta scsi_cdb+3
        lda job_lba3,x
        asl
        asl
        asl
        asl
        asl
        ora scsi_cdb+1
        sta scsi_cdb+1
        rts

; --- scsi_read_cmd: SCSI READ command
; SCSI read/write helpers for the raw jobs: the CDB is built and issued, flag in C chooses
; the 6 or 10 byte form.
scsi_read_cmd
        lda #$01
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
; --- scsi_write_cmd: SCSI WRITE command
scsi_write_cmd
        lda #$00
        ldy #$00
        clc
        bcc scsi_build_and_issue
        ldy #$01
scsi_cmd_with_lba_flag
        sec
scsi_build_and_issue
        jsr scsi_build_cdb
scsi_issue_cdb
        lda scsi_cdb             ; writes are refused when the drive is write protected (drive_flags b7)
        cmp #$0A                 ; $0A = WRITE(6)
        beq scsi_issue_check_write_protect
        cmp #$2A                 ; $2A = WRITE(10)
        bne scsi_issue_select_target
scsi_issue_check_write_protect
        lda #$80
        and drive_flags
        beq scsi_issue_select_target
        lda #$C3                 ; status $C3 = write protect
        jmp scsi_store_status
scsi_issue_select_target
        ldx job_buf_no           ; select the target (job_lba4 holds the target id)
        lda job_lba4,x
        jsr scsi_select
        bne scsi_wait_done
        lda #$85                 ; $85 = no select (target not there)
        jmp scsi_store_status

; --- scsi_wait_done: Wait for the SCSI command to complete and read the status
; Run the command and read the status.
scsi_wait_done
        jsr scsi_bus_phase       ; go through the bus phases
        cmp #$00
        bne scsi_store_status
        lda scsi_status          ; good: the status byte from the target
scsi_store_status                ; keep the status for the error message
        sta scsi_status
        cmp #$00
        rts

; --- scsi_inquiry: Issue SCSI INQUIRY (read 27 bytes)
; SCSI INQUIRY with 27 bytes of answer (the sense data after a check condition). Uses opcode $03
; (REQUEST SENSE) with allocation length $1B, the data goes to $2A11.
scsi_inquiry
        lda #$03
        ldy #$1B
        clc
        jsr scsi_build_cdb
        lda #$11
        sta buf_ptr_b
        lda #$2A
        sta buf_ptr_b_hi
        jmp scsi_issue_cdb
scsi_release_data_latch
        lda ctl_latch
        and #$EF
        sta ctl_latch

; --- scsi_bus_phase: Handle the SCSI bus phases (data in / out, status, message)
; Follow the SCSI bus phases until the target releases the bus. VIA2 port B: bit 7 = REQ,
; bit 6 = ACK, bit 5 = BSY, bit 2 = I/O, bit 1 = MSG, bit 0 = C/D (the phase). Port A is the data bus,
; with the parity bit from the control latch.
scsi_bus_phase
        lda #$20
scsi_phase_wait_request
        bit via2_prb             ; loop while ACK is still asserted
        bvs scsi_phase_wait_request
        bmi scsi_phase_request_phase ; REQ: the target wants something
        bne scsi_phase_wait_request ; still BSY: wait
        jsr scsi_bus_free        ; BSY released: the command is complete
        lda #$00
        rts
scsi_phase_request_phase
        beq scsi_phase_bus_error_reset ; REQ without BSY: bus error
        lda via2_prb
        and #$07                 ; phase bits
        cmp #$00                 ; 000 = data out (to target)
        bne scsi_phase_test_data_in
        jmp scsi_phase_phase_data_out
scsi_phase_test_data_in
        cmp #$04                 ; 100 = data in
        bne scsi_phase_test_command
        jmp scsi_phase_phase_data_in
scsi_phase_test_command
        cmp #$01                 ; 001 = command
        bne scsi_phase_test_status
        jmp scsi_phase_phase_command
scsi_phase_test_status
        cmp #$05                 ; 101 = status
        bne scsi_phase_test_message
        jmp scsi_phase_phase_status
scsi_phase_test_message
        cmp #$07                 ; 111 = message in
        bne scsi_phase_bad_phase
        jmp scsi_phase_phase_message
scsi_phase_bad_phase
        lda #$87                 ; $87 = illegal phase
        !byte $2C                       ; BIT abs opcode: skips the following 2-byte instruction
scsi_phase_bus_error_reset
        lda #$86                 ; $86 = bus error: reset the bus
        pha
        jsr scsi_reset_pulse
        pla
        rts
; Data out phase: send bytes from ($68) to the target, with parity from the table.
scsi_phase_phase_data_out
        ldy buf_ptr_b
        lda #$00
        sta buf_ptr_b
        lda #$FF
        sta via2_ddra            ; port A as outputs
        lda #$A0                 ; $A0: data bus out, REQ/ACK handshake in hardware
        sta via2_prb
scsi_phase_data_out_loop         ; loop while the phase stays "data out"
        lda via2_prb
        cmp #$A0
        bne scsi_phase_data_phase_end
        lda (buf_ptr_b),y
        eor #$FF                 ; invert (the bus is active low)
        tax
        lda ctl_latch
        and #$EF
        ora parity_tbl,x         ; parity bit for the byte via the control latch bit 4
        sta ctl_latch
        stx via2_pra             ; byte on the bus
        iny
        bne scsi_phase_data_out_loop
        inc buf_ptr_b_hi
        jmp scsi_phase_data_out_loop
scsi_phase_data_phase_end        ; phase over: remember the pointer and release the latch
        sty buf_ptr_b
        jmp scsi_release_data_latch
; Data in phase: read bytes from the target into ($68).
scsi_phase_phase_data_in
        ldy buf_ptr_b
        lda #$00
        sta buf_ptr_b
        sta via2_ddra            ; port A as inputs
        lda #$AC                 ; $AC: data in
        sta via2_prb
scsi_phase_data_in_loop
        lda via2_prb
        cmp #$AC
        bne scsi_phase_data_phase_end
        lda via2_pra             ; read the byte
        eor #$FF
        sta (buf_ptr_b),y
        iny
        bne scsi_phase_data_in_loop
        inc buf_ptr_b_hi
        jmp scsi_phase_data_in_loop
; Command phase: send the CDB at ($E0) byte by byte with the REQ/ACK handshake done by hand
; (the ACK bit is toggled by the write to port B).
scsi_phase_phase_command
        ora #$20
        ldy #$FF
        sty via2_ddra
        iny
        sta via2_prb
        sta job_tmp_55           ; the phase value is saved to detect a phase change
scsi_phase_command_wait_req
        bit via2_prb             ; wait for REQ
        bvs scsi_phase_command_wait_req
        lda job_tmp_55
scsi_phase_command_wait_edge
        cmp via2_prb             ; wait until the phase bits change
        beq scsi_phase_command_wait_edge
        ora #$80                 ; check that REQ is still there
        cmp via2_prb
        bne scsi_phase_abort
        lda (scsi_ptr_a),y
        eor #$FF
        tax
        lda ctl_latch
        and #$EF
        ora parity_tbl,x
        sta ctl_latch
        stx via2_pra             ; byte on the bus
        inc scsi_ptr_a
        bne scsi_phase_command_wait_req
        inc scsi_ptr_a+1
        jmp scsi_phase_command_wait_req
scsi_phase_abort
        jmp scsi_release_data_latch
; Status phase: read the status byte(s) into the buffer at ($E2) (scsi_status).
scsi_phase_phase_status
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta job_tmp_55
scsi_phase_status_wait_req
        bit via2_prb
        bvs scsi_phase_status_wait_req
        lda job_tmp_55
scsi_phase_status_wait_edge
        cmp via2_prb
        beq scsi_phase_status_wait_edge
        ora #$80
        cmp via2_prb
        bne scsi_phase_abort
        lda via2_pra
        eor #$FF
        sta (scsi_ptr_a+2),y
        inc scsi_ptr_a+2
        bne scsi_phase_status_wait_req
        inc scsi_ptr_a+3
        jmp scsi_phase_status_wait_req
; Message phase: read the message byte into ($E4).
scsi_phase_phase_message
        ora #$28
        ldy #$00
        sty via2_ddra
        sta via2_prb
        sta job_tmp_55
scsi_phase_message_wait_req
        bit via2_prb
        bvs scsi_phase_message_wait_req
        lda job_tmp_55
scsi_phase_message_wait_edge
        cmp via2_prb
        beq scsi_phase_message_wait_edge
        ora #$80
        cmp via2_prb
        bne scsi_phase_abort
        lda via2_pra
        eor #$FF
        sta (scsi_ptr_a+4),y
        inc scsi_ptr_a+4
        bne scsi_phase_message_wait_req
        inc scsi_ptr_a+5
        jmp scsi_phase_message_wait_req

; --- scsi_bus_free: Release the SCSI bus (via2 PCR/PRB defaults)
; Release the SCSI bus: all lines off, PCR to its idle setting.
scsi_bus_free
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

; --- scsi_reset_pulse: Pulse the SCSI reset line
; Pulse the SCSI RST line (8255 port C bit 3) for a short time.
scsi_reset_pulse
        jsr scsi_bus_free
        lda ppi_pc
        ora #$08
        sta ppi_pc
        ldx #$28
scsi_reset_pulse_delay
        dex
        bne scsi_reset_pulse_delay
        and #$F7
        sta ppi_pc
        lda #$00
        rts

; --- scsi_select: SCSI select target A (arbitration)
; Select the target A (0-7) with its ID bit and the controller's own ID. Arbitration: wait for
; the bus to become free, put the ID bits on the data bus, assert SEL and wait for the target
; to answer with BSY. Returns Z = 1 if it did not (no such target).
scsi_select
        php
        sei
        tax
scsi_select_wait_bus_free
        lda #$20
        and via2_prb             ; BSY still set?
        beq scsi_select_build_id_mask
        bne scsi_select_wait_bus_free
scsi_select_build_id_mask
        sec                      ; build a bit mask of the target number
scsi_select_shift_id_loop
        rol                      ; shift a 1 into position (target number)
        dex
        bpl scsi_select_shift_id_loop
        ldx #$FF
        stx via2_ddra
        ora cfg_scsi_id          ; plus our own ID
        eor #$FF                 ; invert
        tax
        lda ctl_latch
        and #$EF
        ora parity_tbl,x         ; parity
        sta ctl_latch
        stx via2_pra             ; ID on the bus
        lda #$00
        sta via2_prb
        lda #$FB                 ; assert SEL
        ldx #$10
        sta via2_pcr
        stx via2_prb
        ldx #$00
        ldy #$00
scsi_select_wait_busy_loop       ; wait for BSY from the target (about 0.3 s)
        lda via2_prb
        and #$20
        bne scsi_select_release_select
        dex
        bne scsi_select_wait_busy_loop
        dey
        bne scsi_select_wait_busy_loop
        lda #$DB                 ; time out: release
        sta via2_pcr
        ldx #$54
scsi_select_settle_delay
        dex
        bne scsi_select_settle_delay
        lda via2_prb
        and #$20
scsi_select_release_select
        ldx #$08
        stx via2_prb
        ldx #$DB
        stx via2_pcr             ; release SEL
        plp
        tax                      ; A = 0 means it timed out
        bne scsi_select_done
        jsr scsi_bus_free
        ldx #$00
scsi_select_done
        rts

; --- build_parity_table: Build the SCSI parity helper table at $9300
; Fill the 256 byte table parity_tbl with the SCSI parity bit for each byte value: the bit
; is 1 for an even number of one bits (odd parity).
build_parity_table
        php
        sei
        jsr ctl_latch_save_unlock ; the table lives in write-protected RAM
        ldx #$00
build_parity_parity_loop
        txa
        sta lba_b0
        lsr
        lsr
        lsr                      ; fold the byte to four bits
        lsr
        eor lba_b0
        and #$0F
        tay
        lda parity_nibble_tbl,y  ; parity of the nibble
        sta parity_tbl,x
        inx
        bne build_parity_parity_loop
        jsr ctl_latch_restore
        plp
        rts
; --- parity_nibble_tbl: Parity bit per nibble pattern
parity_nibble_tbl
        !byte $10,$00,$00,$10,$00,$10,$10,$00 ; $F1DE
        !byte $00,$10,$10,$00,$10,$00,$00,$10 ; $F1E6

; --- ser_listen_a: Controller (swap feature): send LISTEN under ATN
; Controller routines for the SWAP 8 / SWAP 9 feature: the HD acts as an IEC controller on the
; serial bus to give a device number to another drive. LISTEN with A = device number.
ser_listen_a
        ora #$20

; --- ser_master_init: Serial master: reset bus and talk to the drive
ser_master_init
        pha
        sei
        jsr bus_data_out_off
        lda #$00
        sta via1_prb
        lda #$7A                 ; $7A: PB1, 3, 4, 5, 6 are outputs while we are controller
        sta via1_ddrb
        pla

; --- ser_send_atn: Controller (swap feature): send a byte under ATN
; Send a byte A under ATN (ATN is PB4, held low by the earlier command).
ser_send_atn
        sei
        pha
        jsr bus_clk_out_on
        jsr bus_data_out_off
        jsr delay_cycles
        lda #$00                 ; ser_state b7 = first byte sent
        sta ser_state
        pla

; --- ser_send_byte: Controller (swap feature): send a byte with full IEC handshake
; Send the byte A on the serial bus with the full handshake.
ser_send_byte
        sei
        sta ser_byte_tmp
        jsr bus_data_out_off
        lda via1_prb
        and #$01                 ; DATA from the other device: is a listener there?
        beq no_listener          ; no: nobody listens
        jsr bus_clk_out_off
        bit ser_state            ; first byte after ATN?
        bpl ser_send_byte_wait_clk_ready
        jsr ser_wait_clk_low
        jsr ser_wait_clk_high    ; wait for CLK high, then low (talker ready sequence)
ser_send_byte_wait_clk_ready
        jsr ser_wait_clk_low
        txa
        pha
        jsr bus_clk_out_on
        ldx #$08                 ; eight data bits to send
ser_send_byte_bit_loop
        lda #$14                 ; about 100 us for the setup of the data line
ser_send_byte_data_setup_delay
        sbc #$01
        bne ser_send_byte_data_setup_delay
        ror ser_byte_tmp         ; next bit
        bcs ser_send_byte_data_bit_one ; C = 1: bit is 1
        jsr bus_data_out_on      ; bit 0: pull DATA
        jmp ser_send_byte_clock_bit
ser_send_byte_data_bit_one
        jsr bus_data_out_off     ; bit 1: release DATA
ser_send_byte_clock_bit
        jsr bus_clk_out_off      ; release CLK = the bit is valid
        lda #$14                 ; hold about 100 us
ser_send_byte_clock_hold_delay
        sbc #$01
        bne ser_send_byte_clock_hold_delay
        lda via1_prb             ; put CLK and DATA back
        and #$FD
        ora #$08
        sta via1_prb
        dex
        bne ser_send_byte_bit_loop
        jsr ser_wait_clk_high    ; wait for the listener's byte acknowledge
        pla
        tax
        clc
        rts
no_listener                      ; no listener: UNLISTEN and return with C set
        jsr ser_unlisten
        sec
        rts
send_unlisten                    ; UNLISTEN
        lda #$3F
        jsr ser_master_init

; --- ser_unlisten: Master: send UNLISTEN
ser_unlisten
        jsr ser_bus_enable
        lda #$14                 ; short delay before the bus is released
release_delay
        sbc #$01
        bne release_delay
        jsr bus_clk_out_off
        jsr bus_data_out_off
        clc
        rts

; --- ser_secondary: Master: send secondary address $6F
; Send secondary address $6F (channel 15, the command channel) to the device just addressed.
ser_secondary
        lda #$6F
        jsr ser_send_atn

; --- ser_bus_enable: Master: enable the bus drivers
; Give the bus lines back to the normal (slave) direction setting.
ser_bus_enable
        lda via1_prb             ; ATN-ack (bit 4) and bit 6 high
        ora #$50
        sta via1_prb
        lda #$3A                 ; $3A: back to the normal output mask
        sta via1_ddrb
ser_done
        rts

; --- swap_remote_devnum: SWAP 8/9: as bus controller, LISTEN to the drive now at the target number and M-W its new listen/talk address (HD's old one) to $0077
; SWAP 8 / SWAP 9: tell the drive that is at the number we are taking over to move to our old
; number. LISTEN to it, open its command channel, send "M-W" to its address $0077 (a 1541
; keeps its device address there) with two bytes: our old listen and talk address.
swap_remote_devnum
        jsr ser_listen_a         ; LISTEN to the other drive
        bcs ser_done             ; no answer: nobody there, give up
        jsr ser_secondary        ; secondary $6F
        bcs ser_done
        ldx #$00                 ; send "M-W", address $0077 and the count 2
swap_remote_send_mw_loop
        lda mw_cmd_bytes,x
        jsr ser_send_byte        ; each byte with the full IEC handshake
        inx
        cpx #$06
        bcc swap_remote_send_mw_loop
        lda listen_addr          ; first data byte: our old listen address
        jsr ser_send_byte
        lda #$80                 ; ser_state b7: this is no longer the first byte after ATN
        sta ser_state
        lda talk_addr            ; second data byte: our old talk address
        jsr ser_send_byte
        jmp send_unlisten        ; UNLISTEN and finish
; --- mw_cmd_bytes: 'M-W' command with address $0077 length 2 (device number)
; "M-W" $0077, two bytes: the memory write that changes a 1541's device number.
mw_cmd_bytes
        !byte $4D,$2D,$57,$77,$00,$02   ; $F2BF

; --- delay_cycles: Software delay loop (preserves A)
; Delay about 700 cycles, keeps A and X.
delay_cycles
        txa
        ldx #$00
delay_cycles_outer_loop
        dex
        bne delay_cycles_outer_loop
        ldx #$90
delay_cycles_inner_loop
        dex
        bne delay_cycles_inner_loop
        tax
        rts

; --- panel_swap_device: Front panel SWAP 8 / SWAP 9: apply the device-number swap
; Apply a pending SWAP 8 / 9 request. A swap that is already active is first undone (lamps off,
; back to the default device number), then the new one is started.
panel_swap_device
        lda cfg_devflags         ; cfg_devflags b7 = a swap is active
        bpl panel_swap_check_request
        and #$7F                 ; the active swap's device number
        sec
        sbc swap_request         ; same as the request?
        bne panel_swap_clear_swap_lamps ; different: undo the old swap first
        sta swap_request         ; same: the request is already in effect, forget it
panel_swap_clear_swap_lamps
        lda drive_flags
        and #$FB                 ; SWAP 8 lamp (b2) off
        and #$F7                 ; SWAP 9 lamp (b3) off
        sta drive_flags
        lda cfg_device           ; back to the default device number
        jsr device_num_apply     ; and apply it
panel_swap_check_request
        ldx swap_request         ; a new request?
        beq panel_swap_done
        cpx #$08                 ; SWAP 8 or SWAP 9?
        bne panel_swap_set_swap9_lamp
        lda #$04                 ; SWAP 8 lamp
        !byte $2C                ; (BIT skips the next LDA)
panel_swap_set_swap9_lamp
        lda #$08                 ; SWAP 9 lamp
        ora drive_flags          ; lamp on in drive_flags
        sta drive_flags
        txa                      ; the device number requested
        ora #$80                 ; with b7 = a swap is active

; --- device_num_apply: Apply the device number (listen/talk addresses)
; Make the device number in A (b7 = swap active) the new one: the other drive is told with
; swap_remote_devnum and our listen and talk addresses change.
device_num_apply
        jsr cfg_set_devflags     ; store the flags (protected RAM)
        and #$7F                 ; device number only
        pha
        jsr swap_remote_devnum   ; tell the other drive our old number
        pla
        ora #$20                 ; listen = $20 + n
        sta listen_addr
        eor #$60                 ; talk = $40 + n
        sta talk_addr
panel_swap_done
        rts

; --- panel_scan: Front panel: SWAP 8 (PB1) / SWAP 9 (PB2) buttons and FPPS (front-panel partition selection: hold WRITE PROTECT ~2 s, then set the 3 digits with WP=ones, SWAP 9=tens, SWAP 8=hundreds; lamps show the digit)
; Front panel scan. A short press of WRITE PROTECT (PB3) toggles the write protect flag
; (drive_flags b7); holding it for about two seconds starts partition selection (FPPS).
; SWAP 8 (PB1) and SWAP 9 (PB2) request a device number swap. The software S-8, S-9 and S-D
; commands arrive here through panel_flags and swap_request.
panel_scan
        php
        sei                      ; no interrupts while the buttons are handled
        lda #$08                 ; PB3 = WRITE PROTECT button (active low)
        and ppi_pb
        bne panel_scan_no_wp_button ; not pressed
        jsr panel_debounce       ; wait and see if it is held down
        bcs panel_scan_fpps_entry ; held for two seconds: FPPS
        lda #$80                 ; short press: toggle the write protect flag
        eor drive_flags
        sta drive_flags
        lda #$00
        sta panel_wp             ; the front panel now owns the protect state
        jmp panel_scan_wait_buttons_released
panel_scan_no_wp_button
        bit panel_flags          ; S-D (swap back to the default number) asked through the DOS
        bmi panel_scan_apply_swap_if_idle
        lda swap_request         ; S-8 or S-9 asked through the DOS
        beq panel_scan_check_swap_buttons
        ora #$80                 ; b7 = swap active, as cfg_devflags stores it
        cmp cfg_devflags         ; already in effect?
        beq panel_scan_wait_buttons_released
        bne panel_scan_apply_swap_if_idle
panel_scan_check_swap_buttons
        lda #$02                 ; PB1 = SWAP 8 button
        and ppi_pb
        beq panel_scan_swap8_pressed
        lda #$04                 ; PB2 = SWAP 9 button
        and ppi_pb
        bne panel_scan_clear_state
        lda #$09                 ; swap 9
        !byte $2C                ; (BIT skips the next LDA)
panel_scan_swap8_pressed
        lda #$08                 ; swap 8
        sta swap_request         ; remember the request
panel_scan_apply_swap_if_idle
        jsr panel_bus_idle       ; the bus must be idle before the device number is changed
        bne panel_scan_wait_buttons_released
        jsr panel_swap_device    ; do the swap
panel_scan_wait_buttons_released
        cli                      ; interrupts on again
        jsr panel_wait_release   ; wait until the buttons are let go
        jsr panel_delay
panel_scan_clear_state
        lda #$00                 ; forget the requests
        sta panel_flags
        sta swap_request
        plp
        rts
panel_scan_fpps_entry            ; WRITE PROTECT held for two seconds: front panel partition selection
        lda drive_flags          ; keep the lamps as they are
        bit fpps_start+1         ; (BIT reads the $01 operand of the LDA below: test whether drive_flags b0 is set)
        bne panel_scan_wait_buttons_released
        pha
        lda #$00                 ; clear the three digits and the last button
        sta tmp_a
        sta tmp_b
        sta tmp_c
        sta tmp_d
fpps_start
        lda #$01                 ; the activity lamp shows that FPPS is active
        sta drive_flags
        cli
        pha
panel_scan_wait_release_show
        jsr panel_wait_release   ; wait for the buttons to be released
panel_scan_restore_lamps
        pla                      ; put the lamp state back
        sta drive_flags
panel_scan_lamp_blink_start
        ldx #$FA                 ; blink: about 250 steps of delay between toggles
panel_scan_blink_wait_loop
        lda ppi_pb               ; read the three buttons (bits 1-3, active low)
        and #$0E
        eor #$0E
        bne panel_scan_button_pressed
        jsr delay_cycles         ; delay one step
        dex
        bne panel_scan_blink_wait_loop
        lda drive_flags          ; toggle the activity lamp
        eor #$01
        sta drive_flags
        jmp panel_scan_lamp_blink_start
panel_scan_button_pressed        ; a button was pressed
        ldx #$01                 ; lamp on
        stx drive_flags
        pha
        jsr panel_debounce       ; debounce, C = held a long time
        pla
        bcs panel_scan_fpps_done ; held long: finished
        lsr                      ; button number: SWAP 8 = 1, SWAP 9 = 2, WP = 4, shifted right once
        cmp #$04
        bcc panel_scan_select_digit
        lda #$03                 ; more than one button: use the ones digit
panel_scan_select_digit
        tax
        cpx tmp_d                ; same button as last time?
        stx tmp_d
        bne panel_scan_increment_digit
        inc panel_count,x        ; yes: count up this digit
panel_scan_increment_digit
        lda panel_count,x        ; digit value
        cmp panel_limits,x       ; beyond its limit?
        bcs panel_scan_wrap_digit
        jsr bcd_digits_to_bin    ; three digits to binary: C set if above 254
        bcc panel_scan_show_digit
panel_scan_wrap_digit
        lda #$00                 ; wrap the digit back to 0
        sta panel_count,x
panel_scan_show_digit
        ldy panel_count,x        ; show the digit on the lamps
        lda panel_dev_bits,y     ; lamp pattern for the digit
        ora #$01                 ; keep the activity lamp bit
        pha
        cpx #$03                 ; WP is the last digit (the ones)
        bne panel_scan_wait_release_show ; other digits: keep going
        jsr panel_wait_none      ; wait until no button is pressed
        beq panel_scan_restore_lamps ; and go on blinking
panel_scan_fpps_done
        pla                      ; finished: restore the lamps
        sta drive_flags
        jsr panel_wait_release   ; wait for the buttons to be released
        plp
        jsr bcd_digits_to_bin    ; the partition number made from the three digits
        bne panel_scan_apply_partition_selection ; non-zero: select it
        lda cfg_def_part         ; 0 = keep the default partition
panel_scan_apply_partition_selection
        jmp cmd_c_cp_set_partition ; set it as the default like the CP command

; --- bcd_digits_to_bin: Convert three decimal digits ($50,$51,$52) to binary
; Convert the three decimal digits (tmp_a hundreds, tmp_b tens, tmp_c ones) to binary. C = 1 or
; a result of $FF means too big (above 254).
bcd_digits_to_bin
        lda #$00                 ; hundreds: add 100 per count
        clc
        ldy tmp_a
bcd_digits_hundreds_loop
        dey
        bmi bcd_digits_tens
        adc #$64
        bne bcd_digits_hundreds_loop
bcd_digits_tens                  ; tens: add 10 per count
        ldy tmp_b
bcd_digits_tens_loop
        dey
        bmi bcd_digits_ones
        adc #$0A
        bcs bcd_digits_done
        bcc bcd_digits_tens_loop
bcd_digits_ones
        adc tmp_c                ; ones
        bcs bcd_digits_done
        cmp #$FF                 ; $FF is not allowed either
bcd_digits_done
        rts
; --- panel_dev_bits: FPPS: digit value 0-9 -> lamp pattern (GEOS/SWAP 8/SWAP 9/WP lamps); entry 9 is the byte at panel_limits
; FPPS: lamp pattern for the digit values 0-9 (four lamps used as a binary number).
panel_dev_bits
        !byte $00,$80,$08,$88,$04,$84,$0C,$8C ; $F41A
        !byte $40                       ; $F422
; --- panel_limits: FPPS: lamp pattern for digit 9 ($C0), then the limits for the hundreds (<3), tens (<10), ones (<10) digits
; Pattern for the digit 9, then the limits for the hundreds (below 3), tens and ones (below 10).
panel_limits
        !byte $C0                       ; $F423
        !byte $03,$0A,$0A               ; $F424

; --- panel_debounce: Wait for the WP button to be released (debounce)
; Wait about two seconds for the WRITE PROTECT button to be released. C = 1 if it stayed down.
panel_debounce
        ldy #$1E                 ; 30 steps of about 70 ms
panel_debounce_wait_loop
        jsr panel_delay
        lda #$08
        and ppi_pb
        bne panel_debounce_released
        dey
        bne panel_debounce_wait_loop
        sec
        !byte $24                ; (BIT skips the next CLC)
panel_debounce_released
        clc
        rts

; --- ser_wait_clk_high: Master: wait for CLK high
; Master helpers: wait for CLK in to go high / low.
ser_wait_clk_high
        lda via1_prb
        ror
        bcc ser_wait_clk_high
        rts

; --- ser_wait_clk_low: Master: wait for CLK low
ser_wait_clk_low
        lda via1_prb
        ror
        bcs ser_wait_clk_low
        rts

; --- panel_bus_idle: Check that the bus is idle
; Is the bus idle (no activity lamp, CLK and DATA released)? Z = 1 if the swap may go on.
panel_bus_idle
        lda #$01
        and drive_flags
        bne panel_bus_idle_done
        lda #$F0
        and via1_prb
        sta via1_prb
        lda via1_prb
        and #$05
panel_bus_idle_done
        rts

; --- panel_delay: Long panel delay
; Panel delay, about 70 ms.
panel_delay
        ldx #$4B
panel_delay_delay_loop
        jsr delay_cycles
        dex
        bne panel_delay_delay_loop
        rts

; --- panel_wait_release: Wait for the buttons to be released
; Wait until all three panel buttons have been released.
panel_wait_release
        jsr panel_delay

; --- panel_wait_none: Wait until no button is pressed
panel_wait_none
        lda ppi_pb
        and #$0E
        eor #$0E
        bne panel_wait_none
        rts

; --- reset: Power-on reset: initialise I/O, copy the system, start the DOS (the manual says power-up diagnostics light the panel lamps in turn: ACTIVITY = serial ports, ERROR = SCSI, GEOS = parallel controller, SWAP 8 = zero page RAM, SWAP 9 = boot ROM, WRITE PROTECT = all RAM)
; Power-on reset: stack, front panel latch, configuration and protected RAM, then the hardware.
reset
        sei                      ; no interrupts, binary mode
        cld
        ldx #$8F                 ; stack at $018F
        txs
        jsr ppi_pc1_on           ; 8255 port C bit 1 on
        lda cfg_device           ; device number from the configuration RAM
        jsr cfg_set_devflags
        lda cfg_dev2             ; second configuration byte
        jsr cfg_set_def_part
        jsr ram_protect_on       ; allow writes to the protected RAM
        lda #$00                 ; no lamps lit
        sta drive_flags
        tax
reset_clear_dir_table_loop       ; forget all current directories of the 256 partitions
        sta part_dir_track,x
        sta part_dir_sector,x
        inx
        bne reset_clear_dir_table_loop

; --- hw_init: Initialise VIA1, VIA2, 8255 and RAM
; Initialise the chips: VIA2 for the SCSI bus, VIA1 for the IEC bus (port B) and the unused
; second port (port A), the 8255 parallel interface; then clear all RAM from $0200 to $7FFF.
hw_init
        sei
        cld
        lda #$DB                 ; SCSI: control lines idle
        sta via2_pcr
        lda #$08                 ; SCSI: output latch
        sta via2_prb
        lda #$18                 ; SCSI: PB3 and PB4 are outputs
        sta via2_ddrb
        lda #$00                 ; SCSI: port A is the data bus, input
        sta via2_ddra
        lda #$00
        sta via2_sr
        lda #$7F                 ; no VIA2 interrupts
        sta via2_ier
        sta via2_ifr
        lda #$FF                 ; VIA1 port A: all lines high (the aux port, unused)
        sta via1_pra_nh
        lda #$3A                 ; VIA1 port A direction: like port B, PA1, 3, 4, 5 outputs
        sta via1_ddra
        lda #$D5                 ; VIA1 port B: IEC lines released
        sta via1_prb
        lda #$3A                 ; VIA1 port B direction: DATA, CLK, ATN-ack, fast-serial direction out
        sta via1_ddrb
        lda #$00                 ; timer 2 for the burst protocol
        sta via1_t2ch
        lda #$05
        sta via1_t2cl
        lda #$7F                 ; no VIA1 interrupts
        sta via1_ier
        sta via1_ifr
        lda #$00                 ; CA1 falling edge: ATN
        sta via1_pcr
        lda #$0C                 ; shift register in under the external clock
        sta via1_acr
        lda #$C6                 ; enable the ATN, shift register and timer 1 interrupts
        sta via1_ier
        lda #$92                 ; 8255 control and port C values; the code at $90F8 lives in the protected RAM and sets the 8255
        ldx #$E2
        jsr $90F8
        lda #$02                 ; clear RAM from $0200 to $7FFF with ($00) as pointer (the zero page is free at this point)
        sta jobq_base+1
        ldy #$00
        sty jobq_base
        tya
hw_init_clear_ram_loop
        sta (jobq_base),y
        iny
        bne hw_init_clear_ram_loop
        inc jobq_base+1
        ldx jobq_base+1
        cpx #$80
        bcc hw_init_clear_ram_loop
        lda #$80                 ; first_boot: the utility file will be loaded after the first start
        sta first_boot

; --- warm_start: Warm start (jt_warm_start): clear state, reload the partition table, init
; Warm start (also U: and an error). Clears the zero page and the stack page, installs the jump
; table, selects the default partition, initialises the channels, resets the SCSI interface and
; mounts the default partition.
warm_start
        sei
        ldy drive_flags          ; keep the lamp and write protect flags
        ldx #$00
        txa
warm_start_clear_zero_page_loop
        sta jobq_base,x          ; clear the zero page and the stack page
        sta stack_base,x
        inx
        bne warm_start_clear_zero_page_loop
        sty drive_flags          ; restore the flags
        ldx #$8F                 ; stack at $018F
        txs
        stx saved_sp             ; remember it for the ATN service
        jsr install_jump_table   ; copy the jump table to $FF00
        lda cfg_def_part         ; default partition from the configuration
        sta default_part
        jsr select_partition     ; select it
        jsr init_channels        ; set up the 32 channels and buffers
        ldy #$32                 ; about half a second wait for the SCSI drives
warm_start_startup_delay
        jsr delay_cycles
        dey
        bne warm_start_startup_delay
        ldx #$00                 ; job $82: initialise the SCSI interface
        lda #$82
        jsr do_job
        ldy #$00                 ; and a short settle delay
warm_start_settle_loop
        dex
        bne warm_start_settle_loop
        dey
        bne warm_start_settle_loop
        jsr init_partition       ; mount the default partition
        bit first_boot           ; first start after power on?
        bpl no_boot_utility
        jmp utility_load_start   ; load the boot utility
no_boot_utility
        lda #$73                 ; error 73: shows the DOS version after reset
        jsr set_error_no_ts
        jsr bus_poll_atn
        jmp jt_idle_loop

; --- init_channels: Initialise the channel tables and the static channels
init_channels
        lda #$FF                 ; $FF = free
        ; Channel setup: all secondary addresses are free, all buffers unassigned, then channels 30 and
        ; 31 are tied to the internal command and directory buffers.
        ldx #$00
init_channels_clear_sa_loop
        sta sa_chan,x
        inx
        cpx #$13
        bcc init_channels_clear_sa_loop
        ldx #$00
init_channels_clear_buf_tables_loop
        sta chan_buf,x
        sta chan_buf2,x
        sta chan_dirbuf,x
        inx
        cpx #$20
        bcc init_channels_clear_buf_tables_loop
        lda #$1E                 ; SA 15 (the command channel) uses channel 30, bit 7 marks it as a write channel
        ora #$80
        sta sa_chan+15
        lda #$1F                 ; SA 16 = channel 31
        sta sa_chan+16
        lda #$01                 ; channel 30 is a write channel
        sta chan_flags+30
        lda #$1E
        sta chan_buf+30
        lda #$88                 ; channel 31 is active
        sta chan_flags+31
        lda #$1F
        sta chan_buf+31
        ldx #$00                 ; every job buffer's pointer: low byte 0, high byte = buffer page ($03, $04, ...)
        ldy #$03
init_channels_init_buf_ptr_loop
        lda #$00
        sta buf_ptr_tbl,x
        inx
        tya
        sta buf_ptr_tbl,x
        iny
        inx
        cpx #$40
        bcc init_channels_init_buf_ptr_loop
        jsr cmdbuf_reset         ; command buffer fill pointer = $0200
        jsr errmsg_reset         ; error message pointer = $2300
        jsr set_ucmd_table       ; U command vector table
        jsr set_dev_addrs        ; listen and talk addresses from the device number
        lda #$02                 ; LED timer: two job tries before an error
        sta led_period
        lda #$04                 ; bus_flags b2: burst capable host
        sta bus_flags
        lda #$01
        sta dev_unit_tmp
        lda #$02
        sta dev_unit_tmp2
        lda #$05                 ; interleave 5 for burst format
        sta interleave
        lda #$00
        sta panel_flags
        sta swap_request
        sta burst_count_lo
        lda #$FF                 ; burst counters: -1
        sta burst_count_hi
        sta lookup_tmp
        rts

; --- cmdbuf_reset: Reset the command buffer pointer
; Command buffer at $0200, fill pointer to the start.
cmdbuf_reset
        lda #$00
        sta cmdbuf_ptr
        lda #$02
        sta cmdbuf_ptr_hi
        rts

; --- errmsg_reset: Reset the error message pointer
; Error message pointer at $2300 (the message buffer).
errmsg_reset
        lda #$00
        sta errmsg_ptr
        lda #$23
        sta errmsg_ptr_hi
        rts

; --- set_dev_addrs: Compute listen/talk addresses from the device number
; Listen = $20 + device number, talk = $40 + device number. The number is taken from the
; configuration; when cfg_devflags b7 is set (a SWAP is active) cfg_device is not used.
set_dev_addrs
        lda cfg_devflags
        bmi set_dev_addrs_mask_device
        lda cfg_device
set_dev_addrs_mask_device
        and #$1F
        ora #$20
        sta listen_addr
        eor #$60
        sta talk_addr
        rts

; --- install_jump_table: Copy the default jump table into place
; Install the default jump table at $FF00: each entry is a JMP followed by its target. The
; table lives in protected RAM, so protection is switched off while copying.
install_jump_table
        php
        sei
        jsr ram_protect_on
        ldx #$00
        ldy #$00
install_jump_copy_vector_loop
        lda jump_table_defaults,x
        sta jt_cmd_block+1,y     ; three bytes per jump table entry: JMP lo hi
        lda jump_table_defaults+1,x
        sta jt_cmd_block+2,y
        iny
        iny
        iny
        inx
        inx
        cpx #$3E                 ; 31 entries
        bcc install_jump_copy_vector_loop
        jsr ram_protect_off
        plp
        rts

; ---------------------------------------------------------------------------
; REACTIVATED BY CMD HD BOOTROM v2.80
; load_part_table, copy_part_entry and sys_read_check (with the 16 byte part_hdr_sig) are never called inside
; this DOS image, but the boot ROM contains the same routines (same signature, same destination tables
; $8200/$8300/$8600/$8700/$8A00/$8B00) and uses them during startup:
;   load_part_table  = BOOTROM $DCB6, called from $D0BC and $E547
;   copy_part_entry  = BOOTROM $DCE7, called from its load_part_table
;   sys_read_check   = BOOTROM $DD4E, called from $D0C7, $D134 and $E697
; The boot ROM reads the partition table and the configuration page into the protected RAM, then hands over
; to the RAM resident DOS by switching the memory map (stub copied to $0100: ALTMAP on, ROMOS off,
; JMP ($FFFC)). The copies left in this image are therefore only used when the boot ROM runs them.
; ---------------------------------------------------------------------------
; --- load_part_table: Read the partition table from the system partition
; Read the partition table from the system partition: 32 blocks of 8 entries each.
load_part_table
        ldx #$00
        jsr wait_job_done
        lda #$00                 ; block counter, also used as the partition block index
        sta job_count
load_part_table_read_block_loop
        jsr read_sys_block       ; read block n of the table
        bcs load_part_table_done
        jsr copy_part_entry
        inc job_count
        lda job_count
        cmp #$20
        bcc load_part_table_read_block_loop
        clc
load_part_table_done             ; no more blocks
        rts

; --- read_sys_block: Read system block n
; Read system block A (sectors are relative to the system partition start).
read_sys_block
        clc
        adc cfg_sys_sector
        sta job_sector
        lda #$00
        tax
        adc cfg_sys_track
        sta job_track
        lda #$AA                 ; $AA = read job
        jmp sys_job

; --- copy_part_entry: Copy one partition table entry into RAM
; Copy the eight 32 byte partition entries of the block just read into the partition tables
; in protected RAM, indexed by partition number. Type at offset 0, size (offsets $1C/$1D),
; start block (offsets $13-$15).
copy_part_entry
        jsr ram_protect_on
        lda job_count
        asl
        asl
        asl
        tax                      ; first partition of this block: block number * 8
        lda #$02
        sta buf_ptr_b            ; first entry starts at offset 2
copy_part_entry_entry_loop
        ldy #$00
        lda (buf_ptr_b),y
        sta part_type,x
        ldy #$1C
        lda (buf_ptr_b),y
        sta part_size_hi,x
        iny
        lda (buf_ptr_b),y
        sta part_size_lo,x
        ldy #$13
        lda (buf_ptr_b),y
        sta part_start_hi,x
        iny
        lda (buf_ptr_b),y
        sta part_start_mid,x
        iny
        lda (buf_ptr_b),y
        sta part_start_lo,x
        inx
        lda buf_ptr_b
        clc
        adc #$20                 ; next entry: 32 bytes further
        sta buf_ptr_b
        bcc copy_part_entry_entry_loop ; until the end of the 256 byte block
        jmp ram_protect_off

; --- sys_read_setup: Set up a system-area read
; Set up a read of the first two sectors (the partition table header) into the 512 byte
; sector buffer at $5000.
sys_read_setup
        jsr wait_job_done
        lda #$50                 ; buffer address $50xx
        sta job_bufaddr_hi,x
        txa
        asl
        tax
        lda #$00
        sta job_track,x          ; track 0
        lda #$02
        sta job_sector,x         ; sector 2: the header block of the system partition
        txa
        lsr
        tax
        lda #$01                 ; one block
        sta job_count,x
        lda #$00
        sta job_bufaddr_lo,x
        lda #$FC                 ; $FC = read 512 bytes raw
        jmp sys_job

; --- sys_read_check: Read and verify the partition table header ('CMD HD')
; Read the partition table header and compare its signature at $51F0 with part_hdr_sig. If it
; matches, the 256 bytes behind it are copied to $9000: the configuration and the code at
; $90F8. C = 1 if there is no valid header.
sys_read_check
        jsr sys_read_setup
        bcc sys_read_check_compare_signature
        rts
sys_read_check_compare_signature
        txa                      ; keep the buffer number
        pha
        ldx #$0F                 ; compare 16 bytes
sys_read_check_compare_loop
        lda part_hdr_id,x
        cmp part_hdr_sig,x
        bne sys_read_check_signature_mismatch
        dex
        bpl sys_read_check_compare_loop
        jsr ram_protect_on
        ldx #$00
sys_read_check_copy_config_loop
        lda sector_buf+256,x     ; configuration page = second half of the sector buffer
        sta $9000,x              ; $9000: protected RAM
        inx
        bne sys_read_check_copy_config_loop
        jsr ram_protect_off
        clc
        !byte $24                ; BIT skips the next SEC
sys_read_check_signature_mismatch
        sec
        pla
        tax
        rts
; --- part_hdr_sig: 'CMD HD  ' partition table header signature
; Signature: "CMD HD" followed by the code at $90F8 (STA $8803, STX $8802, NOP, RTS).
part_hdr_sig
        !byte $43,$4D,$44,$20,$48,$44,$20,$20 ; $F6F4
        !byte $8D,$03,$88,$8E,$02,$88,$EA,$60 ; $F6FC

; --- sys_job: Run job A on buffer X in the system partition
; Run job A on buffer X in the system partition (partition 0, always readable): the current
; partition is saved, set to 0 and restored.
sys_job
        php
        sei
        sta job_code,x
        lda cur_part
        pha
        lda #$00
        jsr cfg_set_part         ; partition 0 = the system partition
        jsr ram_protect_on
        lda job_code,x
        jsr do_job_status        ; run the job and wait
        pla
        jsr cfg_set_part
        jsr ram_protect_off
        lda job_code,x
        plp
        cmp #$02                 ; C = 1 when the job failed (status >= 2)
        rts

; --- wait_job_done: Wait for the job to complete
; Wait until the job of buffer X is finished (bit 7 of the job code clear).
wait_job_done
        pha
        php
        cli
wait_job_done_wait_loop
        lda job_code,x
        bmi wait_job_done_wait_loop
        plp
        pla
        rts

; --- ram_protect_off: Write-protect the protected RAM (clear control latch b5)
; Control latch bit 5 = RAM write enable for $9000-$93FF and $8200-$8BFF. Off protects it.
ram_protect_off
        pha
        lda ctl_latch
        and #$DF
        sta ctl_latch
        pla
        rts

; --- ram_protect_on: Allow writes to the protected RAM (set control latch b5)
; Switch the write protection of that RAM off (writes allowed).
ram_protect_on
        pha
        lda ctl_latch
        ora #$20
        sta ctl_latch
        pla
        rts

; --- ctl_latch_restore: Restore the control latch image
; Put back the control latch image saved by ctl_latch_save_unlock.
ctl_latch_restore
        pha
        lda ctl_latch_save
        sta ctl_latch
        pla
        rts

; --- ctl_latch_save_unlock: Save the control latch image and unlock the RAM
; Remember the control latch image and allow writes to the protected RAM.
ctl_latch_save_unlock
        pha
        lda ctl_latch
        sta ctl_latch_save
        jsr ram_protect_on
        pla
        rts

; --- ppi_pc1_on: Set 8255 port C bit 1 (ALTMAP, the alternate memory map)
; Set bit 1 of 8255 port C.
ppi_pc1_on
        pha
        lda ppi_pc
        ora #$02
        sta ppi_pc
        pla
        rts

; --- ppi_pc1_off: Clear 8255 port C bit 1 (ALTMAP off)
; Clear bit 1 of 8255 port C.
ppi_pc1_off
        pha
        lda ppi_pc
        and #$FD
        sta ppi_pc
        pla
        rts

; --- cfg_set0: Write config byte 0 (protected RAM)
; Store A in the configuration byte (protected RAM, so the write protection is lifted).
cfg_set0
        jsr ctl_latch_save_unlock
        sta cfg_0
        jmp ctl_latch_restore

; UNREACHABLE CODE ($F77A-$F78B, 18 bytes): cfg_set_device and cfg_set2 write the two device number bytes
; of the configuration. Only the other cfg_set_* writers are used. CMD HD BOOTROM v2.80 has the same two
; routines ($DE00 and $DE09) and does not call them either.
; --- cfg_set_device: Write the device number (protected RAM)
cfg_set_device
        jsr ctl_latch_save_unlock
        sta cfg_device
        jmp ctl_latch_restore

; --- cfg_set2: Write config byte 2 (protected RAM)
cfg_set2
        jsr ctl_latch_save_unlock
        sta cfg_dev2
        jmp ctl_latch_restore

; --- cfg_set_def_part: Write the default partition (protected RAM)
cfg_set_def_part
        jsr ctl_latch_save_unlock
        sta cfg_def_part
        jmp ctl_latch_restore

; --- cfg_set_devflags: Write the device flags (protected RAM)
cfg_set_devflags
        jsr ctl_latch_save_unlock
        sta cfg_devflags
        jmp ctl_latch_restore

; --- cfg_set_part: Write the current partition (protected RAM)
cfg_set_part
        jsr ctl_latch_save_unlock
        sta cur_part
        jmp ctl_latch_restore

; --- select_system_part: Select the system partition and read the partition table
; Select the system partition. X = 0, 1, ... selects one of the "EOS" areas: its descriptor is
; 64 bytes into the header block. The area's checksum is verified before it is accepted.
select_system_part
        txa                      ; descriptor offset = X * 64
        asl
        asl
        asl
        asl
        asl
        asl
        pha
        ldx #$00                 ; read the header block
        jsr sys_read_setup
        bcs select_system_fail
        pla
        pha
        tax                      ; copy the descriptor into the second half of the buffer: start block, size
        lda sector_buf,x
        sta sector_buf2
        lda sector_buf+1,x
        sta sector_buf2+1
        lda sector_buf+3,x
        sta sector_buf2+4
        lda sector_buf+2,x
        sta sector_buf2+5
        lda #$00                 ; checksum bytes
        sta sector_buf2+2
        sta sector_buf2+3
        jsr set_system_geometry  ; read the area and add it up
        bcs select_system_fail
        pla
        pha
        tax
        lda sector_buf2+2        ; compare the checksum with the one stored in the descriptor
        cmp sector_buf+5,x
        bne select_system_fail
        lda sector_buf2+3
        cmp sector_buf+4,x
        bne select_system_fail
        pla
        jsr cfg_set0             ; write the area number to config byte 0
        clc
        rts
select_system_fail
        pla
        sec
        rts

; --- set_system_geometry: Set the system partition's geometry from the table
; Add up (checksum) the blocks of the system area and check them against the table. The data
; is read into $4000-$BFFF in pieces and summed. Result: C = 1 on a read error.
set_system_geometry
        sei
        lda sector_buf2
        sta tmp_6c
        lda #$00
        sta tmp_6b
        ldx #$00
        lda sector_buf2+5
        lsr                      ; start block = (offset / 2), as two bytes
        sta job_track,x
        lda sector_buf2+4
        ror
        sta job_sector,x
        lda sector_buf2+1        ; number of 512 byte blocks
        lsr
        sta job_count,x
        lda tmp_6b
        sta job_bufaddr_lo,x
        lda tmp_6c
        sta job_bufaddr_hi,x
        lda #$FC                 ; $FC = read raw blocks
        jsr sys_job
        bcs system_geometry_done
        ldx sector_buf2+1        ; number of blocks to add up
        ldy #$00
system_geometry_sum_block_loop
        lda sector_buf2+2        ; 16 bit sum in sector_buf2+2 / +3
system_geometry_sum_byte_loop
        clc
        adc (tmp_6b),y
        bcc system_geometry_next_page
        inc sector_buf2+3
system_geometry_next_page
        iny
        bne system_geometry_sum_byte_loop
        sta sector_buf2+2
        inc tmp_6c
        lda tmp_6c
        cmp #$C0                 ; end of the buffer page?
        bne system_geometry_next_block
        lda #$40
        sta tmp_6c
        jsr ppi_pc1_off          ; 8255 port C bit 1 off
system_geometry_next_block
        dex
        bne system_geometry_sum_block_loop
        clc
system_geometry_done
        rts

; --- idle_loop: Idle loop: wait for a command, poll the panel (jt_idle_loop)
; Idle loop: wait for the host. A command waiting on channel 15 is run; ATN starts the bus
; routines; otherwise the activity lamp follows the number of open channels and queued jobs and
; the front panel is scanned.
idle_loop
        sei
        jsr par_bus_release      ; release the parallel cable
        lda #$10                 ; ATN acknowledge high, everything else released
        sta via1_prb
        lda #$00
        cmp cmd_pending          ; a command waiting?
        beq idle_loop_poll_for_atn
        sta cmd_pending          ; clear the flag
        cli                      ; interrupts on while the command runs
        jsr parse_command        ; run it
        jsr sr_mode_in           ; shift register back to input mode
idle_loop_poll_for_atn
        cli
        bit via1_prb             ; ATN on the serial bus?
        bmi idle_loop_atn_detected
        bit ppi_pb               ; ATN on the parallel cable?
        bpl idle_loop_update_activity_led
idle_loop_atn_detected
        jmp jt_atn_service       ; start the ATN service
idle_loop_update_activity_led
        jmp sp_idle_hook         ; SPOOLER idle work, then the original SEI / LDY #$00
idle_loop_count_start
        ldx #$0E                 ; count open channels: SA 0-14
idle_loop_count_channels_loop
        lda sa_chan,x
        cmp #$FF
        beq idle_loop_next_channel
        iny
idle_loop_next_channel
        dex
        bpl idle_loop_count_channels_loop
        ldx #$1F                 ; count queued jobs
idle_loop_count_jobs_loop
        lda job_code,x
        bpl idle_loop_next_job_count
        iny
idle_loop_next_job_count
        dex
        bpl idle_loop_count_jobs_loop
        tya                      ; any? the activity lamp is on
        beq idle_loop_led_off
        jsr led_on
        jmp idle_loop_scan_panel
idle_loop_led_off
        jsr led_off
idle_loop_scan_panel
        jsr panel_scan           ; look at the buttons
        jmp idle_loop_poll_for_atn

; --- irq_handler: IRQ: ATN edge, SRQ, timer 1 job tick (jt_irq)
; IRQ: VIA1 flags. CA1 = ATN edge (sets iec_state bit 6), shift register = burst byte (only if a
; burst host is enabled), timer 1 = the 20 ms job tick (runs all queued jobs), and a BRK
; instruction also runs the jobs.
irq_handler
        pha
        tya
        pha
        txa
        pha
        ldx via1_ifr             ; interrupt flags
        txa
        and #$02                 ; CA1 = ATN edge
        beq irq_check_shift_register
        sta via1_ifr
        lda #$40
        ora iec_state
        sta iec_state            ; remember it
irq_check_shift_register
        txa
        and #$04                 ; shift register complete
        beq irq_check_timer1
        sta via1_ifr
        and bus_flags            ; only if burst is enabled (bus_flags b2)
        beq irq_check_timer1
        lda #$80
        ora xfer_mode            ; burst byte available
        sta xfer_mode
irq_check_timer1
        txa
        and #$40                 ; timer 1 = 20 ms tick
        beq irq_check_brk_flag
        sta via1_ifr
        jsr jt_run_jobs          ; run the job queue
irq_check_brk_flag
        tsx                      ; a BRK on the stack?
        lda $0104,x              ; status register pushed by the interrupt: bit 4 = BRK
        and #$10
        beq irq_exit
        jsr jt_run_jobs          ; software interrupt: run the jobs now
irq_exit
        pla
        tax
        pla
        tay
        pla
        rti

; --------------------------------------------------------------------------
; Free space between the code and the jump table.
; Unused space (zero filled) up to the vector tables.
; --------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; PRINT SPOOLER ($F8F0 up, in what was 1296 bytes of $00 padding). See the notes at sp_atn_clear.
; ---------------------------------------------------------------------------
free_space                              ; $F8F0
; ---------------------------------------------------------------------------
; PRINT SPOOLER: how it fits together
;   host (computer) --serial bus--> LISTEN 4 is answered here --> stream stored in the first type 6
;   partition (ring of 512 byte blocks, block 0 = header) --> played out of the aux port while idle.
; Hooks in the original code (each marked SPOOLER in the source):
;   atn_service          JSR sp_atn_clear      replaces STA par_mode (also clears the "spooler addressed" flag)
;   atn_test_listen_addr JMP sp_atn_hook       replaces CMP listen_addr / BNE (device 4 is accepted here)
;   atn_test_secondary   JMP sp_atn_sa         replaces CMP #$E0 / BNE (secondary address recorded for device 4)
;   atn_do_listen        JSR sp_listen_dispatch replaces JSR jt_listen (device 4 data goes to sp_listen)
;   idle_loop            JMP sp_idle_hook      replaces SEI / LDY #$00 (idle work: init, flush, play out)
; Stream format in the ring ($FF is the escape byte):
;   plain byte                data byte, $FF is stored as $FF $00
;   $FF $01 <sa>              a LISTEN session starts with this secondary address byte ($6x data, $Fx OPEN, $Ex CLOSE)
;   $FF $03 <byte>            this data byte carried EOI
; Header block (block 0): "SPL1", tail block (16 bit), tail offset (16 bit), head block, head offset, session SA.
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Spooler hooks entered from patches in the original code
; ---------------------------------------------------------------------------
; atn_service clears the "spooler addressed" flag together with par_mode (A = 0 here)
sp_atn_clear
        sta par_mode
        sta sp_lsn
        rts

; replaces "CMP listen_addr / BNE atn_test_secondary": our own LISTEN first, then device 4
sp_atn_hook
        cmp listen_addr
        bne sp_atn_chk4
        jmp atn_test_listen_ours
sp_atn_chk4
        cmp #$20+sp_dev
        bne sp_atn_other
        bit sp_stat              ; only answer when a print buffer partition is ready
        bpl sp_atn_other
        bit drive_flags          ; and the drive is not write protected (we could not store the data)
        bmi sp_atn_other
        lda #$80
        sta sp_lsn               ; this burst is for the spooler
        lda #$40                 ; become a listener, DATA stays low so the host sees a device
        jmp atn_set_role
sp_atn_other
        jmp atn_test_secondary

; replaces "CMP #$E0 / BNE atn_wait_atn_end" after a secondary address (A = high nibble, X = raw byte)
sp_atn_sa
        bit sp_lsn
        bmi sp_atn_sa_spool
        cmp #$E0
        bne sp_atn_sa_plain
        jmp atn_do_close
sp_atn_sa_plain
        jmp atn_wait_atn_end
sp_atn_sa_spool
        pha
        stx sp_sa
        lda #$FF                 ; stream event: $FF $01 <secondary address byte>
        jsr sp_put
        lda #$01
        jsr sp_put
        lda sp_sa
        jsr sp_put
        pla
        cmp #$E0                 ; a CLOSE has no data phase, more ATN bytes (UNLISTEN) may follow
        bne sp_atn_sa_plain
        jmp atn_more_atn_check

; replaces "JSR jt_listen" in atn_do_listen
sp_listen_dispatch
        bit sp_lsn
        bpl sp_listen_plain
        jmp sp_listen
sp_listen_plain
        jmp jt_listen

; Receive data for device 4 and store it until the host stops (ATN aborts through iec_listen_byte)
sp_listen
        lda #$80
        sta eoi_flag
        jsr iec_listen_byte
        bit eoi_flag
        bmi sp_listen_plain_byte
        pha                      ; EOI: $FF $03 <byte>
        lda #$FF
        jsr sp_put
        lda #$03
        jsr sp_put
        pla
        jsr sp_put
        jmp sp_listen
sp_listen_plain_byte
        cmp #$FF                 ; a literal $FF is stored as $FF $00
        bne sp_listen_store
        jsr sp_put
        lda #$00
sp_listen_store
        jsr sp_put
        jmp sp_listen

; replaces the start of the activity lamp code in idle_loop; does the spooler's idle work first
sp_idle_hook
        jsr sp_idle
        sei
        ldy #$00
        jmp idle_loop_count_start

; ---------------------------------------------------------------------------
; Stream buffer: append, advance, read
; ---------------------------------------------------------------------------
; Append A to the write buffer (tail). Keeps X.
sp_put
        stx sp_xs
        pha
        lda sp_toff+1
        cmp #$02                 ; a full block is left over (an earlier advance was interrupted)
        bne sp_put_store
        jsr sp_advance
sp_put_store
        lda sp_toff
        sta sp_ptr
        lda sp_toff+1
        clc
        adc #>sp_wbuf
        sta sp_ptr+1
        pla
        ldy #$00
        sta (sp_ptr),y
        inc sp_toff
        bne sp_put_dirty
        inc sp_toff+1
sp_put_dirty
        lda sp_stat
        ora #$40                 ; write buffer dirty
        sta sp_stat
        lda #$00
        sta sp_wd
        lda sp_toff+1
        cmp #$02                 ; 512 bytes: the block is full
        bne sp_put_done
        jsr sp_advance
sp_put_done
        ldx sp_xs
        rts

; The write buffer is full: write it, move the tail to the next block (waiting while the ring is full)
sp_advance
        lda sp_tblk
        sta sp_zb
        lda sp_tblk+1
        sta sp_zb+1
        lda #$2A
        ldx #>sp_wbuf
        jsr sp_rw                ; write the full block to its place
sp_advance_wait
        lda sp_tblk
        sta sp_zb
        lda sp_tblk+1
        sta sp_zb+1
        jsr sp_next              ; sp_zb = next block (recomputed: sp_tx below changes sp_zb)
        lda sp_zb
        cmp sp_hblk
        bne sp_advance_ok
        lda sp_zb+1
        cmp sp_hblk+1
        bne sp_advance_ok
        jsr sp_tx                ; ring full: play data out to make room
        jmp sp_advance_wait
sp_advance_ok
        lda sp_zb
        sta sp_tblk
        lda sp_zb+1
        sta sp_tblk+1
        lda #$00
        sta sp_toff
        sta sp_toff+1
        lda sp_stat
        and #$BF                 ; write buffer is clean
        ora #$08                 ; header needs saving
        sta sp_stat
        jmp sp_save

; sp_zb = next block after sp_zb, wrapping from the end of the partition to block 1
sp_next
        inc sp_zb
        bne sp_next_chk
        inc sp_zb+1
sp_next_chk
        lda sp_zb+1
        cmp sp_size+1
        bcc sp_next_done
        bne sp_next_wrap
        lda sp_zb
        cmp sp_size
        bcc sp_next_done
sp_next_wrap
        lda #$01
        sta sp_zb
        lda #$00
        sta sp_zb+1
sp_next_done
        rts

; Z = 1 when the head has caught up with the tail (nothing to play)
sp_empty
        ldx #$03
sp_empty_loop
        lda sp_tblk,x
        cmp sp_hblk,x
        bne sp_empty_done
        dex
        bpl sp_empty_loop
        lda #$00                 ; all four words equal: Z = 1
sp_empty_done
        rts

; A = byte at the head of the stream (not consumed). C = 1 if the block could not be read.
sp_peek
        lda sp_hblk
        cmp sp_tblk
        bne sp_peek_disk
        lda sp_hblk+1
        cmp sp_tblk+1
        beq sp_peek_ptr          ; head is in the tail block: use the write buffer
sp_peek_disk
        lda sp_stat
        and #$20
        beq sp_peek_read         ; read buffer holds nothing
        lda sp_rblk
        cmp sp_hblk
        bne sp_peek_read
        lda sp_rblk+1
        cmp sp_hblk+1
        beq sp_peek_ptr_r
sp_peek_read
        lda sp_hblk
        sta sp_zb
        lda sp_hblk+1
        sta sp_zb+1
        lda #$28
        ldx #>sp_rbuf
        jsr sp_rw
        bne sp_peek_fail
        lda sp_hblk
        sta sp_rblk
        lda sp_hblk+1
        sta sp_rblk+1
        lda sp_stat
        ora #$20
        sta sp_stat
sp_peek_ptr_r
        lda #>sp_rbuf
        bne sp_peek_set
sp_peek_ptr
        lda #>sp_wbuf
sp_peek_set
        clc
        adc sp_hoff+1
        sta sp_ptr+1
        lda sp_hoff
        sta sp_ptr
        ldy #$00
        lda (sp_ptr),y
        clc
        rts
sp_peek_fail
        sec
        rts

; Consume one stream byte
sp_adv
        inc sp_hoff
        bne sp_adv_chk
        inc sp_hoff+1
sp_adv_chk
        lda sp_hoff+1
        cmp #$02
        bne sp_adv_done
        lda #$00                 ; end of the block: move to the next one
        sta sp_hoff
        sta sp_hoff+1
        lda sp_hblk
        sta sp_zb
        lda sp_hblk+1
        sta sp_zb+1
        jsr sp_next
        lda sp_zb
        sta sp_hblk
        lda sp_zb+1
        sta sp_hblk+1
        lda sp_stat
        and #$DF                 ; read buffer no longer matches
        ora #$08
        sta sp_stat
sp_adv_done
        rts

; ---------------------------------------------------------------------------
; Disk access: one 512 byte block of the spool partition
; ---------------------------------------------------------------------------
; A = $28 read / $2A write, X = high byte of the buffer, sp_zb = block relative to the partition.
; Returns A = SCSI status (Z = 1: good). Runs with interrupts off like the DOS jobs.
sp_rw
        php
        sei
        pha
        stx sp_t0
        clc
        lda sp_zb
        adc sp_base
        sta lba_b0
        lda sp_zb+1
        adc sp_base+1
        sta lba_b1
        lda #$00
        adc sp_base+2
        sta lba_b2
        lda #$1D                 ; job scratch slot (only its lba fields are used)
        sta job_buf_no
        jsr find_lun             ; absolute block -> SCSI target, unit and block
        bcs sp_rw_fail
        pla
        ldy #$01                 ; one block
        jsr scsi_cdb_lba
        lda #$00
        sta buf_ptr_b
        lda sp_t0
        sta buf_ptr_b_hi
        jsr scsi_issue_cdb
        sta sp_sav
        plp
        lda sp_sav
        rts
sp_rw_fail
        pla
        lda #$C0
        sta sp_sav
        plp
        lda sp_sav
        rts

; Write the header block: signature "SPL1", tail block/offset, head block/offset, current session SA
sp_save
        ldx #$03
sp_save_sig
        lda sp_sig,x
        sta sp_hbuf,x
        dex
        bpl sp_save_sig
        ldx #$07
sp_save_ptr
        lda sp_tblk,x
        sta sp_hbuf+4,x
        dex
        bpl sp_save_ptr
        lda sp_rsa               ; the secondary address of the session in progress
        sta sp_hbuf+12
        lda #$00
        sta sp_zb
        sta sp_zb+1
        lda #$2A
        ldx #>sp_hbuf
        jsr sp_rw
        php
        lda sp_stat
        and #$F7
        sta sp_stat
        plp
        rts
sp_sig
        !text "SPL1"

; Write out the partial tail block and the header
sp_flush
        lda sp_stat
        and #$40
        beq sp_flush_hdr
        lda sp_tblk
        sta sp_zb
        lda sp_tblk+1
        sta sp_zb+1
        lda #$2A
        ldx #>sp_wbuf
        jsr sp_rw
        lda sp_stat
        and #$BF
        sta sp_stat
sp_flush_hdr
        jmp sp_save

; ---------------------------------------------------------------------------
; Start up: find the first type 6 partition, read or create its header
; ---------------------------------------------------------------------------
sp_init
        lda sp_stat
        ora #$01                 ; tried once
        sta sp_stat
        ldx #$01
sp_init_scan
        lda part_type,x
        cmp #$06
        beq sp_init_found
        inx
        cpx #$FF
        bne sp_init_scan
        sec
        rts
sp_init_found
        lda part_start_lo,x
        sta sp_base
        lda part_start_mid,x
        sta sp_base+1
        lda part_start_hi,x
        sta sp_base+2
        lda part_size_lo,x
        sta sp_size
        lda part_size_hi,x
        sta sp_size+1
        bne sp_init_size_ok
        lda sp_size
        cmp #$04                 ; header + at least three data blocks
        bcc sp_init_fail
sp_init_size_ok
        lda #$00
        sta sp_zb
        sta sp_zb+1
        lda #$28
        ldx #>sp_hbuf
        jsr sp_rw                ; read the header block
        bne sp_init_fail
        ldx #$03
sp_init_chk_sig
        lda sp_hbuf,x
        cmp sp_sig,x
        bne sp_init_new
        dex
        bpl sp_init_chk_sig
        ldx #$07
sp_init_copy
        lda sp_hbuf+4,x
        sta sp_tblk,x
        dex
        bpl sp_init_copy
        jsr sp_valid             ; are the pointers sane?
        bcs sp_init_new
        lda sp_hbuf+12
        sta sp_rsa
        jmp sp_init_load
sp_init_new
        ldx #$07                 ; empty ring: head = tail = block 1, offset 0
        lda #$00
sp_init_clear
        sta sp_tblk,x
        dex
        bpl sp_init_clear
        lda #$01
        sta sp_tblk
        sta sp_hblk
        jsr sp_save
        bne sp_init_fail
sp_init_load
        lda sp_toff
        ora sp_toff+1
        beq sp_init_ready        ; tail at a block start: nothing to read back
        lda sp_tblk              ; reload the partial tail block
        sta sp_zb
        lda sp_tblk+1
        sta sp_zb+1
        lda #$28
        ldx #>sp_wbuf
        jsr sp_rw
        bne sp_init_fail
sp_init_ready
        lda #$00
        sta sp_dec
        sta sp_aux
        jsr aux_idle             ; aux lines released
        lda #$80                 ; ready (clears the other bits, keeps nothing else)
        sta sp_stat
        clc
        rts
sp_init_fail
        sec
        rts

; C = 1 when a pointer is out of range: block 1..size-1 and offset below 512, for the tail (X=0) and the head (X=4)
sp_valid
        ldx #$00
sp_valid_loop
        lda sp_tblk,x
        ora sp_tblk+1,x
        beq sp_valid_bad         ; block 0 is the header
        lda sp_tblk+3,x
        cmp #$02
        bcs sp_valid_bad         ; offset 512 or more
        lda sp_tblk+1,x
        cmp sp_size+1
        bcc sp_valid_next
        bne sp_valid_bad
        lda sp_tblk,x
        cmp sp_size
        bcs sp_valid_bad
sp_valid_next
        txa
        eor #$04
        tax
        bne sp_valid_loop        ; X = 4 now: check the head too
        clc
        rts
sp_valid_bad
        sec
        rts

; ---------------------------------------------------------------------------
; Idle work, called from the idle loop
; ---------------------------------------------------------------------------
sp_idle
        bit sp_stat
        bmi sp_idle_ready
        lda sp_stat
        and #$01
        beq sp_idle_try          ; first time: try straight away
        inc sp_retry
        bne sp_idle_ret
        inc sp_retry+1
        bne sp_idle_ret
sp_idle_try
        jmp sp_init
sp_idle_ret
        rts
sp_idle_ready
        lda sp_stat
        and #$48                 ; write buffer dirty or header out of date?
        beq sp_idle_play
        inc sp_wd                ; wait about 256 idle passes without new data, then write it out
        bne sp_idle_play
        jsr sp_flush
sp_idle_play
        jsr sp_empty
        beq sp_idle_empty
        lda sp_bo                ; printer failed recently: wait
        ora sp_bo+1
        beq sp_idle_go
        lda sp_bo
        bne sp_idle_bo_lo
        dec sp_bo+1
sp_idle_bo_lo
        dec sp_bo
        rts
sp_idle_go
        jmp sp_tx
sp_idle_empty
        bit sp_aux
        bpl sp_idle_ret
        jsr aux_unlisten         ; nothing left to print: end the aux session
        lda #$00
        sta sp_aux
        rts

; ---------------------------------------------------------------------------
; Play the stream out of the aux port
; ---------------------------------------------------------------------------
; Send up to 16 stream bytes. Stops early when the queue is empty or the printer does not answer.
sp_tx
        lda #$10
        sta sp_cnt
sp_tx_loop
        jsr sp_empty
        beq sp_tx_done
        jsr sp_tx_one
        bcs sp_tx_done
        dec sp_cnt
        bne sp_tx_loop
sp_tx_done
        rts

; Handle one stream byte. C = 1 if it could not be played (nothing consumed).
sp_tx_one
        jsr sp_peek
        bcs sp_tx_one_fail
        ldx sp_dec
        stx sp_t2
        ldy #$00                 ; Y = decoder state after this byte
        cpx #$02
        beq sp_tx_session
        cpx #$03
        beq sp_tx_eoi
        cpx #$01
        beq sp_tx_esc
        cmp #$FF                 ; state 0: $FF starts an event
        bne sp_tx_data
        ldy #$01
        bne sp_tx_commit
sp_tx_esc
        cmp #$00                 ; $FF $00 = literal $FF
        bne sp_tx_esc1
        lda #$FF
        bne sp_tx_data
sp_tx_esc1
        cmp #$01                 ; $FF $01 = session start, SA byte follows
        bne sp_tx_esc3
        ldy #$02
        bne sp_tx_commit
sp_tx_esc3
        cmp #$03                 ; $FF $03 = next byte carries EOI
        bne sp_tx_commit         ; anything else: ignore
        ldy #$03
        bne sp_tx_commit
sp_tx_data
        ldx #$00
        stx sp_eoi
        beq sp_tx_send
sp_tx_eoi
        ldx #$01
        stx sp_eoi
sp_tx_send
        jsr sp_aux_data
        bcs sp_tx_one_fail
        ldy #$00
sp_tx_commit
        sty sp_dec
        jsr sp_adv
        clc
        rts
sp_tx_session
        jsr sp_aux_session
        bcs sp_tx_one_fail
        ldy #$00
        beq sp_tx_commit
sp_tx_one_fail
        lda #$00                 ; the aux session is gone, do not retry for a while
        sta sp_aux
        sta sp_bo
        lda #$04
        sta sp_bo+1
        sec
        rts

; Send A to the printer (sp_eoi = 1: with EOI), opening the aux session first if needed. C = 1 on failure.
sp_aux_data
        sta sp_by
        bit sp_aux
        bmi sp_aux_data_send
        jsr aux_open_session
        bcs sp_aux_data_fail
sp_aux_data_send
        lda sp_by
        jmp aux_send
sp_aux_data_fail
        rts

; A = secondary address byte from the stream. $6x data sessions open lazily, $Fx OPEN opens now
; and stays open for the file name, $Ex CLOSE is sent at once.
sp_aux_session
        sta sp_by
        bit sp_aux
        bpl sp_aux_session_new
        jsr aux_unlisten         ; end the previous session
        lda #$00
        sta sp_aux
sp_aux_session_new
        lda sp_by
        sta sp_rsa
        cmp #$E0
        bcc sp_aux_session_ok    ; data channel: opened when the first byte comes
        jsr aux_open_session
        bcs sp_aux_session_fail
        lda sp_rsa
        cmp #$F0
        bcs sp_aux_session_ok    ; OPEN: leave it open for the name
        jsr aux_unlisten         ; CLOSE: finished
        lda #$00
        sta sp_aux
sp_aux_session_ok
        clc
        rts
sp_aux_session_fail
        sec
        rts

; ---------------------------------------------------------------------------
; Aux port as a serial bus controller (VIA1 port A)
; ASSUMPTIONS TO CHECK ON THE HARDWARE (schematic HD201300): the drivers are inverting, so a 1 in PA1
; (DATA OUT) or PA3 (CLK OUT) pulls that line low; PA4 (AUX ATN OUT) is active low; an input bit
; PA0 / PA2 reads 1 while that line is low. If any of this is the other way round, change aux_on/aux_off
; at the call sites (the ATN lines are the only ones that use them the "wrong" way round).
; ---------------------------------------------------------------------------
; A = line mask: drive those outputs high / low
aux_on
        ora via1_pra_nh
        sta via1_pra_nh
        rts
aux_off
        eor #$FF
        and via1_pra_nh
        sta via1_pra_nh
        rts

; All aux lines released (DATA and CLK low = released, ATN high = released)
aux_idle
        lda #aux_dout+aux_cout
        jsr aux_off
        lda #aux_atn
        jmp aux_on

; Short delay between line changes (about 50 us at 2 MHz)
aux_dly
        ldx #$14
aux_dly_loop
        dex
        bne aux_dly_loop
        rts


; LISTEN to the printer and send the secondary address in sp_rsa. C = 1 if nobody answers.
aux_open_session
        lda #aux_cout
        jsr aux_on               ; CLK first, so no device sees a released CLK while ATN is asserted
        lda #aux_atn
        jsr aux_off              ; ATN asserted (active low)
        lda #aux_dout
        jsr aux_off
        ldx #$08
        lda #$01
        jsr aux_wait             ; a device pulls DATA low when it is there
        bcs aux_open_fail
        lda #$00
        sta sp_eoi
        lda #$20+sp_dev
        jsr aux_send
        bcs aux_open_fail
        lda sp_rsa
        jsr aux_send
        bcs aux_open_fail
        lda #aux_atn
        jsr aux_on               ; ATN released, we are the talker now
        lda #$80
        sta sp_aux
        clc
        rts
aux_open_fail
        jsr aux_idle
        sec
        rts

        !fill $FE00-*, $00              ; rest of the padding up to the jump table page

; --------------------------------------------------------------------------
; Default contents of the jump table at $FF00 (copied by install_jump_table): the DOS commands
; and the internal routines, so they can be replaced by loading a utility with a different
; address.
; Default targets of the 31 jump-table slots at jt_cmd_block, in slot order.
; install_jump_table copies these words into the operands of the JMPs on every warm
; start, undoing any run-time patch made through set_vector.
; --------------------------------------------------------------------------
jump_table_defaults                     ; $FE00
        !word cmd_block                  ; $FE00
        !word cmd_c                  ; $FE02
        !word cmd_g                  ; $FE04
        !word cmd_initialize                  ; $FE06
        !word cmd_m                  ; $FE08
        !word cmd_new                  ; $FE0A
        !word cmd_position                  ; $FE0C
        !word cmd_rename                  ; $FE0E
        !word cmd_scratch                  ; $FE10
        !word cmd_time                  ; $FE12
        !word cmd_user                  ; $FE14
        !word cmd_validate                  ; $FE16
        !word cmd_slash                  ; $FE18
        !word cmd_utility                  ; $FE1A
        !word warm_start                  ; $FE1C
        !word set_vector                  ; $FE1E
        !word idle_loop                  ; $FE20
        !word dos_error                  ; $FE22
        !word job_error                  ; $FE24
        !word irq_handler                  ; $FE26
        !word atn_service                  ; $FE28
        !word listen_handler                  ; $FE2A
        !word talk_handler                  ; $FE2C
        !word burst_get_byte_raw                  ; $FE2E
        !word burst_send_byte_raw                  ; $FE30
        !word do_job                  ; $FE32
        !word do_job_status                  ; $FE34
        !word run_jobs                  ; $FE36
        !word job_to_block                  ; $FE38
        !word cmd_l                  ; $FE3A
        !word cmd_w                  ; $FE3C
; ---------------------------------------------------------------------------
; PRINT SPOOLER, part 2 ($FE3E-$FE9F): aux_wait and aux_unlisten. The rest of this region is still $00.
; ---------------------------------------------------------------------------
free_space_2                            ; $FE3E
; Wait for DATA to be released (A = 0) or asserted (A = 1); X = timeout in units of 256 passes.
; The host's ATN always wins: the aux lines are released and the ATN service runs.
; Returns C = 1 on timeout.
aux_wait
        sta sp_t2
        ldy #$00
aux_wait_loop
        bit via1_prb
        bmi aux_wait_atn
        lda via1_pra_nh
        and #aux_din
        cmp sp_t2
        beq aux_wait_ok
        iny
        bne aux_wait_loop
        dex
        bne aux_wait_loop
        sec
        rts
aux_wait_ok
        clc
        rts
aux_wait_atn
        jsr aux_idle
        lda #$00
        sta sp_aux
        jmp jt_atn_service

; UNLISTEN
aux_unlisten
        lda #aux_cout
        jsr aux_on               ; CLK first, so no device sees a released CLK while ATN is asserted
        lda #aux_atn
        jsr aux_off              ; ATN asserted (active low)
        lda #aux_dout
        jsr aux_off
        lda #$00
        sta sp_eoi
        lda #$3F
        jsr aux_send
        jmp aux_idle
        !fill $FEA0-*, $00

; Second copy of the copyright text (not referenced by code).
; ---------------------------------------------------------------------------
; UNREFERENCED DATA ($FEA0-$FEE9, 74 bytes): the copyright notice again, never read by any code.
; ---------------------------------------------------------------------------
copyright_msg_2                         ; $FEA0
        !text "CMD HD DOS COPYRIGHT 1990 CREATIVE MICRO DESIGNS, INC. ALL RIGHTS RESERVED" ; $FEA0
; ---------------------------------------------------------------------------
; UNUSED SPACE ($FEEA-$FEFF, 22 bytes of $00) up to the start of the jump table page.
; ---------------------------------------------------------------------------
free_space_3                            ; $FEEA
        !fill 22, $00                   ; $FEEA-$FEFF

; ==========================================================================
; Public jump table: 31 x JMP.  The DOS reaches its own major services
; through these slots, so they can be re-vectored at run time (set_vector
; patches a slot; the image lives in write-protected RAM).  The command
; dispatcher parse_command jumps to $FF00+offset using the offset table cmd_offset_tbl.
; ==========================================================================
; Jump table at $FF00: every command and internal routine is called through here.
jt_cmd_block                            ; $FF00
        jmp cmd_block ; 'B'  block commands (B-R B-W B-A B-F B-P B-E)
jt_cmd_copy                             ; $FF03
        jmp cmd_c ; 'C'  copy / change partition / change directory
jt_cmd_g                                ; $FF06
        jmp cmd_g ; 'G'  G-P get partition info, GEOS
jt_cmd_initialize                       ; $FF09
        jmp cmd_initialize ; 'I'  initialize
jt_cmd_m                                ; $FF0C
        jmp cmd_m ; 'M'  M-R M-W M-E, MD make directory
jt_cmd_new                              ; $FF0F
        jmp cmd_new ; 'N'  new (format partition)
jt_cmd_position                         ; $FF12
        jmp cmd_position ; 'P'  position (relative files)
jt_cmd_rename                           ; $FF15
        jmp cmd_rename ; 'R'  rename, RD remove directory
jt_cmd_scratch                          ; $FF18
        jmp cmd_scratch ; 'S'  scratch
jt_cmd_time                             ; $FF1B
        jmp cmd_time ; 'T'  time: T-R / T-W
jt_cmd_user                             ; $FF1E
        jmp cmd_user ; 'U'  user commands, U0 burst commands
jt_cmd_validate                         ; $FF21
        jmp cmd_validate ; 'V'  validate
jt_cmd_slash                            ; $FF24
        jmp cmd_slash ; '/'
jt_cmd_utility                          ; $FF27
        jmp cmd_utility ; '&'  utility loader
jt_warm_start                           ; $FF2A
        jmp warm_start ; warm start
jt_set_vector                           ; $FF2D
        jmp set_vector ; patch jump-table slot X with address A (lo) / Y (hi)
jt_idle_loop                            ; $FF30
        jmp idle_loop ; idle loop
jt_dos_error                            ; $FF33
        jmp dos_error ; report DOS error A and abort the command
jt_job_error                            ; $FF36
        jmp job_error ; report job error A of job X and abort the command
jt_irq                                  ; $FF39
        jmp irq_handler ; IRQ / BRK handler (target of the IRQ vector)
jt_atn_service                          ; $FF3C
        jmp atn_service ; serial bus ATN service
jt_listen                               ; $FF3F
        jmp listen_handler ; addressed as listener: receive data
jt_talk                                 ; $FF42
        jmp talk_handler ; addressed as talker: send data
jt_burst_get_byte                       ; $FF45
        jmp burst_get_byte_raw
jt_burst_send_byte                      ; $FF48
        jmp burst_send_byte_raw
jt_do_job                               ; $FF4B
        jmp do_job ; run job A for buffer X, job error on failure
jt_do_job_status                        ; $FF4E
        jmp do_job_status ; run job A for buffer X, return status
jt_run_jobs                             ; $FF51
        jmp run_jobs ; execute all pending jobs
jt_job_to_block                         ; $FF54
        jmp job_to_block ; convert the job's track/sector into a block address
jt_cmd_l                                ; $FF57
        jmp cmd_l ; 'L'
jt_cmd_w                                ; $FF5A
        jmp cmd_w ; 'W'
; ---------------------------------------------------------------------------
; PRINT SPOOLER, part 3 ($FF5D-$FFF9): aux_send. The rest of this region is still $00, up to the hardware vectors.
; ---------------------------------------------------------------------------
free_space_4                            ; $FF5D
; Send the byte A (sp_eoi = 1: last byte). C = 1 if the printer did not take it.
aux_send
        sta sp_t1
        lda #aux_cout
        jsr aux_off              ; ready to send
        ldx #$00
        lda #$00
        jsr aux_wait             ; wait until the listener is ready (DATA released)
        bcs aux_send_fail
        lda sp_eoi
        beq aux_send_bits
        ldx #$00                 ; EOI: the listener answers by pulsing DATA low and high
        lda #$01
        jsr aux_wait
        bcs aux_send_fail
        ldx #$00
        lda #$00
        jsr aux_wait
        bcs aux_send_fail
aux_send_bits
        lda #aux_cout
        jsr aux_on
        ldy #$08
aux_send_bit
        lsr sp_t1
        bcs aux_send_one
        lda #aux_dout
        jsr aux_on               ; bit 0: DATA low
        jmp aux_send_clock
aux_send_one
        lda #aux_dout
        jsr aux_off              ; bit 1: DATA high
aux_send_clock
        jsr aux_dly              ; setup
        lda #aux_cout
        jsr aux_off              ; CLK high: bit is valid
        jsr aux_dly              ; hold
        lda #aux_cout
        jsr aux_on
        dey
        bne aux_send_bit
        lda #aux_dout
        jsr aux_off
        ldx #$04
        lda #$01
        jsr aux_wait             ; the listener answers with DATA low
        bcs aux_send_fail
        clc
        rts
aux_send_fail
        jsr aux_idle
        sec
        rts

        !fill $FFFA-*, $00

; --------------------------------------------------------------------------
; 6502 hardware vectors
; --------------------------------------------------------------------------
; Hardware vectors: NMI, reset and IRQ (through the jump table).
hw_vectors                              ; $FFFA
        !word nmi_handler                  ; $FFFA  NMI
        !word reset                  ; $FFFC  RESET
        !word jt_irq                    ; $FFFE  IRQ/BRK (through the jump table)
