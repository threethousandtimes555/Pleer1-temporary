#!/usr/bin/env python3
import datetime, json, pathlib, re, subprocess, sys, urllib.request

STAGES = {
 "history": ("01-history.md", "История изменений", "Собери хронологию изменений между Build #5, #12 и #14. Выдели коммиты по подсистемам. Не делай выводов о работоспособности только по названиям коммитов."),
 "playback": ("02-playback.md", "Изменения воспроизведения", "Разбери изменения Player.swift: окончание трека, watchdog, advance, load, пауза/прерывание и выбор следующего источника. Для каждого замечания укажи конкретный участок diff и SHA, если он известен."),
 "search": ("03-search.md", "Аудит поиска", "Разбери YouTubeEngine.swift, YouTubeHTMLSearch.swift и YouTubePlaylistEngine.swift: отдельные треки, плейлисты, InnerTube, HTML fallback, парсинг и объединение результатов. Найди возможные причины того, что плейлисты находятся, а отдельные треки — нет."),
 "diagnostics": ("04-diagnostics.md", "Аудит диагностики", "Оцени диагностические изменения и их пользу: какие события различают причины проблем, какие дублируют друг друга или шумят. Сформулируй конкретные проверяемые гипотезы и минимальные тесты.")
}

def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout

def clip(s, limit=22000):
    return s if len(s) <= limit else s[:limit] + "\n\n[Часть данных не помещена в контекст; укажи это как ограничение.]"

def evidence_files():
    return {
      "5to12": pathlib.Path("audit-evidence/build5-to-12.md").read_text(encoding="utf-8"),
      "12to14": pathlib.Path("audit-evidence/build12-to-14.md").read_text(encoding="utf-8")
    }

def section_for(diff, path):
    marker = "### " + path + " "
    start = diff.find(marker)
    if start < 0: return ""
    end = diff.find("\n### ", start + len(marker))
    return diff[start:] if end < 0 else diff[start:end]

def collect(stage):
    ev = evidence_files()
    if stage == "history":
        parts=[]
        for key in ("5to12","12to14"):
            data=ev[key]
            match=re.search(r"## Commit sequence\n(.*?)\n\n## Per-file diffs",data,re.S)
            parts.append("=== "+key+" ===\n"+(match.group(1) if match else data[:3000]))
        return "\n\n".join(parts)
    if stage == "playback":
        return pathlib.Path("audit-evidence/playback-key-commits.md").read_text(encoding="utf-8")
    if stage == "search":
        paths=("plei/Sources/YouTubeEngine.swift","plei/Sources/YouTubeHTMLSearch.swift","plei/Sources/YouTubePlaylistEngine.swift")
        aggregate = "\n\n".join("=== "+key+" ===\n"+"\n\n".join(section_for(ev[key],p) for p in paths) for key in ("5to12","12to14"))
        exact = pathlib.Path("audit-evidence/search-key-commits.md").read_text(encoding="utf-8")
        return aggregate + "\n\n=== EXACT SEARCH COMMIT ===\n" + exact
    if stage == "diagnostics":
        data=ev["12to14"]
        paths=("plei/Sources/Player.swift","plei/Sources/YouTubeDiagnostics.swift","plei/Sources/YouTubeEngine.swift","plei/Sources/YouTubeHTMLSearch.swift","plei/Sources/YouTubePlaylistEngine.swift")
        return "\n\n".join(section_for(data,p) for p in paths)
    raise ValueError(stage)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in STAGES:
        raise SystemExit("usage: companion_audit.py history|playback|search|diagnostics")
    stage=sys.argv[1]
    filename,title,task=STAGES[stage]
    out=pathlib.Path("reports"); out.mkdir(exist_ok=True)
    target=out/filename
    header=f"# {title}\n\nЭтап: {stage}\nВремя UTC: {datetime.datetime.now(datetime.timezone.utc).isoformat()}\nМодель: qwen3:8b (локальный Ollama)\n\n"
    target.write_text(header+"## Промежуточный вывод\nАнализ начат; ниже ответ будет дописываться по мере генерации.\n\n",encoding="utf-8")
    try:
        evidence=clip(collect(stage))
        prompt=f"""Ты — независимый read-only аудитор Pleer1. Этап: {stage}.
{task}

ПРАВИЛА:
- Пиши по-русски. Сразу выдавай конкретные наблюдения, не откладывай выводы до общего заключения.
- Каждое замечание оформляй: ФАКТ ИЗ DIFF / ВОЗМОЖНАЯ ПРОБЛЕМА / ПОЧЕМУ ЭТО ВАЖНО / ЧТО ПРОВЕРИТЬ.
- Указывай точный файл, фрагмент/название функции и SHA, если он присутствует в данных. Не выдумывай номера строк.
- Чётко отделяй доказанное изменение от гипотезы и неизвестного.
- Build #12 компилировался, но пользователь не проводил полноценную проверку; YouTube-миксы не работали.
- Build #5 подтверждён пользователем только для трёх полных прослушиваний «Избранного» в фоне/с заблокированным экраном и переключения треков через Siri.
- Не предлагай патчи и не меняй код. Цель — оставить команде рабочие зацепки.
- Если не хватает данных, назови, что именно отсутствует, и всё равно сохрани частичные наблюдения.
- Заверши разделами: «Что уже установлено», «Гипотезы для проверки», «Следующий минимальный тест».

=== ИСТОРИЧЕСКИЕ DIFF ===
{evidence}
"""
        payload={"model":"qwen3:8b","prompt":prompt,"stream":True,"think":False,
                 "options":{"temperature":0,"top_p":0.8,"num_ctx":8192,"num_predict":2200}}
        req=urllib.request.Request("http://127.0.0.1:11434/api/generate",data=json.dumps(payload).encode(),
             headers={"Content-Type":"application/json"},method="POST")
        with urllib.request.urlopen(req,timeout=2700) as response, target.open("a",encoding="utf-8") as f:
            f.write("## Выводы компаньона\n\n"); f.flush()
            for raw in response:
                if not raw.strip(): continue
                item=json.loads(raw)
                piece=item.get("response","")
                if piece:
                    f.write(piece); f.flush()
                    print(piece,end="",flush=True)
                if item.get("done"):
                    f.write("\n\n---\n\nГенерация завершена.\n")
                    f.write(f"Метрики: prompt_eval_count={item.get('prompt_eval_count')}; eval_count={item.get('eval_count')}\n")
                    f.flush()
                    break
    except Exception as exc:
        with target.open("a",encoding="utf-8") as f:
            f.write(f"\n\n## Этап прерван\nПричина: {type(exc).__name__}: {exc}\n")
        print(f"\nЭтап прерван: {type(exc).__name__}: {exc}",file=sys.stderr)
        raise
    print("\n\nОтчёт сохранён:",target)

if __name__=="__main__":
    main()
