extends SceneTree


const GENERATED_ICON_IDS := {
	"red_trigger": true,
	"armor_sponge": true,
	"silent_core": true,
	"zone_battery": true,
}


func _init():
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var resolver_script = load("res://src/ui/ArtifactIconResolver.gd")
	var asset_catalog = asset_catalog_script.new()
	asset_catalog.load_or_default()
	var resolver = resolver_script.new()

	for artifact in catalog_script.starting_artifacts(1):
		var artifact_id := String(artifact.get("id", ""))
		var icon_id := "artifact.%s" % artifact_id
		var path := String(asset_catalog.get_path("icons", icon_id, ""))
		var texture: Texture2D = resolver.make_artifact_icon(artifact, asset_catalog, 54)
		if texture == null:
			_fail("Artifact %s returned a null texture." % artifact_id)
			return

		var expects_generated := bool(GENERATED_ICON_IDS.get(artifact_id, false))
		var file_exists := not path.is_empty() and FileAccess.file_exists(path)
		if expects_generated and not file_exists:
			_fail("Artifact %s expected runtime PNG but path is missing: %s" % [artifact_id, path])
			return
		if expects_generated and (texture.get_width() != 64 or texture.get_height() != 64):
			_fail("Artifact %s did not load the runtime PNG texture; got %dx%d from %s." % [
				artifact_id,
				texture.get_width(),
				texture.get_height(),
				path,
			])
			return
		if not expects_generated and not path.is_empty():
			_fail("Artifact %s unexpectedly has a generated icon path: %s" % [artifact_id, path])
			return

		print("%s icon: path='%s' texture=%dx%d generated=%s" % [
			artifact_id,
			path,
			texture.get_width(),
			texture.get_height(),
			str(expects_generated),
		])

	print("Artifact icon loading smoke passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
