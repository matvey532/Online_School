with tab as (
    select
        s.visitor_id,
        s.visit_date::date,
        l.lead_id,
        l.created_at::date,
        l.created_at::date - s.visit_date::date as days_passed,
        ntile(10) over (
            order by l.created_at::date - s.visit_date::date
        ) as ntile
    from sessions as s
    inner join leads as l
        on s.visitor_id = l.visitor_id
    where
        l.closing_reason = 'Успешная продажа'
        and s.visit_date::date <= l.created_at::date
)

select max(days_passed) as days_passed
from tab
where ntile = 9;
