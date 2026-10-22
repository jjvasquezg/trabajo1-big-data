-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 3 · Hallazgos: defectos de calidad cuantificados

-- =====================================================================
-- PASO 3. HALLAZGOS: defectos de calidad cuantificados con SQL
-- Devuelve UNA tabla: hallazgo | filas_afectadas | % del total | acción
-- =====================================================================
WITH conteos AS (
  SELECT
    count(*) AS total,
    count(*) - count(DISTINCT concat(trim(ncodpers), '|', trim(fecha_dato))) AS dup_llave,
    count_if(try_cast(trim(fecha_dato) AS date) IS NULL)                       AS fecha_dato_invalida,
    count_if(try_cast(trim(ncodpers) AS bigint) IS NULL)                       AS ncodpers_invalido,
    count_if(trim(sexo) = '' AND trim(ind_empleado) = ''
             AND try_cast(trim(age) AS integer) IS NULL)                       AS sociodemografico_vacio,
    count_if(try_cast(trim(age) AS integer) IS NULL)                           AS edad_vacia,
    count_if(try_cast(trim(age) AS integer) > 100)                             AS edad_mayor_100,
    count_if(try_cast(trim(age) AS integer) < 18)                              AS edad_menor_18,
    count_if(try_cast(trim(antiguedad) AS integer) IS NULL)                    AS antiguedad_vacia,
    count_if(try_cast(trim(antiguedad) AS integer) < 0)                        AS antiguedad_negativa,
    count_if(try_cast(trim(renta) AS double) IS NULL)                          AS renta_vacia,
    count_if(trim(sexo) = '')                                                  AS sexo_vacio,
    count_if(try_cast(trim(fecha_alta) AS date) IS NULL)                       AS fecha_alta_invalida,
    count_if(trim(indrel_1mes) LIKE '%.0')                                     AS indrel_1mes_formato,
    count_if(trim(cod_prov) IN ('', 'NA'))                                     AS provincia_vacia,
    count_if(trim(canal_entrada) IN ('', 'NA'))                                AS canal_vacio,
    count_if(trim(conyuemp) IN ('', 'NA'))                                     AS conyuemp_vacio,
    count_if(trim(ult_fec_cli_1t) IN ('', 'NA'))                               AS ult_fec_vacia,
    count_if(NOT regexp_like(
      concat_ws('|',
        trim(ind_ahor_fin_ult1), trim(ind_aval_fin_ult1), trim(ind_cco_fin_ult1),
        trim(ind_cder_fin_ult1), trim(ind_cno_fin_ult1),  trim(ind_ctju_fin_ult1),
        trim(ind_ctma_fin_ult1), trim(ind_ctop_fin_ult1), trim(ind_ctpp_fin_ult1),
        trim(ind_deco_fin_ult1), trim(ind_deme_fin_ult1), trim(ind_dela_fin_ult1),
        trim(ind_ecue_fin_ult1), trim(ind_fond_fin_ult1), trim(ind_hip_fin_ult1),
        trim(ind_plan_fin_ult1), trim(ind_pres_fin_ult1), trim(ind_reca_fin_ult1),
        trim(ind_tjcr_fin_ult1), trim(ind_valo_fin_ult1), trim(ind_viv_fin_ult1),
        trim(ind_nomina_ult1),   trim(ind_nom_pens_ult1), trim(ind_recibo_ult1)),
      '^([01](\.0+)?\|){23}[01](\.0+)?$'))                                    AS productos_no_binarios
  FROM santander.bronze
),
exactos AS (
  SELECT count(*) AS filas_distintas
  FROM (SELECT DISTINCT * FROM santander.bronze)
)
SELECT h.hallazgo,
       h.filas_afectadas,
       round(100.0 * h.filas_afectadas / c.total, 3) AS pct_del_total,
       h.accion_en_plata
FROM conteos c
CROSS JOIN exactos e
CROSS JOIN UNNEST(
  ARRAY[
    'Filas totales en bronce',
    'Filas repetidas exactas (todas las columnas)',
    'Llave (ncodpers, fecha_dato) repetida',
    'fecha_dato no convertible a fecha',
    'ncodpers no numérico',
    'Registro sociodemográfico vacío (sexo, empleado y edad vacíos)',
    'Edad vacía o NA',
    'Edad mayor a 100 años',
    'Edad menor a 18 años (informativo: cuenta juvenil)',
    'Antigüedad vacía o NA',
    'Antigüedad negativa (p. ej. -999999)',
    'Renta vacía o NA',
    'Sexo vacío',
    'fecha_alta vacía o inválida',
    'indrel_1mes con formato inconsistente (1 vs 1.0)',
    'Provincia vacía',
    'Canal de entrada vacío',
    'conyuemp vacío',
    'ult_fec_cli_1t vacía',
    'Algún producto (target) no binario (NA o vacío)'
  ],
  ARRAY[
    c.total,
    c.total - e.filas_distintas,
    c.dup_llave,
    c.fecha_dato_invalida,
    c.ncodpers_invalido,
    c.sociodemografico_vacio,
    c.edad_vacia,
    c.edad_mayor_100,
    c.edad_menor_18,
    c.antiguedad_vacia,
    c.antiguedad_negativa,
    c.renta_vacia,
    c.sexo_vacio,
    c.fecha_alta_invalida,
    c.indrel_1mes_formato,
    c.provincia_vacia,
    c.canal_vacio,
    c.conyuemp_vacio,
    c.ult_fec_vacia,
    c.productos_no_binarios
  ],
  ARRAY[
    '-',
    'R2: rechazo (se conserva una sola fila)',
    'R2: rechazo',
    'R1: rechazo',
    'R1: rechazo',
    'R3: rechazo',
    'R4: rechazo',
    'R4: rechazo',
    'Se conserva (dato válido)',
    'R6: rechazo',
    'R6: rechazo',
    'Se conserva como NULL (se imputa en ML por provincia y segmento)',
    'Se conserva como NULL',
    'Se conserva como NULL',
    'Se normaliza (1.0 -> 1)',
    'Se conserva como NULL',
    'Se conserva como NULL',
    'Se conserva como NULL (columna casi vacía)',
    'Se conserva como NULL (columna casi vacía)',
    'R5: rechazo (el target debe ser 0/1)'
  ]
) AS h(hallazgo, filas_afectadas, accion_en_plata)
ORDER BY h.filas_afectadas DESC;
