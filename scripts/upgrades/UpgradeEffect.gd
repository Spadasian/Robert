class_name UpgradeEffect
extends Resource
## One change to one stat. An upgrade is a list of these.
## ADD: flat bonus (+1 dodge, +25 max HP). PERCENT: fraction (0.2 = +20%, -0.15 = -15%).

enum Operation { ADD, PERCENT }

@export var stat: String = ""
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
