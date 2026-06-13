# Guía de ejecución paso a paso desde terminal

Esta guía está pensada para ejecutar el proyecto desde la terminal integrada de cualquier editor de código: PyCharm, VS Code, IntelliJ, Cursor o una terminal normal de macOS/Linux.

---

## Paso 1: entrar al proyecto

```bash
cd ~/especialista-bigdata/"17 DATA STREAM RECTIFICADO"/spark-k8s-devops-lab
```

Verifica:

```bash
ls
```

Debes ver:

```text
Dockerfile
spark-master.yaml
spark-deployment.yaml
master-service.yaml
spark-config.yaml
monitoring.yaml
prometheus-config.yaml
prometheus-rbac.yaml
prom-config.yaml
```

---

## Paso 2: validar Kubernetes

```bash
kubectl config current-context
kubectl get nodes
```

Salida correcta:

```text
docker-desktop
desktop-control-plane   Ready
```

---

## Paso 3: construir imagen Docker

```bash
docker build -t datastream/spark-worker:3.5.x-jdk17 .
```

Verifica:

```bash
docker images | grep datastream
```

---

## Paso 4: crear namespaces

```bash
kubectl create namespace datastream-bigdata --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl get namespaces
```

---

## Paso 5: revisar conexión Worker → Master

```bash
grep -n "spark://" spark-deployment.yaml
```

Debe decir:

```text
spark://spark-master:7077
```

Si apunta a una IP fija, cambiarla antes de continuar.

---

## Paso 6: aplicar manifiestos válidos

```bash
for f in *.yaml; do
  if [ "$f" != "prom-config.yaml" ]; then
    kubectl apply -f "$f"
  fi
done
```

---

## Paso 7: verificar Pods

```bash
kubectl get pods -n datastream-bigdata
kubectl get pods -n monitoring
```

Debe salir:

```text
spark-master   Running
spark-worker   Running
spark-worker   Running
prometheus     Running
```

---

## Paso 8: verificar Services

```bash
kubectl get svc -n datastream-bigdata
```

Servicios esperados:

```text
spark-master            7077/TCP,8080/TCP
spark-monitor-service   8080/TCP
```

---

## Paso 9: abrir Spark UI

```bash
kubectl port-forward service/spark-master -n datastream-bigdata 8080:8080
```

Abrir:

```text
http://localhost:8080
```

Debe mostrar:

```text
Alive Workers: 2
Status: ALIVE
```

---

## Paso 10: ejecutar SparkPi correctamente

Abrir otra terminal y ejecutar:

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

Resultado correcto:

```text
Pi is roughly 3.140831140831141
SparkContext: Successfully stopped SparkContext
```

---

## Paso 11: validar en Spark UI

Refrescar:

```text
http://localhost:8080
```

Validar:

```text
Completed Applications: 1
```

---

## Paso 12: revisar logs útiles

Spark Master:

```bash
kubectl logs -n datastream-bigdata deployment/spark-master --tail=100
```

Spark Worker:

```bash
kubectl logs -n datastream-bigdata deployment/spark-worker --tail=100
```

Pods detallados:

```bash
kubectl get pods -n datastream-bigdata -o wide
```

---

## Paso 13: detener port-forward

En la terminal donde está activo:

```text
Forwarding from 127.0.0.1:8080 -> 8080
```

Presiona:

```text
CTRL + C
```

---

## Paso 14: eliminar recursos del proyecto

```bash
for f in *.yaml; do
  if [ "$f" != "prom-config.yaml" ]; then
    kubectl delete -f "$f" --ignore-not-found=true
  fi
done
```

Eliminar namespaces:

```bash
kubectl delete namespace datastream-bigdata
kubectl delete namespace monitoring
```

---

## Checklist rápido

| Paso | Comando/acción | Estado esperado |
|---|---|---|
| 1 | Entrar a `bigdata-lab` | Archivos visibles |
| 2 | `kubectl get nodes` | Nodo `Ready` |
| 3 | `docker build` | Imagen creada |
| 4 | Crear namespaces | Namespaces `Active` |
| 5 | Revisar `spark://` | Usa `spark-master:7077` |
| 6 | Aplicar YAMLs | Recursos creados |
| 7 | Revisar Pods | `Running` |
| 8 | Revisar Services | `spark-master` visible |
| 9 | Port-forward | UI en navegador |
| 10 | SparkPi | Resultado de Pi |
| 11 | Spark UI | App en Completed |
