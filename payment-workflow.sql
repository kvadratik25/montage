alter table public.montage_jobs
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists payment_claimed_at timestamptz,
  add column if not exists payment_confirmed_at timestamptz;

update public.montage_jobs
set payment_status = case when paid then 'paid' else 'unpaid' end
where payment_status <> 'claimed';

alter table public.montage_jobs
  drop constraint if exists montage_jobs_payment_status_check;

alter table public.montage_jobs
  add constraint montage_jobs_payment_status_check
  check (payment_status in ('unpaid', 'claimed', 'paid'));

create or replace function public.claim_job_payment(job_id uuid)
returns public.montage_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.montage_jobs;
begin
  update public.montage_jobs job
  set payment_status = 'claimed',
      payment_claimed_at = now(),
      payment_confirmed_at = null,
      updated_at = now()
  where job.id = job_id
    and job.paid = false
    and job.payment_status = 'unpaid'
    and exists (
      select 1
      from public.montage_access access
      where access.owner_id = job.user_id
        and access.viewer_id = auth.uid()
        and access.role = 'client'
    )
  returning job.* into result;

  if result.id is null then
    raise exception 'Ролик не найден или уже отмечен';
  end if;

  return result;
end;
$$;

revoke all on function public.claim_job_payment(uuid) from public;
grant execute on function public.claim_job_payment(uuid) to authenticated;
