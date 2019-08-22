VBlank::

	push af
	push bc
	push de
	push hl

	ld a, [H_LOADEDROMBANK]
	ld [wVBlankSavedROMBank], a

	ld a, [hSCX]
	ld [rSCX], a
	ld a, [hSCY]
	ld [rSCY], a

	ld a, [wDisableVBlankWYUpdate]
	and a
	jr nz, .ok
	ld a, [hWY]
	ld [rWY], a
.ok

	call AutoBgMapTransfer
	call VBlankCopyBgMap
	call RedrawRowOrColumn
	call VBlankCopy
	call VBlankCopyDouble
	call UpdateMovingBgTiles

	; For CGB, need to translate values of BGP, OBP0 and OBP1
	; into CGB tile palette 0 and OAM palettes 0-1.
	call FixCGBPalettes

	call DoOAMDMA
	ld a, BANK(PrepareOAMData)
	ld [H_LOADEDROMBANK], a
	ld [MBC1RomBank], a
	call PrepareOAMData

	; For CGB, need to move palette number from bit 4 to bits 0-2
	; and clear other data from bits 0-2
	call FixOAMDataCGBFlags

	; VBlank-sensitive operations end.

	call Random

	ld a, [H_VBLANKOCCURRED]
	and a
	jr z, .skipZeroing
	xor a
	ld [H_VBLANKOCCURRED], a

.skipZeroing
	ld a, [H_FRAMECOUNTER]
	and a
	jr z, .skipDec
	dec a
	ld [H_FRAMECOUNTER], a

.skipDec
	call FadeOutAudio

	ld a, [wAudioROMBank] ; music ROM bank
	ld [H_LOADEDROMBANK], a
	ld [MBC1RomBank], a

	cp BANK(Audio1_UpdateMusic)
	jr nz, .checkForAudio2
.audio1
	call Audio1_UpdateMusic
	jr .afterMusic
.checkForAudio2
	cp BANK(Audio2_UpdateMusic)
	jr nz, .audio3
.audio2
	call Music_DoLowHealthAlarm
	call Audio2_UpdateMusic
	jr .afterMusic
.audio3
	call Audio3_UpdateMusic
.afterMusic

	callba TrackPlayTime ; keep track of time played

	ld a, [hDisableJoypadPolling]
	and a
	call z, ReadJoypad

	ld a, [wVBlankSavedROMBank]
	ld [H_LOADEDROMBANK], a
	ld [MBC1RomBank], a

	pop hl
	pop de
	pop bc
	pop af
	reti


DelayFrame::
; Wait for the next vblank interrupt.
; As a bonus, this saves battery.

NOT_VBLANKED EQU 1

	ld a, NOT_VBLANKED
	ld [H_VBLANKOCCURRED], a
.halt
	halt
	ld a, [H_VBLANKOCCURRED]
	and a
	jr nz, .halt
	ret


; Mapping of DMA palette values 00, 01, 10 and 11 to CGB 16-bit colors 0bbb bbgg gggr rrrr.
; Note they're little-endian, so it's actually gggrrrrr 0bbbbbgg
DMAColorToCGB:
	db %11111111, %01111111 ; 0 -> (31, 31, 31)
	db %10010100, %01010010 ; 1 -> (20, 20, 20)
	db %01001010, %00101001 ; 2 -> (10, 10, 10)
	db %00000000, %00000000 ; 3 -> ( 0,  0,  0)


; Read palettes from BGP, OBP0 and OBP1 and write equivalents
; to CGB palettes.
FixCGBPalettes:
	ld A, $80
	ld [$ff68], A ; grid palette index = 0, autoincrement on
	ld [$ff6a], A ; OAM palette index = 0, autoincrement on

	ld A, [rBGP]
	ld D, A ; D = DMG grid palette
	ld C, $69 ; grid palette data address low byte (nice.)
	call TranslatePalette ; write grid palette 0

	ld A, [rOBP0]
	ld D, A ; D = DMG OAM palette 0
	ld C, $6b ; OAM palette data address low byte
	call TranslatePalette ; write oam palette 0

	ld A, [rOBP1]
	ld D, A ; D = DMG OAM palette 1
	call TranslatePalette ; write oam palette 1

	ret


; Given DMA palette D, write CGB colors to palette data register (ff+C)
; which has autoincrement on.
; Clobbers all but C, E
TranslatePalette:
	ld B, 4
.loop
	ld A, D
	and $03 ; grab bottom two bits
	rr D
	rr D ; rotate D in prep for next loop
	ld HL, DMAColorToCGB
	; HL += 2A
	add A
	add L
	ld L, A
	ld A, 0
	adc H
	ld H, A
	; now [HL] = DMAColorToCGB[color]
	ld A, [HL+]
	ld [C], A
	ld A, [HL]
	ld [C], A
	; next loop
	dec B
	jr nz, .loop

	ret


; Performs the OAM DMA copy without updating the volume (by writing the same as current).
; As a reminder, OAM DMA routine at $ff80 expects:
;  a = high(source addr)
;  b = time to wait before writing to hl
;  c = low(rDMA)
;  d = value to write to hl
;  e = 40 - b
;  hl = addr in hram or io reg to write to (typically volume)
DoOAMDMA:
	ld a, HIGH(wOAMBuffer)
	ld b, 20
	ld e, b
	ld c, LOW(rDMA)
	ld hl, rNR50
	ld d, [hl]
	jp $ff80 ; tail call
