# BigData Lab: Spark Standalone sobre Kubernetes con Docker Desktop

---

## 0. Enunciado de la Simulación

### 1.1 Contexto de la Empresa
**DataStream Corp** es una empresa de análisis de datos financieros en tiempo real con sede en Madrid. Procesa transacciones bancarias de más de 500.000 clientes en toda Europa, generando aproximadamente 2TB de datos diarios. Actualmente opera con un sistema monolítico legacy que presenta graves problemas de escalabilidad.

El CTO ha aprobado una migración urgente hacia una arquitectura Cloud Native moderna. El equipo de DevOps tiene el mandato de construir y desplegar la nueva plataforma de datos en un entorno Kubernetes gestionado.

### 1.2 El Problema Crítico
**¡INCIDENTE EN PRODUCCIÓN!** El equipo anterior dejó un Dockerfile mal configurado en el repositorio. El clúster de Kubernetes falla al intentar desplegar los pods de Apache Spark. La plataforma lleva 6 horas caída y los SLAs con los bancos clientes están comprometidos.

Los síntomas reportados son los siguientes:
* Los pods de Spark Worker entran en `CrashLoopBackOff` de forma continua.
* El Dockerfile de la imagen base usa `latest` sin fijar versiones, lo que ha causado incompatibilidad.
* El pipeline de ingesta de datos con Apache Flink no arranca por un conflicto de dependencias con la versión de Java.
* Los PersistentVolumeClaims (PVC) de HDFS no se provisionan correctamente.
* No existe monitoreo configurado; el equipo va "a ciegas".

### 1.3 Tu Misión
Como **Senior DevOps Architect y Big Data Engineer** de DataStream Corp, tu equipo debe:
1. Diagnosticar y corregir el Dockerfile con versiones verificadas y estables.
2. Desplegar correctamente el stack de Big Data (Spark + Flink + HDFS) sobre Kubernetes.
3. Configurar el almacenamiento persistente mediante PersistentVolumes.
4. Implementar un pipeline de ingesta de datos funcional.
5. Configurar monitoreo básico con Prometheus y verificar el estado del clúster.
6. Documentar todos los cambios y justificar cada decisión técnica tomada.

---

## 1. Objetivo del proyecto

Este proyecto permite practicar un flujo completo de despliegue Big Data local:

```text
Código / Dockerfile
        ↓
Imagen Docker personalizada
        ↓
Manifiestos Kubernetes
        ↓
Spark Master + Spark Workers
        ↓
Ejecución de jobs distribuidos con spark-submit
        ↓
Validación desde la interfaz web de Spark
```

Es un laboratorio ideal para aprender cómo se conectan **Docker**, **Kubernetes** y **Spark** sin depender de nube pública.

---

## 2. Requisitos previos

Antes de ejecutar el proyecto, asegúrate de tener instalado y funcionando:

| Herramienta | Uso |
|---|---|
| Docker Desktop | Construcción de la imagen y ejecución del clúster local |
| Kubernetes en Docker Desktop | Orquestación de Pods, Services, ConfigMaps y Deployments |
| kubectl | Cliente de línea de comandos para Kubernetes |
| Terminal de cualquier editor | PyCharm, VS Code, IntelliJ, Cursor, terminal macOS/Linux |
| Navegador web | Para acceder a la interfaz de Spark Master |

Verifica que Kubernetes esté activo:

```bash
kubectl config current-context
kubectl get nodes
```

Salida esperada aproximada:

```text
docker-desktop
NAME                    STATUS   ROLES           VERSION
desktop-control-plane   Ready    control-plane   v1.34.3
```

Si el nodo aparece como `Ready`, Kubernetes ya está listo para recibir tu proyecto. Si aparece `NotReady`, Kubernetes está pidiendo café, paciencia o ambas.

---

## 3. Ubicación del proyecto

Desde la terminal, entra a la carpeta donde están el `Dockerfile` y los manifiestos `.yaml`.

Ejemplo en macOS:

```bash
cd ~/especialista-bigdata/"17 DATA STREAM RECTIFICADO"/spark-k8s-devops-lab
```

Comprueba el contenido:

```bash
ls
```

Archivos esperados:

```text
Dockerfile
master-service.yaml
monitoring.yaml
prom-config.yaml
prometheus-config.yaml
prometheus-rbac.yaml
spark-config.yaml
spark-deployment.yaml
spark-master.yaml
```

---

## 4. Construir la imagen Docker

La imagen personalizada usada por Spark es:

```text
datastream/spark-worker:3.5.x-jdk17
```

Construye la imagen:

```bash
docker build -t datastream/spark-worker:3.5.x-jdk17 .
```

Verifica que existe:

```bash
docker images | grep datastream
```

Salida esperada aproximada:

```text
datastream/spark-worker   3.5.x-jdk17
```

---

## 5. Crear namespaces de Kubernetes

Los manifiestos usan dos namespaces:

```text
datastream-bigdata
monitoring
```

Créelos con:

```bash
kubectl create namespace datastream-bigdata --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
```

Verifica:

```bash
kubectl get namespaces
```

Debes ver:

```text
datastream-bigdata   Active
monitoring           Active
```

---

## 6. Revisar la URL del Spark Master en los Workers

El archivo `spark-deployment.yaml` debe apuntar al servicio Kubernetes, no a una IP fija.

Revisa:

```bash
grep -n "spark://" spark-deployment.yaml
```

Debe aparecer algo como:

```yaml
args: ["org.apache.spark.deploy.worker.Worker", "--webui-port", "8081", "spark://spark-master:7077"]
```

Si aparece una IP fija, por ejemplo:

```text
spark://10.96.xxx.xxx:7077
```

cámbiala por:

```text
spark://spark-master:7077
```

En macOS puedes usar:

```bash
sed -i '' 's#spark://10.96.118.169:7077#spark://spark-master:7077#g' spark-deployment.yaml
```

En Linux:

```bash
sed -i 's#spark://10.96.118.169:7077#spark://spark-master:7077#g' spark-deployment.yaml
```

Revisa de nuevo:

```bash
grep -n "spark://" spark-deployment.yaml
```

---

## 7. Aplicar los manifiestos Kubernetes

El archivo `prom-config.yaml` es una configuración interna de Prometheus y no necesariamente un manifiesto Kubernetes completo, por eso puede no tener `apiVersion` ni `kind`.

Para aplicar todos los manifiestos válidos excepto `prom-config.yaml`:

```bash
for f in *.yaml; do
  if [ "$f" != "prom-config.yaml" ]; then
    kubectl apply -f "$f"
  fi
done
```

Salida esperada aproximada:

```text
service/spark-master created
service/spark-monitor-service created
configmap/prometheus-config created
pod/prometheus-server created
clusterrole.rbac.authorization.k8s.io/prometheus-read created
clusterrolebinding.rbac.authorization.k8s.io/prometheus-read-binding created
configmap/spark-config created
deployment.apps/spark-worker created
deployment.apps/spark-master created
```

---

## 8. Verificar Pods

Revisa Spark:

```bash
kubectl get pods -n datastream-bigdata
```

Salida esperada:

```text
NAME                            READY   STATUS    RESTARTS
spark-master-xxxxxxxxxx-xxxxx   1/1     Running   0
spark-worker-xxxxxxxxxx-xxxxx   1/1     Running   0
spark-worker-xxxxxxxxxx-xxxxx   1/1     Running   0
```

Revisa Prometheus:

```bash
kubectl get pods -n monitoring
```

Salida esperada:

```text
prometheus-server   1/1   Running   0
```

---

## 9. Verificar Services

```bash
kubectl get svc -n datastream-bigdata
```

Salida esperada aproximada:

```text
NAME                    TYPE        CLUSTER-IP      PORT(S)
spark-master            ClusterIP   10.96.xx.xx     7077/TCP,8080/TCP
spark-monitor-service   ClusterIP   10.96.xx.xx     8080/TCP
```

Puertos importantes:

| Servicio | Puerto | Uso |
|---|---:|---|
| spark-master | 7077 | Comunicación interna Spark Master/Workers/Drivers |
| spark-master | 8080 | Interfaz web de Spark Master |
| spark-monitor-service | 8080 | Servicio adicional de monitoreo Spark |

---

## 10. Abrir la interfaz web de Spark

Ejecuta:

```bash
kubectl port-forward service/spark-master -n datastream-bigdata 8080:8080
```

La terminal quedará ocupada. Es normal.

Abre en el navegador:

```text
http://localhost:8080
```

Debes ver:

```text
Spark Master at spark://0.0.0.0:7077
Alive Workers: 2
Status: ALIVE
```

Si `8080` está ocupado:

```bash
kubectl port-forward service/spark-master -n datastream-bigdata 8081:8080
```

Y abre:

```text
http://localhost:8081
```

---

## 11. Ejecutar un job Spark de prueba

Para ejecutar el job `SparkPi`, usa este comando. Es la versión recomendada porque define explícitamente la IP del driver y puertos fijos para evitar problemas de comunicación entre executors y driver dentro de Kubernetes.

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

Resultado esperado:

```text
Pi is roughly 3.14...
SparkContext: Successfully stopped SparkContext
```

En la web de Spark debe aparecer en:

```text
Completed Applications
```

---

## 12. Comando rápido de validación completa

```bash
kubectl get pods -n datastream-bigdata
kubectl get svc -n datastream-bigdata
kubectl get pods -n monitoring
```

Y para logs:

```bash
kubectl logs -n datastream-bigdata deployment/spark-master --tail=100
kubectl logs -n datastream-bigdata deployment/spark-worker --tail=100
```

---

## 13. Limpieza del entorno

Para eliminar los recursos del proyecto:

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

Eliminar imagen local, si quieres liberar espacio:

```bash
docker rmi datastream/spark-worker:3.5.x-jdk17
```

---

## 14. Resumen ejecutivo

Este proyecto levanta un clúster Spark Standalone sobre Kubernetes local con Docker Desktop.  
El flujo completo incluye:

1. Construcción de imagen Docker personalizada.
2. Creación de namespaces.
3. Despliegue de manifiestos Kubernetes.
4. Validación de Pods, Services y Workers.
5. Acceso a la UI de Spark.
6. Ejecución de un job distribuido con `spark-submit`.

Resultado validado:

```text
Spark Master: ALIVE
Workers conectados: 2
Job SparkPi: Completed
Resultado: Pi is roughly 3.140831140831141
```

Con esto tienes un entorno Big Data local funcional. Pequeño en tamaño, serio en arquitectura: el clásico “laboratorio de bolsillo con complejo de datacenter”.

---

## 15. Próximos pasos y Mejoras sugeridas

Para evolucionar este laboratorio hacia un entorno más robusto y cercano a producción, se sugieren las siguientes mejoras como hoja de ruta:

1.  **Abstracción del Service DNS:** Configurar los workers para que utilicen el FQDN (Fully Qualified Domain Name) del servicio Spark Master (ej. `spark://spark-master.datastream-bigdata.svc.cluster.local:7077`). Esto hace que la infraestructura sea independiente de nombres cortos y más resiliente ante cambios de red.
2.  **Estandarización de Configuración:** Convertir archivos de configuración plana (como `prom-config.yaml`) en recursos nativos de Kubernetes (`ConfigMaps`). Esto permite gestionar toda la infraestructura mediante `kubectl apply -f .` de manera uniforme.
3.  **Persistencia de Datos:** Implementar `PersistentVolumeClaims` para que los logs de Spark y las métricas de Prometheus no se pierdan al reiniciar los Pods.
4.  **Automatización de Despliegue:** Empaquetar el proyecto utilizando **Helm**, permitiendo instalar todo el stack con un solo comando: `helm install spark-lab ./chart`.

---

## 16. Créditos y Reconocimientos

Este proyecto ha sido desarrollado como parte de un proceso de aprendizaje guiado:

*   **Arquitectura y Código Base:** Desarrollado por el profesor **Antonio Gómez Gallego**. Su diseño original sirve como cimiento técnico para este laboratorio de Big Data.
*   **Implementación, Pruebas y Documentación:** Realizado por **Carlos Alberto Rivasplata Guerrero**. Mi trabajo se centró en la validación del entorno, la resolución de los problemas planteados en la simulación de DataStream Corp, la ejecución de las pruebas de carga (SparkPi) y la elaboración de la documentación técnica detallada para facilitar su despliegue y comprensión.

Agradecimiento especial al profesor Gómez Gallego por proporcionar las bases técnicas necesarias para explorar la orquestación de sistemas distribuidos con Spark y Kubernetes.
