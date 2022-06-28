# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.0"
    }
  }
}
provider "azurerm" {
# whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
subscription_id = "5c4907f5-906f-479a-b2a9-8dfc9adf0fc0"
client_id = "cf78dc7c-a0be-4505-825c-3f9393a56bbf"
client_secret = "X5V8Q~e4nkBtPqVY_I6pJC2AQjU6kljO68wTscYU"
tenant_id = "f346ca54-df12-4296-a686-74f9f2c5409c"
features {}
}

# Create a resource group
resource "azurerm_resource_group" "TF_rg" {
name = "${var.resource_prefix}-RG"
location = var.node_location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "TF_vnet" {
name = "${var.resource_prefix}-vnet"
resource_group_name = azurerm_resource_group.TF_rg.name
location = var.node_location
address_space = var.node_address_space
}

# Create a subnets within the virtual network
resource "azurerm_subnet" "TF_subnet" {
name = "${var.resource_prefix}-subnet"
resource_group_name = azurerm_resource_group.TF_rg.name
virtual_network_name = azurerm_virtual_network.TF_vnet.name
address_prefixes = var.node_address_prefix
}

# Create Linux Public IP
resource "azurerm_public_ip" "TF_public_ip" {
count = var.node_count
name = "${var.resource_prefix}-${format("%02d", count.index)}-PublicIP"
#name = "${var.resource_prefix}-PublicIP"
location = azurerm_resource_group.TF_rg.location
resource_group_name = azurerm_resource_group.TF_rg.name
allocation_method = var.Environment == "Test" ? "Static" : "Dynamic"

tags = {
environment = "Test"
}
}

# Create Network Interface
resource "azurerm_network_interface" "TF_nic" {
count = var.node_count
#name = "${var.resource_prefix}-NIC"
name = "${var.resource_prefix}-${format("%02d", count.index)}-NIC"
location = azurerm_resource_group.TF_rg.location
resource_group_name = azurerm_resource_group.TF_rg.name
#

ip_configuration {
name = "internal"
subnet_id = azurerm_subnet.TF_subnet.id
private_ip_address_allocation = "Dynamic"
public_ip_address_id = element(azurerm_public_ip.TF_public_ip.*.id, count.index)
#public_ip_address_id = azurerm_public_ip.TF_public_ip.id
#public_ip_address_id = azurerm_public_ip.TF_public_ip.id
}
}

# Creating resource NSG
resource "azurerm_network_security_group" "TF_nsg" {

name = "${var.resource_prefix}-NSG"
location = azurerm_resource_group.TF_rg.location
resource_group_name = azurerm_resource_group.TF_rg.name

# Security rule can also be defined with resource azurerm_network_security_rule, here just defining it inline.
security_rule {
name = "Inbound"
priority = 100
direction = "Inbound"
access = "Allow"
protocol = "Tcp"
source_port_range = "*"
destination_port_range = "*"
source_address_prefix = "*"
destination_address_prefix = "*"
}
tags = {
environment = "Test"
}
}

# Subnet and NSG association
resource "azurerm_subnet_network_security_group_association" "TF_subnet_nsg_association" {
subnet_id = azurerm_subnet.TF_subnet.id
network_security_group_id = azurerm_network_security_group.TF_nsg.id
}

# Virtual Machine Creation — Linux
resource "azurerm_virtual_machine" "TF_linux_vm" {
count = var.node_count
name = "${var.resource_prefix}-${format("%02d", count.index)}"
#name = "${var.resource_prefix}-VM"
location = azurerm_resource_group.TF_rg.location
resource_group_name = azurerm_resource_group.TF_rg.name
network_interface_ids = [element(azurerm_network_interface.TF_nic.*.id, count.index)]
vm_size = "Standard_DC1ds_v3"
delete_os_disk_on_termination = true

storage_image_reference {
publisher = "MicrosoftWindowsDesktop"
offer     = "Windows-10"
sku       = "win10-21h2-pro-g2"
version   = "latest"
}
storage_os_disk {
name = "myosdisk-${count.index}"
caching = "ReadWrite"
create_option = "FromImage"
managed_disk_type = "Standard_LRS"
}
os_profile {
computer_name = "linuxhost"
admin_username = "terraform"
admin_password = "Password@1234"
}
os_profile_windows_config { 
    provision_vm_agent = true
}

tags = {
environment = "Test"
}
}