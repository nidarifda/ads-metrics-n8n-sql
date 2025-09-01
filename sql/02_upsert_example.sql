WITH r AS (
  SELECT
    date, platform, account, campaign, country, device,
    spend + 0.01 AS spend,  -- small tweak so you can see the update
    clicks, impressions, conversions
  FROM public.ads_spend
  ORDER BY load_date DESC NULLS LAST
  LIMIT 1
)
INSERT INTO public.ads_spend (
  date, platform, account, campaign, country, device,
  spend, clicks, impressions, conversions, source_file_name
)
SELECT
  r.date, r.platform, r.account, r.campaign, r.country, r.device,
  r.spend, r.clicks, r.impressions, r.conversions, 'reingest_test.csv'
FROM r
ON CONFLICT (date, platform, account, campaign, country, device)
DO UPDATE SET
  spend            = EXCLUDED.spend,
  clicks           = EXCLUDED.clicks,
  impressions      = EXCLUDED.impressions,
  conversions      = EXCLUDED.conversions,
  load_date        = now(),
  source_file_name = EXCLUDED.source_file_name;
