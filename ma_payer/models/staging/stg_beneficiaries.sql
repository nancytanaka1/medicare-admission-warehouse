{{ config(materialized='view') }}

with u as (
    select 2008 as calendar_year, * from {{ source('raw_synpuf', 'BENEFICIARY_2008') }}
    union all
    select 2009 as calendar_year, * from {{ source('raw_synpuf', 'BENEFICIARY_2009') }}
    union all
    select 2010 as calendar_year, * from {{ source('raw_synpuf', 'BENEFICIARY_2010') }}
)

select
    DESYNPUF_ID                                             as beneficiary_id,
    calendar_year,
    try_to_date(cast(BENE_BIRTH_DT as varchar), 'YYYYMMDD') as birth_date,
    try_to_date(cast(BENE_DEATH_DT as varchar), 'YYYYMMDD') as death_date,
    case BENE_SEX_IDENT_CD when '1' then 'M' when '2' then 'F' end as sex,
    BENE_RACE_CD                                            as race_cd,
    BENE_ESRD_IND                                           as esrd_ind,
    SP_STATE_CODE                                           as state_cd,
    BENE_COUNTY_CD                                          as county_cd,
    BENE_HI_CVRAGE_TOT_MONS                                 as part_a_months,
    BENE_SMI_CVRAGE_TOT_MONS                                as part_b_months,
    BENE_HMO_CVRAGE_TOT_MONS                                as hmo_months,
    PLAN_CVRG_MOS_NUM                                       as part_d_months,
    case SP_ALZHDMTA  when 1 then true else false end as has_alzheimers,
    case SP_CHF       when 1 then true else false end as has_chf,
    case SP_CHRNKIDN  when 1 then true else false end as has_ckd,
    case SP_CNCR      when 1 then true else false end as has_cancer,
    case SP_COPD      when 1 then true else false end as has_copd,
    case SP_DEPRESSN  when 1 then true else false end as has_depression,
    case SP_DIABETES  when 1 then true else false end as has_diabetes,
    case SP_ISCHMCHT  when 1 then true else false end as has_ischemic_heart,
    case SP_OSTEOPRS  when 1 then true else false end as has_osteoporosis,
    case SP_RA_OA     when 1 then true else false end as has_ra_oa,
    case SP_STRKETIA  when 1 then true else false end as has_stroke_tia
from u
