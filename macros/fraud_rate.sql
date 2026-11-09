{% macro fraud_rate(fraud_count, transaction_count) -%}
    100.0 * {{ fraud_count }} / nullif({{ transaction_count }}, 0)
{%- endmacro %}
