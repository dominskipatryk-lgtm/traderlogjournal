# TODO — poniedziałek (kontynuacja SMC_Complete)

## DECYZJA ARCHITEKTONICZNA
**Wybrano Opcję C** — dwa osobne pliki (EA + SMC_Complete), ale EA panel dostaje przycisk `[SMC ▶]`
który pokazuje/chowa wszystkie rysunki SMC bez otwierania jego panelu.
- EA osobno → OnTick() nie jest przeciążony
- SMC osobno → OnCalculate(), wydajne na 5 instrumentach
- Wizualnie: jeden panel (EA), SMC zwinięty do minimum lub niewidoczny

---

## Funkcja: Panel zwijany + ON/OFF

### Co zrobić
Panel w `SMC_Complete.mq4` ma dostać dwa nowe przyciski w nagłówku:

1. **Przycisk ON/OFF** — ukrywa/pokazuje WSZYSTKIE rysunki wskaźnika (OBs, BOS, FVG itd.)
   - Panel zostaje widoczny (żeby móc włączyć z powrotem)
   - Stan: `bool gMasterOn = true`

2. **Przycisk [+] / [−]** — zwija/rozwija listę toggleów
   - Domyślnie: zwinięty (widać tylko nagłówek + dwa przyciski)
   - Po kliknięciu [+]: panel się rozszerza, pokazują się wszystkie 13 toggleów
   - Po kliknięciu [−]: panel zwija się do samego nagłówka (~50px wysokości)

### Wygląd nagłówka (zwinięty)
```
┌───────────────────────────────────────┐
│ SMC Suite    TraderLogJournal  [ON] [+] │
└───────────────────────────────────────┘
```

### Wygląd po rozwinięciu
```
┌───────────────────────────────────────┐
│ SMC Suite    TraderLogJournal  [ON] [−] │
├───────────────────────────────────────┤
│ MARKET STRUCTURE                       │
│ [✔] Market Structure Internal          │
│ ... (reszta toggleów)                  │
│ [Reset & Recalculate]                  │
└───────────────────────────────────────┘
```

### Implementacja (główne zmiany)
- `bool gPanelExpanded = false` — stan zwinięcia
- `bool gMasterOn = true` — stan ON/OFF
- `BT_ONOFF = P"bOnOff"` — przycisk włącz/wyłącz
- `BT_EXPAND = P"bExpand"` — przycisk [+]/[−]
- `CreatePanel()` — dwa tryby: zwinięty (h≈46) i rozwinięty (h=482)
- `OnChartEvent` — obsługa BT_ONOFF i BT_EXPAND
- `DrawAll()` — jeśli `!gMasterOn` → `DelDraw(); return;`
- Panel resize: przy toggle trzeba usunąć i odtworzyć tło (OBJPROP_YSIZE)

### Pliki do zmiany
- `wskazniki/SMC_Complete.mq4` — jedyna zmiana

---
*Zapisano: 2026-06-04. Plik SMC_Complete.mq4 już stworzony i gotowy do rozbudowy.*
