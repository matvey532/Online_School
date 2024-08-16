with sales as (
    select
        s.visitor_id,
        s.visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.closing_reason,
        l.status_id,
        row_number()
		over (partition by s.visitor_id order by s.visit_date desc)
        as sale_count
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date <= l.created_at
    where s.medium != 'organic'
)

select
    s.visitor_id,
    s.visit_date,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    s.lead_id,
    s.created_at,
    s.amount,
    s.closing_reason,
    s.status_id
from sales as s
where s.sale_count = 1
order by
    s.amount desc nulls last,
    s.visit_date::date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10;
