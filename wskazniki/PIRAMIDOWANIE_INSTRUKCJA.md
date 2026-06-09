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

Strategia piramidowania zysków — otwierasz pierwszą pozycję, a następnie dokładasz kolejne **w kierunku zysku** (nie na retrace). Przestrzeń od wejścia do TP dzielisz na N równych kroków. Każda pozycja ryzykuje **1% konta** (lot liczony od kroku). Gdy kolejna pozycja wchodzi — **wszystkie** dotychczasowe SL przesuwają się na wspólny poziom = cena wejścia poprzedniej pozycji.

### Jak działają stop lossy (wspólny poziom)

Przykład SELL, N=4, krok=30 pip (TP=120 pip), każda pozycja ryzykuje 1%:

```
SELL #1 @ 1.1000  SL=1.1060 (techniczny)   TP=1.0880
SELL #2 @ 1.0970  SL=1.1000 (= entry#1)    TP=1.0880
SELL #3 @ 1.0940  SL=1.0970 (= entry#2)    TP=1.0880
SELL #4 @ 1.0910  SL=1.0940 (= entry#3)    TP=1.0880
```

Gdy każda kolejna pozycja zostaje wypełniona → **WSZYSTKIE SL przesuwają się razem**:

| Zdarzenie | Wspólny SL | #1 | #2 | #3 | #4 | Net |
|---|---|---|---|---|---|---|
| Start — #1 otwarta | 1.1060 | −1% | — | — | — | **−1%** |
| #2 wchodzi | 1.1000 | 0% (BE) | −1% | — | — | **−1%** |
| #3 wchodzi | 1.0970 | +1% | 0% (BE) | −1% | — | **0%** ← zero |
| #4 wchodzi | 1.0940 | +2% | +1% | 0% (BE) | −1% | **+2%** ← gwarantowany zysk |

> **Zero po 3. pozycji** — od tego momentu nawet trafienie SL daje zysk netto ≥ 0%.

### Wynik przy pełnym TP (N=4, krok = 1 jednostka ryzyka)

Każda pozycja zarabia tyle kroków do TP ile ma przed sobą:

| Pozycja | Kroki do TP | Zysk |
|---|---|---|
| #1 | 4 kroki | **4%** |
| #2 | 3 kroki | **3%** |
| #3 | 2 kroki | **2%** |
| #4 | 1 krok | **1%** |
| **Łącznie** | | **10% przy ryzyku 1%** → R:R **1:10** |

### Porównanie — ile pozycji warto ustawić?

| N pozycji | Zysk przy TP | Zero po | Wzór |
|---|---|---|---|
| 3 | **6%** | #3 | 3+2+1 |
| **4** | **10%** | **#3** | **4+3+2+1** |
| 5 | **15%** | #3 | 5+4+3+2+1 |
| 6 | **21%** | #3 | 6+5+4+3+2+1 |

> Wzór ogólny: `N × (N+1) / 2 %` przy ryzyku 1% na pozycję.
> Bez względu na N — **zawsze jesteś na zero po 3. pozycji**.

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

### Co EA robi po kliknięciu GRID BUY (N=4, SL=50, TP=120)

```
Krok = 120 ÷ 4 = 30 pips
Lot  = CalcLot(Ryzyko%, 30 pip)  ← jednakowy dla wszystkich

Zlecenie 1: BUY market  @ Ask       SL = Ask−50p        TP = Ask+120p
Zlecenie 2: BUY STOP    @ Ask+30p   SL = Ask (=entry#1)  TP = Ask+120p
Zlecenie 3: BUY STOP    @ Ask+60p   SL = Ask+30p (=entry#2) TP = Ask+120p
Zlecenie 4: BUY STOP    @ Ask+90p   SL = Ask+60p (=entry#3) TP = Ask+120p
```

- Wszystkie zlecenia mają **ten sam TP** i **jednakowy lot** (liczony od kroku)
- Każde zlecenie #2+ ma SL ustawiony na wejście poprzedniego (1 krok niżej)
- Zlecenie #1 ma **techniczny SL** z pola kalkulatora (może być szerszy niż krok)

### Automatyczne przesunięcie wspólnego SL

Gdy każdy STOP się wypełni, EA przesuwa **wszystkie** otwarte pozycje siatki na ten sam wspólny poziom = cena wejścia poprzedniej pozycji:

```
Zlecenie 2 wypełnione → WSZYSTKIE SL → Ask       (= entry#1, BE dla #1)
Zlecenie 3 wypełnione → WSZYSTKIE SL → Ask+30p   (= entry#2, BE dla #2, +1krok dla #1)
Zlecenie 4 wypełnione → WSZYSTKIE SL → Ask+60p   (= entry#3, BE dla #3, zysk dla #1,#2)
```

### Anulowanie siatki

Usuń ręcznie wybrane lub wszystkie pending orders w zakładce Trade MT4, albo użyj przycisku **Close ALL**.

---

## 5. PIRA — automatyczne piramidowanie

PIRA to tryb gdzie EA **sam obserwuje zysk** otwartych pozycji i dokłada kolejne bez Twojej interwencji — market orders po aktualnej cenie gdy zysk osiągnie próg.

### Jak używać

1. Wypełnij kalkulator i otwórz pozycję przyciskiem **BUY** lub **SELL** (SIATKA musi być WYŁ)
2. Opcjonalnie ustaw **TP na pozycji** (potrzebne do trybu Faron auto)
3. Ustaw pola w panelu: **Mx** (max dokładek) i **Stp** (krok w pips, `0` = auto)
4. Kliknij **PIRA** → zmienia się na **PIRA:WŁ 0x** (zielony)
5. EA co kilka sekund sprawdza zysk każdej pozycji i dokłada automatycznie
6. Kliknij ponownie żeby wyłączyć

### Trzy tryby pracy — jak ustalany jest krok dokładki

| Tryb | Kiedy | Krok |
|---|---|---|
| **Faron auto** | `Stp=0` + TP na pozycji + `PyramidDivisions≥2` | `(TP − entry) ÷ PyramidDivisions` |
| **Stały pips** | `Stp=0` + brak TP lub `PyramidDivisions=0` | `PyramidPips` z parametrów EA |
| **Panel (override)** | `Stp > 0` (pole w panelu) | wartość z pola `Stp` — nadpisuje oba tryby |

```
Przykład: TP=120p, entry=1.1000, PyramidDivisions=4, Stp=0
  Krok auto = 120÷4 = 30 pips
  Dokładka L1 gdy zysk ≥ 30 pips
  Dokładka L2 gdy zysk ≥ 60 pips

Przykład: Stp=20 (panel override, niezależnie od TP i parametrów)
  Dokładka L1 gdy zysk ≥ 20 pips
  Dokładka L2 gdy zysk ≥ 40 pips
```

### Kiedy używać którego trybu

| Sytuacja | Tryb | Dlaczego |
|---|---|---|
| Masz wyraźny TP (S/R, struktura) | **Faron auto** | Krok = naturalny podział trasy, nie wchodzisz za blisko TP |
| Nie wiesz dokąd pójdzie, grasz momentum | **Stały pips** lub **Panel** | Nie potrzebujesz TP — dokładasz co X pips zysku |
| Chcesz szybko zmienić krok bez restartu EA | **Panel (Stp)** | Jedna cyfra w panelu, bez wchodzenia w parametry |
| Skalpowanie / szybkie ruchy (10–20 pip) | **Panel Stp=10** lub **Stały PyramidPips=10** | Mały krok, szybkie zabezpieczenie |

### Mechanizm wspólnego SL (PyramidMoveSL = true)

Gdy każda kolejna dokładka się otwiera, EA przesuwa **wszystkie** pozycje tej grupy (parent + wszystkie Ln) na wspólny SL = wejście poprzedniej pozycji:

| Zdarzenie | Wspólny SL | #1 (parent) | L1 | L2 | Net w worst case |
|---|---|---|---|---|---|
| Otwarto #1 | techniczny SL | −1% | — | — | **−1%** |
| L1 otwarta (+1 krok) | entry #1 | 0% (BE) | −1% | — | **−1%** |
| L2 otwarta (+2 kroki) | entry L1 | +1% | 0% (BE) | −1% | **0%** ← zero |
| L3 otwarta (+3 kroki) | entry L2 | +2% | +1% | 0% (BE) | **+2%** |

> **Zero po L2** — po drugiej dokładce (trzecia pozycja w grupie) nawet trafienie SL daje wynik netto ≥ 0%. Działa w każdym z trzech trybów.

**Gdy SL zostaje trafiony:** MT4 zamyka automatycznie wszystkie pozycje grupy na tym samym poziomie cenowym (mają wspólny SL price). PIRA toggle pozostaje włączony — gdy otworzysz nową pozycję, EA zaczyna piramidować od nowa.

### Co widać w panelu

```
Mx:[2]  [PIRA:WŁ 2x]
Krok PIRA pips (0=auto): [20.0]
```

---

## 6. ADD BUY / ADD SELL — ręczna dokładka

Jednorazowe dodanie pozycji do już otwartego trade'a — bez czekania na próg.

| Przycisk | Działanie |
|---|---|
| **+ADD BUY** | Otwiera market BUY z ryzykiem `PyramidRiskPct` i SL z pola kalkulatora |
| **+ADD SELL** | Jak wyżej, dla SELL |

Jeśli `PyramidMoveSL=true` (domyślnie) → po otwarciu EA przesuwa **wszystkie** otwarte pozycje tego kierunku na wspólny SL = wejście poprzedniej pozycji. Identyczna mechanika jak SIATKA i PIRA.

> Przydatne gdy widzisz silny momentum i chcesz ręcznie zdecydować o dokładce zamiast czekać na automatyczny próg.

---

## 7. Mechanizm wspólnego SL (auto)

We wszystkich trzech trybach (SIATKA, PIRA, ADD) działa **ta sama** logika:

**Gdy nowa pozycja zostaje otwarta/wypełniona → WSZYSTKIE pozycje z grupy przesuwają SL na ten sam wspólny poziom = cena wejścia poprzedniej pozycji.**

Zasady:
- Wspólny SL przesuwa się **tylko w kierunku zysku** — nigdy w złą stronę
- Wszystkie pozycje grupy mają **ten sam SL** po każdym przesunięciu
- Dla PIRA i ADD steruje tym parametr `PyramidMoveSL = true/false`
- Dla SIATKI — zawsze aktywne
- Gwarantuje **zero strat po 3. pozycji** (gdy każda pozycja ryzykuje 1 krok)

---

## 8. Parametry EA i pola panelu — PIRA

### Pola panelu (zmieniane na żywo, bez restartu EA)

| Pole | Opis |
|---|---|
| **Mx** | Maksymalna liczba dokładek per pozycja (domyślnie = `PyramidMaxLevels`) |
| **Stp** (Krok PIRA pips) | `0` = tryb auto (Faron lub stały pips). `>0` = stały krok override — EA dokłada co tyle pipsów zysku, niezależnie od TP i parametrów |

### Parametry EA (wymagają restartu — dwuklik na EA → Inputs)

| Parametr | Domyślnie | Opis |
|---|---|---|
| `AutoPyramid` | `false` | Czy PIRA startuje włączone przy każdym uruchomieniu EA |
| `PyramidDivisions` | `4` | Faron Mode: dzieli Entry→TP na N równych części. `0` = tryb stały pipsów |
| `PyramidMaxLevels` | `2` | Domyślny max dokładek (można zmienić polem Mx bez restartu) |
| `PyramidRiskPct` | `0.5` | Ryzyko % każdej dokładki PIRA i ADD. `0` = pobiera z pola Ryzyko % |
| `PyramidMoveSL` | `true` | Wspólny SL po każdej dokładce (`true` = zalecane) |
| `PyramidPips` | `20.0` | Krok gdy `Stp=0` i `PyramidDivisions=0` lub brak TP. Domyślna wartość pola Stp przy starcie |

---

## 9. Porównanie: SIATKA vs PIRA

| | SIATKA (GRID) | PIRA (auto) |
|---|---|---|
| **Kiedy wejścia** | Od razu — wszystkie pending orders widoczne w MT4 | Stopniowo — EA otwiera market gdy zysk osiągnie próg |
| **Typ zleceń** | BUY STOP / SELL STOP (pending) | Market (natychmiastowe) |
| **Kontrola** | Pełna — widzisz wszystko z góry, możesz usunąć | Automatyczna — EA decyduje sam |
| **Lot** | Równy dla wszystkich = `CalcLot(1%, krok)` | Parent = `CalcLot(Ryzyko%, SL)`, dokładki = `CalcLot(PyrRisk%, krok)` |
| **Wymaga TP na pozycji** | Nie (TP wpisujesz w kalkulatorze) | Tak (Faron Mode) lub nie (tryb stały pipsów) |
| **Włączanie** | Kliknij SIATKA:WYŁ → WŁ, potem GRID BUY/SELL | Kliknij PIRA → WŁ (po otwarciu pozycji) |
| **Anulowanie** | Usuń pending orders; kliknij SIATKA:WŁ → WYŁ | Kliknij PIRA:WŁ żeby wyłączyć |
| **Najlepsze gdy** | Wiesz dokąd idzie rynek, chcesz plan z góry | Nie wiesz jak daleko pójdzie ruch, wolisz reagować |

### Mechanika SL — identyczna w obu trybach

**Różnica jest tylko w sposobie wejścia. Matematyka ryzyka jest taka sama:**

| Zdarzenie | Wspólny SL | Poz. 1 | Poz. 2 | Poz. 3 | Net |
|---|---|---|---|---|---|
| Otwarto poz. 1 | techniczny SL | −1% | — | — | **−1%** |
| Poz. 2 otwarta (+1 krok) | entry poz. 1 | 0% BE | −1% | — | **−1%** |
| Poz. 3 otwarta (+2 kroki) | entry poz. 2 | +1% | 0% BE | −1% | **0%** ← zero |
| Poz. 4 otwarta (+3 kroki) | entry poz. 3 | +2% | +1% | 0% BE | **+2%** |

> **Po 3. pozycji zawsze jesteś na zero** — niezależnie czy używasz SIATKI, PIRY czy ADD.

---

## 10. Przykłady konfiguracji

### SIATKA — klasyczny Faron 1:10

```
Kalkulator:  Ryzyko% = 1.0 | SL = 50 pips | TP = 120 pips
Siatka N:    4
Krok (auto): 120 ÷ 4 = 30 pips
Lot (auto):  CalcLot(1%, 30 pip) — jednakowy dla wszystkich

Wynik przy pełnym TP:
  Pozycja 1 (4 kroki = 120 pip): 4%
  Pozycja 2 (3 kroki =  90 pip): 3%
  Pozycja 3 (2 kroki =  60 pip): 2%
  Pozycja 4 (1 krok  =  30 pip): 1%
  Łącznie: 10% przy ryzyku 1% → R:R 1:10

Zarządzanie ryzykiem:
  Po #3: net = 0% (nawet jeśli SL — wychodzisz na zero)
  Po #4: net = +2% gwarantowane przy trafieniu SL
```

### PIRA tryb 1 — Faron auto z TP (zalecany dla swing trade)

```
Kalkulator:       Ryzyko% = 1.0 | SL = 40 pips | TP = 120 pips
Parametry EA:     PyramidDivisions=4, PyramidRiskPct=1.0, PyramidMoveSL=true
Panel:            Mx=3, Stp=0 (auto)

Krok auto = 120÷4 = 30 pips
Lot każdej dokładki = CalcLot(1%, 30 pip)

L1 otwarta po +30 pip zysku  → wspólny SL → entry#1 (BE)  | net: -1%
L2 otwarta po +60 pip zysku  → wspólny SL → entry L1      | net:  0%  ← zero
L3 otwarta po +90 pip zysku  → wspólny SL → entry L2      | net: +2%  ← gwarantowany zysk

Przy pełnym TP (120 pip): parent≈4% + L1≈3% + L2≈2% + L3≈1% = 10%
```

### PIRA tryb 2 — panel override bez TP (momentum / bez planu)

```
Kalkulator:       Ryzyko% = 1.0 | SL = 40 pips
Panel:            Mx=3, Stp=20 (override — dokładka co 20 pips)
(TP nie wymagany — EA używa Stp zamiast TP/N)

L1 otwarta po +20 pip zysku  → wspólny SL → entry#1 | net: -1%
L2 otwarta po +40 pip zysku  → wspólny SL → entry L1 | net:  0%  ← zero
L3 otwarta po +60 pip zysku  → wspólny SL → entry L2 | net: +2%

Gdy SL zostanie trafiony → MT4 zamyka wszystkie pozycje grupy automatycznie.
```

### PIRA tryb 3 — konserwatywna (1 dokładka, niskie ryzyko)

```
Parametry EA:     PyramidDivisions=4, PyramidRiskPct=0.5, PyramidMaxLevels=1
Panel:            Mx=1, Stp=0 (auto)

Jedna dokładka L1 co 1 krok zysku, ryzykuje 0.5% konta.
Po L1: wspólny SL → entry#1 (BE parent). Net = -0.5%.
Prosta ochrona bez agresywnej piramidy.
```

### PIRA tryb 4 — skalpowanie (małe kroki, szybkie zabezpieczenie)

```
Panel:    Mx=3, Stp=10 (dokładka co 10 pips)
Ryzyko%:  0.5 per dokładka

L1 po +10 pip → wspólny SL → entry#1 | net: -0.5%
L2 po +20 pip → wspólny SL → entry L1 | net:  0%  ← zero już po 20 pipach!
L3 po +30 pip → wspólny SL → entry L2 | net: +0.5%
```

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
