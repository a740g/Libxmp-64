'-----------------------------------------------------------------------------------------------------------------------
' Demo player for Libxmp
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
_DEFINE A-Z AS LONG
OPTION _EXPLICIT
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='XMPlayer executable'
$VERSIONINFO:InternalName='XMPlayer'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='XMPlayer.exe'
$VERSIONINFO:ProductName='XMPlayer'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=4,2,1,0
$VERSIONINFO:PRODUCTVERSION#=4,2,1,0
$EXEICON:'./XMPlayer.ico'
$RESIZE:SMOOTH
'$STATIC
OPTION BASE 1
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
$COLOR:32
'$INCLUDE:'Libxmp64.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
' Some important constants
CONST APP_NAME = "XMPlayer"
CONST FRAME_RATE_MAX& = 60&
' Program events
CONST EVENT_NONE%% = 0%% ' idle
CONST EVENT_QUIT%% = 1%% ' user wants to quit
CONST EVENT_CMDS%% = 2%% ' process command line
CONST EVENT_LOAD%% = 3%% ' user want to load files
CONST EVENT_DROP%% = 4%% ' user dropped files
CONST EVENT_PLAY%% = 5%% ' play next song
CONST EVENT_HTTP%% = 6%% ' user wants to downloads and play random tunes from modarchive.org
' Background constants
CONST STAR_COUNT& = 1024& ' the maximum stars that we can show
CONST CIRCLE_WAVE_COUNT& = 32&
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' USER DEFINED TYPES
'-----------------------------------------------------------------------------------------------------------------------
TYPE Vector2Type
    x AS SINGLE
    y AS SINGLE
END TYPE

TYPE Vector3Type
    x AS SINGLE
    y AS SINGLE
    z AS SINGLE
END TYPE

TYPE RGBType
    r AS _UNSIGNED _BYTE
    g AS _UNSIGNED _BYTE
    b AS _UNSIGNED _BYTE
END TYPE

TYPE StarType
    p AS Vector3Type ' position
    a AS SINGLE ' angle
    c AS _UNSIGNED LONG ' color
END TYPE

TYPE CircleWaveType
    p AS Vector2Type ' position
    v AS Vector2Type ' velocity
    r AS SINGLE ' radius
    c AS RGBType ' color
    a AS SINGLE ' alpha
    s AS SINGLE ' fade speed
END TYPE
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
DIM SHARED Volume AS LONG, OsciType AS LONG, BackGroundType AS LONG
DIM SHARED FreqFact AS LONG, MagFact AS SINGLE, VolBoost AS SINGLE
REDIM SHARED FFT(0, 0) AS SINGLE
DIM SHARED Stars(1 TO STAR_COUNT) AS StarType
DIM SHARED CircleWaves(1 TO CIRCLE_WAVE_COUNT) AS CircleWaveType
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
_TITLE APP_NAME + " " + _OS$ ' set the program name in the titlebar
CHDIR _STARTDIR$ ' change to the directory specifed by the environment
_ACCEPTFILEDROP ' enable drag and drop of files
SCREEN _NEWIMAGE(640, 480, 32) ' use 640x480 resolution
_ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' all the user to press Alt+Enter to go fullscreen
_PRINTMODE _KEEPBACKGROUND ' print without wiping out the background
RANDOMIZE TIMER ' seed RNG
_DISPLAY ' only swap buffer when we want
Volume = XMP_VOLUME_MAX ' set initial volume as 100%
OsciType = 2 ' 1 = Wave plot, 2 = Frequency spectrum (FFT)
BackGroundType = 2 ' 0 = None, 1 = Stars, 2 = Circle Waves
FreqFact = 8 ' frequency spectrum X-axis scale (powers of two only [4-16])
MagFact = 3! ' frequency spectrum Y-axis scale (magnitude [1.0-5.0])
VolBoost = 1 ' no change
InitializeStars Stars()
InitializeCircleWaves CircleWaves()

DIM event AS _BYTE: event = EVENT_CMDS ' default to command line event first

' Main loop
DO
    SELECT CASE event
        CASE EVENT_QUIT
            EXIT DO

        CASE EVENT_DROP
            event = OnDroppedFiles

        CASE EVENT_LOAD
            event = OnSelectedFiles

        CASE EVENT_CMDS
            event = OnCommandLine

        CASE EVENT_HTTP
            event = OnModArchiveFiles

        CASE ELSE
            event = OnWelcomeScreen
    END SELECT
LOOP

_AUTODISPLAY
SYSTEM
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Initializes, loads and plays a mod file
' Also checks for input, shows info etc
FUNCTION OnPlaySong%% (fileName AS STRING)
    SHARED __XMPPlayer AS __XMPPlayerType ' we are using this only to access the library internals to draw the analyzer

    OnPlaySong = EVENT_PLAY ' default event is to play next song

    DIM buffer AS STRING: buffer = LoadFile(fileName) ' load the whole file to memory

    IF NOT XMP_LoadTuneFromMemory(buffer) THEN
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName, "error"
        EXIT FUNCTION
    END IF

    ' Setup the FFT arrays
    REDIM FFT(0 TO 1, 0 TO __XMPPlayer.soundBufferFrames \ 2 - 1) AS SINGLE

    ' Set the app title to display the file name
    DIM tuneTitle AS STRING: tuneTitle = XMP_GetTuneName
    IF tuneTitle = _STR_EMPTY THEN
        IF LEN(GetDriveOrSchemeFromPathOrURL(fileName)) > 2 THEN
            tuneTitle = GetLegalFileNameFromURL(fileName)
        ELSE
            tuneTitle = GetFileNameFromPathOrURL(fileName)
        END IF
    END IF

    _TITLE tuneTitle + " - " + APP_NAME + " [" + XMP_GetTuneType + "]"

    XMP_Play

    DIM k AS LONG

    XMP_SetVolume Volume

    DO
        XMP_Update

        DrawVisualization '  clears, draws and then display the info screen

        k = _KEYHIT

        SELECT CASE k
            CASE _KEY_ESC
                EXIT DO

            CASE _ASC_SPACE ' SPC - toggle pause
                XMP_Pause NOT XMP_IsPaused

            CASE 43, 61 ' + = volume up
                XMP_SetVolume Volume + 1
                Volume = XMP_GetVolume

            CASE 45, 95 ' - _ volume down
                XMP_SetVolume Volume - 1
                Volume = XMP_GetVolume

            CASE 76, 108 ' L - toggle looping
                XMP_Loop NOT XMP_IsLooping

            CASE 82, 114 ' R -  rewind
                XMP_Replay

            CASE _KEY_LEFT ' <- - rewind one position
                XMP_GoToPreviousPosition

            CASE _KEY_RIGHT ' -> - fast forward on position
                XMP_GoToNextPosition

            CASE 79, 111 ' O - toggle oscillator
                OsciType = OsciType XOR 3

            CASE 66, 98 ' B - toggle background
                BackGroundType = (BackGroundType + 1) MOD 3

            CASE 70 ' F - zoom in (smaller freq range)
                IF FreqFact < 16 THEN FreqFact = FreqFact * 2

            CASE 102 ' f - zoom out (bigger freq range)
                IF FreqFact > 4 THEN FreqFact = FreqFact \ 2

            CASE 77 ' M - scale up (bring out peaks)
                IF MagFact < 5.0! THEN MagFact = MagFact + 0.25!

            CASE 109 ' m - scale down (flatten peaks)
                IF MagFact > 1.0! THEN MagFact = MagFact - 0.25!

            CASE 86 ' V - volume up (louder)
                IF VolBoost < 5.0! THEN VolBoost = VolBoost + 0.05!

            CASE 118 ' v - volume down (quieter)
                IF VolBoost > 1.0! THEN VolBoost = VolBoost - 0.05!

            CASE _KEY_F1 ' F1
                OnPlaySong = EVENT_LOAD
                EXIT DO

            CASE _KEY_F6 ' F6: quick save file loaded from ModArchive
                QuickSave buffer, fileName

            CASE 21248 ' Shift + Delete - you known what it does
                IF LEN(GetDriveOrSchemeFromPathOrURL(fileName)) > 2 THEN
                    _MESSAGEBOX APP_NAME, "You cannot delete " + fileName + "!", "error"
                ELSE
                    IF _MESSAGEBOX(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 THEN
                        KILL fileName
                        EXIT DO
                    END IF
                END IF
        END SELECT

        IF _TOTALDROPPEDFILES > 0 THEN
            OnPlaySong = EVENT_DROP
            EXIT DO
        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE XMP_IsPlaying

    XMP_Stop

    _TITLE APP_NAME + " " + _OS$ ' Set app title to the way it was
END FUNCTION


' Draws the visualization screen during playback
SUB DrawVisualization
    SHARED __XMPPlayer AS __XMPPlayerType ' we are using this only to access the library internals to draw the analyzer
    SHARED __XMPSoundBuffer() AS INTEGER

    ' Do FFT and calculate intensity for both left and right channel
    DIM intensity AS SINGLE: intensity = (AudioAnalyzer_FFT(__XMPSoundBuffer(), 0, 2, FFT()) + AudioAnalyzer_FFT(__XMPSoundBuffer(), 1, 2, FFT())) / 2!

    CLS , Black ' first clear everything

    ' Draw the background
    SELECT CASE BackGroundType
        CASE 1
            ' Larger values of intensity will have more impact on speed and we'll not let this go to zero else LOG will puke
            UpdateAndDrawStars Stars(), -8.0! * LOG(1.0000001192093! - intensity)
        CASE 2
            UpdateAndDrawCircleWaves CircleWaves(), 8.0! * intensity
    END SELECT

    IF XMP_IsPaused _ORELSE NOT XMP_IsPlaying THEN COLOR OrangeRed ELSE COLOR White

    ' Draw the tune info
    DIM AS STRING * 2 minute, second

    LOCATE 21, 49: PRINT "Buffered sound:"; FIX(_SNDRAWLEN(__XMPPlayer.soundHandle) * 1000); "ms ";
    LOCATE 22, 49: PRINT "Position / Row:"; __XMPPlayer.frameInfo.position; "/"; __XMPPlayer.frameInfo.row; "  ";
    LOCATE 23, 49: PRINT USING "Current volume: ###%"; Volume;
    minute = RIGHT$("00" + LTRIM$(STR$((__XMPPlayer.frameInfo.time + 500) \ 60000)), 2)
    second = RIGHT$("00" + LTRIM$(STR$(((__XMPPlayer.frameInfo.time + 500) \ 1000) MOD 60)), 2)
    LOCATE 24, 49: PRINT USING "  Elapsed time: &:& (mm:ss)"; minute; second;
    minute = RIGHT$("00" + LTRIM$(STR$((__XMPPlayer.frameInfo.total_time + 500) \ 60000)), 2)
    second = RIGHT$("00" + LTRIM$(STR$(((__XMPPlayer.frameInfo.total_time + 500) \ 1000) MOD 60)), 2)
    LOCATE 25, 49: PRINT USING "    Total time: &:& (mm:ss)"; minute; second;
    LOCATE 26, 56: PRINT "Looping: "; BoolToStr(XMP_IsLooping, 2); " ";

    COLOR Cyan

    IF OsciType = 2 THEN
        LOCATE 19, 4: PRINT "F/f - FREQUENCY ZOOM IN / OUT";
        LOCATE 20, 4: PRINT "M/m - MAGNITUDE SCALE UP / DOWN";
    ELSE
        LOCATE 20, 4: PRINT "V/v - ANALYZER AMPLITUDE UP / DOWN";
    END IF
    LOCATE 21, 4: PRINT "O|o - TOGGLE OSCILLATOR TYPE";
    LOCATE 22, 4: PRINT "B/b - TOGGLE BACKGROUND TYPE";
    LOCATE 23, 4: PRINT "ESC - NEXT / QUIT";
    LOCATE 24, 4: PRINT "SPC - PLAY / PAUSE";
    LOCATE 25, 4: PRINT "=|+ - INCREASE VOLUME";
    LOCATE 26, 4: PRINT "-|_ - DECREASE VOLUME";
    LOCATE 27, 4: PRINT "L|l - LOOP";
    LOCATE 28, 4: PRINT "R|r - REWIND TO START";
    LOCATE 29, 4: PRINT "/ - REWIND/FORWARD ONE POSITION";

    DIM AS LONG i, xp, yp
    DIM AS _UNSIGNED LONG c
    DIM AS STRING text

    ON OsciType GOSUB DrawOscillators, DrawFFT

    ' Draw the boxes around the analyzer viewport
    LINE (20, 48)-(620, 144), White, B
    LINE (20, 176)-(620, 272), White, B

    _DISPLAY ' flip the frambuffer

    EXIT SUB

    '-------------------------------------------------------------------------------------------------------------------
    DrawOscillators: ' animate waveform oscillators
    '-------------------------------------------------------------------------------------------------------------------
    COLOR DarkOrange
    LOCATE 1, 23: PRINT USING "Current amplitude boost factor = #.##"; VolBoost;
    COLOR White
    LOCATE 3, 29: PRINT "Left channel (wave plot)";
    LOCATE 11, 29: PRINT "Right channel (wave plot)"
    COLOR Lime
    LOCATE 3, 3: PRINT "0 [ms]";
    LOCATE 11, 3: PRINT "0 [ms]";
    text = STR$((__XMPPlayer.soundBufferFrames * 1000~&) \ _SNDRATE) + " [ms]"
    i = 79 - LEN(text)
    LOCATE 3, i: PRINT text;
    LOCATE 11, i: PRINT text;

    ' As the oscillators width is probably <> number of samples, we need to scale the x-position, same is with the amplitude (y-position)
    ' We'll also do the whole drawing using one loop instead of two to get better performance
    i = 0
    DO WHILE i < __XMPPlayer.soundBufferFrames
        xp = 21 + (i * 599) \ __XMPPlayer.soundBufferFrames ' 21 = x_start, 599 = oscillator_width

        yp = __XMPSoundBuffer(XMP_SOUND_BUFFER_CHANNELS * i) * VolBoost * 0.001434326171875! ' <= 1 / (32768 / 47)
        c = 20 + ABS(yp) * 5 ' we're cheating here a bit to set the color using yp
        IF ABS(yp) > 47 THEN yp = 47 * SGN(yp) + 96 ELSE yp = yp + 96 ' 96 = y_start, 47 = oscillator_height
        LINE (xp, 96)-(xp, yp), _RGBA32(c, 255 - c, 0, 255)

        yp = __XMPSoundBuffer(XMP_SOUND_BUFFER_CHANNELS * i + 1) * VolBoost * 0.001434326171875! ' <= 1 / (32768 / 47)
        c = 20 + ABS(yp) * 5 ' we're cheating here a bit to set the color using yp
        IF ABS(yp) > 47 THEN yp = 47 * SGN(yp) + 224 ELSE yp = yp + 224 ' 224 = y_start, 47 = oscillator_height
        LINE (xp, 224)-(xp, yp), _RGBA32(c, 255 - c, 0, 255)

        i = i + 1
    LOOP

    RETURN
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    DrawFFT: ' animate FFT frequency oscillators
    '-------------------------------------------------------------------------------------------------------------------
    COLOR DarkOrange
    LOCATE 1, 3: PRINT USING "Current frequence zoom factor = ##  /  Current magnitude scale factor = #.##"; FreqFact; MagFact;
    COLOR White
    LOCATE 3, 23: PRINT "Left channel (frequency spectrum)";
    LOCATE 11, 23: PRINT "Right channel (frequency spectrum)";
    COLOR Lime
    text = STR$(_SNDRATE \ __XMPPlayer.soundBufferFrames) + " [Hz]"
    LOCATE 3, 2: PRINT text;
    LOCATE 11, 2: PRINT text;
    DIM freqMax AS LONG: freqMax = __XMPPlayer.soundBufferFrames \ FreqFact
    text = STR$(freqMax * _SNDRATE \ __XMPPlayer.soundBufferFrames) + " [Hz]"
    i = 79 - LEN(text)
    LOCATE 3, i: PRINT text;
    LOCATE 11, i: PRINT text;

    ' As the oscillators width is probably <> frequency range, we need to scale the x-position, same is with the magnitude (y-position)
    ' We'll also do the whole drawing using one loop instead of two to get better performance
    DIM barWidth AS LONG: barWidth = FreqFact \ 2
    i = 0
    DO WHILE i < freqMax
        xp = 21 + (i * 600 - barWidth) \ freqMax ' 21 = x_start, 599 = oscillator_width

        ' Draw the left one first
        yp = MagFact * FFT(0, i)
        IF yp > 95 THEN yp = 143 - 95 ELSE yp = 143 - yp ' 143 = y_start, 95 = oscillator_height
        c = 71 + (143 - yp) * 2 ' we're cheating here a bit to set the color using (y_start - yp)
        LINE (xp, 143)-(xp + barWidth, yp), _RGBA32(c, 255 - c, 0, 255), BF

        ' Then the right one
        yp = MagFact * FFT(1, i)
        IF yp > 95 THEN yp = 271 - 95 ELSE yp = 271 - yp ' 271 = y_start, 95 = oscillator_height
        c = 71 + (271 - yp) * 2 ' we're cheating here a bit to set the color using (y_start - yp)
        LINE (xp, 271)-(xp + barWidth, yp), _RGBA32(c, 255 - c, 0, 255), BF

        i = i + 1
    LOOP

    RETURN
    '-------------------------------------------------------------------------------------------------------------------
END SUB


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    DIM AS LONG k
    DIM e AS _BYTE: e = EVENT_NONE

    DO
        CLS , Black ' clear the framebuffer to black color

        UpdateAndDrawStars Stars(), 0.1!

        LOCATE 1, 1
        COLOR OrangeRed, Black
        IF TIMER MOD 7 = 0 THEN
            PRINT "              _    _          ___    _                                     (*_*)"
        ELSEIF TIMER MOD 13 = 0 THEN
            PRINT "              _    _          ___    _                                     (-_-)"
        ELSE
            PRINT "              _    _          ___    _                                     (+_+)"
        END IF
        PRINT "             ( )  ( )/ \_/ \(   _ \ (_ )                                        "
        PRINT "              \ \/ / |     ||  |_) ) |(|    _ _  _   _    __   _ __             "
        COLOR White
        PRINT "               )  (  | (_) ||   __/  |()  / _  )( ) ( ) / __ \(  __)            "
        PRINT "              / /\ \ | | | ||  |     | | ( (_| || (_) |(  ___/| |               "
        COLOR Lime
        PRINT "_.___________( )  (_)(_) (_)( _)    ( (_) \(_ _) \__  | )\___)(()_____________._"
        PRINT " |           /(                     (_)   (_)   ( )_| |(__)   (_)             | "
        PRINT " |          (__)                                 \___/                        | "
        COLOR Yellow
        PRINT " |                                                                            | "
        PRINT " |                     ";: COLOR Cyan: PRINT "F1";: COLOR Gray: PRINT " ............ ";: COLOR Magenta: PRINT "MULTI-SELECT FILES";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "F2";: COLOR Gray: PRINT " .......... ";: COLOR Magenta: PRINT "PLAY FROM MODARCHIVE";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "F6";: COLOR Gray: PRINT " ................ ";: COLOR Magenta: PRINT "QUICKSAVE FILE";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "ESC";: COLOR Gray: PRINT " .................. ";: COLOR Magenta: PRINT "NEXT / QUIT";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "SPC";: COLOR Gray: PRINT " .................. ";: COLOR Magenta: PRINT "PLAY/ PAUSE";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "=|+";: COLOR Gray: PRINT " .............. ";: COLOR Magenta: PRINT "INCREASE VOLUME";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "-|_";: COLOR Gray: PRINT " .............. ";: COLOR Magenta: PRINT "DECREASE VOLUME";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "L|l";: COLOR Gray: PRINT " ......................... ";: COLOR Magenta: PRINT "LOOP";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "R|r";: COLOR Gray: PRINT " .............. ";: COLOR Magenta: PRINT "REWIND TO START";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "/";: COLOR Gray: PRINT " .. ";: COLOR Magenta: PRINT "REWIND/FORWARD ONE POSITION";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "O|o";: COLOR Gray: PRINT " ....... ";: COLOR Magenta: PRINT "TOGGLE OSCILLATOR TYPE";: COLOR Yellow: PRINT "                     | "
        PRINT " |                     ";: COLOR Cyan: PRINT "B|b";: COLOR Gray: PRINT " ....... ";: COLOR Magenta: PRINT "TOGGLE BACKGROUND TYPE";: COLOR Yellow: PRINT "                     | "
        PRINT " |                                                                            | "
        PRINT " |                                                                            | "
        PRINT " | ";: COLOR LightBlue: PRINT "DRAG AND DROP MULTIPLE MOD FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: COLOR Yellow: PRINT " | "
        PRINT " | ";: COLOR LightBlue: PRINT "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: COLOR Yellow: PRINT "  | "
        PRINT " |    ";: COLOR LightBlue: PRINT "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: COLOR Yellow: PRINT "    | "
        PRINT " |                     ";: COLOR LightBlue: PRINT "https://github.com/a740g/Libxmp-64";: COLOR Yellow: PRINT "                     | "
        PRINT "_|_                                                                          _|_"
        PRINT " `/__________________________________________________________________________\' ";

        k = _KEYHIT

        IF k = _KEY_ESC THEN ' ESC
            e = EVENT_QUIT
        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            e = EVENT_DROP
        ELSEIF k = _KEY_F1 THEN ' F1
            e = EVENT_LOAD
        ELSEIF k = _KEY_F2 THEN ' F2
            e = EVENT_HTTP
        END IF

        _DISPLAY ' flip the framebuffer

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


' Processes the command line one file at a time
FUNCTION OnCommandLine%%
    DIM e AS _BYTE: e = EVENT_NONE

    IF (COMMAND$(1) = "/?" _ORELSE COMMAND$(1) = "-?") THEN
        _MESSAGEBOX APP_NAME, APP_NAME + CHR$(_ASC_CR) _
            + "Syntax: " + APP_NAME + " [filespec]" + CHR$(_ASC_CR) _
            + "    /?: Shows this message" + STRING$(2, _ASC_CR) _
            + "Note: Wildcards are supported" + STRING$(2, _ASC_CR) _
            + "Copyright (c) 2024, Samuel Gomes" + STRING$(2, _ASC_CR) _
            + "https://github.com/a740g/", "info"

        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO _COMMANDCOUNT
            e = OnPlaySong(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


' Processes dropped files one file at a time
FUNCTION OnDroppedFiles%%
    ' Make a copy of the dropped file and clear the list
    REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING

    DIM e AS _BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO _TOTALDROPPEDFILES
        fileNames(i) = _DROPPEDFILE(i)
    NEXT
    _FINISHDROP ' This is critical

    ' Now play the dropped file one at a time
    FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
        e = OnPlaySong(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    OnDroppedFiles = e
END FUNCTION


' Processes a list of files selected by the user
FUNCTION OnSelectedFiles%%
    DIM ofdList AS STRING
    DIM e AS _BYTE: e = EVENT_NONE

    ofdList = _OPENFILEDIALOG$(APP_NAME, , , "All files", _TRUE)

    IF ofdList = _STR_EMPTY THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = ParseOpenFileDialogList(ofdList, fileNames())

    DIM i AS LONG: i = 0
    DO WHILE i < j
        e = OnPlaySong(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT DO
        i = i + 1
    LOOP

    OnSelectedFiles = e
END FUNCTION


' Loads and plays random MODs from modarchive.org
FUNCTION OnModArchiveFiles%%
    DIM e AS _BYTE: e = EVENT_NONE
    DIM modArchiveFileName AS STRING

    DO
        modArchiveFileName = GetRandomModArchiveFileName$

        _TITLE "Downloading: " + GetLegalFileNameFromURL(modArchiveFileName) + " - " + APP_NAME

        e = OnPlaySong(modArchiveFileName)
    LOOP WHILE e = EVENT_NONE _ORELSE e = EVENT_PLAY

    OnModArchiveFiles = e
END FUNCTION


' Gets a random file URL from www.modarchive.org
FUNCTION GetRandomModArchiveFileName$
    DIM buffer AS STRING: buffer = LoadFileFromURL("https://modarchive.org/index.php?request=view_random")
    DIM bufPos AS LONG: bufPos = INSTR(buffer, "https://api.modarchive.org/downloads.php?moduleid=")

    IF bufPos > 0 THEN
        GetRandomModArchiveFileName = MID$(buffer, bufPos, INSTR(bufPos, buffer, CHR$(34)) - bufPos)
    END IF
END FUNCTION


' Saves a file loaded from the internet
SUB QuickSave (buffer AS STRING, fileName AS STRING)
    STATIC savePath AS STRING, alwaysUseSamePath AS _BYTE, stopNagging AS _BYTE

    IF LEN(GetDriveOrSchemeFromPathOrURL(fileName)) > 2 THEN
        ' This is a file from the web
        IF NOT _DIREXISTS(savePath) _ORELSE NOT alwaysUseSamePath THEN ' only get the path if path does not exist or user wants to use a new path
            savePath = _SELECTFOLDERDIALOG$("Select a folder to save the file:", savePath)
            IF savePath = _STR_EMPTY THEN EXIT SUB ' exit if user cancelled

            savePath = FixPathDirectoryName(savePath)
        END IF

        DIM saveFileName AS STRING: saveFileName = savePath + GetLegalFileNameFromURL(fileName)

        IF _FILEEXISTS(saveFileName) THEN
            IF _MESSAGEBOX(APP_NAME, "Overwrite " + saveFileName + "?", "yesno", "warning", 0) = 0 THEN EXIT SUB
        END IF

        _WRITEFILE saveFileName, buffer
        _MESSAGEBOX APP_NAME, saveFileName + " saved.", "info"

        ' Check if user want to use the same path in the future
        IF NOT stopNagging THEN
            SELECT CASE _MESSAGEBOX(APP_NAME, "Do you want to use " + savePath + " for future saves?", "yesnocancel", "question", 1)
                CASE 0
                    stopNagging = _TRUE
                CASE 1
                    alwaysUseSamePath = _TRUE
                CASE 2
                    alwaysUseSamePath = _FALSE
            END SELECT
        END IF
    ELSE
        ' This is a local file - do nothing
        _MESSAGEBOX APP_NAME, "You cannot save local file " + fileName + "!", "error"
    END IF
END SUB


' Generates a legal filename from a modarchive download URL
FUNCTION GetLegalFileNameFromURL$ (url AS STRING)
    DIM fileName AS STRING: fileName = GetFileNameFromPathOrURL(url)
    fileName = MID$(fileName, INSTR(fileName, "=") + 1) ' this will get a file name of type: 12312313#filename.mod

    DIM s AS STRING, c AS _UNSIGNED _BYTE

    ' Clean any unwanted characters
    DIM i AS LONG: FOR i = 1 TO LEN(fileName)
        c = ASC(fileName, i)
        SELECT CASE c
            CASE 92, 47, 42, 63, 124
                s = s + "_"
            CASE 58
                s = s + "-"
            CASE 60
                s = s + "{"
            CASE 62
                s = s + "}"
            CASE 34
                s = s + "'"
            CASE ELSE
                s = s + CHR$(c)
        END SELECT
    NEXT

    GetLegalFileNameFromURL = s
END FUNCTION


' Adds a trailing / to a directory name if needed
' TODO: This needs to be more platform specific (i.e. \ should not be checked on non-windows platforms)
FUNCTION FixPathDirectoryName$ (PathOrURL AS STRING)
    IF LEN(PathOrURL) > 0 _ANDALSO (ASC(PathOrURL, LEN(PathOrURL)) <> 47 _ORELSE ASC(PathOrURL, LEN(PathOrURL)) <> 92) THEN
        FixPathDirectoryName = PathOrURL + "/"
    ELSE
        FixPathDirectoryName = PathOrURL
    END IF
END FUNCTION


' Gets the filename portion from a file path
FUNCTION GetFileNameFromPathOrURL$ (pathName AS STRING)
    DIM j AS LONG: j = LEN(pathName)

    ' Retrieve the position of the first / or \ in the parameter from the
    DIM i AS LONG: FOR i = j TO 1 STEP -1
        IF ASC(pathName, i) = 47 _ORELSE ASC(pathName, i) = 92 THEN EXIT FOR
    NEXT

    ' Return the full string if pathsep was not found
    IF i = 0 THEN
        GetFileNameFromPathOrURL = pathName
    ELSE
        GetFileNameFromPathOrURL = RIGHT$(pathName, j - i)
    END IF
END FUNCTION


' Gets the drive or scheme from a path name (ex. C:, HTTPS: etc.)
FUNCTION GetDriveOrSchemeFromPathOrURL$ (PathOrURL AS STRING)
    DIM i AS LONG: i = INSTR(PathOrURL, ":")

    IF i <> 0 THEN
        GetDriveOrSchemeFromPathOrURL = LEFT$(PathOrURL, i)
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


' Load a file from a file or URL
FUNCTION LoadFile$ (PathOrURL AS STRING)
    IF LEN(GetDriveOrSchemeFromPathOrURL(PathOrURL)) > 2 THEN
        LoadFile = LoadFileFromURL(PathOrURL)
    ELSEIF _FILEEXISTS(PathOrURL) THEN
        LoadFile = _READFILE$(PathOrURL)
    END IF
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
    $CHECKING:OFF
    SELECT CASE style
        CASE 1
            BoolToStr = _IIF(expression, "On", "Off")
        CASE 2
            BoolToStr = _IIF(expression, "Enabled", "Disabled")
        CASE 3
            BoolToStr = _IIF(expression, "1", "0")
        CASE ELSE
            BoolToStr = _IIF(expression, "True", "False")
    END SELECT
    $CHECKING:ON
END FUNCTION


' Generates a random number between lo & hi
FUNCTION GetRandomValue& (lo AS LONG, hi AS LONG)
    $CHECKING:OFF
    GetRandomValue = lo + RND * (hi - lo)
    $CHECKING:ON
END FUNCTION


' @brief This function calculates the FFT for use in audio analyzers. All arrays passed must be zero based and power of 2 size.
' This was simplified and adapted from Vince's FFT code at https://qb64phoenix.com/forum/showthread.php?tid=270&pid=2005#pid2005
' @param realInput 16-bit multi-channel interleaved audio sample array.
' @param channel The index in realInput where we should begin (0 for the first channel, 1 for the second, etc.).
' @param channels The number of samples we should skip in realInput (1 for mono data, 2 for stereo, etc.).
' @param fftOutput [out] The output FFT array for positive frequencies only. First dimension is channel, and second is the FFT data.
' @return Audio intensity for the given channel.
FUNCTION AudioAnalyzer_FFT! (realInput() AS INTEGER, channel AS LONG, channels AS LONG, fftOutput( ,) AS SINGLE)
    DECLARE LIBRARY
        FUNCTION __AudioAnalyzer_CLZ& ALIAS "__builtin_clz" (BYVAL x AS _UNSIGNED LONG)
    END DECLARE

    $CHECKING:OFF
    STATIC AS SINGLE fft_real(0 TO 0), fft_imag(0 TO 0)
    STATIC rev_lookup(0 TO 0) AS LONG
    STATIC AS LONG half_n, log2n

    DIM AS SINGLE wr, wi, wmr, wmi, ur, ui, vr, vi, pi_m, intensity
    DIM AS LONG rev, i, j, k, m, p, q, n, half_m

    n = (UBOUND(realInput) + 1) \ channels
    IF n <> UBOUND(fft_real) + 1 THEN
        REDIM AS SINGLE fft_real(0 TO n - 1), fft_imag(0 TO n - 1)

        half_n = n \ 2

        REDIM rev_lookup(0 TO half_n - 1) AS LONG

        log2n = 30~& - __AudioAnalyzer_CLZ(n)

        i = 0
        DO WHILE i < half_n
            j = 0
            DO WHILE j < log2n
                IF i AND _SHL(1, j) THEN rev_lookup(i) = rev_lookup(i) + _SHL(1, (log2n - 1 - j))
                j = j + 1
            LOOP
            i = i + 1
        LOOP
    END IF

    i = 0
    DO WHILE i < half_n
        rev = rev_lookup(i)
        fft_real(i) = realInput(channel + rev * channels) * XMP_I16_TO_F32_MULTIPLIER!
        fft_imag(i) = 0!
        intensity = intensity + fft_real(i) * fft_real(i)
        i = i + 1
    LOOP
    AudioAnalyzer_FFT = intensity / half_n

    FOR i = 1 TO log2n
        m = _SHL(1, i)
        half_m = m \ 2
        pi_m = _PI(-2! / m)
        wmr = COS(pi_m)
        wmi = SIN(pi_m)

        j = 0
        DO WHILE j < half_n
            wr = 1!
            wi = 0!

            k = 0
            DO WHILE k < half_m
                p = j + k
                q = p + half_m

                ur = wr * fft_real(q) - wi * fft_imag(q)
                ui = wr * fft_imag(q) + wi * fft_real(q)
                vr = fft_real(p)
                vi = fft_imag(p)

                fft_real(p) = vr + ur
                fft_imag(p) = vi + ui
                fft_real(q) = vr - ur
                fft_imag(q) = vi - ui

                ur = wr
                wr = ur * wmr - wi * wmi
                wi = ur * wmi + wi * wmr

                k = k + 1
            LOOP
            j = j + m
        LOOP
    NEXT i

    i = 0
    DO WHILE i < half_n
        fftOutput(channel, i) = SQR(fft_real(i) * fft_real(i) + fft_imag(i) * fft_imag(i))

        i = i + 1
    LOOP
    $CHECKING:ON
END FUNCTION


SUB DrawFilledCircle (cx AS LONG, cy AS LONG, r AS LONG, c AS _UNSIGNED LONG)
    $CHECKING:OFF

    IF r <= 0 THEN
        PSET (cx, cy), c
        EXIT SUB
    END IF

    DIM e AS LONG: e = -r
    DIM x AS LONG: x = r
    DIM y AS LONG

    LINE (cx - x, cy)-(cx + x, cy), c, BF

    DO WHILE x > y
        e = e + y * 2 + 1

        IF e >= 0 THEN
            IF x <> y + 1 THEN
                LINE (cx - y, cy - x)-(cx + y, cy - x), c, BF
                LINE (cx - y, cy + x)-(cx + y, cy + x), c, BF
            END IF

            x = x - 1
            e = e - x * 2
        END IF

        y = y + 1

        LINE (cx - x, cy - y)-(cx + x, cy - y), c, BF
        LINE (cx - x, cy + y)-(cx + x, cy + y), c, BF
    LOOP

    $CHECKING:ON
END SUB


SUB InitializeStars (stars() AS StarType)
    DIM L AS LONG: L = LBOUND(stars)
    DIM U AS LONG: U = UBOUND(stars)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = L TO U
        stars(i).p.x = GetRandomValue(0, W - 1)
        stars(i).p.y = GetRandomValue(0, H - 1)
        stars(i).p.z = 4096!
        stars(i).c = _RGBA32(GetRandomValue(64, 255), GetRandomValue(64, 255), GetRandomValue(64, 255), 255)
    NEXT
END SUB


SUB UpdateAndDrawStars (stars() AS StarType, speed AS SINGLE)
    CONST Z_DIVIDER = 4096!

    DIM L AS LONG: L = LBOUND(stars)
    DIM U AS LONG: U = UBOUND(stars)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT
    DIM W_Half AS LONG: W_Half = W \ 2
    DIM H_Half AS LONG: H_Half = H \ 2

    DIM i AS LONG: FOR i = L TO U
        IF stars(i).p.x < 0 _ORELSE stars(i).p.x >= W _ORELSE stars(i).p.y < 0 _ORELSE stars(i).p.y >= H THEN
            stars(i).p.x = GetRandomValue(0, W - 1)
            stars(i).p.y = GetRandomValue(0, H - 1)
            stars(i).p.z = Z_DIVIDER
            stars(i).c = _RGBA32(GetRandomValue(64, 255), GetRandomValue(64, 255), GetRandomValue(64, 255), 255)
        END IF

        PSET (stars(i).p.x, stars(i).p.y), stars(i).c

        stars(i).p.z = stars(i).p.z + speed
        stars(i).a = stars(i).a + 0.01!
        DIM zd AS SINGLE: zd = stars(i).p.z / Z_DIVIDER
        stars(i).p.x = ((stars(i).p.x - W_Half) * zd) + W_Half + COS(stars(i).a * 0.5!)
        stars(i).p.y = ((stars(i).p.y - H_Half) * zd) + H_Half + SIN(stars(i).a * 1.5!)
    NEXT
END SUB


SUB InitializeCircleWaves (circleWaves() AS CircleWaveType)
    DIM L AS LONG: L = LBOUND(circleWaves)
    DIM U AS LONG: U = UBOUND(circleWaves)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = L TO U
        circleWaves(i).a = 0!
        circleWaves(i).r = GetRandomValue(10, 40)
        circleWaves(i).p.x = GetRandomValue(circleWaves(i).r, W - circleWaves(i).r)
        circleWaves(i).p.y = GetRandomValue(circleWaves(i).r, H - circleWaves(i).r)
        circleWaves(i).v.x = (RND - RND) / 3!
        circleWaves(i).v.y = (RND - RND) / 3!
        circleWaves(i).s = GetRandomValue(1, 100) / 4000!
        circleWaves(i).c.r = GetRandomValue(0, 128)
        circleWaves(i).c.g = GetRandomValue(0, 128)
        circleWaves(i).c.b = GetRandomValue(0, 128)
    NEXT
END SUB


SUB UpdateAndDrawCircleWaves (circleWaves() AS CircleWaveType, size AS SINGLE)
    DIM L AS LONG: L = LBOUND(circleWaves)
    DIM U AS LONG: U = UBOUND(circleWaves)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = U TO L STEP -1
        circleWaves(i).a = circleWaves(i).a + circleWaves(i).s
        circleWaves(i).r = circleWaves(i).r + circleWaves(i).s * 10!
        circleWaves(i).p.x = circleWaves(i).p.x + circleWaves(i).v.x
        circleWaves(i).p.y = circleWaves(i).p.y + circleWaves(i).v.y

        IF circleWaves(i).a >= 1 THEN circleWaves(i).s = circleWaves(i).s * -1!

        IF circleWaves(i).a <= 0 THEN
            circleWaves(i).a = 0!
            circleWaves(i).r = GetRandomValue(10, 40)
            circleWaves(i).p.x = GetRandomValue(circleWaves(i).r, W - circleWaves(i).r)
            circleWaves(i).p.y = GetRandomValue(circleWaves(i).r, H - circleWaves(i).r)
            circleWaves(i).v.x = (RND - RND) / 3!
            circleWaves(i).v.y = (RND - RND) / 3!
            circleWaves(i).s = GetRandomValue(1, 100) / 4000!
            circleWaves(i).c.r = GetRandomValue(0, 128)
            circleWaves(i).c.g = GetRandomValue(0, 128)
            circleWaves(i).c.b = GetRandomValue(0, 128)
        END IF

        DrawFilledCircle circleWaves(i).p.x, circleWaves(i).p.y, circleWaves(i).r + circleWaves(i).r * size, _RGBA32(circleWaves(i).c.r, circleWaves(i).c.g, circleWaves(i).c.b, 255! * circleWaves(i).a)
    NEXT
END SUB
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
