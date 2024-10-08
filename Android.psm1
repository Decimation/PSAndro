
<#
# Android utilities
#>


$global:RD_SD = 'sdcard/'

#region ADB completion

$script:AdbCommands = @(
	'push', 'pull', 'connect', 'disconnect', 'tcpip',
	'start-server', 'kill-server', 'shell', 'usb',
	'devices', 'install', 'uninstall'
	#todo...
)

Register-ArgumentCompleter -Native -CommandName adb -ScriptBlock {
	param (
		$wordToComplete,
		$commandAst,
		$fakeBoundParameters
	)
	
	$script:AdbCommands | Where-Object {
		$_ -like "$wordToComplete*"
	} | ForEach-Object {
		"$_"
	}
}


#endregion

#region [IO]

enum AdbDestination {
	Remote
	Local
}

enum Direction {
	Up
	Down
}

<# 
function Adb-SyncItems {
	param (
		[Parameter(Mandatory = $true)]
		[string]$remote,
		[Parameter(Mandatory = $false)]
		[string]$local,
		[Parameter(Mandatory = $true)]
		[AdbDestination]$d
	)
	
	#$remoteItems | ?{($localItems -notcontains $_)}
	
	#| sed "s/ /' '/g"
	#https://stackoverflow.com/questions/45041320/adb-shell-input-text-with-space
	
	$localItems = Get-ChildItem -Name
	$remoteItems = Adb-GetItems $remote
	$remote = Adb-Escape $remote Exchange
	
	#wh $remote
	switch ($d) {
		Remote {
			$m = Get-Difference $remoteItems $localItems
			
			foreach ($x in $m) {
				(adb push $x $remote)
			}
		}
		Local {
			$m = Get-Difference $localItems $remoteItems
			
			foreach ($x in $m) {
				(adb pull "$remote/$x")
			}
		}
		Default {
		}
	}
	return $m
} #>

<#
.Description
ADB enhanced passthru
#>
function adb {
	
	$argBuf = @()
	$argBuf += $args
	
	Write-Verbose "Original args: $(qjoin $argBuf)`n"
	
	switch ($argBuf[0]) {
		'push' {
			if ($argBuf.Length -lt 3) {
				$argBuf += 'sdcard/'
			}
		}
		Default {
		}
	}
	
	Write-Verbose "Final args: $(qjoin $argBuf)"
	
	adb.exe @argBuf
}

<#
.Description
Deletes file
#>
function Adb-RemoveItem {
	param (
		[Parameter(Mandatory = $true)]
		[string]$src
	)
	$a = @(Remove-Item "$src")
	Invoke-AdbShell @a
}

function Adb-Copy {
	param (
		$v
	)
	$s = "am start-activity -a android.intent.action.SEND -e android.intent.extra.TEXT '$v' -t 'text/plain' com.tengu.sharetoclipboard"
	$vv = @('shell', $s)
	return adb @vv

}



function Adb-GetDevices {
	$d = (adb devices) -as [string[]]
	$d = $d[1..($d.Length)]
	return $d
}

const P_SDCARD = 'sdcard/'

<# function Adb-QPush {
	
	param (
		$f,
		[parameter(Mandatory = $false)]
		$d = 'sdcard/'
	)

	if ($f -is [array]) {
		$f | Invoke-Parallel -Parameter $d -ImportVariables -Quiet -ScriptBlock {
			adb push "$_" $parameter
		}
	}
	else {
		adb push $f $d
	}
	
} #>


<# function Adb-QPull {
	param(
		$r, 
		[parameter(Mandatory = $false)] 
		$d = $(Get-Location), 
		[switch]$retain
	)
	
	
	if (-not (Test-Path $d)) {
		mkdir $d
	}
	$d = Resolve-Path $d

	Write-Host "$d"
	Read-Host -Prompt "..."
	$r = Adb-GetItems $r -t 'f'


	$st1 = Get-Date

	$r | Invoke-Parallel -Parameter $d -ImportVariables -Quiet -ScriptBlock {
		
		$vx = adb pull $_ "$parameter"
		Write-Verbose "adb >>> $vx"
		

		# $sz = (Get-ChildItem $parameter).count
		$global:SyncState.Counter++
		Write-Host "`r$($global:SyncState.Counter)" -NoNewline

		# $SyncTable.c++
		# Write-Host "`r $($SyncTable.c)/$($SyncTable.l)" -NoNewline

		# Write-Progress -Activity g -PercentComplete (($i / $l) * 100.0)
	}
	
	Write-Host
	$st2 = Get-Date
	$delta = $st2 - $st1
	Write-Host "$($delta.totalseconds)"
	#todo
	
	$global:SyncState = $global:SyncStateEmpty.psobject.copy()
} #>

$global:SyncStateEmpty = [hashtable]::Synchronized(
	@{
		c       = 0 
		l       = 0
		Counter = 0
	}
)

$global:SyncState = $global:SyncStateEmpty.psobject.copy()



function Adb-GetItemsDifference {
	[CmdletBinding()]
	[outputtype([AdbItem[]])]
	param (
		[Parameter(Mandatory, Position = 0)]
		$RemotePath,
		[Parameter(Mandatory, Position = 1)]
		$LocalPath
	)

	$remoteItems = Adb-GetItems $RemotePath
	$localItems = Get-ChildItem $LocalPath
	$localNames = $localItems | Select-Object -ExpandProperty Name
	$diff = $remoteItems | Where-Object { $localNames -notcontains $_.Name }
	return $diff
}

class AdbItem {
	[bool]$IsDirectory
	[bool]$IsFile
	[string]$Name
	[string]$FullName
	[string]$Permissions
	[string]$Links
	[string]$Owner
	[string]$Group
	[string]$Size
	[string]$Date
	[string]$Time
	[bool]$NameError
}

function Adb-QPull {
	param (
		$Items,
		$Destination = $(Get-Location)
	)
	begin {

	}
	process {
		if (-not (Test-Path $Destination)) {
			mkdir $Destination
		}
		$Destination = Resolve-Path $Destination
		$global:SyncState.l = $Items.Length
		
		$z = Invoke-Parallel -InputObject $Items -Parameter $Destination -ImportVariables -Quiet -ScriptBlock {
			$src = $_.FullName
			$dst = "$parameter\$($_.Name)"
			adb pull -a $_.FullName $dst
			<# $dst = "$parameter\$($_.Name)"
			$dst = Resolve-Path $dst
			$dst = $dst.Path
			$dst = $dst.Replace('Microsoft.PowerShell.Core\FileSystem::', '') #>

			$global:SyncState.Counter++
			# Write-Host "`r$($global:SyncState.Counter)" -NoNewline

			# $SyncTable.c++
			# Write-Host "`r $($SyncTable.c)/$($SyncTable.l)" -NoNewline

			# Write-Progress -Activity g -PercentComplete (($i / $l) * 100.0)

			Write-Progress -Activity 'Pulling' -Status $src -PercentComplete (($global:SyncState.Counter / $global:SyncState.l) * 100.0)
		}
	}
	end {
		$global:SyncState = $global:SyncStateEmpty.psobject.copy()

	}
}

function Adb-GetItems {
	[CmdletBinding()]
	[outputtype([AdbItem[]])]
	param (
		[Parameter(Mandatory, Position = 0)]
		$Path,
		[Parameter()]
		[switch]$Recurse
	)
	
	<# $r = Adb-Find -x $x -type $t
	$r = [string[]] ($r | Sort-Object)

	if ($pattern) {
		$r = $r | Where-Object {
			$_ -match $pattern 
		}
	}
	
	return $r #>

	$lsArgs = '-lap'
	if ($Recurse) {
		$lsArgs += 'R'
	}

	return Invoke-AdbShell "ls $lsArgs $Path" | Select-Object -Skip 2 | ForEach-Object {
		$val = $_ -split '\s+'
		$rn = $val[7..$val.Length] -join ' '
		$fn = $(Join-Path $Path $rn) -replace '\\', '/'
		$buf = [AdbItem] @{
			IsDirectory = $val[0] -match 'd'
			IsFile      = $val[0] -match '^-'
			Permissions = $val[0]
			Links       = $val[1]
			Owner       = $val[2]
			Group       = $val[3]
			Size        = $val[4]
			Date        = $val[5]
			Time        = $val[6]
			Name        = $rn.TrimEnd('/')
			FullName    = $fn
			NameError   = $false
		}
		$buf.NameError = $buf.FullName.Length -ge 260

		return $buf
	}
}

#endregion

Set-Alias Adb-GetItem Adb-Stat

function Invoke-AdbShell {
	$rg = @('shell', $args)
	adb @rg
}

function Adb-SendInput {
	param([parameter(ValueFromRemainingArguments)] $a)
	$x = @('input', $a)
	Invoke-AdbShell @x
}

function Adb-SendFastSwipe {
	param (
		[Parameter(Mandatory = $false)]
		[Direction]$d,
		[Parameter(Mandatory = $false)]
		[int]$t,
		[Parameter(Mandatory = $false)]
		[int]$c
	)
	
	if (!($t)) {
		$t = 25
	}
	
	if (!($d)) {
		$d = [Direction]::Down
	}
	
	while ($c-- -gt 0) {
		switch ($d) {
			Down {
				Adb-SendInput "swipe 500 1000 300 300 $t"
			}
			Up {
				Adb-SendInput "swipe 300 300 500 1000 $t"
			}
		}
		Start-Sleep -Milliseconds $t
	}
}


function Adb-List {
	param (
		$Path
	)
	
	$input2 = Adb-Escape $Path
	$a = @('ls', $input2) -join ' '
	Invoke-AdbShell $a
}

function Adb-Find {
	[CmdletBinding()]
	[outputtype([string[]])]
	param (
		# [Parameter(Mandatory = $true)]
		$x,
		
		[Parameter(Mandatory = $false)]
		$name,

		[parameter(Mandatory = $false)]
		$type,

		[parameter(Mandatory = $false)]
		$maxdepth = -1
	)
	#find . ! -name . -prune -type f -exec ls -ldi {} +
	#adb shell "find sdcard/* ! -name . -prune -type f -exec ls -ldi {} +"
	#adb shell "find sdcard/* ! -name . -prune -type f -exec ls -la {} \;"
	#adb shell "find sdcard/* ! -name . -prune -type f -exec ls -F {} \;"

	$fa = "%p\\n"
	# $ig = "2>&1 | grep -v `"Permission denied`""
	$a = @("find $x")
	#find 'sdcard/*' -type 'f' -maxdepth 0
	if ($name) {
		$a += '-name', $name
	}
	if ($type) {
		$a += '-type', $type
	}
	if ($maxdepth -ne -1) {
		$a += '-maxdepth', $maxdepth
	}
	$a += '-printf', $fa
	
	$r = Invoke-AdbShell @a
	
	#TODO

	# $r = $r[1..$r.Length]
	
	return $r
}

function Adb-Stat {
	param (
		$x
	)
	
	$x = Adb-Escape -x $x -e Shell
	
	$d = "   "

	$a = "%n", `
		"%N", `
		"%F", `
		"%w", `
		"%x", `
		"%y", `
		"%z", `
		"%s" `
		-join $d

	$cmd = @("stat -c '$a' $x")
	$out = [string] (Invoke-AdbShell @cmd)
	$rg = $out -split $d
	$i = 0

	$origName = $rg[$i++] -split '/' | Select-Object -Last 1

	$obj = [PSCustomObject]@{
		Name             = $origName
		FullName         = $rg[$i++]
		Type             = $rg[$i++]
		TimeOfBirth      = $rg[$i++]
		LastAccess       = $rg[$i++]
		LastModification = $rg[$i++]
		LastStatusChange = $rg[$i++]
		Size             = $rg[$i++]
		
		IsDirectory      = $null
		IsFile           = $null
		
		Raw              = $out
		Input            = $cmd
	}

	$obj.IsDirectory = $obj.Type -match 'directory'
	$obj.IsFile = $obj.Type -match 'file'
	
	<# $cmd = @('shell', "stat $x")
	$out = [string] (adb @cmd)
	$rg = $out -split "`n" | ForEach-Object { $_.Trim() } 
	#>
	

	# $statArgs = '%n %F %w %x %y %z %s'
	# $cmd = "for file in *; do stat -c $statArgs `$file; done"
	
	<#region
	
	Toybox 0.8.9-android multicall binary (see toybox --help)

	usage: stat [-tfL] [-c FORMAT] FILE...

	Display status of files or filesystems.

	-c      Output specified FORMAT string instead of default
	-f      Display filesystem status instead of file status
	-L      Follow symlinks
	-t      terse (-c "%n %s %b %f %u %g %D %i %h %t %T %X %Y %Z %o")
				(with -f = -c "%n %i %l %t %s %S %b %f %a %c %d")

	The valid format escape sequences for files:
	%a  Access bits (octal) |%A  Access bits (flags)|%b  Size/512
	%B  Bytes per %b (512)  |%C  Security context   |%d  Device ID (dec)
	%D  Device ID (hex)     |%f  All mode bits (hex)|%F  File type
	%g  Group ID            |%G  Group name         |%h  Hard links
	%i  Inode               |%m  Mount point        |%n  Filename
	%N  Long filename       |%o  I/O block size     |%s  Size (bytes)
	%t  Devtype major (hex) |%T  Devtype minor (hex)|%u  User ID
	%U  User name           |%x  Access time        |%X  Access unix time
	%y  Modification time   |%Y  Mod unix time      |%z  Creation time
	%Z  Creation unix time

	The valid format escape sequences for filesystems:
	%a  Available blocks    |%b  Total blocks       |%c  Total inodes
	%d  Free inodes         |%f  Free blocks        |%i  File system ID
	%l  Max filename length |%n  File name          |%s  Best transfer size
	%S  Actual block size   |%t  FS type (hex)      |%T  FS type (driver name)

	#>

	return $obj
}

<# 
function Adb-GetItem {
	
	param($x)
	return Adb-Stat $x

	# param (
	# 	$x,
	# 	[Parameter(Mandatory = $false)]
	# 	$x2
	# )
		
	# $a = @('shell', "wc -c $x", '2>&1')
	# $x = adb @a
	# $x = [string]$x
	# Write-Debug "$x| $(typeof $x)"

	# if ($x -match 'Is a directory') {
	# 	$isDir = $true
	# 	$isFile = $false
	# }
	# elseif ($x -match ('No such')) {
	# 	#...
	# 	return
	# }
	# else {
	# 	$isDir = $false
	# 	$isFile = $true
	# 	$size = [int]$x.Split(' ')[0]
	# }
	
	# $buf = @{
	# 	IsFile      = $isFile
	# 	IsDirectory = $isDir
	# 	Size        = $size
	# 	Orig        = $x
	# }
	
	
	# return $buf
} #>

function Adb-GetPackages {
	[outputtype([string[]])]
	param()

	$aa = ((adb shell pm list packages --user 0) -split 'package:') | Where-Object { $_ -ne '' }
	return [string[]] $aa
}


enum EscapeType {
	Shell
	Exchange
	Simple
}


function Adb-Escape {
	param (
		[Parameter(Mandatory = $true)]
		[string]$x,
		[Parameter(Mandatory = $false)]
		[EscapeType]$e = 'Shell'
	)
	
	switch ($e) {
		Shell {
			# $x = $x.Replace('`', [string]::Empty)
			$x = $x.Replace(' ', '\ ').Replace('(', '\(').Replace(')', '\)').Replace('"', '\"')
			
			return $x
		}
		Exchange {
			$s = $x.Split('/')
			$x3 = New-List 'string'
			
			foreach ($b in $s) {
				if ($b.Contains(' ')) {
					$b2 = "`"$b/`""
				}
				else {
					$b2 = $b
				}
				$x3.Add($b2)
			}
			return PathJoin($x3, '/')
		}
		Simple {
			return $x.Replace('"', '\"')
		}
		default {

		}
	}
}

function Adb-HandleSettings {
	param (
		$Operation,	$Scope, $Name
	)

	return adb shell settings $Operation $Scope $Name @args
}

function Adb-Paste {
	Adb-SendInput keyevent 279
	
}

function Adb-Screenshot {
	param (
		$FileName
	)
	adb exec-out screencap -p > $FileName
}

<# function Adb-GetAccessibility {
	[outputtype([string[]])]
	$s = Adb-HandleSettings 'get' 'secure' 'enabled_accessibility_services'

	$s2 = ($s -split '/') -as [string[]]
	return $s2
}

function Adb-AddAccessibility {
	param($n)
	$s2 = Adb-GetAccessibility
	$s2 += $n
	Adb-SetAccessibility $s2
}

function Adb-SetAccessibility {
	param($s2)
	$v = $s2 -join '/'
	Adb-HandleSettings 'put' 'secure' 'enabled_accessibility_services' $v
}

function Adb-RemoveAccessibility {
	param($n)
	$s2 = (Adb-GetAccessibility | Where-Object { $_ -ne $n })
	Adb-SetAccessibility $s2
} #>


# region Bluetooth

function Blt-Send {
	param($name, $f)

	return Start-Job -Name 'Blt' -ScriptBlock { 
		btobex.exe -n $using:name $using:f
	}
}

# endregion

function Adb-Pull {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[parameter(Mandatory, ParameterSetName = 'Default')]
		$Remote,
		[parameter(ParameterSetName = 'Default')]
		$Local,

		[parameter(ParameterSetName = 'Array', ValueFromPipeline)]
		$Items
	)
	process {

		if ($PSCmdlet.ParameterSetName -eq 'Array') {
			$n = 0
			foreach ($i in $Items) {
				$cmd = @('pull', '-a', $i, $Local)
				$s = adb @cmd
				$n++
				Write-Progress -Activity 'Pulling' -Status $i -PercentComplete (($n / $Items.Length) * 100.0)
			}
		}
		else {
			$cmd = @('pull', '-a', $Remote, $Local)
			$s = adb @cmd
			return $s
		}
	}

}
