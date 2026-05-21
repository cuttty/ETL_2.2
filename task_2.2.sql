TRUNCATE TABLE dm.loan_holiday_info;

DROP PROCEDURE IF EXISTS refresh_loan_holiday_info();

TRUNCATE TABLE rd.deal_info RESTART IDENTITY;
TRUNCATE TABLE rd.product RESTART IDENTITY;

SELECT * FROM rd.deal_info;

WITH gaps AS (
    SELECT deal_rk, effective_from_date, effective_to_date,
           LAG(effective_to_date) OVER (PARTITION BY deal_rk ORDER BY effective_from_date) AS prev_end
    FROM rd.deal_info
)
SELECT deal_rk, prev_end + 1 AS gap_start, effective_from_date - 1 AS gap_end
FROM gaps
WHERE prev_end IS NOT NULL AND effective_from_date > prev_end + 1;


SELECT COUNT(*) FROM rd.product;

SELECT effective_to_date, COUNT(*) as row_count
FROM rd.product
GROUP BY effective_to_date;

SELECT COUNT(*) FROM rd.deal_info;

SELECT effective_to_date, COUNT(*) as row_count

FROM rd.deal_info
GROUP BY effective_to_date;


CREATE OR REPLACE PROCEDURE refresh_loan_holiday_info()
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Очищаем витрину
    TRUNCATE TABLE dm.loan_holiday_info;

    -- 2. Заполняем витрину заново
    INSERT INTO dm.loan_holiday_info (
        deal_rk,
        effective_from_date,
        effective_to_date,
        agreement_rk,
        account_rk,
        client_rk,
        department_rk,
        product_rk,
        product_name,
        deal_type_cd,
        deal_start_date,
        deal_name,
        deal_number,
        deal_sum,
        loan_holiday_type_cd,
        loan_holiday_start_date,
        loan_holiday_finish_date,
        loan_holiday_fact_finish_date,
        loan_holiday_finish_flg,
        loan_holiday_last_possible_date
    )
    SELECT
        d.deal_rk,
        GREATEST(
            d.effective_from_date,
            COALESCE(lh.effective_from_date, d.effective_from_date),
            p.effective_from_date
        ) AS effective_from_date,
        LEAST(
            d.effective_to_date,
            COALESCE(lh.effective_to_date, d.effective_to_date),
            p.effective_to_date
        ) AS effective_to_date,
        d.agreement_rk,
        d.account_rk,
        d.client_rk,
        d.department_rk,
        d.product_rk,
        p.product_name,
        d.deal_type_cd,
        d.deal_start_date,
        d.deal_name,
        d.deal_num AS deal_number,
        d.deal_sum,
        lh.loan_holiday_type_cd,
        lh.loan_holiday_start_date,
        lh.loan_holiday_finish_date,
        lh.loan_holiday_fact_finish_date,
        lh.loan_holiday_finish_flg,
        lh.loan_holiday_last_possible_date
    FROM rd.deal_info d
    JOIN rd.product p
        ON p.product_rk = d.product_rk
        AND d.effective_from_date <= p.effective_to_date
        AND d.effective_to_date >= p.effective_from_date   -- пересечение интервалов
    LEFT JOIN rd.loan_holiday lh
        ON lh.deal_rk = d.deal_rk
        AND d.effective_from_date <= lh.effective_to_date
        AND d.effective_to_date >= lh.effective_from_date   -- пересечение интервалов
    WHERE GREATEST(
            d.effective_from_date,
            COALESCE(lh.effective_from_date, d.effective_from_date),
            p.effective_from_date
        ) < LEAST(
            d.effective_to_date,
            COALESCE(lh.effective_to_date, d.effective_to_date),
            p.effective_to_date
        );
END;
$$;

-- Проверки 
-- Общее количество записей в витрине
SELECT COUNT(*) FROM dm.loan_holiday_info;

-- Пример записей (первые 10)
SELECT * FROM dm.loan_holiday_info LIMIT 10;

-- Проверьте, есть ли записи с кредитными каникулами (не NULL)
SELECT COUNT(*) FROM dm.loan_holiday_info 
WHERE loan_holiday_type_cd IS NOT NULL;

SELECT COUNT(*) FROM dm.loan_holiday_info 
WHERE effective_from_date >= effective_to_date;

-- Топ-5 продуктов по количеству сделок с каникулами
SELECT product_name, COUNT(DISTINCT deal_rk) as deals_count
FROM dm.loan_holiday_info
WHERE loan_holiday_type_cd IS NOT NULL
GROUP BY product_name
ORDER BY deals_count DESC
LIMIT 5;

-- Распределение по типам каникул
SELECT loan_holiday_type_cd, COUNT(*) as rows_count
FROM dm.loan_holiday_info
WHERE loan_holiday_type_cd IS NOT NULL
GROUP BY loan_holiday_type_cd;