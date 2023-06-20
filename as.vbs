' This script runs a batch file located at C:\system128\system128.bat

Set w = CreateObject("WScript.Shell")
w.Run "C:\system128\system128.bat", 0, False
Set w = Nothing
