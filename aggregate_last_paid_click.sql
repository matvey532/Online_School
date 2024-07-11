-- Шаг 3. Расчет расходов

with sales as (
    select
        s.visitor_id,
        s.visit_date::date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.closing_reason,
        status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date::date desc)
        as sale_count
    from sessions as s
    left join
        leads as l
        on s.visitor_id = l.visitor_id and s.visit_date::date <= l.created_at::date
    where s.medium != 'organic'
),

costs as (
    select
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    from vk_ads as vk
    group by
        vk.campaign_date::date, vk.utm_source, vk.utm_medium, vk.utm_campaign
    union all
    select
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    from ya_ads as ya
    group by
        ya.campaign_date::date, ya.utm_source, ya.utm_medium, ya.utm_campaign
)

select
    visit_date,
    source as utm_source,
    medium as utm_medium,
    campaign as utm_campaign,
    count(s.visitor_id) as visitors_count,
    c.daily_spent as total_cost,
    count(lead_id) as leads_count,
    count(lead_id) filter (
        where closing_reason = 'Успешно реализовано' or status_id = 142
    ) as purchases_count,
    sum(s.amount) as revenue
from sales as s
left join
    costs as c
    on
        s.source = c.utm_source
        and s.medium = c.utm_medium
        and s.campaign = c.utm_campaign
        and s.visit_date::date = c.campaign_date
where s.sale_count = 1
group by visit_date::date, source, medium, campaign, c.daily_spent
order by
    revenue desc nulls last, visit_date::date asc, visitors_count desc, utm_source asc, utm_medium asc, utm_campaign asc;
