# Diagrama de bloques del sistema

Este documento presenta los diagramas principales del proyecto `bigdata-lab`.

Los diagramas están escritos en **Mermaid**, por lo que pueden visualizarse directamente en GitHub, GitLab, VS Code, PyCharm con plugin Mermaid o cualquier visor compatible.

---

## 1. Diagrama general de bloques

```mermaid
flowchart TD
    A[Usuario / Terminal del editor] --> B[Docker Desktop]
    B --> C[Imagen Docker personalizada<br/>datastream/spark-worker:3.5.x-jdk17]
    A --> D[kubectl]
    D --> E[Kubernetes local]
    E --> F[Namespace datastream-bigdata]
    E --> G[Namespace monitoring]

    F --> H[Service spark-master<br/>7077 / 8080]
    F --> I[Spark Master Pod]
    F --> J[Spark Worker Pod 1]
    F --> K[Spark Worker Pod 2]
    F --> L[ConfigMap spark-config]

    G --> M[Prometheus Server Pod]
    G --> N[RBAC Prometheus]

    H --> I
    J --> H
    K --> H

    I --> O[Spark Driver<br/>spark-submit]
    O --> P[Executors]
    P --> J
    P --> K

    A --> Q[Browser<br/>http://localhost:8080]
    Q --> R[port-forward]
    R --> H
```

---

## 2. Flujo de despliegue

```mermaid
sequenceDiagram
    participant U as Usuario
    participant D as Docker
    participant K as Kubernetes
    participant S as Spark

    U->>D: docker build -t datastream/spark-worker:3.5.x-jdk17 .
    D-->>U: Imagen construida
    U->>K: kubectl create namespace datastream-bigdata
    U->>K: kubectl create namespace monitoring
    U->>K: kubectl apply -f YAMLs válidos
    K->>S: Crea Spark Master
    K->>S: Crea Spark Workers
    S->>S: Workers se registran en Master
    U->>K: kubectl port-forward service/spark-master 8080:8080
    U->>S: Abre UI Spark en localhost:8080
```

---

## 3. Flujo de ejecución de job Spark

```mermaid
sequenceDiagram
    participant U as Usuario
    participant M as Spark Master Pod
    participant D as Spark Driver
    participant W1 as Spark Worker 1
    participant W2 as Spark Worker 2
    participant E1 as Executor 1
    participant E2 as Executor 2

    U->>M: kubectl exec deployment/spark-master -- spark-submit
    M->>D: Inicia Spark Driver
    D->>M: Registra aplicación SparkPi
    M->>W1: Solicita executor
    M->>W2: Solicita executor
    W1->>E1: Lanza Executor 1
    W2->>E2: Lanza Executor 2
    E1->>D: Se registra con el driver
    E2->>D: Se registra con el driver
    D->>E1: Envía tasks
    D->>E2: Envía tasks
    E1-->>D: Resultado parcial
    E2-->>D: Resultado parcial
    D-->>U: Pi is roughly 3.14
```

---

## 4. Diagrama de red interno

```mermaid
flowchart LR
    subgraph datastream-bigdata
        SVC[Service spark-master<br/>ClusterIP<br/>7077/TCP, 8080/TCP]
        MASTER[Spark Master Pod<br/>10.244.0.8]
        WORKER1[Spark Worker Pod<br/>10.244.0.9]
        WORKER2[Spark Worker Pod<br/>10.244.0.10]
        DRIVER[Spark Driver<br/>host=10.244.0.8<br/>port=7078]
    end

    BROWSER[Browser local<br/>localhost:8080] --> PF[kubectl port-forward]
    PF --> SVC
    SVC --> MASTER

    WORKER1 -->|spark://spark-master:7077| SVC
    WORKER2 -->|spark://spark-master:7077| SVC

    MASTER --> DRIVER
    WORKER1 -->|Executor RPC| DRIVER
    WORKER2 -->|Executor RPC| DRIVER
```

---

## 5. Diagrama de componentes Kubernetes

```mermaid
flowchart TB
    subgraph Kubernetes Cluster
        subgraph Namespace_datastream_bigdata[Namespace: datastream-bigdata]
            DEPLOY_MASTER[Deployment<br/>spark-master]
            DEPLOY_WORKER[Deployment<br/>spark-worker]
            SVC_MASTER[Service<br/>spark-master]
            SVC_MONITOR[Service<br/>spark-monitor-service]
            CM_SPARK[ConfigMap<br/>spark-config]
        end

        subgraph Namespace_monitoring[Namespace: monitoring]
            POD_PROM[Pod<br/>prometheus-server]
            CM_PROM[ConfigMap<br/>prometheus-config]
        end

        RBAC[ClusterRole + ClusterRoleBinding<br/>prometheus-read]
    end

    DEPLOY_MASTER --> SVC_MASTER
    DEPLOY_WORKER --> SVC_MASTER
    CM_SPARK --> DEPLOY_MASTER
    CM_SPARK --> DEPLOY_WORKER
    CM_PROM --> POD_PROM
    RBAC --> POD_PROM
```

---

## 6. Leyenda

| Elemento | Significado |
|---|---|
| Service | Punto estable de comunicación dentro de Kubernetes |
| Pod | Unidad mínima de ejecución en Kubernetes |
| Deployment | Controlador que mantiene Pods activos |
| ConfigMap | Recurso para configuración no sensible |
| Executor | Proceso Spark que ejecuta tareas |
| Driver | Proceso Spark que coordina la aplicación |
| Master | Coordinador de recursos Spark |
| Worker | Nodo lógico que ejecuta executors |

---

## 7. Lectura rápida del sistema

```text
El usuario construye una imagen Docker.
Kubernetes despliega Master y Workers.
Los Workers se conectan al Service spark-master.
El usuario lanza un spark-submit dentro del Spark Master.
El Driver coordina el job.
Los Executors ejecutan las tareas en los Workers.
El resultado aparece en terminal y la aplicación queda registrada como Completed en la UI.
```
