
; ==========================================
; TOOL LENGTH MEASUREMENT
; ==========================================

M400
G90

; Reset existing tool Z offset
G10 L1 P{state.currentTool} Z0

; Move to safe travel height
G53 G1 Z{global.safe_travel_height} F{global.toolsetter_travel_feed}

; Move to fixed setter
G53 G1 X{global.toolsetter_x} Y{global.toolsetter_y} F{global.toolsetter_travel_feed}

; Probe setter and update active tool offset
; TODO: is this to blame?
M585 K{global.toolsetter_probe} Z{-global.safe_travel_height+global.toolsetter_z} S1 F300

; Retract
G91
G1 Z{global.toolsetter_retract} F600 H1
G90
