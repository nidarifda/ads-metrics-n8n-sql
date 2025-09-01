INSERT INTO public.ads_spend (
  "date","platform","account","campaign","country","device",
  "spend","clicks","impressions","conversions","load_date","source_file_name"
)
VALUES (
  $1::date,
  $2::text, $3::text, $4::text, $5::text, $6::text,
  NULLIF($7::text,'')::double precision,
  NULLIF($8::text,'')::int,
  NULLIF($9::text,'')::int,
  NULLIF($10::text,'')::int,
  COALESCE($11::timestamptz, now()),
  COALESCE(NULLIF($12::text,''), 'ads_spend.csv')
)
ON CONFLICT ("date","platform","account","campaign","country","device")
DO UPDATE SET
  "spend"            = EXCLUDED."spend",
  "clicks"           = EXCLUDED."clicks",
  "impressions"      = EXCLUDED."impressions",
  "conversions"      = EXCLUDED."conversions",
  "load_date"        = now(),
  "source_file_name" = EXCLUDED."source_file_name";
