extends RefCounted

# Old saves may contain fully serialized dialogue lines. Normalize only text
# shown to the player; stable speaker IDs and save keys stay unchanged.
static func normalize(value: String) -> String:
	var result := value
	for pair in [["Артреем", "Артбеем"], ["Артрей", "Артбей"], ["Артрея", "Артбея"], ["Артрею", "Артбею"], ["Артрее", "Артбее"], ["АРТРЕЕМ", "АРТБЕЕМ"], ["АРТРЕЙ", "АРТБЕЙ"], ["АРТРЕЯ", "АРТБЕЯ"], ["АРТРЕЮ", "АРТБЕЮ"], ["АРТРЕЕ", "АРТБЕЕ"], ["Гратом", "4fr"], ["Грата", "4fr"], ["Грату", "4fr"], ["Грате", "4fr"], ["Грат", "4fr"], ["ГРАТОМ", "4fr"], ["ГРАТА", "4fr"], ["ГРАТУ", "4fr"], ["ГРАТЕ", "4fr"], ["ГРАТ", "4fr"]]:
		result = result.replace(pair[0], pair[1])
	for pair in [["артреем", "артбеем"], ["артрей", "артбей"], ["артрея", "артбея"], ["артрею", "артбею"], ["артрее", "артбее"]]:
		result = result.replace(pair[0], pair[1])
	var lower_grat := RegEx.new()
	lower_grat.compile("(?<![\\p{L}])грат(ом|а|у|е)?(?![\\p{L}])")
	result = lower_grat.sub(result, "4fr", true)
	return result
