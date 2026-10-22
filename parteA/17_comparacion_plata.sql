-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 6.2 · Comparación: consulta sobre plata

-- IMPORTANTE: desactiva "Reuse query results" en el editor de Athena y
-- ejecuta la consulta 3 veces; anota "Data scanned" y "Run time".

-- 6.2 PLATA (Iceberg/Parquet, tipada, particionada por mes)
WITH base AS (
  SELECT ncodpers, fecha_dato,
         ARRAY[ind_ahor_fin_ult1, ind_aval_fin_ult1, ind_cco_fin_ult1, ind_cder_fin_ult1,
               ind_cno_fin_ult1, ind_ctju_fin_ult1, ind_ctma_fin_ult1, ind_ctop_fin_ult1,
               ind_ctpp_fin_ult1, ind_deco_fin_ult1, ind_deme_fin_ult1, ind_dela_fin_ult1,
               ind_ecue_fin_ult1, ind_fond_fin_ult1, ind_hip_fin_ult1, ind_plan_fin_ult1,
               ind_pres_fin_ult1, ind_reca_fin_ult1, ind_tjcr_fin_ult1, ind_valo_fin_ult1,
               ind_viv_fin_ult1, ind_nomina_ult1, ind_nom_pens_ult1, ind_recibo_ult1] AS prod
  FROM santander.silver
  WHERE fecha_dato IN (DATE '2016-04-28', DATE '2016-05-28')
),
con_lag AS (
  SELECT fecha_dato, prod,
         lag(fecha_dato) OVER (PARTITION BY ncodpers ORDER BY fecha_dato) AS fecha_prev,
         lag(prod)       OVER (PARTITION BY ncodpers ORDER BY fecha_dato) AS prod_prev
  FROM base
)
SELECT t.producto, count_if(t.actual = 1 AND t.previo = 0) AS nuevas_contrataciones
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
WHERE c.fecha_dato = DATE '2016-05-28' AND c.fecha_prev = DATE '2016-04-28'
GROUP BY t.producto
ORDER BY nuevas_contrataciones DESC;
