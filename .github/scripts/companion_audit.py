#!/usr/bin/env python3
import datetime, hashlib, json, os, pathlib, sys, urllib.request
from zoneinfo import ZoneInfo
ROOT=pathlib.Path(".")
SRC=pathlib.Path(os.environ.get("PLEER1_SOURCE_DIR","source-project/plei/Sources"))
TEST=pathlib.Path(os.environ.get("PLEER1_TEST_DIR","source-project/plei/UITests"))
SHA=os.environ.get("PLEER1_SOURCE_SHA","unknown")
STAGES={
"history":("01-history.md","История изменений","Сопоставь Build #5, #12 и #14, отделяя коммиты от подтверждённого пользователем поведения."),
"playback":("02-playback.md","Проверка воспроизведения","Проследи YouTube-путь от выбора результата до запуска, завершения и следующего элемента. Найди максимум две причины, подтверждённые кодом."),
"search":("03-search.md","Проверка YouTube-поиска","Проследи запрос от UI до выдачи: кто вызывает YouTube, кто Audius, как объединяются результаты, различаются видео/плейлисты/миксы. Учти: «прыгай киска» показывает Audius, а UI-тест не нашёл отдельную строку трека. Не объявляй причину без цепочки вызовов и условия выбора источника."),
"diagnostics":("04-diagnostics.md","Проверка диагностики","Оцени реальные диагностические события и поля, связывающие поиск с источником и запуск с AVPlayer. Укажи только конкретные пробелы.")
}
def srcpath(rel):
 return TEST/rel.removeprefix("UITests/") if rel.startswith("UITests/") else SRC/rel
def excerpt(rel,terms,radius=5,limit=85):
 p=srcpath(rel)
 if not p.is_file(): return f"=== {p}: ФАЙЛ ОТСУТСТВУЕТ; проверка невозможна ==="
 content=p.read_text(encoding="utf-8"); lines=content.splitlines()
 hits=[i for i,x in enumerate(lines) if any(t.casefold() in x.casefold() for t in terms)]
 spans=[]
 for i in hits:
  a,b=max(0,i-radius),min(len(lines),i+radius+1)
  if spans and a<=spans[-1][1]: spans[-1]=(spans[-1][0],max(spans[-1][1],b))
  else: spans.append((a,b))
 chosen=[]
 for a,b in spans:
  if len(chosen)+b-a>limit: break
  chosen.extend((i+1,lines[i]) for i in range(a,b))
 digest=hashlib.sha256(content.encode()).hexdigest()[:16]
 body="\\n".join(f"{n}: {line}" for n,line in chosen) or "Файл прочитан, но релевантные строки не попали в выборку."
 return f"=== {p}; строк={len(lines)}; sha256={digest}; номера строк точные ===\\n{body}"
def collect(stage):
 hist="=== ИСТОРИЧЕСКИЙ МАТЕРИАЛ ===\\n"+(pathlib.Path("audit-evidence/search-key-commits.md").read_text() if stage=="search" else pathlib.Path("audit-evidence/playback-key-commits.md").read_text() if stage=="playback" else "")
 if stage=="history":
  return "\\n\\n".join("=== "+n+" ===\\n"+(pathlib.Path("audit-evidence")/n).read_text()[:6000] for n in ("build5-to-12.md","build12-to-14.md") if (pathlib.Path("audit-evidence")/n).exists())
 if stage=="playback":
  return "\\n\\n".join((hist,excerpt("Player.swift",("watchdog","advance","finish","readyToPlay","timeControlStatus","userPausedPlayback","audioSession","replaceCurrentItem","player.play","player.pause"),5,120),excerpt("YouTubeEngine.swift",("play","stream","videoId","resolve","url"),4,50)))
 if stage=="search":
  return "\\n\\n".join((hist,excerpt("Providers.swift",("search","youtube","audius","provider","source"),5,80),excerpt("Store.swift",("search","youtube","audius","provider","source","results"),5,90),excerpt("Views.swift",("search","youtube","audius","provider","source","result"),4,60),excerpt("YouTubeEngine.swift",("search","videoId","playlist","music","renderer","filter"),5,95),excerpt("YouTubeHTMLSearch.swift",("search","videoId","playlist","music","renderer","filter"),5,95),excerpt("YouTubePlaylistEngine.swift",("search","radio","playlist","renderer","nextEndpoint"),5,65),excerpt("UITests/SearchSmokeTests.swift",("searchQuery","searchArtist","firstTrack","Audius","YouTube","XCTAssert"),4,75)))
 if stage=="diagnostics":
  return "\\n\\n".join((excerpt("Player.swift",("diagnostic","watchdog","tick","finish_event","audio_interruption","time_control","resolve"),5,95),excerpt("YouTubeDiagnostics.swift",("func","event","record","export","log"),5,85),excerpt("YouTubeEngine.swift",("diagnostic","log","search","provider"),4,45)))
def main():
 if len(sys.argv)!=2 or sys.argv[1] not in STAGES: raise SystemExit("usage: companion_audit.py history|playback|search|diagnostics")
 stage=sys.argv[1]; filename,title,task=STAGES[stage]; evidence=collect(stage)
 if not evidence.strip(): raise SystemExit("Нет исходных данных; анализ не запускается.")
 now=datetime.datetime.now(datetime.timezone.utc); msk=now.astimezone(ZoneInfo("Europe/Moscow")).strftime("%Y-%m-%d %H:%M:%S МСК (UTC+03:00)")
 prompt=f"""Ты — независимый технический аудитор Pleer1. Только чтение.
ЗАДАЧА: {task}
ПРАВИЛА:
1. Не выдумывай код, функции, строки, SHA, логи или результаты тестов.
2. Для каждого утверждения о текущем коде укажи точный путь, номера строк и короткую дословную цитату. Без цитаты утверждение запрещено.
3. Исторический diff не доказывает текущее поведение. Отсутствующий файл явно отметь.
4. Разделяй ПОДТВЕРЖДЕНО КОДОМ / ПОДТВЕРЖДЕНО ТЕСТОМ ИЛИ ЛОГОМ / ГИПОТЕЗА / НЕИЗВЕСТНО.
5. Причинный вывод требует показать цепочку вызовов и условие, ведущее к симптому.
6. Не путай Audius и YouTube: найденный трек не подтверждает YouTube-поиск. Докажи провайдера результата.
7. Компиляция не доказывает работу. Build #5 подтверждён пользователем только для трёх полных прослушиваний «Избранного» в фоне и переключения через Siri. Build #12 компилировался, но миксы не работали.
8. Не предлагай патчи. Не называй диагностическое поле ошибкой само по себе.
9. Выбери один тест, лучше всего различающий гипотезы. Если доказательств нет — скажи прямо.
ФОРМАТ: вывод до 3 предложений; максимум 3 находки с статусом, файл:строки, цитатой и значением; гипотезы с недостающими данными; один минимальный тест и ожидаемое различие; ограничения; в конце SHA исходного коммита {SHA}.
Пиши коротко и конкретно.
ВХОДНЫЕ ДАННЫЕ:
{evidence}
"""
 out=pathlib.Path("reports"); out.mkdir(exist_ok=True); target=out/filename
 target.write_text(f"# {title}\\n\\nЗадача: {stage}\\nВремя МСК: {msk}\\nИсходный коммит Pleer1: {SHA}\\nВход: {len(evidence)} символов\\nМодель: qwen3:8b; только чтение\\n\\n## Отчёт\\n\\n",encoding="utf-8")
 payload={"model":"qwen3:8b","prompt":prompt,"stream":True,"think":False,"options":{"temperature":0.05,"top_p":0.75,"num_ctx":12288,"num_predict":1500}}
 req=urllib.request.Request("http://127.0.0.1:11434/api/generate",data=json.dumps(payload).encode(),headers={"Content-Type":"application/json"})
 with urllib.request.urlopen(req,timeout=2400) as response,target.open("a",encoding="utf-8") as report:
  for raw in response:
   if not raw.strip(): continue
   item=json.loads(raw); piece=item.get("response","")
   if piece: report.write(piece); report.flush(); print(piece,end="",flush=True)
   if item.get("done"):
    report.write("\\n\\n---\\n"+f"prompt_tokens={item.get('prompt_eval_count')}; output_tokens={item.get('eval_count')}; reason={item.get('done_reason')}\\n")
    if item.get("done_reason")=="length": report.write("ВНИМАНИЕ: вывод обрезан лимитом токенов.\\n")
    report.flush(); break
 print("\\nОтчёт сохранён:",target)
if __name__=="__main__": main()
