-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 2.1 · Bronce: filas por corte mensual

-- Distribución por corte mensual (17 meses esperados)
SELECT fecha_dato, count(*) AS filas
FROM santander.bronze
GROUP BY fecha_dato
ORDER BY fecha_dato;
