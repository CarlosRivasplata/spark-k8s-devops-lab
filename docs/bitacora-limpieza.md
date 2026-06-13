# Bitácora de Optimización y Parada de Recursos en Kubernetes

Este documento detalla el procedimiento ejecutado para detener las cargas de trabajo de los entornos de Big Data (`datastream-bigdata`) y Monitoreo (`monitoring`) en el clúster local, con el objetivo de liberar recursos de memoria y CPU en la MacBook Pro.

---

## Parte 1: Pausar el Clúster de Spark (`datastream-bigdata`)

### Pasos Ejecutados
```bash
kubectl scale deployment spark-master --replicas=0 -n datastream-bigdata
kubectl scale deployment spark-worker --replicas=0 -n datastream-bigdata
```

### ¿Por qué se hizo así?
* **Escalado a Cero (`--replicas=0`):** En lugar de eliminar el proyecto por completo, se redujeron las réplicas de los controladores (*Deployments*). Esto apaga y destruye los contenedores activos de Spark de forma inmediata, liberando la memoria RAM del equipo de inmediato.
* **Preservación del Entorno:** Al usar `scale` en lugar de `delete`, las configuraciones, volúmenes y definiciones del laboratorio siguen existiendo en el clúster de Kubernetes. El proyecto está "pausado" y listo para ser reactivado en el futuro sin necesidad de reinstalar nada.

### Verificación del Estado
```bash
kubectl get deployments -n datastream-bigdata
```
**Resultado obtenido:**
```text
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
spark-master   0/0     0            0           11h
spark-worker   0/0     0            0           11h
```
* **Explicación:** La columna `READY 0/0` confirma que el clúster de Spark está completamente detenido de forma exitosa.

---

## Parte 2: Diagnóstico y Eliminación del Entorno de Monitoreo (`monitoring`)

### Pasos Ejecutados
Al intentar buscar despliegues tradicionales en este espacio de nombres, el sistema reportó que no existían recursos de ese tipo:
```bash
kubectl get deployments -n monitoring
# Resultado: No resources found in monitoring namespace.
```

Para investigar qué estaba consumiendo recursos, se listaron todos los objetos del namespace:
```bash
kubectl get all -n monitoring
```
**Resultado obtenido:**
```text
NAME                    READY   STATUS    RESTARTS   AGE
pod/prometheus-server   1/1     Running   0          11h
```

### ¿Por qué se procedió a eliminar el Namespace?
1. **Identificación de un "Unmanaged Pod":** El resultado demostró que Prometheus se estaba ejecutando como un **Pod independiente** (`pod/prometheus-server`), no controlado por un *Deployment*. Los Pods independientes no admiten el comando `scale --replicas=0`.
2. **Borrado Completo y Limpio:** Como este entorno de monitoreo ya no era necesario para el laboratorio actual, la forma más rápida y limpia de liberar el Mac fue eliminar su espacio de nombres por completo:
```bash
kubectl delete namespace monitoring
```
* **Explicación:** Este comando realiza una limpieza en cascada; borra el Pod de Prometheus, sus servicios, sus políticas de acceso y el contenedor físico de manera definitiva, asegurando que no queden procesos residuales en Docker Desktop.

---

## Resumen de Beneficios
* **Cero Consumo Activo:** Los motores de Spark y Prometheus han dejado de ejecutar procesos en segundo plano.
* **Persistencia de Datos:** El laboratorio de Big Data quedó guardado en estado de hibernación.

## Cómo reactivar el laboratorio de Big Data en el futuro
Si necesitas levantar los contenedores de Spark nuevamente, solo debes situarte en tu terminal y escalar las réplicas al número original:
```bash
kubectl scale deployment spark-master --replicas=1 -n datastream-bigdata
kubectl scale deployment spark-worker --replicas=2 -n datastream-bigdata
```
