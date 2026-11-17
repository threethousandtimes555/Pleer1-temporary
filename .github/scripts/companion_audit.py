#!/usr/bin/env python3
"""One-task-at-a-time, read-only Pleer1 audit using a local Ollama model."""
import datetime
import json
import pathlib
import sys
import urllib.request
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(".")
STAGES = {
    "history": ("01-history.md", "История изменений",
        "Кратко сопоставь Build #5, #12 и #14. Отделяй историю коммитов от подтверждённого пользователем поведения."),
    "playback": ("02-playback.md", "Проверка воспроизведения",
        "Найди максимум три вероятные причины проблем окончания трека, watchdog, advance/load, паузы и старта следующего YouTube-элемента. Сопоставь diff с доступным актуальным Player.swift."),
    "search": ("03-search.md", "Проверка YouTube-поиска",
        "Проверь путь поиска отдельных видео, плейлистов и миксов. Сопоставь diff с доступным актуальным YouTubeEngine.swift. Не делай выводов о недоступных файлах."),
    "diagnostics": ("04-diagnostics.md", "Проверка диагностики",
        "Оцени диагностические события, которые реально видны во входных данных. Найди дубли и предложи один минимальный способ повысить диагностическую ценность."),
}

def read_file(path):
    p = ROOT / path
    return p.read_text(encoding="utf-8") if p.is_file() else ""

def clip(value, limit=12000):
    if len(value) <= limit:
        return value
    return value[:limit] + "\n[Обрезано по лимиту контекста; не делай выводов по отсутствующей части.]"

def relevant_source(path, terms, radius=7, max_lines=150):
    content = read_file(path)
    if not content:
        return f"=== АКТУАЛЬНЫЙ ФАЙЛ {path}: отсутствует в проверочной копии ==="
    lines = content.splitlines()
    hits = [i for i, line in enumerate(lines) if any(t.lower() in line.lower() for t in terms)]
    windows = []
    for i in hits:
        a, b = max(0, i-radius), min(len(lines), i+radius+1)
        if windows and a <= windows[-1][1]:
            windows[-1] = (windows[-1][0], max(windows[-1][1], b))
        else:
            windows.append((a,b))
    selected = []
    for a,b in windows:
        if len(selected) + b-a > max_lines:
            break
        selected.extend((i+1,lines[i]) for i in range(a,b))
    if not selected:
        return (f"=== АКТУАЛЬНЫЙ ФАЙЛ {path} доступен, но по заданным маркерам "
                "релевантные строки не найдены; случайный фрагмент не подставлялся. ===")
    return f"=== АКТУАЛЬНЫЙ ФАЙЛ {path}; номера строк точные ===\n" + "\n".join(f"{n}: {line}" for n,line in selected)

def collect(stage):
    if stage == "history":
        names = ("build5-to-12.md","build12-to-14.md","README.md")
        return "\n\n".join("=== "+n+" ===\n"+read_file("audit-evidence/"+n)[:6000] for n in names if read_file("audit-evidence/"+n))
    if stage == "playback":
        return "\n\n".join((
            "=== ИСТОРИЧЕСКИЙ DIFF ===\n"+read_file("audit-evidence/playback-key-commits.md"),
            relevant_source("plei/Sources/Player.swift",
                ("watchdog","advance","finish","readyToPlay","timeControlStatus","userPausedPlayback",
                 "audioSession","replaceCurrentItem","player.play","player.pause","currentItem","isPlaying"),
                radius=6,max_lines=120)))
    if stage == "search":
        return "\n\n".join((
            "=== ИСТОРИЧЕСКИЙ DIFF ===\n"+read_file("audit-evidence/search-key-commits.md"),
            relevant_source("plei/Sources/YouTubeEngine.swift",("search","parse","renderer","videoId","playlist","music"),5,100),
            relevant_source("plei/Sources/YouTubeHTMLSearch.swift",("search","renderer","videoId","music"),5,80),
            relevant_source("plei/Sources/YouTubePlaylistEngine.swift",("radio","playlist","renderer","nextEndpoint"),4,60)))
    if stage == "diagnostics":
        return "\n\n".join((
            "=== ИСТОРИЧЕСКИЙ DIFF ===\n"+read_file("audit-evidence/build12-to-14.md")[:7000],
            relevant_source("plei/Sources/Player.swift",
                ("diagnostic","watchdog","tick","finish_event","audio_interruption","time_control","resolve"),5,130),
            relevant_source("plei/Sources/YouTubeDiagnostics.swift",("func","event","record","export","log"),4,80)))
    raise ValueError(stage)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in STAGES:
        raise SystemExit("usage: companion_audit.py history|playback|search|diagnostics")
    stage = sys.argv[1]
    filename,title,task = STAGES[stage]
    evidence = clip(collect(stage))
    if not evidence.strip():
        raise SystemExit("Нет исходных данных для выбранного этапа; анализ не запускается.")
    out = ROOT/"reports"
    out.mkdir(exist_ok=True)
    target = out/filename
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    stamp_utc = now_utc.isoformat()
    stamp_msk = now_utc.astimezone(ZoneInfo("Europe/Moscow")).strftime("%Y-%m-%d %H:%M:%S МСК (UTC+03:00)")
    prompt = f"""Ты — независимый технический аудитор iOS-проекта Pleer1. Работаешь только на чтение.
ЗАДАЧА: {task}

ПРАВИЛА ДОКАЗАТЕЛЬНОСТИ:
1. Не выдумывай код, функции, строки, SHA, логи или результаты тестов.
2. Для утверждения о текущем коде указывай точный файл и номер строки из пронумерованного исходника; приводи короткую цитату, достаточную для проверки.
3. Для исторического изменения указывай файл/diff/SHA только если они явно есть во входных данных; не выдавай diff за текущую реализацию.
4. Если актуальный файл отсутствует или нужные строки не попали во входные данные, прямо скажи: «текущую реализацию проверить не удалось».
5. Разделяй ПОДТВЕРЖДЕНО ДАННЫМИ / ГИПОТЕЗА / НЕИЗВЕСТНО.
6. Компиляция не доказывает правильность воспроизведения.
7. Build #5 подтверждён пользователем только для трёх полных прослушиваний «Избранного» в фоне/с заблокированным экраном и переключения через Siri.
8. Build #12 компилировался, но миксы не работали; полноценной проверки пользователем не было.
9. Не предлагай патчи и не меняй код.
10. Не называй само наличие поля, таймера или диагностического события ошибкой. Для находки нужна конкретная связь кода с наблюдаемым симптомом.
11. Не перечисляй проверки, которые можно сделать когда-нибудь. Выбери один тест, который сильнее всего различает текущие гипотезы.

ФОРМАТ:
- Краткий вывод — до 3 предложений.
- Не более 2 находок. Для каждой: статус; файл и точные строки; короткая цитата; почему это важно для указанного симптома.
- Один следующий минимальный тест с ожидаемыми различиями результатов.
- Что нельзя заключить по этим данным.
- Если доказательных находок нет — напиши это прямо и не заполняй отчёт общими предположениями.
- Запрещены формулировки вида «может быть избыточным», «возможно шумит» без конкретного подтверждающего участка кода.
- Цель — короткий технический вывод, а не длинный список общих проверок.

ВХОДНЫЕ ДАННЫЕ:
{evidence}
"""
    target.write_text(
        f"# {title}\n\nЗадача: {stage}\nВремя МСК: {stamp_msk}\nВремя UTC: {stamp_utc}\n"
        f"Размер входных данных: {len(evidence)} символов\n"
        "Модель: qwen3:8b (локальный Ollama)\nРежим: один целевой аудит; только чтение\n\n## Отчёт\n\n",
        encoding="utf-8")
    payload = {
        "model":"qwen3:8b","prompt":prompt,"stream":True,"think":False,
        "options":{"temperature":0.1,"top_p":0.8,"num_ctx":8192,"num_predict":1200}
    }
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/generate",
        data=json.dumps(payload).encode(),
        headers={"Content-Type":"application/json"},
        method="POST")
    with urllib.request.urlopen(req,timeout=2400) as response, target.open("a",encoding="utf-8") as report:
        for raw in response:
            if not raw.strip():
                continue
            item = json.loads(raw)
            piece = item.get("response","")
            if piece:
                report.write(piece); report.flush()
                print(piece,end="",flush=True)
            if item.get("done"):
                report.write("\n\n---\n")
                report.write(f"Метрики: prompt_eval_count={item.get('prompt_eval_count')}; eval_count={item.get('eval_count')}; done_reason={item.get('done_reason')}\n")
                if item.get("done_reason") == "length":
                    report.write("ВНИМАНИЕ: достигнут лимит токенов; вывод может быть неполным.\n")
                report.flush()
                break
    print("\nОтчёт сохранён:",target)

if __name__ == "__main__":
    main()
