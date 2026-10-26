import duckdb
con = duckdb.connect("e_stat.duckdb", read_only=True)
print(con.sql("select table_schema, table_name from information_schema.tables where table_name like '%kaigo%' or table_name in ('municipality','union_member') order by 1,2"))
def q(t, s):
    print("##", t)
    try:
        con.sql(s).show(max_rows=300, max_width=400)
    except Exception as e:
        print("ERR", e)
q("rows", "select (select count(*) from main.insured_persons) ins, (select count(*) from main.certified_persons) cert, (select count(*) from main.union_member) mem")
q("match by year", "select fiscal_year, count(*) filter (where insurer_kind='municipality') muni, count(*) filter (where insurer_kind='municipality' and area_code is null) unmatched, count(*) filter (where insurer_kind='union') unions from main.insured_persons where category='計' group by 1 order by 1")
q("2014 diff", "select 'ins' t, prefecture_name, insurer_name from main.insured_persons where fiscal_year=2014 except select 'ins', prefecture_name, insurer_name from main.certified_persons where fiscal_year=2014 union all select 'cert', prefecture_name, insurer_name from main.certified_persons where fiscal_year=2014 except select 'cert', prefecture_name, insurer_name from main.insured_persons where fiscal_year=2014")
q("latest unmatched", "select prefecture_name, insurer_name from main.insured_persons where fiscal_year=2024 and category='計' and insurer_kind='municipality' and area_code is null")
q("union coverage latest", "select i.insurer_name, i.value as first_insured, count(m.area_code) members from main.insured_persons i left join main.union_member m using (insurer_name) where i.fiscal_year=2024 and i.category='計' and i.insurer_kind='union' group by all order by 1")
q("nerima", "select fiscal_year, area_code, care_level, value from main.certified_persons where insurer_name='練馬区' and insured_category='第1号被保険者' and age_group is null and care_level='合計' order by 1")
q("rate 2024 top", "with i as (select area_code, insurer_name, prefecture_name, value from main.insured_persons where fiscal_year=2024 and category='計'), c as (select insurer_name, prefecture_name, value from main.certified_persons where fiscal_year=2024 and insured_category='第1号被保険者' and age_group is null and care_level='合計') select i.prefecture_name, i.insurer_name, i.value, c.value, round(100.0*c.value/i.value,1) rate from i join c using (prefecture_name, insurer_name) where i.insurer_name in ('練馬区','世田谷区','杉並区','板橋区') order by rate desc")
q("years", "select min(fiscal_year), max(fiscal_year), count(distinct fiscal_year) from main.certified_persons")
q("2001 nationwide rows", "select count(*) from main.insured_persons where fiscal_year=2001 and insurer_kind='nationwide'")
q("pct with value latest", "select count(*) filter (where value is null), count(*) filter (where value = 0), count(*) from main.certified_persons where fiscal_year=2024")
import pathlib
sql = pathlib.Path("target/compiled/e_stat/tests/kaigo_insurance_is_consistent.sql").read_text()
q("consistency failures", f"select failure, fiscal_year, count(*), min(detail), max(detail) from ({sql}) group by all order by 1,2")
