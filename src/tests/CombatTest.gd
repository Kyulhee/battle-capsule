extends Node3D

# Automated Combat Test Diagnostic
# Runs headlessly to verify bullet blocking and LOS

@onready var player_scn = preload("res://src/entities/player/Player.tscn")
@onready var bot_scn = preload("res://src/entities/bot/Bot.tscn")
@onready var obstacle_scn = preload("res://src/environment/Obstacle.tscn")

var player: Entity
var bot: Entity
var obstacle: Node3D

func _ready():
	print("\n--- STARTING AUTOMATED COMBAT DIAGNOSTIC ---")
	
	setup_scene()
	
	# Case 1: Wall Block
	await test_wall_block()
	
	# Case 2: Open Shot
	await test_open_shot()
	
	print("--- DIAGNOSTIC COMPLETE ---")
	get_tree().quit()

func setup_scene():
	# Ground
	var ground = StaticBody3D.new()
	var coll = CollisionShape3D.new()
	coll.shape = BoxShape3D.new()
	coll.shape.size = Vector3(100, 1, 100)
	ground.add_child(coll)
	add_child(ground)
	ground.collision_layer = 1 # World
	
	# Player at (-5, 0, 0)
	player = player_scn.instantiate()
	add_child(player)
	player.global_position = Vector3(-5, 0, 0)
	
	# Bot at (5, 0, 0)
	bot = bot_scn.instantiate()
	add_child(bot)
	bot.global_position = Vector3(5, 0, 0)
	
	# Rotate bot to face player (Player is at -5, Bot is at 5. Bot should look at -X)
	bot.look_at(Vector3(-5, 0, 0), Vector3.UP)
	
	# Wall at (0, 0, 0)
	obstacle = obstacle_scn.instantiate()
	add_child(obstacle)
	obstacle.global_position = Vector3(0, 1.5, 0)

func test_wall_block():
	print("\n[TEST 1] Testing Wall Block (Bot -> Wall -> Player)")
	player.current_health = 100
	
	# Force bot to shoot 3 times
	for i in range(3):
		bot.shoot()
		await get_tree().create_timer(0.2).timeout
	
	print("Player final HP: ", player.current_health)
	if player.current_health == 100:
		print("RESULT: PASS - Wall successfully blocked bullets.")
	else:
		print("RESULT: FAIL - Bullets penetrated wall! HP lost: ", 100 - player.current_health)

func test_open_shot():
	print("\n[TEST 2] Testing Open Shot (Removing Wall)")
	obstacle.global_position = Vector3(0, -10, 0) # Move wall away
	player.current_health = 100
	
	# Force bot to shoot 3 times
	for i in range(3):
		bot.shoot()
		await get_tree().create_timer(0.2).timeout
	
	print("Player final HP: ", player.current_health)
	if player.current_health < 100:
		print("RESULT: PASS - Bullets hit player in open field.")
	else:
		print("RESULT: FAIL - Bot missed despite open field!")
