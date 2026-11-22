; stop.g
; called when M0 (Stop) is run (e.g. when a print from SD card is cancelled)

M5
G91
G1 Z15 F500 H3 ; move up 15mm
G90