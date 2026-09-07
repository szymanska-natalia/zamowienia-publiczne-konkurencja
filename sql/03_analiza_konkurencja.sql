-- =====================================================================
-- 03_analiza_konkurencja.sql
--
-- Analiza główna: wpływ liczby złożonych ofert na cenę końcową.
--
-- Pytanie badawcze:
--   Czy większa liczba ofert obniża stosunek ceny wybranej oferty
--   do wartości szacowanej przed przetargiem?
--
-- Wejście: awards_final (254 800 wierszy)
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Wskaźniki zbiorcze (karty KPI w raporcie)
--
--   liczba_zamowien  = 254 800
--   pct_jedna_oferta = 53,3%
--   mediana_ratio    = 0,98
-- ---------------------------------------------------------------------

SELECT
    COUNT(*)                                                         AS liczba_zamowien,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_offers = 1) / COUNT(*), 1) AS pct_jedna_oferta,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3)
                                                                     AS mediana_ratio
FROM awards_final;


-- ---------------------------------------------------------------------
-- B. WYNIK GŁÓWNY: mediana wskaźnika według liczby ofert
--
-- Stosowana jest mediana, nie średnia. Na pełnym zbiorze mediana wynosi
-- 0,978, a średnia 33,961 - średnia jest zniszczona przez wartości
-- skrajne i nie nadaje się do raportowania.
--
-- Wynik:
--   1 oferta    135 806   1,000
--   2 oferty     50 448   0,942
--   3 oferty     29 676   0,912
--   4-5 ofert    26 907   0,876
--   6-10 ofert    9 911   0,795
--   11+ ofert     2 052   0,828
--
-- Zależność monotoniczna do przedziału 6-10 ofert, powyżej wypłaszczenie.
-- ---------------------------------------------------------------------

SELECT
    grupa_ofert,
    COUNT(*)                                                                      AS liczba_zamowien,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS mediana_ratio,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p25,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p75
FROM awards_final
GROUP BY grupa_ofert, grupa_ofert_sort
ORDER BY grupa_ofert_sort;


-- ---------------------------------------------------------------------
-- C. Konkurencja w czasie
--
-- Udział postępowań jednoofertowych rośnie: 51,1% -> 53,6% -> 55,3%,
-- przy jednoczesnym spadku średniej liczby ofert.
--
-- Uwaga interpretacyjna: trzy punkty w czasie to za mało, by mówić
-- o trendzie w sensie statystycznym. Opisujemy to jako wzrost
-- w latach 2021-2023, nie jako trend rosnący.
-- ---------------------------------------------------------------------

SELECT
    award_year,
    COUNT(*)                                                          AS liczba_zamowien,
    ROUND(AVG(n_offers), 2)                                           AS srednia_ofert,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_offers = 1) / COUNT(*), 1) AS pct_jedna_oferta
FROM awards_final
GROUP BY award_year
ORDER BY award_year;


-- ---------------------------------------------------------------------
-- D. Kontrola: dziesięć skrajnych wartości wskaźnika
--
-- Uruchamiane przed ustaleniem reguły odcięcia. Ujawniło, że wartości
-- skrajne to wynik wpisywania wartości zastępczych w polu wartości
-- szacowanej (1 EUR oraz 0,22 EUR = przeliczone 1 PLN), a nie zjawisko
-- ekonomiczne. Zasada: obejrzyj obserwacje odstające, zanim je usuniesz.
-- ---------------------------------------------------------------------

SELECT
    cae_name,
    title,
    n_offers,
    est_value_eur,
    value_eur,
    savings_ratio
FROM clean_awards
ORDER BY savings_ratio DESC
LIMIT 10;
