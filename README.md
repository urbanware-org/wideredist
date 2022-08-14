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

This project was not developed to lock out or even screw *Microsoft*, rather than for updating *Windows Defender* definitions (or signatures) in internal environments that are completely separated from the internet.

Nevertheless, this requires at least one system to access the internet, of course.

This tool currently takes advantage of a *Linux* server (or alternatively *BSD*) which downloads the definition files and redistributes them using a web server and the *PowerShell* on the *Windows* systems to obtain the definition updates from that web server.

[Top](#wideredist-)

## Requirements

The project does not have many requirements.

### Server

*   Either a ***Linux*** or ***BSD*** operating system
*   Some web server such as *Apache* or *nginx* (latter has been used in development)
*   The *Bash* shell (must be installed, but it does not have to be set as the default one)
*   The following tools or packages:
    *   `curl` or `wget`
    *   `file` (optional, used to verify the MIME type of the downloaded files)
    *   `rsync`

### Client

*   *Windows* 7 or higher with 32-bit or 64-bit architecture
*   *PowerShell* 2.0 or higher

## Installation

You can find the documentation containing the installation instructions and further information inside the [wiki](https://github.com/urbanware-org/wideredist/wiki).

Please keep *WiDeRedist* up to date, as earlier versions may not work anymore. Usually, outdated versions should not be a problem, but in the past there was the case that *WiDeRedist* did not download the definition files correctly, obviously because of a change on the side of the *Microsoft* servers. Details can be found [here](https://github.com/urbanware-org/wideredist/wiki#required-update-for-old-versions)</a>.

Anyway, it is recommended to run either the server-side or client-side script manually once in a while. Since version 1.2.9 both of the scripts return if a newer version is available, unless the update check was disabled.

[Top](#wideredist-)

## Contact

Any suggestions, questions, bugs to report or feedback to give?

You can contact us by sending an email to [dev@urbanware.org](mailto:dev@urbanware.org) or by opening a *GitHub* issue (which I would prefer if you have a *GitHub* account).

[Top](#wideredist-)

## Useless facts

*   The project name is an abbreviation for ***Wi**ndows* ***De**fender* *Definition* ***Redist**ribution* (the second and thus repetitive "De" from "Definition" was omitted).

[Top](#wideredist-)
