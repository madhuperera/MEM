# MEM (Microsoft Endpoint Manager *a.k.a. Microsoft Intune*)
Welcome to Madhu's Repository of Scripts that you can use with Microsoft Endpoint Manager. I am sharing these scripts **"AS IS" without any kind of warranty**. Please go through the scripts' content before deploying in your environment.

If you have any question about any of the scripts or you have an idea for a PowerShell based script, please leave a comment.

## Resources
- [Intune Win32 Apps](https://github.com/madhuperera/MEM/tree/main/Intune32_Apps "Intune Win32 Apps")
- [Proactive Remediations](https://github.com/madhuperera/MEM/tree/main/Proactive_Remediations "Proactive Remediations")

### Intune Win32 Apps
Here, you can find a collection of Scripts and ideas on how to deploy Applications using Intune Win32 Apps. You can use this method to:
- Install .exe Applications.
- Run PowerShell Script on a Schedule.
- Install Printers to Devices.
- Copy Files to the End Devices.

You can find more information on how Win32 App Management works in Microsoft Intune [here](https://docs.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management "here").

Please note that some packages found here will only have the Detection Script. You can use the Detection Script to detect if the application on the End Device meets your requirements or not. If not, you can simply include the Intune Win32 App package with the correct command to install the EXE within the application package.

### Proactive Remediations
Proactive Remediation Scripts are the best way to deploy PowerShell scripts to an end device using Microsoft Endpoint Manager. Here, you will find ideas for those scripts with samples. Proactive Remediation Package will have two primary components:
1. Detection Script.
2. Deployment Script.

#### Detection Script
These script will rerutn success or error to let Intune know if the device satisfies your requirements. If not, Install Script will get executed on the system.

#### Deployment Script
If the detection script finds out that the end device does not satisfy the requirements set by you, you can use the Deployment Script to remediate.

Please go to Microsoft Docs to find more information on how [Proactive Remediations](https://docs.microsoft.com/en-us/mem/analytics/proactive-remediations "Proactive Remediations") work in Microsoft Endpoint Manager.

## Feedback
Constructive feedback is always appreciated. I am doing most of these Scripts in my own Personal time, so I will not be able to update these as often as I would have liked to. If you find any issues with the Scripts, please leave a comment and I will try my best to get it sorted and update the Script. If you have an idea for a Script that could be useful for yourself as well as others, you can contact me using any of the Social Media platforms below:
- [LinkedIn](https://www.linkedin.com/in/madhuperera/ "LinkedIn")
- [Twitter](https://twitter.com/madhu_perera "Twitter")