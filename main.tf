provider "libvirt" {
  uri = "qemu:///system"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "patroni_base" {
  name   = "patroni-base.img"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
#  source = "https://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img"
  format = "qcow2"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "patroni" {
  count = 3
  name   = "patroni${count.index}.img"
  base_volume_id = "${libvirt_volume.patroni_base.id}"
  size = 23613931520
  pool   = "default"
  format = "qcow2"
}

data "template_file" "user_data" {
  count = 3
  template = "${file("${path.module}/cloud_init.cfg")}"
}

data "template_file" "meta_data" {
  count = 3
  template = "${file("${path.module}/meta_data.cfg")}"
  vars = {
    count_index = "${count.index}"
  }
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  count = 3
  name           = "commoninit${count.index}.iso"
  user_data      = "${element(data.template_file.user_data.*.rendered, count.index)}"
  meta_data      = "${element(data.template_file.meta_data.*.rendered, count.index)}"
}

resource "libvirt_domain" "patroni" {
  count = 3
  name = "patroni${count.index}"
  memory = 4096
  vcpu = 2
  qemu_agent = true

  cloudinit = "${element(libvirt_cloudinit_disk.commoninit.*.id, count.index)}"

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = "${element(libvirt_volume.patroni.*.id, count.index)}"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
