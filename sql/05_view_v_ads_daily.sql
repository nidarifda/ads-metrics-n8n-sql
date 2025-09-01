CREATE OR REPLACE VIEW public.v_ads_daily AS
SELECT
  date, platform, account, campaign, country, device,
  spend, clicks, impressions, conversions,
  CASE WHEN conversions > 0 THEN spend / conversions END                 AS cac,
  CASE WHEN spend > 0       THEN (conversions * 100.0) / spend END       AS roas
FROM public.ads_spend;
