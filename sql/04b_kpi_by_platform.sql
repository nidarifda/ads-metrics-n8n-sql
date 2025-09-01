-- 04b_kpi_by_platform.sql
WITH bounds AS (
  SELECT MAX(date)::date AS anchor FROM public.ads_spend
),
last_30 AS (
  SELECT
    platform,
    SUM(spend)::numeric       AS spend,
    SUM(conversions)::numeric AS conv
  FROM public.ads_spend a
  CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '29 days') AND b.anchor
  GROUP BY platform
),
prior_30 AS (
  SELECT
    platform,
    SUM(spend)::numeric       AS spend,
    SUM(conversions)::numeric AS conv
  FROM public.ads_spend a
  CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '59 days') AND (b.anchor - INTERVAL '30 days')
  GROUP BY platform
),
m AS (
  SELECT
    COALESCE(l.platform, p.platform) AS platform,
    l.spend  AS last_spend,
    l.conv   AS last_conv,
    p.spend  AS prior_spend,
    p.conv   AS prior_conv
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
