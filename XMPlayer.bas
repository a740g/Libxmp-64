'-----------------------------------------------------------------------------------------------------
' XMPlayer
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------
' On Windows libxmp.dll is preferred. Un-comment the line below to link statically
' On Linux, this is ignored and the library is linked statically always
'$LET LIBXMP_STATIC = TRUE
'$Include:'./LibXMPLite.bi'
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------
$ExeIcon:'./XMPlayer.ico'
$VersionInfo:CompanyName=Samuel Gomes
$VersionInfo:FileDescription=XMPlayer executable
$VersionInfo:InternalName=XMPlayer
$VersionInfo:LegalCopyright=Copyright (c) 2022, Samuel Gomes
$VersionInfo:LegalTrademarks=All trademarks are property of their respective owners
$VersionInfo:OriginalFilename=XMPlayer.exe
$VersionInfo:ProductName=XMPlayer
$VersionInfo:Web=https://github.com/a740g
$VersionInfo:Comments=https://github.com/a740g
$VersionInfo:FILEVERSION#=2,0,0,6
$VersionInfo:PRODUCTVERSION#=2,0,0,0
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------
Const APP_NAME = "XMPlayer"
Const FRAME_RATE_MAX = 120
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------
Dim Shared Volume As Long, OsciType As Long
Dim Shared FreqFact As Long, MagFact As Single, VolBoost As Single
ReDim Shared As Single lSig(0 To 0), rSig(0 To 0)
ReDim Shared As Single FFTr(0 To 0), FFTi(0 To 0)
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
OsciType = 2 ' 1 = Wave plot / 2 = Frequency spectrum (FFT)
FreqFact = 8 ' Frequency spectrum X-axis scale (powers of two only [2-16], default 8)
MagFact = 1 ' Frequency spectrum Y-axis scale (magnitude [1.0-5.0], default 1)
VolBoost = 1 ' No change
ProcessCommandLine ' Check if any files were specified in the command line

Dim k As Long

' Main loop
Do
    ProcessDroppedFiles
    PrintWelcomeScreen
    k = KeyHit
    Display
    Limit FRAME_RATE_MAX
Loop Until k = KEY_ESCAPE

System
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------
' Initializes, loads and plays a mod file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    Shared XMPPlayer As XMPPlayerType

    If Not XMPFileLoad(fileName) Then
        Color 12
        Print: Print "Failed to load "; fileName; "!"
        Display
        Sleep 5
        Exit Sub
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPath(fileName)

    Cls

    XMPPlayerStart

    ' Setup the FFT arrays
    ReDim As Single lSig(0 To XMPPlayer.soundBufferSize \ XMP_SOUND_BUFFER_SAMPLE_SIZE - 1), rSig(0 To XMPPlayer.soundBufferSize \ XMP_SOUND_BUFFER_SAMPLE_SIZE - 1)
    ReDim As Single FFTr(0 To XMPPlayer.soundBufferSize \ XMP_SOUND_BUFFER_SAMPLE_SIZE - 1), FFTi(0 To XMPPlayer.soundBufferSize \ XMP_SOUND_BUFFER_SAMPLE_SIZE - 1)

    Dim k As Long, loopCounter As Unsigned Long

    XMPPlayerVolume Volume

    Do
        XMPPlayerUpdate

        k = KeyHit

        Select Case k
            Case KEY_SPACE_BAR ' SPC - toggle pause
                XMPPlayer.isPaused = Not XMPPlayer.isPaused

            Case KEY_PLUS, KEY_EQUALS ' + = volume up
                Volume = Volume + 1
                XMPPlayerVolume Volume
                Volume = XMPPlayerVolume

            Case KEY_MINUS, KEY_UNDERSCORE ' - _ volume down
                Volume = Volume - 1
                XMPPlayerVolume Volume
                Volume = XMPPlayerVolume

            Case KEY_LOWER_L, KEY_UPPER_L ' L - toggle looping
                XMPPlayer.isLooping = Not XMPPlayer.isLooping

            Case KEY_UPPER_R, KEY_LOWER_R ' R -  rewind
                XMPPlayerRestart

            Case KEY_LEFT_ARROW ' <- - rewind one position
                XMPPlayerPreviousPosition

            Case KEY_RIGHT_ARROW ' -> - fast forward on position
                XMPPlayerNextPosition

            Case KEY_UPPER_O, KEY_LOWER_O ' O - toggle oscillator
                OsciType = OsciType Xor 3

            Case KEY_UPPER_F ' F - zoom in (smaller freq range)
                If FreqFact < 16 Then FreqFact = FreqFact * 2

            Case KEY_LOWER_F ' f - zoom out (bigger freq range)
                If FreqFact > 2 Then FreqFact = FreqFact \ 2

            Case KEY_UPPER_M ' M - scale up (bring out peaks)
                If MagFact < 5.0! Then MagFact = MagFact + 0.25!

            Case KEY_LOWER_M ' m - scale down (flatten peaks)
                If MagFact > 1.0! Then MagFact = MagFact - 0.25!

            Case KEY_UPPER_V ' V - volume up (louder)
                If VolBoost < 5.0! Then VolBoost = VolBoost + 0.05!

            Case KEY_LOWER_V ' v - volume down (quieter)
                If VolBoost > 1.0! Then VolBoost = VolBoost - 0.05!
        End Select

        If loopCounter Mod 2 = 0 Then DrawInfoScreen ' Draw every alternate frame

        Display

        Limit FRAME_RATE_MAX

        loopCounter = loopCounter + 1
    Loop Until Not XMPPlayer.isPlaying Or k = KEY_ESCAPE Or TotalDroppedFiles > 0

    XMPPlayerStop

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Sub


' Draws the screen during playback
' This part is mostly from RhoSigma's player code
Sub DrawInfoScreen
    Shared XMPPlayer As XMPPlayerType

    Dim As Long ow, oh, c, x, y, xp, yp
    Dim As Long ns, i
    Dim As Single lSamp, rSamp
    Dim As String minute, second

    ns = XMPPlayer.soundBufferSize \ XMP_SOUND_BUFFER_SAMPLE_SIZE 'number of samples in the buffer

    If XMPPlayer.isPaused Or Not XMPPlayer.isPlaying Then Color 12 Else Color 7

    Locate 21, 43: Print Using "Buffered sound: #.##### seconds"; SndRawLen(XMPPlayer.soundHandle);
    Locate 22, 43: Print "Position / Row:"; XMPPlayer.frameInfo.position; "/"; XMPPlayer.frameInfo.row; "  ";
    Locate 23, 43: Print "Current volume:"; Volume;
    minute = Right$("00" + LTrim$(Str$((XMPPlayer.frameInfo.time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((XMPPlayer.frameInfo.time + 500) \ 1000) Mod 60)), 2)
    Locate 24, 43: Print Using "  Elapsed time: &:& (mm:ss)"; minute; second;
    minute = Right$("00" + LTrim$(Str$((XMPPlayer.frameInfo.total_time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((XMPPlayer.frameInfo.total_time + 500) \ 1000) Mod 60)), 2)
    Locate 25, 43: Print Using "    Total time: &:& (mm:ss)"; minute; second;
    Locate 26, 50: Print "Looping: "; BoolToStr(XMPPlayer.isLooping, 2); " ";

    Color 9

    If OsciType = 2 Then
        Locate 19, 7: Print "F/f - FREQUENCY ZOOM IN/OUT";
        Locate 20, 7: Print "M/m - MAGNITUDE SCALE UP/DOWN";
    Else
        Locate 19, 7: Print "                           ";
        Locate 20, 7: Print "V/v - VOLUME BOOST UP/DOWN   ";
    End If
    Locate 21, 7: Print "O|o - TOGGLE OSCILLATOR TYPE";
    Locate 22, 7: Print "ESC - NEXT / QUIT";
    Locate 23, 7: Print "SPC - PLAY / PAUSE";
    Locate 24, 7: Print "=|+ - INCREASE VOLUME";
    Locate 25, 7: Print "-|_ - DECREASE VOLUME";
    Locate 26, 7: Print "L|l - LOOP";
    Locate 27, 7: Print "R|r - REWIND TO START";
    Locate 28, 7: Print "/ - REWIND/FORWARD ONE POSITION";

    On OsciType GOSUB DrawOscillators, DrawFFT

    Exit Sub

    DrawOscillators: '--- animate wave form oscillators ---

    'As the oscillators width is probably <> number of samples, we need to
    'scale the x-position, same is with the amplitude (y-position).
    ow = 597: oh = 46 'oscillator width/height
    '-----
    Line (0, 0)-(639, 15), 0, BF
    Color 6: Locate 1, 24: Print Using "Current volume boost factor = #.##"; VolBoost;
    '-----
    Line (20, 32)-(620, 144), 0, BF
    Color 7: PrintString (224, 32), "Left Channel (Wave plot)"
    Color 2: PrintString (20, 32), "0 [ms]"
    Color 2: PrintString (556, 32), Left$(Str$(ns / SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 96 'framecolor/origin
    For i = 0 To XMPPlayer.soundBufferSize - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        lSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i, Integer)
        xp = (ow / ns * (i / XMP_SOUND_BUFFER_SAMPLE_SIZE)) + x
        yp = (lSamp / 32768! * VolBoost * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 48)-(620, 144), c, B
    '-----
    Line (20, 160)-(620, 272), 0, BF
    Color 7: PrintString (220, 160), "Right Channel (Wave plot)"
    Color 2: PrintString (20, 160), "0 [ms]"
    Color 2: PrintString (556, 160), Left$(Str$(ns / SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 224 'framecolor/origin
    For i = 0 To XMPPlayer.soundBufferSize - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        rSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, Integer)
        xp = (ow / ns * (i / XMP_SOUND_BUFFER_SAMPLE_SIZE)) + x
        yp = (rSamp / 32768! * VolBoost * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 176)-(620, 272), c, B

    Return

    DrawFFT: '--- animate FFT frequencey oscillators ---

    ' Fill the FFT arrays with sample data
    For i = 0 To XMPPlayer.soundBufferSize - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        lSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i, Integer) / 32768!
        rSamp = MemGet(XMPPlayer.soundBuffer, XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, Integer) / 32768!
        If Abs(lSamp) > 1 Then lSamp = Sgn(lSamp) 'clip out of
        If Abs(rSamp) > 1 Then rSamp = Sgn(rSamp) 'range volume peaks
        lSig(i \ 4) = lSamp: rSig(i \ 4) = rSamp 'fill FFT signal array
    Next

    'As the oscillators width is probably <> frequency range, we need to
    'scale the x-position, same is with the magnitude (y-position).
    ow = 597: oh = 92 'oscillator width/height
    '-----
    Line (0, 0)-(639, 15), 0, BF
    Color 6: Locate 1, 3: Print Using "Current frequence zoom factor = ##  /  Current magnitude scale factor = #.##"; FreqFact; MagFact;
    '-----
    RFFT FFTr(), FFTi(), lSig(), ns
    Line (20, 32)-(620, 144), 0, BF
    Color 7: PrintString (188, 32), "Left Channel (Frequency spectrum)"
    Color 2: PrintString (12, 32), Left$(Str$(SndRate \ ns), 6) + " [Hz]"
    Color 2: PrintString (532, 32), Left$(Str$((ns \ FreqFact) * SndRate \ ns), 6) + " [Hz]"
    x = 22: y = 142 'origin
    For i = 0 To ns \ FreqFact
        xp = (ow / (ns / FreqFact) * i) + x
        yp = MagFact * Sqr((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        If yp > oh Then yp = y - oh Else yp = y - yp
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 48)-(620, 144), 7, B
    '-----
    RFFT FFTr(), FFTi(), rSig(), ns
    Line (20, 160)-(620, 272), 0, BF
    Color 7: PrintString (184, 160), "Right Channel (Frequency spectrum)"
    Color 2: PrintString (12, 160), Left$(Str$(SndRate \ ns), 6) + " [Hz]"
    Color 2: PrintString (532, 160), Left$(Str$((ns& \ FreqFact) * SndRate \ ns), 6) + " [Hz]"
    x = 22: y = 270 'origin
    For i = 0 To ns \ FreqFact
        xp = (ow / (ns / FreqFact) * i) + x
        yp = MagFact * Sqr((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        If yp > oh Then yp = y - oh Else yp = y - yp
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 176)-(620, 272), 7, B

    Return
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
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "ESC";: Color 8: Print " .................... ";: Color 13: Print "NEXT/QUIT";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "SPC";: Color 8: Print " ........................ ";: Color 13: Print "PAUSE";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "=|+";: Color 8: Print " .............. ";: Color 13: Print "INCREASE VOLUME";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "-|_";: Color 8: Print " .............. ";: Color 13: Print "DECREASE VOLUME";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "L|l";: Color 8: Print " ......................... ";: Color 13: Print "LOOP";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "R|r";: Color 8: Print " .............. ";: Color 13: Print "REWIND TO START";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "/";: Color 8: Print " .. ";: Color 13: Print "REWIND/FORWARD ONE POSITION";: Color 14: Print "                     | "
    Print " |                     ";: Color 11: Print "O|o";: Color 8: Print " ....... ";: Color 13: Print "TOGGLE OSCILLATOR TYPE";: Color 14: Print "                     | "
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


' Gets a string form of the boolean value passed
Function BoolToStr$ (expression As Long, style As Unsigned Byte)
    Select Case style
        Case 1
            If expression Then BoolToStr = "On" Else BoolToStr = "Off"
        Case 2
            If expression Then BoolToStr = "Enabled" Else BoolToStr = "Disabled"
        Case 3
            If expression Then BoolToStr = "1" Else BoolToStr = "0"
        Case Else
            If expression Then BoolToStr = "True" Else BoolToStr = "False"
    End Select
End Function


' Vince's FFT routine - https://qb64phoenix.com/forum/showthread.php?tid=270&pid=2005#pid2005
' Modified for efficiency and performance
Sub RFFT (xx_r() As Single, xx_i() As Single, x_r() As Single, n As Long)
    Dim As Single w_r, w_i, wm_r, wm_i, u_r, u_i, v_r, v_i, xpr, xpi, xmr, xmi
    Dim As Long log2n, rev, i, j, k, m, p, q

    log2n = Log(n \ 2) / Log(2)

    For i = 0 To n \ 2 - 1
        rev = 0
        For j = 0 To log2n - 1
            If i And (2 ^ j) Then rev = rev + (2 ^ (log2n - 1 - j))
        Next

        xx_r(i) = x_r(2 * rev)
        xx_i(i) = x_r(2 * rev + 1)
    Next

    For i = 1 To log2n
        m = 2 ^ i
        wm_r = Cos(-2 * Pi / m)
        wm_i = Sin(-2 * Pi / m)

        For j = 0 To n \ 2 - 1 Step m
            w_r = 1
            w_i = 0

            For k = 0 To m \ 2 - 1
                p = j + k
                q = p + (m \ 2)

                u_r = w_r * xx_r(q) - w_i * xx_i(q)
                u_i = w_r * xx_i(q) + w_i * xx_r(q)
                v_r = xx_r(p)
                v_i = xx_i(p)

                xx_r(p) = v_r + u_r
                xx_i(p) = v_i + u_i
                xx_r(q) = v_r - u_r
                xx_i(q) = v_i - u_i

                u_r = w_r
                u_i = w_i
                w_r = u_r * wm_r - u_i * wm_i
                w_i = u_r * wm_i + u_i * wm_r
            Next
        Next
    Next

    xx_r(n \ 2) = xx_r(0)
    xx_i(n \ 2) = xx_i(0)

    For i = 1 To n \ 2 - 1
        xx_r(n \ 2 + i) = xx_r(n \ 2 - i)
        xx_i(n \ 2 + i) = xx_i(n \ 2 - i)
    Next

    For i = 0 To n \ 2 - 1
        xpr = (xx_r(i) + xx_r(n \ 2 + i)) / 2
        xpi = (xx_i(i) + xx_i(n \ 2 + i)) / 2

        xmr = (xx_r(i) - xx_r(n \ 2 + i)) / 2
        xmi = (xx_i(i) - xx_i(n \ 2 + i)) / 2

        xx_r(i) = xpr + xpi * Cos(2 * Pi * i / n) - xmr * Sin(2 * Pi * i / n)
        xx_i(i) = xmi - xpi * Sin(2 * Pi * i / n) - xmr * Cos(2 * Pi * i / n)
    Next

    ' symmetry, complex conj
    For i = 0 To n \ 2 - 1
        xx_r(n \ 2 + i) = xx_r(n \ 2 - 1 - i)
        xx_i(n \ 2 + i) = -xx_i(n \ 2 - 1 - i)
    Next
End Sub
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'./LibXMPLite.bas'
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------

