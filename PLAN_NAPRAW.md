# Plan napraw — TraderLogJournal
**Data:** 2026-05-25

---

## SPRINT 1 — Do zrobienia teraz (przed następnym deploy)

### [1] Heatmapa godzin — fix format daty ⏱ ~2h
**Problem:** `new Date('2026-05-25').getHours()` = 0 (midnight UTC, nie lokalny czas).  
**Fix:** Dodać pole `entryTime: 'HH:MM'` w formularzu transakcji (obok daty wejścia) albo traktować `t.date` jako lokalny timestamp `YYYY-MM-DDTHH:mm`. Najprościej: zmienić `t-date` w formularzu na `<input type="datetime-local">` i migrować stare dane.  
**Alternatywa szybka:** Ukryć heatmapę godzin i zastąpić ją czymś co działa (np. wykres P&L po dniu tygodnia który już mamy).

### [2] Overtrading alert — przed zapisem, nie po ⏱ ~30 min
**Zmiana w `saveTrade()`:**
```js
// PRZED saveTrades():
const otCheck = checkOvertradingAlert(state.currentAccountId, { dryRun: true });
if (otCheck.exceeded) {
  if (!confirm(otCheck.msg + '\n\nCzy mimo to zapisać?')) return;
}
// ...
saveTrades(...)
// checkOvertradingAlert już nie wywołuj po
```

### [3] Reguła max-risk — implementacja check ⏱ ~1h
**W `checkRulesBeforeSave()`:**
```js
} else if (r.type === 'max-risk') {
  const limitPct = parseFloat(r.value);
  const entry = parseFloat(document.getElementById('t-entry')?.value);
  const sl = parseFloat(document.getElementById('t-sl')?.value);
  const size = parseFloat(document.getElementById('t-size')?.value);
  const cap = getAccounts().find(a=>a.id===state.currentAccountId)?.capital || 0;
  if (!isNaN(limitPct) && entry && sl && size && cap > 0) {
    const riskAmount = Math.abs(entry - sl) * size;
    const riskPct = (riskAmount / cap) * 100;
    if (riskPct > limitPct) {
      broken.push(r); messages.push('Ryzyko ' + riskPct.toFixed(1) + '% > limit ' + limitPct + '%');
    }
  }
}
```

### [4] Korelacja snu — komunikat "za mało danych" ⏱ ~30 min
W `renderSummary()`, w sekcji korelacji, gdy danych < 5:
```js
if (enoughSleepData < 5 && enoughEnergyData < 5) {
  return `<div class="summary-card"><div class="summary-card-title">😴 Sen i energia vs wyniki</div>
    <div style="color:var(--text3);font-size:12px;padding:12px">
      Uzupełnij Rutynę dnia przez min. 5 dni aby zobaczyć tę analizę.
      Aktualnie: ${enoughSleepData} dni z danymi.
    </div></div>`;
}
```

### [5] Custom rules — oznaczenie jako "reminder, nie blokada" ⏱ ~30 min
Zmienić `checkRulesBeforeSave()` dla `custom` type: zamiast potwierdzenia, pokazać subtowy toast:
```js
} else if (r.type === 'custom') {
  // custom reguły = reminder, nie blokada
  // NOT pushed to broken[], tylko pokazujemy info toast
}
```
Albo dodać checkbox `isBlocker: true/false` przy tworzeniu reguły.

---

## SPRINT 2 — Wkrótce (w ciągu tygodnia)

### [6] Biblioteka — Supabase Storage zamiast localStorage ⏱ ~4h
**Architektura:**
- Admin uploaduje → `supabase.storage.from('library').upload(filename, file)`
- Metadata (tytuł, opis, typ, URL) → tabela `library` w Supabase
- Użytkownik pobiera → `supabase.storage.from('library').createSignedUrl(path, 3600)`
- `db['library_files']` → tylko cache metadanych (nie base64 pliku)

### [7] EN tłumaczenia — kompletne ⏱ ~3h
Strony do przetłumaczenia:
- `renderEmotions()` — etykiety wykresów, nagłówki sekcji
- `renderRules()` — etykiety typów reguł, placeholdery
- `renderLibrary()` — tytuły, filtry, opisy
- `renderJournal()` — kroki rutyny, etykiety przycisków
- Toast messages / error strings
- Filter dropdown (emocje, kierunek, status)

### [8] Heatmapa godzin — datetime-local field ⏱ ~2h
- Zmień `t-date` na `datetime-local` w formularzu nowej transakcji
- Zmień `t-date` na `datetime-local` w formularzu edycji
- Migracja starych danych: dla transakcji bez czasu → dodaj `T12:00` (południe jako domyślne)
- `renderSummary()` heatmapa: użyj `new Date(t.date).getHours()` (zadziała gdy date ma czas)

---

## SPRINT 3 — Długoterminowe (w ciągu miesiąca)

### Faza F — Profil psychologiczny (po 30 dniach danych)
- Auto-raport "kim jesteś jako trader"
- Trigger patterns: "Wchodzisz po silnym ruchu bez korekty"
- Top 3 wzorce do zmiany

### Faza G — Inteligentne przypomnienia
- Poniedziałek rano → "Zacznij tydzień od planu"
- Piątek 16:00 → "Czas na weekly review"
- Brak wpisu 3 dni → "Rutyna czeka"
- Implementacja: `cron` w Service Worker + `showNotification()` (Push API)

### Faza H — Miesięczny raport PDF
- `jsPDF` lub `html2canvas` + print-to-PDF
- Wyniki, emocje, najlepsze setupy, postęp dyscypliny

### Faza I — All-in-one wskaźnik MQL4
- Połączyć SMC + SR_HVB + 2 nowe wskaźniki
- MTF sygnały kupna/sprzedaży

---

## KOLEJNOŚĆ PRIORYTETÓW (na jutro)

1. **Deploy** preview → index (5 minut, eliminuje "Nadchodzi w następnej wersji" na produkcji)
2. **Fix heatmapa** — albo ukryj albo datetime-local
3. **Fix overtrading** — przenieść przed zapis
4. **Fix max-risk rule** — brakujące sprawdzanie
5. **Komunikat korelacja** — gdy za mało danych
