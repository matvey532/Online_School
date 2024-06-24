with last_visits as (
    select
        visitor_id,
        max(visit_date) as last_visit
    from sessions
    group by visitor_id

)

select
    s.visitor_id,
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from sessions as s
inner join
    last_visits as lv
    on s.visitor_id = lv.visitor_id and s.visit_date = lv.last_visit
left join leads as l on s.visitor_id = l.visitor_id
where s.medium != 'organic'
order by
    amount desc nulls last, visit_date asc, utm_source asc, utm_medium asc, utm_campaign asc;
