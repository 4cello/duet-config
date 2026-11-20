M452 S1 C"nil" R255 F200; switch to laser mode while freeing the pin
M950 F2 C"laser" Q200	; create "Fan 2" on laser pin
M106 P2 S0.1				; turn on laser on 1/255th power
