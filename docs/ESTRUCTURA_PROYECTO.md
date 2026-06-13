# Estructura del proyecto

Este documento describe la organización del proyecto `bigdata-lab` y la función de cada archivo principal.

---

## 1. Estructura general

```text
bigdata-lab/
├── Dockerfile
├── master-service.yaml
├── monitoring.yaml
├── prom-config.yaml
├── prometheus-config.yaml
├── prometheus-rbac.yaml
├── spark-config.yaml
├── spark-deployment.yaml
├── spark-master.yaml
└── docs/
    ├── ESTRUCTURA_PROYECTO.md
    ├── ARQUITECTURA.md
    ├── DIAGRAMA_BLOQUES.md
    ├── GUIA_EJECUCION.md
    └── TROUBLESHOOTING.md
```

---

## 2. Archivos principales

| Archivo | Tipo | Función |
|---|---|---|
| `Dockerfile` | Docker | Define la imagen base con Java 17, Spark 3.5.1, Python 3.10, PySpark, Pandas y NumPy |
| `spark-master.yaml` | Kubernetes | Define el Deployment/Pod del Spark Master y expone puertos internos |
| `spark-deployment.yaml` | Kubernetes | Define el Deployment de los Spark Workers |
| `master-service.yaml` | Kubernetes | Crea el Service `spark-master` para que workers y drivers encuentren al master |
| `spark-config.yaml` | Kubernetes | Define configuración compartida para Spark mediante ConfigMap |
| `monitoring.yaml` | Kubernetes | Define recursos de monitoreo o servicios asociados al laboratorio |
| `prometheus-config.yaml` | Kubernetes | Crea ConfigMaps/Pod de Prometheus |
| `prometheus-rbac.yaml` | Kubernetes | Define permisos RBAC para que Prometheus pueda leer recursos del clúster |
| `prom-config.yaml` | Configuración | Archivo de configuración interna de Prometheus; no siempre se aplica directamente con `kubectl apply` |

---

## 3. Componentes del proyecto

### 3.1 Dockerfile

El `Dockerfile` construye una imagen personalizada:

```text
datastream/spark-worker:3.5.x-jdk17
```

Incluye:

```text
Java 17
Apache Spark 3.5.1
Python 3.10
PySpark 3.5.1
Pandas 2.2.0
NumPy 1.26.0
Usuario sparkuser
Directorio /app
```

La imagen se usa tanto para el Spark Master como para los Spark Workers.

---

### 3.2 Spark Master

El Spark Master es el componente que coordina la ejecución distribuida.

Responsabilidades:

```text
Recibir aplicaciones Spark
Asignar executors a workers
Gestionar estado de workers
Exponer interfaz web en puerto 8080
Escuchar conexiones Spark en puerto 7077
```

En la UI se observa como:

```text
Spark Master at spark://0.0.0.0:7077
Status: ALIVE
Alive Workers: 2
```

---

### 3.3 Spark Workers

Los Spark Workers ejecutan tareas reales del job Spark.

Responsabilidades:

```text
Registrarse contra el Spark Master
Lanzar executors
Ejecutar tasks
Reportar estado al Master
Exponer Worker UI en puerto 8081
```

El archivo `spark-deployment.yaml` debe conectarlos usando:

```text
spark://spark-master:7077
```

No se recomienda usar IPs internas como:

```text
spark://10.96.xxx.xxx:7077
```

porque las IPs de Services pueden cambiar.

---

### 3.4 Kubernetes Services

Los Services permiten comunicación estable dentro del clúster.

| Service | Namespace | Puerto | Uso |
|---|---|---:|---|
| `spark-master` | `datastream-bigdata` | 7077 | Comunicación Spark interna |
| `spark-master` | `datastream-bigdata` | 8080 | UI Spark Master |
| `spark-monitor-service` | `datastream-bigdata` | 8080 | Monitoreo de Spark |

---

### 3.5 Namespaces

El proyecto usa separación lógica por namespaces:

| Namespace | Uso |
|---|---|
| `datastream-bigdata` | Recursos principales de Spark |
| `monitoring` | Recursos de Prometheus/monitoreo |
| `default` | No se recomienda usar para este proyecto |
| `kube-system` | Componentes internos de Kubernetes |

---

## 4. Flujo de ejecución del proyecto

```text
1. El usuario ejecuta docker build
2. Docker crea la imagen datastream/spark-worker:3.5.x-jdk17
3. Kubernetes crea namespaces
4. Kubernetes aplica Services, ConfigMaps, Deployments y RBAC
5. El Spark Master arranca
6. Los Spark Workers se conectan al Master
7. El usuario accede a http://localhost:8080 mediante port-forward
8. El usuario lanza un job con spark-submit
9. Spark distribuye tasks entre workers
10. La aplicación aparece como Completed Applications
```

---

## 5. Buenas prácticas aplicadas

| Práctica | Motivo |
|---|---|
| Usar nombres de Service en lugar de IPs | Evita errores si Kubernetes cambia IPs internas |
| Separar namespaces | Mejora organización y trazabilidad |
| Usar ConfigMaps | Permite separar configuración de imagen |
| Definir puertos del driver en `spark-submit` | Evita problemas de comunicación driver-executor |
| Limitar recursos en pruebas | Evita saturar Docker Desktop |
| Usar `port-forward` para UI local | Más simple para entorno de laboratorio |

---

## 6. Riesgos conocidos

| Riesgo | Causa | Solución |
|---|---|---|
| Workers no aparecen en Spark UI | Worker apunta a IP incorrecta | Usar `spark://spark-master:7077` |
| Job queda en RUNNING | Executors no conectan al driver | Definir `spark.driver.host` y puertos fijos |
| `prom-config.yaml` falla | No es manifiesto Kubernetes completo | Excluirlo del `kubectl apply` masivo |
| `namespace not found` | Namespaces no creados | Crear `datastream-bigdata` y `monitoring` |
| Puerto 8080 ocupado | Otro proceso usa el puerto local | Usar `8081:8080` en `port-forward` |
