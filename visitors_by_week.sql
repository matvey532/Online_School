select
    to_char(visit_date, 'W') as week_of_month,
    count(distinct visitor_id) as visitor_count
from sessions
group by week_of_month
order by week_of_month;