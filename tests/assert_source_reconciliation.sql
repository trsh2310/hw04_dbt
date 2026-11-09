select 'row_count' as failed_check
where
    (select count() from {{ source('raw', 'transactions') }})
    != (select count() from {{ ref('stg_transactions') }})
union all
select 'fraud_count' as failed_check
where
    (select sum(target) from {{ source('raw', 'transactions') }})
    != (select sum(is_fraud) from {{ ref('stg_transactions') }})
union all
select 'total_amount' as failed_check
where
    (select sum(toDecimal64(toString(amount), 2)) from {{ source('raw', 'transactions') }})
    != (select sum(amount) from {{ ref('stg_transactions') }})
