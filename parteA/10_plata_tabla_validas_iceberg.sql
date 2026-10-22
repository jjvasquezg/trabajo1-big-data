-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 4.2 · Plata: tabla Iceberg con las filas válidas

-- 4.2 Tabla Iceberg de PLATA con las filas VÁLIDAS (tipada y limpia,
--     Parquet, particionada por mes)
CREATE TABLE santander.silver
WITH (
  table_type   = 'ICEBERG',
  format       = 'PARQUET',
  is_external  = false,
  location     = 's3://bigdata-trabajo1/silver/santander_validas/',
  partitioning = ARRAY['fecha_dato']
) AS
SELECT
  k_fecha                                                       AS fecha_dato,
  k_ncodpers                                                    AS ncodpers,
  NULLIF(NULLIF(trim(ind_empleado), ''), 'NA')                  AS ind_empleado,
  NULLIF(NULLIF(trim(pais_residencia), ''), 'NA')               AS pais_residencia,
  NULLIF(NULLIF(trim(sexo), ''), 'NA')                          AS sexo,
  k_edad                                                        AS edad,
  try_cast(trim(fecha_alta) AS date)                            AS fecha_alta,
  CAST(try_cast(trim(ind_nuevo) AS double) AS integer)          AS ind_nuevo,
  k_antiguedad                                                  AS antiguedad_meses,
  CAST(try_cast(trim(indrel) AS double) AS integer)             AS indrel,
  try_cast(trim(ult_fec_cli_1t) AS date)                        AS ult_fec_cli_1t,
  NULLIF(NULLIF(regexp_replace(trim(indrel_1mes), '\.0$', ''), ''), 'NA') AS indrel_1mes,
  NULLIF(NULLIF(trim(tiprel_1mes), ''), 'NA')                   AS tiprel_1mes,
  NULLIF(NULLIF(trim(indresi), ''), 'NA')                       AS indresi,
  NULLIF(NULLIF(trim(indext), ''), 'NA')                        AS indext,
  NULLIF(NULLIF(trim(conyuemp), ''), 'NA')                      AS conyuemp,
  NULLIF(NULLIF(trim(canal_entrada), ''), 'NA')                 AS canal_entrada,
  NULLIF(NULLIF(trim(indfall), ''), 'NA')                       AS indfall,
  CAST(try_cast(trim(tipodom) AS double) AS integer)            AS tipodom,
  CAST(try_cast(trim(cod_prov) AS double) AS integer)           AS cod_prov,
  NULLIF(NULLIF(trim(nomprov), ''), 'NA')                       AS nomprov,
  CAST(try_cast(trim(ind_actividad_cliente) AS double) AS integer) AS ind_actividad_cliente,
  try_cast(trim(renta) AS double)                               AS renta,
  NULLIF(NULLIF(trim(segmento), ''), 'NA')                      AS segmento,
  CAST(try_cast(trim(ind_ahor_fin_ult1) AS double) AS integer) AS ind_ahor_fin_ult1,
  CAST(try_cast(trim(ind_aval_fin_ult1) AS double) AS integer) AS ind_aval_fin_ult1,
  CAST(try_cast(trim(ind_cco_fin_ult1)  AS double) AS integer) AS ind_cco_fin_ult1,
  CAST(try_cast(trim(ind_cder_fin_ult1) AS double) AS integer) AS ind_cder_fin_ult1,
  CAST(try_cast(trim(ind_cno_fin_ult1)  AS double) AS integer) AS ind_cno_fin_ult1,
  CAST(try_cast(trim(ind_ctju_fin_ult1) AS double) AS integer) AS ind_ctju_fin_ult1,
  CAST(try_cast(trim(ind_ctma_fin_ult1) AS double) AS integer) AS ind_ctma_fin_ult1,
  CAST(try_cast(trim(ind_ctop_fin_ult1) AS double) AS integer) AS ind_ctop_fin_ult1,
  CAST(try_cast(trim(ind_ctpp_fin_ult1) AS double) AS integer) AS ind_ctpp_fin_ult1,
  CAST(try_cast(trim(ind_deco_fin_ult1) AS double) AS integer) AS ind_deco_fin_ult1,
  CAST(try_cast(trim(ind_deme_fin_ult1) AS double) AS integer) AS ind_deme_fin_ult1,
  CAST(try_cast(trim(ind_dela_fin_ult1) AS double) AS integer) AS ind_dela_fin_ult1,
  CAST(try_cast(trim(ind_ecue_fin_ult1) AS double) AS integer) AS ind_ecue_fin_ult1,
  CAST(try_cast(trim(ind_fond_fin_ult1) AS double) AS integer) AS ind_fond_fin_ult1,
  CAST(try_cast(trim(ind_hip_fin_ult1)  AS double) AS integer) AS ind_hip_fin_ult1,
  CAST(try_cast(trim(ind_plan_fin_ult1) AS double) AS integer) AS ind_plan_fin_ult1,
  CAST(try_cast(trim(ind_pres_fin_ult1) AS double) AS integer) AS ind_pres_fin_ult1,
  CAST(try_cast(trim(ind_reca_fin_ult1) AS double) AS integer) AS ind_reca_fin_ult1,
  CAST(try_cast(trim(ind_tjcr_fin_ult1) AS double) AS integer) AS ind_tjcr_fin_ult1,
  CAST(try_cast(trim(ind_valo_fin_ult1) AS double) AS integer) AS ind_valo_fin_ult1,
  CAST(try_cast(trim(ind_viv_fin_ult1)  AS double) AS integer) AS ind_viv_fin_ult1,
  CAST(try_cast(trim(ind_nomina_ult1)   AS double) AS integer) AS ind_nomina_ult1,
  CAST(try_cast(trim(ind_nom_pens_ult1) AS double) AS integer) AS ind_nom_pens_ult1,
  CAST(try_cast(trim(ind_recibo_ult1)   AS double) AS integer) AS ind_recibo_ult1
FROM santander.v_bronze_evaluado
WHERE motivo_rechazo IS NULL;
