-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 6.3 · Comparación: consulta sobre oro

-- IMPORTANTE: desactiva "Reuse query results" en el editor de Athena y
-- ejecuta la consulta 3 veces; anota "Data scanned" y "Run time".

-- 6.3 ORO (agregado previamente)
SELECT producto, sum(nuevas_contrataciones) AS nuevas_contrataciones
FROM santander.gold_contrataciones_mensuales
WHERE fecha_dato = DATE '2016-05-28'
GROUP BY producto
ORDER BY nuevas_contrataciones DESC;
