-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 2.1 · Bronce: inspección de formatos de ind_nomina_ult1

-- Inspección de formatos reales (útil para confirmar las reglas)
SELECT trim(ind_nomina_ult1) AS valor, count(*) AS filas
FROM santander.bronze GROUP BY 1 ORDER BY 2 DESC;
