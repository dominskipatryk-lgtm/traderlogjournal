# TraderLogJournal — Status Projektu
> Ostatnia aktualizacja: 2026-06-03

---

## Architektura

| Element | Opis |
|---|---|
| **Stack** | Vanilla JS + CSS, jeden plik `index.html` (~19k linii), brak frameworka |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Hosting** | GitHub Pages → `traderlogjournal.com` (branch `main`) |
| **Storage** | localStorage (`db.trades[user_accountId]`) + Supabase sync + opcjonalnie Google Drive |
| **PWA** | `manifest.json` + `service-worker.js` |

## Pliki

| Plik | Linie | Status | Opis |
|---|---|---|---|
| `index.html` | ~19 346 | **PRODUKCJA** | Aktywna wersja na traderlogjournal.com |
| `preview.html` | ~20 126 | **DEV — niezdeployowany** | +780 linii funkcji czekających na deploy |
| `service-worker.js` | — | OK | PWA cache |
| `manifest.json` | — | OK | PWA manifest |
| `wskazniki/TraderLogJournal_EA_v2.mq4` | — | OK | EA MT4 v2 — sync z Supabase |
| `wskazniki/IOFlow_StrengthClassifier.mq4` | — | NOWY | Order Flow Strength + panel toggle |
| `wskazniki/PriceActionConcepts.mq4` | — | NOWY | BOS/CHoCH/OBs/FVG/EQH/TLZ + panel |

---

## Co jest w PRODUKCJI (index.html)

### Core Trading Journal
- [x] Dashboard — equity curve, stats, recent trades
- [x] Lista transakcji — filtrowanie, sortowanie, search
- [x] Formularz transakcji — entry/exit/SL/TP/size/emotions/screenshots/rules
- [x] Emocje pre/post trade (picker)
- [x] R:R kalkulacja, komisje, swap
- [x] Multi-currency per konto (USD/EUR/GBP/PLN/CHF/BTC/USDT)
- [x] Screenshoty transakcji (base64 + Google Drive)
- [x] Reguły tradingowe — tworzenie, sprawdzanie przed zapisem
- [x] Strategie i setupy

### Dziennik (Journal)
- [x] Pre-session routine — plan dnia, instrumenty, poziomy S/R, bias
- [x] Post-session routine — wyniki, emocje, lekcja
- [x] Rytuał Otwarcia i Zamknięcia (PL)
- [x] Selektor strategii w pre-sesji
- [x] Warunki rynkowe, stress (suwak), zgodność strategii
- [x] Kalendarz makro — ostrzeżenie przy pominięciu
- [x] Weekly review — refleksja tygodniowa, Q1/Q2/Q3

### Statystyki
- [x] Equity curve (SVG)
- [x] Win rate, profit factor, max drawdown, Sharpe ratio
- [x] Analiza emocjonalna (post-trade survey, wykresy)
- [x] Profil psychologiczny tradera (min 20 transakcji)
- [x] Heatmapa tygodnia
- [x] Filtrowanie po okresie (7d/30d/90d/YTD/All)

### Analizy
- [x] Tworzenie analiz rynkowych
- [x] Linkowanie analiza ↔ transakcja
- [x] Widok listy i kalendarza
- [x] Archiwizacja
- [x] Sync z Supabase

### Import/Export
- [x] Import CSV/HTML: MT4, MT5, Bybit, MEXC, TradingView Strategy Tester
- [x] **NOWE dziś**: weryfikacja salda po imporcie (porównanie z plikiem MT4)
- [x] **NOWE dziś**: auto-match konta po numerze MT4 z nagłówka pliku
- [x] Eksport CSV transakcji
- [x] Eksport PIT-38

### Konta i sync
- [x] Multi-account
- [x] Supabase sync (down + up + realtime)
- [x] AES-GCM szyfrowanie broker name + MT4 login
- [x] Google Drive backup

### Inne
- [x] Biblioteka materiałów (Supabase Storage, 4 kategorie)
- [x] Portfel inwestycyjny (ETF/akcje/krypto)
- [x] Makro Kalendarz (Investing.com embed)
- [x] Habit Tracker
- [x] Daily Score
- [x] Inteligentne przypomnienia (Notification API)
- [x] Admin panel (zarządzanie użytkownikami)
- [x] TradingView ticker tape widget
- [x] Dwujęzyczność PL/EN
- [x] PWA (offline, install na telefon)
- [x] MT4 EA v2 — sync OPEN/CLOSE/MODIFY z Supabase
- [x] GitHub Actions keepalive dla Supabase Free tier

---

## Co jest w PREVIEW ale NIE w PRODUKCJI

> Commit `3f8c1b8` (01.06.2026) + dzisiejsze zmiany — **czeka na deploy**

### Gotowe w preview.html
- [ ] **BUG-01**: Status badge tygodnia ("Do uzupełnienia" / "Zamknięty ✅")
- [ ] **BUG-02**: Redirect z przypomnienia → bezpośrednio do weekly tab
- [ ] **BUG-03**: Transakcje tygodnia w weekly review — rozwijane karty z entry/exit/emocjami
- [ ] **BUG-04**: Miesięczny przegląd — metryki, top3/bottom3, refleksja, cele
- [ ] **BUG-05**: Roczny przegląd — breakdown miesięczny, słownik błędów, refleksja
- [ ] **FREEMIUM**: Limit 50 zamkniętych transakcji + badge w sidebar + modal Upsell
- [ ] **ONBOARDING**: 4-krokowy modal dla nowego użytkownika (konto → sesje → demo → start)
- [ ] **FIX KRYTYCZNY**: otwarte transakcje MT4 importowane jako `open` (nie `closed`)
- [ ] **FIX KRYTYCZNY**: `mt4Ticket` zapisywany przy imporcie → EA może dopasować
- [ ] **FIX KRYTYCZNY**: migracja danych `db[key]` → `db.trades[key]`
- [ ] **FIX KRYTYCZNY**: `getTrades` czyta z obu lokalizacji (backward compat)

---

## Znane bugi i problemy

| ID | Opis | Priorytet | Status |
|---|---|---|---|
| BUG-SYNC-1 | sbSyncDown pisał do `db[key]` zamiast `db.trades[key]` | 🔴 KRYTYCZNY | ✅ Naprawiony w preview |
| BUG-SYNC-2 | sbSyncDown zastępował konta — orphan trades | 🔴 KRYTYCZNY | ✅ Naprawiony w preview |
| BUG-IMPORT-1 | Otwarte transakcje MT4 importowane jako closed | 🔴 Wysoki | ✅ Naprawiony w preview |
| BUG-IMPORT-2 | Brak mt4Ticket przy imporcie — EA nie może dopasować | 🟠 Wysoki | ✅ Naprawiony w preview |
| BUG-IMPORT-3 | Brak auto-push do Supabase po imporcie | 🟠 Wysoki | ✅ Naprawiony w preview + index |
| BUG-IMPORT-4 | Brak weryfikacji salda po imporcie | 🟡 Średni | ✅ Naprawiony w index |

---

## Faza 1 — Plan (do zrobienia)

| ID | Zadanie | Priorytet | Szacowany czas |
|---|---|---|---|
| DEPLOY | Deploy preview.html → index.html | 🔴 NATYCHMIAST | 5 min |
| LANDING | Landing page traderlogjournal.com | 🟠 Wysoki | 2-3 dni |
| STRIPE | Integracja płatności (Checkout) | 🟠 Wysoki | 2-3 dni |
| FREEMIUM | (w preview) — po deploy gotowe | — | — |
| ONBOARDING | (w preview) — po deploy gotowe | — | — |
| RODO-EXPORT | "Pobierz moje dane" JSON/CSV | 🟠 Wysoki | 1 dzień |
| RODO-DELETE | "Usuń konto i wszystkie dane" | 🟠 Wysoki | 1 dzień |
| 2FA | TOTP Google Authenticator | 🔴 Wysoki | 2 dni |
| ADMIN-V1 | Panel admin: DAU/MAU, streak, conversion | 🟡 Średni | 2 dni |
| EMAIL | Resend: powitanie, weekly email, przypomnienia | 🟡 Średni | 2 dni |
| SEC-TIMEOUT | Session timeout po nieaktywności | 🟡 Średni | 1 dzień |

---

## Decyzje architektoniczne

| Decyzja | Powód | Data |
|---|---|---|
| Monolith vanilla JS | Walidacja monetyzacji najpierw, rewrite po 200 płatnych | 2026-06-01 |
| Supabase Edge Functions dla AI | Nie własny serwer — koszt i złożoność | 2026-06-01 |
| Capacitor dla mobile | Nie React Native — istniejący HTML wystarczy | 2026-06-01 |
| Boty → Plan B | Ryzyko MiFID II, wymaga zespołu prawnego | 2026-06-01 |
| Rewrite Next.js | TYLKO po pierwszych 200 płatnych użytkownikach | 2026-06-01 |
| Freemium limit = 50 trans. | Wystarczy do testowania, ale zachęca do upgrade | 2026-06-03 |
| grandfathered dla istniejących | Nie karać testerów limitami | 2026-06-03 |
