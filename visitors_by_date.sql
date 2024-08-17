select
    to_char(visit_date, 'DD-MM-YYYY') as visit_date,
    count(distinct visitor_id) as visitor_count
from sessions
group by visit_date
order by visit_date;
