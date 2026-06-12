# TraderLogJournal EA v2 — Instrukcja użytkownika

> Wersja: EA v2.1 | Aktualizacja: 2026-06-09

---

## Spis treści

1. [Panel EA — układ i sekcje](#1-panel-ea--układ-i-sekcje)
2. [Kalkulator pozycji](#2-kalkulator-pozycji)
3. [SIATKA — Faron Mode (pending grid)](#3-siatka--faron-mode-pending-grid)
4. [GRID z LINII — ręczne poziomy](#4-grid-z-linii--ręczne-poziomy)
5. [DOŁĄCZ — siatka do istniejącej pozycji](#5-dołącz--siatka-do-istniejącej-pozycji)
6. [Zarządzanie TP całej siatki](#6-zarządzanie-tp-całej-siatki)
7. [PIRA — automatyczne piramidowanie](#7-pira--automatyczne-piramidowanie)
8. [ADD BUY / ADD SELL — ręczna dokładka](#8-add-buy--add-sell--ręczna-dokładka)
9. [Mechanizm wspólnego SL (Break-Even)](#9-mechanizm-wspólnego-sl-break-even)
10. [Matematyka Faron Mode](#10-matematyka-faron-mode)
11. [Virtual SL/TP — tryb stealth](#11-virtual-sltp--tryb-stealth)
12. [Minimalizacja panelu](#12-minimalizacja-panelu)
13. [Parametry EA](#13-parametry-ea)
14. [Wskaźniki — czy zakłócają EA?](#14-wskaźniki--czy-zakłócają-ea)
15. [FTMO — zasady i zgodność](#15-ftmo--zasady-i-zgodność)
16. [Ważne zasady i pułapki](#16-ważne-zasady-i-pułapki)

---

## 1. Panel EA — układ i sekcje

```
┌──────────────────────────────────────────┐
│ TraderLog  Journal               EA  [▼] │  ← [▼] = minimalizuj panel
│ EA v2.1                       ● Aktywny  │
│ ───────────────────────────────────────  │
│ KONTO        #12345678                   │
│ EQUITY       $10 250.00                  │
│ P&L OTWR.    +$45.20                     │
│ OTWARTE      2 pozycje                   │
│ WYSŁANO      14 syg.                     │
│ ───────────────────────────────────────  │
│ KALKULATOR POZYCJI                       │
│ Ryzyko %   [1.0 ]                        │
│ SL (pips)  [30.0]                        │
│ TP (pips)  [120.0]                       │
│ Lot: 0.05   R:R 1:4.0    [Oblicz]        │
│ ───────────────────────────────────────  │
│ [    BUY (GRID)    ] [  SELL (GRID)   ]  │  ← gdy SIATKA WŁ
│ ───────────────────────────────────────  │
│ [▼ SIATKA          ] [      ■ WŁ     ]  │  ← klik ▶/▼ = expand
│   N:[4] [GRID BUY  ] [GRID SELL      ]  │  ← row 1
│   [+ POZIOM] [2 lvl] [- POZIOM       ]  │  ← row 2: ręczne linie
│   [GRID z LINII BUY] [GRID z LINII SEL] │  ← row 3: grid z linii
│   [+ DOŁĄCZ BUY    ] [+ DOŁĄCZ SELL  ]  │  ← row 4
│ ───────────────────────────────────────  │
│ [▶ PIRAMID         ] [      □ WYŁ    ]  │  ← collapsed
│ ───────────────────────────────────────  │
│   (expanded PIRA:)                       │
│   [% konta] Ryz%:[0.5]                  │
│   Mx:[2] Stp:[20.0]                      │
│   [+ADD BUY        ] [+ADD SELL       ]  │
│ ───────────────────────────────────────  │
│ [Close ALL][Close BUY][Close SELL]       │
│ ───────────────────────────────────────  │
│ [⏸ Pauza           ] [⏹ Stop EA     ]   │
│ traderlogjournal.com                     │
└──────────────────────────────────────────┘
```

### Przyciski BUY / SELL (główne)

| Stan SIATKA | Klik BUY / SELL |
|---|---|
| **WYŁ** | Otwiera pojedynczą pozycję market (z TP jeśli wpisane) |
| **WŁ** | Stawia całą siatkę Faron Mode (identycznie jak GRID BUY/SELL) |

### Collapsible sekcje

- Klik **▶/▼** nagłówka = rozwiń/zwiń sekcję (zapamiętywa się po zmianie interwału)
- Klik **WŁ/WYŁ** = włącz/wyłącz funkcję (niezależnie od rozwinięcia)
- Klik **▼** w prawym górnym rogu = minimalizuj cały panel do paska tytułu

---

## 2. Kalkulator pozycji

| Pole | Co wpisać | Uwagi |
|---|---|---|
| **Ryzyko %** | % konta na pozycję | np. `1.0` |
| **SL (pips)** | SL od entry w pipsach | np. `50` dla XAUGBP |
| **TP (pips)** | TP od entry w pipsach | Opcjonalne — jeśli puste, pozycja bez TP |

Kliknij **Oblicz** → panel pokazuje wyliczony lot i R:R.

> **TP jest teraz wysyłany do brokera** — widoczny w terminalu MT4 jako poziom take profit.
> Przy DOŁĄCZ: EA czyta TP z istniejącej pozycji automatycznie (pole TP nie jest wymagane).

---

## 3. SIATKA — Faron Mode (pending grid)

Stawia **wszystkie zlecenia naraz** — #1 market, #2…#N jako STOP orders w kierunku zysku.
Widzisz je wszystkie w zakładce Trade MT4 zanim cena do nich dotrze.

### Jak używać

1. Wypełnij kalkulator: **Ryzyko%**, **SL**, **TP** → kliknij **Oblicz**
2. Wpisz **N** (2–10) — liczba pozycji w piramidzie
3. Kliknij nagłówek **▶ SIATKA** → rozwinie się sekcja
4. Kliknij **GRID BUY** lub **GRID SELL** (albo włącz SIATKA WŁ i klik główny BUY/SELL)

### Co EA stawia (N=4, TP=120 pips, krok=30 pip)

```
Krok = TP ÷ N = 120 ÷ 4 = 30 pip

BUY SIATKA:
  #1  BUY market   @ Ask        SL = Ask − SL_pips    TP = Ask + 120p
  #2  BUY STOP     @ Ask+30p    SL = Ask (= entry#1)  TP = Ask + 120p
  #3  BUY STOP     @ Ask+60p    SL = Ask+30p          TP = Ask + 120p
  #4  BUY STOP     @ Ask+90p    SL = Ask+60p          TP = Ask + 120p

SELL SIATKA:
  #1  SELL market  @ Bid        SL = Bid + SL_pips    TP = Bid − 120p
  #2  SELL STOP    @ Bid−30p    SL = Bid (= entry#1)  TP = Bid − 120p
  #3  SELL STOP    @ Bid−60p    SL = Bid−30p          TP = Bid − 120p
  #4  SELL STOP    @ Bid−90p    SL = Bid−60p          TP = Bid − 120p
```

### Automatyczne przesunięcie SL

Gdy każdy STOP się wypełni → EA automatycznie przesuwa **wszystkie** otwarte pozycje siatki na wspólny SL = cena wejścia poprzedniej:

```
#2 wchodzi → SL wszystkich → entry#1  (BE dla #1)
#3 wchodzi → SL wszystkich → entry#2  (BE dla #2, zysk dla #1)
#4 wchodzi → SL wszystkich → entry#3  (BE dla #3, zysk dla #1,#2)
```

---

## 4. GRID z LINII — ręczne poziomy

Rysujesz poziomy siatki **sam na wykresie** — przeciągasz linie dokładnie do stref które Cię interesują (support/resistance, OB, FVG). EA stawia STOP orders dokładnie w tych miejscach.

### Jak używać

1. W sekcji **▼ SIATKA** klikaj **+ POZIOM** — pojawia się zielona przerywana linia `TLJ_GL_1`, `TLJ_GL_2`...
2. **Przeciągnij** każdą linię na wybrany poziom cenowy (jak każdy inny obiekt w MT4)
3. Licznik `X lvl` pokazuje ile linii masz narysowanych
4. Gdy wszystkie poziomy są gotowe → kliknij **GRID z LINII BUY** lub **GRID z LINII SELL**
5. EA stawia grid: #1 market @ cena bieżąca, #2…#N STOP @ ceny linii
6. Linie znikają po postawieniu zleceń

### Usuwanie poziomów

- **- POZIOM** usuwa ostatnią linię (od najwyżej numerowanej)
- Możesz też usunąć linię ręcznie w MT4 (zaznacz → Delete)

### Jak EA przelicza lot i SL

```
Faron Mode — każdy poziom niezależnie:
  #1  market   @ liveAsk     SL = liveAsk − SL_pips (z kalkulatora)
  #2  STOP     @ cena linii 1  SL = liveAsk (= entry #1)
  #3  STOP     @ cena linii 2  SL = cena linii 1
  ...
  Lot każdego poziomu = CalcLot(Ryzyko%, odległość do własnego SL)
```

> **Wymagane przed kliknięciem GRID z LINII:** Ryzyko% i SL w kalkulatorze.
> TP opcjonalne — jeśli wpisane, wszystkie poziomy dostają ten sam TP.

### Walidacja

EA sprawdza czy każda linia jest:
- Po właściwej stronie ceny (dla BUY — linia powyżej Ask)
- Powyżej minimalnego stop level brokera

Jeśli nie → Alert z numerem błędnego poziomu, grid nie jest stawiany.

---

## 5. DOŁĄCZ — siatka do istniejącej pozycji

Masz już otwartą pozycję i chcesz dostawić do niej N-1 STOP orders siatki **jednym kliknięciem**.

### Jak używać

1. Otwórz pozycję (ręcznie lub normalnym BUY/SELL)
2. Wypełnij kalkulator: **Ryzyko%**, **SL**, **N** → **Oblicz**
3. TP może być pusty — EA odczyta go z TP istniejącej pozycji automatycznie
4. Rozwiń **▼ SIATKA** i kliknij **+ DOŁĄCZ BUY** lub **+ DOŁĄCZ SELL**

### Dwa tryby (auto-wykrywany)

| Warunek | Tryb | Zachowanie |
|---|---|---|
| Brak linii TLJ_GL_* | **Równe kroki** | STOP-y co `TP÷N` pipsów od aktualnej ceny |
| Narysowane linie TLJ_GL_* | **Z linii** | STOP-y dokładnie na Twoich liniach |

> **WAŻNE:** STOP-y są liczone od **aktualnej ceny** (liveAsk/liveBid), NIE od ceny otwarcia bazy.
> Dzięki temu działa poprawnie nawet gdy bazowa pozycja była otwarta kilka godzin temu.

### Co EA robi

1. Szuka ostatnio otwartej pozycji w danym kierunku na bieżącym symbolu
2. Odczytuje jej TP (jeśli ustawione) → używa jako tpPips; fallback: pole TP kalkulatora
3. Ustawia tę pozycję jako **level 1** (zapamiętuje jej ticket)
4. Aktualizuje jej TP do wyliczonego poziomu
5. Wystawia N-1 STOP orders: `TLJ_GRID_2ofN` … `TLJ_GRID_NofN`
6. Od teraz CheckGridFills zarządza wspólnym SL — tak samo jak zwykła siatka

---

## 6. Zarządzanie TP całej siatki

Gdy zmienisz wartość w polu **TP (pips)** kalkulatora i zatwierdzisz (Enter/Tab) → EA automatycznie aktualizuje TP **wszystkich** aktywnych zleceń siatki (GRID + pozycji bazowej DOŁĄCZ) do nowego poziomu.

```
Zmień TP: 120 → 160 pip
→ EA przelicza: baseEntry ± 160*pipSz
→ OrderModify na każdej pozycji/pendingu TLJ_GRID_*
→ Pozycja bazowa (DOŁĄCZ) też dostaje nowy TP
```

---

## 7. PIRA — automatyczne piramidowanie

EA **sam obserwuje zysk** otwartych pozycji i dokłada kolejne market orders gdy zysk przekroczy próg — bez Twojej interwencji.

### Jak używać

1. Otwórz pozycję (SIATKA WYŁ → BUY lub SELL)
2. Opcjonalnie: ustaw TP na pozycji (potrzebne do trybu Faron auto)
3. Rozwiń **▼ PIRAMID** i ustaw:
   - **% konta / stały lot** — tryb kalkulacji lota dokładki
   - **Ryz%** lub **Lot** — wartość ryzyka/lota
   - **Mx** — max dokładek (np. `3`)
   - **Stp** — krok w pipsach (`0` = Faron auto)
4. Kliknij **□ WYŁ** → zmienia się na **■ WŁ**

### Tryby kroku

| Stp w panelu | TP na pozycji | Efekt |
|---|---|---|
| `0` | ustawione | Faron auto: krok = `(TP−entry) ÷ PyramidDivisions` |
| `0` | brak | Stały krok: `PyramidPips` z parametrów EA |
| `>0` | dowolny | Override: krok = wartość pola Stp |

### Tryby lota dokładki

| Tryb (przycisk) | Pole | Działanie |
|---|---|---|
| **% konta** | Ryz% | `CalcLot(Ryz%, krokPips)` — automatyczna kalibracja |
| **stały lot** | Lot | Stały lot niezależnie od rozmiary konta |

> **Dokładka dziedziczy TP parenta** — broker widzi TP na każdej pozycji automatycznie.

---

## 8. ADD BUY / ADD SELL — ręczna dokładka

Jednorazowe dodanie pozycji do już otwartego trade'a — bez czekania na próg PIRA.

- **+ADD BUY** / **+ADD SELL** dostępne w rozwiniętej sekcji PIRAMID
- Lot liczony wg aktualnego trybu (% konta lub stały lot) i pola SL kalkulatora
- Po otwarciu EA przesuwa wszystkie pozycje grupy na wspólny SL = wejście poprzedniej (jeśli `PyramidMoveSL=true`)

---

## 9. Mechanizm wspólnego SL (Break-Even)

We wszystkich trybach (SIATKA, DOŁĄCZ, PIRA, ADD) działa **ta sama** logika:

> **Gdy nowa pozycja wchodzi → WSZYSTKIE pozycje grupy dostają SL = cena wejścia poprzedniej pozycji.**

Zasady:
- SL przesuwa się **tylko w kierunku zysku** — nigdy cofnięty
- Dla PIRA i ADD steruje tym `PyramidMoveSL = true/false` (domyślnie true)
- Dla SIATKI i DOŁĄCZ — zawsze aktywne

### Tabela ryzyka (N=4, 1% na pozycję)

| Zdarzenie | Wspólny SL | #1 | #2 | #3 | #4 | Net |
|---|---|---|---|---|---|---|
| #1 otwarta | techniczny SL | −1% | — | — | — | **−1%** |
| #2 wchodzi | entry #1 | 0% BE | −1% | — | — | **−1%** |
| #3 wchodzi | entry #2 | +1% | 0% BE | −1% | — | **0%** ← zero |
| #4 wchodzi | entry #3 | +2% | +1% | 0% BE | −1% | **+2%** ← gwarantowany zysk |
| TP trafiony | TP | +4% | +3% | +2% | +1% | **+10%** |

---

## 10. Matematyka Faron Mode

### Wynik przy pełnym TP

| N pozycji | Wzór | Zysk przy TP | Zero po |
|---|---|---|---|
| 3 | 3+2+1 | **6%** | pozycji #3 |
| **4** | **4+3+2+1** | **10%** | **pozycji #3** |
| 5 | 5+4+3+2+1 | **15%** | pozycji #3 |
| 6 | 6+5+4+3+2+1 | **21%** | pozycji #3 |

Wzór ogólny: `N × (N+1) / 2 %` przy ryzyku 1% per pozycja.
**Zawsze zero po 3. pozycji** — niezależnie od N.

### Zalecane konfiguracje

| Cel | Konfiguracja | R:R |
|---|---|---|
| Swing (wyraźny TP) | N=4, SL=50p, TP=120p, krok=30p | 1:10 |
| Konserwatywna | N=3, SL=30p, TP=60p, krok=20p | 1:6 |
| Agresywna | N=5, SL=40p, TP=100p, krok=20p | 1:15 |
| Złoto (XAUUSD) | N=4, SL=70p, TP=200p, krok=50p | 1:10 |

---

## 11. Virtual SL/TP — tryb stealth

Broker **nie widzi** Twoich poziomów SL i TP. EA zarządza nimi lokalnie i zamyka pozycję samodzielnie gdy cena dojdzie do wirtualnego poziomu.

### Zastosowanie

- Ochrona przed stop-huntingiem (broker nie zna Twojego SL)
- Brokerzy którzy "widują" SL i manipulują ceną tuż przed nim
- Konta prop firm gdzie chcesz ukryć strukturę zarządzania ryzykiem

### Jak włączyć

W parametrach EA (Inputs): `VirtualSLTP = true`

### Jak działa

```
VirtualSLTP = false (domyślnie):
  OrderSend → sl=rzeczywisty TP, tp=rzeczywisty TP
  → broker widzi poziomy, MT4 pokazuje linie SL/TP

VirtualSLTP = true:
  OrderSend → sl=0, tp=0
  → broker widzi "brak SL/TP"
  → EA co 2 sekundy sprawdza Bid/Ask vs zapisane poziomy
  → gdy cena osiągnie vSL lub vTP → EA zamyka market
```

### Ograniczenia

- Wirtualny SL **nie chroni przed slippage** przy gwałtownych ruchach (Flash Crash)
- Przy wyłączeniu EA lub awarii MT4 — pozycja nie ma rzeczywistego SL → **zawsze ustaw limity konta**
- Dotyczy tylko pozycji otwartych przez BUY/SELL i dokładek PIRA
- Grid (SIATKA, DOŁĄCZ) — używa realnych SL/TP (broker musi akceptować STOP orders z poziomami)

> **Zalecenie:** Jeśli używasz VirtualSLTP — zawsze miej ustawiony max dzienny drawdown po stronie brokera / prop firmy jako ostatnia linia obrony.

---

## 12. Minimalizacja panelu

Panel można złożyć do **paska tytułu** (28px) żeby nie zajmował miejsca na wykresie.

### Jak używać

- Klik **▼** w prawym górnym rogu paska tytułu → panel składa się
- Klik **▲** (w zminimalizowanym pasku) → panel przywraca pełny rozmiar
- **Wartości kalkulatora** (Ryzyko%, SL, TP, N itd.) są zachowane przy przywróceniu
- Stan minimalizacji przeżywa zmianę interwału (zapisany w GlobalVariables)

```
Panel pełny:                    Panel zminimalizowany:
┌──────────────────────────┐    ┌──────────────────────────┐
│ TraderLog  Journal    [▼] │    │ TraderLog  Journal    [▲] │
│ EA v2.1       ● Aktywny  │    └──────────────────────────┘
│ ... (cały panel) ...      │
└──────────────────────────┘
```

> **Gdy panel jest zminimalizowany** — wszystkie funkcje EA (zarządzanie SL, grid, piramida, virtual SL/TP) działają normalnie. Minimalizacja dotyczy tylko widoku.

---

## 13. Parametry EA

### Podstawowe (zakładka Inputs w MT4)

| Parametr | Domyślnie | Opis |
|---|---|---|
| `UserId` | `""` | **Wymagane** — User ID z traderlogjournal.com |
| `MagicNumber` | `202601` | Unikalny numer EA. Zmień jeśli masz kilka EA na tym samym koncie |
| `CheckEvery` | `2` | Timer w sekundach — jak często sprawdzane są SL/piramidy/virtual levels |
| `DefaultRiskPct` | `1.0` | Domyślne ryzyko % w kalkulatorze przy starcie |
| `DefaultSLPips` | `20.0` | Domyślny SL w kalkulatorze przy starcie |
| `Sync_History_Days` | `0` | Sync historii do dziennika (0 = wyłączone) |
| `VirtualSLTP` | `false` | Ukryj SL/TP przed brokerem (stealth mode) |

### Piramidowanie

| Parametr | Domyślnie | Opis |
|---|---|---|
| `AutoPyramid` | `false` | PIRA startuje włączone przy każdym uruchomieniu |
| `PyramidDivisions` | `4` | Faron auto: dzieli Entry→TP na N kroków |
| `PyramidMaxLevels` | `2` | Domyślny Mx w panelu |
| `PyramidRiskPct` | `0.5` | Domyślne Ryz% w panelu |
| `PyramidMoveSL` | `true` | Wspólny SL po każdej dokładce |
| `PyramidPips` | `20.0` | Krok gdy Stp=0 i brak TP |

### Stały stan (przeżywa zmianę interwału)

EA zapisuje w GlobalVariables MT4 stan: włączone PIRA, SIATKA, tryb %, pauza, minimalizacja panelu, wartości kalkulatora. Zmiana interwału (M1→H1) nie resetuje ustawień.

---

## 14. Wskaźniki — czy zakłócają EA?

### Krótka odpowiedź: standardowe wskaźniki NIE zakłócają EA.

| Co robi EA | Co robi wskaźnik | Konflikt? |
|---|---|---|
| Tworzy obiekty z prefiksem `TLJ_` | Tworzy własne obiekty (inne nazwy) | ❌ Brak |
| Obsługuje `OnChartEvent` | Może mieć własny `OnChartEvent` | ⚠️ Patrz niżej |
| Używa `GlobalVariables` z prefiksem `TLJ_<nr_konta>_` | Zwykle nie używa GV | ❌ Brak |

### Zalecane wskaźniki (bezproblemowe)

- Wszystkie wbudowane MT4: MA, RSI, MACD, Bollinger, ATR, Stochastic
- `SMC_Complete.mq4` — rysuje BOS/CHoCH/OB/FVG, brak OnChartEvent → **bezproblemowy**
- `IOFlow_StrengthClassifier.mq4` — panel sił walut, własne przyciski

### Jedyna możliwa kolizja: OnChartEvent

Jeśli wskaźnik używa `OnChartEvent` i nasłuchuje `CHARTEVENT_OBJECT_CLICK`, może przechwycić kliknięcie w przycisk EA. Praktyczne ryzyko: minimalne.

**Jeśli problem wystąpi:** załaduj wskaźniki na osobny wykres.

---

## 15. FTMO — zasady i zgodność

### EA jest kompatybilny z FTMO.

| Reguła FTMO | Jak EA się zachowuje | Wynik |
|---|---|---|
| Max dzienny drawdown | EA nie ogranicza automatycznie — Twoja odpowiedzialność | ⚠️ Patrz niżej |
| Zakaz martingale | Piramidowanie ODWROTNE — dokładamy W KIERUNKU zysku | ✅ OK |
| Zakaz hedgingu | EA nie hedguje | ✅ OK |
| Zakaz kopiowania sygnałów | EA tylko loguje do dziennika | ✅ OK |
| EAs dozwolone | FTMO jawnie zezwala na EA | ✅ OK |

### Kluczowe zasady

```
Worst case siatka: SL trafiony po #1 → strata = 1%
Worst case siatka: SL trafiony po #2 → strata = 1% (BE na #1)
Nigdy więcej niż 1% na jedną siatkę (dzięki wspólnemu SL)
```

Ustaw ryzyko ≤ 1–2% per pozycję i będziesz bezpieczny przy FTMO 5%/10% limitach.

> **Virtual SL/TP a FTMO:** Używanie stealth mode nie łamie zasad FTMO — EA zarządza ryzykiem lokalnie. Upewnij się jednak że zawsze masz ustawiony equity stop po stronie FTMO jako zabezpieczenie.

---

## 16. Ważne zasady i pułapki

| Zasada | Szczegóły |
|---|---|
| **N musi być 2–10** | Przy N=1 nie ma siatki — użyj zwykłego BUY/SELL |
| **TP w kalkulatorze dla GRID** | GRID BUY/SELL wymaga TP > 0 w polu TP |
| **DOŁĄCZ nie potrzebuje TP w kalkulatorze** | EA czyta TP z pozycji; fallback: pole TP |
| **DOŁĄCZ liczy od liveAsk, nie basePrice** | STOP-y zawsze powyżej aktualnej ceny — nie "za ceną" |
| **Krok musi być > stop level brokera** | Jeśli krok < stop level → Alert i brak siatki; zwiększ TP lub zmniejsz N |
| **PIRA nie dotyka GRID** | CheckAutoPyramid ignoruje TLJ_GRID_* — brak podwójnego piramidowania |
| **Zmiana interwału = brak resetu** | Stan przeżywa zmianę interwału dzięki GlobalVariables |
| **Jeden EA na jeden wykres** | Dwa EA z tym samym MagicNumber na dwóch wykresach mogą wzajemnie kasować swoje pendingsy |
| **Komentarze zleceń** | SIATKA: `TLJ_GRID_1of4`; PIRA: `TLJ_PYR_<ticket>_L1`; ADD: `TLJ Panel+` |
| **Zakładka Experts** | Każda akcja EA jest logowana z detalami — sprawdź tam gdy coś nie działa |
| **VirtualSLTP + crash MT4** | Przy awarii terminala pozycja bez SL zostaje otwarta — zawsze miej backup limit po stronie brokera |
| **Hard refresh po deploy** | Usuń stary .ex4, skopiuj nowy .mq4, skompiluj F7, wczytaj na wykres |
