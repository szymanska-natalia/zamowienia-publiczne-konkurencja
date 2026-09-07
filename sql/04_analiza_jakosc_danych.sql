-- =====================================================================
-- 04_analiza_jakosc_danych.sql
--
-- Rozpoznanie i ocena jakości danych. Uruchamiane PRZED budową warstwy
-- czystej - wyniki tych zapytań są podstawą decyzji projektowych
-- opisanych w README.
--
-- Wejście: raw_notices (580 804 wiersze), clean_awards
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Wolumen, granulacja i kompletność kluczowych pól
--
-- Wynik:
--   rok    wiersze   ogłoszenia   komplet danych    %
--   2021   176 435      30 482        132 588     75,2
--   2022   194 331      37 580        143 475     73,8
--   2023   210 038      40 579        159 624     76,0
--
-- Dwa wnioski:
--   1. Jeden wiersz to jedna CZĘŚĆ rozstrzygnięcia, nie postępowanie.
--      Na ogłoszenie przypada ok. 5 części - liczenie postępowań przez
--      COUNT(*) zawyżyłoby wynik pięciokrotnie.
--   2. Liczba ogłoszeń rośnie szybciej (+33%) niż liczba wierszy (+19%),
--      więc wzrost wolumenu jest realny, a nie wynika z fragmentacji
--      zamówień na większą liczbę części.
-- ---------------------------------------------------------------------

SELECT
    year,
    COUNT(*)                                                            AS wszystkie,
    COUNT(DISTINCT id_notice_can)                                       AS ogloszenia,
    COUNT(*) FILTER (WHERE NULLIF(number_offers, '')    IS NOT NULL)    AS ma_liczbe_ofert,
    COUNT(*) FILTER (WHERE NULLIF(award_value_euro, '') IS NOT NULL)    AS ma_wartosc,
    COUNT(*) FILTER (WHERE NULLIF(number_offers, '')    IS NOT NULL
                       AND NULLIF(award_value_euro, '') IS NOT NULL)    AS ma_oba
FROM raw_notices
GROUP BY year
ORDER BY year;


-- ---------------------------------------------------------------------
-- B. Rozkład wartości kolumn, po których filtrujemy
--
-- Zasada: nie filtruj po kolumnie, której zawartości nie widziałeś.
--
-- Wyniki:
--   cancelled        - wyłącznie '0' we wszystkich 580 804 wierszach.
--                      TED nie publikuje w tym eksporcie postępowań
--                      anulowanych, więc filtr byłby martwym kodem.
--   b_fra_agreement  - 'Y' w ok. 1,1% wierszy (umowy ramowe).
--   top_type         - OPE (przetarg nieograniczony) ok. 96%, reszta to
--                      tryby o ograniczonej konkurencji; 122 wiersze
--                      mają pusty tryb i są odrzucane jako wybrakowane.
-- ---------------------------------------------------------------------

SELECT year, cancelled,        COUNT(*) FROM raw_notices GROUP BY year, cancelled        ORDER BY 1, 3 DESC;
SELECT year, b_fra_agreement,  COUNT(*) FROM raw_notices GROUP BY year, b_fra_agreement  ORDER BY 1, 3 DESC;
SELECT       top_type,         COUNT(*) FROM raw_notices GROUP BY top_type               ORDER BY 2 DESC;


-- ---------------------------------------------------------------------
-- C. Weryfikacja hipotezy o przyczynie braków danych
--
-- Hipoteza robocza: brakujące number_offers koncentrują się w trybach
-- niekonkurencyjnych, w których oferta jest tylko jedna.
--
-- HIPOTEZA OBALONA. Kompletność w trybach niekonkurencyjnych jest
-- wyższa niż w trybie otwartym:
--   AWP 90,7%   NOC 78,1%   RES 82,8%   OPE 74,9%
--
-- Braki koncentrują się w głównej masie postępowań konkurencyjnych.
-- Przyczyna pozostaje niewyjaśniona, co odnotowano w ograniczeniach.
-- ---------------------------------------------------------------------

SELECT
    top_type,
    COUNT(*)                                                          AS wszystkie,
    COUNT(*) FILTER (WHERE NULLIF(number_offers, '') IS NOT NULL)     AS nie_puste,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NULLIF(number_offers, '') IS NOT NULL)
          / COUNT(*), 1)                                              AS pct
FROM raw_notices
GROUP BY top_type
ORDER BY wszystkie DESC;


-- ---------------------------------------------------------------------
-- D. Rozkład wskaźnika przed odcięciem wartości błędnych
--
-- Wynik:
--   min 0,000 | p01 0,079 | p25 0,810 | MEDIANA 0,978 | p75 1,046
--   p99 2,356 | max 4 080 000 | ŚREDNIA 33,961
--
-- Mediana 0,978 wobec średniej 33,961 na tej samej kolumnie.
-- Uzasadnienie decyzji o stosowaniu mediany w całej analizie.
-- ---------------------------------------------------------------------

SELECT
    COUNT(*)                                                                      AS n,
    ROUND(MIN(savings_ratio), 3)                                                  AS min,
    ROUND(PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p01,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS mediana,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p75,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY savings_ratio)::numeric, 3) AS p99,
    ROUND(MAX(savings_ratio), 3)                                                  AS max,
    ROUND(AVG(savings_ratio), 3)                                                  AS srednia
FROM clean_awards;


-- ---------------------------------------------------------------------
-- E. Koszt reguły odcięcia
--
-- Zasada: policz, ile obserwacji usuwasz, ZANIM je usuniesz.
-- Wynik: 9 421 wierszy, czyli 3,57% zbioru - odrzucenie dopuszczalne.
-- ---------------------------------------------------------------------

SELECT
    COUNT(*)                                                          AS wszystkie,
    COUNT(*) FILTER (WHERE est_value_eur < 100)                       AS szacunek_ponizej_100,
    COUNT(*) FILTER (WHERE savings_ratio < 0.1 OR savings_ratio > 3)  AS ratio_poza_pasmem,
    COUNT(*) FILTER (WHERE est_value_eur < 100
                        OR savings_ratio < 0.1
                        OR savings_ratio > 3)                         AS do_odciecia,
    ROUND(100.0 * COUNT(*) FILTER (WHERE est_value_eur < 100
                                      OR savings_ratio < 0.1
                                      OR savings_ratio > 3) / COUNT(*), 2)
                                                                      AS pct_odciecia
FROM clean_awards;
