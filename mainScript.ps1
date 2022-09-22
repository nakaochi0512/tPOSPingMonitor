# このps1ファイルのフルパスのうち親ディレクトリまでのフルパスを取得して、カレントディレクトリを移動する
$path = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $path

#通信するIPアドレス
$addressList = @(
    "172.16.152.55",
    "172.16.151.56"
    )

#保存するフォルダ名
$folderName = @{
    info = "info"
    error = "error"
    device = "device"
    ping = "ping"
}

#ファイル名からPathを作成する関数
function createPath($folderList){
    $folderPathList = @{}
    foreach($folderName in $folderList.Values){
    $folderPathList[$folderName] += Join-Path .\log  $folderName
    }
    return $folderPathList
}

<#$foldernameで指定したディレクトリに特定のディレクトリがあるかを確認。ディレクトリがない場合は作成する。#>
 function confirm_directory($pathList){
    foreach($path in $pathList){
       if(Test-Path $path){
            }else{
               New-Item $path -ItemType Directory
           }
        }
}

#ネットワークチェック関数
function netWorkCheck(){
    $ipAddressList = Get-NetIPAddress
    foreach($ipAddress in $ipAddressList){
        logfile $folderName["info"] ($folderName["info"],$ipAddress.InterfaceAlias,$ipAddress.IPAddress)
    }
    $comPort = Get-WmiObject -Class Win32_SerialPort
    logfile $folderName["device"] ($comPort.Caption,$comPort.ProviderType)
    deviceCheck $folderName["device"]
    foreach($address in $addressList) {
        $pingResult = Test-Connection $address -Count 1 -Quiet
		logfile $foldername["info"] ($folderName["info"],$address,$pingResult)
        logfile $foldername["ping"] ($folderName["ping"],$address,$pingResult)
        if(!$pingResult){
            $getNetAdapterList =  Get-NetAdapter
                foreach($ipAddress in $ipAddressList){
                    logfile $folderName["error"] ($folderName["info"],$ipAddress.InterfaceAlias,$ipAddress.IPAddress)
                    }
            logFile $folderName["error"] ($folderName["info"],$address,$pingResult)
            logFile $folderName["error"] ($folderName["device"],$comPort.Caption,$comPort.ProviderType)
            deviceCheck $folderName["error"]
            foreach($getNetAdapter in $getNetAdapterList){
                logFile $folderName["error"] ($folderName["error"],$getNetAdapter.Name,$getNetAdapter.Status)
                }
            }
        }
    }


#正しく認識されていないデバイスをチェックする関数
function deviceCheck($folderName){
    $deviceList = Get-WmiObject Win32_PnpEntity
    $deviceResult = @()
    foreach($device in $deviceList){
        logFile $folderName ("device",$device.Caption,$device.PNPDeviceID,$device.ConfigManagerErrorCode)
    }
}

#ログファイルを生成する
function logFile($fileName,$logString){
    $folderName = Join-Path .\log  $fileName
    $Time = (Get-Date).ToString("yyyy-MM-dd")
    $logfile =  $Time + " " + $fileName + ".log"
    $logpath = Join-Path $folderName $logfile
    $Now = Get-Date
    # Log 出力文字列に時刻を付加(YYYY/MM/DD HH:MM:SS.MMM $LogString)
    $Log = $Now.ToString("yyyy/MM/dd HH:mm:ss.fff") + " "
    $Log += $logString-join","
    Write-Output $Log | Out-File -FilePath $logpath -Encoding Default -append
}

<#
#一番古いファイルを削除(90世代)
function deleteOldFile($folderPathList){
    foreach($foloderPath in $folderPathList){
        Get-ChildItem $folderPath       |
        Sort-Object LastWriteTime -Descending   |
        Select-Object -Skip 90                  |
        foreach{Remove-Item $_.FullName}
    }
}
#>

#新しいPingLogを取得
function Find-LatestPingLog($folderPathList){
    $result = @{}
    $pingLog = (Get-ChildItem $folderPathList["ping"] | Sort-Object LastWriteTime -Descending)[0].FullName
    $textlists = Get-Content $pingLog | Select-Object -Last 3 |
    ConvertFrom-Csv -Header @('date', 'ip', 'tf')
    foreach($textlist in $textlists){
        $result[$textlist.ip] += $textlist.tf
    }
    Write-Host $result["172.16.151.56"]
}


#logフォルダの作成
$folderPathList = createPath $folderName
Find-LatestPingLog $folderPathList


<#
confirm_directory $folderPathList
logfile $foldername["info"] "<START>"
logfile $foldername["error"] "<START>"
logfile $foldername["device"] "<START>"
netWorkCheck
deleteOldFile $folderPathList
logfile $foldername["info"] "<END>"
logfile $foldername["error"] "<END>"
logfile $foldername["device"] "<END>"
#>






