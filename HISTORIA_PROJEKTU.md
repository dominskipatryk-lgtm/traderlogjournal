# Historia projektu TraderLogJournal
*Raport wygenerowany: 2026-05-28*

---

## FAZA 0 — Początki (przed Claude Code)
*"Add files via upload" — dziesiątki commitów ręcznego uploadu przez GitHub UI*

Projekt startował jako prosty plik `index.html` uploadowany ręcznie przez interfejs GitHub. Wielokrotnie usuwano i dodawano `index.html`, CNAME, README. Etap ręcznego developmentu bez narzędzi.

---

## FAZA 1 — Fundamenty z Claude Code

**Co wdrożono:**
- SEO meta tagi + Google Search Console weryfikacja
- Integracja Google Drive — auto-connect, folder button
- Emocje pre/post trade, multi-currency, analiza kalendarza, quick linking
- Auto-sync co 3 minuty, offline queue, CSV export, conflict resolution
- Email powitalny przy aktywacji konta przez admina

**Co odrzucono:**
- **Google SSO login** — zbudowany, następnie całkowicie usunięty. Powód: zbyt skomplikowany dla zamkniętej grupy, użytkownicy mają przypisane loginy przez admina, OAuth tworzył konflikty z istniejącym systemem użytkowników.

---

## FAZA 2 — Google Drive → Supabase Storage

**Co wdrożono:**
- Screenshoty transakcji przez Supabase Storage (zamiast Google Drive)
- Jakość 1920px/88%, ścieżka `sb://`, lightbox

**Co odrzucono:**
- **Cała integracja Google Drive** — zbudowana, działająca, a następnie w całości usunięta. Powód: Drive scope `drive.file` był zbyt restrykcyjny, użytkownicy musieli ręcznie autoryzować, komplikował auth flow, Supabase Storage jest prostsze i wystarczające.

---

## FAZA 3 — Duże funkcje UX (Sprint 1)

**Co wdrożono:**
- Rutyna dnia (4-krokowa + sleep/energy) — przebudowa z "Dziennika"
- Weekly review — lista transakcji, auto analiza dobrze/źle, walidacja emocji
- Kalkulator pozycji — najpierw w dashboardzie, potem przeniesiony do Narzędzi
- System przypomnień + dzienny briefing
- Sesja 5h z ostrzeżeniem 1h przed końcem
- Tabela transakcji max 13 wierszy ze scrollem, sticky header
- Reguły tradera (toggle aktywna/nieaktywna)
- Pełny flow zamknięcia transakcji + konta botowe

**Bugi naprawione:**
- `t()` shadowing — zmienna `t` (trade) przykrywała funkcję `t()` i18n
- adminActivateUser/Delete — JSON.stringify łamało atrybut HTML onclick
- Rutyna dnia — reset klucza po wylogowaniu
- Timer makro uruchamiany tylko przy logowaniu, nie przy wejściu na stronę

---

## FAZA 4 — Sprint 2: Biblioteka + i18n

**Co wdrożono:**
- **Biblioteka zasobów** — Supabase Storage bucket `library`, signed URLs, upload PDF/link
- **System i18n EN/PL** — T.pl/T.en słowniki, `t('klucz')`, `applyLangToStatic()`, `data-i18n`, `data-i18n-placeholder` na 15 inputach
- Tłumaczenia EN: emocje, reguły, biblioteka, toasty, confirm dialogi, admin panel, weekly review, journal, notes — dziesiątki kluczy
- `showConfirm()` — zastąpił natywny `confirm()` w 30 miejscach
- `help.html` — instrukcja obsługi + przycisk Pobierz PDF + print CSS
- Makro kalendarz — po 3 iteracjach (ForexFactory CORS → Finnhub CORS → Investing.com widget)
- Dzwonek makro w topbarze z dropdown i badge
- MT4 EA — przycisk pobierania w sekcji ustawień

**Co było problemem:**
- **Makro kalendarz** — 3 iteracje: ForexFactory (CORS), Finnhub.io API (CORS), CORS proxy, ostatecznie Investing.com widget embed.
- **CORS wszędzie** — zewnętrzne API kalendarza ekonomicznego niedostępne z przeglądarki bez proxy.

---

## FAZA 5 — Sprint 3: Zaawansowane funkcje

**Co wdrożono:**
- **[F] Profil psychologiczny tradera** — nowa zakładka w Statystykach, min 20 transakcji, analiza wzorców
- **[G] Smart Reminders** — Notification API, 4 auto-remindery, notatka w przypomnieniu, dzwonek na analizach
- **[H] Raport miesięczny** — PDF print, picker miesięcy, sparkline SVG, weekly reviews
- **Zakładka Pomysły** — użytkownik zgłasza pomysły, admin accept/reject + notatka
- Generator danych demo — ~150 transakcji, dzienniki, analizy, 60 dni

**Co celowo pominięto:**
- **[I] MQL4 wskaźnik** — był w planie Sprint 3, celowo pominięty bo aplikacja nie była jeszcze wystarczająco stabilna. Zapisany jako "wrócimy później".

---

## FAZA 6 — AI Asystent (zbudowany i usunięty)

**Co zbudowano:**
- AI Asystent — coach tradingowy z czatem
- AI analiza wykresów — zewnętrzne strategie: SMC, ICT, Price Action, S&D, Wyckoff, Elliott, VSA
- AI dual-section — niezależna analiza + kontekst tradera
- AI Raport — pełna analiza historii transakcji (P3.1)

**Co odrzucono:**
- **Cały AI Asystent** — po zbudowaniu zdecydowano go usunąć z aplikacji. Powód: zbyt ciężki dla SPA w jednym pliku HTML, wymaga własnego serwera i API keys, koszty na użytkownika, lepiej jako osobna platforma. Przeniesiony w całości do planu "osobny serwis w przyszłości".

---

## FAZA 7 — Portfel + PIT-38 + Import CSV

**Co wdrożono:**
- **Portfel inwestycyjny** — ETF/akcje/obligacje/krypto, wykres alokacji, P&L, eksport CSV
- **PIT-38** — raport podatkowy dla polskich traderów, CSV eksport, PDF druk
- **Import CSV z brokerów** — parsery dla MT4, MT5, Bybit, MEXC, deduplikacja, podgląd przed importem
- **Auto-ceny portfela** — CoinGecko (krypto, bez klucza), Alpha Vantage (akcje/ETF, darmowy klucz)
- Styl modalów ujednolicony
- Tabela R:R — max 13 wierszy z przewijaniem, sticky header
- Emocje bilingual PL/EN — `tEmo()`

---

## FAZA 8 — Odzyskiwanie hasła (pełny remont)

**Co wdrożono:**
- PKCE flow dla resetu hasła (`flowType: 'pkce'`)
- Natychmiastowe pokazanie formularza z URL po kliknięciu linku w emailu
- Guard `appInit()` — nie ingeruje w sesję PKCE w toku
- Blokada `loginAs()` podczas resetu
- Usunięcie `?code=` z early detection (kolizja z emailem powitalnym)

**Ile bugów było:** 3 osobne bugi w samym flow resetu hasła naprawiane w 5 commitach. Reset hasła okazał się najtrudniejszą do naprawienia rzeczą w całym projekcie przez PKCE edge cases.

**Co usunięto:**
- Legacy recovery code — stary localStorage-only reset, nienadający się do użycia
- Edge function (zastąpiona przez Supabase Dashboard)

---

## FAZA 9 — Sync cross-device (seria fixów)

**Co naprawiono (kolejno):**
- Dane niewidoczne po zalogowaniu z nowej przeglądarki — `renderAll` po `sbSyncDown`
- `rules_broken` payload + stale `currentAccountId` + pełny re-render
- Sync strategii i setupów do Supabase — brakował zupełnie
- `sbSyncAccount` fallback payload — bez `currency/color` powodował 400
- `sbSyncTrade` fallback payload — brakujące kolumny w trades powodowały 400

*Seria 5-6 commitów naprawiających różne aspekty synca, które ujawniały się stopniowo po wdrożeniu na produkcję.*

---

## FAZA 10 — Task #7, #11, #12, #13

**Co wdrożono:**
- **Task #7 — Ankieta post-trade** — popup po zamknięciu transakcji, rating 1-5, plan compliance, exit quality, emocje stats
- **Task #11 — Dzienny Score 0-100** — `getDailyScore()`, karta w dashboardzie z kolorowym wskaźnikiem
- **Task #12 — Habit Tracker** — kolorowy kalendarz w dzienniku: zielony/żółty/czerwony na podstawie danych
- **Task #13 — Weekly reviews sync** — `sbSyncWeeklyReview()`, sync-down i sync-up

---

## FAZA 11 — MT5 EA + TradingView

**Co wdrożono:**
- **MT5 EA v2.0** — pełna wersja MQL5: kalkulator pozycji, panel BUY/SELL, historia zamkniętych transakcji, panel graficzny
- **TradingView CSV import** — `parseTradingViewCSV()`, Strategy Tester export
- **TradingView Webhook** — sekcja w Ustawieniach, URL + przykład JSON dla alertów
- MT4 EA fix — poprawiony link do pobrania EA v2

---

## FAZA 12 — Biblioteka v2 + ogłoszenia + keepalive

**Co wdrożono:**
- Biblioteka 4 kategorie — strategies/setups/indicators/glossary
- Podkategorie strategii — grupowanie setupów po etapach
- Fix Storage upload — `@` w emailu powodował błąd 400 → sanitizacja ścieżki
- Edycja materiałów — modal z prefillowanymi polami
- GitHub Actions keepalive — Supabase Free pauzuje po 7 dniach → ping co 5 dni
- Fix YAML — polskie znaki w workflow łamały YAML
- Fix "Dodaj etap" — apostrof w subcategorii łamał onclick HTML
- Ogłoszenia cykliczne — admin tworzy, dni tygodnia, user opt-in, banner
- Fix download — `download` attribute ignorowany cross-origin → fetch+blob
- Fix `an-content` — `createAnalysisFromJournal` używał złego ID elementu
- Link do wideo — `_HELP_VIDEO_URL` placeholder w sidebarze
- Usunięto `help.html` — zastąpiony linkiem do nagranego wideo

---

## FAZA 13 — Sesja 2026-05-28 (dzisiejsza)

**Co wdrożono:**
- **Realtime sync** — Supabase channels dla trades/accounts/analyses, toast "Dane zaktualizowane z innego urządzenia"
- **REPLICA IDENTITY FULL** — wymagane dla filtered realtime subscriptions (SQL w Supabase)
- **Narzędzia admina** — skanowanie duplikatów kont, usuwanie pustych, force re-sync z Supabase
- **Load test k6** — naprawiony (setup() login raz zamiast na każdej iteracji, poprawne nazwy kolumn: pnl/capital/updated_at), wynik: 0% błędów, p95=395ms przy 50 VU
- **sbFullSyncUp()** — wykonany po wszystkich SQL fixach dnia
- **Supabase SQL** — `rules_broken` kolumna, tabela `weekly_reviews`, `announcements`, `REPLICA IDENTITY FULL`
- Deploy na produkcję

**Co odrzucono dziś:**
- **SMS 2FA** — kosztowny (Twilio), słabszy od TOTP (SIM swap attack), bez sensu na Free tier

---

## PODSUMOWANIE: WDROŻONE vs ODRZUCONE

| Funkcja | Status | Powód |
|---------|--------|-------|
| Google Drive integracja | ❌ Usunięta w całości | Zbyt skomplikowane OAuth, Supabase Storage wystarczy |
| Google SSO login | ❌ Usunięty | Konflikt z systemem loginów admin→user |
| AI Asystent (coach + wykresy + raport) | ❌ Usunięty z SPA | Za ciężki, koszty API, wymaga osobnego serwera |
| Makro ForexFactory / Finnhub | ❌ CORS blokada | Niemożliwy z przeglądarki bez proxy |
| SMS 2FA | ❌ Odrzucony | Kosztowny, słabszy od TOTP, SIM swap |
| MQL4 wskaźnik (Task I Sprint 3) | ⏭ Pominięty | Za wcześnie — wrócimy |
| help.html instrukcja | ⏭ Zastąpiona | Będzie link do nagranego wideo |
| TOTP 2FA (Google Authenticator) | 🔜 W planie | Najbliższy priorytet bezpieczeństwa |
| Email przy nowym logowaniu | 🔜 W planie | Supabase Auth Hook |
| Session timeout | 🔜 W planie | Auto-wylogowanie po nieaktywności |
| Library sync-down | 🔜 W planie | Inne urządzenia widzą pustą bibliotekę |
| Landing page | 🔜 W planie | Gdy otworzysz na szerszą publiczność |
| AI — osobna platforma | 🔜 Przyszłość | Coach, analiza wykresów, raport tygodniowy, pamięć AI |

---

## STATYSTYKI PROJEKTU

- **Liczba commitów:** ~200+
- **Czas trwania:** od pierwszego uploadu do dziś
- **Rozmiar aplikacji:** ~20 500+ linii (jeden plik index.html)
- **Tabele Supabase:** trades, accounts, analyses, user_settings, weekly_reviews, mt4_signals, announcements, profiles, ideas
- **Integracje:** Supabase Auth+DB+Storage+Realtime, CoinGecko, Alpha Vantage, TradingView, MT4 EA, MT5 EA, GitHub Actions
- **Platformy:** GitHub Pages → traderlogjournal.com (PWA)
