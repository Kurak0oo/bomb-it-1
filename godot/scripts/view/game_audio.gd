class_name GameAudio
extends Node

const PATH := "res://art/original/audio/"
const ROUND_TRACKS := ["401_Bombit_-_level_1.mp3","402_Bombit_-_level_2.mp3","403_Bombit_-_level_3.mp3","404_Bombit_-_level_4.mp3"]
const EFFECTS := {"place":"411_putBomb.wav.mp3", "explode":"408_exp.wav.mp3", "pickup":"413_tool.wav.mp3", "push":"410_pushBomb.mp3.mp3", "rocket":"412_rocket.mp3.mp3", "mine":"400_bibi.wav.mp3", "grenade":"409_grenade.mp3.mp3"}
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
# Presentation entropy is deliberately independent of the gameplay tape.
var music_rng := OriginalRng.new(Time.get_ticks_usec())
var _round_tracks: Array = ROUND_TRACKS.duplicate()
var _round_index := 4
var _playbacks: Array[WeakRef] = []
# Platform suspension is independent of the player's saved mute preference.
var suspended := false:
	set(value):
		suspended = value
		if music != null:music.stream_paused = value
		for voice in voices:voice.stream_paused = value
var muted := false:
	set(value):
		if muted == value:return
		muted = value
		if music != null:
			if value:music.stop()
			elif music.stream != null:
				_start(music)

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for key in EFFECTS:
		streams[key] = load(PATH + EFFECTS[key])

func play_music(file: String, loop: bool = true) -> void:
	music.stop()
	var stream: AudioStreamMP3 = load(PATH + file)
	stream.loop = loop
	music.stream = stream
	if not muted:_start(music)
	music.stream_paused = suspended

func new_campaign() -> void:
	_round_tracks = ROUND_TRACKS.duplicate()
	_round_index = 4

func play_round_music(retry: bool = false) -> void:
	# A retry enters original frame 2 directly, reattaching the current track.
	# Only a new stage executes frame 1's selection/shuffle.
	if not retry:
		if _round_index >= 3:
			_round_index = 0
			music_rng.disorder(_round_tracks)
		else:
			_round_index += 1
	play_music(_round_tracks[_round_index])

func _start(player: AudioStreamPlayer) -> void:
	_playbacks = _playbacks.filter(func(playback: WeakRef):return playback.get_ref() != null)
	player.play()
	_playbacks.append(weakref(player.get_stream_playback()))
	player.stream_paused = suspended

func events(names: Array[String]) -> void:
	if muted:return
	for event in names:
		if streams.has(event):
			if voices.filter(func(candidate: AudioStreamPlayer):return candidate.playing).size() >= (31 if music.playing else 32):continue
			var voice: AudioStreamPlayer
			for candidate in voices:
				if not candidate.playing:
					voice = candidate
					break
			if voice == null:
				# Ruffle's attached-sound path rejects new starts at 32 active
				# instances; it never steals an already playing effect tail.
				voice = AudioStreamPlayer.new()
				add_child(voice)
				voices.append(voice)
			voice.stream = streams[event]
			_start(voice)

func _exit_tree() -> void:
	music.stop()
	music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null

func retire() -> void:
	# stop() hands playback to AudioServer's asynchronous fade/deletion queue.
	# Observe its release, rather than guessing a shutdown delay in seconds.
	for player in [music] + voices:
		player.stop()
		player.stream = null
	var deadline := Time.get_ticks_msec() + 2000
	while _playbacks.any(func(playback: WeakRef):return playback.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_warning("Audio playback retirement timed out")
			break
		await get_tree().process_frame
