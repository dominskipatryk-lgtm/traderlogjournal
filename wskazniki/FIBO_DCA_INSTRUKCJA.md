# TraderLogJournal FIBO GRID + DCA — Instrukcja użytkownika

> Plik: `TraderLogJournal_FIBO_DCA_v1.mq4` | Wersja: 1.0 | Data: 2026-06-10

---

## Spis treści

1. [Instalacja](#1-instalacja)
2. [Panel — układ](#2-panel--układ)
3. [FIBO GRID — jak używać](#3-fibo-grid--jak-używać)
4. [DCA Manager — jak używać](#4-dca-manager--jak-używać)
5. [Parametry EA](#5-parametry-ea)
6. [Pip Size — tabela instrumentów](#6-pip-size--tabela-instrumentów)
7. [Matematyka i przykłady](#7-matematyka-i-przykłady)
8. [Zasady i pułapki](#8-zasady-i-pułapki)

---

## 1. Instalacja

```
1. Skopiuj plik do:
   C:\Users\<twój_użytkownik>\AppData\Roaming\MetaQuotes\Terminal\<ID>\MQL4\Experts\

2. Otwórz MetaEditor (F4 w MT4)

3. Otwórz plik → F7 (kompilacja)
   Powinno pokazać: 0 errors, 0 warnings

4. W MT4: Navigator → Expert Advisors → TraderLogJournal_FIBO_DCA_v1
   Przeciągnij na wykres lub double-click

5. W oknie ustawień:
   ✅ Allow live trading
   ✅ Allow DLL imports (jeśli wymagane)
   Kliknij OK
```

> **Ten EA jest OSOBNY od głównego TraderLogJournal_EA_v2.**
> Możesz mieć oba na różnych wykresach jednocześnie — mają różne MagicNumbers.

---

## 2. Panel — układ

```
┌─────────────────────────────────────┐
│ TLJ   FIBO GRID + DCA               │  ← pasek tytułu
├─────────────────────────────────────┤
│ ▶  FIBO GRID                        │  ← nagłówek sekcji
├─────────────────────────────────────┤
│ Ryzyko%  [0.25]    SL  [30]  pip    │
│ N        [4  ]     TP  [24 ] pip    │
│ [Rysuj linie]   [Kasuj linie]       │
│ [■  TRYB: ALL STOP              ]   │
│ [▲  BUILD BUY ] [▼  BUILD SELL ]   │
├─────────────────────────────────────┤
│ ▶  DCA MANAGER                      │  ← nagłówek sekcji
├─────────────────────────────────────┤
│ Lot [0.10]  Krok [10] pip  Mx [5]  │
│ SL  [50 ]   TP   [100] pip  ● --   │
│ [▲  DCA BUY ] [▼  DCA SELL ]       │
│ [■  STOP DCA + CLOSE ALL       ]   │
└─────────────────────────────────────┘
```

### Opis pól

#### FIBO GRID
| Pole | Opis |
|---|---|
| **Ryzyko%** | % konta ryzykowany na każdy poziom siatki |
| **SL** | SL pierwszego poziomu w pipsach (Faron: kolejne = 1 krok) |
| **N** | Liczba poziomów siatki (2–20) |
| **TP** | TP każdego poziomu od jego ceny wejścia (pips) |

#### DCA Manager
| Pole | Opis |
|---|---|
| **Lot** | Stały lot każdej pozycji DCA |
| **Krok** | Ile pipsów na stracie → dodaj kolejną pozycję |
| **Mx** | Maksymalna liczba pozycji DCA łącznie |
| **SL** | SL każdej pozycji DCA (pips od jej ceny wejścia) |
| **TP** | TP każdej pozycji DCA (pips od jej ceny wejścia) |
| **● Status** | WYŁ / BUY WŁ / SELL WŁ |

---

## 3. FIBO GRID — jak używać

### Co to jest

Siatka zleceń rozłożona między dwiema liniami które sam rysuje na wykresie — jak Fibonacci Retracement, ale zamiast poziomów procentowych EA stawia N równych kroków między wyznaczoną strefą.

### Krok po kroku

**1. Ustaw parametry**
```
Ryzyko% = 0.25   (0.25% konta per poziom)
SL      = 6      (6 pipsów SL dla poziomu #1)
N       = 4      (4 poziomy)
TP      = 24     (24 pipy TP od każdego wejścia)
```

**2. Narysuj strefę**

Kliknij `[Rysuj linie]` → na wykresie pojawią się:
- **Zielona linia** `TLJ_FTOP` — szczyt strefy (przeciągnij wyżej/niżej)
- **Czerwona linia** `TLJ_FBOT` — dół strefy (przeciągnij wyżej/niżej)
- **Szare linie** `TLJ_FGL_1…4` — podgląd N poziomów (aktualizują się na żywo)

> Linie szare **pokazują gdzie staną zlecenia** — przeciągaj TOP i BOT aż poziomy będą tam gdzie chcesz.

**3. Wybierz tryb**

Kliknij `[■ TRYB: ALL STOP]` aby przełączyć:

| Tryb | Co robi |
|---|---|
| **ALL STOP** | Wszystkie N poziomów jako STOP orders (czekają na cenę) |
| **#1 MARKET + STOP** | Poziom #1 otwiera się natychmiast market, reszta jako STOP |

**4. Postaw grid**

- `[▲ BUILD BUY]` — BUY STOP na wszystkich poziomach
- `[▼ BUILD SELL]` — SELL STOP na wszystkich poziomach

→ Linie znikają, zlecenia są aktywne w zakładce Trade MT4.

**5. Kasowanie**

`[Kasuj linie]` — usuwa linie TOP/BOT i podgląd bez stawiania zleceń.

---

### Jak EA przelicza SL (Faron Mode)

```
N=4, SL=6 pip, krok=6 pip (TP÷N = 24÷4 = 6 pip)

BUILD BUY (strefa powyżej Ask):
  #1 BUYSTOP @ poziom 1   SL = wejście#1 − 6 pip (pełny SL)
  #2 BUYSTOP @ poziom 2   SL = wejście#1         (Faron: SL = entry poprzedniego)
  #3 BUYSTOP @ poziom 3   SL = wejście#2
  #4 BUYSTOP @ poziom 4   SL = wejście#3

Krok #1 SL jest z pola SL kalkulatora.
Krok #2+ SL = odległość między poziomami (1 krok = 6 pip).
```

### Przykład na WTI.FS (ropa)

```
Strefa: 88.40 (BOT) → 89.00 (TOP)
N = 4 → krok = 0.60÷3 = 0.20 dolara = 2 pipy (0.10/pip)
Ryzyko% = 0.25, SL = 6 pip

Poziomy:
  #1 BUYSTOP @ 88.40   SL @ 87.80 (6 pip × 0.10 = 0.60)
  #2 BUYSTOP @ 88.60   SL @ 88.40
  #3 BUYSTOP @ 88.80   SL @ 88.60
  #4 BUYSTOP @ 89.00   SL @ 88.80
```

---

## 4. DCA Manager — jak używać

### Co to jest

DCA (Dollar Cost Averaging) — EA automatycznie **dokłada pozycję** gdy cena idzie **przeciwko** otwartemu trade'owi o zdefiniowaną liczbę pipsów. Obniża (lub podwyższa przy SELL) średnią cenę wejścia.

> ⚠️ **DCA to strategia wysokiego ryzyka.** Przy silnym trendzie cena może nie wrócić. Zawsze ustaw SL i Mx.

### Krok po kroku

**1. Ustaw parametry**
```
Lot  = 0.10   (stały lot każdej dokładki)
Krok = 10     (dodaj pozycję gdy ostatnia jest 10 pipsów na stracie)
Mx   = 5      (max 5 pozycji łącznie — pierwsza + 4 dokładki)
SL   = 50     (SL 50 pip od każdej pozycji)
TP   = 100    (TP 100 pip od każdej pozycji)
```

**2. Otwórz pierwszą pozycję**

- `[▲ DCA BUY]` → EA otwiera BUY @ market i zaczyna monitorować
- `[▼ DCA SELL]` → EA otwiera SELL @ market i zaczyna monitorować

Status zmienia się na `● BUY WŁ` lub `● SELL WŁ`.

**3. EA pracuje automatycznie**

Co sekundę EA sprawdza:
```
Czy ostatnia DCA pozycja jest na stracie >= Krok pipsów?
  → TAK i liczba pozycji < Mx → otwiera kolejną
  → NIE → czeka
```

**4. Zatrzymaj DCA**

`[■ STOP DCA + CLOSE ALL]` → zamknięcie wszystkich pozycji DCA i wyłączenie.

---

### Jak działa dokładanie

```
Przykład: EURUSD, Krok=10 pip, Mx=3, Lot=0.10

DCA BUY @ 1.08500
  → cena spada do 1.08400 (strata 10 pip)
  → EA otwiera DCA BUY #2 @ 1.08400

  → cena spada do 1.08300 (strata 10 pip od #2)
  → EA otwiera DCA BUY #3 @ 1.08300 (limit Mx=3 osiągnięty)

  → więcej pozycji nie dodaje

Średnia cena: (1.08500 + 1.08400 + 1.08300) / 3 = 1.08400
Gdy cena wraca do ~1.08400 + TP(100p) → zamknięcie z zyskiem
```

> **TP jest synchronizowany:** gdy EA dodaje nową pozycję, aktualizuje TP wszystkich istniejących DCA na nowy poziom od aktualnej ceny.

---

## 5. Parametry EA

Ustawienia w oknie Inputs przy wczytywaniu EA na wykres:

| Parametr | Domyślnie | Opis |
|---|---|---|
| `MagicNumber` | `20261010` | Unikalny numer — nie zmieniaj gdy masz aktywne pozycje |
| `PnlX` | `20` | Pozycja X panelu (px od lewej) |
| `PnlY` | `260` | Pozycja Y panelu (px od góry) |
| `TimerSec` | `1` | Jak często sprawdzane są warunki DCA (sekundy) |

> **Zmień PnlY** jeśli panel nakłada się na panel głównego EA (np. ustaw `PnlY = 500`).

---

## 6. Pip Size — tabela instrumentów

EA automatycznie wykrywa typ instrumentu i przelicza pipy poprawnie. Wpisujesz zawsze **pipy** — EA zamienia na odległość cenową.

| Instrument | 1 pip = | Przykład: SL=6 |
|---|---|---|
| EURUSD, GBPUSD | 0.0001 | 0.0006 odległości |
| USDJPY | 0.01 | 0.06 odległości |
| **XAUUSD (złoto)** | **0.10** | **0.60 odległości** |
| **WTI.FS, BRENT.FS (ropa)** | **0.10** | **0.60 odległości ($0.60/baryłkę)** |
| NGAS.FS | 0.01 | 0.06 odległości |
| AUS200, UK100, US30 | 1.0 | 6 punktów |
| NAS100, GER40 | 1.0 | 6 punktów |
| **BTCUSD, ETHUSD** | **1.0** | **$6 odległości** |
| XRP | 0.0001 | 0.0006 odległości |

> **Zasada:** wpisujesz liczbę naturalną (np. `6`) → EA liczy właściwą odległość na wykresie.
> Na WTI: SL=6 → 6 pipsów × $0.10 = **$0.60 per baryłkę**.

---

## 7. Matematyka i przykłady

### FIBO GRID — zysk przy N=4

```
Instrument: WTI.FS, Lot=2.0 per poziom, TP=24 pip, krok=6 pip

Gdy wszystkie 4 poziomy wypełnione i TP trafiony:
  #1: 24 pip × 2 lot × $100/pip/lot = $4 800
  #2: 18 pip × 2 lot × $100/pip/lot = $3 600
  #3: 12 pip × 2 lot × $100/pip/lot = $2 400
  #4:  6 pip × 2 lot × $100/pip/lot = $1 200
                              RAZEM = $12 000

Maksymalna strata (Faron Mode) = zawsze 1 krok × lot:
  1 krok = 6 pip × 2 lot × $100 = $1 200
  R:R = $12 000 / $1 200 = 1:10 ✓
```

### DCA — break-even

```
3 pozycje DCA BUY EURUSD, każda 0.10 lot, wejścia: 1.0850 / 1.0840 / 1.0830
Średnia = 1.0840

Cena musi wrócić do 1.0840 + spread żeby wyjść na zero.
Przy TP=100 pip od każdego wejścia → każda pozycja zamknie się w innym miejscu.
```

---

## 8. Zasady i pułapki

| Zasada | Szczegóły |
|---|---|
| **FIBO: ALL STOP wymaga strefy powyżej Ask (BUY)** | Wszystkie poziomy muszą być powyżej aktualnej ceny dla BUY STOP. Jeśli poziom jest za blisko — EA go pomija i loguje w Experts |
| **FIBO: N=1 nie działa** | Minimum 2 poziomy — inaczej nie ma Faron Mode |
| **FIBO i główny EA** | Oba EA mogą działać jednocześnie — mają różne MagicNumbers (`202601` vs `20261010`). Nie zarządzają swoimi nawzajem pozycjami |
| **DCA bez SL = ruina** | Zawsze ustaw SL. Bez SL przy silnym trendzie — strata całego konta |
| **DCA Mx = zabezpieczenie** | Mx=5 to maksimum — EA nie doda 6. pozycji nawet jeśli warunek jest spełniony |
| **STOP DCA zamyka wszystko** | Przycisk zamyka **wszystkie** pozycje z komentarzem `TLJ_DCA_*` na bieżącym symbolu |
| **Zmiana interwału** | EA traci stan `_dcaDir` po zmianie interwału → DCA zatrzymuje się. Musisz kliknąć DCA BUY/SELL ponownie |
| **Jeden EA na wykres** | Nie wczytuj dwóch kopii tego EA na ten sam wykres |
| **Linie TLJ_FTOP / TLJ_FBOT** | Możesz je przesuwać ręcznie po narysowaniu — podgląd aktualizuje się co sekundę |
| **Kompilacja po każdej aktualizacji** | Skopiuj nowy `.mq4` → MetaEditor F7 → zdjąć stare EA z wykresu → wczytać nowe |

---

## Szybka ściąga

```
FIBO GRID w 4 krokach:
  1. Ryzyko% / SL / N / TP → wypełnij pola
  2. [Rysuj linie] → ustaw strefę przeciągając linie
  3. [TRYB] → ALL STOP lub #1 MARKET
  4. [BUILD BUY] lub [BUILD SELL] → gotowe

DCA w 2 krokach:
  1. Lot / Krok / Mx / SL / TP → wypełnij pola
  2. [DCA BUY] lub [DCA SELL] → EA pracuje automatycznie

Zatrzymaj: [STOP DCA + CLOSE ALL]
```
