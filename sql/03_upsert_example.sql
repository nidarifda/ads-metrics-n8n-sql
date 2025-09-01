SELECT COUNT(*) FROM public.ads_spend;

SELECT load_date::timestamp(0) AS load_batch, COUNT(*) AS rows
FROM public.ads_spend
GROUP BY 1
ORDER BY 1 DESC;

SELECT *
FROM public.ads_spend
ORDER BY load_date DESC
LIMIT 10;
