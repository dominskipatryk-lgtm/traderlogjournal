# TraderLogJournal EA v2 — Instrukcja: Piramidowanie i Siatka Zleceń

---

## Spis treści

1. [Co to jest Faron Mode](#1-co-to-jest-faron-mode)
2. [Panel EA — przegląd](#2-panel-ea--przegląd)
3. [Kalkulator pozycji](#3-kalkulator-pozycji)
4. [SIATKA — ręczne ustawienie piramidy z góry](#4-siatka--ręczne-ustawienie-piramidy-z-góry)
5. [PIRA — automatyczne piramidowanie](#5-pira--automatyczne-piramidowanie)
6. [ADD BUY / ADD SELL — ręczna dokładka](#6-add-buy--add-sell--ręczna-dokładka)
7. [Mechanizm Break-Even (auto SL)](#7-mechanizm-break-even-auto-sl)
8. [Parametry EA — sekcja Piramidowanie](#8-parametry-ea--sekcja-piramidowanie)
9. [Porównanie: SIATKA vs PIRA](#9-porównanie-siatka-vs-pira)
10. [Przykłady konfiguracji](#10-przykłady-konfiguracji)
11. [Ważne zasady i pułapki](#11-ważne-zasady-i-pułapki)

---

## 1. Co to jest Faron Mode

Strategia piramidowania zysków — otwierasz pierwszą pozycję, a następnie dokładasz kolejne **w kierunku zysku** (nie na retrace). Przestrzeń od wejścia do TP dzielisz na równe części i przy każdym kolejnym przedziale otwierasz nową pozycję. SL poprzedniej przesuwa się na break-even.

**Mechanika zarządzania ryzykiem:**

| Stan | Ryzyko łączne |
|---|---|
| 1 pozycja otwarta | 1% |
| 2 pozycja otwarta → SL #1 na BE | nadal 1% |
| 3 pozycja otwarta → SL #2 na BE | 0% (handlujesz "za darmo") |
| 4 pozycja otwarta → SL #3 na BE | jesteś na zysku niezależnie od wyniku |

**Przykład SELL, entry 1.3000, TP 1.2700, N=4 (krok = 75 pips):**

```
Otwarcie:  SELL #1  @ 1.3000  SL 1.3050  TP 1.2700
+75 pips:  SELL #2  @ 1.2925  SL 1.2925+krok  → SL #1 przesuwa się na 1.3000 (BE)
+150 pips: SELL #3  @ 1.2850  SL 1.2850+krok  → SL #2 przesuwa się na 1.2925 (BE)
+225 pips: SELL #4  @ 1.2775  SL 1.2775+krok  → SL #3 przesuwa się na 1.2850 (BE)
+300 pips: TARGET — wszystkie pozycje zamknięte na TP 1.2700
```

**Wynik przy pełnej piramidzie (ryzykujesz 1%):**

| Pozycja | Zysk |
|---|---|
| #1 (300 pips) | ~2% |
| #2 (225 pips) | ~3% |
| #3 (150 pips) | ~2% |
| #4 (75 pips) | ~1% |
| **Łącznie** | **~8% przy ryzyku 1%** → R:R 1:8 |

---

## 2. Panel EA — przegląd

```
┌──────────────────────────────────────┐
│ TraderLog  Journal          EA v2.0  │
│                           ● Aktywny  │
│ ──────────────────────────────────── │
│ KONTO        #12345678               │
│ EQUITY       $10 250.00              │
│ P&L OTWR.    +$45.20                 │
│ OTWARTE      2 pozycje               │
│ WYSŁANO      14 syg.                 │
│ ──────────────────────────────────── │
│ KALKULATOR POZYCJI                   │
│ Ryzyko %   [1.0 ]                    │
│ SL (pips)  [30.0]                    │
│ TP (pips)  [150.0]                   │
│ Lot: 0.05  R:R 1:5.0     [Oblicz]   │
│ ──────────────────────────────────── │
│ ◆ SIATKA (Faron Mode)                │
│ N: [4]  [     SIATKA:WYŁ          ] │
│ ──────────────────────────────────── │
│ [     BUY      ]  [     SELL      ] │
│ ──────────────────────────────────── │
│ ◆ PIRAMIDOWANIE (auto)               │
│ [+ADD BUY][+ADD SELL] Mx:[2] [PIRA] │
│ ──────────────────────────────────── │
│ [Close ALL][Close BUY][Close SELL]   │
│ ──────────────────────────────────── │
│ [⏸  Pauza]        [⏹  Stop EA]     │
│ traderlogjournal.com                 │
└──────────────────────────────────────┘
```

**Jak działają przyciski BUY / SELL:**
- Gdy `SIATKA:WYŁ` → klik BUY/SELL otwiera **pojedynczą pozycję** market (standardowe zachowanie)
- Gdy `SIATKA:WŁ` → przyciski zmieniają się na `GRID BUY` / `GRID SELL` → klik stawia całą siatkę STOP orders

---

## 3. Kalkulator pozycji

Przed każdą transakcją wypełnij trzy pola i kliknij **Oblicz**:

| Pole | Co wpisać | Przykład |
|---|---|---|
| **Ryzyko %** | Procent kapitału który ryzykujesz na całą transakcję | `1.0` |
| **SL (pips)** | Odległość stop lossa od wejścia w pipsach | `30.0` |
| **TP (pips)** | Odległość take profitu od wejścia w pipsach | `150.0` |

Po kliknięciu **Oblicz** pojawia się:
- **Lot** — wyliczony rozmiar pozycji
- **R:R** — stosunek ryzyko do zysku (np. `R:R 1:5.0`)

> TP wpisany tutaj jest wspólny dla kalkulatora i siatki zleceń — nie trzeba go wpisywać dwa razy.

---

## 4. SIATKA — ręczne ustawienie piramidy z góry

Siatka stawia **wszystkie zlecenia naraz** jako pending STOP orders — widzisz je od razu w zakładce Trade MT4. Wypełniają się automatycznie gdy cena idzie w Twoim kierunku.

### Jak używać

1. Wypełnij kalkulator: **Ryzyko%**, **SL**, **TP** → kliknij **Oblicz**
2. Wpisz **N** — ile pozycji chcesz w piramidzie (np. `4`)
3. Kliknij **SIATKA:WYŁ** → przycisk zmienia się na **SIATKA:WŁ Np** (zielony), przyciski BUY/SELL zmieniają się na **GRID BUY** / **GRID SELL**
4. Kliknij **GRID BUY** (dla pozycji długiej) lub **GRID SELL** (dla krótkiej)

EA automatycznie oblicza **krok = TP ÷ N** i stawia zlecenia.

### Co EA robi po kliknięciu GRID▲ (BUY, N=4, SL=30, TP=120)

```
Krok = 120 ÷ 4 = 30 pips

Zlecenie 1: BUY market    @ Ask        SL = Ask−30p   TP = Ask+120p
Zlecenie 2: BUY STOP      @ Ask+30p    SL = Ask−30p   TP = Ask+120p
Zlecenie 3: BUY STOP      @ Ask+60p    SL = Ask−30p   TP = Ask+120p
Zlecenie 4: BUY STOP      @ Ask+90p    SL = Ask−30p   TP = Ask+120p
```

- Wszystkie zlecenia mają **ten sam TP** (stały poziom cenowy)
- Wszystkie zlecenia mają **ten sam SL** (stały poziom cenowy)
- Lot na każde zlecenie = lot_całkowity ÷ N

### Automatyczne przesunięcie SL na BE

Gdy każdy STOP się wypełni, EA automatycznie przesuwa SL poprzedniego zlecenia na jego cenę wejścia (break-even):

```
Zlecenie 2 wypełnione → SL zlecenia 1 przesuwa się na Ask (BE)
Zlecenie 3 wypełnione → SL zlecenia 2 przesuwa się na Ask+30p (BE)
Zlecenie 4 wypełnione → SL zlecenia 3 przesuwa się na Ask+60p (BE)
```

### Anulowanie siatki

Usuń ręcznie wybrane lub wszystkie pending orders w zakładce Trade MT4, albo użyj przycisku **Close ALL**.

---

## 5. PIRA — automatyczne piramidowanie

PIRA to tryb gdzie EA **sam obserwuje zysk** otwartych pozycji i dokłada kolejne bez Twojej interwencji — market orders po aktualnej cenie gdy zysk osiągnie próg.

### Jak używać

1. Wypełnij kalkulator i otwórz pozycję przyciskiem **BUY** lub **SELL** (SIATKA musi być WYŁ)
2. **Ustaw TP na pozycji** (w MT4 lub przy otwieraniu) — bez TP Faron Mode nie działa
3. Opcjonalnie zmień pole **Mx** — maksymalna liczba dokładek (domyślnie wartość z parametrów EA)
4. Kliknij **PIRA** → zmienia się na **PIRA:WŁ 0x** (zielony)
5. EA co `CheckEvery` sekund sprawdza zysk każdej pozycji i dokłada automatycznie
6. Kliknij ponownie żeby wyłączyć

### Kiedy EA dokłada (Faron Mode — PyramidDivisions ≥ 2)

```
Krok = (TP − entry) ÷ PyramidDivisions

Dokładka L1 gdy zysk ≥ 1 × krok
Dokładka L2 gdy zysk ≥ 2 × krok
...do PyramidMaxLevels dokładek
```

### Kiedy EA dokłada (tryb stały — PyramidDivisions = 0)

```
Dokładka gdy zysk ≥ PyramidPips (np. co 20 pips zysku)
```

### Co widać w panelu gdy PIRA jest włączona

```
[PIRA:WŁ 2x]   ← zielony, 2 aktywne dokładki
```

---

## 6. ADD BUY / ADD SELL — ręczna dokładka

Jednorazowe dodanie pozycji do już otwartego trade'a — bez czekania na próg.

| Przycisk | Działanie |
|---|---|
| **+ADD BUY** | Otwiera market BUY z ryzykiem `PyramidRiskPct` i SL z pola kalkulatora. Jeśli `PyramidMoveSL=true` → SL ostatniej pozycji BUY przesuwa się na BE |
| **+ADD SELL** | Jak wyżej, dla SELL |

> Przydatne gdy widzisz silny momentum i chcesz ręcznie zdecydować o dokładce zamiast czekać na automatyczny próg.

---

## 7. Mechanizm Break-Even (auto SL)

We wszystkich trzech trybach (SIATKA, PIRA, ADD) działa ten sam mechanizm:

**Gdy nowa pozycja zostaje otwarta/wypełniona → SL poprzedniej pozycji automatycznie przesuwa się na jej cenę wejścia.**

Zasady:
- SL przesuwa się **tylko do przodu** — nigdy w złą stronę
- Jeśli SL poprzedniej pozycji jest już na BE lub lepiej → nie zmienia się
- Dla PIRA steruje tym parametr `PyramidMoveSL = true/false`
- Dla SIATKI i ADD — zawsze aktywne

---

## 8. Parametry EA — sekcja Piramidowanie

Ustawiasz je raz w parametrach EA (dwuklik na EA → Inputs):

| Parametr | Domyślnie | Opis |
|---|---|---|
| `AutoPyramid` | `false` | Czy PIRA startuje włączone przy każdym uruchomieniu EA |
| `PyramidDivisions` | `4` | Faron Mode: dzieli Entry→TP na N równych części. `0` = tryb stały pipsów |
| `PyramidMaxLevels` | `2` | Maksymalna liczba dokładek PIRA na jedną pozycję |
| `PyramidRiskPct` | `0.5` | Ryzyko % każdej dokładki PIRA i ADD. `0` = pobiera z pola Ryzyko % |
| `PyramidMoveSL` | `true` | Czy przesuwać SL poprzedniej pozycji na BE po każdej dokładce |
| `PyramidPips` | `20.0` | Próg dokładki gdy `PyramidDivisions=0` lub brak TP na pozycji |

---

## 9. Porównanie: SIATKA vs PIRA

| | SIATKA (GRID) | PIRA (auto) |
|---|---|---|
| **Kiedy wejścia** | Od razu — wszystkie pending orders widoczne w MT4 | Stopniowo — EA otwiera market gdy zysk osiągnie próg |
| **Typ zleceń** | BUY STOP / SELL STOP (pending) | Market (natychmiastowe) |
| **Kontrola** | Pełna — widzisz wszystko z góry, możesz usunąć | Automatyczna — EA decyduje sam |
| **Wymaga TP na pozycji** | Nie (TP wpisujesz w kalkulatorze) | Tak (Faron Mode) lub nie (tryb stały pipsów) |
| **Włączanie** | Kliknij SIATKA:WYŁ → WŁ, potem GRID BUY/SELL | Kliknij PIRA → WŁ (po otwarciu pozycji) |
| **Anulowanie** | Usuń pending orders; kliknij SIATKA:WŁ → WYŁ | Kliknij PIRA:WŁ żeby wyłączyć |
| **Najlepsze gdy** | Pewny setup, chcesz mieć gotowy plan | Nie wiesz jak daleko pójdzie ruch, wolisz reagować |

---

## 10. Przykłady konfiguracji

### SIATKA — klasyczny Faron 1:8

```
Kalkulator:  Ryzyko% = 1.0 | SL = 50 pips | TP = 200 pips
Siatka N:    4
Krok (auto): 200 ÷ 4 = 50 pips

Wynik przy pełnej piramidzie:
  Pozycja 1 (200 pips do TP): ~2%
  Pozycja 2 (150 pips do TP): ~1.5%
  Pozycja 3 (100 pips do TP): ~1%
  Pozycja 4 (50 pips do TP):  ~0.5%
  Łącznie: ~5% przy ryzyku 1%
```

### PIRA — agresywna (3 dokładki)

```
PyramidDivisions  = 4
PyramidMaxLevels  = 3
PyramidRiskPct    = 1.0
PyramidMoveSL     = true
```

### PIRA — konserwatywna (1 dokładka)

```
PyramidDivisions  = 3
PyramidMaxLevels  = 1
PyramidRiskPct    = 0.5
PyramidMoveSL     = true
```

### PIRA — bez TP (stały krok pipsów)

```
PyramidDivisions  = 0
PyramidPips       = 30.0
PyramidMaxLevels  = 2
PyramidRiskPct    = 0.5
```
Dokładka co 30 pipsów zysku, niezależnie od poziomu TP.

---

## 11. Ważne zasady i pułapki

- **SIATKA wymaga TP w kalkulatorze** — pole TP (pips) musi być wypełnione przed kliknięciem GRID
- **PIRA Faron Mode wymaga TP na pozycji** — ustaw TP bezpośrednio na zleceniu w MT4. Jeśli brak TP → EA fallback na `PyramidPips`
- **EA piramiduje tylko własne pozycje** z ustawionym `MagicNumber` — nie dotyka zleceń otwartych ręcznie z MT4 (chyba że `MagicNumber = 0`)
- **Komentarze zleceń w MT4:**
  - SIATKA: `TLJ_GRID_1of4`, `TLJ_GRID_2of4`...
  - PIRA: `TLJ_PYR_<ticket>_L1`, `TLJ_PYR_<ticket>_L2`...
- **Po restarcie EA** — PIRA odczytuje stan z komentarzy otwartych pozycji, nie traci historii dokładek
- **Przycisk PIRA** resetuje się do wartości `AutoPyramid` z parametrów. Jeśli chcesz żeby startował włączony → ustaw `AutoPyramid = true`
- **N w siatce musi być 2–10** — minimum 2 (przynajmniej jedno zlecenie pending)
- **Zakładka Experts w MT4** loguje każdą dokładkę: poziom, ticket parenta, lot, zysk w pipsach w momencie wejścia
