@tool
extends McpTestSuite

func suite_name() -> String:
	return "battlefield"

func test_map_and_bridges() -> void:
	var builder: MapBuilder = track(MapBuilder.new()) as MapBuilder
	builder.grid_size = Vector2i(30, 20)
	
	var blocked: Array[Vector2i] = builder.build(null, null, null, null)
	assert_gt(blocked.size(), 30, "Rivers and ponds must block more than 30 tiles")
	
	# Bridges must NOT be blocked
	var bridge_crossings: Array[Vector2i] = [
		Vector2i(10, 4), Vector2i(19, 4),
		Vector2i(10, 15), Vector2i(19, 15)
	]
	for b in bridge_crossings:
		assert_false(blocked.has(b), "Bridge crossing at %s must remain walkable" % str(b))
