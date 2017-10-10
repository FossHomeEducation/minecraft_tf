
# Sample file to spin up a minecraft server
variable "hostname" { default = "minecraft" }
variable "domain"   { default = "education.fosshome.com" }
variable "cidr"     { default = "10.10.10.0/24" }
variable "keyname"  { default = "minecraft_key" }
variable "use_snapshot"  { default = 0 }

provider "aws" {
  region = "us-east-1"
}

# VPC/Gateway/Routes/Subnet
resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr}"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "subnet" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "${var.cidr}"
}

# Security Group allowing Minecraft traffic
resource "aws_security_group" "allow_minecraft" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "allow_minecraft"
  description = "Allow all inbound minecraft traffic"

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8192
    to_port     = 8192
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group allowing incoming SSH and outgoing http/s
resource "aws_security_group" "allow_ssh_http" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "allow_ssh_http"
  description = "Allow inbound ssh and outbound http/s traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Find the latest Ubuntu image
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create the instance
resource "aws_instance" "server" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.large"
  key_name = "${var.keyname}"
  associate_public_ip_address = "true"
  subnet_id   = "${aws_subnet.subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_minecraft.id}","${aws_security_group.allow_ssh_http.id}"]

  root_block_device {
  } 

  tags {
    Name = "${var.hostname}.${var.domain}"
  }
}

# Generate the EBS volume
resource "aws_ebs_volume" "ebs_new" {
  count = "${1 - var.use_snapshot}"
  availability_zone = "${aws_instance.server.availability_zone}"

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
  instance_id = "${aws_instance.server.id}"
  #force_detach = true
  skip_destroy = true 
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
  availability_zone = "${aws_instance.server.availability_zone}"

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
  instance_id = "${aws_instance.server.id}"
  #force_detach = true
  skip_destroy = true 
}

# Find the Route53 Hosted Zone
data "aws_route53_zone" "zone" {
  name         = "${var.domain}."
  private_zone = false
}

# Add the hostname with the new IP
resource "aws_route53_record" "hostname" {
  zone_id = "${data.aws_route53_zone.zone.zone_id}"
  name    = "${var.hostname}.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.server.public_ip}"]
}

# Output the IP in a format for Ansible to connect
output "inventory" {
  value = "[server]\n${aws_instance.server.public_ip} ansible_user=ubuntu ansible_python_interpreter=/usr/bin/python3"
}
