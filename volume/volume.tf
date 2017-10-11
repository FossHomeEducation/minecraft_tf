# Separate the data volume generation and attachment

# Variables from parent
variable "hostname" { default = "minecraft" }
variable "domain"   { default = "education.fosshome.com" }

variable "use_snapshot"  { default = 0 }

provider "aws" {
  region = "us-east-1"
}

# Find the relevant instance
data "aws_instance" "server" {
  filter {
    name   = "tag:Name"
    values = ["${var.hostname}.${var.domain}"]
  }
}

# Generate the EBS volume
resource "aws_ebs_volume" "ebs_new" {
  count = "${1 - var.use_snapshot}"
  availability_zone = "${data.aws_instance.server.availability_zone}"

  # For the first time generate the volume
  size = 10

  tags {
    Name = "minecraft-data"
  }
}

# Attach the data volume
resource "aws_volume_attachment" "ebs_att_new" {
  count = "${1 - var.use_snapshot}"
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.ebs_new.id}"
  instance_id = "${data.aws_instance.server.id}"
  force_detach = true
  #skip_destroy = true
}

# Find Minecraft Data Snapshot
data "aws_ebs_snapshot" "saved_data" {
  count = "${var.use_snapshot}"
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Name"
    values = ["minecraft-data"]
  }
}

# Generate the EBS volume from snapshot
resource "aws_ebs_volume" "ebs_saved" {
  count = "${var.use_snapshot}"
  availability_zone = "${data.aws_instance.server.availability_zone}"

  # Create the volume from snapshot
  snapshot_id = "${data.aws_ebs_snapshot.saved_data.id}"
  tags {
    Name = "minecraft-data"
  }
}

# Attach the data volume
resource "aws_volume_attachment" "ebs_att_saved" {
  count = "${var.use_snapshot}"
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.ebs_saved.id}"
  instance_id = "${data.aws_instance.server.id}"
  force_detach = true
  #skip_destroy = true
}


