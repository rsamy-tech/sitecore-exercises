terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.37.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = ""
  client_id       = ""
  client_secret   = ""
  tenant_id       = ""
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "raj_rg" {
  name     = "raj_test"
  location = "East US"

  tags = {
    environment = "test"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "raj_nw"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.raj_rg.location
  resource_group_name = azurerm_resource_group.raj_rg.name

  tags = {
    environment = "test"
  }
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "raj_snw"
  resource_group_name  = azurerm_resource_group.raj_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  for_each            = toset(var.vm_name)
  name                = "${each.key}-ip"
  location            = azurerm_resource_group.raj_rg.location
  resource_group_name = azurerm_resource_group.raj_rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "test"
  }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "raj_nsg"
  location            = azurerm_resource_group.raj_rg.location
  resource_group_name = azurerm_resource_group.raj_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "test"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  for_each            = toset(var.vm_name)    
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.raj_rg.location
  resource_group_name = azurerm_resource_group.raj_rg.name

  ip_configuration {
    name                          = "${each.key}-myNicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[each.key].id
  }

  tags = {
    environment = "test"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "association" {
  for_each                  = toset(var.vm_name)
  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.raj_rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.raj_rg.name
  location                 = azurerm_resource_group.raj_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "test"
  }
}

# Create (and display) an SSH key
resource "tls_private_key" "rajtestvm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "linuxvm" {
  for_each              = toset(var.vm_name)
  name                  = each.value
  location              = azurerm_resource_group.raj_rg.location
  resource_group_name   = azurerm_resource_group.raj_rg.name
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "${each.key}-myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "${each.key}-test"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.rajtestvm_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage.primary_blob_endpoint
  }

  tags = {
    environment = "test"
  }
}