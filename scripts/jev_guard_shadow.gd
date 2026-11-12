extends Node
## Optional search planner. Godot validates and reserves every accepted choice.
const ENDPOINT := "https://api.typesafe.ai/v1/systemone"
const MAX_REQUESTS := 40
const BUDGET := &"miro_jev_shadow_requests"
const LAST_REQUEST := &"miro_jev_shadow_last_ms"
var pending := false

## Jev plans the next perimeter step after Godot and Qwen have already made
## their immediate assignments. It returns a strategy, never a guard ID.
func plan_search(trace: int, state: Dictionary, accept: Callable) -> void:
	if pending or "--jev-guard-shadow" not in OS.get_cmdline_user_args():
		return
	var key := OS.get_environment("JEV_API_KEY").strip_edges()
	if key.is_empty():key = OS.get_environment("TYPESAFE_API_KEY").strip_edges()
	if key.is_empty():
		print("JEV: fallback missing_key trace=%d" % trace)
		accept.call("hold")
		return
	var used := int(Engine.get_meta(BUDGET, 0))
	var now := Time.get_ticks_msec()
	if used >= MAX_REQUESTS or now - int(Engine.get_meta(LAST_REQUEST, -3000)) < 3000:
		return
	var strategies := ["hold", "left", "right", "up", "down"]
	var criteria := {}
	for strategy in strategies:
		criteria[strategy] = "Keep the current perimeter." if strategy == "hold" else "Extend to the %s approach, only if listed in reachable_approaches; up/down use authored ladders." % strategy
	var payload := {"model": "jev-latest", "state": state,
		"questions": {"search": {"type": "choice", "criteria": criteria,
			"instructions": "Miro is no longer visible. Suggest one next perimeter action only using reachable_approaches. Do not replace the investigator or immediate cover post. Cover an uncovered escape route or hold; never infer Miro's live position."}}}
	var request := HTTPRequest.new()
	request.timeout = 4.0
	request.body_size_limit = 65536
	add_child(request)
	pending = true
	request.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
		pending = false
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or status != 200:
			print("JEV_SHADOW: search trace=%d unavailable result=%d status=%d" % [trace, result, status])
			accept.call("hold")
			return
		var data = JSON.parse_string(bytes.get_string_from_utf8())
		if data is Dictionary and data.get("answers") is Dictionary:
			var answer = data.answers.get("search")
			var strategy := str(answer.get("choice", "")) if answer is Dictionary else ""
			if strategies.has(strategy):
				print("JEV: search trace=%d strategy=%s ms=%d" % [trace, strategy, Time.get_ticks_msec() - now])
				accept.call(strategy)
				return
		print("JEV: invalid response trace=%d" % trace)
		accept.call("hold")
	, CONNECT_ONE_SHOT)
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + key])
	if request.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) == OK:
		print("JEV: search request trace=%d" % trace)
		Engine.set_meta(BUDGET, used + 1)
		Engine.set_meta(LAST_REQUEST, now)
	else:
		pending = false
		request.queue_free()

