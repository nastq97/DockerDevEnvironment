terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0.1"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.v_subscription_id
  tenant_id       = var.v_tenant_id
  client_id       = var.v_appId
  client_secret   = var.v_password

}



resource "azurerm_resource_group" "rg" {
    name                = var.v_rg
    location            = var.v_region_location
}

resource "azurerm_virtual_network" "vnet" {
   name                 = "${var.v_prefix}-appvnet"
   location             = var.v_region_location
   resource_group_name  = var.v_rg
   address_space        = var.v_vnet_address_space

   depends_on = [
     azurerm_resource_group.rg
   ]
}

resource "azurerm_subnet" "vm_subnet" {
    name                 = var.v_vm_subnet_name
    address_prefixes     = var.v_subnet_prefixes
    resource_group_name  = var.v_rg
    virtual_network_name = azurerm_virtual_network.vnet.name

}

resource "azurerm_network_interface" "vm-nic" {
  #count                 = 1
  name                  = var.v_nic_name_vm
  location              = var.v_region_location
  resource_group_name   = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
  }
}

resource "azurerm_public_ip" "vm_public_ip" {
  #count               = 1
  name                = var.v_vm_public_ip
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.v_region_location
  allocation_method   = "Static"
}


resource "azurerm_windows_virtual_machine" "vm" {
  #count                 = 1
  name                  = var.v_vm_name
  resource_group_name   = var.v_rg
  location              = var.v_region_location
  size                  = var.v_vm_size
  admin_username        = var.v_vm_username
  admin_password        = var.v_vm_password
  network_interface_ids = [
    azurerm_network_interface.vm-nic.id

  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-pro-g2"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = "./RunCommand.ps1"
    interpreter = ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    command = "./wsl2-build.ps1"
    interpreter = ["PowerShell", "-Command"]
  }
}


resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.v_vm_name}-nsg"
  location            = var.v_region_location
  resource_group_name = var.v_rg
  depends_on = [
     azurerm_resource_group.rg
  ]
  security_rule {
    name                       = "http_in"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "https_in"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "http_out"
    priority                   = 301
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP"
    priority                   = 303
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "195.184.101.130"
    destination_address_prefix = "*"
  }                    
}


resource "azurerm_subnet_network_security_group_association" "vm_nsg_associate" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id 
}

