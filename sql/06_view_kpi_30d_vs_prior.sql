WITH bounds AS (
  SELECT MAX(date)::date AS anchor FROM public.ads_spend
),
last_30 AS (
  SELECT SUM(spend)::numeric AS spend, SUM(conversions)::numeric AS conv
  FROM public.ads_spend a CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '29 days') AND b.anchor
),
prior_30 AS (
  SELECT SUM(spend)::numeric AS spend, SUM(conversions)::numeric AS conv
  FROM public.ads_spend a CROSS JOIN bounds b
  WHERE a.date BETWEEN (b.anchor - INTERVAL '59 days') AND (b.anchor - INTERVAL '30 days')
),
vals AS (
  SELECT l.spend AS last_spend, l.conv AS last_conv,
         p.spend AS prior_spend, p.conv AS prior_conv
  FROM last_30 l CROSS JOIN prior_30 p
)
SELECT * FROM (
  -- CAC
  SELECT
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
  FROM vals

  UNION ALL

  -- ROAS (rev = conv * 100)
  SELECT
    'ROAS',
    ROUND(CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END, 4),
    ROUND(CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END, 4),
    ROUND(
      (CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END) -
      (CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END), 4
    ),
    ROUND(
      100.0 *
      (
        (CASE WHEN last_spend  > 0 THEN (last_conv  * 100.0) / last_spend  END) -
        (CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END)
      ) /
      NULLIF((CASE WHEN prior_spend > 0 THEN (prior_conv * 100.0) / prior_spend END), 0), 2
    )
  FROM vals
) f
ORDER BY metric;
