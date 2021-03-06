$registerLocations = New-Object System.Collections.ArrayList;

$registeredDependencies = New-Object System.Collections.ArrayList;

function Resove-Repository-Url($uri) {
	$uriBuilder = new-object system.UriBuilder($uri);
	switch ($uri.Scheme) 
    { 
		"psregister" {
			$uriBuilder.Scheme = [System.Uri]::UriSchemeHttp;
		}
		"psregister-secure" {
			$uriBuilder.Scheme = [System.Uri]::UriSchemeHttps;
		}
	}
	return $uriBuilder.Uri;
}

function Get-All-Repositories-From-Remote($uri) {
	$client = new-object system.net.webclient;
	$repositoryUrl = "$(Resove-Repository-Url($uri))repos";
	
	try {
		[xml]$repoInformation = $client.DownloadString($repositoryUrl);
	} catch {
		return $null;
	}
	
	$repos = @();
	foreach($repo in $repoInformation.psregister.repos.repo) {
		$repos += $repo.'#text';
	}
	return $repos;
}

function Get-Repository-From-Remote($uri, $dependency, $version = "latest") {
	$localRepoStore = [System.IO.Path]::Combine($env:TEMP, "psregister");
	
	if (-not (Test-Path $localRepoStore)) {
		new-item $localRepoStore -itemtype directory  | out-null
	}
	
	$client = new-object system.net.webclient;
	$repositoryUrl = "$(Resove-Repository-Url($uri))repos/$dependency/$version";
	
	try {
		[xml]$repoInformation = $client.DownloadString($repositoryUrl);
	} catch {
		return $null;
	}	
	
	$localRepoStore = [System.IO.Path]::Combine($localRepoStore, $dependency);
	
	if (-not (Test-Path $localRepoStore)) {
		new-item $localRepoStore -itemtype directory  | out-null
	}
	
	$localRepoStore = [System.IO.Path]::Combine($localRepoStore, $repoInformation.psregister.version);
	
	if (-not(Test-Path $localRepoStore)) {
		new-item $localRepoStore -itemtype directory | out-null
	}
	
	$localVersionedRepoStore = [System.IO.Path]::Combine($localRepoStore, $dependency);
	
	if (Test-Path $localVersionedRepoStore) {
		return $localRepoStore;
	}
	
	new-item $localVersionedRepoStore -itemtype directory | out-null
	
	foreach($file in $repoInformation.psregister.files.file) {
		$fileUrl = "$($repositoryUrl)/$($file.'#text')";
		$targetLocation = [System.IO.Path]::Combine($localVersionedRepoStore, $file.'#text')
		$client.DownloadFile($fileUrl, $targetLocation);
	}
	
	return $localRepoStore;
}

function PrintLocation($source, $repo) {
	
	Write-host "PSRegister " -ForegroundColor Green -BackgroundColor DarkBlue -NoNewline
	if (Is-Registered($repo)) {
		Write-host "[$source][registered] " -ForegroundColor Green -BackgroundColor DarkBlue -NoNewline
	} else {
		Write-host "[$source][not registered] " -ForegroundColor Yellow -BackgroundColor DarkBlue -NoNewline
	}
	Write-Host $repo -ForegroundColor White -BackgroundColor DarkBlue
}

function Log($message) {
	Write-host "PSRegister " -ForegroundColor Green -BackgroundColor DarkBlue -NoNewline
	Write-Host "$(Get-Date) " -ForegroundColor Green -BackgroundColor DarkBlue -NoNewline
	Write-Host $message -ForegroundColor White -BackgroundColor DarkBlue
}

function LogError($message) {
	Write-host "PSRegister " -ForegroundColor Red -BackgroundColor DarkBlue -NoNewline
	Write-Host "$(Get-Date) " -ForegroundColor Red -BackgroundColor DarkBlue -NoNewline
	Write-Host $message -ForegroundColor White -BackgroundColor DarkBlue
}

function Clean-Remote-Repositories() {
	$localRepoStore = [System.IO.Path]::Combine($env:TEMP, "psregister");
	rd -Recurse -Path $localRepoStore;
	Log "All temporary directories purged.";
}

function Sandbox() {
	$currentDir = (gmo PSRegister*).path;
	$locations = "";
	foreach($location in $script:registerLocations) {
		$locations += "Add-Register-Location `"$($location)`";";
	}
	powershell -noprofile -noexit -command "Import-Module $($currentDir) -DisableNameChecking;$locations";
}

function List-Available-Repositories {
	foreach($location in $script:registerLocations) {
		$uri = ([System.Uri]$location);
		$source = "undefined";
		
		if ($uri.Scheme.StartsWith("psregister") -eq $true) {
			$repos = Get-All-Repositories-From-Remote $uri;
			$source = $uri;
		}
		else {
			foreach($type in @("ps1", "psm1")) {				
				# will show all repos only if powershell v > 2, otherwise shows only the root path
				$repos += ls "$location/*.$type" -recurse | % {$_.BaseName};
				$source = $uri;
			}
		}
		
		foreach($repo in $repos) {	
			PrintLocation $source $repo;
		}
	}
}

function Register($dependency) {
	$ErrorActionPreference = "inquire"
	if (Is-Registered $dependency) {
		return;
	}
	
	foreach($location in $script:registerLocations) {
		$_location = $location;
		$uri = ([System.Uri]$location);
		if ($uri.Scheme.StartsWith("psregister") -eq $true) {
			$tempLocation =  Get-Repository-From-Remote $uri $dependency 
			if ($tempLocation -ne $null) {
				$_location = $tempLocation;
			}
		}
		
		foreach($type in @("ps1", "psm1")) {				
			if ($_location -ne $null) { 
				register-file $_location $dependency $type; 
				register-folder $_location $dependency $type; 
			}
		}
	}
	
	$script:registeredDependencies.Add($dependency) | Out-Null;
}

function Unregister($dependency) {
	$script:registeredDependencies.Remove($dependency) | Out-Null;
}

function Load-File($fileName, $type) {
	if ($type -eq "psm1")
    { 
		Import-Module $fileName -Global -DisableNameChecking;
		
		Log "module $([System.IO.Path]::GetFileNameWithoutExtension($filename)) loaded"
	}
	else {
		$scriptblock = get-content "$filename";
		$scriptblock = $scriptblock -replace '\s*function\s','function Global:';
		$scriptblock = $scriptblock -replace '#.*?','';
		try {
	    .([scriptblock]::Create($scriptblock));
		} catch {
			LogError "Cannot import $($fileName): $($_.Exception.Message)";
			$_.Exception >> "c:\temp\log";
			$scriptblock >> "c:\temp\log";
		}
		Log "script $([System.IO.Path]::GetFileNameWithoutExtension($filename)) loaded"
	}
}

function Register-File($location, $dependency, $type) {
	$fileName = "$($location)\$($dependency).$($type)";
	$pathExists = Test-Path -path "$($location)\$($dependency).$($type)" -PathType Leaf;
	if ($pathExists -eq $false) {
		return;
	}
	load-file $fileName $type;
}

Function Is-Registered([string]$dependency)
{ 
	$script:registeredDependencies.Contains($dependency);
}

function Register-Folder($location, $dependency, $type) {
	$pathExists = Test-Path -path "$($location)\$($dependency)" -PathType Container;
	if ($pathExists -eq $false) {
		return;
	}
	
	$fileEntries = [IO.Directory]::GetFiles("$($location)\$($dependency)", "*.$($type)"); 
	foreach($fileName in $fileEntries) 
	{ 
		load-file $fileName $type;
	}
}

function With-Configured-Locations() {
	$currentDir = [System.IO.Path]::GetDirectoryName((gmo PSRegister*).path);
	$repoConfigurationFile =  [System.IO.Path]::Combine($currentDir, "known-locations");
	
	if (-not(Test-Path -path $repoConfigurationFile)) {
		LogError "file with known locations does not exist";
		return;
	}
	
	cat $repoConfigurationFile | %{
		Add-Register-Location $_;
	};
	
	Log "all configured locations added";
}

function Add-Register-Location($location) {
	if ($script:registerLocations.Contains($location)) {
		Log "location $location is already known";
		return;
	}
	
	$script:registerLocations.Add($location) | Out-Null;
	Log "added location $location to known locations";
}

function Remove-Register-Location($location) {
	$script:registerLocations.Remove($location);
	Log "removed location $location from known locations";
}

Export-ModuleMember -function sandbox;
Export-ModuleMember -function register;
Export-ModuleMember -function Unregister;
Export-ModuleMember -Function with-configured-locations;
Export-ModuleMember -function add-register-location;
Export-ModuleMember -function remove-register-location;
Export-ModuleMember -function is-registered;
Export-ModuleMember -Function list-available-repositories;
Export-ModuleMember -Function Clean-Remote-Repositories;
