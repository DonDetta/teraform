terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version ="0.85.0"
    }
  }
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "tf-state-bucket-student"
    region     = "ru-central1-a"
    key        = "issue1/lemp.tfstate"
    access_key = "YCAJEGStzIG5o-5Yz5-T7mDSG"
    secret_key = "YCP0ht_f5f_JVED6-U_eM7cHFSafJDPXYNjK35o0"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}


provider "yandex" {
#  token                    = ""
  service_account_key_file = file("~/key.json")
  cloud_id                 = "cloud-dondetta"
  folder_id                = "b1g3v95jc7takhl2hhpa"
  zone                     = "ru-central1-a"
}

#делаем сеть и подсети
resource "yandex_vpc_network" "network-1" {
  name        = "network-1"
  description = "My first network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}
#Делаем инстансы с указанием модуля
module "ya_instance_1" {
  source                = "./modules/instance"
  instance_family_image = "lemp"
  vpc_subnet_id         = yandex_vpc_subnet.subnet-1.id
  instance_zone         = "ru-central1-a"
}

module "ya_instance_2" {
  source                = "./modules/instance"
  instance_family_image = "lamp"
  vpc_subnet_id         = yandex_vpc_subnet.subnet-2.id
  instance_zone         = "ru-central1-b"
}

#Создаем балансировщика

resource "yandex_lb_network_load_balancer" "lb-web" {
  name = "network-load-balancer"

  listener {
    name = "listener-tcp"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web.id
    healthcheck {
      name = "tcp"
      tcp_options {
        port = 80
#        path = "/"
      }
    }
  }
}

resource "yandex_lb_target_group" "web" {
  name      = "my-target-group"
#Тут настраиваются адреса для балансировщика, берём сеть и адрес из модуля.
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address = module.ya_instance_1.internal_ip_address_vm
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet-2.id
    address = module.ya_instance_2.internal_ip_address_vm
  }

}


