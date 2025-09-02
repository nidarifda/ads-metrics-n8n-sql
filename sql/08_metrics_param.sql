WITH params AS (
  SELECT to_date($1,'YYYY-MM-DD') AS start_date,
         to_date($2,'YYYY-MM-DD') AS end_date
),
bounds AS (
  SELECT
    start_date,
    end_date,
    (end_date - start_date + 1) AS n_days
  FROM params
),
periods AS (
  SELECT
    start_date                        AS last_start,
    end_date                          AS last_end,
    (start_date - n_days)             AS prev_start,
    (end_date   - n_days)             AS prev_end
  FROM bounds
),
agg AS (
  SELECT
    CASE
      WHEN s.date BETWEEN p.last_start AND p.last_end THEN 'last'
      WHEN s.date BETWEEN p.prev_start AND p.prev_end THEN 'prev'
    END AS period,
    SUM(s.spend)::numeric       AS spend,
    SUM(s.conversions)::numeric AS conv
  FROM public.ads_spend s
  CROSS JOIN periods p
  WHERE s.date BETWEEN p.prev_start AND p.last_end
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
         (spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0))     AS delta_abs,
         CASE WHEN (spend_prev/NULLIF(conv_prev,0))=0 THEN NULL
              ELSE ((spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0)))
                   / (spend_prev/NULLIF(conv_prev,0)) END                         AS pct_delta
  FROM pivot

  UNION ALL
  -- Conversions
  SELECT 'Conversions',
         conv_last, conv_prev,
         (conv_last - conv_prev)                                                 AS delta_abs,
         CASE WHEN conv_prev=0 THEN NULL
              ELSE (conv_last - conv_prev)::numeric / conv_prev END              AS pct_delta
  FROM pivot

  UNION ALL
  -- ROAS (rev = conv * 100)
  SELECT 'ROAS',
         (conv_last*100.0/NULLIF(spend_last,0)),
         (conv_prev*100.0/NULLIF(spend_prev,0)),
         (conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)) AS delta_abs,
         CASE WHEN (conv_prev*100.0/NULLIF(spend_prev,0))=0 THEN NULL
              ELSE ((conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)))
                   / (conv_prev*100.0/NULLIF(spend_prev,0)) END                   AS pct_delta
  FROM pivot

  UNION ALL
  -- Spend
  SELECT 'Spend',
         spend_last, spend_prev,
         (spend_last - spend_prev)                                               AS delta_abs,
         CASE WHEN spend_prev=0 THEN NULL
              ELSE (spend_last - spend_prev)/spend_prev END                      AS pct_delta
  FROM pivot
)
SELECT
  metric,
  ROUND(value_current::numeric, 4) AS value_current,
  ROUND(value_prior::numeric,   4) AS value_prior,
  ROUND(delta_abs::numeric,     4) AS abs_delta,
  ROUND(100*pct_delta::numeric, 2) AS pct_delta
FROM unioned
ORDER BY metric;
