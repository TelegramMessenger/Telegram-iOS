# TgApiFix — фикс входа (замена api_id/api_hash без пересборки приложения)

## Зачем
Релизный IPA собран с публичным тестовым `api_id: 8` из
`build-system/appstore-configuration.json`. Общие ключи Telegram душит
лимитами (`API_ID_PUBLISHED_FLOOD`, троттлинг `auth.sendCode`): на экране
ввода номера — долгая загрузка, потом «ошибка сети». VPN/прокси не помогают,
потому что режут не IP, а сам `api_id`.

Твик подменяет геттеры `-[BuildConfig apiId]` / `-[BuildConfig apiHash]`
(читаются один раз при старте в `AppDelegate`, дальше ключи текут на экран
ввода номера и в `auth.sendCode`). Зависимостей ноль, грузится до `main`.

## 1. Взять свои ключи
https://my.telegram.org → API development tools → создать application →
вписать `api_id` (число) и `api_hash` (32 hex) в `TgApiFix.m`.

## 2. Собрать (Mac + Xcode)
```bash
chmod +x build.sh
./build.sh   # -> TgApiFix.dylib
```

## 3. Вживить в IPA
Вариант A — Sideloadly: Advanced Options → Tweak Injection → Inject
dylibs → выбрать `TgApiFix.dylib` → Start.

Вариант B — вручную:
```bash
unzip Telegram.ipa
insert_dylib --inplace --all-yes @executable_path/Frameworks/TgApiFix.dylib Payload/Telegram.app/Telegram
mkdir -p Payload/Telegram.app/Frameworks
cp TgApiFix.dylib Payload/Telegram.app/Frameworks/
# TrollStore: ldid -S Payload/Telegram.app/Frameworks/TgApiFix.dylib
# Обычный сайдлоад: переподписать бандл своим сертификатом (Sideloadly/AltStore/ESign)
zip -r Telegram-patched.ipa Payload
```

Вариант C — TrollFools (поверх уже установленной через TrollStore копии):
открыть приложение → Inject → выбрать dylib.

## 4. Проверка
В Console при старте приложения должна быть строка:
`[TgApiFix] BuildConfig apiId/apiHash overridden -> <твой id>`.
Нет строки — dylib не загрузился (подпись/путь), сам свизлинг корректен.
