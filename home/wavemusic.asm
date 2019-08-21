

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
; We need to write the next volume every 116 bytes.
; Every second time we do that, we also need to load the next pair of samples.
; Our cycle budget is half of all cycles (since we've doubled available cycles by doubling
; the cpu speed).


; HRAM variables from $ff80 - $ff89, reclaimed by removing OAM DMA usage,
; which we can't allow anyway as it would block audio from updating while running.

RSSET $ff80
; Next volume to write
hWaveVolume rb 1
; The volume after that, or ff if we need to read the next one
hNextWaveVolume rb 1
; Lower 8 bits of bank of next wave sample
hWaveBankLow rb 1
; Top bit of bank of next wave sample.
hWaveBankHigh rb 1
; Addr of next wave sample, big-endian
hWaveAddr rw 1


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


; Load the track pointer in HL into the hram vars.
LoadTrackPointer: MACRO
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
ENDM


; Begin playing wave music song with id in A
WaveMusicStart::
	; TODO map id A to a wave track pointer
	ld HL, WavePointersByID
	LoadTrackPointer

	; Set up Ch3 regs, but don't actually begin playback
	ld a, $80
	ld [rNR30], a ; turn on ch3
    or %01000100 ; enable ch3 in mux
    ld [rNR51], a
    ld a, %00100000 ; no shift of samples
    ld [rNR32], a
    ld hl, rNR34 ; ready to begin playing

	xor a
	ld [rTAC], a ; stop any existing timer so we can set up timer regs safely
	; We want to fire the timer every 116 cycles = 29 ticks * 4 cycles/tick.
	; But on the first round, we start the timer 4 cycles before we start the audio
	; so we need to delay an additional 4 cycles, so we set it to 30 but modulus to 29.
	ld a, 30
	ld [rTIMA], a
	dec a
	ld [rTMA], a
	; prepare to turn on timer with freq 1 = 4 cycles/tick
	ld a, %00000101

	; Critical section - begin the timer, then exactly 4 cycles later begin playback.
	di
	ld [rTAC], a ; begin timer
	nop ; 1 cycle later
	nop ; 2 cycles later
    set 7, [hl] ; 4 cycles later: play
	ei

	ret
