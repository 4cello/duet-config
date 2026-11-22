var tool = -1

M5 ; stop spindle
M400

; Save position to slot 5
G60 S5

; Move to toolchange position
G53 G0 Z{global.safe_travel_height}
G53 G0 X{global.toolchange_x} Y{global.toolchange_y}
G53 G0 Z{global.toolchange_z}

if {exists(param.T)}
    ; Tool given
    set var.tool = param.T
elif {state.currentTool >= -1}
    ; Tool was selected previously (and exists)
    set var.tool = state.currentTool
else
    ; Previously selected tool did not exist
    set var.tool = move.motionSystems[0].nextTool

if {exists(tools[var.tool])}
    M291 P{"Please install " ^ tools[var.tool].name} R"Manual tool change" S2
else
    if {var.tool >= 0}
        M98 P"/macros/ToolCreate.g" I{var.tool}
    else
        ; negative tool???
        M291 P"No tool selected. Creating T0" R"Manual tool change" S2
        M563 P0 R0 S"Dummy Tool"
        set var.tool = 0


; tool exists now, measure it
T T{var.tool}
M98 P"/macros/ToolLength.g"


; Move back to previous position
G53 G0 Z{global.safe_travel_height}
G0 R5 X0 Y0
G0 R5 Z0

set global.skip_pause = true
set global.skip_resume = true
M400
; Pause job
M25