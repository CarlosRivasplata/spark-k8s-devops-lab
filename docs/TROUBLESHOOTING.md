# Troubleshooting del proyecto

Este documento recoge errores comunes encontrados durante la ejecución del laboratorio y sus soluciones.

---

## 1. Error: namespace not found

### Mensaje típico

```text
Error from server (NotFound): namespaces "datastream-bigdata" not found
Error from server (NotFound): namespaces "monitoring" not found
```

### Causa

Los manifiestos `.yaml` intentan crear recursos dentro de namespaces que todavía no existen.

### Solución

```bash
kubectl create namespace datastream-bigdata --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
```

---

## 2. Error: apiVersion not set, kind not set

### Mensaje típico

```text
error validating "prom-config.yaml": apiVersion not set, kind not set
```

### Causa

`prom-config.yaml` no es un manifiesto Kubernetes completo. Es probablemente configuración interna para Prometheus.

### Solución

No aplicar directamente ese archivo con `kubectl apply -f .`.

Usar:

```bash
for f in *.yaml; do
  if [ "$f" != "prom-config.yaml" ]; then
    kubectl apply -f "$f"
  fi
done
```

---

## 3. Problema: Spark UI muestra Alive Workers: 0

### Causa probable

Los workers están intentando conectarse al master usando una IP interna vieja o incorrecta.

Ejemplo incorrecto:

```text
spark://10.96.118.169:7077
```

### Solución

En `spark-deployment.yaml`, usar el nombre del Service:

```text
spark://spark-master:7077
```

Aplicar cambio:

```bash
kubectl apply -f spark-deployment.yaml
```

Verificar logs:

```bash
kubectl logs -n datastream-bigdata deployment/spark-worker --tail=100
```

Debe aparecer:

```text
Successfully registered with master
```

---

## 4. Problema: SparkPi queda en RUNNING indefinidamente

### Síntomas

En Spark UI:

```text
Running Applications: 1
Spark Pi RUNNING
```

En logs del Master:

```text
Removing executor ... because it is EXITED
Launching executor ...
```

En logs del Worker:

```text
Executor finished with state EXITED message Command exited with code 1
```

### Causa probable

El driver Spark no está anunciando una dirección correctamente alcanzable por los executors.

También puede ocurrir si Spark usa puertos dinámicos difíciles de resolver dentro de Kubernetes local.

### Solución

Ejecutar `spark-submit` indicando explícitamente:

```bash
--conf spark.driver.host=$DRIVER_IP
--conf spark.driver.bindAddress=0.0.0.0
--conf spark.driver.port=7078
--conf spark.blockManager.port=7079
```

Comando recomendado:

```bash
kubectl exec -n datastream-bigdata deployment/spark-master -- sh -c '
DRIVER_IP=$(hostname -i)
echo "DRIVER_IP=$DRIVER_IP"

/opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --conf spark.driver.host=$DRIVER_IP \
  --conf spark.driver.bindAddress=0.0.0.0 \
  --conf spark.driver.port=7078 \
  --conf spark.blockManager.port=7079 \
  --executor-cores 1 \
  --executor-memory 512m \
  --total-executor-cores 2 \
  --class org.apache.spark.examples.SparkPi \
  /opt/spark/examples/jars/spark-examples_2.12-3.5.1.jar \
  10
'
```

---

## 5. Advertencia: Too large frame

### Mensaje típico

```text
java.lang.IllegalArgumentException: Too large frame
```

### Posible causa

Algún proceso o navegador intenta comunicarse mediante HTTP contra el puerto Spark RPC `7077`.

El puerto `7077` no es web. Es interno de Spark.

### Solución

Usar el navegador solo contra el puerto web:

```text
http://localhost:8080
```

No abrir:

```text
http://localhost:7077
```

---

## 6. Problema: puerto 8080 ocupado

### Mensaje típico

```text
Unable to listen on port 8080
```

### Solución

Usar otro puerto local:

```bash
kubectl port-forward service/spark-master -n datastream-bigdata 8081:8080
```

Abrir:

```text
http://localhost:8081
```

---

## 7. Problema: ImagePullBackOff

### Síntoma

```text
ImagePullBackOff
ErrImagePull
```

### Causa

Kubernetes intenta descargar una imagen que está solo localmente.

### Solución

Verificar que la imagen exista:

```bash
docker images | grep datastream
```

Si no existe, construir:

```bash
docker build -t datastream/spark-worker:3.5.x-jdk17 .
```

Si usas `kind` puro fuera de Docker Desktop, cargar la imagen al clúster:

```bash
kind load docker-image datastream/spark-worker:3.5.x-jdk17
```

---

## 8. Problema: Completed Applications aparece después de hacer kill

### Explicación

Si un job queda atascado y lo matas desde la UI con `(kill)`, puede pasar a `Completed Applications`, pero eso no significa que haya terminado correctamente.

Para validar una ejecución correcta, busca en terminal:

```text
Pi is roughly 3.14...
SparkContext: Successfully stopped SparkContext
exitCode 0
```

---

## 9. Comandos de diagnóstico rápido

```bash
kubectl get pods -n datastream-bigdata -o wide
kubectl get svc -n datastream-bigdata
kubectl logs -n datastream-bigdata deployment/spark-master --tail=120
kubectl logs -n datastream-bigdata deployment/spark-worker --tail=120
kubectl describe pod -n datastream-bigdata NOMBRE_DEL_POD
```

---

## 10. Recomendación final

Para pruebas locales, empezar siempre con recursos pequeños:

```bash
--executor-cores 1
--executor-memory 512m
--total-executor-cores 2
```

Luego aumentar progresivamente.

En Big Data, “más recursos” no siempre significa “mejor ejecución”. A veces significa “felicidades, has creado un ventilador de MacBook con interfaz web”.
