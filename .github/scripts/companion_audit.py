#!/usr/bin/env python3
import datetime, json, pathlib, subprocess, sys, urllib.request

STAGES = {
 "history": ("01-history.md", "История изменений", "Восстанови хронологию между контрольной точкой Build #5 и Build #14. Выдели коммиты, которые меняли воспроизведение, поиск и диагностику. Не делай выводов о работоспособности только по названию коммита. Составь карту изменений: SHA, файл/подсистема, фактическое изменение, что требует проверки."),
 "playback": ("02-playback.md", "Изменения воспроизведения", "Сравни поведение и код воспроизведения между Build #5 и Build #12, затем Build #12 и Build #14. Ищи изменения в цепочке окончания трека, watchdog, advance, load, паузе/прерывании и выборе следующего источника. Отделяй доказанные изменения кода от гипотез о причинах зависаний. Укажи точные SHA и пути."),
 "search": ("03-search.md", "Аудит поиска", "Отдельно проанализируй реализацию поиска YouTube: отдельные треки, плейлисты, InnerTube, HTML fallback, разбор результатов и объединение. Найди существенные изменения между Build #5 и Build #14, особенно возврат/удаление фильтров и изменения парсинга. Не называй поиск исправным без пользовательского подтверждения."),
 "diagnostics": ("04-diagnostics.md", "Аудит диагностики", "Оцени диагностические изменения: какие события и поля реально помогают различить причины проблем поиска и воспроизведения, какие дублируют друг друга или создают шум. Не предлагай удалять логи без объяснения, какую неопределённость они устраняют. Заверши коротким планом проверок, по одному проверяемому предположению за раз.")
}

def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout

def clip(s, limit=26000):
    if len(s) <= limit: return s
    return s[:limit] + "\n\n[ОБРЕЗАНО: контекст ограничен для окна модели]"

def collect(stage):
    base = "6ff25c7b249e01f7ae9867dbffe6ee0f34c6d9e3"
    mid = "f6ef9ad4d20b1526f9affcda21796ae9fe0178c2"
    head = "14956c5fbe07d39af97f73d4b462efc3fb42e66f"
    if stage == "history":
        return run("git", "log", "--reverse", "--format=%H%n%s", "--name-status", f"{base}..{head}")
    if stage == "playback":
        a = run("git", "diff", "--find-renames", f"{base}..{mid}", "--", "plei/Sources/Player.swift")
        b = run("git", "diff", "--find-renames", f"{mid}..{head}", "--", "plei/Sources/Player.swift")
        return "=== Build #5 → Build #12: Player.swift ===\n" + a + "\n=== Build #12 → Build #14: Player.swift ===\n" + b
    if stage == "search":
        files = run("bash", "-lc", "git ls-files 'plei/Sources/*' | grep -Ei 'youtube|search|playlist|engine' | head -35 || true").splitlines()
        chunks = []
        for path in files:
            try:
                diff = run("git", "diff", "--find-renames", f"{base}..{head}", "--", path)
                if diff.strip(): chunks.append(f"=== {path} ===\n{diff}")
            except Exception: pass
        return "\n\n".join(chunks) or "Не удалось автоматически найти diff по именам файлов; изучи список файлов и сообщи об ограничении."
    if stage == "diagnostics":
        matches = run("bash", "-lc", "git grep -n -i -E 'diagnostic|journal|watchdog|logEvent|logger' " + head + " -- plei/Sources 2>/dev/null | head -500 || true")
        paths = run("bash", "-lc", "git ls-tree -r --name-only " + head + " | grep -Ei 'diagnostic|journal|log' | head -30 || true")
        return "=== DIAGNOSTIC REFERENCES ===\n" + matches + "\n=== RELATED FILE PATHS ===\n" + paths
    raise ValueError(stage)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in STAGES:
        raise SystemExit("usage: companion_audit.py history|playback|search|diagnostics")
    stage = sys.argv[1]
    filename, title, task = STAGES[stage]
    out = pathlib.Path("reports")
    out.mkdir(exist_ok=True)
    target = out / filename
    try:
        evidence = collect(stage)
        prompt = f"""Ты — независимый read-only аудитор проекта Pleer1. Это этап {stage}: {title}.
Работай только с предоставленными Git-данными. Ничего не меняй и не предлагай сразу применять патчи.
{task}

Правила:
- Пиши по-русски, конкретно и компактно.
- Разделяй ФАКТ ИЗ DIFF, ГИПОТЕЗУ и НЕИЗВЕСТНОЕ.
- Не выдумывай runtime-поведение, номера строк или цитаты.
- Для каждого важного вывода укажи SHA коммита и путь; если данных нет — прямо скажи.
- Не выдавай успешную компиляцию за проверку поведения на реальном iPhone.
- Не считай Build #12 подтверждённо рабочим: он компилировался, но полноценной пользовательской проверки не было; YouTube-миксы не работали.
- Build #5 подтверждён пользователем только для трёх полных прослушиваний «Избранного» в фоне/с заблокированным экраном и переключения треков через Siri. Это не доказывает работу остальных функций.
- В конце добавь: «Что уже установлено», «Что пока неизвестно», «Следующий минимальный тест».
Данные могут быть неполными из-за лимита контекста; обозначай это явно.

=== GIT EVIDENCE ===
{clip(evidence)}
"""
        payload = {"model":"qwen3:8b","prompt":prompt,"stream":False,"think":True,
                   "options":{"temperature":0,"top_p":0.8,"num_ctx":8192,"num_predict":2200}}
        req = urllib.request.Request("http://127.0.0.1:11434/api/generate",
            data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=2700) as response:
            result = json.loads(response.read().decode())
        answer = (result.get("response") or "").strip()
        if not answer: raise RuntimeError("Qwen вернул пустой ответ")
        header = f"# {title}\n\nЭтап: {stage}\nСнимок репозитория: {run('git','rev-parse','HEAD').strip()}\nВремя UTC: {datetime.datetime.now(datetime.timezone.utc).isoformat()}\nМодель: qwen3:8b (локальный Ollama)\n\n"
        target.write_text(header + answer + "\n", encoding="utf-8")
        print(target.read_text(encoding="utf-8"))
        print(f"\nМетрики: prompt_eval_count={result.get('prompt_eval_count')}; eval_count={result.get('eval_count')}")
    except Exception as exc:
        target.write_text(f"# {title}\n\nЭтап не завершён. Ошибка: {type(exc).__name__}: {exc}\n", encoding="utf-8")
        print(target.read_text(encoding="utf-8"))
        raise

if __name__ == "__main__":
    main()
