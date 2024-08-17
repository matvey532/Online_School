with tab as (
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
        ya.campaign_date, ya.utm_source, ya.utm_medium, ya.utm_campaign
)

select
    tab.campaign_date::date,
    tab.utm_source,
    tab.utm_medium,
    tab.utm_campaign,
    tab.daily_spent
from tab
order by tab.campaign_date;