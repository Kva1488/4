# Roblox-игра (Rojo + Luau)

Код игры хранится в `src/`, а Rojo синхронизирует его с Roblox Studio. Отвечай пользователю по-русски.

## Структура

| Папка | Куда попадает в Studio | Что там |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | Общие модули: `Config`, `Remotes` |
| `src/server/` | `ServerScriptService.Server` | `init.server.luau` загружает `Services/*` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | `init.client.luau` загружает `Controllers/*` |

Карта дерева лежит в `default.project.json`, там же Baseplate, SpawnLocation и Lighting.

## Соглашения

- Каждый новый файл начинается с `--!strict`, расширение `.luau`, отступы табами.
- Сервис — это ModuleScript в `src/server/Services/` с методами `Init()` и `Start()`. Загрузчик подхватит его сам. Клиентские контроллеры устроены так же и лежат в `src/client/Controllers/`.
- Данные игрока меняются только через `DataService:Update(player, fn)`. Новые поля нужно добавить в `Config.DefaultData`.
- Remotes получаем через `Remotes.event(name)` / `Remotes.func(name)`. Сервер никогда не доверяет данным, пришедшим от клиента: всё валидируется на сервере.

## Проверки (запускать перед коммитом)

```sh
stylua src            # форматирование
selene src            # линтер (нужен доступ к setup.rbxcdn.com для генерации roblox std)
rojo build -o Game.rbxl  # сборка place-файла
```

CI (`.github/workflows/ci.yml`) прогоняет эти же проверки и выкладывает `Game.rbxl` как артефакт.

## Работа с живым Studio

Если подключён MCP-сервер Roblox Studio (инструменты вроде `run_code`, `insert_model`, `get_console_output`, `start_stop_play`), то:
- код игры всё равно правь в `src/` (Rojo синхронизирует его), а не через `run_code`, иначе изменения потеряются;
- через `run_code` проверяй состояние места, строй/расставляй объекты в Workspace и запускай тесты;
- после изменений запусти плейтест (`start_stop_play`) и проверь консоль (`get_console_output`).
