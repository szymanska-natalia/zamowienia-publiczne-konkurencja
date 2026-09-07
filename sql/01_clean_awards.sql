-- =====================================================================
-- 01_clean_awards.sql
--
-- Warstwa czysta. Buduje clean_awards z surowej tabeli raw_notices,
-- która zawiera wierną kopię plików CSV z TED (wszystkie pola jako tekst).
--
-- Co robi:
--   1. src   - odsiewa wiersze nienadające się do analizy
--   2. typed - nadaje właściwe typy i wylicza kolumny pochodne
--   3. final - dokłada wskaźnik savings_ratio
--
-- Wejście:  raw_notices     (580 804 wiersze, Polska 2021-2023)
-- Wyjście:  clean_awards    (264 223 wiersze)
--
-- Skrypt jest idempotentny - można go uruchamiać wielokrotnie.
-- =====================================================================

DROP TABLE IF EXISTS clean_awards;

CREATE TABLE clean_awards AS

-- KROK 1: odsiew
-- Umowy ramowe wykluczone, bo ich kwota to wieloletni pułap zakupowy,
-- a nie wartość faktycznie udzielonego zamówienia (różnice rzędu 15x).
-- Pozostałe warunki zapewniają komplet pól potrzebnych do analizy.
-- NULLIF jest konieczny, bo Alteryx zapisał puste pola jako pusty string,
-- a nie jako NULL - samo IS NOT NULL przepuściłoby wszystko.
WITH src AS (
    SELECT *
    FROM raw_notices
    WHERE b_fra_agreement = 'N'
      AND NULLIF(top_type, '')             IS NOT NULL
      AND NULLIF(number_offers, '')        IS NOT NULL
      AND NULLIF(award_value_euro, '')     IS NOT NULL
      AND NULLIF(award_est_value_euro, '') IS NOT NULL
),

-- KROK 2: typowanie
-- Warstwa surowa trzyma wszystko jako tekst, żeby ładowanie nie mogło
-- się wywalić ani po cichu zamienić wartości na NULL. Konwersja typów
-- następuje tutaj - jawnie i pod kontrolą.
-- Uwaga: daty w TED mają format DD/MM/YY, nie amerykański MM/DD/YY.
typed AS (
    SELECT
        id_notice_can,
        id_lot,
        id_award,

        cae_name,                                   -- zamawiający
        cae_nationalid,
        cae_town,

        win_name,                                   -- wykonawca
        win_nationalid,

        top_type,                                   -- tryb postępowania
        cpv,
        LEFT(cpv, 4)                  AS cpv_group, -- grupa CPV = 4 pierwsze cyfry
        title,

        number_offers::int            AS n_offers,
        award_value_euro::numeric     AS value_eur,
        award_est_value_euro::numeric AS est_value_eur,

        TO_DATE(dt_award, 'DD/MM/YY') AS award_date,
        year::int                     AS award_year
    FROM src
)

-- KROK 3: wskaźnik
-- savings_ratio = ile faktycznie zapłacono względem tego, ile planowano.
-- Wartość < 1 oznacza oszczędność względem budżetu zamawiającego.
-- Wskaźnik jest znormalizowany, więc pozwala porównywać zamówienia
-- o skrajnie różnej wartości bezwzględnej.
-- NULLIF(est_value_eur, 0) zabezpiecza przed dzieleniem przez zero:
-- zamiast błędu przerywającego całe zapytanie wiersz dostaje NULL.
SELECT
    *,
    ROUND(value_eur / NULLIF(est_value_eur, 0), 4) AS savings_ratio
FROM typed;


-- Kontrola
SELECT COUNT(*) AS wierszy               FROM clean_awards;
SELECT COUNT(*) AS bez_wskaznika         FROM clean_awards WHERE savings_ratio IS NULL;
