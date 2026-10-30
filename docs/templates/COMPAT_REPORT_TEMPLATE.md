# Runner Compatibility Report

Rule: a row may say PASS only if it is backed by a file in the downloaded artifact. Otherwise write NOT RUN or UNKNOWN. Do not copy results from another runner or from documentation.

| Field | Value |
|---|---|
| Date (UTC) | |
| Workflow run URL | |
| Target probed | github-hosted-free / self-hosted / paid-larger-16core |
| Repo visibility (public/private) | |
| Artifact name | |
| `runner_environment` (probe.json) | |
| Completed by | |

## 1. Machine facts (probe.json / probe.txt)
| Item | Observed | AOSP documented minimum | Meets? |
|---|---|---|---|
| Architecture | | x86_64 | |
| CPU cores | | no hard minimum (more = faster) | n/a |
| RAM (GB, MemTotal) | | 64 (probe threshold 60 for VM overhead) | |
| Free disk (GB) at workspace | | 400 | |
| Swap (GB) | | n/a | n/a |
| Kernel | | n/a | n/a |

## 2. Virtualization (probe.json, cuttlefish-compat.json)
| Check | Result (PASS/FAIL/WARN/NOT RUN) | Evidence file |
|---|---|---|
| CPU vmx/svm flag visible | | probe.json `cpu_virt_flag_cpus` |
| /dev/kvm present | | probe.json `dev_kvm` |
| /dev/kvm rw BEFORE udev rule | | probe.json `dev_kvm_rw` |
| /dev/kvm rw AFTER udev rule | | cuttlefish-compat.txt `kvm-access` |
| Nested param | | probe.json `kvm_nested_param` |
| vhost_vsock available | | cuttlefish-compat.txt |
| vhost_net available | | cuttlefish-compat.txt |

## 3. Dependencies (deps.txt)
Missing packages: 
Notes (package renames on this Ubuntu release?): 

## 4. Cuttlefish
| Stage | Status | Evidence |
|---|---|---|
| Environment readiness (`check`) | ENVIRONMENT_READY / ENVIRONMENT_NOT_READY | cuttlefish-compat.json `overall` |
| Host package installed | NOT RUN | |
| Boot test (`boot`) | NOT RUN until images exist | fingerprint.txt + getprop.txt + logcat-tail.txt |

`ENVIRONMENT_READY` means only that the prerequisites we check are present. It does **not** mean Cuttlefish boots.

## 5. Conclusion (facts only)
- Can this runner build AOSP (RAM/disk minimums met)? 
- Is it a candidate for Cuttlefish boot testing? 
- Open questions / next probe: 
