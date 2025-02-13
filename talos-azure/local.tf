locals {
  config_patches_common = [
    for path in var.config_patch_files : file(path)
  ]
}