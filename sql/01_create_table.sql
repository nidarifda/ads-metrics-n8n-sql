CREATE TABLE IF NOT EXISTS public.ads_spend (
  date              date,
  platform          text,
  account           text,
  campaign          text,
  country           text,
  device            text,
  spend             double precision,
  clicks            integer,
  impressions       integer,
  conversions       integer,
  load_date         timestamp,
  source_file_name  text
);
