terraform {
  cloud {
    organization = "markaplay"
    workspaces {
      name = "demo"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.4.1"
    }
  }
}

variable "VAULTTOKEN" {
    type = string
    description = "Vault token for authentication to fetch secrets"
}

provider "vault" {
  address         = "https://vault.lab.markaplay.net"
  token           = var.VAULTTOKEN
}

data "vault_generic_secret" "azsecrets" {
  path = "Azure/Demo-Terraform"
}


provider "azurerm" {
  features {}

  subscription_id = data.vault_generic_secret.azsecrets.subid
  client_id       = data.vault_generic_secret.azsecrets.clientid
  client_secret   = data.vault_generic_secret.azsecrets.clientsecret
  tenant_id       = data.vault_generic_secret.azsecrets.tenantid
}

variable "prefix" {
  default = "terra"
}

resource "azurerm_resource_group" "demo-rs" {
  name     = "${var.prefix}-resources"
  location = "Canada East"
}

resource "azurerm_virtual_network" "demo-vnet" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo-rs.location
  resource_group_name = azurerm_resource_group.demo-rs.name
}

resource "azurerm_subnet" "demo-subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.demo-rs.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "demo-nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.demo-rs.location
  resource_group_name = azurerm_resource_group.demo-rs.name

  ip_configuration {
    name                          = "demo-terraform"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "demo-vm" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.demo-rs.location
  resource_group_name   = azurerm_resource_group.demo-rs.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }
  storage_os_disk {
    name              = "osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  os_profile {
    computer_name  = "demo-terraform"
    admin_username = "myadminuser"
    admin_password = "Password1234!"
  }
  os_profile_windows_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "demo"
    auto        = "terraform"
  }
}