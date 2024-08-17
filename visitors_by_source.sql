with tab as (
    select
        count(visitor_id) as visitor_count,
        upper(substring(
            case
                when source ilike '%ya%' then 'yandex'
                when source ilike '%tg%' or source ilike '%teleg%' 
                    then 'telegram'
                when source ilike '%vk%' then 'vkontakte'
                when source ilike '%facebook%' then 'facebook'
                when source ilike '%tw%' then 'twitter'
                else source
            end, 1, 1
        )) || substring(
            case
                when source ilike '%ya%' then 'yandex'
                when source ilike '%tg%' or source ilike '%teleg%' then 'telegram'
                when source ilike '%vk%' then 'vkontakte'
                when source ilike '%facebook%' then 'facebook'
                when source ilike '%tw%' then 'twitter'
                else source
            end, 2
        ) as source
    from sessions
    group by 2
)

select
    case
        when sum(visitor_count) < 1000 then 'other'
        else source
    end as source,
    sum(visitor_count) as visitor_count
from tab
group by source
order by visitor_count desc;
