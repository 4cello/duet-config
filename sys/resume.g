; resume.g
; called before a print from SD card is resumed

if {global.skip_resume}
    set global.skip_resume = false
else
    M3 R1					; restore spindle speed
    G4 S15					; wait for spindle to get up to speed
    G1 R1 X0 Y0 Z5 F6000 	; go to 5mm above position of the last print move
    G1 R1 X0 Y0          	; go back to the last print move