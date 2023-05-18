function Use-Kde {
	return kdeconnect-cli.exe @args
	
}

function Use-KdeDevice {
	
	$args += @("-d", $global:KdeDevice)
	
	return Use-Kde @args
}

function Kde-GetFirstDevice {
	$x = Use-Kde -l
	$d1 = $x.Split('`n')[0].Split(':')[1].Trim().Split(' ')[0].Trim().Trim(' ')
	return $d1
}


$global:KdeDevice = Kde-GetFirstDevice

function Kde-Run {
	return (Use-KdeDevice @args)
}

function Kde-Share {
	param (
		[Parameter(ParameterSetName = 'File')]
		$Files,
		[Parameter(ParameterSetName = 'Dir')]
		$Dir
	)
	
	if ($Dir) {
		$Files = Get-ChildItem $Dir
	}

	Write-Debug "Files: $Files"

	$fn = {param($a) Use-KdeDevice @a}
	$Files | ForEach-Object {
		#Action that will run in Parallel. Reference the current object via $PSItem and bring in outside variables with $USING:varname

		$a=@('--share', $_)
		# kdeconnect-cli.exe @a
		Use-KdeDevice @a

	}
}