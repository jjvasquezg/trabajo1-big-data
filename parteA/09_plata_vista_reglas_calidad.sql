-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 4.1 · Plata: vista que evalúa las 6 reglas de calidad

-- =====================================================================
-- PASO 4. PLATA
-- 4.1 Vista que evalúa cada fila de bronce contra las reglas.
--     Cada fila recibe UN solo motivo (el de la primera regla que falla),
--     así cada fila de bronce cae exactamente en una de las dos tablas.
-- Reglas (justificadas en la tabla de hallazgos):
--   R1 Llave válida: ncodpers numérico y fecha_dato convertible a fecha
--   R2 Unicidad: una sola fila por (ncodpers, fecha_dato)
--   R3 Completitud sociodemográfica: no puede venir vacío todo el perfil
--   R4 Edad válida: numérica y entre 0 y 100
--   R5 Target válido: los 24 productos deben ser 0 o 1
--   R6 Antigüedad válida: numérica y no negativa
-- =====================================================================
CREATE OR REPLACE VIEW santander.v_bronze_evaluado AS
WITH base AS (
  SELECT b.*,
         try_cast(trim(b.ncodpers) AS bigint)   AS k_ncodpers,
         try_cast(trim(b.fecha_dato) AS date)   AS k_fecha,
         try_cast(trim(b.age) AS integer)       AS k_edad,
         try_cast(trim(b.antiguedad) AS integer) AS k_antiguedad,
         concat_ws('|',
           trim(b.ind_ahor_fin_ult1), trim(b.ind_aval_fin_ult1), trim(b.ind_cco_fin_ult1),
           trim(b.ind_cder_fin_ult1), trim(b.ind_cno_fin_ult1),  trim(b.ind_ctju_fin_ult1),
           trim(b.ind_ctma_fin_ult1), trim(b.ind_ctop_fin_ult1), trim(b.ind_ctpp_fin_ult1),
           trim(b.ind_deco_fin_ult1), trim(b.ind_deme_fin_ult1), trim(b.ind_dela_fin_ult1),
           trim(b.ind_ecue_fin_ult1), trim(b.ind_fond_fin_ult1), trim(b.ind_hip_fin_ult1),
           trim(b.ind_plan_fin_ult1), trim(b.ind_pres_fin_ult1), trim(b.ind_reca_fin_ult1),
           trim(b.ind_tjcr_fin_ult1), trim(b.ind_valo_fin_ult1), trim(b.ind_viv_fin_ult1),
           trim(b.ind_nomina_ult1),   trim(b.ind_nom_pens_ult1), trim(b.ind_recibo_ult1)
         ) AS k_productos
  FROM santander.bronze b
),
marcado AS (
  SELECT base.*,
         row_number() OVER (PARTITION BY k_ncodpers, k_fecha ORDER BY k_ncodpers) AS k_rn
  FROM base
)
SELECT marcado.*,
  CASE
    WHEN k_ncodpers IS NULL OR k_fecha IS NULL
      THEN 'R1: llave invalida (ncodpers o fecha_dato)'
    WHEN k_rn > 1
      THEN 'R2: duplicado de (ncodpers, fecha_dato)'
    WHEN trim(sexo) = '' AND trim(ind_empleado) = '' AND k_edad IS NULL
      THEN 'R3: perfil sociodemografico vacio'
    WHEN k_edad IS NULL OR k_edad NOT BETWEEN 0 AND 100
      THEN 'R4: edad nula o fuera de [0, 100]'
    WHEN NOT regexp_like(k_productos, '^([01](\.0+)?\|){23}[01](\.0+)?$')
      THEN 'R5: producto (target) no binario'
    WHEN k_antiguedad IS NULL OR k_antiguedad < 0
      THEN 'R6: antiguedad nula o negativa'
    ELSE NULL
  END AS motivo_rechazo
FROM marcado;
