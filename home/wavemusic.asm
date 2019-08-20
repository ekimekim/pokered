
; Begin playing wave music song with id in A
WaveMusicStart::
    ; stub for now: play fixed tone
    ld a, $80
    ld [rNR30], a ; turn on ch3
    ld a, [rNR51]
    or %01000100 ; enable ch3 in mux
    ld [rNR51], a
    ld a, %00100000 ; no shift of samples
    ld [rNR32], a
    ld hl, rNR34
    set 7, [hl] ; play
    ret

