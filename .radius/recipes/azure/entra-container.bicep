param context object
param identityClientId string
param tenantId string
param serviceAccountName string = 'mtbbikeshop'

extension kubernetes with {
  kubeConfig: ''
  namespace: context.runtime.kubernetes.namespace
} as kubernetes

var namespace = context.runtime.kubernetes.namespace
var name = toLower(context.resource.name)
var workload = context.resource.properties.containers.radiusDemo
var labels = {
  'radapp.io/resource': context.resource.name
  'radapp.io/application': context.application.name
}

resource serviceAccount 'core/ServiceAccount@v1' = {
  metadata: {
    name: serviceAccountName
    namespace: namespace
    annotations: {
      'azure.workload.identity/client-id': identityClientId
      'azure.workload.identity/tenant-id': tenantId
    }
    labels: labels
  }
  automountServiceAccountToken: false
}

resource deployment 'apps/Deployment@v1' = {
  metadata: {
    name: name
    namespace: namespace
    labels: labels
  }
  spec: {
    replicas: 1
    selector: {
      matchLabels: {
        'radapp.io/resource': context.resource.name
      }
    }
    template: {
      metadata: {
        labels: union(labels, {
          'azure.workload.identity/use': 'true'
        })
      }
      spec: {
        serviceAccountName: serviceAccount.metadata.name
        automountServiceAccountToken: false
        enableServiceLinks: false
        securityContext: {
          runAsNonRoot: true
          runAsUser: 1654
          runAsGroup: 1654
          seccompProfile: {
            type: 'RuntimeDefault'
          }
        }
        containers: [
          {
            name: 'radiusdemo'
            image: workload.image
            env: [for entry in items(workload.env): {
              name: entry.key
              value: entry.value.value
            }]
            ports: [
              {
                name: 'web'
                containerPort: workload.ports.web.containerPort
              }
            ]
            securityContext: {
              allowPrivilegeEscalation: false
              capabilities: {
                drop: [
                  'ALL'
                ]
              }
            }
            resources: {
              requests: {
                cpu: '100m'
                memory: '256Mi'
              }
              limits: {
                cpu: '500m'
                memory: '512Mi'
              }
            }
            readinessProbe: {
              tcpSocket: {
                port: workload.ports.web.containerPort
              }
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          }
        ]
      }
    }
  }
}

resource service 'core/Service@v1' = {
  metadata: {
    name: '${name}-radiusdemo'
    namespace: namespace
    labels: labels
  }
  spec: {
    type: 'ClusterIP'
    selector: {
      'radapp.io/resource': context.resource.name
    }
    ports: [
      {
        name: 'web'
        port: 8080
        targetPort: workload.ports.web.containerPort
      }
    ]
  }
}

output result object = {
  resources: [
    '/planes/kubernetes/local/namespaces/${namespace}/providers/core/ServiceAccount/${serviceAccount.metadata.name}'
    '/planes/kubernetes/local/namespaces/${namespace}/providers/apps/Deployment/${deployment.metadata.name}'
    '/planes/kubernetes/local/namespaces/${namespace}/providers/core/Service/${service.metadata.name}'
  ]
  values: {
    hosts: {
      radiusDemo: '${service.metadata.name}.${namespace}'
    }
  }
}
