extends TechniqueBehavior
## Master: a second Flow slot. Both Flows feed the same bar.


func extra_slot() -> int:
	return TechniqueData.Category.FLOW
