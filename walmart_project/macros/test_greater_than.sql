{% test greater_than(model, column_name, value) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} <= {{ value }}

{% endtest %}
