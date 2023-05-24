'-----------------------------------------------------------------------------------------------------------------------
' Demo player for Libxmp
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$IF VERSION < 3.7 THEN
        $ERROR This requires the latest version of QB64-PE from https://github.com/QB64-Phoenix-Edition/QB64pe/releases
$END IF
DEFLNG A-Z
OPTION _EXPLICIT
'$STATIC
OPTION BASE 1
$RESIZE:SMOOTH
$UNSTABLE:HTTP
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$EXEICON:'./XMPlayer.ico'
$VERSIONINFO:CompanyName=Samuel Gomes
$VERSIONINFO:FileDescription=XMPlayer executable
$VERSIONINFO:InternalName=XMPlayer
$VERSIONINFO:LegalCopyright=Copyright (c) 2022, Samuel Gomes
$VERSIONINFO:LegalTrademarks=All trademarks are property of their respective owners
$VERSIONINFO:OriginalFilename=XMPlayer.exe
$VERSIONINFO:ProductName=XMPlayer
$VERSIONINFO:Web=https://github.com/a740g
$VERSIONINFO:Comments=https://github.com/a740g
$VERSIONINFO:FILEVERSION#=3,0,0,0
$VERSIONINFO:PRODUCTVERSION#=3,0,0,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
CONST APP_NAME = "XMPlayer"
CONST FRAME_RATE_MAX = 120
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
DIM SHARED Volume AS LONG, OsciType AS LONG
DIM SHARED FreqFact AS LONG, MagFact AS SINGLE, VolBoost AS SINGLE
REDIM SHARED AS SINGLE lSig(0 TO 0), rSig(0 TO 0)
REDIM SHARED AS SINGLE FFTr(0 TO 0), FFTi(0 TO 0)
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
_TITLE APP_NAME + " " + _OS$ ' Set the program name in the titlebar
CHDIR _STARTDIR$ ' Change to the directory specifed by the environment
_ACCEPTFILEDROP ' Enable drag and drop of files
SCREEN 12 ' Use 640x480 resolution
_ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' All the user to press Alt+Enter to go fullscreen
_PRINTMODE _KEEPBACKGROUND ' print without wiping out the background
_DISPLAY ' Only swap buffer when we want
RANDOMIZE TIMER ' seed RNG
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
IF XMP_LoadTuneFromMemory(LoadFileFromURL("http://ftp.modland.com/pub/modules/Screamtracker%203/Siren/jazz%20jackrabbit%202%20-%20labratory%20level.s3m")) THEN
    XMP_Play
    XMP_Loop NOT 0 ' -1 or true really XD. We'll loop so that we do not have to check if it is playing
END IF

DIM k AS LONG

' Main loop
DO
    XMP_Update XMP_SOUND_BUFFER_TIME_DEFAULT ' only here for the into music, otherwise does nothing

    ProcessDroppedFiles

    k = _KEYHIT

    IF k = 15104 THEN ProcessSelectedFiles

    PrintWelcomeScreen ' clears, draws and then displays the welcome screen

    _LIMIT FRAME_RATE_MAX
LOOP UNTIL k = 27

XMP_Stop ' we're being nice

SYSTEM
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Initializes, loads and plays a mod file
' Also checks for input, shows info etc
SUB PlaySong (fileName AS STRING)
    SHARED __XMPPlayer AS __XMPPlayerType

    IF NOT XMP_LoadTuneFromFile(fileName) THEN
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName, "error"
        EXIT SUB
    END IF

    ' Set the app title to display the file name
    _TITLE APP_NAME + " - " + GetFileNameFromPath(fileName)

    XMP_Play

    ' Setup the FFT arrays
    REDIM AS SINGLE lSig(0 TO __XMPPlayer.soundBufferFrames - 1), rSig(0 TO __XMPPlayer.soundBufferFrames - 1)
    REDIM AS SINGLE FFTr(0 TO __XMPPlayer.soundBufferFrames - 1), FFTi(0 TO __XMPPlayer.soundBufferFrames - 1)

    DIM k AS LONG, loopCounter AS _UNSIGNED LONG

    XMP_SetVolume Volume

    DO
        XMP_Update XMP_SOUND_BUFFER_TIME_DEFAULT

        k = _KEYHIT

        SELECT CASE k
            CASE 32 ' SPC - toggle pause
                XMP_Pause NOT XMP_IsPaused

            CASE 43, 61 ' + = volume up
                Volume = Volume + 1
                XMP_SetVolume Volume
                Volume = XMP_GetVolume

            CASE 45, 95 ' - _ volume down
                Volume = Volume - 1
                XMP_SetVolume Volume
                Volume = XMP_GetVolume

            CASE 76, 108 ' L - toggle looping
                XMP_Loop NOT XMP_IsLooping

            CASE 82, 114 ' R -  rewind
                XMP_Replay

            CASE 19200 ' <- - rewind one position
                XMP_GoToPreviousPosition

            CASE 19712 ' -> - fast forward on position
                XMP_GoToNextPosition

            CASE 79, 111 ' O - toggle oscillator
                OsciType = OsciType XOR 3

            CASE 70 ' F - zoom in (smaller freq range)
                IF FreqFact < 16 THEN FreqFact = FreqFact * 2

            CASE 102 ' f - zoom out (bigger freq range)
                IF FreqFact > 2 THEN FreqFact = FreqFact \ 2

            CASE 77 ' M - scale up (bring out peaks)
                IF MagFact < 5.0! THEN MagFact = MagFact + 0.25!

            CASE 109 ' m - scale down (flatten peaks)
                IF MagFact > 1.0! THEN MagFact = MagFact - 0.25!

            CASE 86 ' V - volume up (louder)
                IF VolBoost < 5.0! THEN VolBoost = VolBoost + 0.05!

            CASE 118 ' v - volume down (quieter)
                IF VolBoost > 1.0! THEN VolBoost = VolBoost - 0.05!
        END SELECT

        DrawInfoScreen '  clears, draws and then display the info screen

        _LIMIT FRAME_RATE_MAX

        loopCounter = loopCounter + 1
    LOOP UNTIL NOT XMP_IsPlaying OR k = 27 OR _TOTALDROPPEDFILES > 0

    XMP_Stop

    _TITLE APP_NAME + " " + _OS$ ' Set app title to the way it was
END SUB


' Draws the screen during playback
' This part is mostly from RhoSigma's player code
SUB DrawInfoScreen
    SHARED __XMPPlayer AS __XMPPlayerType

    CLS ' first clear everything

    DIM AS LONG ow, oh, c, x, y, xp, yp, i
    DIM AS SINGLE lSamp, rSamp
    DIM AS STRING minute, second

    IF XMP_IsPaused OR NOT XMP_IsPlaying THEN COLOR 12 ELSE COLOR 7

    LOCATE 21, 43: PRINT "Buffered sound:"; FIX(_SNDRAWLEN(__XMPPlayer.soundHandle) * 1000); "ms ";
    LOCATE 22, 43: PRINT "Position / Row:"; __XMPPlayer.frameInfo.position; "/"; __XMPPlayer.frameInfo.row; "  ";
    LOCATE 23, 43: PRINT "Current volume:"; Volume;
    minute = RIGHT$("00" + LTRIM$(STR$((__XMPPlayer.frameInfo.time + 500) \ 60000)), 2)
    second = RIGHT$("00" + LTRIM$(STR$(((__XMPPlayer.frameInfo.time + 500) \ 1000) MOD 60)), 2)
    LOCATE 24, 43: PRINT USING "  Elapsed time: &:& (mm:ss)"; minute; second;
    minute = RIGHT$("00" + LTRIM$(STR$((__XMPPlayer.frameInfo.total_time + 500) \ 60000)), 2)
    second = RIGHT$("00" + LTRIM$(STR$(((__XMPPlayer.frameInfo.total_time + 500) \ 1000) MOD 60)), 2)
    LOCATE 25, 43: PRINT USING "    Total time: &:& (mm:ss)"; minute; second;
    LOCATE 26, 50: PRINT "Looping: "; BoolToStr(XMP_IsLooping, 2); " ";

    COLOR 9

    IF OsciType = 2 THEN
        LOCATE 19, 7: PRINT "F/f - FREQUENCY ZOOM IN/OUT";
        LOCATE 20, 7: PRINT "M/m - MAGNITUDE SCALE UP/DOWN";
    ELSE
        LOCATE 19, 7: PRINT "                           ";
        LOCATE 20, 7: PRINT "V/v - VOLUME BOOST UP/DOWN   ";
    END IF
    LOCATE 21, 7: PRINT "O|o - TOGGLE OSCILLATOR TYPE";
    LOCATE 22, 7: PRINT "ESC - NEXT / QUIT";
    LOCATE 23, 7: PRINT "SPC - PLAY / PAUSE";
    LOCATE 24, 7: PRINT "=|+ - INCREASE VOLUME";
    LOCATE 25, 7: PRINT "-|_ - DECREASE VOLUME";
    LOCATE 26, 7: PRINT "L|l - LOOP";
    LOCATE 27, 7: PRINT "R|r - REWIND TO START";
    LOCATE 28, 7: PRINT "/ - REWIND/FORWARD ONE POSITION";

    ON OsciType GOSUB DrawOscillators, DrawFFT

    _DISPLAY ' flip the frambuffer

    EXIT SUB

    DrawOscillators: '--- animate wave form oscillators ---

    'As the oscillators width is probably <> number of samples, we need to
    'scale the x-position, same is with the amplitude (y-position).
    ow = 597: oh = 46 'oscillator width/height
    '-----
    COLOR 6: LOCATE 1, 24: PRINT USING "Current volume boost factor = #.##"; VolBoost;
    '-----
    COLOR 7: _PRINTSTRING (224, 32), "Left Channel (Wave plot)"
    COLOR 2: _PRINTSTRING (20, 32), "0 [ms]"
    COLOR 2: _PRINTSTRING (556, 32), LEFT$(STR$(__XMPPlayer.soundBufferFrames / _SNDRATE * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 96 'framecolor/origin
    FOR i = 0 TO __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE STEP XMP_SOUND_BUFFER_FRAME_SIZE
        lSamp = _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, INTEGER)
        xp = (ow / __XMPPlayer.soundBufferFrames * (i / XMP_SOUND_BUFFER_FRAME_SIZE)) + x
        yp = (lSamp / 32768! * VolBoost * oh)
        IF ABS(yp) > oh THEN yp = oh * SGN(yp) + y: c = 12 ELSE yp = yp + y
        IF i = 0 THEN PSET (xp, yp), 10 ELSE LINE -(xp, yp), 10
    NEXT
    LINE (20, 48)-(620, 144), c, B
    '-----
    COLOR 7: _PRINTSTRING (220, 160), "Right Channel (Wave plot)"
    COLOR 2: _PRINTSTRING (20, 160), "0 [ms]"
    COLOR 2: _PRINTSTRING (556, 160), LEFT$(STR$(__XMPPlayer.soundBufferFrames / _SNDRATE * 1000), 6) + " [ms]"
    c = 7: x = 22: y = 224 'framecolor/origin
    FOR i = 0 TO __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE STEP XMP_SOUND_BUFFER_FRAME_SIZE
        rSamp = _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, INTEGER)
        xp = (ow / __XMPPlayer.soundBufferFrames * (i / XMP_SOUND_BUFFER_FRAME_SIZE)) + x
        yp = (rSamp / 32768! * VolBoost * oh)
        IF ABS(yp) > oh THEN yp = oh * SGN(yp) + y: c = 12 ELSE yp = yp + y
        IF i = 0 THEN PSET (xp, yp), 10 ELSE LINE -(xp, yp), 10
    NEXT
    LINE (20, 176)-(620, 272), c, B

    RETURN

    DrawFFT: '--- animate FFT frequencey oscillators ---

    ' Fill the FFT arrays with sample data
    FOR i = 0 TO __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE STEP XMP_SOUND_BUFFER_FRAME_SIZE
        lSig(i \ XMP_SOUND_BUFFER_FRAME_SIZE) = _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, INTEGER) / 32768!
        rSig(i \ XMP_SOUND_BUFFER_FRAME_SIZE) = _MEMGET(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, INTEGER) / 32768!
    NEXT

    'As the oscillators width is probably <> frequency range, we need to
    'scale the x-position, same is with the magnitude (y-position).
    ow = 597: oh = 92 'oscillator width/height
    '-----
    COLOR 6: LOCATE 1, 3: PRINT USING "Current frequence zoom factor = ##  /  Current magnitude scale factor = #.##"; FreqFact; MagFact;
    '-----
    RFFT FFTr(), FFTi(), lSig()
    COLOR 7: _PRINTSTRING (188, 32), "Left Channel (Frequency spectrum)"
    COLOR 2: _PRINTSTRING (12, 32), LEFT$(STR$(_SNDRATE \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    COLOR 2: _PRINTSTRING (532, 32), LEFT$(STR$((__XMPPlayer.soundBufferFrames \ FreqFact) * _SNDRATE \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    x = 22: y = 142 'origin
    FOR i = 0 TO __XMPPlayer.soundBufferFrames \ FreqFact
        xp = (ow / (__XMPPlayer.soundBufferFrames / FreqFact) * i) + x
        yp = MagFact * SQR((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        IF yp > oh THEN yp = y - oh ELSE yp = y - yp
        IF i = 0 THEN PSET (xp, yp), 10 ELSE LINE -(xp, yp), 10
    NEXT
    LINE (20, 48)-(620, 144), 7, B
    '-----
    RFFT FFTr(), FFTi(), rSig()
    COLOR 7: _PRINTSTRING (184, 160), "Right Channel (Frequency spectrum)"
    COLOR 2: _PRINTSTRING (12, 160), LEFT$(STR$(_SNDRATE \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    COLOR 2: _PRINTSTRING (532, 160), LEFT$(STR$((__XMPPlayer.soundBufferFrames \ FreqFact) * _SNDRATE \ __XMPPlayer.soundBufferFrames), 6) + " [Hz]"
    x = 22: y = 270 'origin
    FOR i = 0 TO __XMPPlayer.soundBufferFrames \ FreqFact
        xp = (ow / (__XMPPlayer.soundBufferFrames / FreqFact) * i) + x
        yp = MagFact * SQR((FFTr(i) * FFTr(i)) + (FFTi(i) * FFTi(i)))
        IF yp > oh THEN yp = y - oh ELSE yp = y - yp
        IF i = 0 THEN PSET (xp, yp), 10 ELSE LINE -(xp, yp), 10
    NEXT
    LINE (20, 176)-(620, 272), 7, B

    RETURN
END SUB


' Prints the welcome screen
SUB PrintWelcomeScreen
    CONST STAR_COUNT = 512 ' the maximum stars that we can show

    STATIC AS SINGLE starX(1 TO STAR_COUNT), starY(1 TO STAR_COUNT), starZ(1 TO STAR_COUNT)
    STATIC AS LONG starC(1 TO STAR_COUNT)

    CLS

    DIM AS LONG i
    FOR i = 1 TO STAR_COUNT
        IF starX(i) < 1 OR starX(i) >= _WIDTH OR starY(i) < 1 OR starY(i) >= _HEIGHT THEN
            starX(i) = RandomBetween(0, _WIDTH - 1)
            starY(i) = RandomBetween(0, _HEIGHT - 1)
            starZ(i) = 4096
            starC(i) = RandomBetween(9, 15)
        END IF

        PSET (starX(i), starY(i)), starC(i)

        starZ(i) = starZ(i) + 0.1!
        starX(i) = ((starX(i) - (_WIDTH / 2)) * (starZ(i) / 4096)) + (_WIDTH / 2)
        starY(i) = ((starY(i) - (_HEIGHT / 2)) * (starZ(i) / 4096)) + (_HEIGHT / 2)
    NEXT

    LOCATE 1, 1
    COLOR 12, 0
    IF TIMER MOD 7 = 0 THEN
        PRINT "              _    _          ___    _                                     (+_+)"
    ELSEIF TIMER MOD 13 = 0 THEN
        PRINT "              _    _          ___    _                                     (*_*)"
    ELSE
        PRINT "              _    _          ___    _                                     (ù_ù)"
    END IF
    PRINT "             ( )  ( )/ \_/ \(   _ \ (_ )                                        "
    PRINT "              \ \/ / |     ||  |_) ) |(|    _ _  _   _    __   _ __             "
    COLOR 15
    PRINT "               )  (  | (_) ||   __/  |()  / _  )( ) ( ) / __ \(  __)            "
    PRINT "              / /\ \ | | | ||  |     | | ( (_| || (_) |(  ___/| |               "
    COLOR 10
    PRINT "_.___________( )  (_)(_) (_)( _)    ( (_) \(_ _) \__  | )\___)(()_____________._"
    PRINT " |           /(                     (_)   (_)   ( )_| |(__)   (_)             | "
    PRINT " |          (__)                                 \___/                        | "
    COLOR 14
    PRINT " |                                                                            | "
    PRINT " |                     ";: COLOR 11: PRINT "F1";: COLOR 8: PRINT " ............ ";: COLOR 13: PRINT "MULTI-SELECT FILES";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "ESC";: COLOR 8: PRINT " .................... ";: COLOR 13: PRINT "NEXT/QUIT";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "SPC";: COLOR 8: PRINT " ........................ ";: COLOR 13: PRINT "PAUSE";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "=|+";: COLOR 8: PRINT " .............. ";: COLOR 13: PRINT "INCREASE VOLUME";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "-|_";: COLOR 8: PRINT " .............. ";: COLOR 13: PRINT "DECREASE VOLUME";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "L|l";: COLOR 8: PRINT " ......................... ";: COLOR 13: PRINT "LOOP";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "R|r";: COLOR 8: PRINT " .............. ";: COLOR 13: PRINT "REWIND TO START";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "/";: COLOR 8: PRINT " .. ";: COLOR 13: PRINT "REWIND/FORWARD ONE POSITION";: COLOR 14: PRINT "                     | "
    PRINT " |                     ";: COLOR 11: PRINT "O|o";: COLOR 8: PRINT " ....... ";: COLOR 13: PRINT "TOGGLE OSCILLATOR TYPE";: COLOR 14: PRINT "                     | "
    PRINT " |                                                                            | "
    PRINT " |                                                                            | "
    PRINT " | ";: COLOR 9: PRINT "DRAG AND DROP MULTIPLE MOD FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: COLOR 14: PRINT " | "
    PRINT " |                                                                            | "
    PRINT " | ";: COLOR 9: PRINT "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: COLOR 14: PRINT "  | "
    PRINT " |                                                                            | "
    PRINT " |    ";: COLOR 9: PRINT "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: COLOR 14: PRINT "    | "
    PRINT " |                                                                            | "
    PRINT " |                 ";: COLOR 9: PRINT "https://github.com/a740g/QB64-LibXMPLite";: COLOR 14: PRINT "                   | "
    PRINT "_|_                                                                          _|_"
    PRINT " `/__________________________________________________________________________\' ";

    _DISPLAY
END SUB


' Processes the command line one file at a time
SUB ProcessCommandLine
    DIM i AS _UNSIGNED LONG

    FOR i = 1 TO _COMMANDCOUNT
        PlaySong COMMAND$(i)
        IF _TOTALDROPPEDFILES > 0 THEN EXIT FOR ' Exit the loop if we have dropped files
    NEXT
END SUB


' Processes dropped files one file at a time
SUB ProcessDroppedFiles
    IF _TOTALDROPPEDFILES > 0 THEN
        ' Make a copy of the dropped file and clear the list
        REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING
        DIM i AS _UNSIGNED LONG

        FOR i = 1 TO _TOTALDROPPEDFILES
            fileNames(i) = _DROPPEDFILE(i)
        NEXT
        _FINISHDROP ' This is critical

        ' Now play the dropped file one at a time
        FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
            PlaySong fileNames(i)
            IF _TOTALDROPPEDFILES > 0 THEN EXIT FOR ' exit the loop if we have dropped files
        NEXT
    END IF
END SUB


' Processes a list of files selected by the user
SUB ProcessSelectedFiles
    DIM ofdList AS STRING: ofdList = _OPENFILEDIALOG$(APP_NAME, , "*.*", "All files", NOT 0) ' NOT 0 = -1 XD

    IF ofdList = "" THEN EXIT SUB

    REDIM fileNames(0 TO 0) AS STRING
    DIM AS LONG i, j

    j = ParseOpenFileDialogList(ofdList, fileNames())

    FOR i = 0 TO j - 1
        PlaySong fileNames(i)
        IF _TOTALDROPPEDFILES > 0 THEN EXIT FOR ' exit the loop if we have dropped files
    NEXT
END SUB


' Gets the filename portion from a file path
FUNCTION GetFileNameFromPath$ (pathName AS STRING)
    DIM i AS _UNSIGNED LONG

    ' Retrieve the position of the first / or \ in the parameter from the
    FOR i = LEN(pathName) TO 1 STEP -1
        IF ASC(pathName, i) = 47 OR ASC(pathName, i) = 92 THEN EXIT FOR
    NEXT

    ' Return the full string if pathsep was not found
    IF i = 0 THEN
        GetFileNameFromPath = pathName
    ELSE
        GetFileNameFromPath = RIGHT$(pathName, LEN(pathName) - i)
    END IF
END FUNCTION


' This is a simple text parser that can take an input string from OpenFileDialog$ and spit out discrete filepaths in an array
' Returns the number of strings parsed
FUNCTION ParseOpenFileDialogList& (ofdList AS STRING, ofdArray() AS STRING)
    DIM AS LONG p, c
    DIM ts AS STRING

    REDIM ofdArray(0 TO 0) AS STRING
    ts = ofdList

    DO
        p = INSTR(ts, "|")

        IF p = 0 THEN
            ofdArray(c) = ts

            ParseOpenFileDialogList& = c + 1
            EXIT FUNCTION
        END IF

        ofdArray(c) = LEFT$(ts, p - 1)
        ts = MID$(ts, p + 1)

        c = c + 1
        REDIM _PRESERVE ofdArray(0 TO c) AS STRING
    LOOP
END FUNCTION


' Loads a whole file from a URL into memory
FUNCTION LoadFileFromURL$ (url AS STRING)
    DIM h AS LONG: h = _OPENCLIENT("HTTP:" + url)

    IF h <> 0 THEN
        DIM AS STRING content, buffer

        WHILE NOT EOF(h)
            _LIMIT FRAME_RATE_MAX
            GET h, , buffer
            content = content + buffer
        WEND

        CLOSE h

        LoadFileFromURL = content
    END IF
END FUNCTION


' Gets a string form of the boolean value passed
FUNCTION BoolToStr$ (expression AS LONG, style AS _UNSIGNED _BYTE)
    SELECT CASE style
        CASE 1
            IF expression THEN BoolToStr = "On" ELSE BoolToStr = "Off"
        CASE 2
            IF expression THEN BoolToStr = "Enabled" ELSE BoolToStr = "Disabled"
        CASE 3
            IF expression THEN BoolToStr = "1" ELSE BoolToStr = "0"
        CASE ELSE
            IF expression THEN BoolToStr = "True" ELSE BoolToStr = "False"
    END SELECT
END FUNCTION


' Generates a random number between lo & hi
FUNCTION RandomBetween& (lo AS LONG, hi AS LONG)
    RandomBetween = lo + RND * (hi - lo)
END FUNCTION


' Vince's FFT routine - https://qb64phoenix.com/forum/showthread.php?tid=270&pid=2005#pid2005
' Modified for efficiency and performance (a little). All arrays passed must be zero based
SUB RFFT (out_r() AS SINGLE, out_i() AS SINGLE, in_r() AS SINGLE)
    DIM AS SINGLE w_r, w_i, wm_r, wm_i, u_r, u_i, v_r, v_i, xpr, xpi, xmr, xmi, pi_m
    DIM AS LONG log2n, rev, i, j, k, m, p, q
    DIM AS LONG n, half_n

    n = UBOUND(in_r) + 1
    half_n = n \ 2
    log2n = LOG(half_n) / LOG(2)

    FOR i = 0 TO half_n - 1
        rev = 0
        FOR j = 0 TO log2n - 1
            IF i AND (2 ^ j) THEN rev = rev + (2 ^ (log2n - 1 - j))
        NEXT

        out_r(i) = in_r(2 * rev)
        out_i(i) = in_r(2 * rev + 1)
    NEXT

    FOR i = 1 TO log2n
        m = 2 ^ i
        pi_m = _PI(-2 / m)
        wm_r = COS(pi_m)
        wm_i = SIN(pi_m)

        FOR j = 0 TO half_n - 1 STEP m
            w_r = 1
            w_i = 0

            FOR k = 0 TO m \ 2 - 1
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
            NEXT
        NEXT
    NEXT

    out_r(half_n) = out_r(0)
    out_i(half_n) = out_i(0)

    FOR i = 1 TO half_n - 1
        out_r(half_n + i) = out_r(half_n - i)
        out_i(half_n + i) = out_i(half_n - i)
    NEXT

    FOR i = 0 TO half_n - 1
        xpr = (out_r(i) + out_r(half_n + i)) * 0.5!
        xpi = (out_i(i) + out_i(half_n + i)) * 0.5!

        xmr = (out_r(i) - out_r(half_n + i)) * 0.5!
        xmi = (out_i(i) - out_i(half_n + i)) * 0.5!

        pi_m = _PI(2 * i / n)
        out_r(i) = xpr + xpi * COS(pi_m) - xmr * SIN(pi_m)
        out_i(i) = xmi - xpi * SIN(pi_m) - xmr * COS(pi_m)
    NEXT

    FOR i = 0 TO half_n - 1
        out_r(half_n + i) = out_r(half_n - 1 - i)
        out_i(half_n + i) = -out_i(half_n - 1 - i)
    NEXT
END SUB
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
