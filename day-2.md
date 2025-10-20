Next, we will install `ingress-nginx`.

First, install the app, defined as a [`Kustomize` overlay](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) in `manifests/test`:

```sh
# clone the repository locally
cd $REPO_PATH/manifests/test
# edit ingress-patch.json and replace $HOST with test.$CP_IP.nip.io, e.g. test.157.180.123.220.nip.io
# check the manifests:
kubectl kustomize . | less
# and apply them:
kubectl apply --server-side -k .
# check the ingress:
kubectl describe ing test
# Name:             test
# Labels:           app=test
# Namespace:        default
# Address:          
# Ingress Class:    nginx
# Default backend:  <default>
# Rules:
#   Host                         Path  Backends
#   ----                         ----  --------
#   test.157.180.123.220.nip.io  
#                                /   test:http (192.168.238.5:8080)
# Annotations:                   <none>
# Events:                        <none>
#
# try to access it:
curl http://test.157.180.123.220.nip.io/
# curl: (7) Failed to connect to test.65.108.246.26.nip.io port 80 after 250 ms: Couldn't connect to server
```

That's expected, as we don't have any ingress controller running in the cluster yet.

## Task 7

Install `ingress-nginx` from the [Helm chart](https://kubernetes.github.io/ingress-nginx/deploy/#quick-start) into a new `ingress-nginx` namespace, using the values from `manifests/helm/ingress-nginx-values.yaml`, with the release name `ingress-nginx`.

> **Warning**
>
> You need to replace $CP_IP in the values file with your control-plane server IP address.

After the `ingress-nginx-controller` pod becomes `Ready`, we should see the ingress updated:

```sh
kubectl describe ing test
# Name:             test
# Labels:           app=test
# Namespace:        default
# Address:          
# Ingress Class:    nginx
# Default backend:  <default>
# Rules:
#   Host                         Path  Backends
#   ----                         ----  --------
#   test.157.180.123.220.nip.io  
#                                /   test:http (192.168.238.5:8080)
# Annotations:                   <none>
# Events:
#   Type    Reason  Age                   From                      Message
#   ----    ------  ----                  ----                      -------
#   Normal  Sync    31s                   nginx-ingress-controller  Scheduled for sync
#
# and we should be able to access it (also from a browser):
curl http://test.157.180.123.220.nip.io/
# <!doctype html>
# [...]
```

Let's now enable TLS for our ingress; in the `manifests/test` folder do the following:

- edit `ingress-patch-tls.json` and replace all `$HOST` occurrences with `test.$CP_IP.nip.io`, where `$CP_IP` is your control-plane server IP;

- edit `kustomization.yaml` and replace `path: ingress-patch.json` with `path: ingress-patch-tls.json`;

- check (`kubectl diff -k .`) and apply (`kubectl apply --server-side -k .`).

If we now refresh the browser, we'll get redirected to the `https://` URL, but we'll get a `NET::ERR_CERT_AUTHORITY_INVALID` (or similar) error. That's because the `test.157.180.123.220.nip.io-tls` secret doesn't exit, so our ingress controller uses uses its default, self-signed certificate.

In order to fix this, let's next install [`cert-manager`](https://cert-manager.io/), which will auto-generate (and renew) valid certificates using [Let's Encrypt](https://letsencrypt.org/).

## Task 8

Install `cert-manager` from the [Helm chart](https://cert-manager.io/docs/installation/helm/) into a new `cert-manager` namespace, using the values from `manifests/helm/cert-manager-values.yaml`.

For now it still won't work, investigate why.

Edit `manifests/clusterissuer.yaml`, replace `$EMAIL` with your email address, and apply it to the cluster.

To force the certificate regeneration, we can delete the certificate:

```sh
kubectl get cert
# NAME                         READY   SECRET                       AGE
# test.157.180.123.220.nip.io-tls   False   test.157.180.123.220.nip.io-tls   7m47s
kubectl delete cert test.157.180.123.220.nip.io-tls
# certificate.cert-manager.io "test.157.180.123.220.nip.io-tls" deleted
#
# wait for the certificate to become ready:
kubectl get cert
# NAME                         READY   SECRET                       AGE
# test.157.180.123.220.nip.io-tls   True    test.157.180.123.220.nip.io-tls   32s
```

Now you if we refresh, we should be able to access the application over HTTPS.

The only thing we still need to have a functional cluster is storage, so let's add that next! We'll use [Rook](https://rook.io/), which is a Kubernetes operator for the distributed storage system [Ceph](https://ceph.io/en/) and a CSI storage plugin.

## Task 9

First, install the `rook-ceph` operator from the [Helm chart](https://rook.io/docs/rook/v1.18/Helm-Charts/operator-chart/#installing) into a new `rook-ceph` namespace, using the values from `manifests/helm/rook-ceph-values.yaml`.

Check that you have a `/dev/sdb` 10GB disk on your control plane node:

```sh
ssh lbogdan-cp-0 lsblk | grep ^sdb
# NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# sdb       8:16   0   10G  0 disk
```

Now edit `manifests/rook-ceph/cephcluster.yaml` and under `nodes` replace `name: $CP_NAME` with your control plane name, e.g. `lbogdan-cp-0` (⚠️VERY IMPORTANT⚠️), apply it, and watch the `rook-ceph-operator` pod's logs and the `rook-ceph` namespace for new pods. Wait until the cluster is `Ready`:

```sh
kubectl -n rook-ceph get cephcluster
# NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
# rook-ceph   /var/lib/rook     1          17m   Ready   Cluster created successfully   HEALTH_OK              a7099633-ace3-4297-a06c-71000d8d782b
```

We can also apply `manifests/rook-ceph/toolbox.yaml`, which will create a debug pod where you can run `ceph` commands on the Ceph cluster:

```sh
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
# cluster:
#   id:     a7099633-ace3-4297-a06c-71000d8d782b
#   health: HEALTH_OK

# services:
#   mon: 1 daemons, quorum a (age 16m)
#   mgr: a(active, since 8m)
#   osd: 1 osds: 1 up (since 8m), 1 in (since 11m)

# data:
#   pools:   2 pools, 33 pgs
#   objects: 4 objects, 577 KiB
#   usage:   28 MiB used, 10 GiB / 10 GiB avail
#   pgs:     33 active+clean
```

Now we'll create a Ceph storage pool and a `StorageClass` that uses it by applying `manifests/rook-ceph/storageclass.yaml`. We should now have an auto-provisioning default `StorageClass`:

```sh
kubectl -n rook-ceph get cephblockpool -o wide
# NAME         PHASE   TYPE         FAILUREDOMAIN   REPLICATION   EC-CODINGCHUNKS   EC-DATACHUNKS   AGE
# ceph-block   Ready   Replicated   osd             1             0                 0               7m25s
#
kubectl get storageclasses
# NAME                   PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
# ceph-block (default)   rook-ceph.rbd.csi.ceph.com   Retain          Immediate           true                   7m51s
```

To test it, comment the `no-volume.json` and `delete-pvc.json` patches in `kustomization.yaml`. Reapply the `test` app and check that the PVC is bound and the pod starts successfully with the volume mounted:

```sh
kubectl get pvc
# NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
# test   Bound    pvc-a5be626b-ad4c-4ce3-8ece-38458f0d01c6   100Mi      RWO            ceph-block     <unset>                 34s
kubectl exec deploy/test -- mount | grep data
# /dev/rbd0 on /data type ext4 (rw,relatime,stripe=64)
#
# write a file:
kubectl exec deploy/test -- dd if=/dev/random of=/data/random.bin bs=1M count=1
# 1+0 records in
# 1+0 records out
```

Check that you can access the file at `https://test.157.180.123.220.nip.io/fs/data/random.bin`.

Restart the pod and check that the file is persisted.

## Task 10

Create an ingress to expose the Ceph dashboard service `rook-ceph/rook-ceph-mgr-dashboard`. To login, see [Login Credentials](https://rook.io/docs/rook/v1.18/Storage-Configuration/Monitoring/ceph-dashboard/?h=dashboard#login-credentials).

## Task 11

Install `kube-prometheus-stack` from the [Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#kube-prometheus-stack) into a new `monitoring` namespace, using the values from `manifests/helm/kube-prometheus-stack-values.yaml`, with the release name `kube-prometheus-stack`.

Edit the `manifests/helm/kube-prometheus-stack-values.yaml` values file to configure the Prometheus metrics retention time to 2 days; the default chart values are in the `manifests/helm/kube-prometheus-stack-values-orig.yaml`;

Edit the values file to enable the ingress for Grafana (don't enable TLS, to not hit the certificate rate-limit issue);

Edit the values file to configure Grafana to use a pre-existing secret containing the admin username and password; manually create the secret before installing the chart;

This will take some time to install, as it creates a lot of resources. Wait for all the pods in the `monitoring` namespace to become `Ready`.

This chart installs three components: [Prometheus](https://prometheus.io/), [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) and [Grafana](https://grafana.com/).

Port-forward the `monitoring/alertmanager-operated` and `monitoring/prometheus-operated` services locally and access them from a browser;

Login into Grafana, using the username and password set in the secret, and browse the available dashboards.

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

Edit the `manifests/helm/argocd-values.yaml` values file to enable the ingress (check `argocd-values-orig.yaml` for all the possible values). Leave TLS disabled, so we don't generate more certificates.

Download the `argocd` CLI binary from [here](https://github.com/argoproj/argo-cd/releases/tag/v2.8.4).

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
cat <<EOT >infra-app.yaml
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
kubectl apply -f infra-app.yaml
```

Go to the UI and sync it.

## Task 18

Define all the components that we installed in the cluster so far in the git repository, and sync them to the cluster.
