**Welcome to my guide on how I create a de-bloated WIN11 installation**

# Minimal Window 11 

This is my personal take on how I can run a minimal windows 11 on laptops and virtual..

My aim is to have a minimal and low footprint windows 11 installation without any - or only a minimal set - of the M365 cloud tools preinstalled, along with other MS "bloatware".

This is not my daily-driver. My daily-driver is a Ubuntu 24.04 with [Omakub](https://omakub.org/)on top. This is great for almost anything I need to do, however for now I still need to be able to run MS Excel with macros to complete some of my tasks - as an example. To do this i want to have small Windows 11 I can use.

The aim is to create a clean and easy way to bring up virtual machines or a computer with Windows 11, so if/when something is not working as expected I can just start over and deploy a new. 

# Steps

The steps I follow to create my Windows 11 are:
## Download Windows 11 from Microsoft
*  Go to [Download Windows 11](https://www.microsoft.com/da-dk/software-download/windows11) 
	* Go to the "Download Windows 11 Disk Image (ISO) for x64 devices" section
	* Select "Windows 11 (multi-edition ISO for x64 devices)"
	* Click "Download now"
	* Select the product language (I use English International)
	* Click "Confirm"
	* Go to the "Download – Windows 11 English International" section
	* Click "64-bit Download"
	* Verify upon completed download
		* 



Think of this project as the **foundation layer**: automation that bootstraps your virtual infrastructure, so your real IaC tooling has something solid to build on.
## Scripts & Structure

This project uses modular scripts backed by schema-validated YAML files.
Each script targets a single layer of Proxmox automation.

| Script               | Role                                      |
|----------------------|-------------------------------------------|
| `configure_host.py`  | Prepares host (hostname, sshd, repos)     |
| `create_template.py` | Converts a cloud image into a VM template |
| `create_guest.py`    | Clones and configures a guest VM          |

See `/md/` folder for in-depth descriptions and workflows.

## Design Highlights

- **Idempotent**: Re-runs safely — only applies config diffs.
- **Schema-validated**: YAML configs validated by `cerberus`.
- **Modular & inspectable**: Small tools, readable logs.
- **SSH-only**: No Proxmox API or web UI needed.

## Example Guest Config (YAML)

```yaml
name: "test-server"
id: 8888
clone_id: 9001
vlan: 254
driver: virtio
bridge: vmbr0
memory: 2048
ci_network: dhcp
