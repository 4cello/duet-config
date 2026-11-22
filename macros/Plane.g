
; ============================================
; Plane rectangular workpiece
; RepRapFirmware 3.7
;
; Parameters:
; X = Width (mm)
; Y = Length (mm)
; Z = Total depth to remove (mm)
; F = Cutting feedrate (mm/min)
; S = Stepover (fraction of tool diameter)
; D = Maximum stepdown (mm)
;
; Defaults:
; F = 1200
; S = 0.4
; D = 0.2
; ============================================

; Check for selected tool FIRST
if state.currentTool < 0
    abort "No tool selected. Select a tool before running Plane.g"

; Read parameters
var width = {exists(param.X) ? param.X : 100}
var length = {exists(param.Y) ? param.Y : 100}
var depth = {exists(param.Z) ? param.Z : 1}
var feed = {exists(param.F) ? param.F : 1200}
var stepFraction = {exists(param.S) ? param.S : 0.4}
var stepdown = {exists(param.D) ? param.D : 0.2}

; Tool diameter
var diameter = global.tool_diameter[state.currentTool]
var radius = var.diameter / 2

; Calculate stepover
var step = var.diameter * var.stepFraction

; Validate parameters
if var.width <= 0 || var.length <= 0 || var.depth <= 0
    abort "X, Y and Z must be greater than zero"

if var.feed <= 0 || var.stepdown <= 0
    abort "F and D must be greater than zero"

if var.stepFraction <= 0 || var.stepFraction > 1
    abort "S must be greater than 0 and no greater than 1"

if var.diameter <= 0
    abort "Invalid tool diameter"

if var.width < var.diameter || var.length < var.diameter
    abort "Workpiece dimensions must be at least one tool diameter"

; Show cutting parameters and wait for confirmation
var message = "Width: " ^ var.width ^ "mm\n"
set var.message = var.message ^ "Length: " ^ var.length ^ "mm\n"
set var.message = var.message ^ "Depth: " ^ var.depth ^ "mm\n"
set var.message = var.message ^ "Feedrate: " ^ var.feed ^ "mm/min\n"
set var.message = var.message ^ "Stepover: " ^ var.stepFraction ^ " (" ^ var.step ^ "mm)\n"
set var.message = var.message ^ "Stepdown: " ^ var.stepdown ^ "mm\n"
set var.message = var.message ^ "Tool diameter: " ^ var.diameter ^ "mm\n\n"
set var.message = var.message ^ "Start the spindle, then press OK."

M291 P{var.message} R"Facing operation" S2

; Absolute positioning, millimetres
G21
G90

; Move to origin at safe height
G53 G0 Z{global.safe_travel_height}
G0 X0 Y0

; Move to the first cutting position
G0 X{var.radius} Y{var.radius}

; ============================================
; DEPTH PASSES
; ============================================

var currentDepth = 0
var left = var.radius
var right = var.width - var.radius
var bottom = var.radius
var top = var.length - var.radius


while var.currentDepth < var.depth

    set var.currentDepth = {min(var.currentDepth + var.stepdown, var.depth)}

    G1 Z{-var.currentDepth} F{var.feed}

    ; Initial spiral boundaries
    set var.left = var.radius
    set var.right = var.width - var.radius
    set var.bottom = var.radius
    set var.top = var.length - var.radius

    ; ========================================
    ; INWARD RECTANGULAR SPIRAL
    ; Counter-clockwise viewed from above
    ; ========================================

    while var.left <= var.right && var.bottom <= var.top

        ; Bottom edge: +X
        G1 X{var.right} Y{var.bottom}

        ; Right edge: +Y
        G1 X{var.right} Y{var.top}

        ; Top edge: -X
        G1 X{var.left} Y{var.top}

        ; Left edge: -Y
        G1 X{var.left} Y{var.bottom}

        ; Move inward for next spiral revolution
        set var.left = var.left + var.step
        set var.right = var.right - var.step
        set var.bottom = var.bottom + var.step
        set var.top = var.top - var.step

        ; Connect to the next revolution
        if var.left <= var.right && var.bottom <= var.top
            G1 X{var.left} Y{var.bottom}

; ============================================
; FINISH
; ============================================

M5

G0 Z5

M400
