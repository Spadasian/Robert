extends TechniqueBehavior
## Master: a second Opening slot. Either Opening can start the Kata.


func extra_slot() -> int:
	return TechniqueData.Category.OPENING
