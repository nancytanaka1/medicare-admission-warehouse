{{ config(materialized='table') }}

select
    beneficiary_id,
    claim_id,
    min(admission_date)              as admission_date,
    max(discharge_date)              as discharge_date,
    max(length_of_stay_days)         as length_of_stay_days,
    max(drg_cd)                      as drg_cd,
    max(admitting_diagnosis_cd)      as admitting_diagnosis_cd,
    max(provider_id)                 as provider_id,
    max(dx_1)                        as primary_dx,
    sum(claim_payment_amount)        as total_claim_payment,
    count(*)                         as segment_count
from {{ ref('stg_inpatient_claims') }}
where admission_date is not null
group by beneficiary_id, claim_id
