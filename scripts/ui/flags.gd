class_name Flags
extends RefCounted
## Small flags drawn in code, so they show on any device without emoji fonts.

const W := 48
const H := 32


static func texture(code: String) -> Texture2D:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	match code:
		"en":
			_draw_usa(img)
		"pt_BR":
			_draw_brazil(img)
		"es":
			_draw_spain(img)
	return ImageTexture.create_from_image(img)


static func _draw_usa(img: Image) -> void:
	var red := Color("b22234")
	var white := Color.WHITE
	var blue := Color("3c3b6e")
	for y in H:
		var stripe := y * 13 / H
		for x in W:
			var c := red if stripe % 2 == 0 else white
			if x < 20 and y < 17:
				c = blue
			img.set_pixel(x, y, c)


static func _draw_brazil(img: Image) -> void:
	var green := Color("009c3b")
	var yellow := Color("ffdf00")
	var blue := Color("002776")
	for y in H:
		for x in W:
			var c := green
			var dx := absf(x - 23.5) / 21.0
			var dy := absf(y - 15.5) / 13.0
			if dx + dy <= 1.0:
				c = yellow
			var r2 := (x - 23.5) * (x - 23.5) + (y - 15.5) * (y - 15.5)
			if r2 <= 36.0:
				c = blue
			img.set_pixel(x, y, c)


static func _draw_spain(img: Image) -> void:
	var red := Color("aa151b")
	var yellow := Color("f1bf00")
	for y in H:
		var c := yellow
		if y < 8 or y >= 24:
			c = red
		for x in W:
			img.set_pixel(x, y, c)
