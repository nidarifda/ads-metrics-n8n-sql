-- sql/04_kpi_compact_query.sql  (dynamic)
WITH params AS (
  SELECT (SELECT MAX(date) FROM public.ads_spend)::date AS end_date, 30::int AS n_days
),
bounds AS (
  SELECT
    end_date,
    n_days,
    (end_date - (n_days - 1)) AS last_start,
    end_date                  AS last_end,
    (end_date - (2*n_days))   AS prev_start,
    (end_date - n_days)       AS prev_end
  FROM params
),
agg AS (
  SELECT
    CASE
      WHEN s.date BETWEEN b.last_start AND b.last_end THEN 'last'
      WHEN s.date BETWEEN b.prev_start AND b.prev_end THEN 'prev'
    END AS period,
    SUM(s.spend)::numeric       AS spend,
    SUM(s.conversions)::numeric AS conv
  FROM public.ads_spend s
  CROSS JOIN bounds b
  WHERE s.date BETWEEN b.prev_start AND b.last_end
  GROUP BY 1
),
pivot AS (
  SELECT
    MAX(CASE WHEN period='last' THEN spend END) AS spend_last,
    MAX(CASE WHEN period='prev' THEN spend END) AS spend_prev,
    MAX(CASE WHEN period='last' THEN conv  END) AS conv_last,
    MAX(CASE WHEN period='prev' THEN conv  END) AS conv_prev
  FROM agg
),
unioned AS (
  -- CAC
  SELECT 'CAC' AS metric,
         (spend_last/NULLIF(conv_last,0))                                        AS value_current,
         (spend_prev/NULLIF(conv_prev,0))                                        AS value_prior,
         (spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0))     AS abs_delta,
         CASE WHEN (spend_prev/NULLIF(conv_prev,0))=0 THEN NULL
              ELSE ((spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0)))
                   / (spend_prev/NULLIF(conv_prev,0)) END                         AS pct_delta
  FROM pivot
  UNION ALL
  -- Conversions
  SELECT 'Conversions',
         conv_last, conv_prev,
         (conv_last - conv_prev),
         CASE WHEN conv_prev=0 THEN NULL ELSE (conv_last - conv_prev)::numeric / conv_prev END
  FROM pivot
  UNION ALL
  -- ROAS (rev = conv * 100)
  SELECT 'ROAS',
         (conv_last*100.0/NULLIF(spend_last,0)),
         (conv_prev*100.0/NULLIF(spend_prev,0)),
         (conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)),
         CASE WHEN (conv_prev*100.0/NULLIF(spend_prev,0))=0 THEN NULL
              ELSE ((conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)))
                   / (conv_prev*100.0/NULLIF(spend_prev,0)) END
  FROM pivot
  UNION ALL
  -- Spend
  SELECT 'Spend',
         spend_last, spend_prev,
         (spend_last - spend_prev),
         CASE WHEN spend_prev=0 THEN NULL ELSE (spend_last - spend_prev)/spend_prev END
  FROM pivot
)
SELECT
  metric,
  ROUND(value_current::numeric, 4) AS value_current,
  ROUND(value_prior::numeric,   4) AS value_prior,
  ROUND(abs_delta::numeric,     4) AS abs_delta,
  ROUND(pct_delta::numeric,     4) AS pct_delta
FROM unioned
ORDER BY metric;
