{# 並べてからテーブルにする。読み手は scope・item_code・industry_code・size_code で
   絞ることが多いので、その順に並べておくと行グループの統計で読み飛ばせる。 #}
{% set tables = [
    ('raw_corporate_finance_nonfinancial_annual_pre2008', 'nonfinancial', '金融業、保険業以外の業種', none),
    ('raw_corporate_finance_nonfinancial_annual', 'nonfinancial', '金融業、保険業以外の業種', none),
    ('raw_corporate_finance_all_industries_annual', 'all_industries', '全産業（金融業、保険業を含む）', none),
    ('raw_corporate_finance_finance_insurance_annual', 'finance_insurance', '金融業、保険業', none),
    ('raw_corporate_finance_banking_annual', 'banking', '銀行業', none),
    ('raw_corporate_finance_nondeposit_credit_annual', 'nondeposit_credit', '貸金業、クレジットカード業等非預金信用機関', none),
    ('raw_corporate_finance_securities_annual', 'securities', '金融商品取引業（第一種金融商品取引業であって有価証券関連業に限る）', none),
    ('raw_corporate_finance_other_securities_annual', 'other_securities', 'その他の金融商品取引業、商品先物取引業', none),
    ('raw_corporate_finance_insurance_annual', 'insurance', '保険業（その他の保険業を除く）', none),
    ('raw_corporate_finance_other_insurance_annual', 'other_insurance', 'その他の保険業', none),
] %}
SELECT *
FROM (
    {{ e_stat_corporate_finance_stg(tables, quarterly=false) }}
)
ORDER BY scope, item_code, industry_code, size_code, time
