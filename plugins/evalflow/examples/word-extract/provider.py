import json, sys
# promptfoo exec provider: argv[1]=prompt. 간단한 가짜 추출기: 쉼표로 나뉜 단어 중 '역'으로 끝나지 않는 것
prompt = sys.argv[1]
text = prompt.split("TEXT:", 1)[-1]
print(json.dumps([w.strip() for w in text.split(",") if w.strip() and not w.strip().endswith("역")], ensure_ascii=False))
