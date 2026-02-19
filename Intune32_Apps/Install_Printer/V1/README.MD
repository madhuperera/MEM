# How to Install a Printer using these Scripts
You can use the two scripts here to find ways to install Drivers and Printers to your Windows 10 and 11 Devices using Microsoft Endpoint Manager. 

## Components
- [Detection Script](https://github.com/madhuperera/MEM/blob/main/Intune32_Apps/Install_Printer/Detect_Printer.ps1 "Detection Script")
- [Deployment Script](https://github.com/madhuperera/MEM/blob/main/Intune32_Apps/Install_Printer/Deploy_Printer.ps1 "Deployment Script")
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
You can download the latest PCL 6 Drivers for a supported Printer from Manufacturer's Website. In this example, we will use *Canon imageRUNNER ADVANCE C5560i* Multifunction Copier. We will download the installer for *Generic Plus PCL6 Printer Driver* from Canon Website and extract the "Driver" folder. These are the only files you need for this installation.
![image](https://user-images.githubusercontent.com/37104267/183159903-de5e81b1-b8ec-4101-89a2-97bb5d2ddf5a.png)

You will also need to include the name of the file which contains the setup information. Ex: CNP60MA64.INF
![image](https://user-images.githubusercontent.com/37104267/183214694-5d037919-b93a-4f71-a211-dfc7190ef233.png)


Now zip the Driver Folder to "Driver.ZIP".
![image](https://user-images.githubusercontent.com/37104267/183221794-ddf157b3-7db7-4342-b009-7b6c1fb5cd49.png)
![image](https://user-images.githubusercontent.com/37104267/183221808-c42038cb-f8ef-4b28-84e1-948185b59841.png)

### Update Deployment Script with correct values for Variables
Now updates the MEM Variable section with the correct values.
![image](https://user-images.githubusercontent.com/37104267/183215167-79dda25a-531b-4497-9b94-448b8f32df6f.png)

### Prepare the Windows Win32 App for Deployment
Copy the Driver.ZIP file and Deploy_Printer.ps1 to the same folder and run IntuneWinAppUtil.exe to create the Windows Win32 Intune App.
![image](https://user-images.githubusercontent.com/37104267/183216515-a8640c1c-7805-4b4a-a9d5-d515b3fe84f6.png)
![image](https://user-images.githubusercontent.com/37104267/183216977-76444104-7d6a-45aa-bcb4-8339b2243616.png)

### Update Detection Script with correct values for Variables
Now update the MEM Variable section with the same values you used for Deployment Script.
![image](https://user-images.githubusercontent.com/37104267/183216929-87c8ee8e-41a7-4528-b124-8ab6815430de.png)

## Deploy the Printer on Microsoft Endpoint Manager
Now deploy this as any other Intune Win32 App from Microsoft Endpoint Manager Portal.
![image](https://user-images.githubusercontent.com/37104267/183217466-690c3421-1fc0-4a81-87f9-bba7a24eb64a.png)

Install Command would be:
powershell.exe -ExecutionPolicy bypass -file Deploy_Printer.ps1
![image](https://user-images.githubusercontent.com/37104267/183217577-34d52de6-5055-4154-9d20-f68169d0a699.png)
Currently I do not have a Script to uninstalling the printer, so you can have anything in the "Uninstall" command field. I could look into coming up with an uninstallation script in the future if necessary.

Choose the option to use a custom detection script and upload "Detect_Printer.ps1" file.
![image](https://user-images.githubusercontent.com/37104267/183217761-b54008b5-58ed-4f1a-ac2a-49b8650354b3.png)

After successful installation, MEM should report the printer as installed against each device.
![image](https://user-images.githubusercontent.com/37104267/183224517-ee54c289-a679-4cd0-b06d-2402d7932593.png)

## End User Experience
If you had notifications enabled, staff member will get a notification when the printer is installed and ready to use.
![image](https://user-images.githubusercontent.com/37104267/183224629-580305e3-3a04-413f-aa7b-da13b8ac04e7.png)

How it looks in Settings on Windows 11.
![image](https://user-images.githubusercontent.com/37104267/183224647-c5d22f6b-f16c-4e20-af4d-3757a273b588.png)
![image](https://user-images.githubusercontent.com/37104267/183224661-c78980cf-fd22-4e31-a0e0-db7a6e51478f.png)
![image](https://user-images.githubusercontent.com/37104267/183224672-623b64ad-92b3-40f2-945d-50b1d0715da9.png)
![image](https://user-images.githubusercontent.com/37104267/183224685-cc57c779-223d-4a3c-ba1f-76798c320056.png)

Good Luck :)
