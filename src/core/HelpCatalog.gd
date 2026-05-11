class_name HelpCatalog
extends RefCounted

static func sections() -> Array[Dictionary]:
	return [
		{
			"title": "CONTROLS",
			"rows": [
				{"type": "key", "keys": ["W", "A", "S", "D"], "desc": "이동"},
				{"type": "key", "keys": ["MOUSE"], "desc": "조준 (캐릭터가 커서 방향을 바라봄)"},
				{"type": "key", "keys": ["LMB"], "desc": "사격 / 칼 공격"},
				{"type": "key", "keys": ["F"], "desc": "근처 아이템 줍기"},
				{"type": "key", "keys": ["Q"], "desc": "붕대/구급상자 사용 (HP 회복)"},
				{"type": "key", "keys": ["R"], "desc": "재장전"},
				{"type": "key", "keys": ["C"], "desc": "웅크리기 토글 (스텔스 증가)"},
				{"type": "key", "keys": ["SPACE"], "desc": "점프"},
				{"type": "key", "keys": ["`"], "desc": "근접 무기 (칼)"},
				{"type": "key", "keys": ["1", "2", "3", "4"], "desc": "총기 슬롯 전환"},
				{"type": "key", "keys": ["ESC"], "desc": "일시정지 / 메뉴"},
			],
		},
		{
			"title": "HUD 아이콘",
			"rows": [
				{"type": "icon", "shape": "skull", "color": Color(1.0, 0.92, 0.15), "desc": "Kill 수"},
				{"type": "icon", "shape": "hand", "color": Color(1.0, 0.6, 0.2), "desc": "Assist 수"},
				{"type": "icon", "shape": "person", "color": Color(0.72, 0.72, 0.72), "desc": "현재 생존자 수"},
				{"type": "text", "symbol": "♥", "color": Color(0.95, 0.25, 0.25), "desc": "붕대 보유 수"},
				{"type": "text", "symbol": "◆", "color": Color(1.0, 0.85, 0.1), "desc": "구급상자 보유 수"},
			],
		},
		{
			"title": "SYSTEMS",
			"rows": [
				{"type": "desc", "label": "자기장", "desc": "파란 링 밖에 있으면 지속 피해. 타이머가 빨간색이 되기 전에 이동."},
				{"type": "desc", "label": "보급 캡슐", "desc": "자기장 2단계에 맵 중앙 낙하. 레일건 포함 희귀 아이템."},
				{"type": "desc", "label": "아티팩트", "desc": "매치 시작 전 1개 선택 가능. 강한 장점과 패널티가 함께 적용됨."},
				{"type": "desc", "label": "압박 미션", "desc": "Hell은 자동 활성화. Hard는 메뉴에서 opt-in 가능."},
				{"type": "desc", "label": "스텔스", "desc": "풀숲에서 웅크리면 봇 탐지가 크게 늦어짐."},
				{"type": "desc", "label": "무기 획득", "desc": "주우면 탄창 1/3 장전. 탄약 아이템은 예비(+N)로 쌓이고 R로 보충."},
				{"type": "desc", "label": "중복 제한", "desc": "같은 종류 무기는 두 번 주울 수 없음."},
			],
		},
	]
