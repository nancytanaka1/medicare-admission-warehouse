{{ config(materialized='view') }}

with src as (
    select * from {{ source('raw_synpuf', 'INPATIENT_CLAIMS') }}
)

select
    DESYNPUF_ID                                               as beneficiary_id,
    CLM_ID                                                    as claim_id,
    SEGMENT                                                   as segment,
    try_to_date(cast(CLM_FROM_DT   as varchar), 'YYYYMMDD')   as claim_from_date,
    try_to_date(cast(CLM_THRU_DT   as varchar), 'YYYYMMDD')   as claim_thru_date,
    try_to_date(cast(CLM_ADMSN_DT  as varchar), 'YYYYMMDD')   as admission_date,
    try_to_date(cast(NCH_BENE_DSCHRG_DT as varchar), 'YYYYMMDD') as discharge_date,
    PRVDR_NUM                                                 as provider_id,
    AT_PHYSN_NPI                                              as attending_physician_npi,
    OP_PHYSN_NPI                                              as operating_physician_npi,
    CLM_PMT_AMT                                               as claim_payment_amount,
    NCH_PRMRY_PYR_CLM_PD_AMT                                  as primary_payer_paid,
    CLM_PASS_THRU_PER_DIEM_AMT                                as pass_thru_per_diem,
    NCH_BENE_IP_DDCTBL_AMT                                    as beneficiary_deductible,
    NCH_BENE_PTA_COINSRNC_LBLTY_AM                            as beneficiary_coinsurance,
    NCH_BENE_BLOOD_DDCTBL_LBLTY_AM                            as beneficiary_blood_deductible,
    CLM_UTLZTN_DAY_CNT                                        as length_of_stay_days,
    ADMTNG_ICD9_DGNS_CD                                       as admitting_diagnosis_cd,
    CLM_DRG_CD                                                as drg_cd,
    ICD9_DGNS_CD_1   as dx_1,  ICD9_DGNS_CD_2   as dx_2,
    ICD9_DGNS_CD_3   as dx_3,  ICD9_DGNS_CD_4   as dx_4,
    ICD9_DGNS_CD_5   as dx_5,  ICD9_DGNS_CD_6   as dx_6,
    ICD9_DGNS_CD_7   as dx_7,  ICD9_DGNS_CD_8   as dx_8,
    ICD9_DGNS_CD_9   as dx_9,  ICD9_DGNS_CD_10  as dx_10,
    ICD9_PRCDR_CD_1  as proc_1, ICD9_PRCDR_CD_2 as proc_2,
    ICD9_PRCDR_CD_3  as proc_3, ICD9_PRCDR_CD_4 as proc_4,
    ICD9_PRCDR_CD_5  as proc_5, ICD9_PRCDR_CD_6 as proc_6
from src
where DESYNPUF_ID is not null
  and CLM_ID is not null
