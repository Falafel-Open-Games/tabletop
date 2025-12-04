class_name Constants extends Node

const DEFAULT_SERVER_URL = "ws://127.0.0.1:8910" # For Web, use wss:// on HTTPS hosts
const DEFAULT_PORT = 8910

const MIN_PLAYERS = 2
const MAX_PLAYERS = 6

# RPC Keys
const RPC_CREATE_ROOM = "rpc_create_room"
const RPC_JOIN_ROOM = "join_room"
const RPC_LEAVE_ROOM = "leave_room"
const RPC_START_GAME = "start_game"
const RPC_UPDATE_ROOM_LIST = "update_room_list"
const RPC_PLAYER_JOINED = "player_joined"
const RPC_PLAYER_LEFT = "player_left"

# Game States
enum GameState { WAITING, PLAYING, FINISHED }

# Room Data Structure
class RoomInfo:
	var room_id: String
	var host_id: int
	var player_ids: Array[int]
	var max_players: int
	var game_state: int
	var custom_properties: Dictionary

	func _init(id: String, host: int, max_players_per_room: int = MAX_PLAYERS):
		room_id = id
		host_id = host
		player_ids = [host]
		max_players = max_players_per_room
		game_state = GameState.WAITING
		custom_properties = {}
