with tab as (
    select
        'visitors' as category,
        count(distinct visitor_id) as counta
    from sessions

    union all

    select
        'leads' as category,
        count(distinct lead_id) as counta
    from leads

    union all

    select
        'purchased_leads' as category,
        count(lead_id) filter (
            where closing_reason = 'Успешно реализовано' or status_id = 142
        ) as counta
    from leads
)

select
    t.category,
    t.counta
from tab as t
order by t.counta desc;