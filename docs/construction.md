---
title: 建設工事出来高と公共工事の請負契約額
order: 40
---

# 建設工事出来高と公共工事の請負契約額

## 建設総合統計 都道府県別の建設工事出来高

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| prefecture_monthly | その月に施工された建設工事の金額（出来高、億円）。都道府県別・月次。2011年4月〜 | prefecture_code / area / area_name / region_code / region_name / time / time_name / year / month / output |

国土交通省の建設総合統計のうち、月別《地域別》出来高の表です。建築着工統計と建設工事受注動態統計の
工事費を工事の進み具合に合わせて月ごとに割り振った加工統計で、着工した月に全額が載る建築着工統計と
違い、工期の長い工事も毎月の施工分に均されます。185か月 × 47都道府県の8,695行です。

```sql
-- 2025年度（2025年4月〜2026年3月）の出来高が大きかった都道府県
SELECT area_name, sum(output) AS output
FROM e_stat.construction.prefecture_monthly
WHERE (year = 2025 AND month >= 4) OR (year = 2026 AND month <= 3)
GROUP BY area_name
ORDER BY output DESC
LIMIT 5;
```

東京都の76,096億円が最も大きく、神奈川県（37,959億円）・北海道・愛知県・大阪府と続きます。

```sql
-- 2011年度から2025年度にかけての出来高の伸び
SELECT area_name,
    sum(output) FILTER (WHERE (year = 2011 AND month >= 4) OR (year = 2012 AND month <= 3)) AS fy2011,
    sum(output) FILTER (WHERE (year = 2025 AND month >= 4) OR (year = 2026 AND month <= 3)) AS fy2025
FROM e_stat.construction.prefecture_monthly
GROUP BY area_name
ORDER BY fy2025 / fy2011 DESC
LIMIT 3;
```

石川県が3,932億円から9,275億円へ2.4倍で最も大きく、滋賀県・鹿児島県が続きます。

### 建築・土木、民間・公共の内訳は無い

この表の値はすべてを合わせた計です。都道府県別の内訳はこの表にはありません。

### 年度で数えるときは4月始まり

year は暦年です。年度で集計するときは4月〜翌年3月を同じ年度に数えます。都道府県を足した年度計は
全国の年度別出来高と2011〜2025年度のすべてで16億円以内で一致します（億円の丸めによる差）。
全国の月別出来高の表とは2021年度以降に差があり、2025年度は全国の月別のほうが4.6%大きくなっています。

### 値は遡って改定される

毎年6月に、過去3年分の月の値が補正率で遡及改定されます。同じ月でも取得した時期によって値が変わります。

### 地方区分はこの統計独自のもの

region_code / region_name はこの統計の9地方です。山梨県・長野県は関東地方、新潟県は北陸地方に入り、
中部地方は岐阜・静岡・愛知・三重の4県です。

出典: 国土交通省 建設総合統計。
https://www.e-stat.go.jp/statistics/00600260

## 建設工事受注動態統計調査 公共工事の請負契約額

| テーブル | 内容 | 主なカラム |
|---------|------|-----------|
| public_orders_prefecture_monthly | 公共機関から受注した工事（1件500万円以上）の請負契約額（百万円）。施工都道府県別・発注機関別・月次。2021年4月〜 | prefecture_code / area / area_name / year / month / fiscal_year / total / national_total / national_government / independent_agency / government_affiliated / local_total / prefectural_government / municipal_government / local_public_enterprise / other |

国土交通省の建設工事受注動態統計調査のうち、公共機関からの受注工事を施工した都道府県と発注機関で分けた表です。
全国計（area = '00000'、prefecture_code は NULL）と47都道府県の行が月ごとにあり、65か月 × 48行の3,120行です。
受注した月に契約額の全額が載るので、工事の進み具合に合わせて均した金額は prefecture_monthly（建設総合統計）を使います。

```sql
-- 2025年度に国の機関の発注が占める割合が大きかった都道府県
SELECT area_name,
    round(sum(municipal_government) / sum(total) * 100, 1) AS municipal_pct,
    round(sum(national_total) / sum(total) * 100, 1) AS national_pct
FROM e_stat.construction.public_orders_prefecture_monthly
WHERE fiscal_year = 2025 AND prefecture_code IS NOT NULL
GROUP BY area_name
ORDER BY national_pct DESC
LIMIT 3;
```

沖縄県の62.6%が最も大きく、鹿児島県（54.9%）・滋賀県（49.8%）と続きます。

```sql
-- 全国の年度別の請負契約額（兆円）
SELECT fiscal_year, round(sum(total) / 1e6, 2) AS total_cho_yen
FROM e_stat.construction.public_orders_prefecture_monthly
WHERE area = '00000' AND fiscal_year BETWEEN 2021 AND 2025
GROUP BY fiscal_year
ORDER BY fiscal_year;
```

2021年度の20.10兆円から2025年度の23.57兆円まで増えています。

### 2021年4月より前の月は無い

推計方法が2021年4月分から変わり、施工統計調査の未回答業者の欠測を補って復元するようになりました。
それより前の月とは水準がつながらないので収録していません。

### 年度末の3月に契約が集まる

2021〜2025年度の3月の全国計は、平均でほかの月の2.4倍です。月どうしを比べるときは前年同月と並べます。

### 合計と小計を足し合わせない

total は national_total と local_total の和、national_total は国・独立行政法人・政府関連企業等の和、
local_total は都道府県・市区町村・地方公営企業・その他の和です。都道府県を足すと全国計の行に一致するので、
全国の値を出すときに全国計の行と都道府県の行を一緒に足さないでください。

### 値が負の月がある

変更契約で減額された分が多い月は、発注機関の列が負になります（78行、最小は -25,913百万円）。
受注高の少ない区分は標本の誤差が大きくなります。

出典: 国土交通省 建設工事受注動態統計調査。
https://www.e-stat.go.jp/statistics/00600130

## 補足: construction.prefecture_monthly

建築・土木、民間・公共をすべて合わせた計で、内訳はこの表には無い。
全国の月別出来高（sid=0003458439）とは2020年度まで一致するが、2021年度以降はずれ、2025年度は全国の月別のほうが4.6%大きい。
値は毎年6月に過去3年分が補正率で遡及改定される。
同じ月でも取得した時期で値が変わる。

## 補足: construction.public_orders_prefecture_monthly

発注機関は国の機関（国・独立行政法人・政府関連企業等）と地方の機関（都道府県・市区町村・地方公営企業・その他）の7区分で、合計と国の機関・地方の機関の小計も列に持つ。
都道府県を足した値は全国計と一致し、月を足した年度計は年度次の同じ表と2025年度で全国・都道府県・発注機関のすべて一致する。
2025年度の全国の請負契約額は23兆5,706億円で、東京都（3兆1,006億円）・北海道・愛知県・神奈川県・大阪府の順に大きい。
