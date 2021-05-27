### <img src="https://raw.githubusercontent.com/urbanware-org/hello_world/master/stuff/sign_warning/sign_warning_48x48.png" alt="Important" height="48px" width="48px" align="left"/>Please update to the <a href="https://github.com/urbanware-org/wideredist/releases/latest">latest version</a>, as earlier may not work anymore.<br/>[Details](https://github.com/urbanware-org/wideredist/wiki#required-update-for-old-versions)</a>

Furthermore, it is recommended to run either the server-side or client-side script manually once in a while. Since version 1.2.9 both of the scripts return if a newer version is available.

:floppy_disk: Latest program version: **1.4.4** (**2021-02-03**)

:scroll: Download link file (`wideredist.conf`) date: **2020-06-26**

--------

# *WiDeRedist* <img src="https://raw.githubusercontent.com/urbanware-org/wideredist/master/wideredist.png" alt="WiDeRedist logo" height="128px" width="128px" align="right"/>

**Table of contents**
*   [Definition](#definition)
*   [Details](#details)
*   [Requirements](#requirements)
*   [Installation](#installation)
*   [Contact](#contact)
*   [Useless facts](#useless-facts)

----

## Definition

Dedicated tool to update the *Windows Defender* definitions in the local network without client internet access via internal web server.

[Top](#wideredist-)

## Details

This project was not developed to lock out or even screw *Microsoft*, rather than for updating *Windows Defender* definitons (or signatures) in internal environments that are completely separated from the internet.

Nevertheless, this requires at least one system to access the internet, of course.

This tool currently takes advantage of a *Linux* server (or alternatively *BSD*) which downloads the definition files and redistributes them using a web server and the *PowerShell* on the *Windows* systems to obtain the definition updates from that web server.

[Top](#wideredist-)

## Requirements

The project does not have many requirements.

*   ***Linux*** or ***BSD***:
    *   Some web server such as *Apache* or *nginx* (latter has been used in development).
    *   The `rsync` package (should already be pre-installed, depending on the distribution).
    *   The `wget` package (should already be pre-installed, also depending on the distribution).
    *   The *Bash* shell (default in most *Linux* distributions, but usually not on *BSD*).
*   ***Windows***:
    *   The *Windows Defender* as well as the *PowerShell* which should both be already pre-installed.

## Installation

You can find the documentation containing the installation instructions and further information inside the [wiki](https://github.com/urbanware-org/wideredist/wiki).

[Top](#wideredist-)

## Contact

Any suggestions, questions, bugs to report or feedback to give?

You can contact me by sending an email to [dev@urbanware.org](mailto:dev@urbanware.org) or by opening a *GitHub* issue (which I would prefer if you have a *GitHub* account).

[Top](#wideredist-)

## Useless facts

*   The project name is an abbreviation for ***Wi**ndows* ***De**fender* *Definition* ***Redist**ribution* (the second and thus repetitive "De" was omitted).

[Top](#wideredist-)
