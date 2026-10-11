class_name GameAudio
extends Node

const PATH := "res://art/original/audio/"
const EFFECTS := {"place":"411_putBomb.wav.mp3", "explode":"408_exp.wav.mp3", "pickup":"413_tool.wav.mp3", "push":"410_pushBomb.mp3.mp3", "rocket":"412_rocket.mp3.mp3", "mine":"400_bibi.wav.mp3", "grenade":"409_grenade.mp3.mp3"}
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var voice_index := 0
var muted := false:
	set(value):
		muted = value
		if music != null:
			music.volume_db = -80 if value else -15
		for voice in voices:
			voice.volume_db = -80 if value else -8

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -15
	add_child(music)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8
		add_child(voice)
		voices.append(voice)
	for key in EFFECTS:
		streams[key] = load(PATH + EFFECTS[key])

func play_music(file: String, loop: bool = true) -> void:
	music.stop()
	music.stream_paused = false
	var stream: AudioStreamMP3 = load(PATH + file)
	stream.loop = loop
	music.stream = stream
	music.play()

func events(names: Array[String]) -> void:
	var played: Dictionary = {}
	for event in names:
		if streams.has(event) and not played.has(event):
			played[event] = true
			var voice := voices[voice_index % voices.size()]
			voice_index += 1
			voice.stream = streams[event]
			voice.play()

func _exit_tree() -> void:
	music.stop()
	music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
