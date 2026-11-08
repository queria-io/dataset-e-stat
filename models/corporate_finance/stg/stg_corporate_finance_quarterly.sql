{# 並べてからテーブルにする。読み手は scope・item_code・industry_code・size_code で
   絞ることが多いので、その順に並べておくと行グループの統計で読み飛ばせる。 #}
{% set tables = [
    ('raw_corporate_finance_nonfinancial_quarterly', 'nonfinancial', '金融業、保険業以外の業種', 'false'),
    ('raw_corporate_finance_nonfinancial_sa_quarterly', 'nonfinancial', '金融業、保険業以外の業種', 'true'),
    ('raw_corporate_finance_all_industries_quarterly', 'all_industries', '全産業（金融業、保険業を含む）', 'false'),
    ('raw_corporate_finance_finance_insurance_quarterly', 'finance_insurance', '金融業、保険業', 'false'),
    ('raw_corporate_finance_banking_quarterly', 'banking', '銀行業', 'false'),
    ('raw_corporate_finance_nondeposit_credit_quarterly', 'nondeposit_credit', '貸金業、クレジットカード業等非預金信用機関', 'false'),
    ('raw_corporate_finance_securities_quarterly', 'securities', '金融商品取引業（第一種金融商品取引業であって有価証券関連業に限る）', 'false'),
    ('raw_corporate_finance_other_securities_quarterly', 'other_securities', 'その他の金融商品取引業、商品先物取引業', 'false'),
    ('raw_corporate_finance_insurance_quarterly', 'insurance', '保険業（その他の保険業を除く）', 'false'),
    ('raw_corporate_finance_other_insurance_quarterly', 'other_insurance', 'その他の保険業', 'false'),
] %}
SELECT *
FROM (
    {{ e_stat_corporate_finance_stg(tables, quarterly=true) }}
)
ORDER BY scope, seasonally_adjusted, item_code, industry_code, size_code, time
