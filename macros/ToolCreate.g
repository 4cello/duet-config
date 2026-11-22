; CreateTool.g

var index = 0
var diameter = 0
var rpm = 0
var name = ""
var title = "New tool"

if {exists(param.I)}
    set var.index = param.I
else
    M291 R{var.title} P"Tool number:" S5 J2
    if {input == null}
        abort "Tool creation cancelled"
    set var.index = input
set var.title = var.title ^ ": Index=" ^ {var.index}

if {exists(param.N)}
    set var.name = param.N
else
    M291 R{var.title} P"Tool name (Diameter will be appended later):" S7 J2
    if {input == null}
        abort "Tool creation cancelled"
    set var.name = input
set var.title = var.title ^ ", Name=" ^ {var.name}

if {exists(param.D)}
    set var.diameter = param.D
else
    M291 R{var.title} P"Tool diameter (mm):" S6 J2
    if {input == null}
        abort "Tool creation cancelled"
    set var.diameter = input
set var.title = var.title ^ ", Diameter=" ^ {var.diameter}

if {exists(param.F)}
    set var.rpm = param.F
else
    M291 R{var.title} P"Maximum spindle RPM:" S5 J2
    if {input == null}
        abort "Tool creation cancelled"
    set var.rpm = input

if {!exists(global.tool_diameter)}
    global tool_diameter = []
if #global.tool_diameter <= var.index
    var newDiameters = {vector(var.index + 1, -1)}
    var i = 0
    while var.i < #global.tool_diameter
        set var.newDiameters[var.i] = global.tool_diameter[var.i]
        set var.i = var.i + 1
    set global.tool_diameter = var.newDiameters
set global.tool_diameter[var.index] = var.diameter

; Construct tool name
if var.diameter > 0
    set var.name = var.name ^ " (D" ^ var.diameter ^ "mm)"

; Create tool
M563 P{var.index} R0 S{var.name}
; Assign RPM
M568 P{var.index} F{var.rpm}

M291 P{"Created T" ^ var.index ^ ": " ^ var.name} R"Tool created" S2