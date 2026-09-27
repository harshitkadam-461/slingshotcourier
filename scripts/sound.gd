extends Node
## Short synthesized sounds use native AudioStreamWAV. No audio files needed.

var muted := false
var clips: Dictionary = {}


func _ready() -> void:
	clips["launch"] = _tone(0.20, 230.0, 780.0, 0.0)
	clips["impact"] = _tone(0.16, 150.0, 48.0, 0.25)
	clips["glass"] = _tone(0.27, 1500.0, 210.0, 0.60)
	clips["cable"] = _tone(0.17, 620.0, 930.0, 0.04)
	clips["win"] = _tone(0.70, 420.0, 880.0, 0.0)


func play(clip_name: String) -> void:
	if muted or not clips.has(clip_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = clips[clip_name]
	player.volume_db = -17.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _tone(duration: float, from_hz: float, to_hz: float, noise: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in samples:
		var progress := float(i) / samples
		phase += TAU * lerpf(from_hz, to_hz, progress) / stream.mix_rate
		var envelope := sin(minf(progress * 12.0, 1.0) * PI / 2.0) * pow(1.0 - progress, 2.0)
		var value := (sin(phase) * (1.0 - noise) + rng.randf_range(-1, 1) * noise) * envelope
		data.encode_s16(i * 2, int(value * 24000.0))
	stream.data = data
	return stream
