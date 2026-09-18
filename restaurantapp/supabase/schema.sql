create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'customer' check (role in ('customer', 'administrator')),
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null check (category in ('burritos', 'tacos', 'bowls', 'sides', 'drinks')),
  price numeric(10, 2) not null check (price >= 0),
  image_url text,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  customer_name text not null,
  customer_email text not null,
  items jsonb not null default '[]'::jsonb,
  total numeric(10, 2) not null check (total >= 0),
  status text not null default 'pending' check (status in ('pending', 'preparing', 'ready', 'delivered')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

create policy "profiles can read own profile" on public.profiles
  for select using (auth.uid() = id);
create policy "users can create own profile" on public.profiles
  for insert with check (auth.uid() = id);
create policy "users can update own profile" on public.profiles
  for update using (auth.uid() = id);

create or replace function public.is_administrator()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'administrator'
  );
$$;

drop policy if exists "anyone can read available products" on public.products;
drop policy if exists "authenticated users can create products" on public.products;
drop policy if exists "authenticated users can update products" on public.products;
create policy "anyone can read available products" on public.products
  for select using (is_available = true);
create policy "administrators can create products" on public.products
  for insert to authenticated with check (public.is_administrator());
create policy "administrators can update products" on public.products
  for update to authenticated using (public.is_administrator()) with check (public.is_administrator());
create policy "authenticated users can read orders" on public.orders
  for select to authenticated using (true);
create policy "customers can create orders" on public.orders
  for insert to authenticated with check (true);
create policy "administrators can update orders" on public.orders
  for update to authenticated using (public.is_administrator()) with check (public.is_administrator());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'customer'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

insert into public.products (id, name, category, price)
values
  ('burrito-pollo', 'Burrito de pollo', 'burritos', 8.75),
  ('bowl-bbq', 'Bowl BBQ', 'bowls', 8.25),
  ('tacos-picantes', 'Tacos picantes', 'tacos', 7.25),
  ('fries', 'Patatas deluxe', 'sides', 4.50),
  ('agua-citrus', 'Agua cítrica', 'drinks', 2.75)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

drop policy if exists "anyone can view product images" on storage.objects;
drop policy if exists "authenticated users can upload product images" on storage.objects;
drop policy if exists "authenticated users can update product images" on storage.objects;
create policy "anyone can view product images" on storage.objects
  for select using (bucket_id = 'product-images');
create policy "authenticated users can upload product images" on storage.objects
  for insert to authenticated with check (bucket_id = 'product-images' and public.is_administrator());
create policy "authenticated users can update product images" on storage.objects
  for update to authenticated using (bucket_id = 'product-images' and public.is_administrator());

-- Promueve manualmente una cuenta después de registrarla:
-- update public.profiles set role = 'administrator'
-- where id = (select id from auth.users where email = 'admin@restaurant.com');
