# PowahOS
Tools for CC:Tweaked for inventory management and autocrafting with the help of the create mod (6.0.0)
These tools are open source, do whatever modifications in your forks which are necessary to fit into your system

## Mod versions (depends)
Create >6.0.0\
CC: Tweaked >1.1

## Equipment
There are 4 types of computers with different functions (using AE2 as comparison)
- Slave computer: Connected to storage inventories (similar to ME drive and ME storage bus)
- Request computer: Allows for remote request of packages using Create's logistics network (similar to ME interface)
- Interface computer: Interface computer for easy item requests (similar to ME storage terminal)
- Master computer: A singular computer manages item requests and all slave computers (similar to ME controller)
- Insert computer: A computer to manage insertion into network (similar to ME interface)

## Installation
**format: REPO PROGRAM -> COMPUTER PROGRAM // Usage**\
you should use wget or pastebin to copy paste code easily into a computer\
**this should be done after wiring up everything**\
**A tutorial will be made on youtube**

**STEP 1: INSTALL MASTER COMPUTER PROGRAMS:**

master_init.lua -> /master_init.lua // Initialise master computer, establish connection and initialise slave computers\
master_main.lua -> /master_main.lua // Main program of the computer\
master_request.lua -> /master_request.lua // Module for accepting requests\
master_find.lua -> /master_find.lua // Module for finding items\
master_list.lua -> /master_list.lua // Module for listing items\
master_reboot.lua -> /master_reboot.lua // Simple script to reboot slave computers

**STEP 2: SLAVES CONFIG IN MASTER COMPUTER:**\
edit slaves.json -> /slaves.json\
this step is important for computers to recognize a slave's connected storage and packager.

**STEP 3: INSTALL SLAVE PROGRAMS:**\
slave_startup.lua -> /startup.lua // Immediately initialise a slave's function on startup\
edit /startup.lua to match correct interface and orientation

**STEP 4: INSTALL INTERFACE COMPUTER PROGRAMS**\
interface_get -> /get.lua // Program for obtaining items\
interface_find -> /find.lua // Program for finding items\
interface_list -> /list.lua // Program for listing items

**STEP 5 (OPTIONAL) INSTALL REQUEST COMPUTERS**

**RUNNING THE COMPUTER**
- run master_reboot to manage operations of slave computers
- run master_init to inspect network conditions and initialise slave machines
- run master_main if master_init reveals all system operational
- use interface computers as needed
