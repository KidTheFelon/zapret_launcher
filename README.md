## Zapret Launcher for Discord/YouTube (Windows)

Универсальный лаунчер: `discord.bat` (запуск и обход DPI) и `update_checker.bat` (автообновление релизов и ipset).

> Важно: это не оригинальный репозиторий. Скрипты синхронизируются с upstream-проектом (`Flowseal/zapret-discord-youtube`) — версии и архив берутся из его релизов, ipset — из его служебных файлов. Этот репозиторий — упрощённая оболочка (launcher + автообновление) над upstream.

### Что делает
- Запускает обход DPI (`general (ALT3).bat`) и затем Discord
- Перед запуском: проверяет релиз на GitHub, при наличии — качает ZIP, распаковывает в корень и обновляет `version.txt`
- После успешной распаковки — обновляет `lists/ipset-all.txt`
- Удаляет временную папку `downloads` после успеха

### Требования
- Windows 10/11 (админ-права желательны для корректной работы драйверов)
- PowerShell 5+ (входит в Windows)
- `curl.exe` (есть в Windows 10/11; при отсутствии будет использован PowerShell)

### Быстрый старт
1. Распакуй релиз в папку (без кириллицы и пробелов — предпочтительно)
2. Запусти `discord.bat`
3. Подожди, пока батник скачает нужные файлы Запрета с репозитория.
4. Как скачивание закончится, начнется запуск Запрета и Discord из стандартной папки установки.

Если `general (ALT3).bat` перестал работать или его нет:
- Проще и быстрее поменять имя запускаемого батника в лаунчере `discord.bat`
- Открой `discord.bat`, в поиске найди и замени все "general (ALT3).bat" на нужный файл, например:
  ```bat
  if exist "general (ALT3).bat" (
      start "general-alt" /min "general (ALT3).bat"
      timeout /t 8 /nobreak > nul
      powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process ^| Where-Object { $_.Name -ieq 'cmd.exe' -and $_.CommandLine -like '*general (ALT3).bat*' } ^| ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }"
  )
  ```

### Основные файлы
- `discord.bat`
  - `call update_checker.bat auto`
  - Обновление (при наличии), затем старт `general (ALT3).bat`, пауза 8 сек и закрытие окна `general`
  - Запуск Discord из стандартных мест

- `update_checker.bat`
  - Сравнение `version.txt` (локально) и версии на GitHub
  - При новой версии: ZIP → распаковка → `ipset` → запись новой версии → удаление `downloads`
  - При совпадении версии: ничего не трогает, удаляет `downloads` если осталась
  - Защита: при проблемах распаковки останавливает конфликтующие службы (`WinDivert`, `GoodbyeDPI`, `winws.exe`) и делает повтор; при необходимости использует fallback через `Expand-Archive`

### Как это работает (коротко)
1) `discord.bat` → `update_checker.bat auto`
2) Если доступна новая версия:
   - скачивание `zapret-discord-youtube-<ver>.zip` в `downloads/`
   - распаковка в корень рядом с батниками (Unicode-safe через Shell.Application)
   - вызов `:ipset_update` → запись в `lists/ipset-all.txt`
   - запись `<ver>` в корневой `version.txt`
   - удаление `downloads/`
3) Запуск `general (ALT3).bat`, ожидание 8 сек, закрытие окна `general` (не `winws.exe`), старт Discord

### Команды
Запуск в «авто»-режиме без вопросов:
```bat
discord.bat
```
Прямая проверка/обновление без запуска Discord:
```bat
update_checker.bat auto
```

### Траблшутинг
- Распаковка падает с ошибкой
  - Чек: `%TEMP%/update_checker_extract_error.log`
  - Скрипт сам остановит `WinDivert/GoodbyeDPI/winws.exe` и повторит распаковку; есть fallback на `Expand-Archive`

- «В консоли кракозябры»
  - Убедись, что файлы в кодировке UTF-8 без BOM и с окончаниями строк CRLF

### Безопасность
- Секретов в репозитории нет
- Скачивание релизов и ipset — с официального GitHub

### Где править
- Таймаут закрытия окна `general` — в `discord.bat` (`timeout /t 8`)
- URL релиза/версии/IPSET — внутри `update_checker.bat`

### Идеи и улучшения
Есть идеи, как сделать лаунчер лучше? Предлагайте:
- Issues — опишите проблему/идею кратко и по делу
- PR — присылайте рабочие правки (минимальные, без лишних файлов из .gitignore)

### Лицензия
Используй на свой страх и риск. Автор не несёт ответственности за последствия использования.


