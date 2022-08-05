# How to Install a Printer using these Scripts
You can use the two scripts here to find ways to install Drivers and Printers to your Windows 10 and 11 Devices using Microsoft Endpoint Manager. 

## Components
- Detection Script
- Deployment Script
- PCL 6 Printer Drivers
- Intune Win32 App

## Variables and Files Needed for Deployment
While you might be able to get this working with most kind of Drivers, I have only tested this using PCL 6 Canon Drivers so far. You could use this as a guide to come up with your own script to deploy printers of your choice.

For this Example, these are the Variables and Files we are using:
- Printer Driver : Generic Plus PCL6 Printer Driver
- Printer Driver Model: Canon Generic Plus PCL6
- Printer Driver Zip File Name: Driver.ZIP
- Printer Port IP Address: 192.168.1.150
- Printer Port Name: 192.168.1.150
- Printer Name: Canon imageRUNNER (Sonitlo Managed)

### Getting the Driver ZIP File Ready
You can download the latest PCL 6 Drivers for a supported Printer from Manufacturer's Website. In this example, we will use *Canon imageRUNNER ADVANCE C5560i* Multifunction Copier. We will download the installer for *Generic Plus PCL6 Printer Driver* from Canon Website and extract the content of "Driver" folder. These are the only files you need for this installation.
![image](https://user-images.githubusercontent.com/37104267/183159903-de5e81b1-b8ec-4101-89a2-97bb5d2ddf5a.png)

You will also need to include the name of the file which contains the setup information. Ex: CNP60MA64.inf
![image](https://user-images.githubusercontent.com/37104267/183214694-5d037919-b93a-4f71-a211-dfc7190ef233.png)


Now zip the content of this folder to "Driver.ZIP".
![image](https://user-images.githubusercontent.com/37104267/183213315-a3622fe6-e34b-4973-acaa-a26020ee2743.png)

### Update Deployment Script with correct values for Variables
