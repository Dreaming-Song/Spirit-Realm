## 建造音效播放模块
## 封装程序化 WAV 加载和播放

class_name BuildingSFX
extends Node

var _sfx_place: AudioStreamWAV = null
var _sfx_break: AudioStreamWAV = null
var _player: AudioStreamPlayer = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BuildingSFXPlayer"
	add_child(_player)
	_load_sfx()

func _load_sfx() -> void:
	var place_path = "res://assets/sounds/block_place.wav"
	var break_path = "res://assets/sounds/block_break.wav"
	
	if ResourceLoader.exists(place_path):
		_sfx_place = load(place_path) as AudioStreamWAV
	if ResourceLoader.exists(break_path):
		_sfx_break = load(break_path) as AudioStreamWAV

func play(type: String) -> void:
	match type:
		"place":
			_player.stream = _sfx_place
		"break":
			_player.stream = _sfx_break
	
	if _player.stream:
		_player.play()
