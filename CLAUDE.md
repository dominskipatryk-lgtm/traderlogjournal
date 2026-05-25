# TraderLogJournal — Kontekst projektu

## Co to jest
Prywatna aplikacja SPA (Single Page Application) — dziennik tradingowy. Cały kod w jednym pliku `index.html` (~570KB+). Działa jako PWA (Progressive Web App) hostowana na GitHub Pages pod domeną **traderlogjournal.com**.

## Stack
- **Frontend:** vanilla JS + CSS w jednym `index.html` (brak frameworka, brak bundlera)
- **Backend/Auth/DB:** Supabase (PostgreSQL + Auth)
- **Hosting:** GitHub Pages (`main` branch → `traderlogjournal.com` przez CNAME)
- **Storage:** localStorage (`db.accounts[loginKey]`, `db.trades[loginKey + '_' + accountId]`) + Supabase sync + opcjonalnie Google Drive
- **PWA:** `manifest.json` + `service-worker.js`

## Konfiguracja (stałe w index.html)
```
_ADMIN_EMAIL = 'dominskipatryk@gmail.com'
_SB_URL      = 'https://ygrkcynyduuflzvbkkvo.supabase.co'
_SB_ANON     = 'sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK'
```

## Supabase — tabele
- `trades` — transakcje użytkowników
- `accounts` — konta tradingowe
- `analyses` — analizy rynkowe
- `mt4_signals` — sygnały z EA MetaTrader 4 (OPEN/CLOSE/MODIFY)

## Kluczowe funkcje JS
- `sbSyncDown()` — pobierz dane z Supabase do localStorage
- `sbSyncAccount()` — sync jednego konta
- `sbFullSyncUp()` — wyślij lokalnie dane do Supabase
- `getTrades(accountId)` — pobierz transakcje z localStorage
- `getAccounts()` — lista kont z localStorage
- `getCurrSym(accId)` — symbol waluty dla konta (USD→`$`, EUR→`€` itp.)
- `toggleEmotion(type, value, btn)` — obsługa emotion pickerów (nowa transakcja)
- `toggleDvEmotion(type, value, btn)` — emotion pickery (modal edycji)
- `filterLinkedAnalysisList(q)` — wyszukiwarka analizy w formularzu trade
- `selectLinkedAnalysis(id)` — przypisz analizę do trade
- `assignTradeToAnalysis(tradeId)` — one-click przypisanie z panelu analizy
- `renderAnalysisList()` — renderuje listę LUB widok kalendarza analiz
- `setAnalysisView(view)` — przełącz 'list' / 'calendar'

## Waluty kont
```js
_CURR_SYMBOLS = {USD:'$', EUR:'€', GBP:'£', PLN:'zł', CHF:'CHF', JPY:'¥', AUD:'A$', CAD:'C$', BTC:'₿', USDT:'₮'}
```

## Zrealizowane funkcje (historia)
- Śledzenie emocji pre/post trade (picker w modalu nowej i edycji transakcji)
- Multi-currency per konto
- TradingView ticker tape widget na dashboardzie (darmowy embed, nie wymaga umowy)
- Searchable autocomplete dla linkowania analiza↔transakcja
- One-click assign trade do analizy z panelu analizy
- Widok kalendarza analiz (grupowanie po miesiącach)
- MetaTrader 4 EA v1.2 (`TraderLogJournal_EA.mq4`)

## Ważne uwagi
- **Service worker cache:** po każdym deploy na GitHub Pages wymagany hard refresh (`Ctrl+Shift+R`) lub unregister SW w DevTools → Application → Service Workers
- **TradingView widget** jest darmowy do embedowania bez żadnej umowy/klucza API
- Dostęp do aplikacji tylko przez zaproszenie admina
- Google Drive scope: wyłącznie `drive.file` (tylko pliki utworzone przez aplikację)
- Dane użytkownika są jego własnością; admin: dominskipatryk@gmail.com

## Pliki
- `index.html` — cała aplikacja (JS + CSS + HTML)
- `service-worker.js` — PWA cache (cache-first assets, network-first HTML)
- `manifest.json` — PWA manifest
- `terms.html` — Warunki korzystania (PL)
- `privacy.html` — Polityka prywatności (PL)
- `TraderLogJournal_EA.mq4` — Expert Advisor dla MT4
- `CNAME` — domena `traderlogjournal.com`
