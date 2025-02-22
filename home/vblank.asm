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

	; If music is playing, schedule a DMA
	; Otherwise, just do it ourselves immediately
	ld a, [rTAC]
	and $07 ; set z if no music
	jr z, .no_music
	ld a, 1
	ld [hOAMDMAPending], a ; set DMA pending
	jr .after_dma
.no_music
	call DoOAMDMA
.after_dma

	call AutoBgMapTransfer
	call VBlankCopyBgMap
	call RedrawRowOrColumn
	call VBlankCopy
	call VBlankCopyDouble
	call UpdateMovingBgTiles

	; For CGB, need to translate values of BGP, OBP0 and OBP1
	; into CGB tile palette 0 and OAM palettes 0-1.
	call FixCGBPalettes

	; VBlank-sensitive operations end.

	; OAM DMA should definitely be done by now (or we did it ourselves).
	; Just to check, loop until it's done.
.dma_wait
	ld a, [hOAMDMAPending]
	and a ; set z if DMA pending flag has been cleared
	jr nz, .dma_wait

	ld a, BANK(PrepareOAMData)
	ld [H_LOADEDROMBANK], a
	ld [MBC1RomBank], a
	call PrepareOAMData

	; For CGB, need to move palette number from bit 4 to bits 0-2
	; and clear other data from bits 0-2
	call FixOAMDataCGBFlags

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
	; ret not reti because we re-enabled interrupts already
	ret


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


PUSHS

SECTION "Palette map", ROM0 [$00]

; Mapping of DMG palette values 00, 01, 10 and 11 to CGB 16-bit colors 0bbb bbgg gggr rrrr.
; Note they're little-endian, so it's actually gggrrrrr 0bbbbbgg
DMGColorToCGB:
	db %11111111, %01111111 ; 0 -> (31, 31, 31)
	db %10010100, %01010010 ; 1 -> (20, 20, 20)
	db %01001010, %00101001 ; 2 -> (10, 10, 10)
	db %00000000, %00000000 ; 3 -> ( 0,  0,  0)
POPS

; Read palettes from BGP, OBP0 and OBP1 and write equivalents
; to CGB palettes.
; Cycle count: 43 + 3 * TranslatePalette = 232
FixCGBPalettes:
	ld A, $80
	ld [$ff68], A ; grid palette index = 0, autoincrement on
	ld [$ff6a], A ; OAM palette index = 0, autoincrement on
	ld H, HIGH(DMGColorToCGB)
	ld E, $03

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
	jr TranslatePalette ; write oam palette 1. tail call.


; Given DMG palette D, write CGB colors to palette data register (ff+C)
; which has autoincrement on.
; H should be HIGH(DMGColorToCGB).
; E should be $03
; Clobbers A, D, L
; Cycle count: 3 * 16 + 15 = 63
TranslatePalette:
REPT 3
	and E ; grab bottom two bits
	rr D
	rr D ; rotate D in prep for next loop
	add A ; A = 2 * palette index
	ld L, A ; L = 2 * index
	; now [HL] = DMGColorToCGB[color]
	ld A, [HL+]
	ld [C], A
	ld A, [HL]
	ld [C], A
	ld A, D ; restore A for next loop
ENDR
	; final loop: don't update D, don't restore from D at end
	and E ; grab bottom two bits
	add A ; A = 2 * palette index
	ld L, A ; L = 2 * index
	; now [HL] = DMGColorToCGB[color]
	ld A, [HL+]
	ld [C], A
	ld A, [HL]
	ld [C], A

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
	ld b, 40
	ld c, LOW(rDMA)
	ld hl, rNR50
	ld d, [hl]
	ld e, d
	jp $ff80 ; tail call
