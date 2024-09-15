# Chandler Frakes

extends BaseHitbox
class_name Tether

# HOW GRAPPLING / TETHERING DATA IS FORMATTED IN move_data:
# [ 
#   1.5 (legnth of animation so that we can skip to the end if player not detected in window shown above),
#   0.8 ("yoink" frame / point in animation where character reacts to tethering to the opponent)
# ]
# ADDITIONALLY, one will need to attach two NetworkTimers to the respective Tether scene
#   - ActiveTimer: Window of time that tether can extend from player for
#                  (can be thought of as the "length" of the "chain")
#   - FinishTimer: If tether obj. collides with opp. -> time that it takes for the opp. to get pulled
#                  (usually to play reaction animation) 


# ---------------------------------------- CONSTANTS ------------------------------------------ #

const TICKS_PER_SECOND : float = 30.0
const DELTA : float = (1.0 / TICKS_PER_SECOND)

# ---------------- PROPERTIES ----------------- #

@onready var active_timer = $ActiveTimer
@onready var finish_timer = $FinishTimer

@export var speed: int

var direction
var target_displayed = false
var image = load("res://resources/Images/red_crosshair.png")
var target = Sprite3D.new()
var map

var hooked = false
var move_finished = false
var fired_timer = false

# ---------------- FUNCTIONS ---------------- #

func display_target():
	if !self.target_displayed:
		if self.owner_char.targetting:
			var scale = 0.17
			self.target.scale = Vector3(scale, scale, scale)
			self.target.texture = self.image
			self.target.billboard = true
			self.target.transparency = 0.5
			
			self.map = get_parent()
			self.map.add_child(self.target)
			self.map.move_child(self.target, self.map.get_child_count() - 1)
			self.target.global_position = self.owner_char.z_target.global_position
			self.target_displayed = true


# overrideable virtual method.
func _after_hit_computation() -> void:
	self.owner_char.current_move.move_end_timer.stop()
	self.owner_char.current_move.move_end_timer.emit_signal("timeout")
	SyncManager.despawn(self)


func emit():
	self.direction = get_direction()
	self.active = true


func get_direction():
	if self.owner_char and self.owner_char.targetting and self.owner_char.z_target:
		return self.owner_char.global_position.direction_to(self.owner_char.z_target.global_position)
	else:
		# if not targetting, simply shoot left or right
		if (!self.owner_char.sprite.flip_h):
			return self.owner_char.global_position.direction_to(Vector3(self.owner_char.global_position.x + 1000, 0, self.owner_char.global_position.x + 1000))
		else:
			return self.owner_char.global_position.direction_to(Vector3(self.owner_char.global_position.x - 1000, 0, self.owner_char.global_position.x - 1000))


func on_collision_detected(colliding_node) -> void:
	if self.node_is_char(colliding_node) and colliding_node != self.owner_char and (self.hit_chars.get(colliding_node) == null or self.hit_chars.get(colliding_node) == false):
		self.hit_chars[colliding_node] = true
		self.speed = 0
		self.hooked = true
		self.active = false
		if self.move_finished:
			on_hit(colliding_node)


func _on_finish_move_timer_timeout() -> void:
	self.move_finished = true
	self.active = true
	finish_timer = null


func finish_move():
	self.owner_char.anim_player.seek(self.owner_char.current_move.move_data[2])
	self.owner_char.can_move = false
	finish_timer.start()

# ------------------- INIT AND LOOP --------------------- #

func _network_spawn(data: Dictionary) -> void:
	self.owner_char = data["owner_char"]
	self.global_position = data["global_position"]
	self.emit()


# this only runs when the node and ITS CHILDREN have loaded
func _ready() -> void:
	finish_timer.connect("timeout", self._on_finish_move_timer_timeout)
	
	# turn off collisions with default world
	# hitboxes will be on layer 3
	self.set_collision_layer_value(3, true)
	
	# set hitboxes to detect for areas on layer 2 and 5
	self.set_collision_mask_value(2, true)
	self.set_collision_mask_value(5, true)


func _network_process(input: Dictionary) -> void:
	# start the monitoring window to grab opponent
	if !fired_timer:
		# active window
		active_timer.start()
		self.fired_timer = true
	if self.hooked:
		self.global_position = self.owner_char.z_target.global_position
	else:
		self.owner_char.can_move = true
	if active_timer:
		if active_timer.ticks_left > 0:
			if hooked:
				active_timer = null
				finish_move()
		else:
			# cancel/skip to end of animation and despawn
			_after_hit_computation()
	
	# Normal projectile code
	if self.active:
		if self.target_displayed:
			self.map.remove_child(self.target)
		self.global_position += self.speed * self.direction * DELTA
		self.hit_chars = {}
		self.monitoring = true
		if self.debug_on == true and self.mesh_instance != null:
			self.mesh_instance.visible = true
	else:
		self.global_position = self.owner_char.global_position
		self.monitoring = false
		self.hit_chars = {}
		if self.mesh_instance != null:
			self.mesh_instance.visible = false
	
	if self.monitoring and self.has_overlapping_bodies():
		for body in self.get_overlapping_bodies():
			on_collision_detected(body)


func _save_state() -> Dictionary:
	return {
		global_position = self.global_position,
		speed = self.speed,
		direction = self.direction,
		hooked = self.hooked,
		fired_timer = self.fired_timer
	}


func _load_state(state: Dictionary) -> void:
	self.global_position = state["global_position"]
	self.speed = state["speed"]
	self.direction = state["direction"]
	self.hooked = state["hooked"]
	self.fired_timer = state["fired_timer"]


func _init(speed = 0):
	super()
	self.speed = speed
