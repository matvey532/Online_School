-- Расчет суммарного кол-ва посетителей
SELECT COUNT(DISTINCT visitor_id)
FROM sessions;

-- Расчет кол-ва посетителей по источникам
WITH tab AS (
    SELECT
        count(visitor_id) AS visitor_count,
        upper(substring(
            CASE
                WHEN source ILIKE '%ya%' THEN 'yandex'
                WHEN
                    source ILIKE '%tg%' OR source ILIKE '%teleg%'
                    THEN 'telegram'
                WHEN source ILIKE '%vk%' THEN 'vkontakte'
                WHEN source ILIKE '%facebook%' THEN 'facebook'
                WHEN source ILIKE '%tw%' THEN 'twitter'
                ELSE source
            END,
            1, 1
        )) || substring(
            CASE
                WHEN source ILIKE '%ya%' THEN 'yandex'
                WHEN
                    source ILIKE '%tg%' OR source ILIKE '%teleg%'
                    THEN 'telegram'
                WHEN source ILIKE '%vk%' THEN 'vkontakte'
                WHEN source ILIKE '%facebook%' THEN 'facebook'
                WHEN source ILIKE '%tw%' THEN 'twitter'
                ELSE source
            END,
            2
        ) AS source
    FROM sessions
    GROUP BY 2
    ORDER BY 1 DESC
)

SELECT
    CASE
        WHEN visitor_count < 1000 THEN 'Other'
        ELSE source
    END AS source,
    sum(visitor_count) AS visitor_count
FROM tab
GROUP BY 1
ORDER BY 2 DESC;

-- Расчет кол-ва посетителей по дням месяца
select
    to_char(visit_date, 'DD-MM-YYYY') as date,
    count(distinct visitor_id) as visitor_count
from sessions
group by 1
order by 1;

-- Расчет кол-ва посетителей по неделям
select
    to_char(visit_date, 'W') as week_of_month,
    count(distinct visitor_id) as visitor_count
from sessions
group by 1
order by 1;


-- Расчет кол-ва посетителей по дням недели
WITH weekly_visits AS (
    SELECT
        EXTRACT(DOW FROM visit_date) AS day_of_week,
        COUNT(DISTINCT visitor_id) AS visitor_count
    FROM sessions
    GROUP BY EXTRACT(DOW FROM visit_date)
)

SELECT
    visitor_count,
    CASE
        WHEN day_of_week = 0 THEN '7.Sunday'
        WHEN day_of_week = 1 THEN '1.Monday'
        WHEN day_of_week = 2 THEN '2.Tuesday'
        WHEN day_of_week = 3 THEN '3.Wednesday'
        WHEN day_of_week = 4 THEN '4.Thursday'
        WHEN day_of_week = 5 THEN '5.Friday'
        WHEN day_of_week = 6 THEN '6.Saturday'
    END AS day_name
FROM weekly_visits
ORDER BY day_of_week;

--Расчет суммарного кол-ва лидов
SELECT COUNT(DISTINCT lead_id) as leads_count FROM leads;

--Расчет кол-ва созданных лидов по дням месяца
SELECT
    created_at::DATE AS creation_date,
    COUNT(DISTINCT lead_id) AS leads_count
FROM leads
GROUP BY created_at::DATE
ORDER BY creation_date;

-- Расчет метрик (cpu, cpl, cppu, roi) для utm_source
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
        on
            s.visitor_id = l.visitor_id
            and s.visit_date::date <= l.created_at::date
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
),

tab as (
    select
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        c.daily_spent as total_cost,
        count(s.visitor_id) as visitors_count,
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
        revenue desc nulls last,
        visit_date::date asc,
        visitors_count desc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
)

select
    tab.utm_source,
    coalesce(case
        when sum(tab.visitors_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.visitors_count), 2)
    end, 0) as cpu,
    coalesce(case
        when sum(tab.leads_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.leads_count), 2)
    end, 0) as cpl,
    coalesce(case
        when sum(tab.purchases_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.purchases_count), 2)
    end, 0) as cppu,
    coalesce(case
        when sum(tab.total_cost) = 0 then 0
        else
            round(
                (sum(tab.revenue) - sum(tab.total_cost))
                / sum(tab.total_cost)
                * 100,
                2
            )
    end, 0) as roi
from tab
where tab.utm_source in ('vk', 'yandex')
group by tab.utm_source;

-- Расчет метрик (cpu, cpl, cppu, roi) для utm_source, utm_medium и utm_campaign
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
        on
            s.visitor_id = l.visitor_id
            and s.visit_date::date <= l.created_at::date
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
),

tab as (
    select
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        c.daily_spent as total_cost,
        count(s.visitor_id) as visitors_count,
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
        revenue desc nulls last,
        visit_date::date asc,
        visitors_count desc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
)

select
    tab.utm_source,
    tab.utm_medium,
    tab.utm_campaign,
    coalesce(case
        when sum(tab.visitors_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.visitors_count), 2)
    end, 0) as cpu,
    coalesce(case
        when sum(tab.leads_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.leads_count), 2)
    end, 0) as cpl,
    coalesce(case
        when sum(tab.purchases_count) = 0 then 0
        else round(sum(tab.total_cost) / sum(tab.purchases_count), 2)
    end, 0) as cppu,
    coalesce(case
        when sum(tab.total_cost) = 0 then 0
        else
            round(
                (sum(tab.revenue) - sum(tab.total_cost))
                / sum(tab.total_cost)
                * 100,
                2
            )
    end, 0) as roi
from tab
where tab.utm_source in ('vk', 'yandex')
group by tab.utm_source, tab.utm_medium, tab.utm_campaign;


-- Расчет конверсий
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
        on
            s.visitor_id = l.visitor_id
            and s.visit_date::date <= l.created_at::date
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
),

tab as (
    select
        visit_date,
        source as utm_source,
        medium as utm_medium,
        campaign as utm_campaign,
        c.daily_spent as total_cost,
        count(s.visitor_id) as visitors_count,
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
        revenue desc nulls last,
        visit_date::date asc,
        visitors_count desc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
)

select
    round(
        sum(leads_count) / sum(visitors_count) * 100, 2
    ) as clicks_to_leads_conversion,
    round(
        sum(purchases_count) / sum(leads_count) * 100, 2
    ) as leads_to_purchases_conversion
from tab;


-- Расчет трат по каналам
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
        ya.campaign_date::date, ya.utm_source, ya.utm_medium, ya.utm_campaign
)

select
    campaign_date::date,
    utm_source,
    utm_medium,
    utm_campaign,
    daily_spent
from tab
order by campaign_date::date;

--Расчет кол-ва дней, за которое закрывается 90% лидов с момента перехода по рекламе
with tab as (
    select
        s.visitor_id,
        visit_date::date,
        lead_id,
        created_at::date,
        created_at::date - visit_date::date as days_passed,
        ntile(10) over (order by created_at::date - visit_date::date) as ntile
    from sessions as s
    inner join leads as l
        on s.visitor_id = l.visitor_id
    where
        closing_reason = 'Успешная продажа'
        and s.visit_date::date <= l.created_at::date
)

select max(days_passed) as days_passed
from tab
where ntile = 9;


--Расчет кол-ва визитов и кол-ва рекламных кампаний по дням месяца
select
    visit_date::date,
    count(distinct visitor_id) as visitor_count,
    count(distinct campaign) as campaign_count
from sessions
where source ilike '%vk%' or source ilike '%ya%'
group by visit_date::date
order by visit_date::date;


--Кол-во уникальных посетителей, лидов и закрытых лидов для воронки продаж
SELECT
    'visitors' AS category,
    COUNT(DISTINCT visitor_id) AS count
FROM sessions
UNION
SELECT
    'leads' AS category,
    COUNT(DISTINCT lead_id) AS count
FROM leads
UNION
SELECT
    'purchased_leads' AS category,
    COUNT(lead_id) FILTER (
        WHERE closing_reason = 'Успешно реализовано' OR status_id = 142
    ) AS count
FROM leads
ORDER BY count desc;
