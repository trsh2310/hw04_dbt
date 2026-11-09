with hourly_metrics as (
    select
        day_of_week,
        transaction_hour,
        count() as transaction_count,
        sum(is_fraud) as fraud_count,
        {{ fraud_rate('sum(is_fraud)', 'count()') }} as fraud_rate,
        sum(amount) as total_amount,
        sumIf(amount, is_fraud = 1) as fraud_amount
    from {{ ref('stg_transactions') }}
    group by day_of_week, transaction_hour
),

with_baseline as (
    select
        *,
        {{ fraud_rate('sum(fraud_count) over ()', 'sum(transaction_count) over ()') }}
            as overall_fraud_rate
    from hourly_metrics
)

select
    *,
    fraud_rate / nullif(overall_fraud_rate, 0) as risk_lift,
    toUInt8(fraud_rate > overall_fraud_rate) as is_high_risk_window
from with_baseline
