# TraderLogJournal — Dziennik Developerski

> Format: każdy dzień — co zrobiono, co nie wyszło, decyzje, co dalej.
> Cel: żaden kontekst nie ginie między sesjami. Przed każdą sesją czytać ostatni wpis.

---

## 2026-06-03 (środa)

### Stan na wejściu
- `index.html` = produkcja, ostatni commit `ff285aa` (ostrzeżenie kalendarza makro)
- `preview.html` = dev, ma +780 linii funkcji z 01.06 czekających na deploy
- Użytkownik testuje oba pliki

### Co zrobiono

#### Wskaźniki MT4 (nowe pliki)
- `wskazniki/IOFlow_StrengthClassifier.mq4` — port Pine Script "Institutional Order Flow Strength Classifier", Order Blocks ze wskaźnikiem siły BOS, panel z 5 przełącznikami toggle, kompiluje bez błędów
- `wskazniki/PriceActionConcepts.mq4` — port LuxAlgo PAC, zawiera BOS/CHoCH/CHoCH+, OBs z wolumenem %, FVG, EQH/EQL, Premium/Discount, Trend Line Zones, panel 8 przełączników. **Uwaga: wymaga testu kompilacji przez użytkownika**
- Usunięto wszystkie wzmianki o LuxAlgo i licencję CC BY-NC-SA z obu plików

#### Import CSV — poprawki (index.html + preview.html)
- Weryfikacja salda po imporcie MT4 CSV/HTML: wyciąganie wierszy balance/deposit/withdrawal z pliku, porównanie z aktualnym kapitałem konta, auto-korekta po potwierdzeniu
- Auto-match konta: regex wyciąga numer konta MT4 z nagłówka pliku, dopasowuje do `acc.mt4Login`
- Naprawiono: otwarte pozycje MT4 importowane jako `status:'open'` (wcześniej hardkodowane `'closed'`)
- Naprawiono: `mt4Ticket` zapisywany przy imporcie → EA może dopasować pozycję i ją zamknąć
- Naprawiono: po imporcie auto-`sbFullSyncUp()` → Supabase ma dane przed kolejnym sbSyncDown

#### Bug krytyczny — znikające transakcje po odświeżeniu
**Diagnoza:** `sbSyncDown` zapisywał transakcje do `db[loginKey_accountId]` (top-level), a `getTrades`/`saveTrades`/EA szukały w `db.trades[loginKey_accountId]` (pod kluczem `trades`). Dwie różne lokalizacje — dane z Supabase i dane z app nigdy się nie widziały.

**Fix:**
1. `sbSyncDown` → teraz pisze do `db.trades[key]` (zgodnie z resztą kodu)
2. `getTrades` → czyta z obu lokalizacji, merguje, migruje stare dane
3. `saveTrades` → usuwa stary `db[key]` po zapisaniu do `db.trades[key]`
4. `migrateTradesStorage()` → wywoływana przy każdym logowaniu, jednorazowo przenosi dane

#### Bug krytyczny — konta gubione po sbSyncDown
**Diagnoza:** `sbSyncDown` robił `db.accounts[loginKey] = supabaseAccounts` — kompletna zamiana. Konta tylko-lokalne (bez sbId) znikały. Konta z różnym local ID vs Supabase UUID zostawiały orphan trades.

**Fix:** Merge zamiast replace — zachowuje lokalny ID jeśli konto ma matching sbId, przenosi dane jeśli ID się zmieniło, zachowuje konta-tylko-lokalne.

#### Freemium + Onboarding (preview.html)
- Limit 50 zamkniętych transakcji dla nowych użytkowników
- `autoGrantGrandfathered()` — istniejący testerzy automatycznie zwolnieni z limitu przy pierwszym logowaniu
- Badge w sidebarze: `23/50 trans.` → `⚠️ 7 trans. zostało` → `🔒 Limit osiągnięty`
- Modal Upsell: porównanie Free vs Pro (29 zł/mies.), przycisk → email na razie
- Onboarding 4-krokowy: konto → godziny sesji → dane demo → info o planie Free
- Pomija onboarding jeśli użytkownik ma już konta

### Co nie wyszło / problemy
- PriceActionConcepts.mq4: pierwsza wersja miała 22 błędy kompilacji (referencje przez ternary, brakujące `close[]` w parametrach) — wymagała pełnego przepisania
- Zmiana `sbSyncDown` spowodowała chwilową utratę danych u użytkownika (dane były w starym db[key], po naprawie app szukała w db.trades[key]) → naprawione migracją

### Decyzje podjęte
- Freemium limit = 50 (nie mniej — za mało by testować, nie więcej — za mało motywacji do upgrade)
- grandfathered zamiast dat rejestracji — prostsze i niezawodne
- Upsell modal → email zamiast Stripe (Stripe nie zintegrowany jeszcze)

### Stan na wyjście
- `preview.html` niezdeployowany (396 nowych linii uncommitted + dzisiejsze zmiany uncommitted)
- `index.html` ma uncommitted zmiany (balance verification + account auto-match)
- Żadne zmiany nie są w git

### Co dalej (priorytety)
1. **COMMIT + DEPLOY**: zapisać wszystko do gita, preview.html → index.html
2. **TESTY**: użytkownik testuje całość jako nowy użytkownik i jako istniejący
3. **Landing page**: strona główna traderlogjournal.com
4. **RODO**: export + delete konta (wymóg prawny)
5. **Stripe**: po landing page

---

## Szablon dla następnych sesji

```
## YYYY-MM-DD (dzień tygodnia)

### Stan na wejściu
- Co było ostatnio zrobione
- Co czeka na deploy
- Znane problemy

### Cel sesji
- Co chcemy osiągnąć

### Co zrobiono
- (wypełniać na bieżąco)

### Problemy napotkane
- (co nie wyszło i dlaczego)

### Decyzje
- (każda nieoczywista decyzja z uzasadnieniem)

### Stan na wyjście
- Co jest uncommitted
- Co jest niezdeployowane

### Co dalej
- Priorytety na następną sesję
```
