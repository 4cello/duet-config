; pause.g
; called when a print from SD card is paused

if {global.skip_pause}
    set global.skip_pause = false
else
    G91
    G1 Z5 H3 	; move up to 5mm (H3 = terminate on endstop)
    M5 			; turn off spindle
    G4 S20		; wait for spindle to stop
    G90