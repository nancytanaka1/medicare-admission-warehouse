{{ config(materialized='table') }}

with admissions as (
    select
        beneficiary_id,
        claim_id            as index_claim_id,
        admission_date      as index_admission_date,
        discharge_date      as index_discharge_date,
        length_of_stay_days as index_length_of_stay,
        drg_cd              as index_drg_cd,
        primary_dx          as index_primary_dx,
        lead(admission_date) over (partition by beneficiary_id order by admission_date) as next_admission_date,
        lead(claim_id)       over (partition by beneficiary_id order by admission_date) as next_claim_id
    from {{ ref('fct_admission') }}
)

select
    beneficiary_id,
    index_claim_id,
    index_admission_date,
    index_discharge_date,
    index_length_of_stay,
    index_drg_cd,
    index_primary_dx,
    next_admission_date                                                 as readmit_admission_date,
    next_claim_id                                                       as readmit_claim_id,
    case
        when next_admission_date is not null
         and next_admission_date > index_discharge_date
        then datediff('day', index_discharge_date, next_admission_date)
    end                                                                 as days_to_readmit,
    case
        when next_admission_date is not null
         and next_admission_date > index_discharge_date
         and datediff('day', index_discharge_date, next_admission_date) between 1 and 30
        then true
        else false
    end                                                                 as is_30d_readmit,
    case
        when next_admission_date is not null
         and next_admission_date <= index_discharge_date
        then true
        else false
    end                                                                 as is_transfer_or_overlap
from admissions
