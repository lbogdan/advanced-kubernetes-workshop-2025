## Task 12

Install [Grafana Loki](https://grafana.com/oss/loki/) from the [Helm chart](https://grafana.com/docs/loki/latest/setup/install/helm/install-monolithic/#install-the-monolithic-helm-chart) into a new `logging` namespace, using the values from `manifests/helm/grafana-loki-values.yaml`, **with the release name `loki`**.

Add the Loki data source in Grafana: go to Connections, search for Loki, click "Add new data source"; the URL is `http://loki-gateway.logging`, and click the "Save & test" button.

## Task 13

Install the [Promtail agent](https://grafana.com/docs/loki/latest/send-data/promtail/) from the [Helm chart](https://grafana.com/docs/loki/latest/send-data/promtail/installation/#install-using-helm) into the `logging` namespace with the default values, with the release name `promtail`.

Wait for the `promtail` pods to start, and check their logs for any errors.

## Task 14

Install [kubernetes-event-exporter](https://github.com/resmoio/kubernetes-event-exporter) from the [Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/kubernetes-event-exporter/) into the `logging` namespace, using the values from `manifests/helm/kubernetes-event-exporter-values.yaml`, with the release name `kubernetes-event-exporter`.

## Task 15

Install [Sealed Secrets](https://sealed-secrets.netlify.app/) from the [Helm chart](https://github.com/bitnami-labs/sealed-secrets#helm-chart) into the `kube-system` namespace, using the values from `manifests/helm/sealed-secrets-values.yaml`, with the release name `kube-seal`.

Download the `kubeseal` CLI binary from [here](https://github.com/bitnami-labs/sealed-secrets/releases). On MacOS, you can install it using `brew install kubeseal`.

Check that it can communicate to the cluster:

```sh
kubeseal --fetch-cert
# -----BEGIN CERTIFICATE-----
# MIIEzDCCArSgAwIBAgIQMYBh8hSC3zWcqqMgSZZ1NDANBgkqhkiG9w0BAQsFADAA
# [...]
# -----END CERTIFICATE-----
```

Now let's create a simple test secret:

```sh
kubectl create secret generic test --from-literal username=root --from-literal password=topsecret --dry-run=client -o yaml >secret.yaml
cat secret.yaml 
# apiVersion: v1
# data:
#   password: dG9wc2VjcmV0
#   username: cm9vdA==
# kind: Secret
# metadata:
#   creationTimestamp: null
#   name: test
```

and encrypt it with `kubeseal`:

```sh
kubeseal -o yaml <secret.yaml >sealedsecret.yaml
cat sealedsecret.yaml 
# apiVersion: bitnami.com/v1alpha1
# kind: SealedSecret
# metadata:
#   creationTimestamp: null
#   name: test
#   namespace: default
# spec:
#   encryptedData:
#     password: AgCHxGLa0XbkekqxX50SYqpqRUgiIwFywpUgXwOXAwH2krcf02Ni5SnwnCpNfN3+RfL6JD9tE3XquZhOWCSTJCW00lnPToYxjk7Qkyke2mf9XFm4QkYqHCEQBzXNXJfBxMDoHNIbdJ6wIOkLoQD0ZrGdJx5m/q8SL6+aWo3I6+Aol+UrmetlrmthgTJy7jDhnKRNPHZ2v3K4UGIQMG8CAI6l+iNwd6nNsXEeJjZ7J3rFO0mM54XDn1/YhvgQmfvoFSORoJe+JPZjwKzc2hvnJ/S+rn0cuNzz1d7mabVyDDsDjkry6F0v/pXwhVdWXC4005vAM9cVTYrDpVeRIdTgYqseadW4yK3ym5zY4LMnuLgF3gZsrXlxBqN/6dOUMooXYYNVlDEdktMPEKsNynJwju7vufoAFQp+kwl2qDHzkYSbjpUkpV1Qp02stlvCMCGKuAADLEHMlseE9lqJtR5RTVCCHa0ImNIf46EFf47EyRlAYXReQTwjwg1oJinqanhWaYUoqm3FZbUqbXhWGArqUJl+ZDEf3DtP+iVjicajNUZPegdgknb0yScjPXOb3hVtVBGu3FF73s1w6mOEkBZKB3rZPmC7Tx+FsYxcxuzfc6NEbdDiAk4evVYdXNaHn34Onuzo45oZ3HTTuLX+tlqXkgojetn8nfi6tYbqbyLTYbFMEcT2Cw3XoLTNSr7uBBnfDsrd/02xT3Az9Dw=
#     username: AgBC6TqbykJdQKzlGWEGZINkFjyarecwZJvlOpYN/nGt3xVNPb3YgAvpPQPJXgw/I1hvgD5W0FzLvf3yRubfk5+3g5iGUNpMcXDjGloQY1UxroTL/LBg8Bp/8TIn3EveHNyDOBCdcdElEiWjVv2KbSO0CjLRZI3N9dhm/+T/C+ikKgyUafgjQlk6kn7A94zjBVnBEYt2JBI80ugYJsepHnpk7NNJgaNJZfiw8d0vVTrkVg1mHJwFMG6BZrDJuIim68NCXss/PQIMK1ZPHVqtC8XItTSLij84hDDiQOoXct+GUNCjAOGdBvq7nzORjiiWV3WiCdgV6O7/XyA5l5sqZjuWyj5YJg66dM3Wuob0zP4k3pUbqK9ffha0vbvoexUWteGoZr6rYo7XPkAznpErNALG/5xS8uuAHQpHUBHn4jRRbzDisI/XiBy8T/583Mai6CjXNDQ6EUjZriiPfizuuNRFBApB34DxffI3G6zVmDNp9UazDPQNd7snwiV1uYuY60N3NMIuhiQJzTVozdCRuI6uzUsKXrBuPkVin/DzIr3pedBUPMPJvdrbANeCSnclDCJOexpDjuKK0g357flzpS/Fs3VnJBK6dKouzhaFxFXbwqFmw+Je2VEtY7jWpZs543tUSaMcGCIL/f0Y/HncTQKi5XLPxomaLjXs374OmzB256fhtw8uNHaOApP3fPfj0UDGn3wB
#   template:
#     metadata:
#       creationTimestamp: null
#       name: test
#       namespace: default
```

Now let's apply it and check that the secret is created:

```sh
kubectl apply -f sealedsecret.yaml
kubectl describe sealedsecret test
# [...]
# Events:
#   Type    Reason    Age   From            Message
#   ----    ------    ----  ----            -------
#   Normal  Unsealed  22s   sealed-secrets  SealedSecret unsealed successfully
kubectl describe secret test
kubectl get secret test
# NAME   TYPE     DATA   AGE
# test   Opaque   2      78s
kubectl get secret test -o jsonpath={.data.password} | base64 -d; echo
# topsecret
```

Lastly, clean up:

```sh
kubectl delete sealedsecret test
# sealedsecret.bitnami.com "test" deleted
kubectl get secret test
# Error from server (NotFound): secrets "test" not found
```

## Task 16

Install [CloudNativePG](https://cloudnative-pg.io/) from the [Helm chart](https://github.com/cloudnative-pg/charts) into a new `cnpg-system` namespace with the default values, with the release name `cnpg`.

Wait for the operator to be ready, and create a test cluster:

```sh
cat <<EOT >test-pg.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: test-pg
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:17.0
  instances: 3
  storage:
    size: 500Mi
EOT
```

Wait for the cluster to start - we created the cluster in the `default` namespace, so we should watch the pods there.

Connect to the database from a test pod (the username and password are stored in the `test-pg-app` secret):

```sh
kubectl run --rm -it pg-client --image ghcr.io/cloudnative-pg/postgresql:17.0 --command -- /bin/sh
# If you don't see a command prompt, try pressing enter.

# $
psql -h $SERVICE_NAME -U $USERNAME
# Password for user app: 
# psql (15.3 (Debian 15.3-1.pgdg110+1))
# SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
# Type "help" for help.

# app=>
CREATE TABLE test (id serial PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL);
# CREATE TABLE
INSERT INTO test (username) VALUES ('admin'), ('user');
# INSERT 0 2
SELECT * FROM test;
#  id | username 
# ----+----------
#   1 | admin
#   2 | user
# (2 rows)
```

Delete the cluster, and check that all the pods (and PVCs) are cleaned up.

```sh
kubectl delete cluster test-pg
# wait a bit
kubectl get pods
# No resources found in default namespace.
kubectl get pvc
# No resources found in default namespace.
```

## Task 17

Install [ArgoCD](https://argoproj.github.io/cd/) from the [Helm chart](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm) in a new `argocd` namespace, with the values from `manifests/helm/argocd-values.yaml`.

Edit the `manifests/helm/argocd-values.yaml` and update `$HOST`. Leave TLS disabled, so we don't generate more certificates.

Download the `argocd` CLI binary from [here](https://github.com/argoproj/argo-cd/releases/tag/v3.1.9).

Login from the CLI (replace `$HOST` with your ingress hostname):

```sh
argocd login --grpc-web --insecure --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) $HOST
# 'admin:login' logged in successfully
# Context 'gitops.157.180.123.220.nip.io' updated
```

Manually create some application resources (make sure to replace `$CP_IP` with your control plane IP address and `$VERSION` with the currently installed Helm chart versions):

```sh
cat <<EOT >metrics-server-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metrics-server
  namespace: argocd
spec:
  destination:
    namespace: kube-system
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: metrics-server
    repoURL: https://kubernetes-sigs.github.io/metrics-server/
    targetRevision: $VERSION
EOT
kubectl apply -f metrics-server-app.yaml
```

```sh
cat <<EOT >ingress-nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-nginx
  namespace: argocd
spec:
  destination:
    namespace: ingress-nginx
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: ingress-nginx
    helm:
      valuesObject:
        controller:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
          extraArgs:
            publish-status-address: $CP_IP
          hostNetwork: true
          kind: DaemonSet
          priorityClassName: system-cluster-critical
          service:
            enabled: false
          tolerations:
          - effect: NoSchedule
            key: node-role.kubernetes.io/control-plane
            operator: Exists
    repoURL: https://kubernetes.github.io/ingress-nginx
    targetRevision: $VERSION
EOT
kubectl apply -f ingress-nginx-app.yaml
```

List the apps:

```sh
kubectl -n argocd get app
# NAME             SYNC STATUS   HEALTH STATUS
# ingress-nginx    OutOfSync     Healthy
# metrics-server   OutOfSync     Healthy
argocd app list
# NAME                   CLUSTER                         NAMESPACE    PROJECT  STATUS     HEALTH   SYNCPOLICY  CONDITIONS  REPO                                               PATH  TARGET
# argocd/ingress-nginx   https://kubernetes.default.svc  ingress-nginx  default  OutOfSync  Healthy  Manual      <none>      https://kubernetes.github.io/ingress-nginx               4.13.3
# argocd/metrics-server  https://kubernetes.default.svc  kube-system  default  OutOfSync  Healthy  Manual      <none>      https://kubernetes-sigs.github.io/metrics-server/        3.13.0
```

They are out of sync, look at the diffs:

```sh
argocd app diff metrics-server
#
# ===== /Service kube-system/metrics-server ======
# 4a5
# >     argocd.argoproj.io/tracking-id: metrics-server:/Service:kube-system/metrics-server
#
# ===== /ServiceAccount kube-system/metrics-server ======
# 4a5
# >     argocd.argoproj.io/tracking-id: metrics-server:/ServiceAccount:kube-system/metrics-server
# [...]
```

Let's sync them:

```sh
argocd app sync metrics-server
# TIMESTAMP                  GROUP                            KIND           NAMESPACE                   NAME                       STATUS    HEALTH        HOOK  MESSAGE
# 2023-10-20T13:16:31+03:00                                Service          kube-system        metrics-server                     OutOfSync  Healthy
# [...]
# Message:            successfully synced (all tasks run)
# [...]
```

List the apps again, they should now be synced:

```sh
kubectl -n argocd get app
# NAME             SYNC STATUS   HEALTH STATUS
# ingress-nginx    Synced        Healthy
# metrics-server   Synced        Healthy
argocd app list
# NAME                   CLUSTER                         NAMESPACE      PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                               PATH  TARGET
# argocd/ingress-nginx   https://kubernetes.default.svc  ingress-nginx  default  Synced  Healthy  Manual      <none>      https://kubernetes.github.io/ingress-nginx               4.13.3
# argocd/metrics-server  https://kubernetes.default.svc  kube-system    default  Synced  Healthy  Manual      <none>      https://kubernetes-sigs.github.io/metrics-server/        3.13.0
```

Now let's version all this inside a git repository.

Create a GitHub (or similar) git repository. Create an `infra` folder at the root, and inside it, three files:

```
infra
  - kustomization.yaml
  - metrics-server-app.yaml
  - ingress-nginx-app-yaml
```

The `kustomization.yaml` contents should be:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- metrics-server-app.yaml
- ingress-nginx-app.yaml
```

Add your repository to ArgoCD (⚠️replace `$GIT_REPO_URL` with your repository URL):

```sh
argocd repo add $GIT_REPO_URL
# Repository 'https://github.com/lbogdan/gitops-test.git' added
```

Now we create an application from that folder (⚠️again, make sure to replace `$GIT_REPO_URL` with your repository):

```sh
cat <<EOT >infra-apps-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra-apps
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    path: infra
    repoURL: $GIT_REPO_URL
EOT
kubectl apply -f infra-apps-app.yaml
```

Go to the UI and sync it.

## Task 18 (Optional)

Define all the components that we installed in the cluster so far in the git repository, and sync them to the cluster.

## Task 19 (Optional)

Install [Kyverno](https://kyverno.io/) from the [Helm chart](https://kyverno.io/docs/installation/methods/#install-kyverno-using-helm) in a new `kyverno` namespace, with the default values.

Let's create an `Audit` policy in the `default` namespace, which doesn't allow to use images with the `latest` tag, or without a tag at all (taken from [here](https://kyverno.io/policies/best-practices/disallow-latest-tag/disallow-latest-tag/):

```sh
kubectl apply -f manifests/policy/disallow-latest-tag-policy.yaml
```

Let's check what happens if we try to create a deployment using an image without a tag. It should work, as the policy is in audit mode, but we'll see the policy validation error in the events:

```sh
kubectl create deployment nginx --image nginx
# deployment.apps/nginx created
kubectl get events
# 6s          Warning   PolicyViolation     policy/disallow-latest-tag    Deployment default/nginx: [autogen-require-image-tag] fail; validation error: An image tag is required. rule autogen-require-image-tag failed at path /spec/template/spec/containers/0/image/
# 6s          Warning   PolicyViolation     policy/disallow-latest-tag    Pod default/nginx-77b4fdf86c-k9g8b: [require-image-tag] fail; validation error: An image tag is required. rule require-image-tag failed at path /spec/containers/0/image/
# [...]
```

Now let's delete the deployment, switch the policy to `Enforce` mode, and create the deployment again. This time we should get a policy validation error, and the deployment will not be created:

```sh
kubectl delete deployment nginx
# deployment.apps "nginx" deleted
kubectl patch --type merge policy disallow-latest-tag --patch '{"spec":{"validationFailureAction":"Enforce"}}'
# policy.kyverno.io/disallow-latest-tag patched
kubectl create deployment nginx --image nginx
# error: failed to create deployment: admission webhook "validate.kyverno.svc-fail" denied the request: 
#
# resource Deployment/default/nginx was blocked due to the following policies 
#
# disallow-latest-tag:
#   autogen-require-image-tag: 'validation error: An image tag is required. rule autogen-require-image-tag
#     failed at path /spec/template/spec/containers/0/image/'
kubectl get deployment nginx
# Error from server (NotFound): deployments.apps "nginx" not found
```

Delete the Kyverno policy, and do the same with the `ValidatingAdmissionPolicy` in `manifests/policy/validatingadmissionpolicy`.

## Task 20

Clone the `example-app`[https://github.com/lbogdan/example-app/] repository locally.

Deploy the Helm chart in the `helm` folder to a new `app-staging` namespace, with a release name of `example-app`. Set environment to `staging`.

Expose it through ingress (with or without TLS). Check that you can access `/hash/test`, `/counter/1` and `/counter/1/inc` endpoints.

Restart (delete) the pod. Check what happens to the `/counter/1/inc` requests.

Scale the app to two replicas. Check what happens to the `/counter/1/inc` requests.

## Task 21

Enable PostgreSQL by setting `config.dbType: postgresql` and `postgresql.enabled: true`. Check what happens to the `/counter/1/inc` requests.

## Task 22

Check if you can connect to the database from a different pod.

Enable network policy.

Check that the `/counter/1/inc` endpoint still works.

Check again if you can connect to the database from a different pod.

## Task 23

Experiment with the readiness probe by setting the `ASYNC_QUEUE` environment variable to `0` and increase `config.rounds` to 20.

## Task 24

Experiment with [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/).

```sh
# validate
kubectl label --dry-run=server --overwrite ns app-staging pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "app-staging" violate the new PodSecurity enforce level "restricted:latest"
# Warning: example-app-f5b96b955-p8mj6: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
# namespace/app-staging labeled (server dry run)
#
# apply
kubectl label --overwrite ns app-staging pod-security.kubernetes.io/enforce=restricted
# [...]
# namespace/app-staging labeled
```

Delete the pod. What happens? Why?

Enable security in `example-app` values and redeploy. What happens? Why?

Use the image tag `v0.0.27`.

## Task 25

Experiment with the [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).

## Task 26

Disable PostgreSQL, create a CloudNativePG cluster and configure it in `example-app` values `externalPostgresql`.

## Task 27

Update the Helm chart to support providing sealed secrets instead of secrets.

## Task 28

Deploy `example-app` in a new `app-dev` namespace and experiment with [Okteto](https://www.okteto.com/). Make a change, commit, add a release tag, push. Deploy it to staging after the image is built and pushed.

## Task 29

Add the staging app, and create a new production app, in ArgoCD.
