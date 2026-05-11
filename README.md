# PowahOS
Tools for CC:Tweaked for inventory management and autocrafting with the help of the create mod (6.0.0)\
These tools are open source, do whatever modifications in your forks which are necessary to fit into your system

## Mod versions (depends)
Create >6.0.0\
CC: Tweaked >1.1

## Equipment
There are 4 types of computers with different functions (using AE2 as comparison)\
- Slave computer: Connected to storage inventories (similar to ME drive and ME storage bus)\
- Request computer: Allows for remote request of packages using Create's logistics network (similar to ME interface)\
- Interface computer: Interface computer for easy item requests (similar to ME storage terminal)\
- Master computer: A singular computer manages item requests and all slave computers (similar to ME controller)\

## Installation
format: REPO PROGRAM -> COMPUTER PROGRAM // Usage\
you should use wget or pastebin to copy paste code easily into a computer\

STEP 1: INSTALL MASTER COMPUTER PROGRAMS:

master_init.lua -> /master_init.lua // Initialise master computer, establish handshake with slave networks and start accepting requests (main program)\
master_request.lua -> /master_request.lua // Module for accepting requests\
master_find.lua -> /master_find.lua // Module for finding items\
master_list.lua -> /master_list.lua // Module for listing items\
master_reboot.lua -> /master_reboot.lua // Module for rebooting slaves\

STEP 2: SLAVES CONFIG:

edit slaves.json -> /slaves.json
