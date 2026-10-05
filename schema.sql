create table leads (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text,
  company text,
  message text,
  score int,
  category text,
  score_reason text,
  status text default 'new',
  created_at timestamptz default now()
);

create table errors (
  id uuid primary key default gen_random_uuid(),
  workflow_name text,
  node_name text,
  error_message text,
  payload jsonb,
  created_at timestamptz default now()
);

alter table leads enable row level security;
alter table errors enable row level security;

grant usage on schema public to service_role;
grant all on table public.leads to service_role;
grant all on table public.errors to service_role;
