# KUB 34: Сбор логов в кластере Kubernetes


https://lk.rebrainme.com/kubernetesv2/task/700



## Задание:

### 1. Установите kibana, elasticsearch, fluent-bit в namespace logging
(в данном задании у нас нет StorageClass, поэтому необходимо отключить создание pvc).


- fluent-bit должен собирать логи со всех подов кластера
- fluent-bit должен отправлять логи в elasticsearch
- kibana должна подключаться и читать данные из elasticsearch



### 2. Настройте basic authentication для kibana ingress
(вы можете использовать выданное вам доменное имя для настройки ingress)



## Выполнение

Реаллизовано запуском helm charts через ansible. С добавлением некоторых кастомных манифестов.

DNS: 

os-test.berg.ru - os
osd-test.berg.ru - dashboard

OS admin user: admin:password
OS logs collector user: log_writer:LogWriterPassword


## Особенности

### 1 Использовался Opensearch + OS Dashboard

### 2 Ingess
Не делал Ingess, так как в корпоративном окружении у нас есть Istio, на нем и реализован доступ по доменному имени.
Для этого использовались виртуальные сервисы (приложены)

### 3 Basic auth
Не делал так как нет Ingress. К тому же доступ в Dashboard защищен нативным security. А в корпоративном Istio Gateway у меня нет прав.

Надюсь, буду прощен, так как Ingress and Basicauth я успешно воплощал в предыдущих заданиях. Если потребутся для макс оценки - переделаю.


### 4 Непонятное поведение в логах fluent-bit

Со старта контейнера fluentbit его логи показывают что запись в OS усшена

Однако, по прошествии какого то времени, ФБ начинает выделываться:

```
[2025/06/04 21:16:00] [debug] [output:opensearch:opensearch.0] HTTP Status=200 URI=/_bulk
[2025/06/04 21:16:00] [debug] [output:opensearch:opensearch.0] HTTP Status=200 URI=/_bulk
[2025/06/04 21:16:00] [debug] [output:opensearch:opensearch.0] HTTP Status=200 URI=/_bulk
[2025/06/04 21:16:00] [ warn] [engine] failed to flush chunk '1-1748991061.317876068.flb', retry in 1791 seconds: task_id=407, input=tail.0 > output=opensearch.0 (out_id=0)
[2025/06/04 21:16:00] [ warn] [engine] failed to flush chunk '1-1748994769.600766687.flb', retry in 135 seconds: task_id=1938, input=tail.0 > output=opensearch.0 (out_id=0)
[2025/06/04 21:16:00] [ warn] [engine] failed to flush chunk '1-1748994871.319613300.flb', retry in 411 seconds: task_id=1974, input=tail.0 > output=opensearch.0 (out_id=0)
```

[логи флюента](pics/fluent-bit-logs-failed-flush.png)

Странно следующее: дашборд OS  показывает что в это самое время логи успешно сохранены в OS

[OS Dashboard с логами всех контейнеров кластера](pics/dashboard.png)

Пока не могу найти этому объяснения.

[на всякий случай, полный лог одного из bluentbit контейнеров](logs/fluent-bit-logging-pgkjr.log)


Скорее всего это ошибки маппинга по умолчанию для полей в логах кубернетис.

Требует отдельной работы по созданию кастомного маппинга.


## Скриншоты

```
curl -sku admin:password -X GET https://os-test.berg.ru | jq

curl -sku admin:password -X GET https://os-test.berg.ru/_cluster/health?pretty | jq
```

[curl](pics/curl.png)





[OS Dashboard с логами всех контейнеров кластера](pics/dashboard.png)

видно что в логах имеются поля от Kubernetes фильтра из fluentbit

[ноды](pics/nodes.png)

[pods](pics/pods.png)

[pvc](pics/pvc.png)

[services](pics/services.png)


## некоторые объекты

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit-logging
  namespace: logging
  uid: 3b6b218a-7ac7-4619-9238-9dc5406ad5bb
  resourceVersion: '90419913'
  generation: 23
  creationTimestamp: '2025-06-01T05:15:36Z'
  labels:
    app.kubernetes.io/instance: fluent-bit-logging
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: fluent-bit
    app.kubernetes.io/version: 4.0.1
    helm.sh/chart: fluent-bit-0.49.0
  annotations:
    deprecated.daemonset.template.generation: '23'
    meta.helm.sh/release-name: fluent-bit-logging
    meta.helm.sh/release-namespace: logging
  selfLink: /apis/apps/v1/namespaces/logging/daemonsets/fluent-bit-logging
status:
  currentNumberScheduled: 5
  numberMisscheduled: 0
  desiredNumberScheduled: 5
  numberReady: 5
  observedGeneration: 23
  updatedNumberScheduled: 5
  numberAvailable: 5
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: fluent-bit-logging
      app.kubernetes.io/name: fluent-bit
  template:
    metadata:
      creationTimestamp: null
      labels:
        app.kubernetes.io/instance: fluent-bit-logging
        app.kubernetes.io/name: fluent-bit
      annotations:
        checksum/config: 269843990f85ac073e8bbf19b0c11337b1a372b4a34ad16c6c0ccdee34f08852
        kubectl.kubernetes.io/restartedAt: '2025-06-04T00:22:45+03:00'
    spec:
      volumes:
        - name: config
          configMap:
            name: fluent-bit-logging
            defaultMode: 420
        - name: varlog
          hostPath:
            path: /var/log
            type: ''
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
            type: ''
        - name: etcmachineid
          hostPath:
            path: /etc/machine-id
            type: File
      containers:
        - name: fluent-bit
          image: cr.fluentbit.io/fluent/fluent-bit:4.0-debug
          command:
            - /fluent-bit/bin/fluent-bit
          args:
            - '--workdir=/fluent-bit/etc'
            - '--config=/fluent-bit/etc/conf/fluent-bit.conf'
          ports:
            - name: http
              containerPort: 2020
              protocol: TCP
          env:
            - name: FLUENT_OPENSEARCH_PORT
              value: '9200'
            - name: FLUENT_OPENSEARCH_USER
              valueFrom:
                secretKeyRef:
                  name: ossecret
                  key: username
            - name: FLUENT_OPENSEARCH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ossecret
                  key: password
          resources: {}
          volumeMounts:
            - name: config
              mountPath: /fluent-bit/etc/conf
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              readOnly: true
              mountPath: /var/lib/docker/containers
            - name: etcmachineid
              readOnly: true
              mountPath: /etc/machine-id
          livenessProbe:
            httpGet:
              path: /
              port: http
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /api/v1/health
              port: http
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      serviceAccountName: fluent-bit-logging
      serviceAccount: fluent-bit-logging
      securityContext: {}
      schedulerName: default-scheduler
      tolerations:
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
        - operator: Exists
          effect: NoExecute
        - operator: Exists
          effect: NoSchedule
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 0
  revisionHistoryLimit: 10
```

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: master
  namespace: logging
  uid: 10a600ce-a8ff-4148-badc-d3dab6e7c7da
  resourceVersion: '90000466'
  generation: 3
  creationTimestamp: '2025-05-29T15:48:47Z'
  labels:
    app.kubernetes.io/component: master
    app.kubernetes.io/instance: os-master
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: opensearch
    app.kubernetes.io/version: 3.0.0
    helm.sh/chart: opensearch-3.0.0
  annotations:
    majorVersion: '3'
    meta.helm.sh/release-name: os-master
    meta.helm.sh/release-namespace: logging
  selfLink: /apis/apps/v1/namespaces/logging/statefulsets/master
status:
  observedGeneration: 3
  replicas: 3
  readyReplicas: 3
  currentReplicas: 3
  updatedReplicas: 3
  currentRevision: master-7f47d6cb86
  updateRevision: master-7f47d6cb86
  collisionCount: 0
  availableReplicas: 3
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/instance: os-master
      app.kubernetes.io/name: opensearch
  template:
    metadata:
      name: master
      creationTimestamp: null
      labels:
        app.kubernetes.io/component: master
        app.kubernetes.io/instance: os-master
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: opensearch
        app.kubernetes.io/version: 3.0.0
        helm.sh/chart: opensearch-3.0.0
      annotations:
        configchecksum: 859d48434e50caa5fa5d280384db85164b5572d89a6aed3dfbabc870b707556
        kubectl.kubernetes.io/restartedAt: '2025-06-01T05:31:18+03:00'
    spec:
      volumes:
        - name: config
          configMap:
            name: master-config
            defaultMode: 420
        - name: config-emptydir
          emptyDir: {}
        - name: master-tls
          secret:
            secretName: master-tls
            defaultMode: 420
        - name: admin-tls
          secret:
            secretName: admin-tls
            defaultMode: 420
        - name: action-groups
          secret:
            secretName: opensearch-action-groups
            defaultMode: 420
        - name: security-config
          secret:
            secretName: opensearch-config
            defaultMode: 420
        - name: internal-users-config
          secret:
            secretName: opensearch-internal-users
            defaultMode: 420
        - name: roles
          secret:
            secretName: opensearch-roles
            defaultMode: 420
        - name: role-mapping
          secret:
            secretName: opensearch-roles-mapping
            defaultMode: 420
        - name: tenants
          secret:
            secretName: opensearch-tenats
            defaultMode: 420
      initContainers:
        - name: fsgroup-volume
          image: busybox:latest
          command:
            - sh
            - '-c'
          args:
            - chown -R 1000:1000 /usr/share/opensearch/data
          resources: {}
          volumeMounts:
            - name: master
              mountPath: /usr/share/opensearch/data
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 0
        - name: configfile
          image: opensearchproject/opensearch:3.0.0
          command:
            - sh
            - '-c'
            - |
              #!/usr/bin/env bash
              cp -r /tmp/configfolder/*  /tmp/config/
          resources: {}
          volumeMounts:
            - name: config-emptydir
              mountPath: /tmp/config/
            - name: config
              mountPath: /tmp/configfolder/log4j2.properties
              subPath: log4j2.properties
            - name: config
              mountPath: /tmp/configfolder/opensearch.yml
              subPath: opensearch.yml
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      containers:
        - name: opensearch
          image: opensearchproject/opensearch:3.0.0
          ports:
            - name: http
              containerPort: 9200
              protocol: TCP
            - name: transport
              containerPort: 9300
              protocol: TCP
            - name: metrics
              containerPort: 9600
              protocol: TCP
          env:
            - name: node.name
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
            - name: cluster.initial_master_nodes
              value: master-0,master-1,master-2,
            - name: discovery.seed_hosts
              value: opensearch-cluster-master-headless
            - name: cluster.name
              value: test-cluster
            - name: network.host
              value: 0.0.0.0
            - name: OPENSEARCH_JAVA_OPTS
              value: '-Xmx1024M -Xms1024M'
            - name: node.roles
              value: master,
            - name: DISABLE_INSTALL_DEMO_CONFIG
              value: 'true'
          resources:
            limits:
              cpu: '2'
              memory: 3000Mi
            requests:
              cpu: '1'
              memory: 2000Mi
          volumeMounts:
            - name: master
              mountPath: /usr/share/opensearch/data
            - name: action-groups
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/action_groups.yml
              subPath: action_groups.yml
            - name: security-config
              mountPath: /usr/share/opensearch/config/opensearch-security/config.yml
              subPath: config.yml
            - name: internal-users-config
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/internal_users.yml
              subPath: internal_users.yml
            - name: roles
              mountPath: /usr/share/opensearch/config/opensearch-security/roles.yml
              subPath: roles.yml
            - name: role-mapping
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/roles_mapping.yml
              subPath: roles_mapping.yml
            - name: tenants
              mountPath: /usr/share/opensearch/config/opensearch-security/tenants.yml
              subPath: tenants.yml
            - name: master-tls
              mountPath: /usr/share/opensearch/config/certs
            - name: admin-tls
              mountPath: /usr/share/opensearch/config/admin
            - name: config-emptydir
              mountPath: /usr/share/opensearch/config/log4j2.properties
              subPath: log4j2.properties
            - name: config-emptydir
              mountPath: /usr/share/opensearch/config/opensearch.yml
              subPath: opensearch.yml
          readinessProbe:
            tcpSocket:
              port: 9200
            timeoutSeconds: 3
            periodSeconds: 5
            successThreshold: 1
            failureThreshold: 3
          startupProbe:
            tcpSocket:
              port: 9200
            initialDelaySeconds: 5
            timeoutSeconds: 3
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 30
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            capabilities:
              drop:
                - ALL
            runAsUser: 1000
            runAsNonRoot: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 120
      dnsPolicy: ClusterFirst
      automountServiceAccountToken: false
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 1
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app.kubernetes.io/instance
                      operator: In
                      values:
                        - os-master
                    - key: app.kubernetes.io/name
                      operator: In
                      values:
                        - opensearch
                topologyKey: kubernetes.io/hostname
      schedulerName: default-scheduler
      enableServiceLinks: true
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: master
        creationTimestamp: null
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 8Gi
        storageClassName: local-path
        volumeMode: Filesystem
      status:
        phase: Pending
  serviceName: opensearch-cluster-master-headless
  podManagementPolicy: Parallel
  updateStrategy:
    type: RollingUpdate
  revisionHistoryLimit: 10
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Retain

```

```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: data
  namespace: logging
  uid: 28367f29-9678-42a0-be20-39b2ce424928
  resourceVersion: '89276087'
  generation: 3
  creationTimestamp: '2025-05-29T15:49:23Z'
  labels:
    app.kubernetes.io/component: data
    app.kubernetes.io/instance: os-data
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: opensearch
    app.kubernetes.io/version: 3.0.0
    helm.sh/chart: opensearch-3.0.0
  annotations:
    majorVersion: '3'
    meta.helm.sh/release-name: os-data
    meta.helm.sh/release-namespace: logging
  selfLink: /apis/apps/v1/namespaces/logging/statefulsets/data
status:
  observedGeneration: 3
  replicas: 3
  readyReplicas: 3
  currentReplicas: 3
  updatedReplicas: 3
  currentRevision: data-6697ff9598
  updateRevision: data-6697ff9598
  collisionCount: 0
  availableReplicas: 3
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/instance: os-data
      app.kubernetes.io/name: opensearch
  template:
    metadata:
      name: data
      creationTimestamp: null
      labels:
        app.kubernetes.io/component: data
        app.kubernetes.io/instance: os-data
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: opensearch
        app.kubernetes.io/version: 3.0.0
        helm.sh/chart: opensearch-3.0.0
      annotations:
        configchecksum: 085f142469e84eba84d92f0ef5b91d1cbbd043deedb8debf1f6d93867bcc753
        kubectl.kubernetes.io/restartedAt: '2025-06-01T05:31:24+03:00'
    spec:
      volumes:
        - name: config
          configMap:
            name: data-config
            defaultMode: 420
        - name: config-emptydir
          emptyDir: {}
        - name: master-tls
          secret:
            secretName: master-tls
            defaultMode: 420
        - name: admin-tls
          secret:
            secretName: admin-tls
            defaultMode: 420
        - name: action-groups
          secret:
            secretName: opensearch-action-groups
            defaultMode: 420
        - name: security-config
          secret:
            secretName: opensearch-config
            defaultMode: 420
        - name: internal-users-config
          secret:
            secretName: opensearch-internal-users
            defaultMode: 420
        - name: roles
          secret:
            secretName: opensearch-roles
            defaultMode: 420
        - name: role-mapping
          secret:
            secretName: opensearch-roles-mapping
            defaultMode: 420
        - name: tenants
          secret:
            secretName: opensearch-tenats
            defaultMode: 420
      initContainers:
        - name: fsgroup-volume
          image: busybox:latest
          command:
            - sh
            - '-c'
          args:
            - chown -R 1000:1000 /usr/share/opensearch/data
          resources: {}
          volumeMounts:
            - name: data
              mountPath: /usr/share/opensearch/data
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 0
        - name: configfile
          image: opensearchproject/opensearch:3.0.0
          command:
            - sh
            - '-c'
            - |
              #!/usr/bin/env bash
              cp -r /tmp/configfolder/*  /tmp/config/
          resources: {}
          volumeMounts:
            - name: config-emptydir
              mountPath: /tmp/config/
            - name: config
              mountPath: /tmp/configfolder/log4j2.properties
              subPath: log4j2.properties
            - name: config
              mountPath: /tmp/configfolder/opensearch.yml
              subPath: opensearch.yml
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      containers:
        - name: opensearch
          image: opensearchproject/opensearch:3.0.0
          ports:
            - name: http
              containerPort: 9200
              protocol: TCP
            - name: transport
              containerPort: 9300
              protocol: TCP
            - name: metrics
              containerPort: 9600
              protocol: TCP
          env:
            - name: node.name
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
            - name: discovery.seed_hosts
              value: opensearch-cluster-master-headless
            - name: cluster.name
              value: test-cluster
            - name: network.host
              value: 0.0.0.0
            - name: OPENSEARCH_JAVA_OPTS
              value: '-Xmx3096M -Xms3096M'
            - name: node.roles
              value: data,ingest,
            - name: DISABLE_INSTALL_DEMO_CONFIG
              value: 'true'
          resources:
            limits:
              cpu: '2'
              memory: 6000Mi
            requests:
              cpu: '1'
              memory: 4000Mi
          volumeMounts:
            - name: data
              mountPath: /usr/share/opensearch/data
            - name: action-groups
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/action_groups.yml
              subPath: action_groups.yml
            - name: security-config
              mountPath: /usr/share/opensearch/config/opensearch-security/config.yml
              subPath: config.yml
            - name: internal-users-config
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/internal_users.yml
              subPath: internal_users.yml
            - name: roles
              mountPath: /usr/share/opensearch/config/opensearch-security/roles.yml
              subPath: roles.yml
            - name: role-mapping
              mountPath: >-
                /usr/share/opensearch/config/opensearch-security/roles_mapping.yml
              subPath: roles_mapping.yml
            - name: tenants
              mountPath: /usr/share/opensearch/config/opensearch-security/tenants.yml
              subPath: tenants.yml
            - name: master-tls
              mountPath: /usr/share/opensearch/config/certs
            - name: admin-tls
              mountPath: /usr/share/opensearch/config/admin
            - name: config-emptydir
              mountPath: /usr/share/opensearch/config/log4j2.properties
              subPath: log4j2.properties
            - name: config-emptydir
              mountPath: /usr/share/opensearch/config/opensearch.yml
              subPath: opensearch.yml
          readinessProbe:
            tcpSocket:
              port: 9200
            timeoutSeconds: 3
            periodSeconds: 5
            successThreshold: 1
            failureThreshold: 3
          startupProbe:
            tcpSocket:
              port: 9200
            initialDelaySeconds: 5
            timeoutSeconds: 3
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 30
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            capabilities:
              drop:
                - ALL
            runAsUser: 1000
            runAsNonRoot: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 120
      dnsPolicy: ClusterFirst
      automountServiceAccountToken: false
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 1
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app.kubernetes.io/instance
                      operator: In
                      values:
                        - os-data
                    - key: app.kubernetes.io/name
                      operator: In
                      values:
                        - opensearch
                topologyKey: kubernetes.io/hostname
      schedulerName: default-scheduler
      enableServiceLinks: true
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: data
        creationTimestamp: null
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 8Gi
        storageClassName: local-path
        volumeMode: Filesystem
      status:
        phase: Pending
  serviceName: data-headless
  podManagementPolicy: Parallel
  updateStrategy:
    type: RollingUpdate
  revisionHistoryLimit: 10
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Retain

```

```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: dashboard-5f97888db6
  namespace: logging
  uid: 823295dc-1f6e-4d5d-b230-be71b7fa7a2a
  resourceVersion: '88309250'
  generation: 1
  creationTimestamp: '2025-05-29T18:13:47Z'
  labels:
    app.kubernetes.io/instance: os-dashboard
    app.kubernetes.io/name: opensearch-dashboards
    pod-template-hash: 5f97888db6
  annotations:
    deployment.kubernetes.io/desired-replicas: '1'
    deployment.kubernetes.io/max-replicas: '1'
    deployment.kubernetes.io/revision: '1'
    meta.helm.sh/release-name: os-dashboard
    meta.helm.sh/release-namespace: logging
  ownerReferences:
    - apiVersion: apps/v1
      kind: Deployment
      name: dashboard
      uid: f8eb7b9c-2e55-4f69-8002-daa515b2fbb4
      controller: true
      blockOwnerDeletion: true
  selfLink: /apis/apps/v1/namespaces/logging/replicasets/dashboard-5f97888db6
status:
  replicas: 1
  fullyLabeledReplicas: 1
  readyReplicas: 1
  availableReplicas: 1
  observedGeneration: 1
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: os-dashboard
      app.kubernetes.io/name: opensearch-dashboards
      pod-template-hash: 5f97888db6
  template:
    metadata:
      creationTimestamp: null
      labels:
        app.kubernetes.io/instance: os-dashboard
        app.kubernetes.io/name: opensearch-dashboards
        pod-template-hash: 5f97888db6
      annotations:
        configchecksum: 0d722ea9395912dcc80a09ceb39347bce39cfff6280c392f149494bc73fdb3e
    spec:
      volumes:
        - name: certs
          secret:
            secretName: master-tls
            defaultMode: 420
        - name: config
          configMap:
            name: dashboard-config
            defaultMode: 420
      containers:
        - name: dashboards
          image: opensearchproject/opensearch-dashboards:3.0.0
          ports:
            - name: http
              containerPort: 5601
              protocol: TCP
          envFrom:
            - secretRef:
                name: dashboard-user
          env:
            - name: OPENSEARCH_HOSTS
              value: https://opensearch-cluster-master:9200
            - name: SERVER_HOST
              value: 0.0.0.0
          resources:
            limits:
              cpu: '2'
              memory: 1024M
            requests:
              cpu: '1'
              memory: 512M
          volumeMounts:
            - name: certs
              mountPath: /usr/share/opensearch-dashboards/certs
            - name: config
              mountPath: >-
                /usr/share/opensearch-dashboards/config/opensearch_dashboards.yml
              subPath: opensearch_dashboards.yml
          livenessProbe:
            tcpSocket:
              port: 5601
            initialDelaySeconds: 10
            timeoutSeconds: 5
            periodSeconds: 20
            successThreshold: 1
            failureThreshold: 10
          readinessProbe:
            tcpSocket:
              port: 5601
            initialDelaySeconds: 10
            timeoutSeconds: 5
            periodSeconds: 20
            successThreshold: 1
            failureThreshold: 10
          startupProbe:
            tcpSocket:
              port: 5601
            initialDelaySeconds: 10
            timeoutSeconds: 5
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 20
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            capabilities:
              drop:
                - ALL
            runAsUser: 1000
            runAsNonRoot: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      serviceAccountName: dashboard-dashboards
      serviceAccount: dashboard-dashboards
      securityContext: {}
      schedulerName: default-scheduler

```