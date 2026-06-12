# TraderLogJournal — Dziennik Developerski

---

## 2026-06-12 / 2026-06-13 (czwartek/piątek)

### Temat sesji
Przegląd wskaźników MT4 — katalogowanie, instrukcje, plan wspólnego panelu TLJ

### Co zrobiono

#### 1. Pełny katalog wskaźników w repo
Przejrzano wszystkie pliki w `wskazniki/`:

**Aktywne (do pracy):**
- `SMC_Complete.mq4` — PAC + IOFlow, 13 togglei
- `HVB1.mq4` — SR High Volume Boxes v4, 5 togglei ✅ (używać zamiast starego v3)
- `RANGE_BREAKOUT_WSKAZNIK.mq4` — ORB sesja 09:30–10:00, extensions + hit rate
- `VRVP Pro MT4.mq4` — Volume Profile, POC/VAH/VAL, brak klikalnego panelu
- `SmartMoneyConcepts.mq4` — LuxAlgo SMC v2 z Daily/Weekly/Monthly levels
- `TraderLogJournal_FIBO_DCA_v1.mq4` — EA: Fibo Grid + DCA Manager
- `IB FIRST HOUR EA.mq4` — Initial Balance EA, NY session

**Duplikaty do usunięcia:** PriceActionConcepts, IOFlow (są w SMC_Complete), SR v3, SMC1, stary EA backup

#### 2. Instrukcja FIBO_DCA
Opisano oba moduły: Fibo Grid (N poziomów, Faron Mode SL, ALL STOP vs #1 MARKET) i DCA Manager (krok pipsowy, shared TP, UpdateAllDcaTP).

#### 3. Analiza matematyczna DCA
- 11 pozycji × 1 lot, krok 15 pips, TP=10 od ostatniego → **wynik: −715 pipsów (STRATA)**
- Breakeven wymaga TP ≥ **75 pipsów** od ostatniego wejścia przy tym scenariuszu
- Potencjalna zmiana kodu: TP liczony od **średniej ceny** zamiast od ostatniego wejścia

### Ustalony workflow (zapisany w memory)
1. Każdy wskaźnik: przegląd → instrukcja → zatwierdzenie przez usera
2. Po zatwierdzeniu: dodanie ON/OFF + zwijany panel [+]/[−]
3. Na końcu: połączenie w jeden panel TraderLogJournal

### Następny wskaźnik do omówienia
Do ustalenia (FIBO_DCA omówiony, czeka na decyzję czy zmieniać TP na średnią)

---

## 2026-06-11 (środa)

### Stan na wejściu
- Kontynuacja sesji z 2026-06-10 (P&L discrepancy między MT4 DetailedStatement a dziennikiem)
- Poprzednio naprawiono: subskrypcja Pro, enc:: prefix EA, sbSyncDown mt4Login

### Co zrobiono — P&L reconciliation

#### 1. Toast EA (index.html + preview.html)
- Linia ~13974: zmieniono `signal.profit` na `(signal.profit||0) + (signal.commission||0) + (signal.swap||0)`
- Bot notification teraz pokazuje "P&L netto" zamiast gross

#### 2. Import — deduplicacja po numerze ticketu MT4
- `renderImportPreview`: priorytet dopasowania to `mt4Ticket` (zamiast data+entry)
- Nowa flaga `_pnlDiffers`: zaznacza transakcje które matchują ticketem ale mają inne P&L
- Podgląd importu: badge "↻ P&L" zamiast "dup" dla transakcji z innym P&L
- Licznik "↻ X z innym P&L" w summary (widoczne w nagłówku)

#### 3. Import — checkbox "Aktualizuj P&L istniejących"
- Nowy checkbox `#import-update-pnl` obok przycisku Importuj
- Gdy zaznaczony + transakcja dopasowana po ticket: aktualizuje pnl/commission/swap istniejącej
- Toast końcowy pokazuje: `| ↻ zaktualizowano P&L: X`
- Przycisk "Importuj" aktywny gdy są NOWE lub do AKTUALIZACJI (wcześniej tylko nowe)

#### 4. Dashboard — karta "Balans konta"
- Zmieniono etykietę "Kapitał" → "Balans konta"
- Karty: Depozyt: $X + P&L netto: ±$Y (dwie linie w stat-sub)
- Karta "P&L Total" → "P&L netto"

#### 5. Stats — karta "Całkowity P&L"
- Dodano sub-linie: Depozyt / Prowizje / Swap / Balans
- Wyraźne zestawienie identyczne jak MT4 balance reconciliation
- Prowizje i swap pokazują się tylko gdy != 0

### Jak dopasować historyczne dane do MT4 raportu
1. Import → wybierz konto → przeciągnij DetailedStatement.htm
2. W podglądzie zobaczysz "↻ X z innym P&L" — to transakcje które wymagają aktualizacji
3. Zaznacz checkbox "Aktualizuj P&L istniejących (po tickecie MT4)"
4. Kliknij Importuj

---

## 2026-06-10 (wtorek)

### Stan na wejściu
- EA v2.mq4 gotowy do testów po poprzedniej sesji (bugfixe DOŁĄCZ, TP, Virtual SL/TP, minimalizacja panelu)
- User testuje na żywo (czeka na ruch rynkowy)
- Pending: WTI.FS nieprawidłowo liczy lot (diagnostyka wysłana, czeka na dane z Experts tab)

### Co zrobiono — GetPipSize: pełny audyt i przepisanie

#### Audyt instrumentów AXI (tabela)
| Kategoria | Digits | Stary wynik | Poprawny? |
|---|---|---|---|
| Forex (EURUSD, GBPUSD) | 5 | 0.0001 | ✅ |
| JPY (USDJPY) | 3 | 0.01 | ✅ |
| Gold (XAUUSD) | 2-3 | 0.1 | ✅ |
| Silver (XAGUSD) | 3 | 0.01 | ✅ |
| WTI.FS, BRENT.FS | 2 | 0.01 | ✅ prawdopodobnie |
| AUS200.FS, US30.FS (digit=1) | 1 | 1.0 | ✅ |
| NAS100.FS, GER40.FS (digit=1) | 1 | 1.0 | ✅ |
| JPN225.FS (digit=0) | 0 | 1.0 | ✅ |
| **BTCUSD, ETHUSD** | **2** | **0.01** | **❌ powinno być 1.0** |

#### Fix GetPipSize (wskazniki/TraderLogJournal_EA_v2.mq4)
- Przepisana pełna funkcja GetPipSize z 6 blokami:
  1. **ZŁOTO/PLATYNA/PALLAD** — hardkodowane 0.1 (bez zmian)
  2. **SREBRO** — 0.01 dla digits≤2, pt*10 dla digits=3
  3. **KRYPTO** — BTC/ETH/LTC/BCH/DOT/ADA/SOL/LINK → 1.0; XRP/DOGE → 0.0001
  4. **ROPA I GAZY** — WTI/BRENT/OIL/NGAS → pt (digits=2) lub pt*10 (digits=3) = 0.01
  5. **INDEKSY** — AUS200/UK100/US30/US500/NAS100/GER40/FRA40/JPN225/HKG50 itd. → 1.0 (force)
  6. **FOREX i RESZTA** — dg%2==1 → pt*10, inaczej pt

#### Diagnostyka CalcLot (nadal aktywna)
- Print "[CALCLOT]" w Experts tab — user musi: kompilacja F7 → otwarcie WTI.FS → klik Oblicz → wkleić wynik
- Po potwierdzeniu WTI.FS działa → usunąć Print z kodu

### GetPipSize WTI — potwierdzony diagnostyką
- User wkleił wynik `TLJ [CALCLOT]`: `tickVal=10.00, pipSz=0.10, pipVal=100.00, lot=0.27` ✓
- Lot 0.27 jest POPRAWNY: $65k × 0.25% = $164 / (6 × $100) = 0.27 ✓
- Usunięto Print diagnostyczny z CalcLot

### Nowy EA: TraderLogJournal_FIBO_DCA_v1.mq4
- Stworzono osobny plik EA z dwoma strategiami:
  - **FIBO GRID**: 2 linie (TOP/BOT) → N podglądów → BUILD BUY/SELL STOP
  - **DCA Manager**: dokłada pozycję gdy cena cofa o Krok pipsów (max Mx razy)
- Faron Mode SL w FIBO GRID (jak w głównym EA)
- Ta sama logika CalcLot i GetPipSize co główny EA
- Osobny MagicNumber: `20261010`
- Panel na Y=260 (poniżej głównego EA)

### Nowa instrukcja: FIBO_DCA_INSTRUKCJA.md
- Osobna instrukcja dla nowego EA
- Sekcje: instalacja, panel, FIBO krok-po-kroku, DCA krok-po-kroku
- Tabela pip size dla wszystkich instrumentów
- Matematyka + przykłady WTI ($12 000 zysk przy N=4, 2 loty)
- Szybka ściąga na końcu

### Co dalej
1. **[PILNE]** Kompilacja F7 nowego EA `TraderLogJournal_FIBO_DCA_v1.mq4`
2. **[TEST]** FIBO GRID: narysuj linie → BUILD BUY → sprawdź zlecenia w terminalu
3. **[TEST]** DCA: DCA BUY → sprawdź czy dokłada po Krok pipsach
4. **[OPCJONALNE]** Minimalizacja sekcji FIBO/DCA (ON/OFF per sekcja)

---

## 2026-06-08 (poniedziałek)

### Stan na wejściu
- Sesja przerwana (zamknięty terminal) — kontekst odtworzony z DAILY_LOG + git log
- EA v2.mq4 miał rozpoczęty refaktor separacji SIATKA/PIRA — ukończony dzisiaj

### Co zrobiono (EA v2.mq4)

#### Separacja SIATKA / PIRA — ukończona
- **SIATKA:WYŁ/WŁ toggle**: kliknięcie przełącza `_siatkaEnabled`; gdy WŁ → przyciski BUY/SELL zmieniają się na **GRID BUY** / **GRID SELL** i wywołują `PlaceGrid()`
- **PIRA toggle**: przycisk `PIRA` (38px) włącza/wyłącza `_autoPyramidEnabled`; pole **Mx** (edytowalne, 22px) pozwala zmienić max dokładek bez rekompilacji EA
- **UpdatePanel**: SIATKA pokazuje `SIATKA:WŁ Np` (N = ilość pending STOP orders TLJ_GRID_*); PIRA pokazuje `PIRA:WŁ Nx` (N = otwarte dokładki TLJ_PYR_*)
- **CheckAutoPyramid**: czyta max poziomy z `EDIT_PYR_MAX` (fallback na parametr `PyramidMaxLevels` gdy pole puste/0)
- **DeletePanel**: zawiera `BTN_SIATKA`, `EDIT_PYR_MAX`, `TLJ_MxLbl`; usunięto nieistniejące `BTN_GRID_BUY`/`BTN_GRID_SEL`
- **OnChartEvent**: `BTN_GRID_BUY`/`BTN_GRID_SEL` usunięte; `BTN_SIATKA` toggle dodany

#### Nowe pliki w repo
- `wskazniki/SMC_Complete.mq4` — wskaźnik SMC Suite (732 linie), wymaga testu kompilacji
- `wskazniki/TraderLogJournal_EA_v2.mq5` — port MT5 EA (do testów)
- `wskazniki/TODO_PONIEDZIALEK.md` — plan SMC panel ON/OFF + collapse (Opcja C)
- `wskazniki/PIRAMIDOWANIE_INSTRUKCJA.md` — pełna instrukcja zaktualizowana

#### Instrukcja zaktualizowana
- Diagram panelu odzwierciedla nowy układ (SIATKA sekcja z togglem, PIRA sekcja z Mx)
- Kroki "jak używać" zaktualizowane dla obu strategii
- Tabela porównawcza ma wiersze "Włączanie" i "Anulowanie"

#### Faron Mode — naprawa SL i lota per-pozycja (commit b20f2e4)
- **Stary błąd:** wszystkie zlecenia siatki miały TEN SAM absolutny SL i lot = `totalLot/N`
- **Diagnoza z nagrania:** Paweł wprost mówi: „100-plus z drugiej pozycji nie może być w tym samym miejscu — nasz 100-plus jest przesuwany"
- **Naprawa `PlaceGrid()`:**
  - `#1`: lot = `CalcLot(riskPct, slPips)`, SL = `entry ± slPips` (oryginalny SL)
  - `#2+`: lot = `CalcLot(riskPct, stepPips)`, SL = `entry - stepPips` = wejście poprzedniego = BE poprzedniego
  - Efekt: #1≈2%, #2≈3%, #3≈2%, #4≈1% → łącznie **~8%** przy trafieniu TP (zgodnie z filmem)
- `CheckGridFills` → `MoveSLtoBreakEven` pozostaje bez zmian — przesuwa SL pozycji market do jej wejścia gdy kolejna się wypełnia ✓

### Sesja 2026-06-09 — bugfixe EA v2 po testach na XAUGBP.pro

#### Bug 1: GetPipSize złoto — LOT 10× ZA DUŻY (naprawione)
- **Problem**: XAUGBP.pro ma dg=3 (nieparzyste) → kod wchodził w `dg%2==1` → zwracał 0.001×10=0.01. XAUUSD dg=2 → `dg==2` XAU check → zwracał 0.01×10=0.10 (10× za duże). Lot dla XAUUSD był 10× za mały, dla XAUGBP.pro był przypadkowo poprawny (0.01).
- **Fix**: Detekcja XAU/XPT/XPD/GOLD PRZED sprawdzeniem parzystości cyfr → zawsze zwraca 0.01 ("pip-punkt"). Użytkownik wpisuje liczby w pip-punktach (0.01 jednostki/pip).

#### Bug 2: Orphaned pending orders po SL (naprawione)
- **Problem**: Gdy EA było restartowane po SL, `_gridOpenTickets` był pusty → `anyClosed` nigdy nie wykrywało zamknięcia → zlecenia pending siatki zostawały.
- **Fix**: W `CheckGridFills()` przy inicjalizacji (`!_gridInitialized`): jeśli `currentOpen=[]` ale są pending TLJ_GRID_* → usuń je od razu.

#### Bug 3: OrderModify error logging (dodane)
- `OrderModify` w CheckGridFills teraz loguje błąd z `GetLastError()` gdy zawiedzie.

#### Pole Stp w panelu — jest w kodzie (linia 295), ale EA wymaga rekompilacji
- Pole `EDIT_PYR_STP` ("Krok PIRA pips") JEST w kodzie między wierszem PIRA a Close buttons.
- Użytkownik nie widzi go bo ma stary .ex4 skompilowany. Wymaga: skopiować .mq4 do folderu MT4, otworzyć MetaEditor, kompilacja F7, zdjąć EA i wczytać nowe.

### Sesja 2026-06-09 (cd.) — Nowy panel collapsible SIATKA + PIRAMID

#### Ukończono przepisanie panelu EA v2

- **CreatePanel**: dynamiczne Y (hSiatka=26, hPira=68) — wysokość od 368 do 462px
  - BASE: tytuł, konto, kalkulator, BUY/SELL (zawsze widoczne)
  - SIATKA header: [▶/▼ SIATKA] + [□WYŁ/■WŁ] — klik ▶/▼ → expand/collapse, klik WŁ/WYŁ → toggle
  - SIATKA expanded: N: field + GRID BUY + GRID SELL
  - PIRA header: [▶/▼ PIRAMID] + [□WYŁ/■WŁ x] — analogicznie
  - PIRA expanded: [% konta / stały lot] toggle + pole ryzyko/lot + [Mx Stp] + [+ADD BUY/SELL]
  - FOOTER: Close ALL/BUY/SELL + Pauza + Stop + link
- **UpdatePanel**: aktualizuje BTN_SIATKA_HDR, BTN_SIATKA_ONOFF, BTN_PIRA_HDR, BTN_PIRA_ONOFF; usuwa stare BTN_SIATKA/BTN_PYRAMID
- **DeletePanel**: pełna lista obiektów nowego panelu + BTN_SIATKA/BTN_PYRAMID legacy cleanup
- **OnChartEvent**: nowe handlery BTN_SIATKA_HDR/ONOFF, BTN_GRID_BUY/SEL, BTN_PIRA_HDR/ONOFF, BTN_PIRA_MODE
- **GetPiraLot(slPips)**: czyta EDIT_PYR_RISK (% konta) lub EDIT_PYR_LOT (stały lot) wg `_piraModePct`
- **OpenPyramidOrder**: używa GetPiraLot zamiast PyramidRiskPct/CalcLot
- **CheckAutoPyramid**: używa GetPiraLot zamiast PyramidRiskPct/CalcLot

#### Sesja 2026-06-09 (kontynuacja po przerwie kontekstu)

##### Funkcja DOŁĄCZ + UpdateGridTP (dokończone)
- **`AttachGridToExisting(direction)`** — pełna implementacja:
  - Szuka ostatnio otwartej pozycji w danym kierunku (wyklucza TLJ_GRID_*)
  - Ustawia `_gridBaseTicket = baseTicket`
  - Aktualizuje TP bazowej pozycji
  - Wystawia N-1 STOP-ów (TLJ_GRID_2ofN … TLJ_GRID_NofN) z entry/SL/TP od bazy
  - `_gridInitialized = false` → `CheckGridFills` od razu przejmuje zarządzanie SL
- **`UpdateGridTP()`** — wywoływane przez `CHARTEVENT_OBJECT_ENDEDIT` na EDIT_TP:
  - Szuka bazy przez `_gridBaseTicket` lub pierwszy TLJ_GRID_1of*
  - Przelicza nowy TP: `basePrice ± tpPips × pipSz`
  - Modyfikuje TP bazy + wszystkich aktywnych TLJ_GRID_* jednym przebiegiem
- **Fixe legacy**: wszystkie `clrNone` → `CLR_NONE` (0 błędów kompilacji)
- **CheckAutoPyramid**: wyklucza TLJ_GRID_* i "TLJ Panel+" z piramidowania
- **GlobalVariables**: SaveState/LoadState przeżywa zmianę interwału (`_gvPfx = "TLJ_" + accountNumber + "_"`)

##### Bug: SELL grid znika po postawieniu (naprawiony)
- **Symptom**: siatka SELL stawiana, natychmiast kasowana ("deleting of invalid order" w logu MT4)
- **Przyczyna**: `PlaceGrid` nie resetowało `_gridInitialized = false`. Gdy poprzednia siatka była zamknięta przez SL, `_gridOpenTickets` zawierał stare zamknięte tickety, a `_gridInitialized = true`. Następna siatka zostawała postawiona, a po 2 sekundach `CheckGridFills` widział `anyClosed = true` (stare tickety zniknęły) i kasował wszystkie nowe pending orders.
- **Fix**: `_gridInitialized = false` dodane na końcu `PlaceGrid` (tak jak już było w `AttachGridToExisting`)
- **Dlaczego BUY działało**: pierwszy grid w sesji → `_gridInitialized` było jeszcze `false` z OnInit → init block uruchamiał się poprawnie bez fałszywego `anyClosed`

##### Instrukcja zaktualizowana
- Pełna przebudowa `PIRAMIDOWANIE_INSTRUKCJA.md`:
  - Nowy diagram panelu (collapsible SIATKA + PIRA)
  - Sekcja DOŁĄCZ (nowa funkcja)
  - Sekcja Zarządzanie TP
  - Sekcja Wskaźniki — czy zakłócają EA (nowa)
  - Sekcja FTMO — zasady i zgodność (nowa)
  - Zaktualizowane tabele parametrów, konfiguracji, matematyki

### Co dalej (sesja wieczorna — patrz niżej)
1. Skompiluj EA: skopiuj `.mq4` do `MQL4/Experts/`, MetaEditor F7, wczytaj na wykres
2. Test pełny: SELL grid N=4 → powinna zostać (fix); DOŁĄCZ BUY do istniejącej pozycji; zmiana TP → siatka przesuwa się
3. SMC_Complete.mq4 — panel ON/OFF + collapse (zgodnie z TODO_PONIEDZIALEK.md, Opcja C)
4. Deploy preview.html → index.html po akceptacji przez użytkownika

---

### Sesja 2026-06-09 wieczór — bugfixe z testów live + nowe funkcje

#### Bug: DOŁĄCZ — "deleting of invalid order" (naprawiony)
- **Symptom**: po kliknięciu DOŁĄCZ BUY siatka stawiana → natychmiast kasowana przez brokera
- **Diagnoza z logów MT4** (screenshoty 222132, 222139, 222706, 222709): broker zwracał "deleting of invalid order" — znaczy EA NIE kasowało, kasował broker
- **Przyczyna**: STOP orders wyliczane od `basePrice` (cena otwarcia istniejącej pozycji). Jeśli rynek przesunął się kilka pipsów od momentu otwarcia, pierwsze STOP-y lądowały poniżej lub w strefie stop level brokera (Ask ± minDist) → invalid
- **Fix**: anchor zmieniony z `basePrice` na `liveAsk`/`liveBid` (aktualna cena). Faron SL zachowany: level 2 SL = basePrice, level j+1 SL = liveAsk + (j-1)*step
- **Dodane**: walidacja `stepPips * pipSz < minDist` → Alert "Zmniejsz N lub zwiększ TP" zamiast cichego błędu

#### Bug: DOŁĄCZ z LINII — brak walidacji stop level (naprawiony)
- Dodany check dla każdej linii: `distFromMkt < minDistL` → Alert z numerem poziomu
- Chroni przed rysowaniem linii po złej stronie ceny lub zbyt blisko

#### Fix: TP nie widoczny w terminalu po BUY/SELL (naprawiony)
- **Przyczyna**: `OpenOrder` miał hardkodowane `tp=0` przy OrderSend — EDIT_TP było ignorowane
- **Fix**: odczyt `tpPips = EDIT_TP`, wyliczenie `tp = liveAsk + tpPips * pipSz`, przekazanie do OrderSend
- Teraz SL i TP są widoczne jako linie w terminalu MT4

#### Fix: TP dokładki PIRA (naprawiony)
- `CheckAutoPyramid` wysyłało `tp=0` mimo że `parentTP` było dostępne
- Fix: `pyrTP = parentTP`, przekazane do OrderSend

#### Nowa funkcja: Virtual SL/TP — stealth mode
- Parametr `input bool VirtualSLTP = false`
- Gdy `true`: EA wysyła `sl=0, tp=0` do brokera, przechowuje poziomy w GlobalVariables `VTLJ_SL_TICKET` / `VTLJ_TP_TICKET`
- Nowa funkcja `CheckVirtualLevels()` w OnTimer: sprawdza Bid/Ask vs vSL/vTP co 2s, zamyka market gdy osiągnięty
- Obsługuje: OpenOrder i CheckAutoPyramid (pyramid orders)
- SIATKA/DOŁĄCZ NIE używa virtual (broker musi akceptować STOP orders z SL/TP)

#### Nowa funkcja: Minimalizacja panelu
- Przycisk `▼` w prawym górnym rogu → panel składa się do paska 28px
- Przycisk `▲` → przywraca pełny panel
- Wartości kalkulatora (Ryzyko%, SL, TP, N, Mx, Stp, Lot) zapisywane do GlobalVariables przy minimize, przywracane przy restore
- Stan minimalizacji przeżywa zmianę interwału

#### Instrukcja PIRAMIDOWANIE_INSTRUKCJA.md — pełna aktualizacja do v2.1
- Nowa sekcja 4: GRID z LINII — instrukcja użytkowania ręcznych poziomów
- Nowa sekcja 11: Virtual SL/TP — tryb stealth z ograniczeniami
- Nowa sekcja 12: Minimalizacja panelu
- Zaktualizowany diagram panelu (4 rzędy SIATKA expanded, przycisk ▼ w tytule)
- Sekcja DOŁĄCZ — dodana info o anchor = liveAsk (nie basePrice)
- Sekcja TP — wyjaśnienie że TP teraz wysyłany do brokera

#### Pytanie użytkownika: GRID jak FIBO na wykresie?
- **Tak, możliwe** — do implementacji w następnej sesji
- Koncepcja: dwie linie graniczne `TLJ_ZONE_TOP` i `TLJ_ZONE_BOT` (przeciągalne), EA auto-dzieli zakres na N równych poziomów i je wyświetla jako podgląd, klik BUILD → stawia zlecenia
- Wizualnie identyczne jak Fibonacci Retracement — przeciągnij od strefy A do strefy B

#### Pytanie użytkownika: DCA (Dollar Cost Averaging)
- **Do implementacji jutro** — dodawanie pozycji na cofnięcie (przeciwnie do PIRA/GRID)
- Ryzyko: wymaga bardzo ostrożnego zarządzania ryzykiem (różni się od Faron Mode)

### Co dalej (na jutro)
1. **[PRIORYTET]** Kompilacja F7 + test live: DOŁĄCZ BUY, TP w terminalu, panel minimize
2. **GRID jak FIBO** — implementacja dwóch linii granicznych + auto-podział + BUILD
3. **DCA Manager** — odrębna sekcja w panelu, dokłada gdy cena cofa o X pips na stratę
4. Minimalizacja sekcji przy każdej strategii (ON/OFF widoczny w zminimalizowanym)

> Format: każdy dzień — co zrobiono, co nie wyszło, decyzje, co dalej.
> Cel: żaden kontekst nie ginie między sesjami. Przed każdą sesją czytać ostatni wpis.
> Cel: żaden kontekst nie ginie między sesjami. Przed każdą sesją czytać ostatni wpis.

---

## 2026-06-07 (sobota)

### Stan na wejściu
- `preview.html` = dev, niezdeployowany
- `index.html` = produkcja (bez dzisiejszych zmian)

### Co zrobiono (preview.html)

#### Terminal Analiz — nowa architektura rutyny dnia
- Kroki pre-sesji przeorganizowane: Plan (krok 2) → Gotowość (krok 3) → **Terminal Analiz** (krok 4, ostatni)
- Terminal Analiz to nowy krok: użytkownik wpisuje instrumenty, dla każdego pojawia się karta
- Karta karty: przycisk "📈 Analizuj" otwiera **pełne okno analizy** (istniejący modal) pre-wypełniony symbolem i datą
- Jeśli analiza na dany instrument już istnieje dziś → karta pokazuje ✅ + podgląd (bias, poziomy)
- `renderInstrumentCards()` odświeża karty po każdym zapisie analizy
- Pasek postępu kroku 4 zalicza się gdy: kalendarz sprawdzony LUB min. 1 analiza dla planowanych instrumentów
- Stary formularz (globalne poziomy S/R, bias, warunki) usunięty — zastąpiony terminalem

#### Freemium — panel PRO w Admin
- W tabeli użytkowników dodana kolumna "Plan" (Free / ⭐ PRO / 👑 Admin)
- Przycisk "⭐ PRO" / "→ Free" per użytkownik → `adminTogglePro(userId, sub)` → PATCH `/profiles` w Supabase
- Admini i własne konto nie mają przycisku toggle (zabezpieczenie)

#### Powrót do rutyny dnia
- Przyciski w ostrzeżeniu kalendarza: "Otwórz makro" i "Ustaw przypomnienia" → `_returnToRoutineFrom(page)`
- Na stronie Makro pojawia się baner "← Wróć do rutyny" gdy wejście z rutyny
- `_backToRoutine()` wraca do zakładki Journal Pre-sesji i resetuje flagę

#### Ostrzeżenie o nieplanowanym instrumencie
- W oknie analizy: gdy użytkownik wpisuje symbol, po 700ms sprawdza czy był w planie dnia
- Jeśli nie był → modal `showConfirm` z pytaniem "Czy jesteś przygotowany?"
- Jeśli symbol otwarto z Terminal Analiz (`_analysisFromRoutineSym`) → ostrzeżenie pominięte

#### Sugestia przypomnień makro
- Na stronie Makro, gdy brak skonfigurowanych przypomnień → baner sugestii z przyciskiem

#### Analiza → Transakcja (przepisane)
- Przycisk "Zapisz jako transakcję" nie wymaga już istniejącej transakcji
- Otwiera nowy formularz transakcji z pre-wypełnionymi: symbol, pre-analiza, kierunek (z bias), screenshoty, link do analizy
- Analiza jest najpierw zapisywana, potem otwierany modal transakcji

### Co dalej
1. Użytkownik testuje Terminal Analiz i zgłasza feedback
2. Deploy do index.html po akceptacji
3. Settings — return banner analogicznie jak na Makro

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
