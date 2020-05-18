# k8s-tools

Scripts to aid/diagnose GSS on Kubernetes installations.

## Installation

```bash
git clone https://github.com/OpenSmallworld/k8s-tools.git
git checkout <version> # v523, v522, v521 etc
```

## Scripts

### bundle.sh

Gather data into a support "bundle" for diagnosing issues.

#### Usage

```bash
 bash bundle.sh </path/to/pdc_input_manifest.yaml>
```

#### Example

```bash
[root@k8s k8s-tools]# bash bundle.sh /opt/sw/kubernetes_scripts/pdc_input_manifest.yaml
..................
Generating bundle bundle_20200515_213409Z.tar.gz
tar: Removing leading `/' from member names
-rw-r--r--. 1 root root 2.5M May 15 22:34 bundle_20200515_213409Z.tar.gz

Please provide bundle_20200515_213409Z.tar.gz with any support tickets.
[root@k8s k8s-tools]#
```
