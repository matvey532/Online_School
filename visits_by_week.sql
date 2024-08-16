with weekly_visits as (
    select
        extract(dow from s.visit_date) as day_of_week,
        count(distinct s.visitor_id) as visitor_count
    from sessions as s
    group by extract(dow from s.visit_date)
)

select
    wv.visitor_count,
    case
        when wv.day_of_week = 0 then '7.Sunday'
        when wv.day_of_week = 1 then '1.Monday'
        when wv.day_of_week = 2 then '2.Tuesday'
        when wv.day_of_week = 3 then '3.Wednesday'
        when wv.day_of_week = 4 then '4.Thursday'
        when wv.day_of_week = 5 then '5.Friday'
        when wv.day_of_week = 6 then '6.Saturday'
    end as day_name
from weekly_visits as wv
order by wv.day_of_week;