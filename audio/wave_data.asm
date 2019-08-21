

SECTION "Testing track", ROMX

; Dummy test data
TestingTrack:
	; full up, then down, every 4 samples = 1/4 sample freq square wave ~= 4kHz
	; for about 0.25s
REPT 1200
	db $77, $ff
	db $77, $ff
	db $77, $00
	db $77, $00
ENDR
	; then the same but half freq (every 8 samples) for another 0.25s
REPT 600
	db $77, $ff
	db $77, $ff
	db $77, $ff
	db $77, $ff
	db $77, $00
	db $77, $00
	db $77, $00
	db $77, $00
ENDR
	; then loop
	WaveJump TestingTrack
