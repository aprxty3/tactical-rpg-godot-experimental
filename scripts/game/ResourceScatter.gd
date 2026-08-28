extends RefCounted
class_name ResourceScatter
## ResourceScatter — lays the mines and villages out fresh every match, without
## giving anyone a better opening than anyone else.
##
## The authored layout in `Match.tscn` was hand-tuned until all four armies were
## exactly the same walk from a gold mine, an iron mine and two villages. That is
## worth keeping and it is also the same board every single time. This rolls a
## new one per match and keeps the guarantee, by never placing a single building:
## it places an ORBIT of four — a cell and its three mirror images — so the
## layout is symmetric under the same reflections that map one castle onto
## another. Symmetry is what makes it fair; the roll is what makes it different.
##
## Symmetry alone is not quite proof, because the terrain under it is only
## roughly symmetric (the centre road sits a column off, one pond is a row off).
## So every candidate orbit is measured with a real path search from all four
## castles and rejected unless the four distances tie exactly. A fair map is a
## measured property here, not an assumed one.
##
## A RefCounted with injected collaborators, like `ArmyMuster` and
## `PandoraTable`: it can be run against a bare grid and interrogated without
## building a match around it.

## How much room to leave around a castle, in cells. The opening army musters
## from the rings immediately outside its keep, and a mine dropped into that
## ring is one fewer place to stand.
const CASTLE_CLEARANCE: int = 3

## Minimum Manhattan gap between cells belonging to different orbits, so two
## prizes never end up close enough to be taken as one.
const ORBIT_SPACING: int = 3

## How many complete layouts to try before giving up and leaving the authored
## one alone. Each attempt is a fresh draw from pools that are already known to
## be fair, so failure here means the SPACING could not be satisfied, not that
## the map is unfair.
const MAX_ATTEMPTS: int = 400

## Distances are measured in movement points. This stands in for "unreachable".
const UNREACHABLE: int = 1 << 20

## How far from the nearest castle each kind of prize may sit, in movement
## points. Fairness alone leaves the map shapeless: a draw that pushes both
## village orbits thirteen moves out is perfectly even-handed and still a bad
## board, because nobody can garrison anything before turn five. These bands are
## what make a roll feel like the same game each time — near villages, a flank
## mine worth an early march, and iron far enough out to be genuinely contested.
const REACH_BAND: Dictionary = {
	"gold_mine": Vector2i(3, 11),
	"iron_mine": Vector2i(9, 16),
	"village": Vector2i(2, 9),
}

var _grid: GridManager
var _rng: RandomNumberGenerator

## Inclusive x ranges within the LEFT half of the map, derived from where the
## rivers actually are rather than written down as numbers a second time.
## `_centre_band` is the contested lane between the two rivers; `_flank_band` is
## the army's own side of the near river.
var _centre_band: Vector2i
var _flank_band: Vector2i


func _init(grid_manager: GridManager, rng: RandomNumberGenerator) -> void:
	_grid = grid_manager
	_rng = rng
	_compute_bands()


## Roll a layout and move the resource buildings onto it.
##
## Nothing moves unless a complete, measured-fair layout was found — a
## half-applied board would be worse than the authored one, so the authored one
## stands whenever this cannot better it.
func scatter(buildings: Array) -> Dictionary:
	var report: Dictionary = roll(buildings)
	report["applied"] = report["found"]
	if not report["found"]:
		return report

	var by_type: Dictionary = _group(buildings)
	for kind in ["gold_mine", "iron_mine", "village"]:
		_place(by_type[kind], report[kind])
	return report


## Everything `scatter` does except touching the board.
##
## Separate so the roll can be interrogated — twice with different seeds, to
## prove it actually rolls — without a test having to rearrange a live match to
## find out. `found` says whether a layout was reached; the three cell arrays
## say where each kind would go.
func roll(buildings: Array) -> Dictionary:
	var report: Dictionary = {
		"found": false, "reason": "",
		"gold_mine": [], "iron_mine": [], "village": [],
	}

	var by_type: Dictionary = _group(buildings)
	var anchors: Array[Vector2i] = _mirror_castles(by_type["castle"])
	if anchors.size() != 4:
		report["reason"] = "the map has no four-fold ring of castles to be fair between"
		return report

	# Every kind is placed four at a time. A map holding a number that is not a
	# multiple of four cannot be laid out symmetrically at all, and quietly
	# dropping the remainder would be a silent change to that map's economy.
	var wanted: Dictionary = {}
	for kind in ["gold_mine", "iron_mine", "village"]:
		var count: int = by_type[kind].size()
		if count % 4 != 0:
			report["reason"] = "%d %s(s) will not divide into orbits of four" % [count, kind]
			return report
		wanted[kind] = count / 4

	var fields: Dictionary = {}
	for anchor in anchors:
		fields[anchor] = distance_field(anchor)

	var pools: Dictionary = _build_pools(anchors, fields, by_type["castle"])
	for kind in wanted:
		if pools[kind].size() < wanted[kind]:
			report["reason"] = "only %d fair %s orbit(s) on this map" % [pools[kind].size(), kind]
			return report

	var layout: Dictionary = _choose(pools, wanted)
	if layout.is_empty():
		report["reason"] = "no draw satisfied the spacing between orbits"
		return report

	for kind in layout:
		report[kind] = layout[kind]
	report["found"] = true
	return report


# ==============================================================================
# THE MIRROR GROUP
# ==============================================================================

## A cell and its three reflections. Returned in a stable order, and empty when
## the cell lies on an axis — a cell that is its own mirror cannot seed an orbit
## of four, and half an orbit is exactly the asymmetry this exists to prevent.
func orbit_of(cell: Vector2i) -> Array[Vector2i]:
	var size: Vector2i = _grid.grid_size
	var mx: int = size.x - 1 - cell.x
	var my: int = size.y - 1 - cell.y
	if mx == cell.x or my == cell.y:
		return [] as Array[Vector2i]
	return [
		cell,
		Vector2i(mx, cell.y),
		Vector2i(cell.x, my),
		Vector2i(mx, my),
	] as Array[Vector2i]


## The castles that actually form a four-fold ring.
##
## Derived rather than listed: a castle belongs to the ring exactly when all
## three of its mirror images are castles too. That drops the Black Coven's keep
## in the middle of the map — which is nobody's opening position — without this
## needing to know that the Black Coven exists.
func _mirror_castles(castles: Array) -> Array[Vector2i]:
	var occupied: Dictionary = {}
	for cell in castles:
		occupied[cell] = true

	var ring: Array[Vector2i] = []
	for cell in castles:
		var orbit: Array[Vector2i] = orbit_of(cell)
		if orbit.is_empty():
			continue
		var complete: bool = true
		for c in orbit:
			if not occupied.has(c):
				complete = false
				break
		if complete:
			ring.append(cell)
	return ring


# ==============================================================================
# MEASUREMENT
# ==============================================================================

## Movement-point cost from `origin` to every cell it can reach.
##
## A real Dijkstra over the grid's own move costs, not Manhattan distance: the
## first hand-balanced layout put two mines in forest at 2 MP a cell, which is an
## asymmetry a ruler cannot see. Run before the terrain map is filled in, every
## open cell costs 1 and this degrades to a plain BFS — the right answer for a
## board whose only obstacles at that point are its rivers.
func distance_field(origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]

	while not frontier.is_empty():
		var best_i: int = 0
		for i in range(frontier.size()):
			if dist[frontier[i]] < dist[frontier[best_i]]:
				best_i = i
		var cur: Vector2i = frontier[best_i]
		frontier.remove_at(best_i)

		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = cur + d
			if not _is_open(nxt):
				continue
			var nd: int = int(dist[cur]) + _grid.get_move_cost(nxt)
			if not dist.has(nxt) or nd < int(dist[nxt]):
				dist[nxt] = nd
				frontier.append(nxt)
	return dist


## Open ground for the purposes of measuring the map's shape. Deliberately blind
## to who is standing where: this measures the board, and on the turn it runs
## nobody has been mustered onto it yet anyway.
func _is_open(cell: Vector2i) -> bool:
	if not _grid.is_within_bounds(cell):
		return false
	return _grid.get_move_cost(cell) < GameConfig.MOVE_COST_IMPASSABLE \
		and _grid.is_cell_walkable(cell)


## How far each castle is from the nearest cell of this orbit.
func _reach(orbit: Array[Vector2i], anchors: Array[Vector2i], fields: Dictionary) -> Array[int]:
	var reach: Array[int] = []
	for anchor in anchors:
		var field: Dictionary = fields[anchor]
		var best: int = UNREACHABLE
		for cell in orbit:
			if field.has(cell):
				best = mini(best, int(field[cell]))
		reach.append(best)
	return reach


# ==============================================================================
# CANDIDATE POOLS
# ==============================================================================

## Every orbit that is legal ground AND measures the same from all four castles,
## sorted into the kind of prize it is allowed to hold.
##
## Gold sits on the flanks and iron in the contested middle. That is not an
## aesthetic choice: it is the shape the map was balanced into deliberately —
## the flank prize is yours to hold, the centre prize is the reason to march.
## Villages go anywhere, because their job is to be spread out.
func _build_pools(anchors: Array[Vector2i], fields: Dictionary,
		castles: Array) -> Dictionary:
	var pools: Dictionary = {"gold_mine": [], "iron_mine": [], "village": []}
	var size: Vector2i = _grid.grid_size

	# Only the top-left quadrant is walked. Every other quadrant is reachable as
	# somebody's mirror image, so walking them all would just find each orbit
	# four times over.
	for x in range((size.x + 1) / 2):
		for y in range((size.y + 1) / 2):
			var orbit: Array[Vector2i] = orbit_of(Vector2i(x, y))
			if orbit.is_empty() or not _orbit_is_placeable(orbit, castles):
				continue

			var reach: Array[int] = _reach(orbit, anchors, fields)
			var lo: int = UNREACHABLE
			var hi: int = -1
			for r in reach:
				lo = mini(lo, r)
				hi = maxi(hi, r)
			# An exact tie, not a tolerance. A tolerance is how a map ends up
			# with one army a turn ahead every single match.
			if hi >= UNREACHABLE or hi != lo:
				continue

			if x >= _centre_band.x and x <= _centre_band.y:
				_offer(pools, "iron_mine", orbit, lo)
			elif x >= _flank_band.x and x <= _flank_band.y:
				_offer(pools, "gold_mine", orbit, lo)
			_offer(pools, "village", orbit, lo)
	return pools


## Add an orbit to a pool if it sits the right distance out for that kind.
func _offer(pools: Dictionary, kind: String, orbit: Array[Vector2i], reach: int) -> void:
	var band: Vector2i = REACH_BAND[kind]
	if reach >= band.x and reach <= band.y:
		pools[kind].append(orbit)


func _orbit_is_placeable(orbit: Array[Vector2i], castles: Array) -> bool:
	for cell in orbit:
		if not _is_open(cell):
			return false
		# Bridges stay clear because a bridge is the only way across a river and
		# putting a prize on one turns the crossing into the prize. Forest and
		# rock stay clear because those cells already hold a prop sprite, and a
		# village drawn on top of a boulder is a bug the player can see. Roads
		# need no exclusion: a building blocks nobody's movement.
		var terrain: int = _grid.get_terrain(cell)
		if terrain in [GameConfig.TerrainType.BRIDGE, GameConfig.TerrainType.WATER,
				GameConfig.TerrainType.FOREST, GameConfig.TerrainType.ROCK]:
			return false
		for castle in castles:
			if _manhattan(cell, castle) < CASTLE_CLEARANCE:
				return false
	return true


## Where the rivers are decides what "flank" and "centre" mean, so both bands
## are read off MapBuilder instead of being written down as numbers twice.
## Falls back to a straight half-and-half split on a map with no rivers.
func _compute_bands() -> void:
	var half: int = (_grid.grid_size.x - 1) / 2
	var rivers: Array[int] = MapBuilder.RIVER_COLUMNS
	if rivers.is_empty():
		_flank_band = Vector2i(0, half / 2)
		_centre_band = Vector2i(half / 2 + 1, half)
		return
	var west: int = rivers[0]
	_flank_band = Vector2i(0, west - 1)
	_centre_band = Vector2i(west + 1, half)


# ==============================================================================
# THE DRAW
# ==============================================================================

## Draw one layout: `wanted[kind]` orbits of each kind, no two chosen cells
## closer than ORBIT_SPACING. Retried as a whole rather than backtracked — a
## failed draw costs nothing, and a backtracking search here would be more
## machinery than a board this size can justify.
func _choose(pools: Dictionary, wanted: Dictionary) -> Dictionary:
	for _attempt in range(MAX_ATTEMPTS):
		var taken: Dictionary = {}
		var layout: Dictionary = {}
		var ok: bool = true

		# Iron first, then gold, then villages: the tightest pool draws while the
		# board is still empty, or it is the one that keeps failing.
		for kind in ["iron_mine", "gold_mine", "village"]:
			var picked: Array = _draw(pools[kind], int(wanted[kind]), taken)
			if picked.size() < int(wanted[kind]):
				ok = false
				break
			layout[kind] = picked

		if ok:
			return layout
	return {}


## Pick `count` orbits at random from `pool`, skipping any that crowd a cell
## already claimed. Draws without replacement so it always terminates.
func _draw(pool: Array, count: int, taken: Dictionary) -> Array[Vector2i]:
	var bag: Array = pool.duplicate()
	var cells: Array[Vector2i] = []
	var found: int = 0

	while found < count and not bag.is_empty():
		var idx: int = _rng.randi_range(0, bag.size() - 1)
		var orbit: Array = bag[idx]
		bag.remove_at(idx)

		var crowded: bool = false
		for cell in orbit:
			for other in taken:
				if _manhattan(cell, other) < ORBIT_SPACING:
					crowded = true
					break
			if crowded:
				break
		if crowded:
			continue

		for cell in orbit:
			taken[cell] = true
			cells.append(cell)
		found += 1
	return cells


# ==============================================================================
# APPLYING IT
# ==============================================================================

func _place(buildings: Array, cells: Array) -> void:
	for i in range(mini(buildings.size(), cells.size())):
		var bld: Building = buildings[i]
		if not is_instance_valid(bld):
			continue
		bld.grid_position = cells[i]
		# The pixel position is authored in the scene file and nothing recomputes
		# it, so moving a building means moving both or the sprite stays behind
		# while the rules move on.
		bld.position = _grid.grid_to_world(cells[i])


func _group(buildings: Array) -> Dictionary:
	var by_type: Dictionary = {"castle": [], "gold_mine": [], "iron_mine": [], "village": []}
	for node in buildings:
		if not (node is Building):
			continue
		var bld: Building = node
		var kind: String = bld.get_type_string()
		if kind == "castle":
			by_type["castle"].append(bld.grid_position)
		elif by_type.has(kind):
			by_type[kind].append(bld)
	return by_type


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
