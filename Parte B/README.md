# Parte B — Streaming con IoT Core → SQS → Lambda → DynamoDB

Esta carpeta es la **Parte B** del Trabajo 1 del curso _Almacenamiento y Procesamiento de
Grandes Datos_ (SI7006/SI6003, EAFIT 2026). La idea es sencilla de contar pero tiene su
miga: publicamos un montón de eventos hacia AWS, los dejamos recorrer una tubería de
streaming y, al final, medimos cuánto tardan en llegar a su destino.

El recorrido completo es: publicamos eventos en **IoT Core**, una regla los deja caer en
una cola de **SQS**, una función **Lambda** los va sacando de la cola, los valida y los
guarda en **DynamoDB**. Sobre esa base medimos la latencia de punta a punta.

> Ojo: todos los recursos de AWS se crearon **a mano desde la consola**, sin
> infraestructura como código. Es un requisito del trabajo (y además ayuda a perderle el
> miedo a la consola de AWS).

## Cómo se ve el flujo

```text
publish_events.py ──► IoT Core (topic: finsir/events)
                           │  (regla: SELECT *, timestamp() AS iot_received_ms)
                           ▼
                         SQS (la cola donde se acumulan los eventos)
                           │  (event source mapping)
                           ▼
                        Lambda (lambda.py)  ── valida el esquema y calcula la latencia
                           │
                           ▼
                   DynamoDB (tabla finsir-events, PK: event_id)
```

## Qué hace cada archivo

Para no perderte, esto es lo que encontrarás en la carpeta:

- **`lambda.py`** — El corazón del flujo. Es la función Lambda que va vaciando la cola de
  SQS. Por cada mensaje: lo abre, revisa que el evento traiga todos los campos que debe
  traer (y con el formato correcto), calcula la latencia y lo guarda en DynamoDB. Si un
  evento viene mal formado, lo descarta sin reintentar; si detecta un duplicado, lo ignora;
  y si algo falla por el lado de AWS, pide que se reintente. Nada de perder datos en
  silencio.
- **`publish_events.py`** — El que lanza la lluvia de eventos. Publica 10.000 eventos al
  topic `finsir/events` usando 10 hilos en paralelo para que vaya rápido. A propósito
  rompe el 1 % de los eventos (les quita el campo `product_id`) para comprobar que la
  Lambda efectivamente los rechaza y no se los traga.
- **`measure_latency.py`** — El que saca las cuentas. Recorre la tabla de DynamoDB, junta
  todas las latencias y te dice el promedio, el mínimo, el máximo y cuántas salieron
  negativas (ya veremos por qué eso importa).
- **`README.md`** — Lo que estás leyendo.

### Cómo luce un evento

Cada evento que viaja por la tubería se ve así:

```json
{
    "event_id": "evt-000123",
    "customer_id": "customer-0123",
    "event_type": "recommendation_requested",
    "product_id": "ind_tjcr_fin_ult1",
    "event_timestamp": "2026-10-22T00:25:03.563366+00:00"
}
```

La **regla de IoT Core** le añade un campo extra, `iot_received_ms`, con `timestamp()`:
es la hora exacta (en milisegundos) en que IoT Core recibió el evento. Ese dato resulta
ser clave para medir bien la latencia, como explicamos más abajo.

### ¿Por qué `event_id` como llave de DynamoDB?

La tabla `finsir-events` usa `event_id` como **clave de partición**, y hay dos buenas
razones para ello:

- Es único para cada evento, así que las escrituras se reparten de forma pareja en la
  tabla y no se amontonan en una sola partición.
- Nos deja escribir con la condición `attribute_not_exists(event_id)`, que es nuestra red
  de seguridad contra duplicados. SQS puede entregar el mismo mensaje más de una vez (así
  funciona la entrega _at-least-once_), y gracias a esta llave el duplicado simplemente no
  pisa al registro original.

## El misterio de las latencias negativas

La latencia que queremos medir es el tiempo entre que IoT Core recibe el evento y que la
Lambda lo escribe en DynamoDB. Suena directo: restar dos tiempos. El problema está en
_qué_ dos tiempos restar.

En una primera versión, restábamos contra el `event_timestamp`, que es la hora que pone
el **cliente** que publica los eventos. ¿El detalle? El reloj del computador que publica y
el reloj de Lambda no están sincronizados al milisegundo. Resultado: algunos eventos
parecían llegar _antes_ de haber sido enviados, o sea, latencias **negativas**. Un sinsentido
físico que delataba que estábamos midiendo con dos reglas distintas.

La solución fue medir contra `iot_received_ms`, un tiempo que genera el propio AWS (la
regla de IoT Core). Al tener ambos extremos de la medición con relojes de AWS, las
latencias negativas desaparecieron y los números empezaron a tener sentido.

## Los resultados

Publicamos **10.000 eventos**. Como el 1 % se invalida a propósito, la Lambda descarta
100 y en DynamoDB quedan **9.900**. Las cuentas cuadran:

> `10.000 publicados = 9.900 guardados + 100 descartados`
> (los 100 descartados fallan por la misma razón: les falta el campo obligatorio `product_id`).

Y aquí está la comparación que cuenta toda la historia:

### Antes: midiendo con el reloj del cliente (`event_timestamp`)

| Métrica                | Valor      |
| ---------------------- | ---------- |
| Eventos con latencia   | 9.900      |
| Latencia promedio      | 167.23 ms  |
| Latencia máxima        | 5798.28 ms |
| Latencia mínima        | -28.26 ms  |
| Latencias negativas    | 3.801      |
| Latencias no negativas | 6.099      |

Casi 4 de cada 10 mediciones salieron negativas. Con ese nivel de ruido, estos números no
sirven para concluir nada sobre el rendimiento real.

### Después: midiendo con el reloj de AWS (`iot_received_ms`)

| Métrica                | Valor      |
| ---------------------- | ---------- |
| Eventos con latencia   | 9.900      |
| Latencia promedio      | 73.53 ms   |
| Latencia máxima        | 3320.77 ms |
| Latencia mínima        | 20.37 ms   |
| Latencias negativas    | 0          |
| Latencias no negativas | 9.900      |

Cero negativas, un promedio de ~73 ms y un mínimo positivo de 20.37 ms. Ahora sí, cada
número representa tiempo real de viaje por la tubería.

### Qué nos dicen estos números

- El promedio de ~73 ms es lo que cuesta el recorrido asíncrono: encolar en SQS, despertar
  e invocar la Lambda y escribir en DynamoDB.
- La máxima de ~3.3 segundos son los _cold starts_ de Lambda y los primeros lotes, cuando
  el consumidor todavía está arrancando y escalando.
- Lo más importante: la gran mejora entre una medición y otra **no fue de rendimiento, sino
  de método**. Medir con un reloj consistente lo cambió todo.

## Cómo ejecutar todo esto

### Antes de empezar

1. Tener los recursos creados a mano en la consola de AWS:
    - **IoT Core**: una regla sobre el topic `finsir/events` con
      `SELECT *, timestamp() AS iot_received_ms FROM 'finsir/events'` que apunte a SQS.
    - **SQS**: la cola a la que escribe la regla.
    - **Lambda**: la función con el código de `lambda.py`, con la cola como _trigger_ y
      `ReportBatchItemFailures` activado.
    - **DynamoDB**: la tabla `finsir-events` con `event_id` (String) como clave de partición.
2. Exportar las variables de entorno que necesita el productor:

    ```bash
    export AWS_REGION="us-east-1"
    export IOT_ENDPOINT="xxxxxxxxxxxxx-ats.iot.us-east-1.amazonaws.com"
    ```

    Si no conoces el endpoint, lo sacas con:

    ```bash
    aws iot describe-endpoint --endpoint-type iot:Data-ATS --region us-east-1
    ```

3. Tener las credenciales de AWS configuradas con el perfil que prefieras (por ejemplo con
   `aws configure`). Solo asegúrate de que el perfil apunte a la región y la cuenta donde
   creaste los recursos.

### Paso 1 — Soltar los 10.000 eventos

```bash
python publish_events.py
```

Deberías ver algo así (las cuentas que reporta IoT Core):

```text
Events attempted: 10000
API accepted: 10000
Publication failures: 0
Elapsed seconds: ...
```

### Paso 2 — (Opcional) Echar un vistazo a lo que quedó en DynamoDB

```bash
aws dynamodb scan \
  --table-name finsir-events \
  --filter-expression "begins_with(event_id, :prefix)" \
  --expression-attribute-values '{":prefix":{"S":"evt-"}}' \
  --projection-expression "event_id, latency_ms, stored_at" \
  --region us-east-1 \
  --output json > latencies.json
```

### Paso 3 — Medir la latencia

```bash
python measure_latency.py
```

Esto imprime el conteo de eventos, el promedio, el mínimo, el máximo y cuántas latencias
salieron negativas (justo los números de la sección de resultados).

### Al terminar, limpia

Cuando acabes, borra los recursos desde la consola para no gastar los créditos gratuitos.
