-- Dimension: Item Attributes
-- 1 row per item + attribute combination
-- Enables Power BI slicing by color, size, composition, etc.
-- Long format: item_code | attribute | attribute_value

DROP TABLE IF EXISTS mart.dim_item_attribute CASCADE;
CREATE TABLE mart.dim_item_attribute AS
SELECT
    ROW_NUMBER() OVER (ORDER BY item_code, attribute, attribute_value) AS attribute_key,
    item_code,
    attribute,
    attribute_value,
    is_numeric,
    from_range,
    to_range,
    increment,
    NOW() AS dw_load_date
FROM staging.stg_item_variant_attribute
ORDER BY item_code, attribute, attribute_value;

ALTER TABLE mart.dim_item_attribute ADD PRIMARY KEY (attribute_key);
CREATE INDEX idx_dim_item_attribute_item ON mart.dim_item_attribute(item_code);
CREATE INDEX idx_dim_item_attribute_attr ON mart.dim_item_attribute(attribute);
CREATE INDEX idx_dim_item_attribute_value ON mart.dim_item_attribute(attribute_value);
CREATE INDEX idx_dim_item_attribute_composite ON mart.dim_item_attribute(item_code, attribute);
