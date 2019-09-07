$ircregex = [Regex]::new("^(?:@([^ ]+) )?(?:[:]((?:(\w+)!)?\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.+))?$")
# $ircregex = [Regex]::new("^(?:@([^ ]+) )?(?:[:](\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.+))?$")

#^:(?<user>[a-zA-Z0-9_]{4,25})!\1@\1\.tmi\.twitch\.tv PRIVMSG #(?<channel>[a-zA-Z0-9_]{4,25}) :(?<message>.+)$ 

function Send {
    Write-Host $args[0]
    $writer.WriteLine("PRIVMSG #fourtf :$($args[0])")
    $writer.Flush()
}

#/([^=;]+)=([^;]*)/g
function Irc-Parse {
    $match = $ircregex.Match($args[0])

    $tags = $match.Groups[1].Value
    $prefix = $match.Groups[2].Value
    $user = $match.Groups[3].Value
    $command = $match.Groups[4].Value
    $params = $match.Groups[5].Value # channel for PRIVMSG
    $message = $match.Groups[6].Value

    #Write-Host "$user : [$message]"

    # elseif ($user -eq "fourtf" -and $message.StartsWith(">")) {

    if ($user -eq "fourtf" -and $message -eq "`$exit") {
        [Environment]::Exit(0)
    }
    elseif ($message.StartsWith(">")) {
        $words = $message.Substring(1).Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries);

        if ($words[0] -eq "ping") {
            Send("pong")
        }
    }
}

# $script = "`$user = $user; `$message = $message; $message"
# $ExecutionContext.InvokeCommand.ExpandString($message.Substring(1))
# Invoke-Expression $message.Substring(1)

# set current directory
Set-Location $PSScriptRoot
[System.Environment]::CurrentDirectory = $PSScriptRoot

# bot stuff
$botname = "pwshbot"
$botuid = "460607714"
$botcid = "g5zg0400k4vhrx2g6xi4hgveruamlv"

$conn = New-Object System.Net.Sockets.TcpClient
$conn.NoDelay = $true
$conn.SendBufferSize = 8192
$conn.ReceiveBufferSize = 8192

$conn.Connect("irc.chat.twitch.tv", 6697)
# $conn.Connect("irc.chat.twitch.tv", 6667)
# $conn.Connect("localhost", 6667)
$stream = $conn.GetStream()

Write-Output $conn.Active
Write-Host "asd"

$sslstream = New-Object System.Net.Security.SslStream $stream, true
$sslstream.AuthenticateAsClient("irc.chat.twitch.tv")

$writer = New-Object System.IO.StreamWriter $sslstream
$writer.NewLine = "`r`n"
$reader = New-Object System.IO.StreamReader $sslstream

$writer.WriteLine("PASS oauth:$(Get-Content ./token.txt)")
$writer.WriteLine("NICK $botname")
$writer.WriteLine("CAP REQ :twitch.tv/tags");
$writer.WriteLine("JOIN #fourtf");
$writer.Flush();

Write-Host "before read"
$line = $reader.ReadLine()
Write-Host "after read"

while ($line) {
    # Write-Host $line

    Irc-Parse $line

    $line = $reader.ReadLine()
}

