@tool
extends Camera3D


@export var post_processing := true:
	set(p):
		if p:
			$Postprocess.show()
			post_processing = p
		else:
			$Postprocess.hide()
			post_processing = p
