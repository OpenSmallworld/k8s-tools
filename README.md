# k8s-tools

Scripts to aid/diagnose GSS on Kubernetes installations.

## Installation

### Initial installation

```bash
git clone https://github.com/OpenSmallworld/k8s-tools.git
git checkout <version> # v524, v523, v522, v521 etc
```

### Update installation

```bash
git pull
```

## Scripts

### bundle.sh

Gather data into a support "bundle" for diagnosing issues.

#### Usage

```bash
git pull # recommended to pull reqularly as there are frequent updates
sudo bash bundle.sh </path/to/pdc_input_manifest.yaml>
```

If you have deployed to a namespace other than gss-prod, then use the ```--namespace <namespace>``` option.

To display all arguments, use the ```--help``` option.

#### Example

```bash
[swadmin@k8s k8s-tools]$ sudo bash bundle.sh /opt/sw/gss-5.2.5/kubernetes_scripts/pdi_input_manifest.yaml 
...............Warning: extensions/v1beta1 Ingress is deprecated in v1.14+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress
....
Generating bundle bundle_20201027_211513Z.tar.gz
tar: Removing leading `/' from member names
-rw-r--r--. 1 root root 4.0M Oct 27 21:15 bundle_20201027_211513Z.tar.gz

Always provide info.txt with any support tickets. bundle_20201027_211513Z.tar.gz is only required when requested.

[swadmin@k8s k8s-tools]$
```
