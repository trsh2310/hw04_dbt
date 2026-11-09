{% macro customer_risk(rate) -%}
    case
        when {{ rate }} >= {{ var('customer_high_risk_rate') }} then 'HIGH'
        when {{ rate }} >= {{ var('customer_medium_risk_rate') }} then 'MEDIUM'
        else 'LOW'
    end
{%- endmacro %}
