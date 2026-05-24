# TraderLogJournal — Raport Audytu + Plan Działania
**Data:** 2026-05-24

---

## CZĘŚĆ 1 — BUGI DO NAPRAWY (przed nową wersją)

### Krytyczne (crash / utrata danych)

| # | Problem | Efekt |
|---|---------|-------|
| 1 | Brak elementów HTML: `an-linked-trade-id`, `an-linked-trade`, `an-linked-trade-display`, `an-linked-clear` w modalu analizy | TypeError crash przy linkowaniu analizy z transakcją |
| 2 | Brak pola `an-levels` w HTML | Kluczowe poziomy nigdy nie są zapisywane |
| 3 | `saveAnalysis()` nie zapisuje `strategyId`, `setupId`, `linkedTradeId` | Strategia/setup zawsze puste po ponownym otwarciu analizy |
| 4 | `openEditAnalysis()` nie przywraca strategii/setupu | Edycja analizy = brak strategii i setupu mimo że były przypisane |
| 5 | Autosave analizy nie zapisuje `strategyId`/`setupId`/`linkedTradeId` | Draft po crashu nie ma powiązań |
| 6 | `analysis-filter-instr` nie jest wypełniany unikalnymi symbolami | Filtr instrumentu zawsze pusty |

---

## CZĘŚĆ 2 — WIZJA NOWEJ WERSJI

### Czego trader potrzebuje każdego dnia:
1. **Rano** — zapisać nastrój, plan sesji, co obserwujesz na rynku
2. **Podczas** — zapisać transakcję (już jest), powiązać z analizą
3. **Po tradzie** — ankieta post-trade: dlaczego wszedłeś, co czułeś, czy trzymałeś plan
4. **Wieczorem** — wpis dzienny: co się stało, czego się nauczyłeś
5. **Po tygodniu** — automatyczna ankieta: podsumowanie, motywacja, błędy tygodnia
6. **Zawsze** — notatki swobodne (OneNote), strategie, screenshoty setupów

---

## CZĘŚĆ 3 — PLAN DZIAŁANIA (FAZY)

### FAZA 1 — Naprawa bugów (1 dzień)
- [ ] Fix: brakujące HTML w modalu analizy (linked trade widget + `an-levels`)
- [ ] Fix: `saveAnalysis()` + `openEditAnalysis()` — strategyId, setupId, linkedTradeId
- [ ] Fix: autosave analizy — brakujące pola
- [ ] Fix: filtr instrumentów w analizie — populacja unikalnymi symbolami

### FAZA 2 — Full Redesign UI (nowy układ)
**Cel:** jednolity wygląd, nowoczesny sidebar, spójny design system

Nowa nawigacja (sidebar lewy):
```
📊 Dashboard
📋 Transakcje       ← połączone z kalendarzem
📔 Dziennik         ← NOWE (wpis dzienny + OneNote + weekly review)
🔍 Analiza
🎯 Narzędzia        (kalkulator, strategie, setupy)
📊 Statystyki       (statystyki + analiza emocjonalna)
⚙️ Ustawienia
```

Design system:
- Ujednolicone karty (jeden styl dla wszystkich sekcji)
- Spójne empty states
- Spójne formularze (jeden system label + input)
- Mobile responsive

### FAZA 3 — Zakładka Dziennik (Nowe)

#### 3a. Wpis Dzienny (Daily Entry)
Każdy dzień ma:
- **Rano (Pre-session):** nastrój (emoji skala), plan sesji (textarea), które pary obserwujesz, cel dnia, poziom skupienia 1–10
- **Wieczorem (Post-session):** co się stało (textarea), czego się nauczyłeś, ocena dnia 1–10
- **Status:** bez wpisu / rano wypełnione / dzień zamknięty

#### 3b. OneNote-style Notatki
- Zakładki/sekcje: Strategie, Setupy, Rynek, Przemyślenia, Inne
- Notatka = tytuł + rich textarea + screenshoty + tagi
- Wyszukiwarka pełnotekstowa
- Pinowanie ważnych notatek

#### 3c. Kalendarz (ulepszony)
- Widok miesiąca z każdym dniem: P&L (kolor), emocja (emoji), liczba transakcji
- Klik na dzień = panel: wpis dzienny + lista transakcji + notatki z tego dnia
- Zakładka Transakcje może się przełączyć na widok kalendarza

#### 3d. Weekly Review (Automatyczny)
Wyzwalany w piątek wieczór lub ręcznie:
1. Podsumowanie tygodnia (automatyczne: X transakcji, P&L, win rate)
2. Pytania refleksji: "Co poszło dobrze?", "Co byś zmienił?", "Czy trzymałeś plan?", "Co Cię rozpraszało?"
3. Ocena emocjonalna tygodnia
4. Motywacyjne podsumowanie — trader widzi postęp, wysiłek, poprawę

### FAZA 4 — Analiza Emocjonalna (Nowe)

#### 4a. Ankieta post-trade
Po zamknięciu każdej transakcji (lub ręcznie po otwarciu):
- Dlaczego wszedłeś? (plan / impuls / FOMO / revenge)
- Jak się czułeś? (spokojny / podekscytowany / zestresowany / zmęczony)
- Czy trzymałeś swój plan? (tak / nie / częściowo)
- Czy zmieniłeś SL/TP podczas trwania? (tak / nie)
- Ocena jakości decyzji 1–5

#### 4b. Analiza i Wykresy Emocji (w Statystykach)
- **Emocje vs P&L** — wykres słupkowy: gdy grasz spokojny vs zestresowany — ile zarabiasz
- **Overtrading Alert** — po X transakcjach w jednej sesji / po X stratach z rzędu — popup STOP
- **Revenge Trading Detektor** — wejście < 15 min po zamknięciu stratnej transakcji → ostrzeżenie
- **Heatmapa godzin** — o której godzinie Twoje wyniki są najgorsze (emocje + P&L)
- **Wykres konsekwencji planu** — jak często trzymasz plan vs jak wpływa to na P&L
- **Postęp w czasie** — poprawa jakości decyzji miesiąc po miesiącu

#### 4c. Weekly Review Score
Automatyczny wskaźnik zdrowia psychicznego tradera:
- Consistency Score — czy trzymasz strategię
- Discipline Score — czy unikasz impulsów
- Learning Score — czy wracasz do błędów
- Trend poprawy — po 4 tygodniach widać progres

### FAZA 5 — Integracja MT4 + Wskaźniki (po dodaniu 2 nowych)
- All-in-one wskaźnik MQL4 łączący SMC + SR_HVB + nowe 2
- Sygnały kupna/sprzedaży z MTF
- Automatyczne wypełnianie ankiety post-trade z danych EA

---

## CZĘŚĆ 4 — ARCHITEKTURA DANYCH (nowe klucze)

```
// Istniejące
db.accounts[loginKey]
db.trades[loginKey + '_' + accountId]
db.analyses_[user]_[accountId]
db.strategies_[user]
db.setups_[strategyId]

// Nowe
db.journal_[user]_[YYYY-MM-DD]     — wpis dzienny
db.notes_[user]                    — notatki OneNote
db.weekly_[user]_[YYYY-WXX]       — weekly review
db.post_trade_survey_[user]        — ankiety post-trade
```

**Uwaga:** Rozważyć przeniesienie analiz na klucz globalny `analyses_[user]` zamiast per konto — trader często analizuje te same pary na różnych kontach.

---

## CZĘŚĆ 5 — PRIORYTETY (kolejność pracy)

| Kolejność | Zadanie | Czas szacowany |
|-----------|---------|----------------|
| 1 | Naprawa 6 bugów (Faza 1) | ~2h |
| 2 | Full redesign — sidebar + design system (Faza 2) | ~1 dzień |
| 3 | Ulepszony kalendarz + połączenie z transakcjami | ~4h |
| 4 | Zakładka Dziennik: wpis dzienny + notatki | ~6h |
| 5 | Ankieta post-trade | ~3h |
| 6 | Weekly Review | ~4h |
| 7 | Analiza emocjonalna — wykresy i alerty | ~6h |
| 8 | All-in-one wskaźnik MQL4 | po dodaniu 2 nowych plików |

---

*Raport: 2026-05-24 | TraderLogJournal*
