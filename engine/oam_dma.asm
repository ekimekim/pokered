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
;   b = 40
; Writes d to [hl] immediately (2 cycles after call). Then writes e to [hl]
; immediately after DMA, with exactly 164 cycles between.
; Don't forget to include time to do the call when timing this.
; Total size: 8
; Which is 2 less than the original routine.
DMARoutine:
	; write d, 2 cycles. 164-cycle timer starts.
	ld [hl], d

	; initiate DMA, 2 cycles
	ld [c], a

	; wait for dma - 40*4 + 3 (last iteration is faster)
.wait1
	dec b
	jr nz, .wait1
	; now we're at 161 cycles
	nop ; 162

	; write e, 2 cycles, so it ends on cycle 164
	ld [hl], e

	ret
DMARoutineEnd:
