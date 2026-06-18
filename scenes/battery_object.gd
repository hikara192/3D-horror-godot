extends StaticBody3D


@export var item_name: String = "Батарейка" 

func interact(player):
	var success = player.add_item_to_inventory(item_name)
	
	if success:
		queue_free()
