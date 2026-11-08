---
title: 法人企業景気予測調査 BSI と売上高・経常利益・設備投資の見通し
order: 51
---

# 法人企業景気予測調査 BSI と売上高・経常利益・設備投資の見通し

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| bsi | 景況判断（貴社・国内）・従業員数判断・設備判断の BSI。調査期 × 業種 × 規模 × 当期・翌期・翌々期 | survey_time / indicator / horizon / size / industry_code / value |
| sales_profit_investment_outlook | 売上高・経常利益・設備投資の見通し（金額・前年同期比）。調査期 × 年度 × 業種 | survey_time / outlook_table / fiscal_year / half / industry_code / item / measure / value |

内閣府・財務省の法人企業景気予測調査です。資本金1千万円以上の法人に、四半期ごとに景況の判断と
売上高・経常利益・設備投資の見通しを聞いています。2004年4〜6月期の調査から収録しています。

## BSI

BSI は「上昇」と答えた企業の割合から「下降」の割合を引いた値（%ポイント）です。従業員数判断は
「不足気味」-「過剰気味」、設備判断は「不足」-「過大」です。規模は大企業・中堅企業・中小企業の3つで、
全規模の行はありません。

```sql
-- 最新の調査期の景況判断（貴社）、全産業
SELECT survey_name, horizon, size, value
FROM e_stat.business_outlook.bsi
WHERE indicator = '景況判断（貴社）' AND industry_code = '10'
QUALIFY survey_time = max(survey_time) OVER ()
ORDER BY horizon_code, size_code;
```

## 見通しの年度

原典の時期は調査期から見た前年度・当年度・翌年度なので、実際の年度（`fiscal_year`）に読み替えています。
1〜3月期の調査では当年度はその3月に終わる年度、4〜12月期の調査ではその年の4月に始まる年度です。
翌年度の見通しは1〜3月期の調査にだけあり、別の表（`outlook_table` = 翌年度見通し）です。
1〜3月期の調査では同じ年度が当年度見通しと翌年度見通しの両方にありますが、値は一致しません。

同じ年度の見通しは調査期ごとに更新されます。最新の見通しは最新の調査期の行です。
