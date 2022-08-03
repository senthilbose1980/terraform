provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "fl-grp"
  location = "eastus"
}

resource "azurerm_virtual_network" "fl_network" {
  name                = "fl-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "fl_subnetA" {
  name                 = "fl-subnetA"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.fl_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "fl_network_interfaceA" {
  name                = "fl-network-interfaceA"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.fl_subnetA.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "fl_network_interfaceB" {
  name                = "fl-network-interfaceB"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.fl_subnetA.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "fl_vm1" {
  name                = "fl-vm1"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.fl_network_interfaceA.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "fl_vm2" {
  name                = "fl-vm2"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.fl_network_interfaceB.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_availability_set" "app_set" {
  name                         = "app-set"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.name
  platform_fault_domain_count  = 3
  platform_update_domain_count = 3
}

resource "azurerm_network_security_group" "fl_nsg" {
  name                = "fl-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "test123"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_public_ip" "fl_lb_ip" {
  name                = "fl-lb-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "fl_lb" {
  name                = "myapp-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Standard"


  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.fl_lb_ip.id
  }
}


resource "azurerm_lb_backend_address_pool" "fl_poolA" {
  loadbalancer_id = azurerm_lb.fl_lb.id
  name            = "fl-PoolA"
}

resource "azurerm_lb_backend_address_pool_address" "fl_addressA" {
  name                    = "fl-app1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.fl_poolA.id
  virtual_network_id      = azurerm_virtual_network.fl_network.id
  ip_address              = azurerm_network_interface.fl_network_interfaceA.private_ip_address
}


resource "azurerm_lb_backend_address_pool_address" "fl_addressB" {
  name                    = "fl-app2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.fl_poolA.id
  virtual_network_id      = azurerm_virtual_network.fl_network.id
  ip_address              = azurerm_network_interface.fl_network_interfaceB.private_ip_address
}

resource "azurerm_lb_probe" "fl_probe" {
  loadbalancer_id = azurerm_lb.fl_lb.id
  name            = "webprobe"
  port            = 80
}

resource "azurerm_lb_rule" "fl_ruleapp" {
  loadbalancer_id                = azurerm_lb.fl_lb.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.fl_poolA.id]
  probe_id                       = azurerm_lb_probe.fl_probe.id
}