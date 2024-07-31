locals {
  resource_group_name = "LAB04-RG"
  location = "EAST US"

  #definig the virtual network variable
  virtual_networks = [
    {
      name = "vnet1"
      address_space = ["30.0.0.0/16"]
    }
  ]
  subnets = [
    {
      name = "subneta"
      address_prefix = "30.0.1.0/24"
    },
    {
      name = "subnetb"
      address_prefix = "30.0.2.0/26"
    }
  ]
}

#defining Resource Group
resource "azurerm_resource_group" "ResourceGroup5" {

  name = local.resource_group_name
  location = local.location

}

#defining Virtual Network
resource "azurerm_virtual_network" "network1" {

  name = local.virtual_networks[0].name
  resource_group_name = local.resource_group_name
  location = local.location
  address_space = local.virtual_networks[0].address_space

  depends_on = [ 
     azurerm_resource_group.ResourceGroup5
   ]
}

#defining Subnet1
resource "azurerm_subnet" "subnet1" {

  name = local.subnets[0].name
  resource_group_name = local.resource_group_name
  virtual_network_name = local.virtual_networks[0].name
  address_prefixes = [ local.subnets[0].address_prefix ]

  depends_on = [
    azurerm_virtual_network.network1
    ]  
}

#defining Subnet2
resource "azurerm_subnet" "subnet2" {

  name = local.subnets[1].name
  resource_group_name = local.resource_group_name
  virtual_network_name = local.virtual_networks[0].name
  address_prefixes = [ local.subnets[1].address_prefix ] 

  depends_on = [ 
    azurerm_virtual_network.network1
   ]
}

#printing the outputs of subnet
output "subnets" {

  value = azurerm_virtual_network.network1.subnet  
}

#defining the network interface card
resource "azurerm_network_interface" "nic1" {
  name                = "niclab04"
  location            = local.location
  resource_group_name = local.resource_group_name 

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.pip2.id
  }
  depends_on = [ azurerm_subnet.subnet2 ]
}

#defining public ip address 
resource "azurerm_public_ip" "pip2" {
  name = "publicip-lab04"
  resource_group_name = local.resource_group_name
  location = local.location
  allocation_method = "Static"
  sku = "Standard"
  sku_tier = "Regional"

  depends_on = [ azurerm_resource_group.ResourceGroup5 ]
}

#defining network security group
resource "azurerm_network_security_group" "nsg2" {
  name                = "lab04nsg"
  location            = local.location
  resource_group_name = local.resource_group_name 

  security_rule {
    name                       = "blockhttp"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Testing"
  }

  depends_on = [ azurerm_resource_group.ResourceGroup5 ]
}

#defining security rules 
resource "azurerm_network_security_rule" "rule2" {
  name                        = "allowrdp"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = local.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg2.name

  depends_on = [ azurerm_network_security_group.nsg2 ]
}

#associating the nsg with subnet
resource "azurerm_subnet_network_security_group_association" "associatensg" {

  subnet_id = azurerm_subnet.subnet2.id
  network_security_group_id = azurerm_network_security_group.nsg2.id

}

#creating a virtual machine
resource "azurerm_windows_virtual_machine" "vm1" {
  name                = "test-vm4"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = "admini"
  admin_password      = "Shriram@9151"
  network_interface_ids = [
    azurerm_network_interface.nic1.id,
    azurerm_network_interface.secondary-network-interface.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [ 
    azurerm_network_interface.nic1,
    azurerm_network_interface.secondary-network-interface,
     azurerm_resource_group.ResourceGroup5 
  ]
}

#defining a secondary network interface 
resource "azurerm_network_interface" "secondary-network-interface" {
  name                = "nic1lab04"
  location            = local.location
  resource_group_name = local.resource_group_name 

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [ azurerm_subnet.subnet2 ]
}

#defining a data disk
resource "azurerm_managed_disk" "disk1" {
  name                 = "disk-lab04"
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "64"

  tags = {
    environment = "testing"
  }

  depends_on = [ azurerm_resource_group.ResourceGroup5 ]
}

#attaching the disk to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "diskattachment1" {
  managed_disk_id    = azurerm_managed_disk.disk1.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm1.id
  lun                = "0"
  caching            = "ReadWrite"

  depends_on = [ 
    azurerm_windows_virtual_machine.vm1,
    azurerm_resource_group.ResourceGroup5
   ]
}


#defining a secondary data disk
resource "azurerm_managed_disk" "disk2" {
  name                 = "disk2-lab04"
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "256"

  tags = {
    environment = "testing"
  }

  depends_on = [ azurerm_resource_group.ResourceGroup5 ]
}

#attaching the secondary data disk to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "diskattachment2" {
  managed_disk_id    = azurerm_managed_disk.disk2.id 
  virtual_machine_id = azurerm_windows_virtual_machine.vm1.id
  lun                = "1"
  caching            = "ReadWrite"

  depends_on = [ 
    azurerm_windows_virtual_machine.vm1,
    azurerm_resource_group.ResourceGroup5
   ]
}
