-- Trabajo 1 – Parte A (Medallion en Athena) · Equipo FINSIR
-- Paso 4.5 · Plata: rechazos por motivo

-- 4.5 Rechazos por motivo
SELECT motivo_rechazo, count(*) AS filas
FROM santander.silver_rechazadas
GROUP BY motivo_rechazo
ORDER BY filas DESC;
