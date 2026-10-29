extends RefCounted

const DURATION := 180.0
const COOLDOWN := 1.45
const PERFECT_WINDOW := 0.35
const CELL_COUNT := 24
const TARGET := 20
const HOLD_SECONDS := 4.0

var phase := "select"
var side := "grok"
var cells: Array[String] = []
var elapsed := 0.0
var cooldown_left := 0.0
var ready_age := 0.0
var enemy_timer := 1.9
var hold_time := 0.0
var opened := 0
var closed_enemy := 0
var closed_own := 0
var perfects := 0
var won := false
var reason := ""
var revision := 0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	cells.resize(CELL_COUNT)
	cells.fill("")

func enemy() -> String:
	return "jbt" if side == "grok" else "grok"

func count(owner: String) -> int:
	return cells.count(owner)

func start(chosen_side: String) -> void:
	side = chosen_side if chosen_side in ["grok", "jbt"] else "grok"
	phase = "running"
	elapsed = 0.0
	cooldown_left = 0.0
	ready_age = 0.0
	enemy_timer = 1.9
	hold_time = 0.0
	opened = 0
	closed_enemy = 0
	closed_own = 0
	perfects = 0
	won = false
	reason = ""
	cells.fill("")
	for i in range(4): _place(side)
	for i in range(6): _place(enemy())
	revision += 1

func _slots(owner: String) -> Array[int]:
	var found: Array[int] = []
	for i in range(cells.size()):
		if cells[i] == owner: found.append(i)
	return found

func _place(owner: String) -> bool:
	var free := _slots("")
	if free.is_empty(): return false
	cells[free[rng.randi_range(0, free.size()-1)]] = owner
	revision += 1
	return true

func spawn_own() -> int:
	if phase != "running" or cooldown_left > 0.0: return 0
	var available: int = cells.count("")
	if available == 0: return 0
	var perfect := ready_age <= PERFECT_WINDOW
	var amount := mini(2 if perfect else 1, available)
	for i in range(amount): _place(side)
	opened += amount
	if perfect: perfects += 1
	cooldown_left = COOLDOWN
	ready_age = 0.0
	return amount

func close_tab(index: int) -> bool:
	if phase != "running" or index < 0 or index >= CELL_COUNT or cells[index] == "": return false
	if cells[index] == side: closed_own += 1
	else: closed_enemy += 1
	cells[index] = ""
	if count(side) < TARGET: hold_time = 0.0
	revision += 1
	return true

func tick(delta: float) -> void:
	if phase != "running" or delta <= 0.0: return
	var step := minf(delta, DURATION-elapsed)
	elapsed += step
	ready_age += maxf(0.0, step-cooldown_left)
	cooldown_left = maxf(0.0, cooldown_left-step)
	enemy_timer -= step
	while enemy_timer <= 0.0:
		if not _place(enemy()):
			var own := _slots(side)
			if not own.is_empty():
				cells[own[rng.randi_range(0,own.size()-1)]] = enemy()
				revision += 1
		enemy_timer += lerpf(1.9,1.25,elapsed/DURATION)
	if count(side) >= TARGET: hold_time += step
	else: hold_time = 0.0
	if hold_time >= HOLD_SECONDS: finish(true,"control")
	elif elapsed >= DURATION: finish(false,"timeout")

func finish(victory: bool, why: String) -> void:
	if phase != "running": return
	won = victory
	reason = why
	phase = "result"
	revision += 1

func result() -> Dictionary:
	return {"side":side,"won":won,"reason":reason,"elapsed":elapsed,"owned":count(side),"opened":opened,"closed_enemy":closed_enemy,"closed_own":closed_own,"perfects":perfects}

func snapshot() -> Dictionary:
	return {"version":1,"phase":phase,"side":side,"cells":cells.duplicate(),"elapsed":elapsed,"cooldown_left":cooldown_left,"ready_age":ready_age,"enemy_timer":enemy_timer,"hold_time":hold_time,"opened":opened,"closed_enemy":closed_enemy,"closed_own":closed_own,"perfects":perfects,"won":won,"reason":reason,"rng_state":str(rng.state)}

func restore(raw: Dictionary) -> void:
	phase = "select"
	if raw.get("phase","") not in ["running","result"]: return
	if raw.get("side","") not in ["grok","jbt"]: return
	var saved: Variant = raw.get("cells",[])
	if not saved is Array or saved.size() != CELL_COUNT: return
	for owner in saved:
		if owner not in ["","grok","jbt"]: return
	side = str(raw.side)
	cells.assign(saved)
	for key in ["elapsed","cooldown_left","ready_age","enemy_timer","hold_time"]:
		var value: Variant = raw.get(key,0.0)
		if not (value is int or value is float) or not is_finite(float(value)): return
	elapsed = clampf(float(raw.get("elapsed",0.0)),0.0,DURATION)
	cooldown_left = clampf(float(raw.get("cooldown_left",0.0)),0.0,COOLDOWN)
	ready_age = clampf(float(raw.get("ready_age",0.0)),0.0,DURATION)
	enemy_timer = clampf(float(raw.get("enemy_timer",1.9)),0.01,1.9)
	hold_time = clampf(float(raw.get("hold_time",0.0)),0.0,HOLD_SECONDS)
	opened = clampi(int(raw.get("opened",0)),0,10000)
	closed_enemy = clampi(int(raw.get("closed_enemy",0)),0,10000)
	closed_own = clampi(int(raw.get("closed_own",0)),0,10000)
	perfects = clampi(int(raw.get("perfects",0)),0,10000)
	won = raw.get("won",false) == true
	reason = str(raw.get("reason",""))
	if raw.get("rng_state") is String and raw.rng_state.is_valid_int(): rng.state = raw.rng_state.to_int()
	phase = str(raw.phase)
	revision += 1
