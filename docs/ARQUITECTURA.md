# Arquitectura del laboratorio Big Data

Este documento describe la arquitectura técnica del proyecto `spark-k8s-devops-lab`, centrado en Apache Spark desplegado sobre Kubernetes local mediante Docker Desktop.

---

## 1. Vista general

La arquitectura combina tres capas principales:

```text
Capa de contenedores: Docker
Capa de orquestación: Kubernetes
Capa de procesamiento: Apache Spark
```

Además, se incorpora una capa de monitoreo basada en Prometheus.

---

## 2. Arquitectura lógica

```text
Usuario / Terminal
        |
        | kubectl / docker
        v
Docker Desktop + Kubernetes
        |
        +------------------------------+
        | Namespace datastream-bigdata |
        |                              |
        |  +------------------------+  |
        |  | Spark Master           |  |
        |  | Puerto 7077            |  |
        |  | UI 8080                |  |
        |  +-----------+------------+  |
        |              |               |
        |              | spark://      |
        |              v               |
        |   +----------+----------+    |
        |   |                     |    |
        |   v                     v    |
        | Spark Worker 1      Spark Worker 2
        | Executor(s)         Executor(s)
        |                              |
        +------------------------------+
        |
        +------------------------------+
        | Namespace monitoring         |
        |                              |
        | Prometheus Server            |
        +------------------------------+
```

---

## 3. Componentes técnicos

### 3.1 Docker Desktop

Docker Desktop proporciona:

```text
Motor Docker
Construcción de imágenes
Clúster Kubernetes local
Runtime de contenedores
Interfaz gráfica para observar recursos
```

En este proyecto se usa para crear la imagen:

```text
datastream/spark-worker:3.5.x-jdk17
```

---

### 3.2 Kubernetes

Kubernetes orquesta:

```text
Pods
Deployments
Services
ConfigMaps
Namespaces
RBAC
```

Su función es mantener el estado deseado del sistema. Por ejemplo:

```text
Quiero 1 Spark Master
Quiero 2 Spark Workers
Quiero un Service estable llamado spark-master
```

Si un Pod falla, Kubernetes puede recrearlo. Los Pods no son mascotas; son ganado cloud-native. Con cariño, pero reemplazables.

---

### 3.3 Spark Master

El Spark Master actúa como coordinador del clúster Spark Standalone.

Funciones:

```text
Aceptar aplicaciones Spark
Registrar workers
Asignar executors
Administrar recursos
Mostrar estado desde la UI web
```

Puertos:

| Puerto | Uso |
|---:|---|
| 7077 | Comunicación Spark interna |
| 8080 | Interfaz web Spark Master |

---

### 3.4 Spark Workers

Los workers ejecutan las tareas distribuidas.

Funciones:

```text
Registrarse ante el master
Levantar executors
Ejecutar tasks
Reportar resultados
Liberar recursos al finalizar
```

En la prueba realizada, se observaron 2 workers:

```text
Worker 1: 10.244.0.9
Worker 2: 10.244.0.10
```

Cada worker ejecutó tasks del job `SparkPi`.

---

### 3.5 Driver Spark

El driver es el proceso que coordina la aplicación Spark.

En este laboratorio, el driver se ejecuta dentro del Pod del Spark Master cuando usamos:

```bash
kubectl exec -n datastream-bigdata deployment/spark-master -- spark-submit ...
```

El driver debe ser alcanzable desde los executors. Por eso se recomienda definir:

```bash
--conf spark.driver.host=$DRIVER_IP
--conf spark.driver.bindAddress=0.0.0.0
--conf spark.driver.port=7078
--conf spark.blockManager.port=7079
```

Esto evita que los executors intenten conectarse a un hostname no resoluble o a un puerto dinámico problemático.

---

### 3.6 Executors

Los executors son procesos lanzados en los workers para ejecutar tasks.

En el job validado se usó:

```bash
--executor-cores 1
--executor-memory 512m
--total-executor-cores 2
```

Esto produjo 2 executors, uno por worker.

---

### 3.7 Prometheus

Prometheus se ubica en el namespace:

```text
monitoring
```

Su objetivo es facilitar monitoreo de recursos. En esta versión del laboratorio se despliega el Pod de Prometheus y configuración asociada.

---

## 4. Flujo de datos y ejecución

### 4.1 Construcción

```text
Dockerfile → docker build → imagen local
```

### 4.2 Despliegue

```text
YAMLs → kubectl apply → recursos Kubernetes
```

### 4.3 Registro Spark

```text
Spark Worker → spark://spark-master:7077 → Spark Master
```

### 4.4 Ejecución de job

```text
spark-submit
    ↓
Spark Driver
    ↓
Spark Master
    ↓
Executors en Workers
    ↓
Tasks distribuidas
    ↓
Resultado
```

---

## 5. Decisiones de arquitectura

| Decisión | Justificación |
|---|---|
| Kubernetes local con Docker Desktop | Permite practicar sin nube |
| Spark Standalone | Arquitectura simple para laboratorio |
| Service `spark-master` | Evita depender de IPs internas |
| Namespaces separados | Organización y aislamiento lógico |
| Driver dentro del Spark Master | Simplifica ejecución inicial |
| Puertos fijos para driver | Evita errores de comunicación |
| Recursos limitados en pruebas | Evita saturación local |

---

## 6. Validación realizada

Se ejecutó el job de ejemplo `SparkPi`.

Resultado esperado obtenido:

```text
Pi is roughly 3.140831140831141
```

Evidencia funcional:

```text
Spark Master: ALIVE
Alive Workers: 2
Executors: RUNNING durante ejecución
Tasks: 10/10 finalizadas
Application: Completed
Exit code: 0
```

---

## 7. Arquitectura objetivo futura

Una evolución natural del laboratorio sería incorporar:

```text
Jobs PySpark propios
Volúmenes persistentes
Datasets CSV/Parquet
MinIO o S3 local
Grafana
Spark History Server
CI/CD con GitHub Actions
Helm Charts
Namespace por ambiente: dev, test, prod
```

Esto convertiría el laboratorio en una mini plataforma Big Data local.

### 7.1 Optimización de Networking y Configuración
*   **Service Discovery Interno:** Evolucionar del uso de nombres cortos a nombres DNS completos de Kubernetes (FQDN) para evitar colisiones y mejorar la resolución entre Namespaces.
*   **Infrastructure as Code (IaC):** Migrar de archivos de configuración plana a un enfoque nativo usando ConfigMaps para inyectar configuraciones dinámicamente en los contenedores de monitoreo y procesamiento, permitiendo una gestión uniforme con `kubectl`.
