with sales as (
    select
        s.visitor_id,
        s.visit_date::date as visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date::date desc
        ) as sale_count
    from sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id
       and s.visit_date::date <= l.created_at::date
    where s.medium != 'organic'
),

costs as (
    select
        vk.campaign_date::date as campaign_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    from vk_ads as vk
    group by vk.campaign_date, vk.utm_source, vk.utm_medium, vk.utm_campaign
    union all
    select
        ya.campaign_date::date as campaign_date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    from ya_ads as ya
    group by ya.campaign_date, ya.utm_source, ya.utm_medium, ya.utm_campaign
),

tab as (
    select
        s.visit_date::date as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        c.daily_spent as total_cost,
        count(s.visitor_id) as visitors_count,
        count(s.lead_id) as leads_count,
        count(s.lead_id) filter (
            where s.closing_reason = 'успешно реализовано' or s.status_id = 142
        ) as purchases_count,
        sum(s.amount) as revenue
    from sales as s
    left join costs as c
        on s.source = c.utm_source
       and s.medium = c.utm_medium
       and s.campaign = c.utm_campaign
       and s.visit_date::date = c.campaign_date
    where s.sale_count = 1
    group by s.visit_date, s.source, s.medium, s.campaign, c.daily_spent
)

select
    tab.utm_source,
    coalesce(
        case
            when sum(tab.visitors_count) = 0 then 0
            else round(sum(tab.total_cost) / sum(tab.visitors_count), 2)
        end,
        0
    ) as cpu,
    coalesce(
        case
            when sum(tab.leads_count) = 0 then 0
            else round(sum(tab.total_cost) / sum(tab.leads_count), 2)
        end,
        0
    ) as cpl,
    coalesce(
        case
            when sum(tab.purchases_count) = 0 then 0
            else round(sum(tab.total_cost) / sum(tab.purchases_count), 2)
        end,
        0
    ) as cppu,
    coalesce(
        case
            when sum(tab.total_cost) = 0 then 0
            else round(
                (sum(tab.revenue) - sum(tab.total_cost)) /
                sum(tab.total_cost) * 100, 2
            )
        end,
        0
    ) as roi
from tab
where tab.utm_source in ('vk', 'yandex')
group by tab.utm_source;
