packer {
  required_plugins {
    virtualbox = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "virtualbox-iso" "secnet" {
  iso_url             = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
  iso_checksum        = "file:https://releases.ubuntu.com/26.04/SHA256SUMS"
  iso_target_path     = "./iso_cache/ubuntu-26.04.iso"
  vm_name             = "secnet-base-box"
  guest_os_type       = "Ubuntu_64"
  memory              = 4096
  cpus                = 2

  # Kein enable_secure_boot / generation / switch_name nötig -
  # VirtualBox kennt diese Hyper-V-spezifischen Optionen nicht.

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

  shutdown_command    = "sudo shutdown -P now"

  # VirtualBox-Guest-Additions werden von Vagrant/den Labs nicht benötigt -
  # explizit deaktiviert, um den Build zu beschleunigen und die ISO schlank
  # zu halten.
  guest_additions_mode = "disable"
}

build {
  sources = ["source.virtualbox-iso.secnet"]

  post-processor "vagrant" {
    keep_input_artifact = false
    output              = "ubuntu-secnet-virtualbox.box"
  }
}
