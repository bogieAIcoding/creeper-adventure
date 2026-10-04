-- Apply AFTER schema.sql in the Supabase SQL Editor before a future release.
-- Preserves existing records and old-client submissions. No admin keys in HTML.
begin;
alter table public.completed_runs add column if not exists scoring_version integer not null default 1;
alter table public.completed_runs add column if not exists secret_victory boolean not null default false;
alter table public.completed_runs enable row level security;
alter table public.score_rewards enable row level security;
alter table public.score_limits enable row level security;
revoke all on public.completed_runs,public.score_rewards,public.score_limits from public,anon,authenticated;
create or replace function public.submit_run(payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid(); run_id uuid; display_name text; record public.completed_runs;
  event text; reward integer; total integer := 0; death_count integer := 0;
  seen text[] := array[]::text[]; seconds double precision[]; stage integer := 0;
  completed boolean := false; bonus_due boolean := false; limits public.score_limits;
  expected_bonus integer; milliseconds bigint; rules integer := 1; secret_started boolean := false; secret_finished boolean := false; secret_won boolean := false; secret_hits integer := 0;
begin
  if owner_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if jsonb_typeof(payload) <> 'object' or pg_column_size(payload)>200000 or
     not (payload ?& array['id','name','score','deaths','world_seconds','trace']) or
     (select count(*) from jsonb_object_keys(payload))<>6 then raise exception 'Invalid run payload'; end if;
  if jsonb_typeof(payload->'id')<>'string' or (payload->>'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'Invalid run ID'; end if;
  run_id := (payload->>'id')::uuid;
  select * into record from public.completed_runs where id=run_id;
  if found then
    if record.player_id<>owner_id then raise exception 'Run ID already used' using errcode='42501'; end if;
    return jsonb_build_object('id',record.id,'score',record.score,'duplicate',true);
  end if;
  display_name := payload->>'name';
  if jsonb_typeof(payload->'name')<>'string' or display_name<>btrim(display_name) or char_length(display_name) not between 3 and 16 or display_name !~ '^[[:alnum:] _-]+$' or btrim(display_name)='' then raise exception 'Invalid player name'; end if;
  if jsonb_typeof(payload->'score')<>'number' or (payload->>'score') !~ '^[0-9]{1,7}$' or
     jsonb_typeof(payload->'deaths')<>'number' or (payload->>'deaths') !~ '^[0-9]{1,4}$' or
     (payload->>'deaths')::integer>1000 then raise exception 'Invalid score or deaths'; end if;
  if jsonb_typeof(payload->'world_seconds')<>'array' or jsonb_array_length(payload->'world_seconds')<>3 or
     jsonb_typeof(payload->'trace')<>'array' or jsonb_array_length(payload->'trace') not between 9 and 3000 then raise exception 'Invalid completion history'; end if;
  for stage in 0..2 loop
    if jsonb_typeof(payload->'world_seconds'->stage)<>'number' then raise exception 'Invalid completion time'; end if;
    seconds[stage+1] := (payload->'world_seconds'->>stage)::double precision;
    if seconds[stage+1]<=0 or seconds[stage+1]>86400 then raise exception 'Invalid completion time'; end if;
  end loop;
  stage:=0;
  if payload->'trace'->>0='rules:2' then rules:=2;end if;
  for event in select jsonb_array_elements_text(payload->'trace') loop
    if event='rules:2' then
      if rules<>2 or cardinality(seen)>0 then raise exception 'Invalid scoring rules';end if;
      seen:=array_append(seen,event);continue;
    end if;
    if completed then
      if rules<>2 or death_count<>0 or secret_finished then raise exception 'History after completion';end if;
      if event='secret:enter' and not secret_started then secret_started:=true;
      elsif secret_started and secret_hits<9 and event=('secret:hit:'||(secret_hits+1)::text) then secret_hits:=secret_hits+1;
      elsif event='secret:victory' and secret_started and secret_hits=9 then secret_finished:=true;secret_won:=true;total:=total+15000;
      elsif event='secret:failed' and secret_started and secret_hits<9 then secret_finished:=true;
      else raise exception 'Invalid secret encounter history';end if;
      continue;
    end if;
    if bonus_due and event<>(stage::text||':timeBonus') then raise exception 'Missing time bonus'; end if;
    if event='death' then death_count:=death_count+1;total:=case when rules=2 then greatest(0,total-2000) else floor(total/2.0) end;continue;end if;
    if event=any(seen) or event not like (stage::text||':%') then raise exception 'Duplicate or out-of-order reward'; end if;
    seen:=array_append(seen,event);
    if event=(stage::text||':timeBonus') then
      if not bonus_due then raise exception 'Invalid time bonus'; end if;
      expected_bonus:=floor(3000*greatest(0,600-seconds[stage+1])/600);
      total:=total+expected_bonus;bonus_due:=false;
      if stage=2 then completed:=true;else stage:=stage+1;end if;
    else
      select points into reward from public.score_rewards where id=event;
      if reward is null then raise exception 'Unknown reward';end if;
      if event=(stage::text||':world') then
        if not ((stage::text||':boss')=any(seen)) or not ((stage::text||':stage:1')=any(seen)) or not ((stage::text||':stage:2')=any(seen)) or not ((stage::text||':stage:3')=any(seen)) then raise exception 'Boss must be defeated';end if;
        bonus_due:=true;
      end if;
      total:=total+reward;
    end if;
  end loop;
  if not completed or total<>(payload->>'score')::integer or death_count<>(payload->>'deaths')::integer then raise exception 'Score does not match completed history'; end if;
  if rules=2 and death_count=0 and not secret_finished then raise exception 'Secret attempt must conclude';end if;
  milliseconds:=round((seconds[1]+seconds[2]+seconds[3])*1000);
  -- Lock one row per identity. Concurrent retries are safe and rate limited.
  insert into public.score_limits values(owner_id,now(),0) on conflict do nothing;
  select * into limits from public.score_limits where player_id=owner_id for update;
  select * into record from public.completed_runs where id=run_id;
  if found then
    if record.player_id<>owner_id then raise exception 'Run ID already used' using errcode='42501';end if;
    return jsonb_build_object('id',record.id,'score',record.score,'duplicate',true);
  end if;
  if limits.window_start<now()-interval '10 minutes' then limits.window_start:=now();limits.submissions:=0;end if;
  if limits.submissions>=5 then raise exception 'Too many submissions. Please wait ten minutes.';end if;
  update public.score_limits set window_start=limits.window_start,submissions=limits.submissions+1 where player_id=owner_id;
  insert into public.completed_runs(id,player_id,name,score,deaths,completion_ms,scoring_version,secret_victory) values(run_id,owner_id,display_name,total,death_count,milliseconds,rules,secret_won);
  return jsonb_build_object('id',run_id,'score',total,'duplicate',false);
end $$;

create or replace function public.read_leaderboard() returns jsonb
language sql stable security definer set search_path = '' as $$
  with personal as (
    select distinct on (player_id) * from public.completed_runs
    order by player_id,score desc,completion_ms asc,deaths asc,completed_at asc,id asc
  ), ranked as (
    select *,row_number() over(order by score desc,completion_ms asc,deaths asc,completed_at asc,id asc) rank from personal
  ), display as (
    select player_id,jsonb_build_object('id',id,'rank',rank,'name',name,'score',score,'deaths',deaths,'completion_ms',completion_ms,'completed_at',completed_at,'secret_victory',secret_victory) entry,rank from ranked
  )
  select jsonb_build_object('top',coalesce((select jsonb_agg(entry order by rank) from display where rank<=10),'[]'::jsonb),'me',(select entry from display where player_id=auth.uid()));
$$;
revoke all on function public.submit_run(jsonb),public.read_leaderboard() from public,anon,authenticated;
grant execute on function public.submit_run(jsonb) to authenticated;
grant execute on function public.read_leaderboard() to anon,authenticated;

commit;
