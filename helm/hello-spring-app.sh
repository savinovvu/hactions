#!/bin/bash

CHART_NAME="hello-spring-app"
IMAGE_NAME="ghcr.io/savinovvu/hactions/hactions:master-f65c048"

# Создаем структуру директорий
mkdir -p ${CHART_NAME}/templates

# Создаем Chart.yaml
cat > ${CHART_NAME}/Chart.yaml << EOF
apiVersion: v2
name: ${CHART_NAME}
description: Spring Boot MVC Application
type: application
version: 0.1.0
appVersion: "1.0.0"

# Зависимости (опционально)
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
EOF

# Создаем values.yaml с Spring Boot конфигурацией
cat > ${CHART_NAME}/values.yaml << 'EOF'
# Default values for hello-spring-app
replicaCount: 2

image:
  repository: ${IMAGE_NAME}
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}
podSecurityContext:
  fsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000

securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

# Spring Boot специфичные настройки
spring:
  app:
    name: "hello-spring-app"
    port: 8080
  profiles: "prod"
  config:
    import: "optional:configserver:"
  cloud:
    kubernetes:
      enabled: false

  datasource:
    url: "jdbc:postgresql://postgresql:5432/mydb"
    username: "appuser"
    driverClassName: "org.postgresql.Driver"

  jpa:
    hibernate:
      ddl-auto: "validate"
    show-sql: "false"

  redis:
    host: "redis-master"
    port: 6379

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  className: "nginx"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
  hosts:
    - host: hello-spring.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1024Mi"
    cpu: "500m"

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# Зависимости
postgresql:
  enabled: false
  auth:
    database: "mydb"
    username: "appuser"
    password: ""

redis:
  enabled: false
  auth:
    password: ""

# Spring Cloud Config Server (опционально)
configserver:
  enabled: false
  url: "http://config-server:8888"

# Actuator endpoints
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics,prometheus"
      base-path: "/actuator"
  endpoint:
    health:
      show-details: "always"
      probes:
        enabled: true

nodeSelector: {}
tolerations: []
affinity: {}
EOF

# Создаем директорию templates
cd ${CHART_NAME}

# Создаем базовые шаблоны
echo "Создание базовых шаблонов..."

# 1. Deployment с Spring Boot конфигурацией
cat > templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "hello-spring-app.fullname" . }}
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "hello-spring-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "hello-spring-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "hello-spring-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.spring.app.port }}
              protocol: TCP
          env:
            - name: SPRING_APPLICATION_NAME
              value: "{{ .Values.spring.app.name }}"
            - name: SPRING_PROFILES_ACTIVE
              value: "{{ .Values.spring.profiles }}"
            - name: SERVER_PORT
              value: "{{ .Values.spring.app.port }}"
            - name: JAVA_OPTS
              value: "-Xmx512m -Xms256m -XX:+UseG1GC"
            {{- if .Values.spring.config.import }}
            - name: SPRING_CONFIG_IMPORT
              value: "{{ .Values.spring.config.import }}"
            {{- end }}
            {{- if .Values.spring.cloud.kubernetes.enabled }}
            - name: SPRING_CLOUD_KUBERNETES_ENABLED
              value: "{{ .Values.spring.cloud.kubernetes.enabled }}"
            {{- end }}
            {{- if .Values.spring.datasource.url }}
            - name: SPRING_DATASOURCE_URL
              value: "{{ .Values.spring.datasource.url }}"
            {{- end }}
            {{- if .Values.spring.datasource.username }}
            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: {{ include "hello-spring-app.fullname" . }}-db-secret
                  key: username
            {{- end }}
            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ include "hello-spring-app.fullname" . }}-db-secret
                  key: password
          livenessProbe:
            httpGet:
              path: {{ .Values.management.endpoints.web.base-path }}/health/liveness
              port: http
            initialDelaySeconds: 60
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: {{ .Values.management.endpoints.web.base-path }}/health/readiness
              port: http
            initialDelaySeconds: 30
            periodSeconds: 5
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: {{ .Values.management.endpoints.web.base-path }}/health/startup
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 30
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: config-volume
              mountPath: /workspace/config
            - name: tmp-volume
              mountPath: /tmp
      volumes:
        - name: config-volume
          configMap:
            name: {{ include "hello-spring-app.fullname" . }}-config
        - name: tmp-volume
          emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF

# 2. Service
cat > templates/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "hello-spring-app.fullname" . }}
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "hello-spring-app.selectorLabels" . | nindent 4 }}
EOF

# 3. Ingress
cat > templates/ingress.yaml << 'EOF'
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "hello-spring-app.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- if $.Values.ingress.pathType }}
            pathType: {{ $.Values.ingress.pathType }}
            {{- else if .pathType }}
            pathType: {{ .pathType }}
            {{- else }}
            pathType: ImplementationSpecific
            {{- end }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

# 4. ConfigMap для Spring Boot
cat > templates/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "hello-spring-app.fullname" . }}-config
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
data:
  application.yaml: |
    server:
      port: {{ .Values.spring.app.port }}
      servlet:
        context-path: /

    spring:
      application:
        name: {{ .Values.spring.app.name }}

      profiles:
        active: {{ .Values.spring.profiles }}

      {{- if .Values.spring.datasource.url }}
      datasource:
        url: {{ .Values.spring.datasource.url }}
        username: ${SPRING_DATASOURCE_USERNAME}
        password: ${SPRING_DATASOURCE_PASSWORD}
        driver-class-name: {{ .Values.spring.datasource.driverClassName }}
        hikari:
          connection-timeout: 30000
          maximum-pool-size: 10
      {{- end }}

      {{- if .Values.spring.jpa.hibernate }}
      jpa:
        hibernate:
          ddl-auto: {{ .Values.spring.jpa.hibernate.ddl-auto }}
        show-sql: {{ .Values.spring.jpa.show-sql }}
        properties:
          hibernate:
            dialect: org.hibernate.dialect.PostgreSQLDialect
            jdbc:
              batch_size: 20
      {{- end }}

      {{- if .Values.spring.redis.host }}
      redis:
        host: {{ .Values.spring.redis.host }}
        port: {{ .Values.spring.redis.port }}
        timeout: 2000ms
      {{- end }}

    management:
      endpoints:
        web:
          exposure:
            include: {{ .Values.management.endpoints.web.exposure.include }}
          base-path: {{ .Values.management.endpoints.web.base-path }}
      endpoint:
        health:
          show-details: {{ .Values.management.endpoint.health.show-details }}
          probes:
            enabled: {{ .Values.management.endpoint.health.probes.enabled }}

    logging:
      level:
        root: INFO
        org.springframework.web: INFO
        com.example: DEBUG
      pattern:
        console: "%d{yyyy-MM-dd HH:mm:ss} - %msg%n"
        file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"

    info:
      app:
        name: {{ .Values.spring.app.name }}
        version: {{ .Chart.AppVersion }}
        description: {{ .Chart.Description }}
EOF

# 5. Secret для базы данных
cat > templates/secret.yaml << 'EOF'
{{- if or .Values.spring.datasource.username .Values.spring.datasource.url }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "hello-spring-app.fullname" . }}-db-secret
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
type: Opaque
data:
  username: {{ .Values.spring.datasource.username | b64enc }}
  password: {{ randAlphaNum 16 | b64enc }}
{{- end }}
EOF

# 6. HPA
cat > templates/hpa.yaml << 'EOF'
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "hello-spring-app.fullname" . }}
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "hello-spring-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
EOF

# 7. ServiceAccount
cat > templates/serviceaccount.yaml << 'EOF'
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "hello-spring-app.serviceAccountName" . }}
  labels:
    {{- include "hello-spring-app.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
EOF

# 8. _helpers.tpl
cat > templates/_helpers.tpl << 'EOF'
{{/*
Expand the name of the chart.
*/}}
{{- define "hello-spring-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hello-spring-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hello-spring-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "hello-spring-app.labels" -}}
helm.sh/chart: {{ include "hello-spring-app.chart" . }}
{{ include "hello-spring-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "hello-spring-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hello-spring-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "hello-spring-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "hello-spring-app.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Generate database URL
*/}}
{{- define "hello-spring-app.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
jdbc:postgresql://{{ .Release.Name }}-postgresql:5432/{{ .Values.postgresql.auth.database }}
{{- else -}}
{{ .Values.spring.datasource.url }}
{{- end -}}
{{- end -}}
EOF

# 9. NOTES.txt
cat > templates/NOTES.txt << 'EOF'
1. Get the application URL by running these commands:
{{- if .Values.ingress.enabled }}
{{- range .Values.ingress.hosts }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ .host }}{{ range .paths }}{{ .path }}{{ end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "hello-spring-app.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch the status by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "hello-spring-app.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "hello-spring-app.fullname" . }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  echo http://$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "hello-spring-app.fullname" . }} -o jsonpath='{.spec.clusterIP}'):{{ .Values.service.port }}
{{- end }}

2. Check the application health:
   kubectl get pods -l app.kubernetes.io/name={{ include "hello-spring-app.name" . }}

3. View logs:
   kubectl logs -f deployment/{{ include "hello-spring-app.fullname" . }}

4. Access Actuator endpoints:
   kubectl port-forward svc/{{ include "hello-spring-app.fullname" . }} 8080:{{ .Values.service.port }}
   Then visit: http://localhost:8080{{ .Values.management.endpoints.web.base-path }}/health

{{- if .Values.postgresql.enabled }}
5. PostgreSQL is enabled. Connection details:
   Host: {{ .Release.Name }}-postgresql
   Database: {{ .Values.postgresql.auth.database }}
   Username: {{ .Values.postgresql.auth.username }}
{{- end }}

{{- if .Values.redis.enabled }}
6. Redis is enabled. Connection details:
   Host: {{ .Release.Name }}-redis-master
   Port: 6379
{{- end }}
EOF

echo "Chart создан в директории: ${CHART_NAME}"
echo "Используйте:"
echo "  helm install my-app ./${CHART_NAME}"
echo "  helm upgrade my-app ./${CHART_NAME}"