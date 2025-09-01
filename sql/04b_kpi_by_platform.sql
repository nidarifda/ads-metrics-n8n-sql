WITH params AS (
  SELECT (SELECT MAX(date) FROM public.ads_spend)::date AS end_date, 30::int AS n_days
),
bounds AS (
  SELECT
    end_date,
    n_days,
    (end_date - (n_days - 1)) AS last_start,         -- inclusive window of n_days
    end_date                  AS last_end,
    (end_date - (2*n_days - 1)) AS prev_start,       -- <-- fixed: n_days long
    (end_date - n_days)         AS prev_end
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
  SELECT 'CAC' AS metric,
         (spend_last/NULLIF(conv_last,0))                                        AS value_current,
         (spend_prev/NULLIF(conv_prev,0))                                        AS value_prior,
         (spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0))     AS abs_delta,
         CASE WHEN (spend_prev/NULLIF(conv_prev,0))=0 THEN NULL
              ELSE ((spend_last/NULLIF(conv_last,0)) - (spend_prev/NULLIF(conv_prev,0)))
                   / (spend_prev/NULLIF(conv_prev,0)) END                         AS pct_delta
  FROM pivot
  UNION ALL
  SELECT 'Conversions',
         conv_last, conv_prev,
         (conv_last - conv_prev),
         CASE WHEN conv_prev=0 THEN NULL ELSE (conv_last - conv_prev)::numeric / conv_prev END
  FROM pivot
  UNION ALL
  SELECT 'ROAS',
         (conv_last*100.0/NULLIF(spend_last,0)),
         (conv_prev*100.0/NULLIF(spend_prev,0)),
         (conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)),
         CASE WHEN (conv_prev*100.0/NULLIF(spend_prev,0))=0 THEN NULL
              ELSE ((conv_last*100.0/NULLIF(spend_last,0)) - (conv_prev*100.0/NULLIF(spend_prev,0)))
                   / (conv_prev*100.0/NULLIF(spend_prev,0)) END
  FROM pivot
  UNION ALL
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



-- 04b_kpi_by_platform.sql
WITH canon AS (
  SELECT
    date,
    CASE
      WHEN lower(trim(platform)) IN ('google','google ads','googleads','adwords') THEN 'Google'
      WHEN lower(trim(platform)) IN ('meta','facebook','fb','facebook ads','fb ads') THEN 'Meta'
      ELSE initcap(trim(platform))
    END AS platform_norm,
    spend,
    conversions
  FROM public.ads_spend
),
bounds AS (
  SELECT MAX(date)::date AS anchor FROM canon
),
last_30 AS (
  SELECT platform_norm AS platform,
         SUM(spend)::numeric AS spend,
         SUM(conversions)::numeric AS conv
  FROM canon a CROSS JOIN bounds b
  WHERE a.date > b.anchor - INTERVAL '30 days'
    AND a.date <= b.anchor
  GROUP BY platform_norm
),
prior_30 AS (
  SELECT platform_norm AS platform,
         SUM(spend)::numeric AS spend,
         SUM(conversions)::numeric AS conv
  FROM canon a CROSS JOIN bounds b
  WHERE a.date > b.anchor - INTERVAL '60 days'
    AND a.date <= b.anchor - INTERVAL '30 days'
  GROUP BY platform_norm
),
m AS (
  SELECT COALESCE(l.platform, p.platform) AS platform,
         l.spend  AS last_spend,  l.conv  AS last_conv,
         p.spend  AS prior_spend, p.conv  AS prior_conv
  FROM last_30 l
  FULL OUTER JOIN prior_30 p USING (platform)
)

-- CAC
SELECT
  platform,
  'CAC' AS metric,
  ROUND(CASE WHEN last_conv  > 0 THEN last_spend  / last_conv  END, 2) AS last_30_value,
  ROUND(CASE WHEN prior_conv > 0 THEN prior_spend / prior_conv END, 2) AS prior_30_value,
  ROUND(
    (CASE WHEN last_conv  > 0 THEN last_spend  / last_conv  END) -
    (CASE WHEN prior_conv > 0 THEN prior_spend / prior_conv END), 2
  ) AS delta_abs,
  ROUND(
    100.0 *
    (
      (CASE WHEN last_conv  > 0 THEN last_spend  / last_conv  END) -
      (CASE WHEN prior_conv > 0 THEN prior_spend / prior_conv END)
    ) /
    NULLIF((CASE WHEN prior_conv > 0 THEN prior_spend / prior_conv END), 0), 2
  ) AS delta_pct
FROM m

UNION ALL

-- ROAS (rev = conv * 100)
SELECT
  platform,
  'ROAS' AS metric,
  ROUND(CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END, 4) AS last_30_value,
  ROUND(CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END, 4) AS prior_30_value,
  ROUND(
    (CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END) -
    (CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END), 4
  ) AS delta_abs,
  ROUND(
    100.0 *
    (
      (CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END) -
      (CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END)
    ) /
    NULLIF((CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END), 0), 2
  ) AS delta_pct
FROM m
ORDER BY platform, metric;
