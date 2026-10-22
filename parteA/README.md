# Parte A: arquitectura Medallion en Amazon Athena

Esta parte transforma un CSV de observaciones mensuales de clientes de Santander en datos aptos para analizar la contratación de productos. Se usan **Amazon S3** para almacenar los archivos y **Amazon Athena** para ejecutar SQL. El flujo tiene tres capas: bronce conserva el origen, plata separa y limpia registros, y oro resume una pregunta de negocio.

## Datos y requisitos

El CSV contiene fechas de corte, identificadores de cliente, atributos demográficos y financieros, y **24 indicadores de productos**. En bronce todos los campos son `STRING`; en plata se convierten fechas y números a sus tipos correspondientes. El CSV no está versionado en el repositorio. Para la entrega, el enunciado pide documentar su procedencia, tamaño y un mínimo de **1.000.000 de filas**. Esos valores deben verificarse en el archivo y en Athena; aquí no se consignan cifras que no puedan comprobarse con el material disponible.

Antes de ejecutar las consultas:

1. Crear manualmente en AWS el bucket S3, configurar una ubicación para los resultados de Athena y disponer de permisos para leer y escribir S3 y consultar Athena. La región, el bucket y los permisos deben corresponder a la cuenta utilizada.
2. Subir el CSV con encabezado a `s3://bigdata-trabajo1/bronze/santander/`. Si se usa otro bucket, sustituir las rutas `LOCATION`/`location` de los scripts `02`, `10`, `11` y `14` antes de ejecutarlos.
3. Abrir el editor SQL de Athena y ejecutar los archivos en el orden indicado abajo. Las instrucciones `CREATE TABLE AS SELECT` de plata y oro materializan datos en S3; requieren rutas de destino vacías cuando se vuelven a crear.

Los recursos se crean desde la consola, conforme al [enunciado](../APGD-trabajo1-262.pdf); los archivos SQL sirven para definir y consultar las tablas en Athena.

## Flujo de ejecución

| Paso | Archivos | Qué producen o verifican |
| --- | --- | --- |
| Base de datos | [`01_crear_base_datos.sql`](01_crear_base_datos.sql) | Crea el esquema `santander`. |
| Bronce | [`02_bronce_crear_tabla_externa.sql`](02_bronce_crear_tabla_externa.sql) | Crea `santander.bronze`, tabla externa sobre el CSV en S3. Usa `OpenCSVSerde` para respetar campos entre comillas y omite el encabezado. |
| Inspección | Scripts [`03`](03_bronce_conteo_filas.sql), [`04`](04_bronce_muestra_10_filas.sql), [`05`](05_bronce_filas_por_mes.sql), [`06`](06_bronce_inspeccion_indrel_1mes.sql) y [`07`](07_bronce_inspeccion_ind_nomina.sql) | Revisan el total, una muestra, la cantidad de filas por mes y formatos que necesitan atención. |
| Hallazgos | [`08_hallazgos_tabla_calidad.sql`](08_hallazgos_tabla_calidad.sql) | Devuelve una tabla de defectos con filas afectadas, porcentaje y tratamiento propuesto. Es una consulta de análisis, no una tabla persistida. |
| Reglas de plata | [`09_plata_vista_reglas_calidad.sql`](09_plata_vista_reglas_calidad.sql) | Crea `santander.v_bronze_evaluado` y asigna a cada fila un único `motivo_rechazo` o `NULL` si pasa las reglas. |
| Tablas de plata | [`10_plata_tabla_validas_iceberg.sql`](10_plata_tabla_validas_iceberg.sql) y [`11_plata_tabla_rechazadas_iceberg.sql`](11_plata_tabla_rechazadas_iceberg.sql) | Crean `santander.silver` y `santander.silver_rechazadas` en Iceberg/Parquet. |
| Control de calidad | [`12_plata_cuadre_conteos.sql`](12_plata_cuadre_conteos.sql) y [`13_plata_rechazos_por_motivo.sql`](13_plata_rechazos_por_motivo.sql) | Confirman el cuadre de filas y muestran la distribución de rechazos. |
| Oro | [`14_oro_tabla_contrataciones_iceberg.sql`](14_oro_tabla_contrataciones_iceberg.sql) y [`15_oro_top7_mayo_2016.sql`](15_oro_top7_mayo_2016.sql) | Materializan contrataciones mensuales por producto y segmento y consultan el top 7 de mayo de 2016. |
| Rendimiento | Scripts [`16`](16_comparacion_bronce.sql), [`17`](17_comparacion_plata.sql) y [`18`](18_comparacion_oro.sql) | Comparan la misma pregunta sobre las tres capas. |
| Limpieza | [`19_limpieza_recursos.sql`](19_limpieza_recursos.sql) | Contiene, comentadas, las sentencias para retirar las tablas y la vista cuando ya no se necesiten. |

## Calidad de datos en plata

La consulta de hallazgos cuantifica, entre otros, duplicados exactos, duplicados de `(ncodpers, fecha_dato)`, fechas y números no convertibles, campos vacíos, edades fuera de rango, antigüedad negativa y productos con valores no binarios. La vista aplica las reglas siguientes **en orden**; una fila rechazada queda asociada al primer motivo que falle:

| Regla | Criterio |
| --- | --- |
| R1 | `ncodpers` debe ser numérico y `fecha_dato` una fecha válida. |
| R2 | Solo se conserva una fila por cliente y fecha de corte. |
| R3 | El perfil no puede tener simultáneamente vacíos `sexo`, `ind_empleado` y `age`. |
| R4 | La edad debe ser numérica y estar entre 0 y 100. |
| R5 | Los 24 indicadores de productos deben representar 0 o 1. |
| R6 | La antigüedad debe ser numérica y no negativa. |

Las filas que pasan se convierten a tipos apropiados en `silver`; valores opcionales vacíos o `NA` pasan a `NULL` y `indrel_1mes` se normaliza. Las filas rechazadas conservan los campos originales como texto para auditoría. El control del script `12` debe devolver `CUADRA`, es decir, **filas de bronce = filas válidas + filas rechazadas**. El script `13` permite examinar cuántas filas corresponden a cada motivo.

## Pregunta de negocio y capa oro

**¿Cuántos clientes contrataron por primera vez cada producto en cada mes y segmento, y qué tasa de conversión representa?**

La tabla `gold_contrataciones_mensuales` compara la tenencia de cada cliente entre dos cortes mensuales consecutivos. Una nueva contratación es el cambio de **0 en el mes anterior a 1 en el actual**. Para cada producto y segmento guarda el número de clientes que no tenían el producto el mes anterior, las nuevas contrataciones y el porcentaje de conversión. Los clientes sin un corte del mes inmediatamente anterior no entran en ese cálculo. El script `15` consulta el top 7 de mayo de 2016.

## Comparación de bronce, plata y oro

Los scripts `16`, `17` y `18` calculan las contrataciones nuevas por producto de mayo de 2016 frente a abril de 2016. Ejecutar cada consulta en Athena con **Reuse query results** desactivado y registrar **Data scanned** y **Run time**; los comentarios de los scripts sugieren repetir cada una tres veces. Bronce lee y convierte el CSV al consultar, plata lee datos ya tipados en Parquet, y oro consulta un agregado materializado.

Los resultados pueden diferir entre bronce y plata porque plata excluye filas que fallan las reglas de calidad. Al interpretar bytes y tiempos, revisar tanto el trabajo de lectura como esta diferencia de población. Este repositorio no incluye las mediciones de Athena, por lo que no se atribuye una mejora numérica específica a ninguna capa.

## Al terminar

El archivo [`19_limpieza_recursos.sql`](19_limpieza_recursos.sql) deja las sentencias `DROP` comentadas para ejecutarlas solo cuando ya se hayan registrado los resultados y el video. Después, revisar los objetos restantes en S3 y Athena desde la consola de AWS.
