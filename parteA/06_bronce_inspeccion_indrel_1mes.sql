-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 2.1 · Bronce: inspección de formatos de indrel_1mes

-- Inspección de formatos reales (útil para confirmar las reglas)
SELECT trim(indrel_1mes) AS valor, count(*) AS filas
FROM santander.bronze GROUP BY 1 ORDER BY 2 DESC;
