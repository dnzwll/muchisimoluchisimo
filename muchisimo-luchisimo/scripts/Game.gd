extends Node

var score := 0
var combo := 1
var is_game_over := false

func reset_run():
	score = 0
	combo = 1
	is_game_over = false

func add_score(base: int, finisher := false):
	var bonus := 3 if finisher else 1
	score += base * bonus * combo
	combo += 1

func reset_combo():
	combo = 1

func game_over():
	is_game_over = true
