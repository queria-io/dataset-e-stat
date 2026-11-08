{# 企業活動基本調査の2020年より前の表で、コードの付かない産業名（大分類・合計・総合計）を
   2020年以降の表のコードに当てる。名前は全角括弧を半角にそろえてから比べる。
   当たらない名前は NULL（コードの付いた中分類・小分類の名前も NULL になる）。 #}
{% macro e_stat_enterprise_activity_major_code(name) %}
CASE {{ name }}
    WHEN '総合計' THEN '総合計'
    WHEN '合計' THEN '000'
    WHEN '鉱業、採石業、砂利採取業' THEN 'C'
    WHEN '製造業' THEN 'E'
    WHEN '電気・ガス業' THEN 'F'
    WHEN '情報通信業' THEN 'G'
    WHEN '卸売業' THEN 'I1'
    WHEN '小売業' THEN 'I2'
    WHEN 'クレジットカード業、割賦金融業' THEN 'J1'
    -- 2010年調査の都道府県別の表だけ中黒で区切っている
    WHEN 'クレジットカード業・割賦金融業' THEN 'J1'
    WHEN '物品賃貸業' THEN 'K1'
    WHEN '学術研究、専門・技術サービス業' THEN 'L'
    WHEN '飲食サービス業' THEN 'M'
    WHEN '生活関連サービス業、娯楽業' THEN 'N'
    WHEN '個人教授所' THEN 'O'
    WHEN 'サービス業(その他のサービス業を除く)' THEN 'R1'
    WHEN 'サービス業(その他のサービス業)' THEN 'R2'
    WHEN 'その他の産業' THEN 'Z'
END
{% endmacro %}
