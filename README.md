# *WiDeRedist* <img src="https://raw.githubusercontent.com/urbanware-org/wideredist/master/wideredist.png" alt="WiDeRedist logo" height="128px" width="128px" align="right"/>

**Table of contents**

* [Definition](#definition)
* [Details](#details)
* [Requirements](#requirements)
* [Installation](#installation)
* [Contact](#contact)

----

## Definition

Dedicated tool to update the *Windows Defender* definitions in the local network without client internet access via internal web server.

[Top](#wideredist-)

## Details

The *WiDeRedist* project was not developed to lock out or even screw *Microsoft*, rather than for updating *Windows Defender* definitions (or signatures) in internal environments that are completely separated from the internet. However, this requires at least one system with access to the internet, of course.

It consists of two components. The server-side component takes advantage of a *Linux* server (or alternatively *BSD*) which downloads the definition files and redistributes them using a web server. The client-side component on *Windows* uses the *PowerShell* to obtain and install the definition updates provided by the web server.

This project transitioned into maintenance mode. Details can be found [here](https://github.com/urbanware-org/wideredist/wiki#maintenance-mode).

[Top](#wideredist-)

## Requirements

The project does not have many requirements.

### Server

* Either a ***Linux*** or ***BSD*** operating system
* Some web server such as *Apache* or *nginx* (latter has been used in development)
* The *Bash* shell (must be installed, but it does not have to be set as the default one)
* The following tools or packages:
  * `curl` or `wget`
  * `file` (optional, used to verify the MIME type of the downloaded files)
  * `rsync`

### Client

* *Windows 7* and above or *Windows Server 2016* and above
* *PowerShell* 2.0 or higher

In September 2024, it is still possible to manually update the *Windows Defender* definitions under *Windows 7* using the downloadable updates from the *Microsoft* website, even though the support of the operating was discontinued in January 2020.

## Installation

You can find the documentation containing the installation instructions and further information inside the [wiki](https://github.com/urbanware-org/wideredist/wiki).

Please keep *WiDeRedist* up to date, as earlier versions may not work anymore. Usually, outdated versions should not be a problem, but in the past there was the case that *WiDeRedist* did not download the definition files correctly, obviously because of a change on the side of the *Microsoft* servers. Details can be found [here](https://github.com/urbanware-org/wideredist/wiki#required-update-for-old-versions)</a>.

Anyway, it is recommended to run either the server-side or client-side script manually once in a while. Since version 1.2.9 both of the scripts return if a newer version is available, unless the update check was disabled.

[Top](#wideredist-)

## Contact

Any suggestions, questions, bugs to report or feedback to give?

You can contact us by sending an email to [dev@urbanware.org](mailto:dev@urbanware.org) or by opening a *GitHub* issue (which I would prefer if you have a *GitHub* account).

[Top](#wideredist-)
