SELECT date, platform, account, campaign, country, device, COUNT(*) AS cnt
FROM public.ads_spend
GROUP BY 1,2,3,4,5,6
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 50;

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
