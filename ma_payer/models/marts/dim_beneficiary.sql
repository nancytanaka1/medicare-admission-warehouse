{{ config(materialized='table') }}

with ranked as (
    select *,
           row_number() over (partition by beneficiary_id order by calendar_year desc) as rn
    from {{ ref('stg_beneficiaries') }}
)

select
    beneficiary_id,
    birth_date,
    death_date,
    datediff('year', birth_date, date '2010-12-31') as age_at_2010,
    sex,
    race_cd,
    esrd_ind,
    state_cd,
    county_cd,
    part_a_months,
    part_b_months,
    hmo_months,
    part_d_months,
    has_alzheimers,
    has_chf,
    has_ckd,
    has_cancer,
    has_copd,
    has_depression,
    has_diabetes,
    has_ischemic_heart,
    has_osteoporosis,
    has_ra_oa,
    has_stroke_tia,
    (iff(has_alzheimers, 1, 0)
   + iff(has_chf, 1, 0)
   + iff(has_ckd, 1, 0)
   + iff(has_cancer, 1, 0)
   + iff(has_copd, 1, 0)
   + iff(has_depression, 1, 0)
   + iff(has_diabetes, 1, 0)
   + iff(has_ischemic_heart, 1, 0)
   + iff(has_osteoporosis, 1, 0)
   + iff(has_ra_oa, 1, 0)
   + iff(has_stroke_tia, 1, 0)) as chronic_condition_count
from ranked
where rn = 1
