# TraderLogJournal — Audit UX (jako użytkownik, bez owijania w bawełnę)
**Data:** 2026-05-25 | Testowano: `preview.html`

---

**Aktualizacja 2026-05-25:** Poprawki 1-9 wdrożone w commit `07e9252`.

---

## KRYTYCZNE (psują funkcjonalność)

### 1. Biblioteka: localStorage nie udźwignie plików PDF
**Problem:** Pliki są konwertowane na base64 i zapisywane w localStorage (limit ~5-10MB łącznie dla CAŁEJ aplikacji). Jeden PDF 2MB → po base64 to ~2.7MB. Dwa PDFy = aplikacja przestaje działać (localStorage pełne, dane transakcji mogą się nie zapisać).  
**Realny skutek:** Admin wgrywa 3 pliki → dane transakcji użytkownika przestają się zapisywać, aplikacja crashuje po cichu.  
**Fix:** Biblioteka powinna zapisywać pliki w Supabase Storage (bucket), nie w localStorage.

### 2. Overtrading alert: odpala PO zapisaniu transakcji
**Problem:** `checkOvertradingAlert()` jest wywoływane w `saveTrade()` DOPIERO po `saveTrades()` — transakcja już jest w bazie gdy pojawia się alert "Przekroczyłeś limit".  
**Realny skutek:** Alert działa jako informacja, nie jako blokada. Użytkownik może zignorować — transakcja jest już zapisana.  
**Fix:** Przenieść `checkOvertradingAlert()` PRZED `saveTrades()` i jeśli limit przekroczony → `confirm()` "Czy mimo to zapisać?".

### 3. Reguła "max-risk %" nie jest sprawdzana
**Problem:** W `checkRulesBeforeSave()` obsługiwane są tylko typy: `max-daily`, `max-losses`, `stop-hour`. Typ `max-risk` nie ma żadnej implementacji — reguła jest wyświetlana, ale nigdy nie jest sprawdzana.  
**Realny skutek:** Użytkownik dodaje regułę "Max 2% ryzyko", ma poczucie bezpieczeństwa, ale żaden check nie działa.  
**Fix:** Dodać sprawdzanie: `(|entry - sl| × size / capital) × 100 > limit`.

### 4. Heatmapa godzin jest zawsze pusta
**Problem:** Godzina wejścia jest brana z `new Date(t.date).getHours()` gdzie `t.date = 'YYYY-MM-DD'`. Data bez czasu → JavaScript parsuje jako midnight UTC → w Polsce (UTC+2) = godzina 2:00. Wszystkie transakcje lądują na godzinie 2 lub 0. Heatmapa nigdy nie pokazuje realnych godzin.  
**Fix:** Przechowywać `dateTime` w transakcji (date + czas wejścia). Albo dodać osobne pole `entryTime` (HH:MM).

---

## POWAŻNE (degradują UX)

### 5. Reguły używają natywnego `confirm()` — brzydkie i blokowane
**Problem:** Naruszenie reguły = `confirm('Łamiesz regułę:\n...')`. Na mobile dialog `confirm()` wygląda jak alert przeglądarki, bez stylów, strasznie. Na niektórych przeglądarkach mobilnych może być zablokowany.  
**Fix:** Własny modal potwierdzenia zamiast `confirm()`.

### 6. Demo data nie testuje overtrading alert
**Problem:** Demo generuje transakcje z przeszłości (60 dni wstecz). `checkOvertradingAlert()` sprawdza tylko dzisiejszą datę (`new Date().toISOString().slice(0,10)`). Nigdy nie odpali dla demo danych. Użytkownik testujący myśli że funkcja nie działa.

### 7. Korelacja sen/energia — minimum 5 dni to za mało i nie ma komunikatu
**Problem:** Sekcja korelacji w Statystykach pojawia się gdy jest ≥5 dni z danymi. Jeśli jest mniej → sekcja znika bez śladu. Użytkownik nie wie dlaczego jej nie widzi.  
**Fix:** Wyświetlić komunikat "Uzupełnij Rutynę dnia przez min. 5 dni aby zobaczyć korelację" — nawet gdy danych jest za mało.

### 8. Tłumaczenie EN jest połowiczne
**Problem:** Przetłumaczone: nav, nagłówki tabel, statusy transakcji. NIE przetłumaczone: cała zawartość stron Emocje, Reguły, Biblioteka, Rutyna dnia, komunikaty błędów, toast notyfikacje, etykiety emocji w filtrze, opisy tygodniowego przeglądu.  
**Realny skutek:** Użytkownik przełącza na EN → nav w angielskim, ale cała treść nadal po polsku. Wygląda źle, jak niedokończone.

### 9. Strona Emocje w index.html pokazuje "Nadchodzi w następnej wersji"
**Problem:** index.html (produkcja) ma starą wersję `renderEmotions()` z dosłowną kartą "🚀 Nadchodzi w następnej wersji". Dla prawdziwych użytkowników wyglada to jak demo.  
**Fix:** Deploy preview → index.

### 10. Tabela transakcji: "Otwarta/Zamknięta" nie uwzględniało starych transakcji
**Problem:** Przed dzisiejszą poprawką status w tabeli był hardcoded `'Otwarta'/'Zamknięta'`. Teraz używa `t()`. Ale jeśli ktoś zapisał transakcję w EN i przełączy na PL — badge jest OK. Drobne, ale spójność dobra.

---

## DROBNE (irytują, ale nie blokują)

### 11. Filter emocji w transakcjach nie tłumaczy się
Opcje selecta (`🧠 Emocje: Wszystkie`, `Spokojny (pre)` itp.) są hardcoded Polish. Po przełączeniu na EN nadal PL.

### 12. PAGE_TITLES regex dla nav_analysis/nav_calendar
`t('nav_analysis').replace(/^\S+\s/, '')` — teraz gdy `nav_analysis = 'Analiza'` regex nie matchuje nic i zwraca `'Analiza'`. OK. Ale jeśli ktoś doda emoji z powrotem do tłumaczenia, regex może się wysypać dla emojis z ZWJ (złożonych).

### 13. Biblioteka: brak potwierdzenia przed usunięciem pliku
`deleteLibraryFile()` usuwa bez pytania — brak `confirm()`. Łatwo usunąć przez przypadek.

### 14. Heatmapa tygodnia — kolor po lewej stronie jest zawsze szary
Heatmapa grupy `Pn-Pt × 7-18h` — dni bez żadnej transakcji mają kolor tła `var(--bg3)`. Wizualnie ciężko odróżnić "brak danych" od "breakeven". Lepszy byłby crosshatch lub inna tekstura dla "brak danych".

### 15. Reguła "custom" (własna zasada) nigdy nie jest sprawdzana
Użytkownik może wpisać "Nie traduj podczas News" — ale `checkRulesBeforeSave()` nie sprawdza custom rules (jak miałaby to zrobić?). Wyświetlana jako dekoracja. Powinna mieć checkbox "wymagaj potwierdzenia przy każdym wejściu" lub być jasno oznaczona jako "reminder, nie blokada".

---

## CO DZIAŁA DOBRZE (uczciwy raport ma też plusy)

- **Generator demo danych** — działa, 127 transakcji z emocjami, journal, weekly review ładowane automatycznie ✓
- **Unified kalkulator** — solidnie, uzupełnianie z konta działa ✓
- **Overtrading popup** — wizualnie bardzo dobry, duże STOP, auto-close 8s ✓
- **R:R tabela z suwakiem** — sticky header + max-height 420px, scrolluje płynnie ✓
- **Tabela transakcji** — mniejszy padding, nowrap = cyfry mieszczą się ✓
- **Rutyna dnia 4+5 kroków** — flow działa, progress bar reaguje ✓
- **Sesja 5h** — persist po odświeżeniu, ostrzeżenie 1h przed końcem działa ✓
- **Walidacja emocji** — highlight czerwoną ramką + scroll do pickera = intuicyjne ✓

---

## PRIORYTET NAPRAW

| # | Problem | Priorytet | Status |
|---|---------|-----------|--------|
| 1 | Heatmapa godzin — check czy data ma czas | 🔴 KRYTYCZNY | ✅ `07e9252` |
| 2 | Overtrading alert po zapisie zamiast przed | 🔴 WYSOKI | ✅ `07e9252` |
| 3 | Biblioteka base64 → limit localStorage | 🔴 WYSOKI (architektura) | ✅ `07e9252` limit 400KB + błąd |
| 4 | Reguła max-risk nie działa | 🟡 ŚREDNI | ✅ `07e9252` |
| 5 | Custom rules — oznaczone "(tylko przypomnienie)" | 🟡 ŚREDNI | ✅ `07e9252` |
| 6 | Filtry EN — tłumaczenie selektów | 🟡 ŚREDNI | ✅ `07e9252` |
| 7 | Korelacja snu — komunikat gdy za mało danych | 🟢 NISKI | ✅ `07e9252` |
| 8 | Demo data — używa dzisiejszej daty | 🟢 NISKI | ✅ `07e9252` |
| 9 | confirm() → własne modale | 🟢 NISKI | ⏳ do zrobienia |
| 10 | Deploy preview → index | 🔴 NATYCHMIAST | ⏳ czeka na decyzję |
| 11 | Biblioteka Supabase Storage | 🔴 Architektura | ⏳ Sprint 2 |
| 12 | EN tłumaczenia stron emocje/reguły/biblioteka | 🟡 ŚREDNI | ⏳ Sprint 2 |
