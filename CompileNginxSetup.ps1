<#
  Author:  Solaris765
  Version: 0.1
  Purpose: Prepair MinGW env for compiling nginx on windows.
#>

#Must run elevated.
function selfElevate {
    #Author: https://social.msdn.microsoft.com/profile/Benjamin+Armstrong
    #Source: https://blogs.msdn.microsoft.com/virtual_pc_guy/2010/09/23/a-self-elevating-powershell-script/
    #I turned original file into a function
    param (
    [parameter (Mandatory=$true)]
    [string]$Script
    )
    
	# Get the ID and security principal of the current user account
	$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
	$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
	
	# Get the security principal for the Administrator role
	$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
	
	# Check to see if we are currently running "as Administrator"
	if ($myWindowsPrincipal.IsInRole($adminRole))
	{
		# We are running "as Administrator" - so change the title and background color to indicate this
		$Host.UI.RawUI.WindowTitle = $Script + "(Elevated)"
		$Host.UI.RawUI.BackgroundColor = "DarkBlue"
		clear-host
	}
	else
	{
		# We are not running "as Administrator" - so relaunch as administrator
		
		# Create a new process object that starts PowerShell
		$newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
		
		# Specify the current script path and name as a parameter
		$newProcess.Arguments = $Script;
		
		# Indicate that the process should be elevated
		$newProcess.Verb = "runas";
		
		# Start the new process
		[System.Diagnostics.Process]::Start($newProcess);
		
		# Exit from the current, unelevated, process
		exit
	}
	
	# Run your code that needs to be elevated here
	Write-Host -NoNewLine "Press any key to continue...`n`n"
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
selfElevate -Script $myInvocation.MyCommand.Definition

#Download Lists
$PreMinGW = (# MinGW Block
        ('MinGW.exe'     ,'/passive',                                                          #Name ID 0, Params ID 1
            'https://downloads.sourceforge.net/project/mingw/Installer/mingw-get-setup.exe',   #LINK ID 2s
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                   #UserAgent ID 3
            $env:temp),                                                                       <#Download Location ID 4#>

####### TortoiseHG Block
        ('TortoiseHG.msi','/passive',                                                                                               
            'https://bitbucket.org/tortoisehg/files/downloads/tortoisehg-4.3.1-x64.msi',                                           
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                                                       
            $env:temp), 

####### ActivePearl Block
        ('ActivePearl.exe','/passive',                                                                                               
            'http://downloads.activestate.com/ActivePerl/releases/5.24.1.2402/ActivePerl-5.24.1.2402-MSWin32-x64-401627.exe',                                           
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                                                       
            $env:temp), 

####### 7-Zip Block
        ('7zip.exe','/S',                                                                                               
            'http://www.7-zip.org/a/7z1604-x64.exe',                                       
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                                                       
            $env:temp)
       )  

$PostMinGW = (# pcre8.41 Block
        ('pcre-8.41.zip'     ,'archive',                                                       
            'https://downloads.sourceforge.net/project/pcre/pcre/8.41/pcre-8.41.zip',  
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',           
            'dummy'),  #<- Fake location because set later in script

####### zlib-1.2.11 Block
        ('zlib-1.2.11.zip','archive',                                                                                               
            'http://zlib.net/zlib1211.zip',                                           
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                                                       
            'dummy'),

####### openssl-1.0.2l Block
        ('openssl-1.0.2l.tar.gz','archive',                                                                                               
            'https://www.openssl.org/source/openssl-1.0.2l.tar.gz',                                           
            '[Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer',                                                       
            'dummy')
       )  


#Downloads A File
function downloadFile {
    param (
     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Name,

     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Link,

     [parameter(Mandatory=$true)]$userAgent,

     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Location
    )

    Invoke-WebRequest -Uri $Link -OutFile ($Location + '\' + $Name) -UserAgent $userAgent | out-null
}

#Downloads arrays of files if array contains install parameters, install current file.
function downloadArray {
    param (
     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Array
     )
     
     foreach ($item in $Array) {
     cd $item[4]
     downloadFile $item[0] $item[2] $item[3] $item[4]

     If ($item[1] -eq 'archive') { unzip $item[0] }

     #If array has parameters, Install File
     ElseIf ($item[1]) { Start-Process $item[0] $item[1] }
     }
}

function unzip {
param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Name
    )

    If ($Name -like '*tar.gz*') { 
        7z 'e', $Name, $Name.Substring(0,$Name.Lastindexof('.'))
        $Name = $Name.Substring(0,$Name.Lastindexof('.'))
        7z 'x', $Name, $Name.Substring(0,$Name.Lastindexof('.')) 
        }
    Else { 7z 'x', $Name, $Name.Substring(0,$Name.Lastindexof('.')) }
}

function addToPath {
param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Name    
    )

    If ($env:path -notlike ('*' + $Name + '*')) {
    $SystemPath = regGetKey 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'Path'
    $SystemPath += (';'+ $Name)
    regKeyCreate 'HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment' 'Path' $SystemPath
    }
}
function refreshEnvVars {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

#Reg Fns from RegistryTools.ps1 Added to code to keep 1 file tool.
function regKeyCreate {

param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Path,

    [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Name,

    [parameter(Mandatory=$false)]$Value
    )

    If (!$Value) {$Value = $Null}
    
    #Trim to file name
    if ($Name.LastIndexOf('\')[0] -gt 0) {
        $Path += $Name.Substring(0, $Name.LastIndexOf("\")[0])
        $Path.Replace("\\","\")

        $Name = $Name.Substring($Name.LastIndexOf("\")[0]+1)
    }
    
    #Make Path
    IF (-Not (regCheckPath -Path $Path)) {New-Item -Path $Path}
    
    #Make Key
    IF (regCheckKey -Path $Path -Name $Name) {
            If ($Value -eq $null ) { write-host "Key Exists" }
            Else { Set-ItemProperty -Path $Path -Name $Name -Value $Value }
        }
    Else {
        write-host "Key Created"
        If ($value -eq $null) { New-ItemProperty -Path $Path -Name $Name -Value 1 }
        Else { New-ItemProperty -Path $Path -Name $Name -Value $Value }
        }
}
function regGetKey {

    param (
     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Path,
    
    [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Name
    )
    
    #Check if Key Exists and has a value
    try {
        return Get-ItemPropertyValue -Path $Path -Name $Name 
        } 
    catch {
        return $Null
        }

}
function regCheckKey {

    param (
     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Path,
    
    [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Name
    )
    
    #Check if Key Exists and has a value
    try {
        $dummy = Get-ItemPropertyValue -Path $Path -Name $Name 
        return $true
        } 
    catch {
        return $false
        }

}      
function regCheckPath {

    param (
     [parameter(Mandatory=$true)]
     [ValidateNotNullOrEmpty()]$Path
    )
    
    $dummy = Get-Item -Path $Path -ErrorVariable ErrorVar -ErrorAction SilentlyContinue

    #Check if Path Exists
    If ($ErrorVar) {
            return $false
        } 
    Else {
            return $true
        }

}                                                                                         

downloadArray $PreMinGW

#---------------------------------------------------------------------------
 $MinGWBin = "C:\MinGW" #<- sets to default instal location
 
 [void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
 $temp = [Microsoft.VisualBasic.Interaction]::InputBox('Leave blank if Path is "C:\MinGW"', 'MinGW Path')
 
 #If not blank set to install location
 If ($temp) {$MinGWBin = $temp}
#---------------------------------------------------------------------------

#Permanately installs MinGW's bin directory into System Path
addToPath ($MinGWBin + '\bin')

#Refresh Environment Variables
refreshEnvVars
$env:Path += (';' + $env:ProgramFiles + '\7-zip')

#Launching MinGW by full Path b/c powershell will need to be restarted before Env Var changes are recognized
& 'mingw-get.exe' 'install', 'mingw-developer-toolkit', 'mingw32-gcc-g++'

#Sets up Msys Directories
$MsysHome = $MinGWBin + '\msys\1.0\home\' + $env:USERNAME
mkdir $MsysHome
CD $MsysHome

#Clones Nginx source to home folder
hg 'clone', 'http://hg.nginx.org/nginx' | Out-Null

ForEach ($item in $PostMinGW) {$Item[4] = $MsysHome + '\nginx\objs\lib'}

#Creates Download location for Modules and Downloads them.
mkdir ($MsysHome + '\nginx\objs\lib')
downloadArray $PostMinGW

$Unzipped = @()
foreach ($item in $PostMinGW) {
    $Name=$item[0]
    If ($Name -like '*tar.gz*') { 
        $Name = $Name.Substring(0,$Name.Lastindexof('.'))
        $Name = $Name.Substring(0,$Name.Lastindexof('.'))
        }
    Else { $Name = $Name.Substring(0,$Name.Lastindexof('.')) } 
    $Unzipped += $Name 
    }

#Opens Folder and directs first compile
Start-Process ($MinGWBin + '\msys\1.0\msys.bat')
[System.Windows.Forms.MessageBox]::Show("`"msys.bat`" will open automatically.

Type `"cd nginx`" into the prompt then
Hit `"OK`" to copy the below to your clipboard and paste it in the command prompt.

-------------------------------------------------------------------------------------
auto/configure --with-cc=gcc --builddir=objs --prefix= \
--conf-path=conf/nginx.conf --pid-path=logs/nginx.pid \
--http-log-path=logs/access.log --error-log-path=logs/error.log \
--sbin-path=nginx.exe --http-client-body-temp-path=temp/client_body_temp \
--http-proxy-temp-path=temp/proxy_temp \
--http-fastcgi-temp-path=temp/fastcgi_temp \
--http-uwsgi-temp-path=temp/uwsgi_temp \
--http-scgi-temp-path=temp/scgi_temp \
--with-cc-opt=-DFD_SETSIZE=1024 --with-pcre=objs/lib/" + $Unzipped[0] + " \
--with-zlib=objs/lib/" + $Unzipped[1] + " --with-openssl=objs/lib/" + $Unzipped[2] + " \
--with-select_module --with-http_stub_status_module --with-http_ssl_module \
--with-http_v2_module --with-http_auth_request_module
-------------------------------------------------------------------------------------
   
")

"auto/configure --with-cc=gcc --builddir=objs --prefix= \
--conf-path=conf/nginx.conf --pid-path=logs/nginx.pid \
--http-log-path=logs/access.log --error-log-path=logs/error.log \
--sbin-path=nginx.exe --http-client-body-temp-path=temp/client_body_temp \
--http-proxy-temp-path=temp/proxy_temp \
--http-fastcgi-temp-path=temp/fastcgi_temp \
--http-uwsgi-temp-path=temp/uwsgi_temp \
--http-scgi-temp-path=temp/scgi_temp \
--with-cc-opt=-DFD_SETSIZE=1024 --with-pcre=objs/lib/" + $Unzipped[0] + " \
--with-zlib=objs/lib/" + $Unzipped[1] + " --with-openssl=objs/lib/" + $Unzipped[2] + " \
--with-select_module --with-http_stub_status_module --with-http_ssl_module \
--with-http_v2_module --with-http_auth_request_module" | clip.exe;


[System.Windows.Forms.MessageBox]::Show("When the configuration step is done hit `"OK`" to copy the line below to clipboard.
Run this in the prompt to build the nginx executable.
When it is finished be sure to check that the nginx.exe file in " + $MsysHome + '\nginx\objs\' + " works correctly.

-------------------------------------------------------------------------------------
make -f objs/Makefile
-------------------------------------------------------------------------------------")

"make -f objs/Makefile"| clip.exe;
