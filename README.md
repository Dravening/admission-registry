# admission-registry
实现准入控制功能，基础知识请参考[编写一个k8s的webhook来实现deployment的拦截](https://cloud.tencent.com/developer/article/1964242)

### 组件构成

##### 1.deploy.yaml

这是主要的deployment文件，除相应的ServiceAccount等常规内容外，可以看到主要的deployment任务中包含一个container和一个initContainer；显然，这个initContainer用来生成certs文件，并挂载给Container容器，给它赋访问api-server的权限。

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admission-registry-sa

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admission-registry-clusterrole
rules:
- verbs: ["*"]
  resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  apiGroups: ["admissionregistration.k8s.io"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admission-registry-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admission-registry-clusterrole
subjects:
  - kind: ServiceAccount
    name: admission-registry-sa
    namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admission-registry
  labels:
    app: admission-registry
spec:
  selector:
    matchLabels:
      app: admission-registry
  template:
    metadata:
      labels:
        app: admission-registry
    spec:
      serviceAccountName: admission-registry-sa
      initContainers:
      - name: webhook-init
        image: registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry-tls:v1.0
        imagePullPolicy: IfNotPresent
        env:
        - name: WEBHOOK_NAMESPACE
          value: default
        - name: WEBHOOK_SERVICE
          value: admission-registry
        - name: VALIDATE_CONFIG
          value: admission-registry
        - name: VALIDATE_PATH
          value: /validate
        - name: MUTATE_CONFIG
          value: admission-registry-mutate
        - name: MUTATE_PATH
          value: /mutate
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/webhook/certs
      containers:
      - name: webhook
        image: registry.cn-hangzhou.aliyuncs.com/draven_yyz/admission-registry:v1.0
        imagePullPolicy: IfNotPresent
        env:
        - name: WHITELIST_REGISTRIES
          value: "docker.io,gcr.io"
        ports:
        - containerPort: 443
        volumeMounts:
        - name: webhook-certs
          mountPath: /etc/webhook/certs
          readOnly: true
      volumes:
      - name: webhook-certs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: admission-registry
  labels:
    app: admission-registry
spec:
  ports:
    - port: 443
      targetPort: 443
  selector:
    app: admission-registry
```

##### 2.validating-webhook-config.yaml

注册一个ValidatingWebhookConfiguration类型的实例，实例名叫admission-registry；rules限制生效条件是“所有api创建pod时”应用此准入控制；clientConfig生效行为是访问admission-registry.default.svc服务的80端口的/validate路径。sideEffects表示webhook是否存在副作用，主要针对 dryRun 的请求

```
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: admission-registry
webhooks:
  - name: io.ydzs.admission-registry
    rules:
      - apiGroups:   [""]
        apiVersions: ["v1"]
        operations:  ["CREATE"]
        resources:   ["pods"]
    clientConfig:
      service:
        namespace: default
        name: admission-registry
        path: "/validate"
        port: 80
      caBundle: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR2akNDQXFhZ0F3SUJBZ0lVTk0xR2l6d1JhL2pUcDd3NDFqWnY4Qm84THFzd0RRWUpLb1pJaHZjTkFRRUwKQlFBd1pURUxNQWtHQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFVcHBibWN4RURBT0JnTlZCQWNUQjBKbAphVXBwYm1jeEREQUtCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByCmRXSmxjbTVsZEdWek1CNFhEVEl6TURNd01qQXlNVFF3TUZvWERUSTRNREl5T1RBeU1UUXdNRm93WlRFTE1Ba0cKQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFVcHBibWN4RURBT0JnTlZCQWNUQjBKbGFVcHBibWN4RERBSwpCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByZFdKbGNtNWxkR1Z6Ck1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBMHRpNFFoamJaVVc3SVNxaDB5R1UKbUdyclR3U3owUXdzRFBEUEpRY3pEQkRXNThUT2hvU010STAwakh3d0VDM3hVR29iNnRORXlrdmhkcmxiUitjSwpSeFNQbmw4bVZMblpRcUhuSDAzd0pwOEZoNnZVdVU3dDk2R01vTjZtdzRBTGlZT3pEV3lmVHpDUDVIOW9rRjRhCnQyb2pMcTRYMnQ0KzlmRzFXdlg4NnJsTEo3cFJLUGZKVERVazVVRlB2L1UrT1VMdExUbVZhc0pReG80aUxnd3gKYWQrOFdwY3Y5b0hHR0d1Y2VXLzZteEtQOUtUZFZ4OXRxUUpxdmNERy9HWE1pTngvbzA0Q3FKM1NvTW5UTWVIZApNY2YxVFIrNER6Y3FSekx6d21pMGhlQ01PeHFvcENqcXphekwrUDZ3Q01RNWowTytPbGMzemJnbzNLaFRqMEYrCmhRSURBUUFCbzJZd1pEQU9CZ05WSFE4QkFmOEVCQU1DQVFZd0VnWURWUjBUQVFIL0JBZ3dCZ0VCL3dJQkFqQWQKQmdOVkhRNEVGZ1FVWmVqL3lhTVFoWUZaOHZ5NjE2Q09PWE5JdGhjd0h3WURWUjBqQkJnd0ZvQVVaZWoveWFNUQpoWUZaOHZ5NjE2Q09PWE5JdGhjd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFDZnZSdVgzQlB5YTN1TDZNN1Z4CjVrV3Y5TXlrdG9ZQmhQYmNoNFhRSFI5V2lUc2xuSjBoekd0WEtFbmZiUkQ4VU1VeHRNVGFzZVZnVU10ekdEc1QKS0VqeWVoVlcvNTAwcmlSSzNvVVd2Q3B6SUsvTUlzc3hSVU1mZlhsZnZMcnFKdCtpQ2ROUlVPMWhFUWF1MlcvTwp3V3RIZTBRWjNtOEtNVHJya3dRMzl2bGhjMUVuMFNTSmx4SnJYRjhxUHdlQXhjZ1lTVVhxdkxxOVdOR3Y3dEEyCmd4bFBmQ1VhdjVYZUhMY0wrelFHNURQbXI5RWJESWJlSVppRWNVZnJrYTF3ZVdZNEsvaXJvT3FiQzJScjRNaDYKNUVLcU9ZRjdhQXhwN1hyYmZiWjV6eUloS0R5Q2Jtb3l6VlFrNXFJUkRGTGJHdVYyemV1TmltS0FCbGVqYyszawprNTg9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    admissionReviewVersions: ["v1"]
    sideEffects: None
```

##### 3.admission-registry-tls.yaml（这个可以没有，可以由initContainer动态生成）

这是一个secret文件

```
[root@cosmo-ai01 draven]# cat admission-registry-tls.yaml
apiVersion: v1
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVBekNDQXV1Z0F3SUJBZ0lVVS9iQkZUNTdCVG5valVDZk1XWmpmc1Y1Y0Vzd0RRWUpLb1pJaHZjTkFRRUwKQlFBd1pURUxNQWtHQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFVcHBibWN4RURBT0JnTlZCQWNUQjBKbAphVXBwYm1jeEREQUtCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByCmRXSmxjbTVsZEdWek1CNFhEVEl6TURNd01qQXlNVFV3TUZvWERUSTBNRE13TVRBeU1UVXdNRm93WkRFTE1Ba0cKQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFVcHBibWN4RURBT0JnTlZCQWNUQjBKbGFVcHBibWN4RERBSwpCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUkl3RUFZRFZRUURFd2xoWkcxcGMzTnBiMjR3CmdnRWlNQTBHQ1NxR1NJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUURTWUhDckV5ZG9aenJDY1hyLzBjN1QKaWpCTHlFdTdVQ0NXaVdNTm9LdXNuYTdidi9PaU1yYjZmSnJCUklUdXk0QjZBemYrejRrcHhNcnhmSzczdUVqbQprcWpYblh1bnBldlpUM3BkOTU0NzZ6TjRXbDlSNGxiYTlYcEpiZnNoUExGbTlpdVdDRkVlSnQxWHFYVEdDU2phCkh3REpEWjV4WUdwdlo4ZTR4Ri85WTFCVDFnWXpjK1VTSTQ4L0FvWG5JbEpqRHNxZGFWUlZ4YzNQZ1MzMW1XUWkKZkt5T3FUTXNaUXFvcWlkYisrK3dhbTVQMXF1emlnRTZoeU9KZ0NzdVJ5Q2tUV0paYjZBcEdtSEIrOHBpRmJYcgpjQkk4ZVJSZUFkc2M4Z0p6eWFLTU9sTy9lTlJ2RnRDM3pJSFp5ditVQlgvQ21VMm4yNmIxcys5N3RFVlhlTEhUCkFnTUJBQUdqZ2Fzd2dhZ3dEZ1lEVlIwUEFRSC9CQVFEQWdXZ01CMEdBMVVkSlFRV01CUUdDQ3NHQVFVRkJ3TUIKQmdnckJnRUZCUWNEQWpBTUJnTlZIUk1CQWY4RUFqQUFNQjBHQTFVZERnUVdCQlJUOGhzbGxjbGt0R0ZCNDgxdgpkUmlBZXZLWExUQWZCZ05WSFNNRUdEQVdnQlJsNlAvSm94Q0ZnVm55L0xyWG9JNDVjMGkyRnpBcEJnTlZIUkVFCklqQWdnaDVoWkcxcGMzTnBiMjR0Y21WbmFYTjBjbmt1WkdWbVlYVnNkQzV6ZG1Nd0RRWUpLb1pJaHZjTkFRRUwKQlFBRGdnRUJBQnhrYlZtL2FSamhIOTlTZ2Q3d3pBdHFvR3p2VEs5ZzBudldBR2V5MmRpcUFEUldxK0hyNjJpRApvSjRqUm9aUStEbFUvNjU4MzM3QVBFRUVjblhrTjhvSGlZaDljNFlxMzVXVEZZVW10TkwzdXZITlAvd0ZoNVhICmYyTEM3aFRUaDRzK1JERmNCcWduUjVRcVVvQ0dyV0VKaTdLQlFpZlUxc3FFMXF0Nmo0a3dIaWtodFNpV01Za2wKZVRBZklKNHIwdUFoNnJHa25HajZvRXlMNUhEUmdEQklJaUp2RlNWaG1TZjh0djdOWk5nT25xVW5kTmJFeWdtSwo0WGxBVjMvWTJhZ1Y1QmYwRFBJdkJiQ0dxdWM0ZGJTSUN4M1RhcXVnclpoM2ltOFdORWd6amVib3VxZEhUWEhYCmpmSlR3K21ka21PSVdyT3d2aDhVTTI0RGhRbTdQMWc9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
  tls.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcFFJQkFBS0NBUUVBMG1Cd3F4TW5hR2M2d25GNi85SE8wNG93UzhoTHUxQWdsb2xqRGFDcnJKMnUyNy96Cm9qSzIrbnlhd1VTRTdzdUFlZ00zL3MrSktjVEs4WHl1OTdoSTVwS28xNTE3cDZYcjJVOTZYZmVlTytzemVGcGYKVWVKVzJ2VjZTVzM3SVR5eFp2WXJsZ2hSSGliZFY2bDB4Z2tvMmg4QXlRMmVjV0JxYjJmSHVNUmYvV05RVTlZRwpNM1BsRWlPUFB3S0Y1eUpTWXc3S25XbFVWY1hOejRFdDlabGtJbnlzanFrekxHVUtxS29uVy92dnNHcHVUOWFyCnM0b0JPb2NqaVlBckxrY2dwRTFpV1crZ0tScGh3ZnZLWWhXMTYzQVNQSGtVWGdIYkhQSUNjOG1pakRwVHYzalUKYnhiUXQ4eUIyY3IvbEFWL3dwbE5wOXVtOWJQdmU3UkZWM2l4MHdJREFRQUJBb0lCQUhOYVhBMEI2S2JQaTZHWQpsY2YxNUFHTUVTVk1nM0lHNG9lSWQ1NitUY1BOaGxhS0x1M3QvdlRrSS9yN05pUzF3eEdqK0MwbzROM2RRU1llCnB0Vy8zNEZHUTN4T3BzSHJNYUlyZVQ1VEN4bHh3dndvR1lJTnFIQlJENmQ1dmF5ZzJlbEo2K1pOVXlWRVREUEgKLy9haWlScm95d1p6Q0VERWpEZmY0TnhJR1JZWFFvM1h3RHNQNnRyRWFGTFovY3g1bXE0a2JKOWVHdXBhem5HOQptUTNBeHA0YzlkM05QWlVlTDE2eGgxRlBWUVdXcjRZMEF3c3dIaVQvalIxeXFhS3lxdkd4WkQycWZuWkhWZVJMCkY4NHZVZ0x5V01TMGp6VXZmRVo0RzA3ZmNrME5JYnFDSEJSRFdIb3VRZGhOOUEwTStkUk9zMG5wTlR0bW1OcysKZTBwVDU1a0NnWUVBK1IzZXZFdnFVRGs2Ui9VTUlJSWhBQUJ1M2RTMmd5WDM3cXNIdkFTMHJ5WjRaMVVoR0R6NApwdVdSRWVWdE45TDVjbjU2QWxnYWR1cjhCVE5aTTRpRHMyaEw5cHJsUXp2eGw4R0Y1MFhqdlhYMEhrWWZFQzNzClFrL2pvVVpsSFlRY0k1ZXl6UEEwVU1uKzFWRUdQaGlXcm90T0NyS0NDbUd2cG5TTWNQRXZmTjhDZ1lFQTJEQ0sKM2svNVROajVOdExWU1Uwb2ljYWxBWW1mOFpjbGd5QVY4aTFaUUthV3lENVJkaXRma0NVejlKUjdEYjY5TlpubAo0NDhCUjdqYisxOUFTUTdHbGMySUhVUWxOMFZNYjZ3bCsrUjRkODRnRUJneC9wY1hrdldzb2hXQUp2M2dzRHVVClVHS3ZYM0NaK2FBNnNNNE9lVFltZjJML3E2SkppdTdXekR5aGRZMENnWUVBbWt6dkZuQnJMTStWa3Rac2NZSkkKa0dpMFF3Q3JINmFYNENQZGdZN2tuNHhUamFXRC96QmN6M3RvRk02bmpLbEh5cXdlUkc5dnpQS1ZzVjd4eEdLdApPS1hFVDNYM3hXSk9yVEc0RDkwUlI5dlVuaC9PdzhXK0RnRFB2S2dPbjI2aHcwWUdBTHhUbXlyU2hpeE9rbzNHClgweDN4VloyQjVva0l4VVRuQzAzdmI4Q2dZRUFtYWwzS3lrQTgrUk16dkR3ZE5lSTl0VGd0OFVRa0hGMFVrMWUKQy9LN3U3NHM4a3VKTDBzSTg3WGR4Znc3c3J0ZVZWajhFOUN6Z2owYzd3RDIrbmFzSkJJZ3ExeWlielNzYmJ1WQpqQUFLdUcwa1VReEJqTW5zRWFMWmY2TjBvVUpXa0N6bzhISVVZT3Z5SllJRDlXT2cyZnJwUmlZaHYrYnNDdnBVClpucTU4SWtDZ1lFQTBWNkgyaEU2eW9tMXB0aGZyZGYvVjBlUk9qNVc2dVpkcmRSN2tmYjVGRWU3ZVVZUkYwZ2QKYnR1KzJjaHo3a0VXMUNJVitSaG9ma0dNcjRCbHdhSVl5aEtpSTR5eW9VTjRHaVhlaDFIeEphbGw3YkhTaWlNSgp5aUhqeEpMb290cWtiMlcvTWZTc21nbTBHbWVXQ0ZKcUJzZ3orL1lUY2MvRksrWVhubWx3NTBrPQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQo=
kind: Secret
metadata:
  name: admission-registry-tls
  namespace: default
type: kubernetes.io/tls
```

### 执行逻辑

##### 用户操作

1.注册一个ValidatingWebhookConfiguration类型的实例，实例名叫admission-registry

```
kubectl apply -f validating-webhook-config.yaml
```

2.拉起一个可以处理准入逻辑的pod

```
kubectl apply -f deploy.yaml
```

##### k8s行为

用户执行上述步骤后，k8s的api-server会在接到任务时，访问相应的ValidatingWebhookConfiguration获取验证服务地址，即`admission-registry.default.svc:80/validate`，并向此地址发送请求如下

```
curl -X POST \
  http://admission-registry.default.svc:80/validate \
  -H 'content-type: application/json' \
  -d '{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "request": {
    ...
  }
}'
```

> 注意：validate/mutate请求的数据kind都是 AdmissionReview，这意味着服务要通过请求的路径（即/validate）自行区分逻辑

应收到服务的返回json如下

```
{
    "kind": "AdmissionReview",
    "apiVersion": "admission.k8s.io/v1",
    "response": {
        "uid": "b955fb34-0135-4e78-908e-eeb2f874933f",   # 等于request中的uid
        "allowed": true,                                 # 代表准入控制已通过
        "status": {
            "metadata": {},
            "code": 200
        },                                               # patch代表需要使用patch更新的对象
        "patch": "W3sib3AiOiJyZXBsYWNlIiwicGF0aCI6Ii9zcGVjL3JlcGxpY2FzIiwidmFsdWUiOjJ9XQ==",
        "patchType": "JSONPatch"
    }
}
```

```
$ echo "W3sib3AiOiJyZXBsYWNlIiwicGF0aCI6Ii9zcGVjL3JlcGxpY2FzIiwidmFsdWUiOjJ9XQ==" | base64 -d
[
    {
        "op": "replace",
        "path": "/spec/replicas",
        "value": 2                                        # 显然，本次mutate修改了相应资源的replicas为2
    }
]
```

即相当于k8s接收到了patch命令
