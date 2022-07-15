'-----------------------------------------------------------------------------------------------------
' XMP Player
' Copyright (c) 2022 Samuel Gomes
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'./LibXMPLite.bi'
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------
$ExeIcon:'./XMPlayer.ico'
$VersionInfo:CompanyName='Samuel Gomes'
$VersionInfo:FileDescription='XMPlayer executable'
$VersionInfo:InternalName='XMPlayer'
$VersionInfo:LegalCopyright='Copyright (c) 2022, Samuel Gomes'
$VersionInfo:LegalTrademarks='All trademarks are property of their respective owners'
$VersionInfo:OriginalFilename='XMPlayer.exe'
$VersionInfo:ProductName='XMPlayer'
$VersionInfo:Web='https://github.com/a740g'
$VersionInfo:Comments='https://github.com/a740g'
$VersionInfo:FILEVERSION#=1,0,0,11
$VersionInfo:PRODUCTVERSION#=1,0,0,0
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------
Const APP_NAME = "XMPlayer"
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------
Dim Shared Volume As Integer
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------
Title APP_NAME + " " + OS$ ' Set the program name in the titlebar
ChDir StartDir$ ' Change to the directory specifed by the environment
AcceptFileDrop ' Enable drag and drop of files
Screen 12 ' Use 640x480 resolution
AllowFullScreen SquarePixels , Smooth ' All the user to press Alt+Enter to go fullscreen
Display ' Only swap buffer when we want
Volume = XMP_VOLUME_MAX ' Set initial volume as 100%

ProcessCommandLine ' Check if any files were specified in the command line

Dim k As Long

' Main loop
Do
    ProcessDroppedFiles
    PrintWelcomeScreen
    k = KeyHit
    Display
    Limit 120
Loop Until k = 27

System 0
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------
' Initializes, loads and plays a mod file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    If Not XMPLoadFile(fileName) Then
        Color 12
        Print: Print "Failed to load "; fileName; "!"
        Display
        Sleep 5
        Exit Sub
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPath(fileName)

    Cls

    XMPStartPlayer

    Dim k As Long, loopCounter As Unsigned Long

    XMPSetVolume Volume

    Do
        XMPUpdatePlayer

        k = KeyHit

        Select Case k
            Case 32
                XMPPlayer.isPaused = Not XMPPlayer.isPaused

            Case 43, 61
                Volume = Volume + 1
                XMPSetVolume Volume
                Volume = XMPGetVolume

            Case 45, 95
                Volume = Volume - 1
                XMPSetVolume Volume
                Volume = XMPGetVolume

            Case 76, 108
                XMPPlayer.isLooping = Not XMPPlayer.isLooping
        End Select

        If loopCounter Mod 2 = 0 Then DrawInfoScreen ' Draw every alternate frame

        Display

        Limit 120

        loopCounter = loopCounter + 1
    Loop Until Not XMPPlayer.isPlaying Or k = 27 Or TotalDroppedFiles > 0

    XMPStopPlayer

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Sub


' Draws the screen during playback
' This part is mostly from RhoSigma's player code
Sub DrawInfoScreen
    Dim As Integer ow, oh, c, x, y, xp, yp
    Dim As Long ns, i, lSamp, rSamp
    Dim As String minute, second

    ns = XMPPlayer.soundBufferSize / XMP_SOUND_BUFFER_SAMPLE_SIZE 'number of samples in the buffer

    If XMPPlayer.isPaused Or Not XMPPlayer.isPlaying Then Color 12 Else Color 7

    Locate 22, 43: Print Using "Buffered sound: #.##### seconds"; SndRawLen(XMPPlayer.soundHandle)
    Locate 23, 43: Print "Position / Row:"; XMPPlayer.frameInfo.position; "/"; XMPPlayer.frameInfo.row; "  "
    Locate 24, 43: Print "Current volume:"; Volume
    minute = Right$("00" + LTrim$(Str$((XMPPlayer.frameInfo.time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((XMPPlayer.frameInfo.time + 500) \ 1000) Mod 60)), 2)
    Locate 25, 43: Print Using "  Elapsed time: &:& (mm:ss)"; minute; second
    minute = Right$("00" + LTrim$(Str$((XMPPlayer.frameInfo.total_time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((XMPPlayer.frameInfo.total_time + 500) \ 1000) Mod 60)), 2)
    Locate 26, 43: Print Using "    Total time: &:& (mm:ss)"; minute; second

    Color 9
    Locate 22, 7: Print "ESC - NEXT / QUIT"
    Locate 23, 7: Print "SPC - PLAY / PAUSE"
    Locate 24, 7: Print "=|+ - INCREASE VOLUME"
    Locate 25, 7: Print "-|_ - DECREASE VOLUME"
    Locate 26, 7: Print "L|l - LOOP"

    '--- animate wave form oscillators ---
    'As the oscillators width is probably <> number of samples, we need to
    'scale the x-position, same is with the amplitude (y-position).
    ow = 597: oh = 46 'oscillator width/height

    Line (20, 32)-(620, 144), 0, BF
    Color 7: DrawStringCenter "Left Channel", 32
    Color 2: PrintString (20, 32), "0 [ms]"
    Color 2: PrintString (532, 32), Left$(Str$(ns / SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 96 'framecolor/origin
    For i = 0 To XMPPlayer.soundBufferSize - XMP_SOUND_BUFFER_CHANNEL_SAMPLE_BYTES Step XMP_SOUND_BUFFER_SAMPLE_SIZE
        lSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i, Integer)
        xp = (ow / ns * (i / XMP_SOUND_BUFFER_SAMPLE_SIZE)) + x
        yp = (lSamp / 32768 * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10: Else Line -(xp, yp), 10
    Next
    Line (20, 48)-(620, 144), c, B

    '-----
    Line (20, 160)-(620, 272), 0, BF
    Color 7: DrawStringCenter "Right Channel", 160
    Color 2: PrintString (20, 160), "0 [ms]"
    Color 2: PrintString (532, 160), Left$(Str$(ns / SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 224 'framecolor/origin
    For i = 0 To XMPPlayer.soundBufferSize - XMP_SOUND_BUFFER_CHANNEL_SAMPLE_BYTES Step XMP_SOUND_BUFFER_SAMPLE_SIZE
        rSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_CHANNEL_SAMPLE_BYTES, Integer)
        xp = (ow / ns * (i / XMP_SOUND_BUFFER_SAMPLE_SIZE)) + x
        yp = (rSamp / 32768 * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10: Else Line -(xp, yp), 10
    Next
    Line (20, 176)-(620, 272), c, B
End Sub


' Prints the welcome screen
Sub PrintWelcomeScreen
    Cls
    Locate 1, 1
    Color 12, 0
    If Timer Mod 7 = 0 Then
        Print "              _    _          ___    _                                     (+_+)"
    ElseIf Timer Mod 13 = 0 Then
        Print "              _    _          ___    _                                     (*_*)"
    Else
        Print "              _    _          ___    _                                     (ù_ù)"
    End If
    Print "             ( )  ( )/ \_/ \(   _ \ (_ )                                        "
    Print "              \ \/ / |     ||  |_) ) |(|    _ _  _   _    __   _ __             "
    Color 15
    Print "               )  (  | (_) ||   __/  |()  / _  )( ) ( ) / __ \(  __)            "
    Print "              / /\ \ | | | ||  |     | | ( (_| || (_) |(  ___/| |               "
    Color 10
    Print "_.___________( )  (_)(_) (_)( _)    ( (_) \(_ _) \__  | )\___)(()_____________._"
    Print " |           /(                     (_)   (_)   ( )_| |(__)   (_)             | "
    Print " |          (__)                                 \___/                        | "
    Color 14
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "ESC";: Color 8: Print " .................... ";: Color 13: Print "NEXT/QUIT";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "SPC";: Color 8: Print " ........................ ";: Color 13: Print "PAUSE";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "=|+";: Color 8: Print " .............. ";: Color 13: Print "INCREASE VOLUME";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "-|_";: Color 8: Print " .............. ";: Color 13: Print "DECREASE VOLUME";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "L|l";: Color 8: Print " ......................... ";: Color 13: Print "LOOP";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                                                                            | "
    Print " | ";: Color 9: Print "DRAG AND DROP MULTIPLE MOD FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: Color 14: Print " | "
    Print " |                                                                            | "
    Print " | ";: Color 9: Print "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: Color 14: Print "  | "
    Print " |                                                                            | "
    Print " |    ";: Color 9: Print "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: Color 14: Print "    | "
    Print " |                                                                            | "
    Print " |                 ";: Color 9: Print "https://github.com/a740g/QB64-LibXMPLite";: Color 14: Print "                   | "
    Print "_|_                                                                          _|_"
    Print " `/__________________________________________________________________________\' ";
End Sub


' Processes the command line one file at a time
Sub ProcessCommandLine
    Dim i As Unsigned Long

    For i = 1 To CommandCount
        PlaySong Command$(i)
        If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
    Next
End Sub


' Processes dropped files one file at a time
Sub ProcessDroppedFiles
    If TotalDroppedFiles > 0 Then
        ' Make a copy of the dropped file and clear the list
        ReDim fileNames(1 To TotalDroppedFiles) As String
        Dim i As Unsigned Long

        For i = 1 To TotalDroppedFiles
            fileNames(i) = DroppedFile(i)
        Next
        FinishDrop ' This is critical

        ' Now play the dropped file one at a time
        For i = LBound(fileNames) To UBound(fileNames)
            PlaySong fileNames(i)
            If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
        Next
    End If
End Sub


' Centers a string on the screen
' The function calculates the correct starting column position to center the string on the screen and then draws the actual text
Sub DrawStringCenter (s As String, y As Integer)
    PrintString ((Width / 2) - (PrintWidth(s) / 2), y), s
End Sub


' Gets the filename portion from a file path
Function GetFileNameFromPath$ (pathName As String)
    Dim i As Unsigned Long

    ' Retrieve the position of the first / or \ in the parameter from the
    For i = Len(pathName) To 1 Step -1
        If Asc(pathName, i) = 47 Or Asc(pathName, i) = 92 Then Exit For
    Next

    ' Return the full string if pathsep was not found
    If i = 0 Then
        GetFileNameFromPath = pathName
    Else
        GetFileNameFromPath = Right$(pathName, Len(pathName) - i)
    End If
End Function
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'./LibXMPLite.bas'
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------

