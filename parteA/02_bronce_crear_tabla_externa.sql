-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 2 · Bronce: tabla externa sobre el CSV (todo como texto)

-- =====================================================================
-- PASO 2. BRONCE: tabla externa sobre el CSV original, TODO como texto
-- El CSV trae campos entre comillas (p. ej. nomprov = "CORUÑA, A"),
-- por eso se usa OpenCSVSerDe, que además lee todo como STRING.
-- =====================================================================
CREATE EXTERNAL TABLE IF NOT EXISTS santander.bronze (
  fecha_dato            STRING,
  ncodpers              STRING,
  ind_empleado          STRING,
  pais_residencia       STRING,
  sexo                  STRING,
  age                   STRING,
  fecha_alta            STRING,
  ind_nuevo             STRING,
  antiguedad            STRING,
  indrel                STRING,
  ult_fec_cli_1t        STRING,
  indrel_1mes           STRING,
  tiprel_1mes           STRING,
  indresi               STRING,
  indext                STRING,
  conyuemp              STRING,
  canal_entrada         STRING,
  indfall               STRING,
  tipodom               STRING,
  cod_prov              STRING,
  nomprov               STRING,
  ind_actividad_cliente STRING,
  renta                 STRING,
  segmento              STRING,
  ind_ahor_fin_ult1     STRING,
  ind_aval_fin_ult1     STRING,
  ind_cco_fin_ult1      STRING,
  ind_cder_fin_ult1     STRING,
  ind_cno_fin_ult1      STRING,
  ind_ctju_fin_ult1     STRING,
  ind_ctma_fin_ult1     STRING,
  ind_ctop_fin_ult1     STRING,
  ind_ctpp_fin_ult1     STRING,
  ind_deco_fin_ult1     STRING,
  ind_deme_fin_ult1     STRING,
  ind_dela_fin_ult1     STRING,
  ind_ecue_fin_ult1     STRING,
  ind_fond_fin_ult1     STRING,
  ind_hip_fin_ult1      STRING,
  ind_plan_fin_ult1     STRING,
  ind_pres_fin_ult1     STRING,
  ind_reca_fin_ult1     STRING,
  ind_tjcr_fin_ult1     STRING,
  ind_valo_fin_ult1     STRING,
  ind_viv_fin_ult1      STRING,
  ind_nomina_ult1       STRING,
  ind_nom_pens_ult1     STRING,
  ind_recibo_ult1       STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
  'separatorChar' = ',',
  'quoteChar'     = '"',
  'escapeChar'    = '\\'
)
LOCATION 's3://bigdata-trabajo1/bronze/santander/'
TBLPROPERTIES ('skip.header.line.count' = '1');
