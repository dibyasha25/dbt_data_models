{#
    Converts an integer amount in cents to dollars:
    cents_to_dollars('amount_cents') compiles to  (amount_cents / 100.0)::decimal(18,2)

    WARNING: do NOT apply this to TPC-H price columns. They are already in dollars
    (DECIMAL(15,2), e.g. 901.00 to 95,949.50), so dividing by 100 would make every
    revenue figure 100x too small without any error. Built here to learn macros only.
#}

{% macro cents_to_dollars(column_name) -%}
    ({{ column_name }} / 100.0)::decimal(18, 2)
{%- endmacro %}
