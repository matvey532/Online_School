with last_visits as (
    select
        visitor_id,
        max(visit_date) as last_visit
    from sessions
    group by visitor_id
),

paid_leads as (
    select
        visitor_id,
        lead_id,
        amount
    from leads
    where closing_reason = 'Успешно реализовано' or status_id = 142
),

costs as (
    select
        vk.campaign_date,
        vk.utm_source,
        vk.daily_spent
    from vk_ads as vk
    union
    select
        ya.campaign_date,
        ya.utm_source,
        ya.daily_spent
    from ya_ads as ya
)

select
    visit_date,
    source as utm_source,
    medium as utm_medium,
    campaign as utm_campaign,
    count(s.visitor_id) as visitors_count,
    sum(c.daily_spent) as total_cost,
    count(l.lead_id) as leads_count,
    count(pl.lead_id) as purchases_count,
    sum(pl.amount) as revenue
from sessions as s
left join leads as l on s.visitor_id = l.visitor_id
inner join paid_leads as pl on l.visitor_id = pl.visitor_id
inner join
    last_visits as lv
    on s.visitor_id = lv.visitor_id and s.visit_date = lv.last_visit
inner join costs as c on s.source = c.utm_source
where s.medium != 'organic'
group by visit_date, source, medium, campaign
order by
    revenue desc nulls last,
    visit_date asc,
    visitors_count desc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc;