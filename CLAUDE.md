# Roblox-игра (Rojo + Luau)

Код игры хранится в `src/`, а Rojo синхронизирует его с Roblox Studio. Отвечай пользователю по-русски.

## Структура

| Папка | Куда попадает в Studio | Что там |
|---|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` | `Items` (камни), `Abilities` (способности), `Config`, `Remotes` |
| `src/server/Services/` | `ServerScriptService.Server.Services` | Сервисы, их автоматически загружает `init.server.luau` |
| `src/server/Combat/` | `ServerScriptService.Server.Combat` | `AbilityHandlers`, `Damage`, `Status`, `Fx`. Загрузчик их не трогает |
| `src/client/Controllers/` | `...StarterPlayerScripts.Client.Controllers` | Контроллеры, их автоматически загружает `init.client.luau` |
| `src/client/` | `...StarterPlayerScripts.Client` | `PlayerState` (копия данных игрока), `Ui` (хелперы интерфейса) |

### Как добавить способность

1. Добавь запись в `src/shared/Abilities.luau`: id, клавиша, перезарядка, `requires`.
2. Добавь `function Handlers.<id>(ctx)` в `src/server/Combat/AbilityHandlers.luau`.
3. Панель, блокировка и инвентарь подхватят её автоматически. `tools/verify.luau` проверит, что обработчик есть, а клавиша ни с чем не пересекается.

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
lune run tools/verify.luau Game.rbxl  # проверка структуры и данных
```

CI (`.github/workflows/ci.yml`) прогоняет эти же проверки и выкладывает `Game.rbxl` как артефакт.

## Работа с живым Studio

Если подключён MCP-сервер Roblox Studio (инструменты вроде `run_code`, `insert_model`, `get_console_output`, `start_stop_play`), то:
- код игры всё равно правь в `src/` (Rojo синхронизирует его), а не через `run_code`, иначе изменения потеряются;
- через `run_code` проверяй состояние места, строй/расставляй объекты в Workspace и запускай тесты;
- после изменений запусти плейтест (`start_stop_play`) и проверь консоль (`get_console_output`).
