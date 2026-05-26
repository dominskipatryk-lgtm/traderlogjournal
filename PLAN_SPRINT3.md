# Plan Sprint 3 — TraderLogJournal
**Data:** 2026-05-25 | Status: Sprint 3 ✅ kompletny (X1+X2+X3, G, F, H) | [I] MQL4 — pominięty celowo, wrócimy gdy app gotowa

---

## STATUS PO SPRINT 1+2

Wszystko z audytu UX i planu Sprint 2 zrealizowane:

| Zadanie | Status |
|---------|--------|
| datetime-local w formularzu (heatmapa godzin) | ✅ |
| Supabase Storage — biblioteka | ✅ |
| EN tłumaczenia stron + placeholderów | ✅ |
| confirm() → własne modale | ✅ |
| Overtrading alert przed zapisem | ✅ |
| Max-risk rule check | ✅ |
| Crosshatch no-data w heatmapie tygodnia | ✅ |
| deploy preview → index | ✅ live |

---

## DROBNE POZOSTAŁOŚCI (przed Sprint 3, ~1h łącznie)

Te rzeczy są małe — można zrobić jednym commitem.

### [X1] Demo data — overtrading alert ⏱ ~20 min
Generator demo tworzy transakcje z przeszłości (60 dni wstecz). `checkOvertradingAlert()` sprawdza tylko dzisiejszą datę → alert nigdy nie odpala dla demo.
**Fix:** W generatorze demo, dla ostatniego dnia (dziś), dodaj 5+ transakcji — przekroczy limit dzienny i odpali alert.

### [X2] Filter emocji — tłumaczenie na EN ⏱ ~20 min
Opcje selecta `#filter-emotion` (`Spokojny (pre)`, `Skupiony` itp.) są hardcoded PL.
**Fix:** Dodać do sekcji `// ── 3. Selects` w `applyLangToStatic()` tablicę EN/PL dla emocji.

### [X3] ~30 admin-panel strings po polsku ⏱ ~20 min
Panele: zapis użytkownika, eksport/import danych, hasła, nieobsługiwane błędy Supabase.
**Fix:** Wystarczy t() + klucze w T.en z PL fallback — nie blokują użytkowników.

---

## SPRINT 3 — Funkcje długoterminowe

### [F] Profil psychologiczny tradera ⏱ ~6h
**Trigger:** Po 30 dniach danych z emocjami i journal.
**Co pokazuje:**
- "Kim jesteś jako trader" — na podstawie dominującej emocji, win rate, dyscypliny
- Top 3 wzorce błędów (np. "Wchodzisz z overconfidence → WR 32%")
- Progress score: dyscyplina, zarządzanie ryzykiem, emocje (0-100)
- Porównanie tygodni: czy robisz postęp?

**Implementacja:**
```js
function renderTradingProfile() {
  // Min. 30 dni danych — inaczej "Zbyt mało danych"
  // Analiza: emotionPre × wynik → trigger patterns
  // Score: (reguły przestrzegane / łącznie) × 100
}
```

**Gdzie:** Nowa zakładka "Profil" w Statystykach (obok Summary/Emocje).

---

### [G] Inteligentne przypomnienia ⏱ ~4h
**Cel:** Powiadomienia push w przeglądarce (bez zewnętrznego serwera).

**Harmonogram:**
| Dzień/czas | Treść |
|-----------|-------|
| Poniedziałek 8:00 | "Zacznij tydzień od planu — otwórz Rutynę dnia" |
| Piątek 16:30 | "Czas na weekly review — jak minął tydzień?" |
| Codziennie 20:00 (jeśli brak wpisu) | "Uzupełnij dziennik z dzisiaj" |
| Po 3 dniach bez logowania | "Dziennik czeka — wróć do rutyny" |

**Implementacja:**
- `Notification.requestPermission()` w settings
- `setTimeout` / `setInterval` dla powiadomień w trakcie sesji
- Service Worker: `self.registration.showNotification()` dla powiadomień gdy app zamknięta
- Zapis harmonogramu: `db['reminders_' + user]`

**Uwaga:** Push API bez serwera push = powiadomienia tylko gdy SW jest aktywny (ograniczenie). Prawdziwe push wymaga backendu — na razie Notification API tylko gdy okno otwarte.

---

### [H] Miesięczny raport PDF ⏱ ~5h
**Cel:** Jeden przycisk → pobierz PDF z podsumowaniem miesiąca.

**Zawartość:**
- Wyniki: P&L, WR%, liczba transakcji, najlepszy/najgorszy dzień
- Top 3 instrumenty (P&L)
- Emocje: dominująca emocja pre/post
- Dyscyplina: ile reguł złamanych
- Weekly reviews: cytaty z własnych notatek
- Wykres P&L po dniach (sparkline)

**Implementacja:**
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
```
```js
async function exportMonthlyPDF(year, month) {
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF();
  // ... buduj strony
  doc.save(`TLJ_${year}_${String(month+1).padStart(2,'0')}.pdf`);
}
```

**Gdzie:** Przycisk w Statystykach → "📄 Eksportuj raport PDF (miesiąc)".

---

### [I] All-in-one wskaźnik MQL4 ⏱ ~8h
**Cel:** Jeden wskaźnik MT4 łączący: SMC + SR_HVB + sygnały MTF.

**Funkcje:**
- Oznaczenia Order Blocków (BOS + CHoCH)
- Strefy Supply/Demand (SVB)
- Sygnał wejścia (strzałka) gdy confluence 3+ timeframe
- Panel: kierunek trendu M15/H1/H4/D1
- Alert → wysyłka do TraderLogJournal przez istniejące EA

**Pliki:** `TraderLogJournal_Indicator_v1.mq4`

---

## KOLEJNOŚĆ REALIZACJI

| Priorytet | Zadanie | Czas | Zależność |
|-----------|---------|------|-----------|
| 🔴 1 | [X1+X2+X3] Drobne pozostałości | ~1h | brak |
| 🟡 2 | [G] Przypomnienia (Notification API, bez push) | ~2h | brak |
| 🟡 3 | [F] Profil psychologiczny | ~6h | min. 30 dni danych u użytkownika |
| 🟢 4 | [H] PDF raport miesięczny | ~5h | brak |
| 🟢 5 | [I] Wskaźnik MQL4 | ~8h | niezależne od appki |

**Łącznie:** ~22h kodu

---

## Co NIE jest w planie (świadoma decyzja)

- **Własny serwer push** — wymaga backendu (Node.js + Supabase Edge Functions). Poza scope free tier.
- **Multi-device sync w czasie rzeczywistym** — Supabase Realtime możliwe, ale niski priorytet.
- **Mobile app (PWA install)** — już działa jako PWA, nie trzeba nic robić.
- **TradingView chart embed w transakcji** — poza zakresem TradingView free API.
