#SingleInstance force
SetWorkingDir A_ScriptDir
SendMode "Input"
KeyHistory 0
#WinActivateForce
ProcessSetPriority "H"
SetWinDelay -1
SetControlDelay -1

; Include the Virtual Desktop library
#Include %A_LineFile%\..\VD.ahk\VD.ah2

; Create maps to store last activity time and unique desktop numbers
lastActivity := Map() ; To track the last activity time for each desktop
uniqueNumbers := Map() ; To store unique desktop numbers

; Hotkeys for moving windows and desktops

; Move the focused window to the left desktop and follow it
^!+Left:: {
    VerifyRightMostEmpty()
    VD.goToDesktopNum(VD.MoveWindowToRelativeDesktopNum("A", -1))
    UpdateLastActivity() ; Update activity after desktop switching
}

; Move the focused window to the right desktop and follow it
^!+Right:: {
    VerifyRightMostEmpty()
    VD.goToDesktopNum(VD.MoveWindowToRelativeDesktopNum("A", 1))
    UpdateLastActivity() ; Update activity after desktop switching
}

; Move to the desktop in the specified direction without moving any windows
^!Left:: {
    UpdateLastActivity()
    VerifyRightMostEmpty()
    VD.goToRelativeDesktopNum(-1)
    UpdateLastActivity() ; Update activity after desktop switching
}

VerifyRightMostEmpty() {
    totalDesktops := VD.getCount()

    ; Check if the rightmost desktop is occupied
    occupied := false
    id := WinGetList()
    for hwnd in id {
        desktopNum := VD.getDesktopNumOfWindow("ahk_id" hwnd)
        if (desktopNum == totalDesktops) {
            occupied := true
            break
        }
    }

    if (occupied) {
        ; If the rightmost desktop is occupied, create a new desktop
        VD.createDesktop(false)
        totalDesktops++ ; Update the total number of desktops after creation
    }
}

^!Right:: {
    UpdateLastActivity()

    VerifyRightMostEmpty()
    VD.goToRelativeDesktopNum(1)
    
    UpdateLastActivity() ; Update activity after desktop switching
}

; Function to update the last activity timestamp for the current desktop
UpdateLastActivity() {
    currentDesktop := VD.getCurrentDesktopNum()
    lastActivity[currentDesktop] := A_TickCount
}

; Automatically close empty desktops
Loop {
    foundProcesses := ""
    deskList := ""
    totalDesktops := VD.getCount()
    currentDesktop := VD.getCurrentDesktopNum() ; Get the current desktop

    ; Make sure to get all windows from all virtual desktops
    DetectHiddenWindows(true)
    id := WinGetList() ; Updated syntax for WinGet in AHK v2
    for hwnd in id { ; scans and creates the window list, adds a new desktop if the last desktop is occupied
        desktopNum := VD.getDesktopNumOfWindow("ahk_id" hwnd)
        If (desktopNum > 0) { ; -1 for invalid window, 0 for "Show on all desktops", 1 for Desktop 1
            exe := WinGetProcessName("ahk_id " hwnd)
            foundProcesses .= desktopNum " " exe "`n"
            deskList .= desktopNum ","
        }
    }
    
    ; Remove the trailing comma from deskList
    if (StrLen(deskList) > 0) {
        deskList := SubStr(deskList, 1, -1)
    }

    deskNumbers := StrSplit(deskList, ",")
    uniqueNumbers.Clear() ; Clear map before using it again
    for num in deskNumbers {
        if (!uniqueNumbers.Has(num))
            uniqueNumbers[num] := 1
    }

    deskListUnique := ""
    for num, _ in uniqueNumbers
        deskListUnique .= num ","
    deskListUnique := SubStr(deskListUnique, 1, -1) ; Remove trailing comma

    occupiedDesktops := StrSplit(deskListUnique, ",")

    ; Close any empty desktops if they have been inactive for at least 5 seconds, and there is more than one desktop
    ; Ignore the rightmost desktop
    d := VD.getCount() - 1
    while (d >= 2) {
        if !occupiedDesktops.Has(d) { ; Use Has to check if the desktop is occupied
            ; Only close if it's not the current desktop and inactive for at least 5 seconds
            lastActive := lastActivity.Has(d) ? lastActivity[d] : 0
            timeSinceLastActive := (A_TickCount - lastActive) / 1000
            
            if (d != currentDesktop && timeSinceLastActive >= 2) {
                VD.removeDesktop(d)
                ; Only delete if the key exists in lastActivity
                if (lastActivity.Has(d)) {
                    lastActivity.Delete(d) ; Remove the desktop from tracking since it's gone
                }
            }
        }
        d -= 1
    }

    ; Update last activity for the current desktop
    UpdateLastActivity()

    VerifyRightMostEmpty()

    Sleep 1000 ; Check every 1 second for more responsiveness
}
