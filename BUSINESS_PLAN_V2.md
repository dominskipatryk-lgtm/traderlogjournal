# TraderLog — Biznes Plan V2

> **Wersja:** 2.0 · **Data:** Czerwiec 2026  
> **Zmiana względem V1:** usunięto Warstwę Botów (przeniesiona do Plan B), dodano Capacitor Mobile, doprecyzowano AI Coach, uzupełniono pominięte obszary.  
> **Poprzednia wersja:** `BUSINESS_PLAN.md` — zachowana bez zmian, może być przydatna w przyszłości.

---

## 1. Wizja i Misja

**Wizja**  
Pierwsza polskojęzyczna platforma która zamienia wiedzę tradingową w nawyk, a nawyk w mierzalny postęp — przez codzienną strukturę, głęboką samoświadomość i spersonalizowany coaching AI.

**Misja**  
TraderLog to system nawykowy dla tradera, nie aplikacja do analizy transakcji. Trzy filary:

**① STRUKTURA** — Rytuały otwarcia i zamknięcia, podsumowania tygodniowe, miesięczne i roczne.  
**② SAMOŚWIADOMOŚĆ** — Dziennik emocji, oceny dyscypliny, tagi błędów. Trader widzi wzorce których wcześniej nie dostrzegał.  
**③ KOREKTA** — AI Coach oparty na danych użytkownika: konkretna diagnoza, nie ogólne porady.

---

## 2. Problem i Rozwiązanie

### Problem
- 80% traderów traci nie z braku wiedzy, ale z braku dyscypliny i samoświadomości
- Istniejące narzędzia (Tradervue, Edgewonk) to kalkulatory wyników — nie zmieniają zachowania
- Brak platformy która zamyka pętlę: praktyka → refleksja → korekta → nawyk
- Dostępne dzienniki są po angielsku, drogie, bez mechanizmów budowania nawyku

### Rozwiązanie

```
Wiedza (kurs)
    ↓
Praktyka (dziennik transakcji)
    ↓
Refleksja (rutyny + podsumowania)
    ↓
Korekta (AI Coach)
    ↓
Nawyk (powrót każdego dnia)
    ↓
Mierzalny postęp
```

---

## 3. Ekosystem Produktowy — 3 Warstwy

> Boty handlowe (Warstwa 4 z V1) przeniesione do Plan B — patrz sekcja 16.

```
TraderLog Ecosystem
│
├── 📓  WARSTWA 1 — Dziennik (core)
│         Dziennik transakcji, rutyny, AI Coach, kurs
│         → Fundament. Każdy użytkownik zaczyna tutaj.
│
├── 📊  WARSTWA 2 — Wskaźniki
│         TradingView Pine Script, MT4/MT5 indicators
│         Centralny system licencji (Stripe ↔ backend)
│
└── 🧠  WARSTWA 3 — AI Market Intelligence
          Analiza wykresów ze screenshotów (Claude Vision)
          Wpływ newsów na cenę (pipeline + push notification)
```

### Flywheel ekosystemu

Im więcej warstw użytkownik aktywuje, tym AI Coach ma pełniejszy obraz i produkt staje się trudniejszy do porzucenia:

```
Dziennik (dane manualne + emocje)
    +
Wskaźniki (dane z wykresów, setup quality)
    +
AI Market Intelligence (kontekst rynkowy)
         ↓
AI Coach: analiza nieosiągalna nigdzie indziej
         ↓
Silny lock-in + wysoki LTV + naturalny upsell
```

---

## 4. Produkt — Moduły

| Moduł | Opis | Status |
|---|---|---|
| Dziennik transakcji | Import/ręczny wpis, screenshoty, tagi setupów | ✅ Działa |
| Rytuał Otwarcia | 5-punktowy ekran przed sesją (oryginalny PL) | 🔧 Bugfix |
| Rytuał Zamknięcia | 5-punktowy ekran po sesji (oryginalny PL) | 🔧 Bugfix |
| Podsumowanie tygodniowe | Review + status reviewed/draft | 🔧 Bugfix |
| Podsumowanie miesięczne | Metryki, top zagrania, refleksja, cele | 🏗 Do zbudowania |
| Podsumowanie roczne | Raport roczny, krzywa kapitału | 🏗 Do zbudowania |
| Habit Tracker | Kolorowy kalendarz dyscypliny w dzienniku | ✅ Działa |
| Dzienny Score 0–100 | Karta w dashboardzie | ✅ Działa |
| Ankieta post-trade | Survey popup, detail view, emotions stats | ✅ Działa |
| Portfel inwestycyjny | ETF/akcje/obligacje/krypto + auto-ceny | ✅ Działa |
| Import CSV | MT4/MT5/Bybit/MEXC/TradingView | ✅ Działa |
| Biblioteka zasobów | PDF/pliki admin→user, Supabase Storage | ✅ Działa |
| AI Coach v1 | Tygodniowy raport tekstowy | 🏗 Faza 2 |
| AI Analiza Wykresu | Claude Vision na screenshot | 🏗 Faza 4 |
| Wskaźniki TradingView | Pine Script + system licencji | 🏗 Faza 3 |
| Wskaźniki MT4/MT5 | MQL4/5 + HWID licencja | 🏗 Faza 3 |
| Aplikacja Mobilna | Capacitor (iOS + Android) | 🏗 Faza 1.5 |
| Kurs tradingowy | Moduły wideo/tekst, integracja z dziennikiem | 🏗 Faza 3 |
| Panel Admin | Analytics, użytkownicy, retencja | 🏗 Faza 1 |

### 4.1 Rytuał Otwarcia

```
① CIAŁO     — Czy jesteś wypoczęty i najedzony?
② UMYSŁ     — Czy wiesz co rynek robi dziś rano?
③ PLAN      — Czy Twoje setupy na dziś są zidentyfikowane?
④ GRANICE   — Czy znasz swój dzienny limit straty?
⑤ INTENCJA  — Co chcesz osiągnąć podczas tej sesji?
```

### 4.2 Rytuał Zamknięcia

```
① WYNIKI      — Jak zakończyłeś dzień finansowo?
② DYSCYPLINA  — Czy trzymałeś się swojego planu? (skala 1–5)
③ EMOCJE      — Jak oceniasz swój stan przez całą sesję? (skala 1–5)
④ LEKCJA      — Jedno zdanie: czego nauczyłeś się dziś? (wymagane)
⑤ RESET       — Jutro to nowy dzień. Zamknij notes.
```

---

## 5. AI Coach — Architektura

### Jak działa (uczenie przez kontekst, nie fine-tuning)

Claude nie aktualizuje wag na podstawie danych użytkownika. Zamiast tego każda sesja AI Coacha otrzymuje coraz bogatszy kontekst:

```
Tydzień 1:  ogólna analiza (brak historii)
Tydzień 8:  47 transakcji + 3 wzorce błędów + styl ICT +
            12 korekt użytkownika + 2 miesiące weekly reviews
            → spersonalizowana diagnoza
```

Efekt dla użytkownika jest identyczny jak "uczenie się". Mechanizm to RAG (pgvector + embeddingi).

### Dane wejściowe

```
├── Historia transakcji (wyniki, timing, RR, drawdown)
├── Wpisy emocji (tekst + oceny 1–10)
├── Compliance rutyn (ile % dni z wypełnioną rutyną)
├── Refleksje tygodniowe i miesięczne
├── Korekty użytkownika do poprzednich analiz (👍/👎)
└── Postęp w kursie (ukończone moduły)
```

### Baza wiedzy (RAG)

```
├── Mark Douglas — Trading in the Zone
├── Brett Steenbarger — Psychology of Trading
├── Daniel Kahneman — Thinking Fast and Slow
├── Carol Dweck — Mindset
└── James Clear — Atomic Habits
```

### Pętla walidacji (użytkownik ulepsza analizy)

```
Analiza wykresu → User 👍/👎 → Korekta zapisana → 
Lepsze analizy kolejnym razem
```

### AI w infrastrukturze (bez własnego serwera)

```
Browser → Supabase Storage (screenshot)
       → Supabase Edge Function (trzyma klucz API)
       → Claude Vision API
       → Wynik → DB + UI
```

Koszt Claude API rośnie liniowo z bazą: 500 userów × 5 analiz/tydzień ≈ $10/mies.

---

## 6. Aplikacja Mobilna — Capacitor

### Strategia

```
Obecny index.html (vanilla JS)
        ↓
Capacitor CLI
        ↓
  iOS (.ipa)          Android (.apk)
  App Store           Google Play
```

Żadne przepisanie kodu nie jest wymagane. Capacitor pakuje istniejącą aplikację webową.

### Co daje Capacitor ponad PWA

| Funkcja | PWA | Capacitor |
|---|---|---|
| Instalacja z App Store | Nie | Tak |
| Push notifications natywne | Ograniczone (iOS) | Tak |
| Touch ID / Face ID | Nie | Tak |
| Działanie offline | Częściowe | Pełne |
| Wiarygodność (App Store) | Niska | Wysoka |

### Wymagania techniczne

- Android: Windows + Android Studio + konto Google Play ($25 jednorazowo)
- iOS: Mac lub EAS Build cloud + konto Apple Developer ($99/rok)

---

## 7. Szyfrowanie Danych Konta

Dane konta u brokera szyfrowane przed zapisem do localStorage i Supabase:

| Pole | Szyfrowanie |
|---|---|
| Numer konta MT4 (login) | AES-GCM, Web Crypto API |
| Serwer brokera | AES-GCM |
| Nazwa brokera | AES-GCM |
| Hasło MT4 | Nie przechowujemy |

Klucz = pochodna z `user_id` + stały salt aplikacji → unikalny per user, spójny cross-device.

---

## 8. Stack Technologiczny

### Obecny (monolith)

```
Frontend:   vanilla JS + CSS, jeden plik index.html
Backend:    Supabase (PostgreSQL + Auth + Storage + Edge Functions)
Hosting:    GitHub Pages → traderlogjournal.com
Mobile:     Capacitor (Faza 1.5)
AI:         Claude Vision API przez Supabase Edge Function
Płatności:  Stripe (Faza 1)
Email:      Resend (Faza 1)
Analytics:  PostHog lub własny panel admin
```

### Decyzja o rewrite

**Monolith zostaje do walidacji monetyzacji.** Rewrite do Next.js 14 + TypeScript planowany po osiągnięciu pierwszych 200 płatnych użytkowników. Powód: rewrite teraz = 2–3 miesiące bez nowych funkcji, bez przychodu.

```
Teraz:    monolith + Capacitor + Stripe + Supabase Edge Functions
Faza 5+:  Next.js 14 + TypeScript + Tailwind (po walidacji)
```

---

## 9. Model Biznesowy

### Warstwy produktu

```
DARMOWE
└── Kurs tradingowy (pełny dostęp po rejestracji)
└── Dziennik: limit 50 transakcji/miesiąc (freemium)

TRADER — 49 zł/mies | 399 zł/rok
├── Nieograniczone transakcje
├── Podsumowania tygodniowe / miesięczne / roczne
├── Pełna historia i eksport danych
└── Priorytetowe wsparcie

PRO — 99 zł/mies | 799 zł/rok
├── Wszystko z Trader
├── AI Coach — tygodniowe raporty
├── Analiza wykresów (Claude Vision)
└── Profil psychologiczny

WSKAŹNIKI — osobna subskrypcja
├── Starter: 29 zł/mies
└── Pro: 69 zł/mies

BUNDLE — 149 zł/mies
└── Dziennik Pro + Wskaźniki Pro
```

### Projekcje przychodów

| Scenariusz | Płatni | ARPU | MRR |
|---|---|---|---|
| Konserwatywny (rok 1) | 200 | 45 zł | 9 000 zł |
| Bazowy (rok 1) | 500 | 50 zł | 25 000 zł |
| Optymistyczny (rok 2) | 1 200 | 55 zł | 66 000 zł |

---

## 10. Onboarding Nowego Użytkownika

Krytyczny element konwersji — brak dobrego onboardingu = churn po 3 dniach.

### Flow pierwszego dnia

```
Rejestracja / zaproszenie admina
        ↓
Ekran powitalny: "Zanim zaczniesz — 3 minuty setup"
        ↓
Krok 1: Dodaj pierwsze konto tradingowe
Krok 2: Ustaw dzienny limit straty
Krok 3: Wybierz godzinę przypomnienia o rytuałach
Krok 4: Pierwszy Rytuał Otwarcia (demo)
        ↓
Dashboard — z podpowiedzią "Dodaj pierwszą transakcję"
```

### Freemium limit (50 transakcji)

Gdy user osiąga 40 transakcji → banner "Zostało Ci 10 transakcji w planie Free".  
Gdy osiąga 50 → modal upsell z porównaniem planów + przycisk Stripe Checkout.

---

## 11. Email i Notyfikacje

| Email | Trigger | Narzędzie |
|---|---|---|
| Powitanie | Rejestracja | Resend |
| Podsumowanie tygodnia | Każdy poniedziałek 9:00 | Resend + Supabase CRON |
| Przypomnienie o planie | 3 dni bez wpisu | Resend |
| Upsell | Po 40 transakcjach | Resend |
| Nowe logowanie | Login z nowego urządzenia | Supabase Auth Hook |

Push notifications (po wdrożeniu Capacitor):
- Codzienne przypomnienie o Rytuale Otwarcia
- Przypomnienie o Rytuale Zamknięcia
- Alert o podsumowaniu tygodnia (poniedziałek)

---

## 12. Admin Panel

Niezbędny do podejmowania decyzji produktowych:

| Metryka | Opis |
|---|---|
| DAU / MAU | Aktywni użytkownicy dzienny / miesięczny |
| Completion rate rutyn | % dni z wypełnionym rytuałem |
| Weekly summary rate | % userów kończących weekly review |
| Streak average | Średnia długość passy |
| Conversion rate | Free → Paid |
| Churn rate | Odejścia miesięcznie |
| Feature usage | Które moduły są używane |

---

## 13. Bezpieczeństwo

| Element | Plan |
|---|---|
| Szyfrowanie danych konta | AES-GCM, Web Crypto API — Faza 0 |
| 2FA (Google Authenticator) | TOTP w Supabase Auth — Faza 1 |
| Session timeout | Auto-wylogowanie po X godzinach — Faza 1 |
| Email przy nowym logowaniu | Supabase Auth Hook — Faza 1 |
| RODO — export danych | Przycisk "Pobierz moje dane" (JSON/CSV) — Faza 1 |
| RODO — usunięcie konta | "Usuń konto i wszystkie dane" — Faza 1 |

---

## 14. RODO i AI

Privacy Policy wymaga aktualizacji przed wdrożeniem AI Coach:
- Przetwarzamy dane behawioralne (emocje, oceny, wzorce)
- Dane wysyłane do Claude API (Anthropic) — EU data processing agreement
- Użytkownik ma prawo do eksportu i usunięcia wszystkich danych
- Dane AI nie są używane do trenowania modelu (Anthropic API gwarantuje)

---

## 15. Harmonogram (zaktualizowany)

| Faza | Czas | Deliverables |
|---|---|---|
| **Faza 0** | Tyg. 1–2 | BUG-01/02/03, BUG-06/07, monthly/yearly summary, szyfrowanie kont, nowe rytuały |
| **Faza 1** | Tyg. 2–6 | Landing page, Stripe, freemium limit, onboarding, 2FA, session timeout, RODO (export/delete), admin panel v1, email (Resend) |
| **Faza 1.5** | Tyg. 4–8 | Capacitor: iOS + Android build, App Store / Play Store |
| **Faza 2** | Tyg. 6–12 | AI Coach v1 (tygodniowy raport), Supabase Edge Functions, pętla 👍/👎 |
| **Faza 3** | Tyg. 10–18 | Wskaźniki TradingView (Pine Script + licencje Stripe), kurs tradingowy v1 |
| **Faza 4** | Tyg. 14–22 | AI Analiza Wykresu (Claude Vision), AI News Intelligence, wskaźniki MT4/5 |
| **Faza 5** | Tyg. 18–28 | AI Coach v2 (RAG + profil psychologiczny), EN expansion, Next.js rewrite |
| **Plan B** | Gdy MRR > 50k zł | Boty handlowe (patrz BUSINESS_PLAN.md sekcja 14.3) |

---

## 16. Plan B — Boty Handlowe

Warstwa botów handlowych usunięta z aktywnego planu ze względu na:
- Ryzyko regulacyjne (MiFID II — dostarczanie sygnałów to działalność regulowana)
- Wysokie koszty infrastruktury
- Konieczność posiadania zespołu

**Architektura i specyfikacja zachowana w `BUSINESS_PLAN.md` sekcja 14.3.**  
Wrócimy do tematu gdy MRR > 50 000 zł/mies i będzie zespół.

---

## 17. Internacjonalizacja (i18n)

Bez zmian względem V1. Architektura `next-intl` planowana przy rewrite do Next.js.  
Obecny system: słowniki `T.pl` / `T.en` w kodzie — ekspansja EN możliwa bez rewrite.

Mapa ekspansji: PL (teraz) → EN UK/Ireland (Q1 2027) → DACH (Q3 2027) → EU (2028)

---

## 18. Metryki Sukcesu (KPIs)

### Produkt
- **DAU/MAU** > 40%
- **Completion rate rutyn** > 60%
- **Streak średni** > 7 dni po 30 dniach użytkowania
- **Weekly summary completion** > 50% aktywnych userów

### Biznes
- **MRR wzrost** > 15%/mies w fazie growth
- **Churn** < 8%/mies
- **LTV/CAC** > 3:1
- **NPS** > 40

### AI Coach (Faza 2+)
- **Open rate raportów** > 65%
- **Actionability score** (ankieta: czy wdrażasz rekomendacje) > 40%

---

## 19. Zaktualizowane Cele

| Horyzont | Cel | Driver |
|---|---|---|
| 12 mies. | 500 płatnych · 25 000 zł MRR | Dziennik + kurs |
| 18 mies. | 1 200 płatnych · 60 000 zł MRR | EN + wskaźniki TV |
| 24 mies. | 3 000 płatnych · 150 000 zł MRR | AI Coach + wskaźniki MT4/5 |
| 36 mies. | 8 000 płatnych · 400 000 zł MRR | Pełny ekosystem 3 warstwy |

---

## 20. Ryzyka i Mitigacja

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitigacja |
|---|---|---|---|
| Niska retencja (brak nawyku) | Wysokie | Krytyczny | Rytuały, streak, AI raporty, email |
| Koszt API Claude (skalowanie) | Średnie | Wysoki | Cache, batching, limity per plan |
| Konkurencja zachodnia (PL wersja) | Średnie | Średni | Społeczność, UX w języku, kurs |
| Brak konwersji freemium → paid | Średnie | Krytyczny | Freemium limit 50 trans., jasna wartość Pro |
| Problemy RODO (dane AI) | Niskie | Wysoki | DPA z Anthropic, export danych, delete account |
| Opóźnienie rewrite (dług techniczny) | Wysokie | Średni | Monolith do walidacji, rewrite po 200 userach |
| Odrzucenie z App Store | Niskie | Średni | Capacitor, guidelines compliance, PWA fallback |

---

*TraderLog — Zamień trading w nawyk, nawyk w wyniki.*  
*Turn trading into mastery.*
