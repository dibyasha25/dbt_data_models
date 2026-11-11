{#
    Renames a column by removing a prefix: strip_prefix('l_quantity', 'l_')
    compiles to:  l_quantity as quantity

    Caveats:
    - It only removes the prefix. 'o_orderkey' becomes 'orderkey', NOT 'order_id',
      so it doesn't produce this project's *_id key names. Keys are renamed explicitly.
    - Jinja's replace() removes the prefix text ANYWHERE in the name, not just at the
      start (e.g. prefix 'l_' would also hit 'total_l_value'). Safe for TPC-H's names.
#}

{% macro strip_prefix(column_name, prefix) -%}
    {{ column_name }} as {{ column_name | replace(prefix, '') }}
{%- endmacro %}
