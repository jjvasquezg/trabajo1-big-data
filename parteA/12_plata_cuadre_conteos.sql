-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 4.4 · Plata: cuadre bronce = válidas + rechazadas

-- 4.4 CUADRE de conteos: bronce = válidas + rechazadas
WITH b AS (SELECT count(*) AS n FROM santander.bronze),
     v AS (SELECT count(*) AS n FROM santander.silver),
     r AS (SELECT count(*) AS n FROM santander.silver_rechazadas)
SELECT b.n                AS filas_bronce,
       v.n                AS filas_validas,
       r.n                AS filas_rechazadas,
       v.n + r.n          AS validas_mas_rechazadas,
       CASE WHEN b.n = v.n + r.n THEN 'CUADRA' ELSE 'NO CUADRA' END AS verificacion
FROM b, v, r;
