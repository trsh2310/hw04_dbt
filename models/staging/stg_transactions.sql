with normalized as (
    select
        cast(transaction_time as DateTime) as transaction_time,
        cast(lat as Float64) as latitude,
        cast(lon as Float64) as longitude,
        cast(merchant_lat as Float64) as merchant_latitude,
        cast(merchant_lon as Float64) as merchant_longitude,
        cast(target as UInt8) as is_fraud,
        trimBoth(merch) as merchant,
        lowerUTF8(trimBoth(cat_id)) as category,
        toDecimal64(toString(amount), 2) as amount,
        lowerUTF8(trimBoth(name_1)) as first_name,
        lowerUTF8(trimBoth(name_2)) as last_name,
        upperUTF8(trimBoth(gender)) as gender,
        upperUTF8(trimBoth(us_state)) as us_state
    from {{ source('raw', 'transactions') }}
)

select
    {{ dbt_utils.generate_surrogate_key([
        'transaction_time', 'merchant', 'category', 'amount',
        'first_name', 'last_name', 'gender', 'us_state',
        'latitude', 'longitude', 'merchant_latitude', 'merchant_longitude', 'is_fraud'
    ]) }} as transaction_id,
    {{ dbt_utils.generate_surrogate_key([
        'first_name', 'last_name', 'gender', 'latitude', 'longitude'
    ]) }} as customer_id,
    transaction_time,
    toDate(transaction_time) as transaction_date,
    {{ dbt_date.day_of_week('transaction_time', isoweek=true) }} as day_of_week,
    toHour(transaction_time) as transaction_hour,
    merchant,
    category,
    amount,
    {{ amount_bucket('amount') }} as amount_bucket,
    gender,
    us_state,
    latitude,
    longitude,
    merchant_latitude,
    merchant_longitude,
    is_fraud
from normalized
