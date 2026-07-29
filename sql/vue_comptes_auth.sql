-- Vue read-only sur les comptes GoTrue (auth.users) pour l'écran
-- « Administration des comptes » : liste des comptes créés (SSO ou e-mail)
-- afin de les rattacher facilement à une personne des opérations.
-- Idempotent. À exécuter sur la VM :
--   docker cp vue_comptes_auth.sql sfo-db:/tmp/
--   docker exec sfo-db sh -c 'psql -U postgres -d "$POSTGRES_DB" -f /tmp/vue_comptes_auth.sql'
-- (fonctionne aussi tel quel dans l'éditeur SQL Supabase cloud)

create or replace view public.comptes_auth as
  select u.email,
         u.created_at,
         u.last_sign_in_at,
         coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') as display_name
  from auth.users u
  where u.email is not null;

-- Réservé aux utilisateurs connectés : pas d'énumération de comptes en anonyme
grant select on public.comptes_auth to authenticated;
revoke select on public.comptes_auth from anon;

-- PostgREST : recharger le cache de schéma pour voir la nouvelle vue
notify pgrst, 'reload schema';
