SELECT
  metric,
  ROUND(value_current::numeric, 4) AS last_30,
  ROUND(value_prior::numeric,   4) AS prior_30,
  ROUND(abs_delta::numeric,     4) AS delta_abs,
  ROUND(100 * pct_delta::numeric, 2) AS delta_pct
FROM analytics.kpi_30d_vs_prior
WHERE metric IN ('CAC','ROAS')
ORDER BY metric;
