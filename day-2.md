Next, we will install `ingress-nginx`.

First, install the app, defined as a [`Kustomize` overlay](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) in `manifests/test`:

```sh
# clone the repository locally
git clone https://github.com/lbogdan/advanced-kubernetes-workshop-2025.git
cd advanced-kubernetes-workshop-2025/manifests/test
# edit ingress-patch.json and replace $HOST with test.$CP_IP.nip.io, e.g. test.157.180.123.220.nip.io
# check the manifests:
kubectl kustomize . | less # or kubectl diff -k .
# and apply them:
kubectl apply -k .
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

- check (`kubectl diff -k .`) and apply (`kubectl apply -k .`).

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
