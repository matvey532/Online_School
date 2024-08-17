select
    s.visit_date::date as visit_date,
    count(distinct s.visitor_id) as visitor_count,
    count(distinct s.campaign) as campaign_count
from sessions as s
where s.source ilike '%vk%' or s.source ilike '%ya%'
group by s.visit_date
order by s.visit_date;