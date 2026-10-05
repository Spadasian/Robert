extends NavigationRegion3D
## Builds the navigation mesh at runtime from the static colliders under this node (floor, walls, props).
## Put this on the NavigationRegion3D of every room, so enemies can path around obstacles.


func _ready() -> void:
	bake_navigation_mesh(false)
	if navigation_mesh.get_polygon_count() == 0:
		push_warning("NavBaker: navigation mesh is empty. Does the floor have a StaticBody3D with a collision shape?")
