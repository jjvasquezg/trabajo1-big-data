-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 5 · Oro: tabla Iceberg de contrataciones mensuales

-- =====================================================================
-- PASO 5. ORO
-- Pregunta de negocio: ¿Cuántos clientes contratan por primera vez cada
-- producto, cada mes y en cada segmento, y con qué tasa de conversión?
-- (Es la base del modelo de popularidad contra el que se compara el
--  MAP@7 del proyecto y de la priorización de campañas del tablero.)
-- "Nueva contratación" = el cliente tiene el producto en el mes t y NO
-- lo tenía en el mes t-1 (delta de tenencia).
-- =====================================================================
CREATE TABLE santander.gold_contrataciones_mensuales
WITH (
  table_type  = 'ICEBERG',
  format      = 'PARQUET',
  is_external = false,
  location    = 's3://bigdata-trabajo1/gold/contrataciones_mensuales/'
) AS
WITH base AS (
  SELECT fecha_dato, ncodpers, coalesce(segmento, 'SIN SEGMENTO') AS segmento,
         ARRAY[ind_ahor_fin_ult1, ind_aval_fin_ult1, ind_cco_fin_ult1, ind_cder_fin_ult1,
               ind_cno_fin_ult1, ind_ctju_fin_ult1, ind_ctma_fin_ult1, ind_ctop_fin_ult1,
               ind_ctpp_fin_ult1, ind_deco_fin_ult1, ind_deme_fin_ult1, ind_dela_fin_ult1,
               ind_ecue_fin_ult1, ind_fond_fin_ult1, ind_hip_fin_ult1, ind_plan_fin_ult1,
               ind_pres_fin_ult1, ind_reca_fin_ult1, ind_tjcr_fin_ult1, ind_valo_fin_ult1,
               ind_viv_fin_ult1, ind_nomina_ult1, ind_nom_pens_ult1, ind_recibo_ult1] AS prod
  FROM santander.silver
),
con_lag AS (
  SELECT fecha_dato, segmento, prod,
         lag(fecha_dato) OVER (PARTITION BY ncodpers ORDER BY fecha_dato) AS fecha_prev,
         lag(prod)       OVER (PARTITION BY ncodpers ORDER BY fecha_dato) AS prod_prev
  FROM base
)
SELECT c.fecha_dato,
       c.segmento,
       t.producto,
       count_if(t.previo = 0)                    AS clientes_sin_producto_mes_anterior,
       count_if(t.previo = 0 AND t.actual = 1)   AS nuevas_contrataciones,
       round(100.0 * count_if(t.previo = 0 AND t.actual = 1)
             / nullif(count_if(t.previo = 0), 0), 4) AS tasa_conversion_pct
FROM con_lag c
CROSS JOIN UNNEST(
  ARRAY['ahorro','avales','cuenta_corriente','derivados','cuenta_nomina','cuenta_juvenil',
        'cuenta_mas_particular','cuenta_particular','cuenta_particular_plus',
        'deposito_corto_plazo','deposito_mediano_plazo','deposito_largo_plazo',
        'e_cuenta','fondos_inversion','hipoteca','planes_pensiones','prestamos',
        'impuestos','tarjeta_credito','valores','vivienda','nomina','pension',
        'debito_automatico'],
  c.prod, c.prod_prev
) AS t(producto, actual, previo)
WHERE c.fecha_prev = date_add('month', -1, c.fecha_dato)
GROUP BY c.fecha_dato, c.segmento, t.producto;
