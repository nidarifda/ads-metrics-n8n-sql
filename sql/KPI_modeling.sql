WITH bounds AS (
  SELECT MAX(date)::date AS anchor FROM public.ads_spend
),
last_30 AS (
  SELECT
    SUM(spend)::numeric                         AS spend,
    SUM(conversions)::numeric                   AS conv
  FROM public.ads_spend a
  CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '29 days') AND b.anchor
),
prior_30 AS (
  SELECT
    SUM(spend)::numeric                         AS spend,
    SUM(conversions)::numeric                   AS conv
  FROM public.ads_spend a
  CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '59 days') AND (b.anchor - INTERVAL '30 days')
),
kpis AS (
  SELECT
    -- Last 30d
    (SELECT spend FROM last_30)                               AS last_spend,
    (SELECT conv  FROM last_30)                               AS last_conv,
    (SELECT conv  FROM last_30) * 100.0                       AS last_revenue,
    CASE WHEN (SELECT spend FROM last_30) > 0
         THEN ((SELECT conv FROM last_30) * 100.0) / (SELECT spend FROM last_30)
         ELSE NULL END                                        AS last_roas,
    CASE WHEN (SELECT conv FROM last_30) > 0
         THEN (SELECT spend FROM last_30) / (SELECT conv FROM last_30)
         ELSE NULL END                                        AS last_cac,

    -- Prior 30d
    (SELECT spend FROM prior_30)                              AS prior_spend,
    (SELECT conv  FROM prior_30)                              AS prior_conv,
    (SELECT conv  FROM prior_30) * 100.0                      AS prior_revenue,
    CASE WHEN (SELECT spend FROM prior_30) > 0
         THEN ((SELECT conv FROM prior_30) * 100.0) / (SELECT spend FROM prior_30)
         ELSE NULL END                                        AS prior_roas,
    CASE WHEN (SELECT conv FROM prior_30) > 0
         THEN (SELECT spend FROM prior_30) / (SELECT conv FROM prior_30)
         ELSE NULL END                                        AS prior_cac
),
final AS (
  SELECT
    'CAC'::text                                               AS metric,
    ROUND(last_cac, 2)                                        AS last_30_value,
    ROUND(prior_cac, 2)                                       AS prior_30_value,
    ROUND(last_cac - prior_cac, 2)                            AS delta_abs,
    ROUND(100.0 * (last_cac - prior_cac) / NULLIF(prior_cac,0), 2) AS delta_pct
  FROM kpis
  UNION ALL
  SELECT
    'ROAS',
    ROUND(last_roas, 4),
    ROUND(prior_roas, 4),
    ROUND(last_roas - prior_roas, 4),
    ROUND(100.0 * (last_roas - prior_roas) / NULLIF(prior_roas,0), 2)
  FROM kpis
)
SELECT * FROM final;
