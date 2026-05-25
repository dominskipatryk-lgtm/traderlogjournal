# Plan Sprint 2 — TraderLogJournal
**Data:** 2026-05-25 | Szacowany czas: ~9h łącznie

---

## Supabase — czy potrzebny płatny plan?

**NIE. Free tier wystarczy dla tej aplikacji.**

| Feature | Free tier | Potrzebujemy |
|---------|-----------|--------------|
| Storage | 1 GB | Materiały PDF/video kilka MB każdy — wystarczy |
| Bandwidth | 5 GB/miesiąc | Kilku użytkowników pobiera pliki — wystarczy |
| Buckets | nieograniczone | Potrzebujemy 1 bucket `library` |
| File size limit | 50 MB per plik | Większość PDF < 10 MB — OK |
| Signed URLs | ✅ included | Potrzebujemy do tymczasowych linków |
| Row Level Security | ✅ included | Potrzebujemy do ochrony plików |

Paid plan (Pro $25/mies.) jest potrzebny dopiero gdy:
- Przekroczysz 1 GB storage lub 5 GB bandwidth
- Masz setki aktywnych użytkowników jednocześnie

---

## [A] Biblioteka → Supabase Storage ⏱ ~4h

### Problem aktualny
Pliki zapisywane jako base64 w localStorage → limit 400KB/plik, crash przy większych plikach.

### Co trzeba zrobić

#### 1. Krok ręczny (Ty w Supabase Dashboard)
Jednorazowa konfiguracja — zajmie ~5 minut:
1. Wejdź na `https://supabase.com/dashboard` → projekt `ygrkcynyduuflzvbkkvo`
2. **Storage** → **New bucket** → nazwa: `library`, Public: **OFF** (private)
3. **Storage** → **Policies** → bucket `library`:
   - Dodaj policy: `INSERT` dla roli `authenticated` (admin upload)
   - Dodaj policy: `SELECT` dla roli `authenticated` (wszyscy zalogowani mogą czytać)
   - Dodaj policy: `DELETE` dla roli `authenticated` where `auth.email() = 'dominskipatryk@gmail.com'` (tylko admin usuwa)

#### 2. Zmiany w kodzie (preview.html)

**`addLibraryFile()` — upload do Storage zamiast base64:**
```js
async function addLibraryFile() {
  // ... walidacja tytułu ...
  const file = fileInput.files[0];
  if (file) {
    // Upload do Supabase Storage
    const ext = file.name.split('.').pop();
    const path = `${state.currentUser}/${genId()}.${ext}`;
    const { data, error } = await _sb.storage.from('library').upload(path, file);
    if (error) { toast('Błąd uploadu: ' + error.message, 'error'); return; }
    const { data: urlData } = _sb.storage.from('library').getPublicUrl(path);
    // Zamiast base64 zapisujemy tylko metadata + ścieżkę
    newFile.storagePath = path;
    newFile.url = urlData.publicUrl;
    newFile.base64 = null; // nie używamy base64
  }
  saveLibraryFiles([...getLibraryFiles(), newFile]);
  filterLibrary(_libFilter);
  toast('Materiał dodany ✓', 'success');
}
```

**`deleteLibraryFile()` — usuń też z Storage:**
```js
function deleteLibraryFile(id) {
  showConfirm('Usunąć ten materiał z biblioteki?', async () => {
    const f = getLibraryFiles().find(x => x.id === id);
    if (f?.storagePath) {
      await _sb.storage.from('library').remove([f.storagePath]);
    }
    saveLibraryFiles(getLibraryFiles().filter(x => x.id !== id));
    filterLibrary(_libFilter);
    toast('Materiał usunięty', 'success');
  });
}
```

**`downloadLibraryFile()` — signed URL zamiast base64:**
```js
async function downloadLibraryFile(id) {
  const f = getLibraryFiles().find(x => x.id === id);
  if (!f) return toast('Nie znaleziono pliku', 'error');
  if (f.storagePath) {
    // Signed URL ważny 1 godzinę
    const { data, error } = await _sb.storage.from('library').createSignedUrl(f.storagePath, 3600);
    if (error) { toast('Błąd pobierania', 'error'); return; }
    window.open(data.signedUrl, '_blank');
  } else if (f.base64) {
    // fallback dla starych plików base64
    const a = document.createElement('a');
    a.href = f.base64;
    a.download = f.name || 'plik';
    a.click();
  } else if (f.url) {
    window.open(f.url, '_blank');
  }
}
```

**`libPreviewFile()` — podgląd przez signed URL:**
Analogicznie — gdy `f.storagePath` istnieje, wygeneruj signed URL i otwórz w `<iframe>` lub `window.open`.

**Migracja starych danych:**
Stare pliki base64 (jeśli ktoś zdążył dodać) — zostaną wyświetlone jako "Stary format — pobierz ponownie", nie blokują działania.

---

## [B] Tłumaczenia EN — strony dynamiczne ⏱ ~3h

### Problem aktualny
Nav i nagłówki tabel przetłumaczone. Zawartość stron nadal po polsku.

### Co trzeba przetłumaczyć (lista kluczy do dodania do `T.en`)

#### renderEmotions()
```
emotions_title: 'Emotional Analysis'
emotions_pre_label: 'Emotion before entry'
emotions_post_label: 'Emotion after close'
emotions_chart_title: 'Win rate by emotion'
emotions_heatmap_title: 'Emotion heatmap'
emotions_weekly_title: 'Weekly review'
emotions_weekly_empty: 'No weekly reviews yet'
```

#### renderRules()
```
rules_title: 'Trading Rules'
rules_add: 'Add rule'
rules_empty: 'No rules — add your first'
rule_type_max_daily: 'Max daily trades'
rule_type_max_losses: 'Max loss streak'
rule_type_stop_hour: 'Stop after hour'
rule_type_max_risk: 'Max risk %'
rule_type_custom: 'Custom rule'
rules_reminder_label: '(reminder only — does not block)'
```

#### renderLibrary()
```
library_title: 'Library'
library_add: 'Add material'
library_empty: 'No materials — add your first'
library_filter_all: 'All'
library_filter_pdf: 'PDF'
library_filter_video: 'Video'
library_filter_article: 'Article'
library_url_hint: 'Or paste a URL (YouTube, article link)'
```

#### renderJournal() / rutyna dnia
```
journal_title: 'Daily Journal'
journal_routine_title: 'Daily Routine'
routine_step1: 'Morning plan'
routine_step2: 'Market review'
routine_step3: 'Trade plan'
routine_step4: 'End of day review'
routine_step5: 'Reflection'
```

#### Toast messages
```
toast_trade_saved: 'Trade saved ✓'
toast_trade_deleted: 'Trade deleted'
toast_account_deleted: 'Account deleted'
toast_rule_deleted: 'Rule deleted'
toast_note_deleted: 'Note deleted'
```

#### Overtrading modal
```
ot_daily_limit: '⚠️ You will exceed the daily limit of {n} trades!\n(You already have {count})\n\nSave anyway?'
ot_loss_streak: '⚠️ You have {n} consecutive losses!\nLimit: {limit}\n\nAre you sure you want to enter?'
rules_broken_msg: '⚠️ You are breaking a rule:\n{rules}\n\nAre you sure you want to save?'
```

### Podejście implementacyjne
Użyć funkcji `t()` z fallbackiem — jeśli klucz nie istnieje w `T.en`, zwraca wartość z `T.pl`. Dzięki temu nie trzeba tłumaczyć wszystkiego naraz — można dodawać stopniowo.

---

## [C] datetime-local w formularzu transakcji ⏱ ~2h

### Problem aktualny
Pole `t-date` to `<input type="date">` → zapisuje `YYYY-MM-DD` → heatmapa godzin nie ma danych.

### Co trzeba zrobić

#### 1. Zmień typ inputu w HTML (formularz nowej transakcji)
```html
<!-- PRZED -->
<input type="date" id="t-date" ...>
<!-- PO -->
<input type="datetime-local" id="t-date" ...>
```
To samo w formularzu edycji (modal edycji).

#### 2. Zmień domyślną wartość w `openTradeModal()`
```js
// PRZED
document.getElementById('t-date').value = new Date().toISOString().slice(0,10);
// PO
function nowDatetime() {
  const d = new Date();
  return d.getFullYear() + '-' +
    String(d.getMonth()+1).padStart(2,'0') + '-' +
    String(d.getDate()).padStart(2,'0') + 'T' +
    String(d.getHours()).padStart(2,'0') + ':' +
    String(d.getMinutes()).padStart(2,'0');
}
document.getElementById('t-date').value = nowDatetime();
```

#### 3. Migracja starych transakcji
W `getDB()` lub przy ładowaniu — jednorazowy patch:
```js
// Przy pierwszym załadowaniu — dodaj T12:00 do starych dat
trades = trades.map(t => {
  if (t.date && t.date.length === 10) {
    return { ...t, date: t.date + 'T12:00' };
  }
  return t;
});
```

#### 4. Heatmapa godzin
Po tej zmianie `new Date(t.date).getHours()` zadziała poprawnie dla wszystkich transakcji.
Usunąć filtr `t.date.length >= 13` — będzie zbędny po migracji.

---

## [D] Heatmapa tygodnia — "brak danych" vs breakeven ⏱ ~30 min

### Problem aktualny
Komórki bez transakcji mają kolor `var(--bg3)` — identyczny z breakeven (P&L = 0).

### Fix
```css
/* Crosshatch dla "brak danych" */
.heat-cell.no-data {
  background: repeating-linear-gradient(
    45deg,
    var(--bg3),
    var(--bg3) 2px,
    var(--bg2) 2px,
    var(--bg2) 6px
  );
}
```
W JS dodać klasę `no-data` gdy komórka nie ma żadnej transakcji.

---

## KOLEJNOŚĆ REALIZACJI

| Kolejność | Task | Czas | Zależność |
|-----------|------|------|-----------|
| 1 | [Ty] Stwórz bucket `library` w Supabase | 5 min | Musisz to zrobić Ty w dashboard |
| 2 | [C] datetime-local — formularz | ~2h | brak |
| 3 | [A] Biblioteka → Supabase Storage | ~4h | bucket gotowy |
| 4 | [B] EN tłumaczenia dynamiczne | ~3h | brak |
| 5 | [D] Heatmapa no-data kolor | ~30 min | po [C] |

**Łącznie:** ~9.5h kodu + 5 min konfiguracji Supabase (jednorazowe).

---

## Sprint 3 (długoterminowe — bez zmian)
- **Faza F:** Profil psychologiczny tradera (po 30 dniach danych)
- **Faza G:** Inteligentne przypomnienia (Service Worker + Push API)
- **Faza H:** Miesięczny raport PDF (jsPDF)
- **Faza I:** All-in-one wskaźnik MQL4
