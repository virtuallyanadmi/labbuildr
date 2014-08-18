Param(
[Parameter(Mandatory=$false)][string]$Builddir = $PSScriptRoot,
[Parameter(Mandatory=$true)][string]$MasterVMX,
[Parameter(Mandatory=$false)][string]$Domainname,
[Parameter(Mandatory=$true)][string]$Nodename,
[Parameter(Mandatory=$false)][string]$CloneVMX = "$Builddir\$Nodename\$Nodename.vmx",
[Parameter(Mandatory=$false)][string]$vmnet ="vmnet2",
[Parameter(Mandatory=$false)][switch]$Isilon,
[Parameter(Mandatory=$false)][string]$scenarioname = "Default",
[Parameter(Mandatory=$false)][int]$Scenario = 1,
[Parameter(Mandatory=$false)][int]$ActivationPreference = 1,
#[string]$Build,
[Parameter(Mandatory=$false)][ValidateSet('XS','S','M','L','XL','TXL','XXL')]$Size = "M",
[switch]$Exchange,
[switch]$HyperV,
[switch]$NW,
[switch]$Gateway,
$Mountdrive = "c:"
# $Machinetype
)
$SharedFolder = "Sources"
$Origin = $MyInvocation.InvocationName
$Sources = "$MountDrive\sources"
$Adminuser = "Administrator"
$Adminpassword = "Password123!"
$BuildDate = Get-Date -Format "MM.dd.yyyy hh:mm:ss"
###################################################
### Node Cloning and Customizing script
### Karsten Bott
### 08.10.2013 Added vmrun errorcheck on initial base snap
###################################################
### $vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
### VMrun Error Condition help to tune the Bug wher the VMRUN COmmand can not communicate with the Host !
$VMrunErrorCondition = @("Waiting for Command execution Available","Error","Unable to connect to host.","Error: The operation is not supported for the specified parameters","Unable to connect to host. Error: The operation is not supported for the specified parameters")
### Sanity Check addd 02.09.2013#####
### Check for VMware Path from registry ###
function write-log {
    Param ([string]$line)
    $Logtime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
    Add-Content $Logfile -Value "$Logtime  $line"
}

function test-user {param ($whois)
$Origin = $MyInvocation.MyCommand
do {([string]$cmdresult = &$vmrun -gu $Adminuser -gp $Adminpassword listProcessesInGuest $CloneVMX )2>&1 | Out-Null

}
until (($cmdresult -match $whois) -and ($VMrunErrorCondition -notcontains $cmdresult))
write-log "$origin $UserLoggedOn"
}

####################################################
# Get VMWARE Directory from registry
<#
if (!(Test-Path $vmware)){
if (!(Test-Path "HKCR:\")) {New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT}
$VMWAREpath = Get-ItemProperty HKCR:\Applications\vmware.exe\shell\open\command
$VMWAREpath = Split-Path $VMWAREpath.'(default)' -Parent
$VMWAREpath = $VMWAREpath -replace '"',''
$VMWAREpath
$vmware = "$VMWAREpath\vmware.exe"
$vmrun = "$VMWAREpath\vmrun.exe"
} 
# End VMWare Path
#>

if (!(Get-ChildItem $MasterVMX -ErrorAction SilentlyContinue)) { write-host "Panic, $MasterVMX not installed"!; Break}
###################################################
# Setting Base Snapshot upon First Run
do {($Snapshots = &$vmrun listSnapshots $MasterVMX ) 2>&1 | Out-Null 
write-log "$origin listSnapshots $MasterVMX $Snapshots"
}
until ($VMrunErrorCondition -notcontains $Snapshots)
write-log "$origin listSnapshots $MasterVMX $Snapshots"

if ($Snapshots -eq "Total snapshots: 0") 
{
do {($cmdresult = &$vmrun snapshot $MasterVMX Base ) 2>&1 | Out-Null 
write-log "$origin snapshot $MasterVMXX $cmdresult"
}
until ($VMrunErrorCondition -notcontains $cmdresult)
}
write-log "$origin snapshot $MasterVMX $cmdresult"

if (Get-ChildItem $CloneVMX -ErrorAction SilentlyContinue ) {write-host "VM $Nodename Already exists, nothing to do here"
return $false
}

else
{
$Displayname = 'displayname = "'+$Nodename+'@'+$Domainname+'"'
Write-Host -ForegroundColor Gray "Creating Linked Clone $CloneVMX from $MasterVMX, VMsize is $Size"

# while (!(Get-ChildItem $MasterVMX)) {
# write-Host "Try Snapshot"

do {($cmdresult = &$vmrun clone $MasterVMX $CloneVMX linked Base )
write-log "$origin clone $MasterVMX $CloneVMX linked Base $cmdresult"
}
until ($VMrunErrorCondition -notcontains $cmdresult)
write-log "$origin clone $MasterVMX $CloneVMX linked Base $cmdresult"



# $Retval = &$vmrun clone $MasterVMX $CloneVMX linked Base 
# write-host $Retval

$Content = get-content $CloneVMX
$Content = $Content | where {$_ -NotMatch "memsize"}
$Content = $Content | where {$_ -NotMatch "numvcpus"}
<#
    $content = Get-Content "$Builddir\$vmname\$vmname.vmx" | where 
    $content += 'guestinfo.hypervisor = "'+$env:COMPUTERNAME+'"'
    $content = $content | where {$_ -NotMatch "guestinfo.powerontime"}
    $content += 'guestinfo.powerontime = "'+$VMXStarttime+'"'
    set-Content -Path "$Builddir\$vmname\$vmname.vmx" -Value $content -Force
#>


switch ($Size)
{ 
"XS"{
$content += 'memsize = "512"'
$Content += 'numvcpus = "1"'
}
"S"{
$content += 'memsize = "768"'
$Content += 'numvcpus = "1"'
}
"M"{
$content += 'memsize = "1024"'
$Content += 'numvcpus = "1"'
}
"L"{
$content += 'memsize = "2048"'
$Content += 'numvcpus = "2"'
}
"XL"{
$content += 'memsize = "4096"'
$Content += 'numvcpus = "2"'
}
"TXL"{
$content += 'memsize = "6144"'
$Content += 'numvcpus = "2"'
}
"XXL"{
$content += 'memsize = "8192"'
$Content += 'numvcpus = "4"'
}
}

$Content = $content | where { $_ -NotMatch "DisplayName" }
$content += $Displayname
Set-Content -Path $CloneVMX -Value $content -Force
$vmnetname =  'ethernet0.vnet = "'+$vmnet+'"'
# (get-content $CloneVMX) | foreach-object {$_ -replace 'displayName = "Clone of Master"', $Displayname } | set-content $CloneVMX
(get-content $CloneVMX) | foreach-object {$_ -replace 'gui.exitAtPowerOff = "FALSE"','gui.exitAtPowerOff = "TRUE"'} | set-content $CloneVMX
(get-content $CloneVMX) | foreach-object {$_ -replace 'ethernet0.vnet = "VMnet2"',$vmnetname} | set-content $CloneVMX
(get-content $CloneVMX) | foreach-object {$_ -replace 'mainMem.useNamedFile = "true"','' }| set-content $CloneVMX 
$memhook =  'mainMem.useNamedFile = "FALSE"'
add-content -Path $CloneVMX $memhook

if ($HyperV){
(get-content $CloneVMX) | foreach-object {$_ -replace 'guestOS = "windows8srv-64"', 'guestOS = "winhyperv"' } | set-content $CloneVMX
}


if ($Exchange){

copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\DB1.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\LOG1.vmdk
copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\DB2.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\LOG2.vmdk
copy-item $Builddir\Disks\DB1.vmdk $Builddir\$Nodename\RDB.vmdk
copy-item $Builddir\Disks\LOG1.vmdk $Builddir\$Nodename\RDBLOG.vmdk
$AddDrives = @('scsi0:1.present = "TRUE"','scsi0:1.fileName = "DB1.vmdk"','scsi0:2.present = "TRUE"','scsi0:2.fileName = "LOG1.vmdk"','scsi0:3.present = "TRUE"','scsi0:3.fileName = "DB2.vmdk"','scsi0:4.present = "TRUE"','scsi0:4.fileName = "LOG2.vmdk"','scsi0:5.present = "TRUE"','scsi0:5.fileName = "RDB.vmdk"','scsi0:6.present = "TRUE"','scsi0:6.fileName = "RDBLOG.vmdk"')
$AddDrives | Add-Content -Path $CloneVMX
}


if ($NW -and $gateway.IsPresent) {
$AddNic = @('ethernet1.present = "TRUE"','ethernet1.connectionType = "nat"','ethernet1.wakeOnPcktRcv = "FALSE"','ethernet1.pciSlotNumber = "256"','ethernet1.virtualDev = "e1000e"')
#,'ethernet1.virtualDev = "e1000"'
# ,'scsi0:2.fileName = "LOG1.vmdk"','scsi0:3.present = "TRUE"','scsi0:3.fileName = "RDB.vmdk"','scsi0:4.present = "TRUE"','scsi0:4.fileName = "RDBLOG.vmdk"')
$AddNic | Add-Content -Path $CloneVMX
}

######### next commands will be moved in vmrunfunction soon 
# KB , 06.10.2013 ##
$Addcontent = @()
$Addcontent += 'annotation = "This is node '+$Nodename+' for domain '+$Domainname+'|0D|0A built on '+(Get-Date -Format "MM-dd-yyyy_hh-mm")+'|0D|0A using labbuildr by @Hyperv_Guy|0D|0A Adminpasswords: Password123! |0D|0A Userpasswords: Welcome1"'
$Addcontent += 'guestinfo.hypervisor = "'+$env:COMPUTERNAME+'"'
$Addcontent += 'guestinfo.buildDate = "'+$BuildDate+'"'
$Addcontent += 'guestinfo.powerontime = "'+$BuildDate+'"'
Add-Content -Path $CloneVMX -Value $Addcontent
Set-VMXActivationPreference -config $CloneVMX -activationpreference $ActivationPreference
Set-VMXscenario -config $CloneVMX -Scenario $Scenario -Scenarioname $scenarioname
Set-VMXscenario -config $CloneVMX -Scenario 9 -Scenarioname labbuildr


Start-VMX -Path $CloneVMX




if (!$Isilon.IsPresent)
    {
    ###Enable Shared Folders
    Write-Output "Enabling Shared Folders"

    do { ($cmdresult = &$vmrun enableSharedFolders $CloneVMX)
write-log "$Origin enableSharedFolders $CloneVMX $cmdresult"

}
until ($VMrunErrorCondition -notcontains $cmdresult)
write-log "$Origin enableSharedFolders $CloneVMX $cmdresult"


do { ($cmdresult = &$vmrun addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder )
write-log "$Origin addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder $cmdresult"

}
until ($VMrunErrorCondition -notcontains $cmdresult)
write-log "$Origin addSharedFolder $CloneVMX $SharedFolder $Mountdrive\$SharedFolder $cmdresult"

#############
write-host $CloneVMX
Write-Host -ForegroundColor Yellow "Waiting for Pass 1 (sysprep Finished)"
test-user -whois Administrator
} #end not isilon

return,[bool]$True
}
