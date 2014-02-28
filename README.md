PSRegistration-Tools
====================

A module that allows to import modules and files in a more readable syntax. It ultimatly allows you to specify required Modules at the beginning of your script, and the modules will be (down-)loaded automatically. 

Old way: 

    # check the readme file for required modules to add to this module
    Import-Module .\PSColorWriter.psm1; # <-This fails if module not available
    Write-Output-Color -Red "Look " -White "I have colors"; # <- This breaks if module not available
    
New way:

    register PSColorWriter; # <- This will download the module from the remote repository and import it
    Write-Output-Color -Red "Look " -White "I have colors";
    

## getting started

You can start and test the module by calling this one-liner:

    $f = "$env:TEMP/psregister.psm1";$c = new-object system.net.webclient;$c.DownloadFile("http://ow.ly/u5RmT", $f);Import-Module $f -DisableNameChecking;add-register-location "psregister://psreg.net/";

Otherwise clone this repo and open your Powershell Profile File and add the following line: 

    Import-Module path_to_the_file\PSRegister.psm1 -DisableNameChecking

Then you can add a [PSRegistration-Server](https://github.as24.local/mkainer/PSRegistration-Server) (this assumes you have one running locally)

    add-register-location psregister://localhost:1337/
    
For AutoScout24, there is a list with the known [PSRegistration-Server](https://github.as24.local/mkainer/PSRegistration-Server) available. You can add all known servers at once with the command

    With-Configured-Locations
    
Once this is done you can start by trying: 

    register PSColorWriter
    Write-Output-Color -Red "Look " -White "I have colors"

Which should then print colored output

## local locations

You might have a lot of components that are only on your machine and not on a PSRegistration-Server. You can add these files as well by adding a path as location. 
Let's try that.

If you look in the directory you can see the following subdirectories

    PS>ls C:\Projects\SMP\Production\SetupTesting | select Name
    
    Name
    ----
    Monitoring
    Msmq
    
Looking inside we can see there are files inside the directory

    PS>cd .\Msmq
    PS>ls | select Name
    
    Name
    ----
    msmq-tools.ps1
    msmq-helpers.ps1
    
Since we have added the location to the PSRegistration we can add both files easily like this: 

    register msmq
    
If we'd want to import only the msmq-tools file we would write

    register msmq-tools
    
## Sandbox

If you require a specific method of a dependency, and globally you are using another one, you can start the sandbox mode to get a clean shell. Just type

    sandbox

You can leave the sandbox mode by typing "powershell"    

## adding your own repository servers:

Insert a new line to the file [known-locations](https://github.as24.local/mkainer/PSRegistration/blob/master/known-locations) and push request your change

## List of commands

#### add-register-location

Adds a new location to the registration locations if not already added

*Usage:*

    add-register-location C:\Projects\SMP\Production\SetupTesting
    add-register-location psregister://asdw0435:1337/
    
#### with-configured-locations

Loads all configured locations 

*Usage:*

    with-configured-locations

### register

registers a module or ps1 file 

*Usage:* 

    register module
    
### is-registered module

checks if a module or ps1 file is registered

*Usage:* 

    is-registered module
    
Logic behind: 
  1. Use ps1 file with this name if it exists
  2. Use psm1 file with this name if it exists
  3. Use folder with this name and load all ps1 & psm1 files in it 

All 3 stages are done every time.

#### remove-register-location

Removes a location from the registered locations

*Usage:*

    add-register-location C:\Projects\SMP\Production\SetupTesting
    register msmq
    PSRegister 02/07/2014 12:27:21 script msmq-tools loaded
    remove-register-location C:\Projects\SMP\Production\SetupTesting

#### sandbox

Starts a shell without profile files, but with all locations from the current PSRegistration instance

*Usage:*

    sandbox
    register PSColorWriter
    PSRegister 02/07/2014 12:26:37 module PSColorWriting loaded
    Write-Output-Color -Red "Alert!"
    > "Alert!"
    powershell
    Write-Output-Color -Red "Alert!"
    > The term 'Write-Output-Color' is not recognized as the name of a cmdlet, function, script file, or operable program.
    
#### list-available-repositories

Lists all available repositories 

*Usage:*

    list-available-repositories
    
    > PSRegister [file:///c:/path_helpers][registered] browser-tool
    > PSRegister [file:///c:/path_helpers][not registered] file-replace
    > PSRegister [psregister://asdw0435:1337/][not registered] How-Are-We
    > PSRegister [psregister://asdw0435:1337/][registered] PSColorWriter
    
#### clean-remote-repositories

Cleans all temporary folders that are used for the remote repositories. Used for development

*Usage:*

    clean-remote-repositories
