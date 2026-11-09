with merchant_metrics as (
    select
        merchant,
        count() as transaction_count,
        sum(is_fraud) as fraud_count,
        {{ fraud_rate('sum(is_fraud)', 'count()') }} as fraud_rate,
        sum(amount) as total_amount,
        sumIf(amount, is_fraud = 1) as fraud_amount,
        avg(amount) as average_amount,
        uniqExact(customer_id) as unique_customers,
        uniqExact(us_state) as states_count
    from {{ ref('stg_transactions') }}
    group by merchant
)

select
    *,
    toUInt8(
        fraud_rate >= {{ var('suspicious_merchant_rate') }}
        and transaction_count >= {{ var('suspicious_merchant_min_transactions') }}
    ) as is_suspicious
from merchant_metrics
