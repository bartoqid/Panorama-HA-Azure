provider "azurerm" {}

locals {
  virtual_machine_name = "${var.prefix}vm"
}

# Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-ResourceGroup"
  location = "${var.location}"
}

# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["172.16.0.0/16"]
  resource_group_name = "${azurerm_resource_group.main.name}"
  location            = "${azurerm_resource_group.main.location}"
}

# Create the first Subnet within the Virtual Network
resource "azurerm_subnet" "External" {
  name                 = "External"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  address_prefix       = "172.16.1.0/24"
}

# Create a Public IP for the Virtual Machine
resource "azurerm_public_ip" "main1" {
  name                         = "${var.prefix}-pip1"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  public_ip_address_allocation = "dynamic"
}

resource "azurerm_public_ip" "main2" {
  name                         = "${var.prefix}-pip2"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  public_ip_address_allocation = "dynamic"
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_https"
    description                = "Allow https access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create the first network interface card for External and attach the PIP and the NSG - this nic will have the deafult route
resource "azurerm_network_interface" "ext-nic1" {
  name                      = "${var.prefix}-ext-nic1"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.main.id}"

  ip_configuration {
    name                          = "primary1"
    subnet_id                     = "${azurerm_subnet.External.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.main1.id}"
  }
}

resource "azurerm_network_interface" "ext-nic2" {
  name                      = "${var.prefix}-ext-nic2"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.main.id}"

  ip_configuration {
    name                          = "primary2"
    subnet_id                     = "${azurerm_subnet.External.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.main2.id}"
  }
}

resource "azurerm_virtual_machine" "main1" {
  name                         = "${var.prefix}-panorama1"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  primary_network_interface_id = "${azurerm_network_interface.ext-nic1.id}"
  network_interface_ids        = ["${azurerm_network_interface.ext-nic1.id}"]
  vm_size                      = "Standard_D5_V2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
delete_data_disks_on_termination = true

    plan {
    name = "byol"
    publisher = "paloaltonetworks"
    product = "panorama"
  }

  storage_image_reference {
    publisher = "paloaltonetworks"
    offer     = "panorama"
    sku       = "byol"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${local.virtual_machine_name}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  storage_data_disk {
    name            = "${local.virtual_machine_name}-DISK-1"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "2065"
}
  os_profile {
    computer_name  = "${local.virtual_machine_name}-panorama1"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}


resource "azurerm_virtual_machine" "main2" {
  name                         = "${var.prefix}-panorama2"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  primary_network_interface_id = "${azurerm_network_interface.ext-nic2.id}"
  network_interface_ids        = ["${azurerm_network_interface.ext-nic2.id}"]
  vm_size                      = "Standard_D5_V2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
delete_data_disks_on_termination = true

    plan {
    name = "byol"
    publisher = "paloaltonetworks"
    product = "panorama"
  }

  storage_image_reference {
    publisher = "paloaltonetworks"
    offer     = "panorama"
    sku       = "byol"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${local.virtual_machine_name}-osdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  storage_data_disk {
    name            = "${local.virtual_machine_name}-DISK-2"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option   = "Empty"
    lun             = 0
    disk_size_gb    = "2065"
}
  os_profile {
    computer_name  = "${local.virtual_machine_name}-panorama2"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}