# TraderLog — Biznes Plan

> **Wersja:** 1.0 · **Data:** Czerwiec 2026  
> **Typ produktu:** SaaS / EdTech · **Rynek:** Polska (ekspansja EU)

---

## 1. Wizja i Misja

**Wizja**  
Stać się systemem numer jeden w Polsce który zamienia wiedzę tradingową w nawyk, a nawyk w mierzalny postęp — dla każdego tradera który myśli o tym poważnie.

**Misja**  
TraderLog to system nawykowy dla tradera, nie aplikacja do analizy transakcji. Transakcje i statystyki są tylko danymi wejściowymi — efektem końcowym jest trwała zmiana zachowania użytkownika poprzez trzy filary:

**① STRUKTURA**  
Rytuały otwarcia i zamknięcia, podsumowania tygodniowe, miesięczne i roczne. Trader przestaje działać chaotycznie, zaczyna działać procesowo. Każdy dzień ma świadomy początek i koniec.

**② SAMOŚWIADOMOŚĆ**  
Dziennik emocji, oceny dyscypliny, tagi błędów. Trader zaczyna widzieć wzorce w swoim zachowaniu których wcześniej nie dostrzegał — "zawsze tracę w piątek po południu, zawsze overtradeuję po stratnej serii."

**③ KOREKTA**  
AI Coach który na podstawie danych z obu warstw mówi konkretnie: co powtarzasz, co cię kosztuje, jaki jeden krok wdrożyć w następnym tygodniu. Nie ogólne porady — spersonalizowana diagnoza oparta na rzeczywistych danych użytkownika.

> *"TraderLog to system który zamienia wiedzę tradingową w nawyk, a nawyk w mierzalny postęp — przez codzienną strukturę, głęboką samoświadomość i spersonalizowany coaching AI."*

---

## 2. Problem i Rozwiązanie

### Problem
- 80% początkujących traderów traci pieniądze nie z braku wiedzy, ale z braku dyscypliny i samoświadomości
- Istniejące narzędzia (Tradervue, Edgewonk) to kalkulatory wyników — pokazują liczby, ale nie zmieniają zachowania
- Nie ma platformy która zamyka pętlę: edukacja → praktyka → refleksja → korekta → nawyk
- Dostępne dzienniki są po angielsku, drogie i nie budują nawyku — użytkownik odpada po 2 tygodniach

### Różnica między TraderLog a konkurencją

| | Tradervue / Edgewonk | TraderLog |
|---|---|---|
| **Cel** | Analiza wyników | Zmiana zachowania |
| **Codzienne użycie** | Opcjonalne | Wbudowane w rutynę |
| **Psychologia** | Brak | Rdzeń produktu |
| **AI** | Brak lub szczątkowa | Personalny coach |
| **Kurs** | Brak | Zintegrowany lejek |
| **Język** | Angielski | Polski (+ ekspansja EU) |
| **Efekt** | Wiem jak grałem | Wiem jak się zmienić |

### Rozwiązanie
TraderLog zamyka pętlę której nie zamknął żaden konkurent:

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

## 3. Produkt

### 3.1 Moduły Aplikacji

| Moduł | Opis | Status |
|---|---|---|
| Dziennik transakcji | Import/ręczny wpis, screenshoty, tagi setupów | W budowie |
| Rutyna otwarcia | 5-punktowy Rytuał Otwarcia przed sesją | Do przepisania |
| Rutyna zamknięcia | 5-punktowy Rytuał Zamknięcia po sesji | Do przepisania |
| Podsumowanie tygodniowe | Review z transakcjami, refleksja, oceny | Bugfix w toku |
| Podsumowanie miesięczne | Metryki, top zagrania, cele | Do zbudowania |
| Podsumowanie roczne | Raport roczny, krzywa kapitału | Do zbudowania |
| AI Coach | Profil psychologiczny, tygodniowy raport | Planowany |
| Panel Admin | Analytics, ankiety, heatmapy | Planowany |
| Kurs tradingowy | Moduły wideo/tekst, quizy, integracja z dziennikiem | Planowany |

### 3.2 Rytuał Otwarcia (oryginalny ekran po zalogowaniu)

Użytkownik przechodzi przez 5 świadomych pytań przed otwarciem sesji:

1. **CIAŁO** — Czy jesteś wypoczęty i najedzony?
2. **UMYSŁ** — Czy wiesz co rynek robi dziś rano?
3. **PLAN** — Czy Twoje setupy są zidentyfikowane?
4. **GRANICE** — Czy znasz swój dzienny limit straty?
5. **INTENCJA** — Co chcesz osiągnąć podczas tej sesji?

### 3.3 Rytuał Zamknięcia (oryginalny ekran przed wylogowaniem)

1. **WYNIKI** — Jak zakończyłeś dzień finansowo?
2. **DYSCYPLINA** — Czy trzymałeś się swojego planu?
3. **EMOCJE** — Jak oceniasz swój stan przez całą sesję?
4. **LEKCJA** — Jedno zdanie: czego dowiedziałeś się dziś?
5. **RESET** — Jutro to nowy dzień. Zamknij notes.

### 3.4 AI Coach — Architektura

```
Dane wejściowe
  ├── Historia transakcji (wyniki, timing, RR, drawdown)
  ├── Wpisy emocji (tekst + oceny 1–10)
  ├── Compliance rutyn (ile % dni z wypełnioną rutyną)
  ├── Refleksje tygodniowe i miesięczne
  └── Postęp w kursie (ukończone moduły)
          │
          ▼
Baza wiedzy (RAG — embeddingi książek)
  ├── Mark Douglas — Trading in the Zone
  ├── Brett Steenbarger — Psychology of Trading
  ├── Daniel Kahneman — Thinking Fast and Slow
  ├── Robert Cialdini — Influence
  ├── Carol Dweck — Mindset
  └── James Clear — Atomic Habits
          │
          ▼
Profil psychologiczny użytkownika
  ├── Overtrader (za dużo transakcji, brak cierpliwości)
  ├── Revenge Trader (eskaluje po stratach)
  ├── Scared Trader (wychodzi za wcześnie z zysku)
  ├── Undisciplined (ignoruje plan)
  └── Consistent (wzorzec do utrzymania)
          │
          ▼
Output: Tygodniowy raport + rekomendacje + następny krok
```

---

## 4. Model Biznesowy

### 4.1 Warstwy Produktu

```
DARMOWE
└── Kurs tradingowy (pełny dostęp po rejestracji mailowej)
    └── Cel: budowanie bazy, zaufanie, edukacja

FREEMIUM
└── Dziennik transakcji (limit: 50 transakcji/miesiąc)
    └── Cel: onboarding, test wartości

PREMIUM — Plan Trader (płatny)
├── Nieograniczone transakcje
├── Podsumowania tygodniowe/miesięczne/roczne
├── AI Coach — tygodniowe raporty
├── Pełna historia i eksport danych
└── Priorytetowe wsparcie

PREMIUM — Plan Pro (wyższy tier, przyszłość)
├── AI Coach zaawansowany (profil psychologiczny)
├── Integracja broker API (auto-import)
├── Raport roczny z certyfikatem
└── Dostęp do grupy zamkniętej / mastermind
```

### 4.2 Cennik (propozycja)

| Plan | Cena | Cel |
|---|---|---|
| Kurs (darmowy) | 0 zł | Lejek, budowanie bazy |
| Freemium | 0 zł | Onboarding |
| Trader (miesięczny) | 49 zł/mies | Core revenue |
| Trader (roczny) | 399 zł/rok (~33 zł/mies) | Retencja |
| Pro (miesięczny) | 99 zł/mies | Power users |
| Pro (roczny) | 799 zł/rok (~67 zł/mies) | LTV |

### 4.3 Projekcje Przychodów

| Scenariusz | Użytkownicy płatni | Średni ARPU | MRR |
|---|---|---|---|
| Konserwatywny (rok 1) | 200 | 45 zł | 9 000 zł |
| Bazowy (rok 1) | 500 | 50 zł | 25 000 zł |
| Optymistyczny (rok 2) | 2 000 | 55 zł | 110 000 zł |

---

## 5. Rynek

### 5.1 Segment docelowy

**Persona główna: "Ambitny Początkujący"**
- 25–40 lat, Polska
- 6–24 miesięcy doświadczenia w tradingu
- Traci pieniądze lub osiąga słabe wyniki
- Szuka struktury i systemu, nie kolejnych sygnałów
- Gotowy płacić za narzędzie które faktycznie pomaga

**Persona drugorzędna: "Średniozaawansowany Trader"**
- 2–5 lat doświadczenia
- Chce wyjść z plateau wyników
- Rozumie wartość psychologii tradingu
- Porównuje z Tradervue/Edgewonk

### 5.2 Wielkość rynku (Polska)

- ~300 000 aktywnych traderów detalicznych w Polsce (szacunek)
- ~50 000 traderzy którzy aktywnie szukają edukacji i narzędzi
- ~5 000 potencjalnych klientów płatnych w roku 1 (10% addressable)

### 5.3 Przewaga konkurencyjna

| Cecha | TraderLog | Tradervue | Edgewonk |
|---|---|---|---|
| Język | Polski | Angielski | Angielski |
| AI Coach | Tak (planowany) | Nie | Nie |
| Psychologia tradingu | Tak (wbudowana) | Nie | Częściowo |
| Kurs zintegrowany | Tak | Nie | Nie |
| Rutyny mentalne | Tak | Nie | Nie |
| Cena (miesięczna) | ~49 zł | ~$30 | ~€30 |

---

## 6. Marketing i Akwizycja

### 6.1 Lejek pozyskiwania

```
Świadomość
  └── Content marketing (YT, TikTok, Instagram — trading tips)
  └── SEO: "dziennik tradera", "psychologia tradingu"
  └── Kurs darmowy jako lead magnet

Zainteresowanie
  └── Kurs → naturalne przejście do dziennika
  └── Demo dziennika bez rejestracji

Konwersja
  └── Freemium → limit 50 transakcji → upsell do płatnego
  └── Trial 14 dni planu Trader

Retencja
  └── AI Coach, streak, tygodniowe raporty
  └── Email z podsumowaniem tygodnia
  └── Powiadomienia push (rutyna)
```

### 6.2 Kanały

| Kanał | Priorytet | Opis |
|---|---|---|
| YouTube | Wysoki | Kurs tradingowy + treści edukacyjne |
| TikTok / Instagram Reels | Wysoki | Krótkie tips, screeny z dziennika |
| SEO / Blog | Średni | Artykuły o psychologii tradingu |
| Grupy FB/Discord | Wysoki | Community building, direct engagement |
| Referral program | Średni | "Zaproś tradera, oboje dostajecie miesiąc gratis" |
| Paid ads (Meta) | Niski (start) | Po ugruntowaniu organicznego |

---

## 7. Technologia

### 7.1 Stack technologiczny

```
Frontend:     Next.js 14 + TypeScript + Tailwind CSS
Backend:      Node.js / Supabase (BaaS)
Baza danych:  PostgreSQL (Supabase) + pgvector (AI embeddingi)
Auth:         Supabase Auth / Clerk
Storage:      Supabase Storage (screenshoty)
AI:           Anthropic Claude API (claude-sonnet-4)
Embeddingi:   OpenAI text-embedding-3-small + pgvector
Płatności:    Stripe
Analytics:    PostHog (self-hosted)
Email:        Resend
Hosting:      Vercel (frontend) + Supabase (backend)
```

### 7.2 Priorytety techniczne (kolejność)

1. **Bugfixes krytyczne** — routing, auto-uzupełnianie tygodni, podgląd transakcji w weekly summary
2. **Podsumowanie miesięczne i roczne** — nowe widoki
3. **Ekrany rutyny** — oryginalne treści po polsku
4. **Panel admin** — analytics, ankiety
5. **AI Coach v1** — tygodniowy raport tekstowy
6. **Baza wiedzy RAG** — embeddingi książek
7. **Kurs** — integracja z dziennikiem
8. **AI Coach v2** — pełne profilowanie psychologiczne

---

## 8. Harmonogram

| Faza | Czas | Deliverables |
|---|---|---|
| Faza 0 — Stabilizacja | Tyg. 1–2 | Bugfixes, podsumowania, nowe ekrany rutyny |
| Faza 1 — Admin & Feedback | Tyg. 2–4 | Panel admin, ankiety, analytics |
| Faza 2 — AI Coach v1 | Tyg. 4–8 | Tygodniowy raport AI, podstawowe profilowanie |
| Faza 3 — Kurs | Tyg. 6–12 | Struktura kursu, integracja kurs↔dziennik |
| Faza 4 — AI Coach v2 | Tyg. 10–16 | RAG, baza wiedzy, pełny profil psychologiczny |
| Faza 5 — Growth | Tyg. 14+ | Referral, paid, skalowanie |

---

## 9. Metryki Sukcesu (KPIs)

### Produkt
- **DAU/MAU ratio** > 40% (cel: użytkownicy wracają regularnie)
- **Completion rate rutyny** > 60% (użytkownicy kończą ekrany)
- **Streak średni** > 7 dni po 30 dniach użytkowania
- **Weekly summary completion** > 50% aktywnych użytkowników

### Biznes
- **MRR** — miesięczny wzrost > 15% (faza growth)
- **Churn rate** < 8% miesięcznie
- **LTV/CAC** > 3:1
- **NPS** > 40

### AI Coach
- **Open rate raportów tygodniowych** > 65%
- **Actionability score** (czy użytkownicy wdrażają rekomendacje) — ankieta

---

## 10. Ryzyka i Mitigacja

| Ryzyko | Prawdopodobieństwo | Wpływ | Mitigacja |
|---|---|---|---|
| Niska retencja (brak nawyku) | Wysokie | Krytyczny | Hooked Model, streak, AI raporty |
| Koszt API Claude (skalowanie) | Średnie | Wysoki | Cache, batching, limity per plan |
| Konkurencja zachodnia (PL wersja) | Średnie | Średni | Silna społeczność, UX w języku, integracja kursu |
| Brak płatnych konwersji | Średnie | Krytyczny | Freemium dobrze skrojony, jasna wartość Pro |
| Problemy prawne (RODO, dane finansowe) | Niskie | Wysoki | Polityka prywatności, dane na EU serwerach |

---

## 11. Zespół (docelowy)

| Rola | Czas | Priorytet |
|---|---|---|
| Founder / Product Owner | Full-time | Teraz |
| Senior Frontend Dev | Full-time | Faza 1 |
| Backend / AI Engineer | Full-time | Faza 2 |
| Content Creator (kurs + social) | Part-time | Faza 1 |
| Customer Success | Part-time | Faza 3 |

---

## 12. Podsumowanie Inwestycyjne

**Co budujemy:** Pierwszą polskojęzyczną platformę łączącą edukację tradingową, dziennik transakcji i AI coaching psychologiczny.

**Dlaczego teraz:** Rosnący rynek retailowych traderów w Polsce + AI jako enabler spersonalizowanego coachingu który wcześniej był nieosiągalny cenowo.

**Przewaga:** Język, rutyny mentalne, integracja kurs↔narzędzie, AI profilowanie na bazie literatury psychologicznej.

**Potrzeba:** Stabilizacja produktu (bugfixes), uruchomienie AI Coach v1, skalowanie content marketingu.

**Cel 12 miesięcy:** 500 płatnych użytkowników · 25 000 zł MRR · NPS > 40

---

## 13. Strategia Internacjonalizacji (i18n)

> **Zasada:** Jedna platforma, wiele języków. Nigdy osobna aplikacja.

### 13.1 Filozofia

Budujemy jeden produkt technologiczny który obsługuje wszystkie rynki. Osobna platforma per kraj oznacza podwójne koszty developmentu, podwójne bugfixowanie i rozjazd funkcjonalności między wersjami. Właściwe podejście to **i18n (internationalization)** — architektura w której interfejs przełącza się językowo, a rdzeń produktu pozostaje jeden.

### 13.2 Architektura Techniczna

**Stack:** Next.js + `next-intl` (rekomendowany) lub `next-i18next`

```
/locales
  /pl
    common.json        ← UI ogólny
    journal.json       ← Dziennik transakcji
    routine.json       ← Rytuały otwarcia/zamknięcia
    ai-coach.json      ← Raporty AI
    course.json        ← Kurs tradingowy
  /en
    common.json
    journal.json
    routine.json
    ai-coach.json
    course.json
  /de                  ← Faza 3 (DACH)
    ...
```

**Kluczowa zasada od dziś:** Żadnych hardcodowanych stringów w komponentach. Każdy tekst interfejsu przez zmienną — nawet zanim wdrożysz pełny system i18n.

```tsx
// ŹLE — hardcode
<h1>Rytuał Otwarcia</h1>

// DOBRZE — gotowe na i18n
<h1>{t('routine.opening.title')}</h1>
```

**Wykrywanie języka:**
1. Parametr URL: `traderlog.app/en/dashboard`
2. Ustawienie konta użytkownika (override)
3. Automatyczne z `Accept-Language` przeglądarki

### 13.3 Mapa Ekspansji Rynkowej

| Faza | Rynek | Język | Trigger | Szacowany czas |
|---|---|---|---|---|
| **Faza 0** | Polska | Polski | Teraz — buduj i waliduj | 2026 |
| **Faza 1** | UK / Ireland | Angielski | 1 000 PL użytkowników płatnych | Q1 2027 |
| **Faza 2** | Czechy / Słowacja | Angielski (bridge) | Produkt stabilny EN | Q2 2027 |
| **Faza 3** | DACH (DE/AT/CH) | Niemiecki | 500 EN użytkowników | Q3 2027 |
| **Faza 4** | Reszta EU | Angielski | Organiczny wzrost | 2028 |
| **Faza 5** | USA / Kanada | Angielski US | Funding lub silny organics | 2028+ |

### 13.4 Co wymaga lokalizacji (nie tylko tłumaczenia)

Tłumaczenie to minimum. Prawdziwa lokalizacja oznacza:

| Element | Polska | Angielski (UK/US) | Niemcy |
|---|---|---|---|
| Waluta w przykładach | PLN / złoty | GBP / USD | EUR |
| Przykłady instrumentów | WIG20, PKN, CD Projekt | FTSE, S&P500, Apple | DAX, BASF, Volkswagen |
| Styl komunikacji | Bezpośredni, motywacyjny | Professional, data-driven | Formalny, precyzyjny |
| Regulacje (disclaimer) | KNF | FCA | BaFin |
| Format daty | DD.MM.YYYY | MM/DD/YYYY | DD.MM.YYYY |
| Strefa czasowa sesji | CET/CEST | GMT/BST | CET/CEST |

### 13.5 AI Coach na Rynkach Zagranicznych

AI Coach musi generować analizy w języku użytkownika. Podejście:

```
Prompt systemowy AI:
"Respond in {user.language}. Use trading examples
relevant to {user.market} (instruments, sessions, timezone).
Apply psychological frameworks from: {knowledge_base}."
```

Baza wiedzy (książki) jest universalna — psychologia tradingu nie ma języka. Embeddingi działają wielojęzycznie przez modele `multilingual-e5` lub `text-embedding-3-large`.

### 13.6 Kurs Tradingowy — Wersje Językowe

Kurs wymaga osobnej strategii bo to content wideo/tekstowy, nie interfejs:

- **Wariant A (szybki):** Kurs PL z angielskimi napisami → test zainteresowania EN rynku bez nagrywania od nowa
- **Wariant B (docelowy):** Osobne nagrania EN — inny styl, inne przykłady rynkowe
- **Wariant C (skalowanie):** AI dubbing / transkrypcja → automatyczne tłumaczenie przy niższym koszcie

Rekomendacja: zacznij od Wariantu A jako MVP internacjonalizacji kursu.

### 13.7 Branding i Pozycjonowanie per Rynek

Jedna marka `TraderLog` działa globalnie — nazwa jest anglojęzyczna z założenia, co ułatwia ekspansję. Nie zmieniaj nazwy per rynek.

Dostosuj jedynie:
- Tagline: PL _"Zamień trading w nawyk"_ → EN _"Turn trading into mastery"_
- Testimoniale i case studies z lokalnych traderów
- Pricing w lokalnej walucie (Stripe obsługuje automatycznie)
- Landing page z lokalnymi przykładami i regulatorami

### 13.8 Metryki Gotowości do Ekspansji

Przed wejściem na nowy rynek sprawdź:

- [ ] Compliance rate rutyn w PL > 55% (produkt buduje nawyk)
- [ ] NPS > 40 w PL (użytkownicy polecają)
- [ ] Churn < 8%/miesiąc (retencja działa)
- [ ] AI Coach v1 live i używany przez > 30% bazy
- [ ] Kod i18n wdrożony (wszystkie stringi w plikach językowych)
- [ ] EN tłumaczenie interfejsu gotowe
- [ ] Stripe skonfigurowany dla GBP/EUR

### 13.9 Koszt Wdrożenia i18n

| Zadanie | Nakład | Kiedy |
|---|---|---|
| Refaktor stringów w kodzie (ekstrakcja do plików) | 3–5 dni | Faza 0 (teraz, przy okazji bugfixów) |
| Wdrożenie `next-intl` + routing językowy | 2–3 dni | Faza 0 |
| Tłumaczenie interfejsu PL → EN | 2–3 dni (AI + review) | Przed Fazą 1 |
| Lokalizacja AI Coach promptów | 1–2 dni | Przed Fazą 1 |
| Tłumaczenie kursu (napisy EN) | 1 tydzień | Faza 1 |
| **Łącznie do pierwszego rynku EN** | **~3 tygodnie** | Q4 2026 |

---

## 14. Ekosystem Produktowy

> **Zasada:** Jedno konto TraderLog — cztery warstwy wartości. Im więcej warstw użytkownik aktywuje, tym silniejszy lock-in i bogatsza analiza AI.

### 14.1 Mapa Ekosystemu

```
TraderLog Ecosystem
│
├── 📓  WARSTWA 1 — Dziennik (core)
│         Dziennik transakcji, rutyny, AI Coach, kurs
│         → Fundament. Każdy użytkownik zaczyna tutaj.
│
├── 📊  WARSTWA 2 — Wskaźniki
│         Płatne i darmowe wskaźniki dla TradingView, MT4/5, cTrader
│         → Drugi produkt. Osobny cennik, centralny system licencji.
│
├── 🤖  WARSTWA 3 — Boty Handlowe
│         Strategie automatyczne, sygnały w chmurze, agent lokalny
│         → Trzeci produkt. Model hybrid: sygnały cloud, egzekucja u usera.
│
└── 🧠  WARSTWA 4 — AI Market Intelligence
          Analiza wykresów ze screena + wpływ newsów na cenę
          → Czwarty produkt. Wbudowany w dziennik i boty.
```

### 14.2 Warstwa 2 — System Wskaźników

#### Platformy docelowe

| Platforma | Język | Trudność licencji | Priorytet |
|---|---|---|---|
| TradingView | Pine Script | Brak (wbudowany system TV) | Wysoki |
| MetaTrader 4/5 | MQL4/5 | Własny backend licencji | Wysoki |
| cTrader | C# / cAlgo | Własny backend licencji | Średni |
| NinjaTrader | NinjaScript (C#) | Własny backend licencji | Niski |
| ThinkOrSwim | thinkScript | Własny backend licencji | Niski |

#### TradingView — Model Licencji (najprostszy)

TradingView ma wbudowany system `invite-only` i `paid scripts`. Nie piszesz systemu licencji — platforma robi to za Ciebie:

1. Publikujesz skrypt jako `invite-only`
2. Stripe webhook `subscription.created` → Twój backend wywołuje TV API → dodaje użytkownika
3. Stripe webhook `subscription.deleted` → Twój backend wywołuje TV API → usuwa dostęp
4. TradingView egzekwuje dostęp automatycznie

#### MT4/MT5 — Centralny System Licencji

Wskaźnik przy każdym starcie odpytuje Twój serwer:

```
Wskaźnik (MT4/5)                    TraderLog Backend
       │                                    │
       │── GET /api/license/validate ──────►│
       │   { key, hwid, platform }          │
       │                                    │ sprawdź:
       │                                    │ • klucz istnieje?
       │                                    │ • subskrypcja aktywna?
       │                                    │ • HWID zgodny?
       │◄── { valid, expiresAt, tier } ─────│
       │                                    │
  valid=true → działa                  valid=false
  valid=false → wyłącza się            → log incydentu
```

**HWID (Hardware ID)** — fingerprint maszyny użytkownika. Zapobiega współdzieleniu jednej licencji. Generowany z: MAC address + CPU ID + nazwa komputera → hash SHA256.

#### Architektura Backendu Licencji

```
/api/license
  ├── POST /activate        ← po zakupie, generuje klucz + przypisuje HWID
  ├── GET  /validate        ← wskaźnik odpytuje przy starcie (co 24h cache)
  ├── POST /revoke          ← webhook Stripe subscription.deleted
  ├── POST /transfer        ← user zmienia komputer (reset HWID, limit 2x/rok)
  └── GET  /status          ← panel użytkownika: aktywne licencje

Baza danych:
licenses {
  id, user_id, product_id, platform,
  license_key (UUID),
  hwid_hash,
  status (active | expired | revoked),
  stripe_subscription_id,
  created_at, expires_at,
  last_validated_at
}
```

#### Przepływ Stripe ↔ Licencje

```
Zakup subskrypcji (Stripe)
        ↓
Webhook: customer.subscription.created
        ↓
Backend: generuje license_key → wysyła email z kluczem i instrukcją
        ↓
User instaluje wskaźnik + wpisuje klucz
        ↓
Wskaźnik: POST /activate { key, hwid }
        ↓
[aktywna subskrypcja]
        ↓ (co miesiąc/rok odnowienie)
Webhook: invoice.payment_succeeded → status: active, expires_at += period
        ↓
[brak płatności]
        ↓
Webhook: customer.subscription.deleted
        ↓
Backend: status = expired
        ↓
Następne uruchomienie wskaźnika → valid: false → wyłączenie
```

#### Tiery Wskaźników

| Tier | Cena | Zawartość |
|---|---|---|
| Free | 0 zł | 1–2 podstawowe wskaźniki, watermark |
| Starter | 29 zł/mies | Pakiet wskaźników technicznych |
| Pro | 69 zł/mies | Pełny pakiet + priorytetowe update'y |
| Bundle | 99 zł/mies | Wskaźniki + Dziennik TraderLog Pro |

---

### 14.3 Warstwa 3 — Boty Handlowe

#### Model Dystrybucji: Hybrid (rekomendowany)

```
TraderLog Cloud                    User (lokalnie / VPS)
      │                                    │
      │  Strategia + obliczenia            │
      │  Sygnały (BUY/SELL/CLOSE)          │
      │──────── WebSocket feed ───────────►│
      │                                    │ Agent lokalny
      │                                    │ (Python / EA)
      │                                    │     │
      │                                    │     ▼
      │                                    │ Broker API
      │                                    │ (egzekucja)
      │◄──────── wynik zlecenia ───────────│
```

**Dlaczego hybrid:**
- Ty nie dotykasz pieniędzy użytkownika → brak ryzyka regulacyjnego
- Strategia i sygnały chronione po Twojej stronie (IP protection)
- User ma pełną kontrolę nad egzekucją i może wyłączyć w każdej chwili

#### Stack Techniczny Botów

```
Backend sygnałów:
  Python 3.11+
  ├── freqtrade / backtrader  — logika strategii + backtesting
  ├── FastAPI                  — REST API + WebSocket sygnałów
  ├── Celery + Redis           — kolejkowanie zadań, scheduled jobs
  └── PostgreSQL               — historia sygnałów, wyniki, logi

Agent lokalny (u użytkownika):
  Python lub C# (MT4/5 EA)
  ├── Odbiera sygnały przez WebSocket
  ├── Weryfikuje licencję (tak samo jak wskaźniki)
  ├── Egzekwuje przez API brokera
  └── Odsyła wyniki do TraderLog (automatyczny wpis w dzienniku!)
```

#### Automatyczna Integracja z Dziennikiem

To kluczowa przewaga ekosystemu: każde zlecenie bota **automatycznie trafia do dziennika TraderLog** z pełnymi danymi. AI Coach widzi transakcje manualne i automatyczne razem — i może porównać skuteczność.

```
Bot wykonuje transakcję
        ↓
Agent lokalny: POST /api/journal/auto-import
{ symbol, direction, entry, exit, pnl, strategy, timestamp }
        ↓
Dziennik: nowy wpis z tagiem "BOT: {strategy_name}"
        ↓
AI Coach: uwzględnia w analizie tygodniowej
```

---

### 14.4 Warstwa 4 — AI Market Intelligence

#### Silnik 1: Analiza Wykresu ze Screena

Użytkownik uploaduje screenshot wykresu (lub bot wysyła automatycznie):

```javascript
// Prompt do Claude Vision API
{
  model: "claude-sonnet-4-20250514",
  messages: [{
    role: "user",
    content: [
      {
        type: "image",
        source: { type: "base64", media_type: "image/png", data: chartBase64 }
      },
      {
        type: "text",
        text: `Analizujesz wykres tradingowy. Zidentyfikuj:
        1. Trend główny (UP/DOWN/SIDEWAYS) + timeframe
        2. Kluczowe poziomy wsparcia i oporu (max 3 każdy)
        3. Formacje świecowe lub cenowe (jeśli widoczne)
        4. Wolumen (rosnący/malejący/neutralny)
        5. Bias ogólny: BULLISH / BEARISH / NEUTRAL
        6. Poziomy do obserwacji w następnych godzinach
        Odpowiedz w JSON: { trend, support[], resistance[], patterns[], 
        volume, bias, confidence, keyLevels[], notes }`
      }
    ]
  }]
}
```

**Gdzie używane:**
- Przy dodawaniu transakcji do dziennika → "Przeanalizuj mój setup"
- W module podsumowania tygodnia → "Oceń moje screenshoty z tego tygodnia"
- W bocie → automatyczna analiza przed sygnałem

#### Silnik 2: Analiza Newsów → Wpływ na Cenę

```
Źródła newsów (pipeline):
  NewsAPI / Finnhub / Alpha Vantage
        ↓
  Filtrowanie: instrumenty obserwowane przez użytkownika
        ↓
  Claude API:
  "Wydarzenie: {news_title + summary}
   Instrument: {symbol} ({asset_class})
   Kontekst rynkowy: {current_trend}
   
   Oceń:
   1. Kierunek potencjalnego ruchu: UP / DOWN / NEUTRAL
   2. Siła impulsu: STRONG / MODERATE / WEAK
   3. Timeframe efektu: IMMEDIATE (<1h) / SHORT (1–24h) / LONG (1–7d)
   4. Confidence: HIGH / MEDIUM / LOW
   5. Historyczne analogi (jeśli znane)
   6. Co obserwować jako potwierdzenie
   
   Output: JSON strukturyzowany"
        ↓
  Push notification + zapis w dzienniku
  (użytkownik może kliknąć "Wszedłem w tę transakcję")
```

#### Źródła Danych Newsów

| Źródło | Cena | Jakość | Użycie |
|---|---|---|---|
| NewsAPI.org | Darmowy (100 req/dzień) | Średnia | MVP, testy |
| Finnhub | Freemium (60 req/min) | Dobra | Faza 1 |
| Alpha Vantage | Freemium | Dobra | Faza 1 |
| Benzinga Pro API | ~$50/mies | Bardzo dobra | Faza 2 |
| Reuters / Bloomberg | $$$$ | Profesjonalna | Faza 4+ |

---

### 14.5 Cennik Ekosystemu

```
┌─────────────────────────────────────────────────────┐
│                  TRADERLOG ECOSYSTEM                │
├──────────────┬──────────────┬──────────────┬────────┤
│   DZIENNIK   │  WSKAŹNIKI   │    BOTY      │  AI    │
├──────────────┼──────────────┼──────────────┼────────┤
│ Free         │ Free (1 wsk) │ —            │ Basic  │
│ 0 zł         │ 0 zł         │              │        │
├──────────────┼──────────────┼──────────────┼────────┤
│ Trader       │ Starter      │ —            │ Coach  │
│ 49 zł/mies   │ 29 zł/mies   │              │ v1     │
├──────────────┼──────────────┼──────────────┼────────┤
│ Pro          │ Pro          │ Bot Basic    │ Coach  │
│ 99 zł/mies   │ 69 zł/mies   │ 149 zł/mies  │ v2     │
├──────────────┴──────────────┴──────────────┴────────┤
│              BUNDLE ALL-IN-ONE                      │
│              249 zł/mies (oszczędzasz ~40%)         │
└─────────────────────────────────────────────────────┘
```

### 14.6 Flywheel Ekosystemu

Im więcej warstw użytkownik aktywuje, tym produkt staje się cenniejszy i trudniejszy do porzucenia:

```
Dziennik (dane manualne)
    +
Wskaźniki (dane z wykresów)
    +
Boty (dane automatyczne)
    +
AI Intelligence (dane rynkowe)
         ↓
AI Coach ma pełny obraz tradera:
manualne + automatyczne + rynkowe + psychologiczne
         ↓
Analiza nieosiągalna nigdzie indziej
         ↓
Silny lock-in + wysoki LTV + naturalny upsell
```

### 14.7 Harmonogram Warstw

| Warstwa | Start | MVP | Dojrzały produkt |
|---|---|---|---|
| Dziennik (core) | Teraz | Q3 2026 | Q4 2026 |
| AI w dzienniku (screen) | Q3 2026 | Q4 2026 | Q1 2027 |
| Wskaźniki TradingView | Q4 2026 | Q1 2027 | Q2 2027 |
| Wskaźniki MT4/5 | Q1 2027 | Q2 2027 | Q3 2027 |
| AI News Intelligence | Q1 2027 | Q2 2027 | Q3 2027 |
| Boty Handlowe | Q2 2027 | Q4 2027 | Q1 2028 |

---

## 15. Zaktualizowane Cele

| Horyzont | Cel | Główny Driver |
|---|---|---|
| 12 mies. (PL, Dziennik) | 500 płatnych · 25 000 zł MRR | Dziennik + kurs |
| 18 mies. (PL+EN) | 1 200 płatnych · 60 000 zł MRR | Ekspansja EN + wskaźniki TV |
| 24 mies. (EU + Wskaźniki) | 3 000 płatnych · 150 000 zł MRR | Ekosystem 2 warstwy |
| 36 mies. (Ekosystem) | 8 000 płatnych · 400 000 zł MRR | Boty + AI Intelligence |
| 48 mies. | 20 000 płatnych · Seed funding | Pełny ekosystem |

---

*TraderLog — Zamień trading w nawyk, nawyk w wyniki.*  
*Turn trading into mastery.*
