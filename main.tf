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
      version = "~>3.8.0"
    }
  }
}

variable "AZ_SUBID" {
  type        = string
  description = "Azure subscription ID"
}

variable "AZ_CLIENTID" {
  type        = string
  description = "azure client id"
}

variable "AZ_CLIENTSECRET" {
  type        = string
  description = "azure client secret"
}

variable "AZ_TENNANTID" {
  type        = string
  description = "azure tennant id"
}

provider "vault" {
  address = "https://vault.lab.markaplay.net"
  token   = var.VAULTTOKEN
}

data "vault_generic_secret" "azsecrets" {
  path = "Azure/Demo-Terraform"
}


provider "azurerm" {
  features {}

  subscription_id = data.vault_generic_secret.azsecrets.data["subid"]
  client_id       = data.vault_generic_secret.azsecrets.data["clientid"]
  client_secret   = data.vault_generic_secret.azsecrets.data["clientsecret"]
  tenant_id       = data.vault_generic_secret.azsecrets.data["tenantid"]
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "Canada East"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "demo-terraform"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"
  admin_username      = "myadminuser"
  admin_password      = "Password1234!"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }
  
  tags = {
    environment = "demo"
    auto        = "terraform"
  }
}