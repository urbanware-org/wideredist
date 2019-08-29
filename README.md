# *WiDeRedist* <img src="https://raw.githubusercontent.com/urbanware-org/wideredist/master/wideredist.png" alt="WiDeRedist logo" height="48px" width="48px" align="right"/>

**Table of contents**
*   [Definition](#definition)
*   [Details](#details)
*   [Requirements](#requirements)
*   [Installation](#installation)
*   [Contact](#contact)
*   [Useless facts](#useless-facts)

----

## Definition

Special tool to update the *Windows Defender* definitions in the local network without client internet access via internal web server.

[Top](#wideredist-)

## Details

This project was not developed to lock out or even screw *Microsoft*, rather than for updating *Windows Defender* definitons (or signatures) in internal environments that are completely separated from the internet.

Nevertheless, this requires at least one system to access the internet, of course.

This tool currently takes advantage of a *Linux* server which downloads the definition files and redistributes them using a web server and the *PowerShell* on the *Windows* systems to obtain the definition updates from that web server.

This tool is meant for advanced system administators. Furthermore, the project just contains basic scripts which work so far, but are in need of improvement (e. g. enhanced error handling and log output).

[Top](#wideredist-)

## Requirements

The project does not have many requirements.

*   ***Linux***:
    *   A web server such as *Apache* or *nginx* (latter has been used in development).
    *   The `wget` package (already pre-installed in most distributions).
*   ***Windows***:
    *   The *Windows Defender* as well as the *PowerShell* which are both already pre-installed, of course.

## Installation

### *Linux* part

#### Web server

As already mentioned above, you need a web server to provide the downloaded definitions.

Please do not ask me about the base configuration of a web server, as there are plenty how-tos online.

Below is a sample site config file for *nginx* listening on port 8080 using `/var/www/html/defender` as document root.

```nginx
server {
    listen 8080;
    root /var/www/html/defender;
    location / {
        autoindex on;
    }
}
```

When finished, create the corresponding directory

```bash
mkdir -p /var/www/html/defender
```

with a `test` file inside it:

```bash
touch /var/www/html/defender/test
```

Now you can test if the web server works by restarting its service, opening a browser and navigating to the corresponding URL, for example `http://192.168.2.1:8080`. You should see a typical index page with the heading `Index of /` there and the `test` file listed below.

After that, you can remove the `test` file again:

```bash
rm -f /var/www/html/defender/test
```

#### *WiDeRedist* script and config

As **root**, create the directory `/opt/wideredist` and copy the `wideredist.sh` as well as `wideredist.conf` there. The script should already be executable. If not (for whatever reason), run the following command to set the executable flag:

```bash
chmod +x /opt/wideredist/wideredist.sh
```

Inside the `wideredist.conf` file you can also set the directory where the definition files should be downloaded to and proxy settings (if required). Notice that if you change the definition path inside the config file, you also have to apply that change to your web server config.

Manually run the script as follows to see if it works as expected:

```bash
/opt/wideredist/wideredist.sh
```

In case the download fails, check if the settings inside `wideredist.conf` are correct and that the system is able to access the internet.

#### Cronjob

Finally, you may add a cronjob to `/etc/crontab` to automatically download the latest definitions, e. g. each hour:

```bash
# Download and redistribute latest Windows Defender definitions
* */1 * * * root /opt/wideredist/wideredist.sh &>/dev/null
```

### *Windows* part

#### *DefenderUpdate* script

The *PowerShell* script has been developed on *Windows Server 2016* and successfully tested on that operating system as well as *Windows 10* so far.

Create two directories on your system (for example)

*   `C:\Defender` (where the *Windows Defender* definitions will be stored in)
*   `C:\Tools\WiDeRedist` (the directory that contains the script files)

and copy the files `DefenderUpdate.ps1` as well as `Update.ini` into `C:\Tools\WiDeRedist`.

Edit the file `Update.ini` and adjust the network settings (web server IP address and port).

Then, run the *PowerShell* with **administrative privileges**. Inside that shell, execute the script as follows:

```cmd
powershell -ExecutionPolicy Bypass -Command C:\Tools\WiDeRedist\DefenderUpdate.ps1
```

In case the download fails, check the configuration of the web server as well as the network settings inside `Update.ini`.

#### Scheduled update task

In order to automatically update the *Windows Defender* definitions, you may use the *Windows* task scheduler to setup the update cycles. Notice that the task must be executed with an account that has **administrative privileges** as well as the preference **Run whether user is logged on or not** enabled.

For the task scheduler, the command to execute requires the full path to `powershell.exe`, so it looks like this:

```cmd
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -Command C:\Tools\WiDeRedist\DefenderUpdate.ps1
```

[Top](#wideredist-)

## Contact

Any suggestions, questions, bugs to report or feedback to give?

You can contact me either by sending an email to <dev@urbanware.org> or by opening a *GitHub* issue (which I would prefer if you have a *GitHub* account).

[Top](#wideredist-)

## Useless facts

*   The project name is an abbreviation for ***Wi**ndows* ***De**fender* *Definition* ***Redist**ribution* (the second and thus repetitive "De" was omitted).

[Top](#wideredist-)
