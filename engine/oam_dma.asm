WriteDMACodeToHRAM:
; Since no other memory is available during OAM DMA,
; DMARoutine is copied to HRAM and executed there.
	ld c, $ff80 % $100
	ld b, DMARoutineEnd - DMARoutine
	ld hl, DMARoutine
.copy
	ld a, [hli]
	ld [$ff00+c], a
	inc c
	dec b
	jr nz, .copy
	ret

; Expects:
;   a = high(source addr)
;   c = low(rDMA)
;   hl = rNR50
;   e = 40 - b
; After 4 * b + 3 cycles, writes d to [hl]
; Then waits 4 * e - 1 more cycles before returning.
; Total size: 9
; Which is 1 less than the original routine. Success!
DMARoutine:
	; initiate DMA
	ld [c], a

	; wait for volume write
.wait1
	dec b
	jr nz, .wait1

	; do volume write
	ld [hl], d

	; wait for finish
.wait2
	dec e
	jr nz, .wait2

	ret
DMARoutineEnd:
