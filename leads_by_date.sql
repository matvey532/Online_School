select
    l.created_at::date as creation_date,
    count(distinct l.lead_id) as leads_count
from leads as l
group by creation_date
order by creation_date asc;