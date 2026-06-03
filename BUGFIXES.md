# TraderLog — Lista Błędów do Naprawy

> **Dla developera** · Wersja: 1.0 · Data: Czerwiec 2026  
> Priorytet wykonania: od góry do dołu

---

## BUG-01 · KRYTYCZNY
### Podsumowanie tygodnia — auto-uzupełnianie bez akcji użytkownika

**Opis problemu:**  
Po imporcie danych tygodnie są automatycznie oznaczane jako "podsumowane" mimo że użytkownik nigdy nie wykonał podsumowania. Tygodnie wyglądają na zamknięte w UI choć użytkownik ich nie przerobił.

**Przyczyna:**  
Brak rozróżnienia między stanem `dane istnieją` a `podsumowanie zatwierdzone przez użytkownika`.

**Oczekiwane zachowanie:**  
- Import danych → tydzień ma status `draft` (dane są, ale nie przerobione)
- Użytkownik wypełnia i zatwierdza formularz podsumowania → status zmienia się na `reviewed`
- W UI tydzień bez akcji użytkownika NIE może wyglądać jak zamknięty

**Wymagane zmiany w bazie danych:**
```sql
ALTER TABLE weekly_summaries
  ADD COLUMN reviewed BOOLEAN DEFAULT FALSE,
  ADD COLUMN reviewed_at TIMESTAMP DEFAULT NULL;
```

**Wymagane zmiany w logice:**
- Import danych: ustawia `reviewed = false`, `reviewed_at = null`
- Zatwierdzenie formularza przez użytkownika: ustawia `reviewed = true`, `reviewed_at = NOW()`
- UI: wyświetla badge "Do uzupełnienia" gdy `reviewed = false` i dane istnieją
- UI: wyświetla badge "Zamknięty" TYLKO gdy `reviewed = true`

---

## BUG-02 · KRYTYCZNY
### Przypomnienie o podsumowaniu tygodnia → błędne przekierowanie

**Opis problemu:**  
Kliknięcie w powiadomienie / przypomnienie o podsumowaniu tygodnia przekierowuje użytkownika do ekranu rutyny dziennej zamiast do ekranu podsumowania tygodnia.

**Oczekiwane zachowanie:**  
Kliknięcie przypomnienia → `/weekly-summary/:weekId`

**Wymagane zmiany:**
- Znajdź miejsce w kodzie gdzie generowane jest powiadomienie o podsumowaniu tygodnia
- Zmień docelowy URL z obecnego (rutyna dzienna) na `/weekly-summary/:weekId`
- Dodaj parametr `weekId` odpowiadający tygodniowi który wymaga podsumowania
- Po zakończeniu podsumowania: redirect do rutyny przed sesją (nie przed podsumowaniem)

**Kolejność ekranów powinna być:**
```
Powiadomienie → Podsumowanie tygodnia → Rutyna przed sesją
```

---

## BUG-03 · WYSOKI
### Podsumowanie tygodnia — brak podglądu transakcji

**Opis problemu:**  
W ekranie tygodniowego review użytkownik widzi tylko liczby i sumy (ilość transakcji, łączny P&L). Nie ma wglądu w szczegóły poszczególnych transakcji — przez co nie może ocenić jakości swoich decyzji i wykonania.

**Oczekiwane zachowanie:**  
W widoku `/weekly-summary/:weekId` powinna znajdować się sekcja z listą wszystkich transakcji z danego tygodnia.

**Wymagane zmiany w UI — nowa sekcja "Transakcje tygodnia":**
- Lista transakcji z danego tygodnia (posortowana chronologicznie)
- Każda transakcja jako rozwijana karta zawierająca:
  - Symbol, kierunek (LONG/SHORT), data i godzina wejścia/wyjścia
  - Entry price, Exit price, SL, TP
  - Wynik: P&L w zł/$ + wynik w R
  - Screenshot setupu (jeśli dodany)
  - Komentarz użytkownika (jeśli dodany)
  - Tag strategii / setupu
- Filtry listy: po wyniku (zysk/strata), po setupie, po instrumencie
- Podsumowanie na dole listy: Win Rate tygodnia, Avg R, Best/Worst trade

---

## BUG-04 · WYSOKI
### Brak ekranu podsumowania miesięcznego

**Opis problemu:**  
Platforma nie posiada żadnego widoku zamknięcia miesiąca. Użytkownik nie może ocenić swojego postępu w skali miesięcznej ani postawić celów na kolejny miesiąc.

**Wymagane zmiany — nowy widok `/monthly-summary/:year/:month`:**

Sekcja 1 — Metryki miesiąca:
- Win Rate, Profit Factor, Średnie RR, Max Drawdown
- Liczba transakcji, Liczba sesji, Dni z wpisem w dzienniku
- Porównanie z poprzednim miesiącem (strzałka wzrost/spadek)

Sekcja 2 — Najlepsze i najgorsze zagrania:
- Top 3 transakcje miesiąca (do nauki i powtarzania)
- Bottom 3 transakcje miesiąca (błędy do eliminacji)
- Każda z rozwijalnym szczegółem i screenshotem

Sekcja 3 — Refleksja (pola tekstowe do wypełnienia):
- "Co działało w tym miesiącu?"
- "Co chcę wyeliminować?"
- "Jeden nawyk do wdrożenia w następnym miesiącu"

Sekcja 4 — Cele na kolejny miesiąc:
- Pole: target Win Rate
- Pole: target liczba transakcji
- Pole: max dzienny drawdown
- Pole wolnotekstowe: główny focus

Sekcja 5 — Przycisk "Zamknij miesiąc" (analogiczny do BUG-01, wymaga świadomej akcji)

**Nowa tabela w bazie:**
```sql
CREATE TABLE monthly_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  year INT NOT NULL,
  month INT NOT NULL,
  reviewed BOOLEAN DEFAULT FALSE,
  reviewed_at TIMESTAMP DEFAULT NULL,
  reflection_what_worked TEXT,
  reflection_to_eliminate TEXT,
  reflection_new_habit TEXT,
  goal_win_rate DECIMAL,
  goal_trade_count INT,
  goal_max_drawdown DECIMAL,
  goal_focus TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, year, month)
);
```

---

## BUG-05 · WYSOKI
### Brak ekranu podsumowania rocznego

**Opis problemu:**  
Platforma nie posiada widoku zamknięcia roku. Użytkownik nie może ocenić swojego całorocznego postępu.

**Wymagane zmiany — nowy widok `/yearly-summary/:year`:**

Sekcja 1 — Krzywa kapitału rok do roku (wykres liniowy)

Sekcja 2 — Metryki roczne:
- Win Rate, Profit Factor, Total P&L, Max Drawdown roczny
- Najlepszy i najgorszy miesiąc (link do monthly summary)
- Ewolucja Win Rate miesiąc do miesiąca (wykres)

Sekcja 3 — Słownik błędów roku:
- Najczęściej powtarzające się błędy (z tagów transakcji)
- Ile razy każdy błąd wystąpił

Sekcja 4 — Refleksja roczna (pola tekstowe):
- "Moje największe osiągnięcie tradingowe tego roku"
- "Błąd który kosztował mnie najwięcej"
- "Co zmieniam w przyszłym roku"

Sekcja 5 — Cele na kolejny rok

Sekcja 6 — Przycisk "Zamknij rok" (wymaga świadomej akcji, analogicznie do BUG-01)

**Nowa tabela w bazie:**
```sql
CREATE TABLE yearly_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  year INT NOT NULL,
  reviewed BOOLEAN DEFAULT FALSE,
  reviewed_at TIMESTAMP DEFAULT NULL,
  reflection_achievement TEXT,
  reflection_biggest_mistake TEXT,
  reflection_changes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, year)
);
```

---

## BUG-06 · WYSOKI
### Ekran startowy — plagiat, wymaga zastąpienia oryginalną treścią

**Opis problemu:**  
Ekran wyświetlany po zalogowaniu (rutyna otwarcia / 5 punktów) zawiera treść która nie jest oryginalna. Wymaga zastąpienia własnym, oryginalnym ekranem w języku polskim.

**Wymagane zmiany — nowy ekran "Rytuał Otwarcia":**

Użytkownik przechodzi przez 5 pytań. Każde pytanie wymaga świadomego kliknięcia "Tak, jestem gotowy" lub "Nie teraz". Dopiero po przejściu wszystkich 5 punktów otwiera się dostęp do platformy.

Treść 5 punktów (oryginalna, nie kopiować z innych źródeł):
```
① CIAŁO
   "Czy jesteś wypoczęty i najedzony?"
   
② UMYSŁ  
   "Czy wiesz co rynek robi dziś rano?"
   
③ PLAN
   "Czy Twoje setupy na dziś są zidentyfikowane?"
   
④ GRANICE
   "Czy znasz swój dzienny limit straty?"
   
⑤ INTENCJA
   "Co chcesz osiągnąć podczas tej sesji?"
```

UI: animowany checklist, pasek postępu, każdy punkt "zapala się" po kliknięciu. Ostatni ekran: podsumowanie gotowości + przycisk "Zaczynam sesję".

**Uwaga:** Ekran pojawia się przy każdym logowaniu. Użytkownik może go przejść szybko (kliknięcia) ale nie może go całkowicie pominąć.

---

## BUG-07 · WYSOKI
### Ekran zamknięcia — plagiat, wymaga zastąpienia oryginalną treścią

**Opis problemu:**  
Ekran wyświetlany przed wylogowaniem (rutyna po sesji) zawiera treść która nie jest oryginalna. Wymaga zastąpienia własnym ekranem w języku polskim.

**Wymagane zmiany — nowy ekran "Rytuał Zamknięcia":**

Analogiczna struktura do BUG-06. 5 pytań przed wylogowaniem:

```
① WYNIKI
   "Jak zakończyłeś dzień finansowo?"
   (pole: zysk / strata / break-even + kwota opcjonalnie)
   
② DYSCYPLINA
   "Czy trzymałeś się swojego planu?"
   (skala 1–5)
   
③ EMOCJE
   "Jak oceniasz swój stan przez całą sesję?"
   (skala 1–5 + opcjonalne pole tekstowe)
   
④ LEKCJA
   "Jedno zdanie: czego nauczyłeś się dziś?"
   (pole tekstowe, wymagane)
   
⑤ RESET
   "Jutro to nowy dzień. Zamknij notes."
   (przycisk potwierdzenia)
```

Dane z tego ekranu zapisują się automatycznie jako wpis dzienny w dzienniku (nie trzeba wypełniać osobno).

UI: animacja "zamknięcia" po przejściu wszystkich kroków — wizualna metafora odejścia od ekranu i zakończenia sesji.

---

## Podsumowanie — Kolejność Prac

| # | Bug | Priorytet | Szacowany czas |
|---|---|---|---|
| BUG-02 | Błędne przekierowanie z przypomnienia | KRYTYCZNY | 2–4 godziny |
| BUG-01 | Auto-uzupełnianie tygodni | KRYTYCZNY | 1–2 dni |
| BUG-03 | Brak transakcji w weekly summary | WYSOKI | 2–3 dni |
| BUG-06 | Nowy ekran Rytuał Otwarcia | WYSOKI | 2–3 dni |
| BUG-07 | Nowy ekran Rytuał Zamknięcia | WYSOKI | 2–3 dni |
| BUG-04 | Podsumowanie miesięczne | WYSOKI | 4–5 dni |
| BUG-05 | Podsumowanie roczne | WYSOKI | 3–4 dni |

**Łączny szacowany czas: 2–3 tygodnie robocze**

---

> Przed rozpoczęciem prac: poproś o aktualną wersję `index` i głównych komponentów.  
> Po każdym BUG: deploy na staging + test przed merge do main.
