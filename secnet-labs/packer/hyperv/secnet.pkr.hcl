packer {
  required_plugins {
    hyperv = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/hyperv"
    }
    vagrant = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "hyperv-iso" "secnet" {
  iso_url             = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
  iso_checksum        = "file:https://releases.ubuntu.com/26.04/SHA256SUMS"
  iso_target_path     = "./iso_cache/ubuntu-26.04.iso"
  vm_name             = "secnet-base-box"
  memory              = 4096
  cpus                = 2
  generation          = 2
  enable_secure_boot  = false
  switch_name         = "Default Switch"

  boot_wait           = "15s"
  boot_command        = [
    "c",
    "<wait2s>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ip=dhcp",
    "<enter><wait2s>",
    "initrd /casper/initrd",
    "<enter><wait2s>",
    "boot<enter>"
  ]

  http_directory      = "http"
  http_bind_address   = "0.0.0.0"

  communicator        = "ssh"
  ssh_username        = "vagrant"
  ssh_password        = "vagrant"
  ssh_timeout         = "30m"

  ssh_agent_auth      = false
  skip_export         = false

  shutdown_command    = "sudo shutdown -P now"
}

build {
  sources = ["source.hyperv-iso.secnet"]

  post-processor "vagrant" {
    keep_input_artifact = false
    output              = "ubuntu-secnet-hyperv.box"
  }
}
