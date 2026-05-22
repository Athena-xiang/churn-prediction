WITH qualifying AS (
      SELECT DISTINCT c.customer_unique_id
      FROM orders o
      JOIN customers c ON o.customer_id = c.customer_id
      WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp <  '2018-03-01'
),
    
order_base AS (
      SELECT
          c.customer_unique_id,
          o.order_id,
          o.order_purchase_timestamp,
          o.order_delivered_customer_date,
          o.order_estimated_delivery_date
      FROM orders o
      JOIN customers c ON o.customer_id = c.customer_id
      WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp <  '2018-03-01'
),

payment_agg AS (
      SELECT
          ob.customer_unique_id,
          SUM(op.payment_value) as monetary,
          AVG(op.payment_value) as avg_order_value,
          MAX(op.payment_installments) as max_installments,
          AVG(CASE WHEN op.payment_type = 'credit_card' THEN 1.0 ELSE 0.0 END) as credit_card_ratio
      FROM order_base ob
      JOIN order_payments op ON ob.order_id = op.order_id
      GROUP BY ob.customer_unique_id
),

review_agg AS (
      SELECT
          ob.customer_unique_id,
          AVG(r.review_score) as avg_review_score,
          MIN(r.review_score) as min_review_score,
          COUNT(r.review_id) as review_count
      FROM order_base ob
      LEFT JOIN order_reviews r ON ob.order_id = r.order_id
      GROUP BY ob.customer_unique_id
),

product_agg AS (
      SELECT
          ob.customer_unique_id,
          COUNT(DISTINCT oi.product_id) as num_unique_products,
          COUNT(DISTINCT p.product_category_name) as category_diversity,
          AVG(oi.freight_value / NULLIF(oi.price, 0)) as avg_freight_ratio
      FROM order_base ob
      JOIN order_items oi ON ob.order_id = oi.order_id
      JOIN products p ON oi.product_id = p.product_id
      GROUP BY ob.customer_unique_id
),

delivery_agg AS (
      SELECT
          customer_unique_id,
          AVG(
              JULIANDAY(order_delivered_customer_date) -
              JULIANDAY(order_estimated_delivery_date)
          ) as avg_delivery_delay_days,  -- 负数=提前，正数=延迟
          COUNT(CASE
              WHEN order_delivered_customer_date > order_estimated_delivery_date
              THEN 1 END) as late_delivery_count
      FROM order_base
      WHERE order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
      GROUP BY customer_unique_id
),

rfm AS (
      SELECT
          customer_unique_id,
          COUNT(DISTINCT order_id) as frequency,
          ROUND(JULIANDAY('2018-03-01') - JULIANDAY(MAX(order_purchase_timestamp))) as recency_days,
          MIN(order_purchase_timestamp) as first_purchase_date
      FROM order_base
      GROUP BY customer_unique_id
),

churn_label AS (
      SELECT
          q.customer_unique_id,
          CASE WHEN COUNT(o.order_id) > 0 THEN 0 ELSE 1 END as churned
      FROM qualifying q
      LEFT JOIN customers c  ON q.customer_unique_id = c.customer_unique_id
      LEFT JOIN orders o     ON c.customer_id = o.customer_id
                            AND o.order_status = 'delivered'
                            AND o.order_purchase_timestamp >= '2018-03-01'
                            AND o.order_purchase_timestamp <  '2018-09-01'
      GROUP BY q.customer_unique_id
)

SELECT
    q.customer_unique_id,
    r.recency_days,
    r.frequency,
    pa.monetary,
    pa.avg_order_value,
    COALESCE(ra.avg_review_score, 3.0) as avg_review_score,
    COALESCE(ra.min_review_score, 3)   as min_review_score,
    COALESCE(ra.review_count, 0)       as review_count,
    COALESCE(pra.num_unique_products, 1)  as num_unique_products,
    COALESCE(pra.category_diversity, 1)   as category_diversity,
    COALESCE(pra.avg_freight_ratio, 0.2)  as avg_freight_ratio,
    COALESCE(pa.credit_card_ratio, 0)     as credit_card_ratio,
    COALESCE(pa.max_installments, 1)      as max_installments,
    COALESCE(da.avg_delivery_delay_days, 0) as avg_delivery_delay_days,
    COALESCE(da.late_delivery_count, 0)     as late_delivery_count,
    cl.churned
FROM qualifying q
JOIN rfm          r   ON q.customer_unique_id = r.customer_unique_id
JOIN payment_agg  pa  ON q.customer_unique_id = pa.customer_unique_id
LEFT JOIN review_agg   ra  ON q.customer_unique_id = ra.customer_unique_id
LEFT JOIN product_agg  pra ON q.customer_unique_id = pra.customer_unique_id
LEFT JOIN delivery_agg da  ON q.customer_unique_id = da.customer_unique_id
JOIN churn_label  cl  ON q.customer_unique_id = cl.customer_unique_id

