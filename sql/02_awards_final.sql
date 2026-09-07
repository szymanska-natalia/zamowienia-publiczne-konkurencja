-- =====================================================================
-- 02_awards_final.sql
--
-- Tabela analityczna. Usuwa z clean_awards obserwacje o wartościach
-- nierealistycznych i dokłada kolumny pomocnicze pod raport Power BI.
--
-- Reguła odcięcia (uzasadnienie w README, sekcja "Reguła odcięcia"):
--   est_value_eur >= 100        - wartość szacowana poniżej 100 EUR jest
--                                 niemożliwa dla zamówienia powyżej progów
--                                 unijnych; to wartość zastępcza wpisana
--                                 w formularzu (obserwowano 1 EUR oraz
--                                 0,22 EUR = przeliczone 1 PLN)
--   savings_ratio 0.1 - 3       - poza tym pasmem relacja ceny do szacunku
--                                 nie jest wiarygodna
--   n_offers >= 1               - zamówienie udzielone przy zerowej liczbie
--                                 ofert nie ma sensu (2 wiersze)
--
-- Łącznie odrzuca 9 423 wiersze, czyli 3,57% zbioru.
--
-- Wejście:  clean_awards   (264 223 wiersze)
-- Wyjście:  awards_final   (254 800 wierszy)
-- =====================================================================

DROP TABLE IF EXISTS awards_final;

CREATE TABLE awards_final AS
SELECT *
FROM clean_awards
WHERE est_value_eur >= 100
  AND savings_ratio BETWEEN 0.1 AND 3;

DELETE FROM awards_final WHERE n_offers < 1;


-- ---------------------------------------------------------------------
-- Kolumny pomocnicze dla Power BI
--
-- Grupowanie liczby ofert liczone jest tutaj, a nie miarą w DAX.
-- Przekształcenia trzymamy jak najbliżej źródła: kolumna w bazie jest
-- widoczna w kodzie, testowalna i wspólna dla wszystkich odbiorców,
-- a logika ukryta w pliku .pbix nie jest ani jednym, ani drugim.
-- ---------------------------------------------------------------------

ALTER TABLE awards_final ADD COLUMN grupa_ofert      text;
ALTER TABLE awards_final ADD COLUMN grupa_ofert_sort int;

UPDATE awards_final
SET grupa_ofert = CASE
        WHEN n_offers = 1              THEN '1 oferta'
        WHEN n_offers = 2              THEN '2 oferty'
        WHEN n_offers = 3              THEN '3 oferty'
        WHEN n_offers BETWEEN 4 AND 5  THEN '4-5 ofert'
        WHEN n_offers BETWEEN 6 AND 10 THEN '6-10 ofert'
        ELSE                                '11+ ofert'
    END,
    -- Power BI sortuje tekst alfabetycznie, co dałoby kolejność
    -- 1, 11+, 2, 3... Kolumna liczbowa wymusza kolejność merytoryczną.
    grupa_ofert_sort = CASE
        WHEN n_offers = 1              THEN 1
        WHEN n_offers = 2              THEN 2
        WHEN n_offers = 3              THEN 3
        WHEN n_offers BETWEEN 4 AND 5  THEN 4
        WHEN n_offers BETWEEN 6 AND 10 THEN 5
        ELSE                                6
    END;


-- Kontrola: oczekiwane 254 800
SELECT COUNT(*) AS wierszy FROM awards_final;
