var t = 0


M28 "/sys/tools.g"
while {var.t < #tools}
  if {tools[var.t] != null}
    echo {var.t}
  set var.t = var.t + 1
M29