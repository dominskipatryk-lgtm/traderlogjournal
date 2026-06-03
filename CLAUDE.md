# TraderLogJournal — Kontekst projektu dla Claude

## Zasady pracy (CZYTAJ NAJPIERW)

1. **Przed każdą sesją** przeczytaj `DAILY_LOG.md` (ostatni wpis) i `PROJECT_STATUS.md`
2. **Workflow deploy**: zmiany ZAWSZE do `preview.html` najpierw. Do `index.html` tylko na wyraźne polecenie "deploy" / "wdróż"
3. **Przed każdą decyzją techniczną** — przeanalizuj, wypisz opcje, uzasadnij wybór
4. **Po każdej sesji** — zaktualizuj `DAILY_LOG.md` i `PROJECT_STATUS.md`
5. **Nigdy nie rób założeń** o stanie kodu — zawsze czytaj aktualne linie pliku przed edycją
6. **Krytyczne bugfixe** trafiają do obu plików jednocześnie (index.html + preview.html)

---

## Co to jest
Zaawansowany dziennik tradingowy SPA — narzędzie do analizy psychologii i wyników tradera. Aplikacja dla aktywnych traderów MT4/MT5/crypto. Docelowo: płatny SaaS (29 zł/mies. Pro plan).

**Cel biznesowy:** 200 płatnych użytkowników → rewrite do Next.js → skalowanie

---

## Stack

| Element | Szczegóły |
|---|---|
| Frontend | Vanilla JS + CSS, jeden plik `index.html` (brak frameworka) |
| Backend/Auth | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| Hosting | GitHub Pages, branch `main` → `traderlogjournal.com` |
| Storage | `localStorage` (`db.trades[user_accId]`) + Supabase + Google Drive |
| PWA | `manifest.json` + `service-worker.js` |

---

## Konfiguracja
```js
_ADMIN_EMAIL = 'dominskipatryk@gmail.com'
_SB_URL      = 'https://ygrkcynyduuflzvbkkvo.supabase.co'
_SB_ANON     = 'sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK'
FREEMIUM_LIMIT = 50  // max zamkniętych transakcji w planie Free
```

---

## Supabase — tabele
| Tabela | Opis |
|---|---|
| `trades` | Transakcje użytkowników |
| `accounts` | Konta tradingowe |
| `analyses` | Analizy rynkowe |
| `mt4_signals` | Sygnały z EA MT4 (OPEN/CLOSE/MODIFY) |
| `weekly_reviews` | Tygodniowe przeglądy |
| `user_settings` | Ustawienia, reguły, strategie |
| `profiles` | Profile użytkowników |

---

## Kluczowe funkcje JS — storage

```js
// WAŻNE: trades są w db.trades[loginKey + '_' + accountId]
// NIE w db[loginKey + '_' + accountId] (stary, błędny format)
getTrades(accountId)          // czyta db.trades[key] + migruje stary db[key]
saveTrades(accountId, arr)    // zapisuje do db.trades[key], usuwa stary db[key]
getAccounts()                 // db.accounts[currentUser]
saveAccounts(arr)             // db.accounts[currentUser] = arr

// Sync Supabase
sbSyncDown(userId, userLogin) // Supabase → localStorage (merge, nie replace!)
sbFullSyncUp()                // localStorage → Supabase
sbSyncAccount(acc)            // sync jednego konta
sbSyncTrade(trade, accSbId)   // sync jednej transakcji

// UI
renderAll()                   // odśwież wszystkie strony
renderTrades()                // lista transakcji
renderDashboard()             // dashboard
updateFreemiumBadge()         // badge "X/50 trans." w sidebarze
```

---

## Kluczowe funkcje JS — logika biznesowa

```js
// Freemium
isProUser()                   // true jeśli subscription=pro/admin, role=admin, lub grandfathered
getTotalClosedCount()         // suma zamkniętych trans. ze wszystkich kont
checkFreemiumLimit()          // sprawdza limit, pokazuje upsell jeśli przekroczony
autoGrantGrandfathered()      // wywoływana przy login — zwalnia istniejących testerów z limitu

// Onboarding
shouldShowOnboarding()        // true jeśli nowy user (brak kont + !onboardingDone)
showOnboarding()              // modal 4-krokowy
migrateTradesStorage()        // jednorazowa migracja db[key] → db.trades[key]

// Market Structure
_calendarWarning(show)        // pokazuje/ukrywa ostrzeżenie o kalendarzu makro
renderWeeklyStatusBadge()     // badge "Do uzupełnienia" / "Zamknięty"
```

---

## Wzorce kodu

### Routing
```js
showPage('trades')            // przełącz stronę
// Strony: dashboard, trades, journal, analyses, stats, calendar,
//         macro, library, portfolio, tools, settings, accounts, admin
```

### Modals
```js
document.getElementById('modal-id').classList.add('open')    // otwórz
closeModal('modal-id')        // zamknij
```

### Toast
```js
toast('Wiadomość', 'success') // success | error | warning | info
```

### i18n
```js
t('key')                      // tłumaczenie (PL/EN)
// Klucze w obiektach _TRANSLATIONS_PL i _TRANSLATIONS_EN
```

---

## Pliki projektu

| Plik | Status | Opis |
|---|---|---|
| `index.html` | PRODUKCJA (~19k linii) | Aktywna wersja na traderlogjournal.com |
| `preview.html` | DEV (niezdeployowany) | Wszystkie nowe funkcje przed testem |
| `service-worker.js` | OK | PWA cache-first assets, network-first HTML |
| `manifest.json` | OK | PWA manifest |
| `DAILY_LOG.md` | Aktywny | Dziennik sesji developerskich |
| `PROJECT_STATUS.md` | Aktywny | Pełny status projektu |
| `BUSINESS_PLAN_V2.md` | Ref | Strategia, roadmapa, decyzje biznesowe |
| `BUGFIXES.md` | Ref | Historia bugów znalezionych przez testerów |
| `wskazniki/TraderLogJournal_EA_v2.mq4` | OK | EA MT4 — sync OPEN/CLOSE/MODIFY |
| `wskazniki/IOFlow_StrengthClassifier.mq4` | NOWY | Order Flow + panel toggle |
| `wskazniki/PriceActionConcepts.mq4` | NOWY | BOS/CHoCH/OBs/FVG + panel toggle |

---

## Ważne pułapki (nie popełniaj tych błędów)

| Pułapka | Opis |
|---|---|
| `db[key]` vs `db.trades[key]` | Trades są ZAWSZE w `db.trades[key]`. Stary format `db[key]` jest migrowany. |
| `sbSyncDown` accounts | Nie zastępuj tablicy kont — merguj! Zachowaj lokalny ID jeśli `sbId` pasuje. |
| `status: 'closed'` hardkodowane | Przy parsowaniu MT4 sprawdzaj `closeTime` i `exit` — może być `'open'` |
| Service Worker cache | Po każdym deploy wymagany hard refresh (Ctrl+Shift+R) |
| Deploy bez testu | Zawsze najpierw preview.html, test, potem index.html |
| Ternary references w MQL4 | `type &x = a ? b : c` nie działa w MQL4 — używaj if/else |

---

## Waluty kont
```js
_CURR_SYMBOLS = {
  USD:'$', EUR:'€', GBP:'£', PLN:'zł', CHF:'CHF',
  JPY:'¥', AUD:'A$', CAD:'C$', BTC:'₿', USDT:'₮'
}
```

---

## Decyzje architektoniczne (nie zmieniać bez dyskusji)
- Monolith vanilla JS → do walidacji monetyzacji
- Rewrite Next.js → TYLKO po 200 płatnych użytkownikach
- AI przez Supabase Edge Functions (nie własny serwer)
- Mobile przez Capacitor (nie React Native)
- Boty handlowe → Plan B (ryzyko MiFID II)
- Freemium limit = 50 transakcji
