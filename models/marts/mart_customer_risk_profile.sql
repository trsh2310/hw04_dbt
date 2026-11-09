with customer_metrics as (
    select
        customer_id,
        min(transaction_time) as first_transaction_at,
        max(transaction_time) as last_transaction_at,
        count() as transaction_count,
        sum(is_fraud) as fraud_count,
        {{ fraud_rate('sum(is_fraud)', 'count()') }} as fraud_rate,
        sum(amount) as total_amount,
        sumIf(amount, is_fraud = 1) as fraud_amount,
        avg(amount) as average_amount,
        uniqExact(merchant) as unique_merchants,
        uniqExact(toDate(transaction_time)) as active_days
    from {{ ref('stg_transactions') }}
    group by customer_id
)

select
    *,
    {{ customer_risk('fraud_rate') }} as risk_level
from customer_metrics
