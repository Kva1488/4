# Roblox-игра

Код игры хранится здесь в виде файлов, а [Rojo](https://rojo.space) синхронизирует его с Roblox Studio в реальном времени. Claude может писать код и пушить его сюда, а при подключении MCP ещё и напрямую управлять твоим Studio.

## Способ 1. Код отсюда в Studio через Rojo

1. Поставь [Rokit](https://github.com/rojo-rbx/rokit) (менеджер инструментов), затем в папке проекта выполни:
   ```sh
   rokit install
   ```
   Команда поставит `rojo`, `selene` и `stylua` нужных версий.
2. Поставь плагин Rojo в Studio: `rojo plugin install`.
3. Забери свежий код и запусти сервер синхронизации:
   ```sh
   git pull
   rojo serve
   ```
4. В Studio открой вкладку **Plugins → Rojo → Connect**. Весь код из `src/` появится в игре и будет обновляться при каждом изменении файлов.

Нет времени на установку? Открой вкладку **Actions** на GitHub, выбери последний зелёный запуск и скачай артефакт **Game**. Внутри готовый `Game.rbxl`, его можно открыть в Studio двойным кликом.

## Способ 2. Claude сам управляет Studio (MCP)

Этот способ работает только на твоём компьютере: облачная сессия не видит твой Studio.

1. Обнови Roblox Studio и установи [Claude Code](https://claude.com/claude-code) или Claude Desktop.
2. В Studio открой **Assistant → Manage MCP Servers**, включи **Studio as MCP server** и нажми **Quick connect** для Claude Code.
3. Перезапусти Claude Code, открой в нём эту папку и выполни `/mcp`. В списке должен появиться Roblox Studio.
4. Запусти `rojo serve` (способ 1) и подключи Rojo в Studio, чтобы код из `src/` тоже синхронизировался.

После этого Claude сможет выполнять Luau в открытом месте, вставлять модели, запускать плейтест и читать консоль. Правила работы для Claude описаны в `CLAUDE.md`.

## Структура

```
src/
  shared/   → ReplicatedStorage.Shared      (Config, Remotes)
  server/   → ServerScriptService.Server    (Services/*: DataService, LeaderstatsService)
  client/   → StarterPlayerScripts.Client   (Controllers/*: HudController)
default.project.json   карта дерева для Rojo
```

Что уже умеет каркас:
- **DataService** сохраняет данные игрока в DataStore: повторяет загрузку при сбоях, делает автосейв, сохраняет при выходе игрока и при выключении сервера.
- **LeaderstatsService** выводит монеты в таблицу лидеров.
- **HudController** показывает счётчик монет на экране.

> Чтобы сохранения работали в Studio, включи **Game Settings → Security → Enable Studio Access to API Services** (место должно быть опубликовано).
