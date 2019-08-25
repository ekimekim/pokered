

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


; HRAM variables available:
;  $ff88, reclaimed by making OAM DMA routine smaller
;  $ffbf - $ffc0, reclaimed by removing SP abuse from fast copy
;  $fffa - $fffe, which are unused

; Next volume to write
hWaveVolume EQU $ffbf
; The volume after that, or ff if we need to read the next one
hNextWaveVolume EQU $ffc0
; Lower 8 bits of bank of next wave sample
hWaveBankLow EQU $fffa
; Top bit of bank of next wave sample.
hWaveBankHigh EQU $fffb
; Addr of next wave sample, big-endian
hWaveAddr EQU $fffc ; 2 bytes, so also fffd
; ff88,fffe still unused

SFX_VOLUME EQU 1 ; volume 2/8, because music is otherwise very quiet

; Wave data. Use the section stack to avoid losing our current context inside home section.

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

WavePointerWithID: MACRO
	db \1
	WavePointer \2
ENDM

WavePointerList: MACRO
	db BANK(\1), HIGH(\2 - 4), LOW(\2 - 4)
ENDM

; Because ids repeat per bank, we maintain three WavePointersByID lists.
; We find the correct list by first matching on [wAudioROMBank].
WavePointerLists:
	WavePointerList Audio1_PlaySound, WavePointerList1
	WavePointerList Audio2_PlaySound, WavePointerList2
	WavePointerList Audio3_PlaySound, WavePointerList3

; For each id, map to a wave track pointer.
; This is a list of (id, pointer) (each entry is 4 bytes).
WavePointerList1:
	WavePointerWithID          MUSIC_PALLET_TOWN, WaveData_blank_0
	WavePointerWithID           MUSIC_POKECENTER, WaveData_blank_0
	WavePointerWithID                  MUSIC_GYM, WaveData_blank_0
	; viridian, pewter, saffron, museum, daycare, dojo, various small houses
	WavePointerWithID              MUSIC_CITIES1, WaveData_blank_0
	; cerulean, fuchsia, a few people's houses
	WavePointerWithID              MUSIC_CITIES2, WaveData_blank_0
	WavePointerWithID              MUSIC_CELADON, WaveData_blank_0
	WavePointerWithID             MUSIC_CINNABAR, WaveData_blank_0
	WavePointerWithID            MUSIC_VERMILION, WaveData_blank_0
	WavePointerWithID             MUSIC_LAVENDER, WaveData_blank_0
	WavePointerWithID              MUSIC_SS_ANNE, WaveData_blank_0
	WavePointerWithID        MUSIC_MEET_PROF_OAK, WaveData_oak_0
	WavePointerWithID           MUSIC_MEET_RIVAL, WaveData_blank_0
	; Used in a few places where NPCs are leading you around
	WavePointerWithID           MUSIC_MUSEUM_GUY, WaveData_blank_0
	WavePointerWithID          MUSIC_SAFARI_ZONE, WaveData_blank_0
	WavePointerWithID          MUSIC_PKMN_HEALED, WaveData_blank_0
	; Route 1, Route 2, and underground paths
	WavePointerWithID              MUSIC_ROUTES1, WaveData_blank_0
	; Route 24 and Route 25, plus the New Game "Oak Speech"
	WavePointerWithID              MUSIC_ROUTES2, WaveData_blank_0
	; Most of the other routes
	WavePointerWithID              MUSIC_ROUTES3, WaveData_blank_0
	; Routes 11-15
	WavePointerWithID              MUSIC_ROUTES4, WaveData_blank_0
	WavePointerWithID       MUSIC_INDIGO_PLATEAU, WaveData_blank_0

WavePointerList2:
	WavePointerWithID    MUSIC_GYM_LEADER_BATTLE, WaveData_blank_0
	WavePointerWithID       MUSIC_TRAINER_BATTLE, WaveData_blank_0
	WavePointerWithID          MUSIC_WILD_BATTLE, WaveData_blank_0
	WavePointerWithID         MUSIC_FINAL_BATTLE, WaveData_blank_0
	WavePointerWithID     MUSIC_DEFEATED_TRAINER, WaveData_blank_0
	WavePointerWithID    MUSIC_DEFEATED_WILD_MON, WaveData_blank_0
	WavePointerWithID  MUSIC_DEFEATED_GYM_LEADER, WaveData_blank_0

WavePointerList3:
	WavePointerWithID         MUSIC_TITLE_SCREEN, WaveData_title_0
	WavePointerWithID              MUSIC_CREDITS, WaveData_blank_0
	WavePointerWithID         MUSIC_HALL_OF_FAME, WaveData_blank_0
	WavePointerWithID             MUSIC_OAKS_LAB, WaveData_oak_0
	WavePointerWithID      MUSIC_JIGGLYPUFF_SONG, WaveData_blank_0
	WavePointerWithID          MUSIC_BIKE_RIDING, WaveData_blank_0
	WavePointerWithID              MUSIC_SURFING, WaveData_blank_0
	WavePointerWithID          MUSIC_GAME_CORNER, WaveData_blank_0
	WavePointerWithID         MUSIC_INTRO_BATTLE, WaveData_intro_0
	; Rocket hideout, power plant, cerulean cave, some other misc places
	WavePointerWithID             MUSIC_DUNGEON1, WaveData_blank_0
	; Viridian Forest, Diglett Cave, Seaform Islands
	WavePointerWithID             MUSIC_DUNGEON2, WaveData_blank_0
	; Mt Moon, Victory Road caves, Rock Tunnel
	WavePointerWithID             MUSIC_DUNGEON3, WaveData_blank_0
	WavePointerWithID     MUSIC_CINNABAR_MANSION, WaveData_blank_0
	WavePointerWithID        MUSIC_POKEMON_TOWER, WaveData_blank_0
	WavePointerWithID             MUSIC_SILPH_CO, WaveData_blank_0
	WavePointerWithID    MUSIC_MEET_EVIL_TRAINER, WaveData_blank_0
	WavePointerWithID  MUSIC_MEET_FEMALE_TRAINER, WaveData_blank_0
	WavePointerWithID    MUSIC_MEET_MALE_TRAINER, WaveData_blank_0

PUSHS
include "music/wave_data.asm"
POPS


; Begin playing wave music song with id in A
WaveMusicStart::
	ld D, A ; put ID aside for now

	; map id A to a wave track pointer by scanning list
	ld HL, WavePointerLists - 1
	ld A, [wAudioROMBank]
.find_list_loop
	inc HL
	cp [HL] ; set z if match
	jr nz, .find_list_loop
	inc HL
	; now [HL] points to track pointer list - 4

	ld A, [HL+]
	ld L, [HL]
	ld H, A ; now HL = track pointer list - 4

	ld A, D ; restore ID
	ld BC, 4
.find_loop
	add HL, BC
	cp [HL]
	jr nz, .find_loop
	inc HL
	; now HL points at track pointer

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
    ld a, %01000000 ; enable ch3 on left side. stop everything else.
    ld [rNR51], a
    ld a, %00100000 ; no shift of samples
    ld [rNR32], a
    ld hl, rNR34 ; ready to begin playing

	; Some ordering weirdness here. Our normal order goes:
	;  play 1, play 2, PrepareSample for 3-4, play 3, play 4, PrepareSample for 5-6
	; but because the first sample begins playing immediately,
	; but the first sample we write doesn't kick in until later,
	; our start sequence should be more like:
	;  START for 1, play 2, PrepareSample (the first one in the data) for 3-4, ...
	; so our initial state should be with a garbage (but valid) value in hWaveVolume,
	; and ff in hNextWaveVolume, so that the first interrupt to fire (corresponding
	; to the second sample in the wave ram) causes the first PrepareSample.

	xor a
	ld [hWaveVolume], a
	dec a ; a = ff
	ld [hNextWaveVolume], a

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

	reti ; combine ei and ret


; Timer interrupt handler.
; By the time we get here, at least 4 cycles have passed since the interrupt,
; probably more since the CPU needs to finish the last instruction (6 for a call),
; or if vblank fires first then it can take up to 5(?) more cycles.
; So worst case is 15 cycles delay in getting here, best is 4.
; BUT that's all super hard to re-sync from, so we're just gonna ignore it and hope
; that it's irregular enough not to be noticed. We'll assume we're at timer + 4.
; Total cycles for interrupt:
;  Fast branch: 36 cycles
;  Slow branch: 21 + PrepareSample(90) = 111, which is still well below our time limit of ~150.
;  With a jump: 21 + PrepareSample with Jump (119) = 140, which is _just_ within our limit.
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
; For the non-jump case, total time: 86 cycles
; With jump: 
PrepareSample:
	push BC
	push HL

.after_oam
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
	; resolve volume pair into seperate bytes and save them
	; ie. 0xxx0yyy -> 0xxx0vvv, 0yyy0vvv where vvv is sfx volume
	ld B, SFX_VOLUME
	ld C, A ; C = volume pair (1st, 2nd)
	and $f0 ; A = (1st, 0)
	or B ; A = (1st, sfx)
	ld [hWaveVolume], A ; save first volume
	ld A, C
	and $0f ; A = (0, 2nd)
	swap A ; A = (2nd, 0)
	or B ; A = (2nd, sfx)
	ld [hNextWaveVolume], A

	; Write next sample. This can be done at any time during playing of current sample
	; and the written value will overwrite current sample.
	; It won't actually play for 30 more iterations, but we account for that when encoding.
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
	; Right now we're at 76 cycles since PrepareSample start,
	; and 7 more (= 85) since last volume write.
	; We want to time the OAM DMA call so that it begins two cycles
	; before next volume write is needed.

	; The below (post-wait-loop, up to and including the call to $ff80) will take 31 cycles.
	; We want to wait loop such that 85 + 31 + wait = 164.
	; Each wait loop cycle is 4 cycles, - 1 on the last cycle, but +2 for setting B, so +1 overall.
	; so wait loop iterations = (164 - (85 + 31 + 1)) / 4 = 49 / 4 = 12 loops, plus 1 nop.
	; One of the above calcs is off. Experimentally, this must be 13 or we get artifacting.
	ld B, 13
.oam_wait
	dec B
	jr nz, .oam_wait
	nop

	; clear pending OAM DMA flag. it's safe to do this now since we won't return
	; until it's actually done, and we have time to kill.
	xor A
	ld [hOAMDMAPending], A

	push DE

	; OAM DMA routine at $ff80 expects:
	;  a = high(wOAMBuffer)
	;  c = low(rDMA)
	;  hl = rNR50
	;  b = 40
	;  d = first volume
	;  e = second volume
	ld B, 40
	ld C, LOW(rDMA)
	ld A, [hWaveVolume]
	ld D, A
	ld A, [hNextWaveVolume]
	ld E, A
	ld HL, rNR50
	ld A, HIGH(wOAMBuffer)

	; Do the DMA and volume updates
	call $ff80

	; Multiple timer interrupts have fired since we started.
	; Clear them.
	ld A, [rIF]
	and %11111011 ; clear timer flag
	ld [rIF], A

	pop DE
	; Now run PrepareSamples again (though without re-pushing HL and BC)
	; since we just used the next two samples.
	jr .after_oam

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
