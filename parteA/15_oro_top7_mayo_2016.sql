-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 5.1 · Oro: top 7 productos de mayo 2016

-- 5.1 Respuesta a la pregunta (para mostrar en el video):
--     Top 7 productos más contratados en el último mes disponible
SELECT producto,
       sum(nuevas_contrataciones) AS nuevas_contrataciones,
       round(100.0 * sum(nuevas_contrataciones)
             / sum(clientes_sin_producto_mes_anterior), 4) AS tasa_conversion_pct
FROM santander.gold_contrataciones_mensuales
WHERE fecha_dato = DATE '2016-05-28'
GROUP BY producto
ORDER BY nuevas_contrataciones DESC
LIMIT 7;
