# k8s-tools

Scripts to aid/diagnose GSS on Kubernetes installations.

## Installation

### Initial installation

```bash
git clone https://github.com/OpenSmallworld/k8s-tools.git 
# or if you want a specific version
git clone --branch <version> https://github.com/OpenSmallworld/k8s-tools.git # for example v526
# list available branches/versions
git branch -A 
# checkout alternate version
git checkout <version>
```

### Update installation

```bash
git pull
```

You are recommended to use ```git pull``` frequently as there are regular updates, indicated by the VERSION ID.

If you find that a ```git pull``` does not update, please delete and re-clone. The default branch may have changed.

## Scripts

### bundle.sh

Gather data into a support "bundle" for diagnosing issues.

#### Usage

**Note**: It is important to run the bundle script from the deployment node, or a node which has docker and Kubernetes installed.

In general, later versions of the script are backwards compatible with earlier versions, i.e. v526 can be used with GSS 5.2.2.
The exception to this is v521/GSS 5.2.1.

```bash
git pull # recommended
sudo bash bundle.sh </path/to/pdc_input_manifest.yaml>
```

If you have deployed to a namespace other than gss-prod, then use the ```--namespace <namespace>``` or ```-n <namespace>``` option.

To avoid creating the bundled tar archive, use the ```--no-bundle``` or ```-z``` option.

To display execution progress, use the ```--debug``` or ```-D``` option.

For AWS or restricted shells where root access is not permitted, use the ```--non-root``` or ```-N``` option. This may cause some information to not be captured as well as errors while running!

If ```KUBECONFIG``` is not defined, you can point to an alternative file using the ```--kubeconfig </path/to/kubeconfig>``` or ```-k </path/to/kubeconfig>``` option.

If a pod has restarted and you want to include the logs fronm the previous instance, use the ```--include-previous``` or ```--p``` option.

If you need to restrict the log output, you can use the ```--since``` or ```-s``` option. Valid units are ```h```,```m```,```s```. Examples of this are:

```bash
--since=30m # last 30 minutes
--since=3h # last 3 hours
-s 72h # last 3 days
```

To display all options, use the ```--help``` option.

#### Example

You should expect to see a simple ```...................``` as output. If you see a warning (shown below), these can be ignored. If you see errors, including those mentioning port numbers, then you have either run as the wrong user, there is a problem with your KUBECONFIG environment variable or an error with the script. **Please include any errors with the case**.

```bash
[swadmin@k8s k8s-tools]$ git pull # recommended
[swadmin@k8s k8s-tools]$ sudo bash bundle.sh /opt/sw/gss-5.2.5/kubernetes_scripts/pdi_input_manifest.yaml 
...............Warning: extensions/v1beta1 Ingress is deprecated in v1.14+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress
....
Generating bundle bundle_20201027_211513Z.tar.gz
tar: Removing leading `/' from member names
-rw-r--r--. 1 root root 4.0M Oct 27 21:15 bundle_20201027_211513Z.tar.gz

Always provide info.txt with any support tickets. bundle_20201027_211513Z.tar.gz is only required when requested.

[swadmin@k8s k8s-tools]$
```
