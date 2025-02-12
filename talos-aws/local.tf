locals {
    common_machine_config_patch = {
        machine = {
            kubelet = {
                registerWithFQDN = true
            }
        }
    }

    ccm_patch_cp = {
        cluster = {
            externalCloudProvider = {
                enabled = true
                manifests = fileset("${path.module}/manifests", "*.yaml")
            }
        }
    }

    ccm_patch_worker = {
        cluster = {
            externalCloudProvider = {
                enabled = true
            }
        }
    }

    config_patches_common = [
        for path in var.var.config_patch_files: file(path)
    ]

    config_patches_controlplane = var.ccm ? [yamlencode(local.ccm_patch_cp)]: []

    config_patches_worker = var.ccm ? [yamlencode(local.ccm_patch_worker)]: []

    cluster_required_tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
}