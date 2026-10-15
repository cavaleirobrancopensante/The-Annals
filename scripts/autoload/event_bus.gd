extends Node
## Global signals. Systems talk through these instead of calling each other.

signal week_advanced(week: int)
signal event_presented(view: Dictionary)
signal event_resolved(event_id: String, choice_index: int)
signal chronicle_added(entry: Dictionary)
signal monk_died(monk: Dictionary)
signal abbot_changed(monk: Dictionary)
signal world_changed
signal house_fell
