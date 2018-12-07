#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <Debug.au3>

;Command line paramaters:
; param 1: complete path to Brainsuite executable (your param will be enclosed in double quotes). Example: c:\Program Files\BrainSuite18a\bin\BrainSuite18a.exe
; param 2: working directory to switch to before opening BrainSuite.  Typically should specify the main BrainSuite data folder. Example: D:\MRI Processing\MRI Data\Post-hypoxic dopamine R21\PH005\Brainsuite
; param 3: path BST file to load, relative to working directory.  Example:  .\dti\153_b_mprage_3.FRACT.T1_coord.bst
;

;Example of complete command line to launch:
; "C:\Program Files (x86)\AutoIt3\AutoIt3.exe" "N:\MRI Processing\MRI Processing Software\Tools\ComputeTractography.au3" "c:\Program Files\BrainSuite18a\bin\BrainSuite18a.exe"  "N:\MRI Processing\MRI Data\Post-hypoxic dopamine R21\PH005\Brainsuite" ".\dti\153_b_mprage_3.FRACT.T1_coord.bst"


;Test command line
; "C:\Program Files (x86)\AutoIt3\AutoIt3.exe" "D:\MRI Processing\MRI Processing Software\Tools\ComputeTractography.au3" "c:\Program Files\BrainSuite18a\bin\BrainSuite18a.exe"   "D:\MRI Processing\MRI Data\WPAFB HyperO2\CW002\Brainsuite" "101_b_mprage_2.FRACT.T1_coord.bst"

_DebugSetup("Check ComputeTractography", True) ; start displaying debug environment


AutoItSetOption("MustDeclareVars", 1)
AutoItSetOption("ExpandVarStrings",1)
AutoItSetOption("WinTitleMatchMode",1) ;match from beginning of window title
AutoItSetOption("MouseCoordMode",2)  ;use relative coords to the client area of the active window
AutoItSetOption("PixelCoordMode",2)  ;use relative coords to the client area of the active window
AutoItSetOption("MouseClickDelay",100) ;100 msec delay between mouse clicks

; MsgBox($MB_SYSTEMMODAL, "Command line params", $CmdLine[1] & @CRLF & $CmdLine[2] & @CRLF & $CmdLine[3])

Local $vBS_Exe = $CmdLine[1]
Local $vWorkingDir = $CmdLine[2]
Local $vBST_Path = $CmdLine[3]

Local $vCommandString =  '"$vBS_Exe$" "$vBST_Path$"'

; MsgBox($MB_SYSTEMMODAL, "Run params", "vCommandString:$vCommandString$" & @CRLF & _
                                               ; "vWorkingDir:$vWorkingDir$")

Run($vCommandString, $CmdLine[2],  @SW_MAXIMIZE )

; Wait 10 seconds for the Brainsuite window to appear.
Local $hWnd = WinWait("BrainSuite", "", 10)
Local $aClientSize =  WinGetClientSize($hWnd)

;wait for window title to end with the BST name
Local $vBST_Name, $vPositionLastSlash
$vPositionLastSlash =  StringInStr($vBST_Path , "\" , 0, -1 )
if ($vPositionLastSlash>0) then
   $vBST_Name = StringMid($vBST_Path, ($vPositionLastSlash+1))
else
   $vBST_Name = $vBST_Path
endif
_DebugOut("$vBST_Name:" & $vBST_Name)

Local $vWindowTitle_Main, $vPosition_BSTName
Local $hTimer
$hTimer = TimerInit()
do
   Sleep(500)
   WinActivate($hWnd)
   $vWindowTitle_Main = WinGetTitle($hWnd)
   $vPosition_BSTName = StringInStr($vWindowTitle_Main, $vBST_Name)
   _DebugOut("$vWindowTitle_Main:" & $vWindowTitle_Main)
until (($vPosition_BSTName>0) or (TimerDiff($hTimer) > 100000))

if ($vPosition_BSTName=0) then ;failed after 100 seconds to get exepected
   Exit 1  ; exit with errorcode 1
endif

Local $aClientSize = WinGetClientSize($hWnd)
Local $vClientWidth = $aClientSize[0]
Local $vClientHeight= $aClientSize[1]
_DebugOut("$vClientWidth:" & $vClientWidth)
_DebugOut("$vClientHeight:" & $vClientHeight)

WinActivate($hWnd)
Send("!t")     ;Alt-T
Send("d")


;Now we want to find the "Tract Filtering" button.  Unfortunately, it's text is not visible in AutoIt, and
; even worse is that it's location is dependent on the screen display resolution, and other factors.
; Therefore, we will try to be tricky to find it.
; Find the control with ClassName= Qt5QWindowIcon;text= diffusionToolboxDockWidgetWindow -- this is the Diffusion Toolbox window
; Find the bottom of that control
; Then move the mouse up, looking for a pixel value 0xA0A0A0 -- this is the bottom of the button "Connectivity"
; Then move the mouse up more, looking for a pixel value 0xA0A0A0 -- this is the bottom of the button "Track Filtering"
; go a bit father up to click that button.
; move mouse back to the Connectivty button.  Then scan up for white areas... stop in the 3rd white area.  That is
; the length theshold text box

WinActivate($hWnd)
Local $aDiffToolboxPos = ControlGetPos($hWnd, "", "[CLASS:Qt5QWindowIcon; TEXT:diffusionToolboxDockWidgetWindow]")
_DebugOut("@error:" & @error )
_DebugReportVar("$aDiffToolboxPos", $aDiffToolboxPos)
Local $vLocation_X, $vLocation_Y
$vLocation_X = $aDiffToolboxPos[0] + $aDiffToolboxPos[2] - 60 ; 60 pixels from right
$vLocation_Y = $aDiffToolboxPos[1] + $aDiffToolboxPos[3]  ; bottom of toolbox
Local $mButtonLocation_Bottom[]      ;a map, will contain the pixel location of bottom of each needed button
Local $vButtonName
Local $vFoundButtons=False
Local $vButtonIndex_FromBottom = 0

_DebugOut("$vLocation_X:" & $vLocation_X)
_DebugOut("$vLocation_Y:" & $vLocation_Y)


Do
   $vLocation_Y = $vLocation_Y - 1

   ;_DebugOut("at $vLocation_Y=" & $vLocation_Y & " pixel color:" & PixelGetColor($vLocation_X , $vLocation_Y))
   if (PixelGetColor($vLocation_X , $vLocation_Y)=0xA0A0A0) then
	  $vLocation_Y = $vLocation_Y - 10  ;move a few more pixels up
	  $vButtonIndex_FromBottom = $vButtonIndex_FromBottom + 1
	  Switch $vButtonIndex_FromBottom
		  Case 1
			  $vButtonName = "Connectivty"
		  Case 2
			  $vButtonName = "Filtering"
		  Case 3
			  $vButtonName = "Display"
		  Case 4
			  $vButtonName = "Tractography"
			  $vFoundButtons= True
	  EndSwitch

	  $mButtonLocation_Bottom[$vButtonName] = $vLocation_Y
	  _DebugOut("Button " & $vButtonName & " found at Y=" & $mButtonLocation_Bottom[$vButtonName])
   EndIf
Until ($vFoundButtons) or ($vLocation_Y < 700)


MouseClick($MOUSE_CLICK_LEFT, $vLocation_X, $mButtonLocation_Bottom["Filtering"])	;click Tract Filtering button

;now move up from bottom, looking for the 3rd white are
$vLocation_Y = $aDiffToolboxPos[1] + $aDiffToolboxPos[3]  ; bottom of toolbox
Local $vCountWhiteArea = 0, $vInWhiteArea = False, $vFoundTarget = False
Do
   $vLocation_Y = $vLocation_Y - ($vInWhiteArea ? 15 : 5 ) ; when in the big white areas, we can step large, looking for the border of the white area

   _DebugOut("at $vLocation_Y=" & $vLocation_Y & " pixel color:" & PixelGetColor($vLocation_X , $vLocation_Y) & "; $vInWhiteArea=" & $vInWhiteArea)
   if ($vInWhiteArea) then
	  $vInWhiteArea = (PixelGetColor($vLocation_X , $vLocation_Y)<>0xF0F0F0)

   else
	  if (PixelGetColor($vLocation_X , $vLocation_Y)=0xFFFFFF) and (PixelGetColor($vLocation_X , $vLocation_Y-2)=0xFFFFFF)  then
		 ;look also 2 more pixels up to make sure its not just a single-pixel white line
		 $vLocation_Y = $vLocation_Y - 1  ; move one more pixel up
		 $vCountWhiteArea = $vCountWhiteArea + 1
		 $vInWhiteArea = True
		 _DebugOut("Found white area #" & $vCountWhiteArea  & " at Y=" & $vLocation_Y)

		 if $vCountWhiteArea=3 Then
			_DebugOut("Found desired box, at Y=" & $vLocation_Y)
			$vFoundTarget = True
		 EndIf
	  EndIf
   EndIf
Until ($vFoundTarget) or ($vLocation_Y < 20)

If $vFoundTarget then
   ClipPut("50")  ;put 50 on clipboard
   MouseClick($MOUSE_CLICK_LEFT, $vLocation_X, $vLocation_Y) ;filtering length
   Send("^a") ;Ctrl-a, select all the text
   Send("^v") ;Ctrl-v, paste
EndIf


;collapse the diffusion toolbox options again
WinActivate($hWnd)
Send("!t")     ;Alt-T
Send("d")

MouseClick($MOUSE_CLICK_LEFT, $vLocation_X, $mButtonLocation_Bottom["Tractography"])	;click Tractography button

;Search for the "Compute Tracks" button
$vLocation_X = $aDiffToolboxPos[0] + $aDiffToolboxPos[2] - 30 ; 30 pixels from right
$vLocation_Y = 400  ;start pretty high up to make quicker search
$vFoundButtons = False
$vButtonName = "Compute Tracks"
Do
   $vLocation_Y = $vLocation_Y - 12   ;can move pretty quickly, looking for the button

   ;_DebugOut("at $vLocation_Y=" & $vLocation_Y & " pixel color:" & PixelGetColor($vLocation_X , $vLocation_Y))
   if (PixelGetColor($vLocation_X , $vLocation_Y)=0xE1E1E1) then
	  $vFoundButtons= True
	  _DebugOut("Button " & $vButtonName & " found at Y=" & $vLocation_Y)
   EndIf
Until ($vFoundButtons) or ($vLocation_Y < 50)

if ($vFoundButtons) then
   MouseClick($MOUSE_CLICK_LEFT, $vLocation_X, $vLocation_Y)	; click "Compute Tracks" button
endif

Sleep(2000)
MouseClick($MOUSE_CLICK_LEFT, $aClientSize[0]/2, $aClientSize[1]/2)  ;click in middle of screen

Local $vWindowTitle , $vWindowTitleToWaitFor, $vFoundWindow, $vWindowWaitTimeout_ms
$vWindowTitleToWaitFor = "Fiber Tracking"
$vFoundWindow = False
$vWindowWaitTimeout_ms = 300000
$hTimer = TimerInit()
_DebugOut("$vWindowTitleToWaitFor:" & $vWindowTitleToWaitFor)
Do
   Sleep(500)
   $vWindowTitle = WinGetTitle("[ACTIVE]")
   $vFoundWindow = ($vWindowTitle = $vWindowTitleToWaitFor)
Until  $vFoundWindow or (TimerDiff($hTimer) > $vWindowWaitTimeout_ms)
_DebugOut("$vFoundWindow:" & $vFoundWindow)

if ($vFoundWindow) then
   ;now wait for the center window to disapper, and main window to be back
   $vWindowTitleToWaitFor = $vWindowTitle_Main
   $vFoundWindow = False
   $vWindowWaitTimeout_ms = 600000
   $hTimer = TimerInit()
   _DebugOut("$vWindowTitleToWaitFor:" & $vWindowTitleToWaitFor)
   Do
	  Sleep(500)
	  $vWindowTitle = WinGetTitle("[ACTIVE]")
	  $vFoundWindow = ($vWindowTitle = $vWindowTitleToWaitFor)
   Until  $vFoundWindow or (TimerDiff($hTimer) > $vWindowWaitTimeout_ms)
   _DebugOut("$vFoundWindow:" & $vFoundWindow)

   if ($vFoundWindow) then
	  Send("!f")  ; Alt-F
	  Send("{DOWN 4}")   ;down arrow 4 times
	  Send("{RIGHT}")    ;right arrow
	  Send("{DOWN}")   ;down arrow
	  Send("{ENTER}")
	  WinWaitActive("Save Fibertrack Set")
	  ClipPut("fibertracks_filtered_50mm.dft")
	  Send("^v") ;Ctrl-v, paste
	  Send("!s")  ; Alt-S
	  Sleep(3000)
   EndIf

EndIf


#comments-start



MouseClick 1800,224  #compute tractography


pause 2 seconds
mouseclick 930,500  # in middle
check for window title = Fiber Tracking

wait for window title to go back to BST name
'save the fiber tracks
SendKeys Alt-F
SendKeys down arrow 4 times
SendKeys right arrow
SendKeys down arrow
SendKeys enter
Wait window title "Save Fibertrack Set"
ClipPut("fibertracks_filtered_50mm.dft")
SendKeys Alt-S
wait for file to appear, and to stop changing in size



pause 2 seconds
mouseclick 930,500  # in middle
check for window title = Compute Connectivity

'save connectivity
SendKeys Alt-F
SendKeys down arrow 6 times
SendKeys enter
Wait window title "Save Connectivity Matrix"
set clipbaord text  "connectivity_matrix.tsv"
SendKeys Alt-S
wait for file to appear, and to stop changing in size

#comments-end
