BEGIN;

WITH ranked AS (
  SELECT
    ctid,
    ROW_NUMBER() OVER (
      PARTITION BY date, platform, account, campaign, country, device
      ORDER BY load_date DESC NULLS LAST, ctid DESC
    ) AS rn
  FROM public.ads_spend
)
DELETE FROM public.ads_spend t
USING ranked r
WHERE t.ctid = r.ctid
  AND r.rn > 1;

COMMIT;

-- Enforce uniqueness for idempotent loads
CREATE UNIQUE INDEX IF NOT EXISTS ux_ads_spend_nk
  ON public.ads_spend (date, platform, account, campaign, country, device);
