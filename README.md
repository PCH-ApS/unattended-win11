**Welcome to my guide on how I create a de-bloated WIN11 installation**

# Minimal Window 11 

This is my personal take on how I can run a minimal windows 11 on laptops and virtual..

My aim is to have a minimal and low footprint windows 11 installation without any - or only a minimal set - of the M365 cloud tools preinstalled, along with other MS "bloatware".

This is not my daily-driver. My daily-driver is a Ubuntu 24.04 with [Omakub](https://omakub.org/)on top. This is great for almost anything I need to do, however for now I still need to be able to run MS Excel with macros to complete some of my tasks - as an example. To do this i want to have small Windows 11 I can use.

The aim is to create a clean and easy way to bring up virtual machines or a computer with Windows 11, so if/when something is not working as expected I can just start over and deploy a new. 

# Steps

The steps I follow to create my Windows 11 are:
## [Download Windows 11 from Microsoft](https://github.com/PCH-ApS/unattended-win11/blob/main/Step%2001.md)

## Create the unattended file on schneegans.de
*  Go to [schneegans.de](https://schneegans.de/windows/unattend-generator/) 
	* Fill out the available options and save the file.

* Region and language settings:
	
	| Key                                            | Selecetion            |
	| ---------------------------------------------- | --------------------- |
	| Windows display language:                      | English International |
	| Specify the first language and keyboard layout | True                  |
	| Language                                       | Danish (Denmark)      |
	| Kayboard layout                                | Danish                |
	| Home location                                  | Denmark               |
	|                                                |                       |

* Setup settings:

| Key                                                           | Selection |
| ------------------------------------------------------------- | --------- |
| Bypass Windows 11 requirements check (TPM, Secure Boot, etc.) | True      |


| `configure_host.py`  | Prepares host (hostname, sshd, repos)     |

Note: the attached example is for at laptop installation - Change the appropriate usernames, SSID and passwords.
## Create a USB key with Windows 11 unattended installation
* Run the "customize_win11_iso.sh" script to create the USB with unattended installation

