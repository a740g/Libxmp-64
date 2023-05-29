'-----------------------------------------------------------------------------------------------------------------------
' Demo player for Libxmp
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$If VERSION < 3.7 Then
        $ERROR This requires the latest version of QB64-PE from https://github.com/QB64-Phoenix-Edition/QB64pe/releases
$End If
DefLng A-Z
Option _Explicit
'$STATIC
Option Base 1
$Resize:Smooth
$Unstable:Http
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
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
$VersionInfo:FILEVERSION#=3,0,0,0
$VersionInfo:PRODUCTVERSION#=3,0,0,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
Const APP_NAME = "XMPlayer"
Const FRAME_RATE_MAX = 120
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
Dim Shared Volume As Long, OsciType As Long
Dim Shared FreqFact As Long, MagFact As Single, VolBoost As Single
ReDim Shared As Single lSig(0 To 0), rSig(0 To 0)
ReDim Shared As Single FFTr(0 To 0), FFTi(0 To 0)
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
_Title APP_NAME + " " + _OS$ ' Set the program name in the titlebar
ChDir _StartDir$ ' Change to the directory specifed by the environment
_AcceptFileDrop ' Enable drag and drop of files
Screen 12 ' Use 640x480 resolution
_AllowFullScreen _SquarePixels , _Smooth ' All the user to press Alt+Enter to go fullscreen
_PrintMode _KeepBackground ' print without wiping out the background
_Display ' Only swap buffer when we want
Randomize Timer ' seed RNG
Volume = XMP_VOLUME_MAX ' Set initial volume as 100%
OsciType = 2 ' 1 = Wave plot / 2 = Frequency spectrum (FFT)
FreqFact = 2 ' Frequency spectrum X-axis scale (powers of two only [2-16])
MagFact = 5 ' Frequency spectrum Y-axis scale (magnitude [1.0-5.0])
VolBoost = 1 ' No change
ProcessCommandLine ' Check if any files were specified in the command line

' Load from memory test:
' We'll download a S3M file directly to a memory buffer and then pass that buffer to the library
' The song should be automatically closed when the user tries to play another tune
' Also the XMP_Update inside the loop should do nothing with nothing playing
' If anuthing goes wrong here, then it is silently ignored
If XMP_LoadTuneFromMemory(LoadFileFromURL("http://ftp.modland.com/pub/modules/Screamtracker%203/Siren/jazz%20jackrabbit%202%20-%20labratory%20level.s3m")) Then
    XMP_Play
    XMP_Loop Not 0 ' -1 or true really XD. We'll loop so that we do not have to check if it is playing
End If

Dim k As Long

' Main loop
Do
    XMP_Update XMP_SOUND_BUFFER_TIME_DEFAULT ' only here in the main loop for the intro music, otherwise does nothing

    ProcessDroppedFiles

    k = _KeyHit

    If k = 15104 Then ProcessSelectedFiles

    PrintWelcomeScreen ' clears, draws and then displays the welcome screen

    _Limit FRAME_RATE_MAX
Loop Until k = 27

XMP_Stop ' we're being nice

System
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Initializes, loads and plays a mod file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    Shared __XMPPlayer As __XMPPlayerType

    If Not XMP_LoadTuneFromFile(fileName) Then
        _MessageBox APP_NAME, "Failed to load: " + fileName, "error"
        Exit Sub
    End If

    ' Set the app title to display the file name
    _Title APP_NAME + " - " + GetFileNameFromPath(fileName)

    XMP_Play

    ' Setup the FFT arrays
    ReDim As Single lSig(0 To __XMPPlayer.soundBufferFrames - 1), rSig(0 To __XMPPlayer.soundBufferFrames - 1)
    ReDim As Single FFTr(0 To __XMPPlayer.soundBufferFrames - 1), FFTi(0 To __XMPPlayer.soundBufferFrames - 1)

    Dim k As Long, loopCounter As _Unsigned Long

    XMP_SetVolume Volume

    Do
        XMP_Update XMP_SOUND_BUFFER_TIME_DEFAULT

        k = _KeyHit

        Select Case k
            Case 32 ' SPC - toggle pause
                XMP_Pause Not XMP_IsPaused

            Case 43, 61 ' + = volume up
                Volume = Volume + 1
                XMP_SetVolume Volume
                Volume = XMP_GetVolume

            Case 45, 95 ' - _ volume down
                Volume = Volume - 1
                XMP_SetVolume Volume
                Volume = XMP_GetVolume

            Case 76, 108 ' L - toggle looping
                XMP_Loop Not XMP_IsLooping

            Case 82, 114 ' R -  rewind
                XMP_Replay

            Case 19200 ' <- - rewind one position
                XMP_GoToPreviousPosition

            Case 19712 ' -> - fast forward on position
                XMP_GoToNextPosition

            Case 79, 111 ' O - toggle oscillator
                OsciType = OsciType Xor 3

            Case 70 ' F - zoom in (smaller freq range)
                If FreqFact < 16 Then FreqFact = FreqFact * 2

            Case 102 ' f - zoom out (bigger freq range)
                If FreqFact > 2 Then FreqFact = FreqFact \ 2

            Case 77 ' M - scale up (bring out peaks)
                If MagFact < 5.0! Then MagFact = MagFact + 0.25!

            Case 109 ' m - scale down (flatten peaks)
                If MagFact > 1.0! Then MagFact = MagFact - 0.25!

            Case 86 ' V - volume up (louder)
                If VolBoost < 5.0! Then VolBoost = VolBoost + 0.05!

            Case 118 ' v - volume down (quieter)
                If VolBoost > 1.0! Then VolBoost = VolBoost - 0.05!
        End Select

        DrawInfoScreen '  clears, draws and then display the info screen

        _Limit FRAME_RATE_MAX

        loopCounter = loopCounter + 1
    Loop Until Not XMP_IsPlaying Or k = 27 Or _TotalDroppedFiles > 0

    XMP_Stop

    _Title APP_NAME + " " + _OS$ ' Set app title to the way it was
End Sub


' Draws the screen during playback
' This part is mostly from RhoSigma's player code
Sub DrawInfoScreen
    Shared __XMPPlayer As __XMPPlayerType

    Cls ' first clear everything

    Dim As Long ow, oh, c, x, y, xp, yp, i
    Dim As Single lSamp, rSamp
    Dim As String minute, second

    If XMP_IsPaused Or Not XMP_IsPlaying Then Color 12 Else Color 7

    Locate 21, 43: Print "Buffered sound:"; Fix(_SndRawLen(__XMPPlayer.soundHandle) * 1000); "ms ";
    Locate 22, 43: Print "Position / Row:"; __XMPPlayer.frameInfo.position; "/"; __XMPPlayer.frameInfo.row; "  ";
    Locate 23, 43: Print "Current volume:"; Volume;
    minute = Right$("00" + LTrim$(Str$((__XMPPlayer.frameInfo.time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((__XMPPlayer.frameInfo.time + 500) \ 1000) Mod 60)), 2)
    Locate 24, 43: Print Using "  Elapsed time: &:& (mm:ss)"; minute; second;
    minute = Right$("00" + LTrim$(Str$((__XMPPlayer.frameInfo.total_time + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((__XMPPlayer.frameInfo.total_time + 500) \ 1000) Mod 60)), 2)
    Locate 25, 43: Print Using "    Total time: &:& (mm:ss)"; minute; second;
    Locate 26, 50: Print "Looping: "; BoolToStr(XMP_IsLooping, 2); " ";

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

    _Display ' flip the frambuffer

    Exit Sub

    DrawOscillators: '--- animate wave form oscillators ---

    'As the oscillators width is probably <> number of samples, we need to
    'scale the x-position, same is with the amplitude (y-position).
    ow = 597: oh = 46 'oscillator width/height
    '-----
    Color 6: Locate 1, 24: Print Using "Current volume boost factor = #.##"; VolBoost;
    '-----
    Color 7: _PrintString (224, 32), "Left Channel (Wave plot)"
    Color 2: _PrintString (20, 32), "0 [ms]"
    Color 2: _PrintString (556, 32), Left$(Str$(__XMPPlayer.soundBufferFrames / _SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 96 'framecolor/origin
    For i = 0 To __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        lSamp = _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, Integer)
        xp = (ow / __XMPPlayer.soundBufferFrames * (i / XMP_SOUND_BUFFER_FRAME_SIZE)) + x
        yp = (lSamp / 32768! * VolBoost * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 48)-(620, 144), c, B
    '-----
    Color 7: _PrintString (220, 160), "Right Channel (Wave plot)"
    Color 2: _PrintString (20, 160), "0 [ms]"
    Color 2: _PrintString (556, 160), Left$(Str$(__XMPPlayer.soundBufferFrames / _SndRate * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 224 'framecolor/origin
    For i = 0 To __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        rSamp = _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, Integer)
        xp = (ow / __XMPPlayer.soundBufferFrames * (i / XMP_SOUND_BUFFER_FRAME_SIZE)) + x
        yp = (rSamp / 32768! * VolBoost * oh)
        If Abs(yp) > oh Then yp = oh * Sgn(yp) + y: c = 12 Else yp = yp + y
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 176)-(620, 272), c, B

    Return

    DrawFFT: '--- animate FFT frequencey oscillators ---

    ' Fill the FFT arrays with sample data
    For i = 0 To __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
        lSig(i \ XMP_SOUND_BUFFER_FRAME_SIZE) = _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, Integer) / 32768!
        rSig(i \ XMP_SOUND_BUFFER_FRAME_SIZE) = _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, Integer) / 32768!
    Next

    'As the oscillators width is probably <> frequency range, we need to
    'scale the x-position, same is with the magnitude (y-position).
    ow = 597: oh = 92 'oscillator width/height
    '-----
    Color 6: Locate 1, 3: Print Using "Current frequence zoom factor = ##  /  Current magnitude scale factor = #.##"; FreqFact; MagFact;
    '-----
    RFFT FFTr(), FFTi(), lSig()
    Color 7: _PrintString (188, 32), "Left Channel (Frequency spectrum)"
    Color 2: _PrintString (12, 32), Left$(Str$(_SndRate \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    Color 2: _PrintString (532, 32), Left$(Str$((__XMPPlayer.soundBufferFrames \ FreqFact) * _SndRate \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    x = 22: y = 142 'origin
    For i = 0 To __XMPPlayer.soundBufferFrames \ FreqFact
        xp = (ow / (__XMPPlayer.soundBufferFrames / FreqFact) * i) + x
        yp = MagFact * Sqr((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        If yp > oh Then yp = y - oh Else yp = y - yp
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 48)-(620, 144), 7, B
    '-----
    RFFT FFTr(), FFTi(), rSig()
    Color 7: _PrintString (184, 160), "Right Channel (Frequency spectrum)"
    Color 2: _PrintString (12, 160), Left$(Str$(_SndRate \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    Color 2: _PrintString (532, 160), Left$(Str$((__XMPPlayer.soundBufferFrames \ FreqFact) * _SndRate \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    x = 22: y = 270 'origin
    For i = 0 To __XMPPlayer.soundBufferFrames \ FreqFact
        xp = (ow / (__XMPPlayer.soundBufferFrames / FreqFact) * i) + x
        yp = MagFact * Sqr((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        If yp > oh Then yp = y - oh Else yp = y - yp
        If i = 0 Then PSet (xp, yp), 10 Else Line -(xp, yp), 10
    Next
    Line (20, 176)-(620, 272), 7, B

    Return
End Sub


' Prints the welcome screen
Sub PrintWelcomeScreen
    Const STAR_COUNT = 512 ' the maximum stars that we can show

    Static As Single starX(1 To STAR_COUNT), starY(1 To STAR_COUNT), starZ(1 To STAR_COUNT)
    Static As Long starC(1 To STAR_COUNT)

    Cls

    Dim As Long i
    For i = 1 To STAR_COUNT
        If starX(i) < 1 Or starX(i) >= _Width Or starY(i) < 1 Or starY(i) >= _Height Then
            starX(i) = RandomBetween(0, _Width - 1)
            starY(i) = RandomBetween(0, _Height - 1)
            starZ(i) = 4096
            starC(i) = RandomBetween(9, 15)
        End If

        PSet (starX(i), starY(i)), starC(i)

        starZ(i) = starZ(i) + 0.1!
        starX(i) = ((starX(i) - (_Width / 2)) * (starZ(i) / 4096)) + (_Width / 2)
        starY(i) = ((starY(i) - (_Height / 2)) * (starZ(i) / 4096)) + (_Height / 2)
    Next

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
    Print " |                     ";: Color 11: Print "F1";: Color 8: Print " ............ ";: Color 13: Print "MULTI-SELECT FILES";: Color 14: Print "                     | "
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

    _Display
End Sub


' Processes the command line one file at a time
Sub ProcessCommandLine
    Dim i As _Unsigned Long

    For i = 1 To _CommandCount
        PlaySong Command$(i)
        If _TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
    Next
End Sub


' Processes dropped files one file at a time
Sub ProcessDroppedFiles
    If _TotalDroppedFiles > 0 Then
        ' Make a copy of the dropped file and clear the list
        ReDim fileNames(1 To _TotalDroppedFiles) As String
        Dim i As _Unsigned Long

        For i = 1 To _TotalDroppedFiles
            fileNames(i) = _DroppedFile(i)
        Next
        _FinishDrop ' This is critical

        ' Now play the dropped file one at a time
        For i = LBound(fileNames) To UBound(fileNames)
            PlaySong fileNames(i)
            If _TotalDroppedFiles > 0 Then Exit For ' exit the loop if we have dropped files
        Next
    End If
End Sub


' Processes a list of files selected by the user
Sub ProcessSelectedFiles
    Dim ofdList As String: ofdList = _OpenFileDialog$(APP_NAME, , "*.*", "All files", Not 0) ' NOT 0 = -1 XD

    If ofdList = "" Then Exit Sub

    ReDim fileNames(0 To 0) As String
    Dim As Long i, j

    j = ParseOpenFileDialogList(ofdList, fileNames())

    For i = 0 To j - 1
        PlaySong fileNames(i)
        If _TotalDroppedFiles > 0 Then Exit For ' exit the loop if we have dropped files
    Next
End Sub


' Gets the filename portion from a file path
Function GetFileNameFromPath$ (pathName As String)
    Dim i As _Unsigned Long

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


' This is a simple text parser that can take an input string from OpenFileDialog$ and spit out discrete filepaths in an array
' Returns the number of strings parsed
Function ParseOpenFileDialogList& (ofdList As String, ofdArray() As String)
    Dim As Long p, c
    Dim ts As String

    ReDim ofdArray(0 To 0) As String
    ts = ofdList

    Do
        p = InStr(ts, "|")

        If p = 0 Then
            ofdArray(c) = ts

            ParseOpenFileDialogList& = c + 1
            Exit Function
        End If

        ofdArray(c) = Left$(ts, p - 1)
        ts = Mid$(ts, p + 1)

        c = c + 1
        ReDim _Preserve ofdArray(0 To c) As String
    Loop
End Function


' Loads a whole file from a URL into memory
Function LoadFileFromURL$ (url As String)
    Dim h As Long: h = _OpenClient("HTTP:" + url)

    If h <> 0 Then
        Dim As String content, buffer

        While Not EOF(h)
            _Limit FRAME_RATE_MAX
            Get h, , buffer
            content = content + buffer
        Wend

        Close h

        LoadFileFromURL = content
    End If
End Function


' Gets a string form of the boolean value passed
Function BoolToStr$ (expression As Long, style As _Unsigned _Byte)
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


' Generates a random number between lo & hi
Function RandomBetween& (lo As Long, hi As Long)
    RandomBetween = lo + Rnd * (hi - lo)
End Function


' Vince's FFT routine - https://qb64phoenix.com/forum/showthread.php?tid=270&pid=2005#pid2005
' Modified for efficiency and performance (a little). All arrays passed must be zero based
Sub RFFT (out_r() As Single, out_i() As Single, in_r() As Single)
    Dim As Single w_r, w_i, wm_r, wm_i, u_r, u_i, v_r, v_i, xpr, xpi, xmr, xmi, pi_m
    Dim As Long log2n, rev, i, j, k, m, p, q
    Dim As Long n, half_n

    n = UBound(in_r) + 1
    half_n = n \ 2
    log2n = Log(half_n) / Log(2)

    For i = 0 To half_n - 1
        rev = 0
        For j = 0 To log2n - 1
            If i And (2 ^ j) Then rev = rev + (2 ^ (log2n - 1 - j))
        Next

        out_r(i) = in_r(2 * rev)
        out_i(i) = in_r(2 * rev + 1)
    Next

    For i = 1 To log2n
        m = 2 ^ i
        pi_m = _Pi(-2 / m)
        wm_r = Cos(pi_m)
        wm_i = Sin(pi_m)

        For j = 0 To half_n - 1 Step m
            w_r = 1
            w_i = 0

            For k = 0 To m \ 2 - 1
                p = j + k
                q = p + (m \ 2)

                u_r = w_r * out_r(q) - w_i * out_i(q)
                u_i = w_r * out_i(q) + w_i * out_r(q)
                v_r = out_r(p)
                v_i = out_i(p)

                out_r(p) = v_r + u_r
                out_i(p) = v_i + u_i
                out_r(q) = v_r - u_r
                out_i(q) = v_i - u_i

                u_r = w_r
                u_i = w_i
                w_r = u_r * wm_r - u_i * wm_i
                w_i = u_r * wm_i + u_i * wm_r
            Next
        Next
    Next

    out_r(half_n) = out_r(0)
    out_i(half_n) = out_i(0)

    For i = 1 To half_n - 1
        out_r(half_n + i) = out_r(half_n - i)
        out_i(half_n + i) = out_i(half_n - i)
    Next

    For i = 0 To half_n - 1
        xpr = (out_r(i) + out_r(half_n + i)) * 0.5!
        xpi = (out_i(i) + out_i(half_n + i)) * 0.5!

        xmr = (out_r(i) - out_r(half_n + i)) * 0.5!
        xmi = (out_i(i) - out_i(half_n + i)) * 0.5!

        pi_m = _Pi(2 * i / n)
        out_r(i) = xpr + xpi * Cos(pi_m) - xmr * Sin(pi_m)
        out_i(i) = xmi - xpi * Sin(pi_m) - xmr * Cos(pi_m)
    Next

    For i = 0 To half_n - 1
        out_r(half_n + i) = out_r(half_n - 1 - i)
        out_i(half_n + i) = -out_i(half_n - 1 - i)
    Next
End Sub
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
