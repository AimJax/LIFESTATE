class_name GameClock
extends RefCounted

## Game time authority. Ported 1:1 from the C# reference (GameClock.cs).
## 1 real second = 4 in-game minutes; 15 real seconds = 1 game hour;
## 6 real minutes = 1 game day.

const MINUTES_PER_REAL_SECOND: int = 4
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DAYS_PER_YEAR: int = 365
const MAX_DAY: int = 2147483647

var day: int = 0
var hour: int = 0
var minute: int = 0

var year: int:
	get:
		return day / DAYS_PER_YEAR

var day_of_year: int:
	get:
		return day % DAYS_PER_YEAR

## Advances game time. Returns false without mutating anything when the day
## counter would overflow past int.MaxValue, which is the C# OverflowException
## contract the save/load path relies on.
func advance_game_minutes(minutes: int) -> bool:
	if minutes < 0:
		return true

	var total_minutes: int = minute + minutes
	var new_minute: int = total_minutes % MINUTES_PER_HOUR
	var hours_to_add: int = total_minutes / MINUTES_PER_HOUR

	var total_hours: int = hour + hours_to_add
	var new_hour: int = total_hours % HOURS_PER_DAY
	var days_to_add: int = total_hours / HOURS_PER_DAY

	var new_day: int = day + days_to_add
	if new_day > MAX_DAY:
		return false

	day = new_day
	hour = new_hour
	minute = new_minute
	return true


func advance_seconds(real_seconds_elapsed: int) -> bool:
	return advance_game_minutes(real_seconds_elapsed * MINUTES_PER_REAL_SECOND)


## Controlled internal restore (save/load transaction commit path).
func restore(new_day: int, new_hour: int, new_minute: int) -> void:
	day = new_day
	hour = new_hour
	minute = new_minute


func clock_text() -> String:
	return "Day %d, %02d:%02d" % [day, hour, minute]
