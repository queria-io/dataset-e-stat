SELECT
    cat01, cat02, cat03, time, unit, value,
    cat01_metadata, cat02_metadata, cat03_metadata, time_metadata
FROM {{ source('estat_source', 'corporate_finance_other_insurance_quarterly') }}
