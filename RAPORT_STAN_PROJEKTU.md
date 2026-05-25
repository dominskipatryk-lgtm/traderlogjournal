# TraderLogJournal — Raport stanu projektu
**Data:** 2026-05-25

---

## 1. PREVIEW vs INDEX — Co jest w preview czego nie ma w index

### Statystyki plików
| | `preview.html` | `index.html` | Różnica |
|--|--|--|--|
| Linii kodu | 16 450 | 15 774 | **+676 linii** |
| Funkcji JS | 490 | 472 | **+18 funkcji** |
| Ostatnia zmiana | dziś | 2026-05-25 02:42 (commit `3e95bcc`) | |

---

### Funkcje w preview których NIE MA w index.html

| Funkcja | Co robi |
|---------|---------|
| `renderLibrary()` | Strona Biblioteki strategii (Faza E) |
| `addLibraryFile()` | Upload pliku do biblioteki |
| `deleteLibraryFile()` | Usuwanie pliku |
| `downloadLibraryFile()` | Pobieranie pliku przez użytkownika |
| `filterLibrary()` | Filtr PDF/MQ4/Screenshots |
| `getLibraryFiles()` | Odczyt biblioteki z localStorage |
| `saveLibraryFiles()` | Zapis biblioteki |
| `libPreviewFile()` | Podgląd pliku |
| `renderRules()` | Lista reguł osobistych (Faza C) |
| `addRule()` | Dodanie reguły |
| `deleteRule()` | Usunięcie reguły |
| `getRules()` | Odczyt reguł |
| `saveRules()` | Zapis reguł |
| `updateRuleValueHint()` | Hint w formularzu reguł |
| `checkRulesBeforeSave()` | Walidacja reguł przy zapisie transakcji |
| `checkOvertradingAlert()` | Sprawdzenie limitu dziennego/strat (Faza B) |
| `showOvertradingPopup()` | Popup STOP |
| `saveOtLimits()` | Zapis konfiguracji alertu |

---

### Commity w preview których NIE MA w index (po ostatnim deploy `3e95bcc`)

| Commit | Opis | Rodzaj |
|--------|------|--------|
| `e4ffc1f` | Fix emotionPre CSV + null user guard journal/weekly | **Bug fix** |
| `c509aca` | Rename "Dziennik" → "Rutyna dnia" | UI |
| `3326859` | **Fazy B+C+D+E** — wykresy emocji, reguły, korelacja snu, biblioteka | **Nowa funkcja** |
| `a5e3ccd` | Fix CAGR nie wyświetla >999% | **Bug fix** |
| `36a7318` | i18n kompletne nav + tabela mniejszy padding + R:R suwak | UI |

---

### Co index.html ma a co robi źle

`renderEmotions()` w index.html to **stara wersja** — zamiast wykresów i heatmapy pokazuje tabelę + kartę "Nadchodzi w następnej wersji". Jest tam literalny tekst "Nadchodzi w następnej wersji" widoczny dla użytkowników produkcyjnych.

---

## 2. HISTORIA WDROŻEŃ

| Data | Commit | Co wdrożono |
|------|--------|-------------|
| przed 25.05 | `ff6303d` | Unified kalkulator ryzyka, rutyna krokowa, EA flow |
| 25.05 02:42 | `3e95bcc` | i18n fix ikon nav + bump SW cache v9 (ostatni deploy) |
| **NIE wdrożono** | `e4ffc1f`–`36a7318` | 5 commitów czeka na wdrożenie |

---

## 3. CO CZEKA NA WDROŻENIE DO INDEX

Łącznie **5 commitów** + **676 linii** + **18 funkcji** czeka na deploy.

Komenda wdrożenia:
```bash
cp preview.html index.html
git add index.html
git commit -m "deploy: preview -> index (Fazy B+C+D+E + bugfix)"
git push
```
