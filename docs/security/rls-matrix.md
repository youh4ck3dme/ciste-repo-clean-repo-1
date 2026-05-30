# RLS matrix baseline

Tento dokument definuje baseline Row-Level Security (RLS) politík po deduplikácii a zjednotení názvoslovia na formát:

`<table>_<role>_<action>`

Kde role = `anon | authenticated | service_role | admin`, action = `select | insert | update | delete`.

> Poznámka: `service_role` a `admin` sú považované za trusted backend roly (full access), ostatné roly sú deny-by-default s explicitným povolením iba tam, kde je to potrebné.

## bookings

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | deny | deny | deny | deny | n/a |
| authenticated | allow | allow | allow | deny | `user_id = auth.uid()` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## push_subscriptions

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | deny | deny | deny | deny | n/a |
| authenticated | allow | allow | allow | allow | `user_id = auth.uid()` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## blocked_dates

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | allow | deny | deny | deny | `true` |
| authenticated | allow | deny | deny | deny | `true` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## time_slots_config

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | allow | deny | deny | deny | `true` |
| authenticated | allow | deny | deny | deny | `true` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## favorite_services

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | deny | deny | deny | deny | n/a |
| authenticated | allow | allow | allow | allow | `user_id = auth.uid()` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## client_profiles

| role | SELECT | INSERT | UPDATE | DELETE | condition |
|---|---|---|---|---|---|
| anon | deny | deny | deny | deny | n/a |
| authenticated | allow | allow | allow | deny | `id = auth.uid()` |
| service_role | allow | allow | allow | allow | `true` |
| admin | allow | allow | allow | allow | `true` |

## Ďalšie tabuľky s duplicitami

Pri ďalších tabuľkách postupuj rovnako:

1. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`.
2. Export existujúcich policies z `pg_policies`.
3. Odstráň duplicity tak, aby pre každú kombináciu `(table, role, action)` ostala 1 policy.
4. Premenuj policy na `<table>_<role>_<action>`.
5. Deny-by-default verifikuj smoke testom.
