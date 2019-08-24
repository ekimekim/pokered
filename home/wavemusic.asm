

; Various notes:
;
; Wave track data is encoded as byte pairs (v1:v2, s1:s2), where : indicates concat of nibbles,
; and v and s together make a sample, with v being the volume value and s being the wave sample.
; Note that v is only 3 bits, so the top bit is always 0.
; We use this bit as a flag:
;  0: This is a pair of samples as described above.
;  1: This is a jump to another track (or the same track, to implement looping).
;     The next 3 bytes are a wave track pointer.
;
; A wave track is pointed to by a far pointer, to bank and addr.
; Since addr is always in ROMX (begins with 01), we reuse top bit as top bit of
; bank. So the full bit field looks like:
;  bbbbbbbb B1aaaaaa aaaaaaaa
; with the bank being Bbbbbbbbb and the address being 01aaaaaa aaaaaaaa.
;
; We need to write the next volume every 164 bytes.
; Every second time we do that, we also need to load the next pair of samples.
; Our cycle budget is half of all cycles (since we've doubled available cycles by doubling
; the cpu speed).


; HRAM variables available from $ff87 - $ff88, reclaimed by making OAM DMA routine smaller,
; plus $fffa - $fffe, which are unused.

; Next volume to write
hWaveVolume EQU $fffa
; The volume after that, or ff if we need to read the next one
hNextWaveVolume EQU $fffb
; Lower 8 bits of bank of next wave sample
hWaveBankLow EQU $fffc
; Top bit of bank of next wave sample.
hWaveBankHigh rb $fffd
; Addr of next wave sample, big-endian
hWaveAddr rw $fffe


; Wave data. Use the section stack to avoid losing our current context inside home section.

PUSHS

SECTION "Wave pointer data", ROMX

; Pointer to track symbol \1
WavePointer: MACRO
	db LOW(BANK(\1))
	db (HIGH(BANK(\1)) << 7) | (HIGH(\1))
	db LOW(\1)
ENDM

; A flagged sample that jumps the music to symbol \1
WaveJump: MACRO
	db $80
	WavePointer \1
ENDM

; For each id, map to a wave track pointer.
WavePointersByID::
	WavePointer TestingTrack ; dummy 0 track for testing
	; TODO

include "audio/wave_data.asm"
POPS


; Begin playing wave music song with id in A
WaveMusicStart::
	; TODO map id A to a wave track pointer
	ld HL, WavePointersByID

	; stop existing playback so we can modify things safely
	xor a
	di ; a long delay between next two instructions could cause audio artifacts
	ld [rTAC], a ; stop timer
	ld [rNR30], a ; stop playback
	ei

	; Load Track Pointer into hram vars
	ld A, [HL+] ; Bank low
	ld [hWaveBankLow], A
	ld A, [HL+] ; Bank high + addr high
	rlca ; rotate A left, so now top bit (high bank bit) is in bottom bit
	; the only bit of the bank high value that matters is the bottom one,
	; so we just leave the garbage (the top 7 bits of addr) in there.
	ld [hWaveBankHigh], A
	and a ; clear carry flag
	rra ; rotate right through carry, so now the 7 bits of addr are back to normal but top bit is 0
	ld [hWaveAddr], A ; save top byte of addr
	ld A, [HL]
	ld [hWaveAddr+1], A

	; Set up Ch3 regs, but don't actually begin playback
	ld a, $80
	ld [rNR30], a ; turn on ch3
    or %01000100 ; enable ch3 in mux
    ld [rNR51], a
    ld a, %00100000 ; no shift of samples
    ld [rNR32], a
    ld hl, rNR34 ; ready to begin playing

	; We want to fire the timer every 164 cycles = 41 ticks * 4 cycles/tick.
	; But we want to have some leeway time between when it fires and when the next volume
	; needs to be set.
	; We start the timer exactly 2 cycles before audio begins.
	; So to get a leeway of 4*N+2 cycles between timer overflow and volume time,
	; we shorten the first round by N.
	; We want to delay 14 cycles (see Timer handler below), so 4N+2 = 14, N = 3.
	; Note that timer counts up and triggers on overflow so we set it to 256 - number of ticks
	ld a, 256 - (41 - 3)
	ld [rTIMA], a
	ld a, 256 - 41
	ld [rTMA], a
	; prepare to turn on timer with freq 1 = 4 cycles/tick
	ld a, %00000101

	; Critical section - begin the timer, then exactly 2 cycles later begin playback.
	di
	ld [rTAC], a ; begin timer
    set 7, [hl] ; 2 cycles later: play

	; We need to complete the first sample prepare before enabling interrupts,
	; or else we might not finish it in time.
	
	push AF ; PrepareSample expects to need to pop AF when returning
	jp PrepareSample
	; note PrepareSample ends in reti, so this is a tail call AND an ei at the end


; Timer interrupt handler.
; By the time we get here, at least 4 cycles have passed since the interrupt,
; probably more since the CPU needs to finish the last instruction (6 for a call),
; or if vblank fires first then it can take up to 5(?) more cycles.
; So worst case is 15 cycles delay in getting here, best is 4.
; BUT that's all super hard to re-sync from, so we're just gonna ignore it and hope
; that it's irregular enough not to be noticed. We'll assume we're at timer + 4.
; Total cycles for interrupt:
;  Fast branch: 36 cycles
;  Slow branch: 21 + PrepareSample(88) = 109, which is still well below our time limit of ~150.
;  With a jump: 21 + PrepareSample with Jump (117) = 138, which is _just_ within our limit.
Timer::
	; T+4
	push AF ; T+8
	ld A, [hWaveVolume] ; T+11
	ld [rNR50], A ; write volume at T+14

	; ok, absolutely critical section is over.

	; check next wave volume. if it's ff, we need to prepare a new pair.
	; otherwise, move it up into hWaveVolume and set hNextWaveVolume to ff.
	ld A, [hNextWaveVolume]
	inc A ; set z if A was $ff
	jr z, PrepareSample ; tail call, PrepareSample takes care of pop AF and reti

	dec A ; return it to its prev value
	ld [hWaveVolume], A
	ld A, $ff
	ld [hNextWaveVolume], A ; write ff for next wave volume

	; and we're done on the short path
	pop af
	reti


; Look up next sample, resolve any jumps, write sample value to wave RAM,
; then write next two volumes to HRAM.
; For the non-jump case, total time: 88 cycles
; With jump: 
PrepareSample:
	push BC
	push HL

	; Load bank and addr
	ld HL, hWaveBankLow
	ld A, [HL+] ; A = wave bank low
	ld [MBC1RomBank], A ; switch to wave bank low
	ld A, [HL+] ; A = wave bank high
	ld [$3000], A ; switch to wave bank high, wave bank is now loaded
	ld A, [HL+] ; A = top byte of wave addr
	ld L, [HL] ; L = bottom byte of wave addr
	ld H, A ; HL = wave addr

	; grab volume pair and check for jump
	ld A, [HL+]
	rla ; shifts top bit of A into c
	jr c, .jump
	rra ; shift it back

PrepareSampleBody: MACRO
	; resolve volume pair into seperate bytes
	; ie. 0xxx0yyy -> 0xxx0xxx, 0yyy0yyy
	ld C, A ; C = volume pair (1st, 2nd)
	and $0f ; select second volume, A = (0, 2nd)
	ld B, A ; B = (0, 2nd)
	swap A ; A = (2nd, 0)
	or B ; A = (2nd, 2nd)
    ld B, A ; A = B = second volume, copied to both nibbles
    xor C ; A = (2nd^1st, 2nd^2nd) = (1st^2nd, 0)
    swap A ; A = (0, 1st^2nd)
    xor C ; A = (0^1st, 1st^2nd^2nd) = (1st, 1st)

	; save the two volumes
	ld [hWaveVolume], A
	ld A, B
	ld [hWaveNextVolume], A

	; Write next sample. This can be done at any time during playing of current sample
	; and the written value will overwrite current sample.
	; It won't actually play for 32 more iterations, but we account for that when encoding.
	ld A, [HL+] ; note HL now points at next volume/sample pair
	ld [$ff30], A ; write to wave ram

	; Save updated value of HL to hWaveAddr
	ld A, H
	ld [hWaveAddr], A
	ld A, L
	ld [hWaveAddr+1], A

	; Cleanup: switch back banks
	; dirty trick: Since hWaveAddr should always be even, bottom bit is 0.
	; so we know bottom bit of A is 0 here so we can unset bank bit using it.
	ld [$3000], A ; set bank top bit low, since that's where all non-wave-data banks are
	ld A, [H_LOADEDROMBANK] ; get the bank that should be loaded right now
	ld [MBC1RomBank], A ; switch back to original bank
ENDM

	PrepareSampleBody

	ld A, [hOAMDMAPending]
	and A ; set z if no DMA pending
	jr nz, .oam_dma

	pop HL
	pop BC
	pop AF
	reti

.oam_dma
	; TODO
	pop HL
	pop BC
	pop AF
	reti

.jump
	; Load the track pointer from HL into hram vars
	; as well as switch to the bank now.
	ld A, [HL+] ; Bank low
	ld [hWaveBankLow], A ; save it to hram
	ld B, A ; and keep it for later. B = bank low
	ld A, [HL+] ; Bank high + addr high
	ld L, [HL] ; L = addr low
	; we're done reading HL, so it's now safe to change banks
	rlca ; rotate A left, so now top bit (high bank bit) is in bottom bit
	; the only bit of the bank high value that matters is the bottom one,
	; so we just leave the garbage (the top 7 bits of addr) in there.
	ld [hWaveBankHigh], A ; save high bank
	ld [$3000], A ; and also switch to it
	and a ; clear carry flag
	rra ; rotate right through carry, so now the 7 bits of addr are back to normal but top bit is 0
	ld [hWaveAddr], A ; save top byte of addr
	ld H, A ; now HL = addr
	ld A, L
	ld [hWaveAddr+1], A ; save bottom byte of addr
	ld A, B ; A = bank low
	ld [MBC1RomBank], A ; switch to it

	; phew. ok, now we're in the new bank and HL = addr.
	ld A, [HL+]
	; and we're back to the state we were in before jumping to .jump

	PrepareSampleBody

	; note that unlike the other path, we DO NOT check for OAM DMA here.
	; this is why this is its own path, we can't combine a jump and an OAM DMA
	; because the timing would be different.

	pop HL
	pop BC
	pop AF
	reti
