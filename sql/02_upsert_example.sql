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


/* Query Parameters*/
{{
[
  $json.date,                          // 1
  $json.platform,                      // 2
  $json.account,                       // 3
  $json.campaign,                      // 4
  $json.country,                       // 5
  $json.device,                        // 6
  String($json.spend ?? ''),           // 7
  String($json.clicks ?? ''),          // 8
  String($json.impressions ?? ''),     // 9
  String($json.conversions ?? ''),     // 10
  ($json.load_date ?? new Date().toISOString()),  // 11
  ($json.source_file_name ?? 'ads_spend.csv')     // 12
]
}}
