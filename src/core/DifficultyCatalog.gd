class_name DifficultyCatalog
extends RefCounted

static func labels() -> Array[String]:
	return ["쉬움", "보통", "어려움", "지옥"]

static func descriptions() -> Array[String]:
	return [
		"봇 시야 75%  ·  반응 느림  ·  조준 부정확\n입문용 난이도.",
		"표준 난이도.",
		"봇 시야 125%  ·  즉각 반응  ·  정밀 조준\n극한의 도전.",
		"HP 1 시작  ·  힐 감소  ·  암전 + 폭격\n랜덤 이벤트: 힐추가반감 / 탄막 / 전원적대",
	]

static func colors() -> Array[Color]:
	return [
		Color(0.3, 1.0, 0.45),
		Color(1.0, 0.88, 0.25),
		Color(1.0, 0.35, 0.35),
		Color(0.75, 0.1, 1.0),
	]

static func dim_color() -> Color:
	return Color(0.55, 0.55, 0.55)

static func label(difficulty: int) -> String:
	var items = labels()
	return items[clampi(difficulty, 0, items.size() - 1)]

static func description(difficulty: int) -> String:
	var items = descriptions()
	return items[clampi(difficulty, 0, items.size() - 1)]

static func color(difficulty: int) -> Color:
	var items = colors()
	return items[clampi(difficulty, 0, items.size() - 1)]
