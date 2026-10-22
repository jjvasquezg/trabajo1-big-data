-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 4.3 · Plata: tabla Iceberg con las filas rechazadas

-- 4.3 Tabla Iceberg de PLATA con las filas RECHAZADAS y su motivo
--     (se guardan los valores originales como texto, para auditoría)
CREATE TABLE santander.silver_rechazadas
WITH (
  table_type  = 'ICEBERG',
  format      = 'PARQUET',
  is_external = false,
  location    = 's3://bigdata-trabajo1/silver/santander_rechazadas/'
) AS
SELECT
  motivo_rechazo,
  fecha_dato, ncodpers, ind_empleado, pais_residencia, sexo, age, fecha_alta,
  ind_nuevo, antiguedad, indrel, ult_fec_cli_1t, indrel_1mes, tiprel_1mes,
  indresi, indext, conyuemp, canal_entrada, indfall, tipodom, cod_prov, nomprov,
  ind_actividad_cliente, renta, segmento,
  ind_ahor_fin_ult1, ind_aval_fin_ult1, ind_cco_fin_ult1, ind_cder_fin_ult1,
  ind_cno_fin_ult1, ind_ctju_fin_ult1, ind_ctma_fin_ult1, ind_ctop_fin_ult1,
  ind_ctpp_fin_ult1, ind_deco_fin_ult1, ind_deme_fin_ult1, ind_dela_fin_ult1,
  ind_ecue_fin_ult1, ind_fond_fin_ult1, ind_hip_fin_ult1, ind_plan_fin_ult1,
  ind_pres_fin_ult1, ind_reca_fin_ult1, ind_tjcr_fin_ult1, ind_valo_fin_ult1,
  ind_viv_fin_ult1, ind_nomina_ult1, ind_nom_pens_ult1, ind_recibo_ult1
FROM santander.v_bronze_evaluado
WHERE motivo_rechazo IS NOT NULL;
