| ?column?                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Table: bom_lines
product_id int4
product_qty numeric
write_date timestamp
updated_at timestamp
bom_line_id_1 int4
bom_line_id_2 int4
bom_line_id_8 int4
bom_line_id_7 int4
bom_line_id_6 int4
bom_line_id_5 int4
bom_line_id_4 int4
bom_line_id_3 int4
product_uom text
product_name text
bom_id int4 NOT NULL
bom_line_id_10 int4
bom_line_id_9 int4
                                                                                         |
| Table: coo_reports
report_content jsonb
report_pdf_url text
generated_at timestamp
report_type text
id int4 NOT NULL
report_week date NOT NULL
                                                                                                                                                                                                                                                                                                |
| Table: email_logs
total_alerts int4
subject text NOT NULL
recipient_name text
recipient_email text NOT NULL
error_message text
status text NOT NULL
id int8 NOT NULL
critical_count int4
warning_count int4
sent_at timestamptz NOT NULL
created_at timestamptz NOT NULL
                                                                                                                                                                      |
| Table: lead_times
updated_at timestamp
created_at timestamp
id int4 NOT NULL
lead_time_days int4 NOT NULL
product_name text NOT NULL
category text
supplier_name text
notes text
product_id int4
                                                                                                                                                                                                                                              |
| Table: production_simulations
estimated_cost numeric
product_name text
earliest_production_date date
auto_generated_pos _text
created_by text
target_quantity numeric
product_id int4
id int4 NOT NULL
simulation_date timestamp
is_feasible bool
missing_materials jsonb
                                                                                                                                                                     |
| Table: products
type text
id int4 NOT NULL
list_price numeric
standard_price numeric
categ_id int4
x_min_stock numeric
x_max_stock numeric
x_daily_avg_sales numeric
x_lead_time_days int4
x_auto_reorder bool
write_date timestamp
updated_at timestamp
qty_available numeric
virtual_available numeric
incoming_qty numeric
outgoing_qty numeric
reordering_min_qty numeric
reordering_max_qty numeric
name text NOT NULL
default_code text
 |
| Table: purchase_order_lines
product_qty numeric
price_total numeric
price_unit numeric
write_date timestamptz
product_id int4
order_id int4
id int4 NOT NULL
date_planned timestamp
product_name text
updated_at timestamp
                                                                                                                                                                                                                    |
| Table: purchase_orders
amount_total numeric
date_order timestamp
partner_id int4
id int4 NOT NULL
partner_name text
state text
name text
updated_at timestamp
write_date timestamp
date_planned timestamp
                                                                                                                                                                                                                                     |
| Table: rupture_alerts
status varchar
alert_type varchar NOT NULL
store_number varchar NOT NULL
saq_code varchar NOT NULL
updated_at timestamptz
created_at timestamptz
resolved_at timestamptz
escalated_at timestamptz
days_in_rupture int4
alert_date date NOT NULL
id int8 NOT NULL
sales_rep_email varchar
escalated_to varchar
                                                                                                           |
| Table: saq_products
saq_code varchar NOT NULL
supplier_no varchar
status varchar
updated_at timestamptz
created_at timestamptz
odoo_product_id int4
sales_price numeric
description text
format varchar
                                                                                                                                                                                                                                       |
| Table: saq_store_inventory
created_at timestamptz
is_warning bool
days_of_inventory numeric
store_number varchar NOT NULL
saq_code varchar NOT NULL
avg_weekly_sales numeric
updated_at timestamptz
snapshot_date date NOT NULL
id int8 NOT NULL
qty_inventory int4
is_critical bool
                                                                                                                                                          |
| Table: saq_stores
store_name varchar
region varchar
sales_rep_name varchar
sales_rep_email varchar
created_at timestamptz
updated_at timestamptz
store_number varchar NOT NULL
city varchar
                                                                                                                                                                                                                                                   |
| Table: saq_weekly_sales
updated_at timestamptz
year int4 NOT NULL
period int4 NOT NULL
week_start_date date NOT NULL
saq_code varchar NOT NULL
store_number varchar NOT NULL
is_rupture bool
created_at timestamptz
amount numeric
week int4 NOT NULL
id int8 NOT NULL
qty_bottles int4
                                                                                                                                                       |
| Table: stock_movements
product_id int4
product_name text
state text
updated_at timestamp
write_date timestamp
date timestamp
product_qty numeric
location_dest_id int4
id int4 NOT NULL
location_id int4
                                                                                                                                                                                                                                      |
| Table: stock_quants
reserved_quantity float4
available_quantity float4
product_id int4
write_date timestamp
updated_at timestamp
location_name text
product_name text
id int4 NOT NULL
location_id int4
quantity float4
                                                                                                                                                                                                                       |