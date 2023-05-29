'-----------------------------------------------------------------------------------------------------------------------
' Libxmp bindings for QB64-PE (minimalistic)
' Copyright (c) 2023 Samuel Gomes
'
' Most of the stuff here is from https://github.com/libxmp/libxmp/blob/master/include/xmp.h
'-----------------------------------------------------------------------------------------------------------------------

$If LIBXMP64_BI = UNDEFINED Then
    $Let LIBXMP64_BI = TRUE
    '-------------------------------------------------------------------------------------------------------------------
    ' CONSTANTS
    '-------------------------------------------------------------------------------------------------------------------
    Const XMP_NAME_SIZE = 64 ' size of module name and type

    Const XMP_PLAYER_INTERP = 2 ' interpolation type
    Const XMP_PLAYER_DSP = 3 ' DSP effect flags
    Const XMP_PLAYER_VOLUME = 7 ' player module volume

    Const XMP_MAX_CHANNELS = 64 ' max number of channels in module

    Const XMP_INTERP_SPLINE = 2 ' cubic spline

    Const XMP_DSP_LOWPASS = 1 ' lowpass filter effect
    Const XMP_DSP_ALL = XMP_DSP_LOWPASS

    Const XMP_VOLUME_MAX = 100 ' max volume in percentage

    ' Helper constants. These must be in sync with the types below
    Const XMP_CHANNEL_INFO_SIZE = 24 ' size of xmp_channel_info type
    Const XMP_CHANNEL_INFO_ARRAY_SIZE = XMP_CHANNEL_INFO_SIZE * XMP_MAX_CHANNELS

    Const XMP_SOUND_BUFFER_CHANNELS = 2 ' 2 channel (stereo)
    Const XMP_SOUND_BUFFER_SAMPLE_SIZE = 2 ' 2 bytes (16-bits signed integer)
    Const XMP_SOUND_BUFFER_FRAME_SIZE = XMP_SOUND_BUFFER_SAMPLE_SIZE * XMP_SOUND_BUFFER_CHANNELS
    Const XMP_SOUND_BUFFER_TIME_DEFAULT = 0.2 ' we will check that we have this amount of time left in the QB64 sound pipe
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' USER DEFINED TYPES
    '-------------------------------------------------------------------------------------------------------------------
    ' Info type used with xmp_test_module()
    Type xmp_test_info
        mod_name As String * Xmp_name_size ' module title
        mod_type As String * Xmp_name_size ' module format
    End Type

    Type xmp_event
        note As _Unsigned _Byte ' note number (0 means no note)
        ins As _Unsigned _Byte ' patch number
        vol As _Unsigned _Byte ' volume (0 to basevol)
        fxt As _Unsigned _Byte ' effect type
        fxp As _Unsigned _Byte ' effect parameter
        f2t As _Unsigned _Byte ' secondary effect type
        f2p As _Unsigned _Byte ' secondary effect parameter
        flag As _Unsigned _Byte ' internal (reserved) flags
    End Type

    Type xmp_channel_info
        period As _Unsigned Long ' sample period (* 4096)
        position As _Unsigned Long ' sample position
        pitchbend As Integer ' linear bend from base note
        note As _Unsigned _Byte ' current base note number
        instrument As _Unsigned _Byte ' current instrument number
        sample As _Unsigned _Byte ' current sample number
        volume As _Unsigned _Byte ' current volume
        pan As _Unsigned _Byte ' current stereo pan
        reserved As _Unsigned _Byte ' reserved
        event As xmp_event ' current track event
    End Type

    ' Info type used with xmp_get_frame_info()
    Type xmp_frame_info
        position As Long ' current position
        pattern As Long ' current pattern
        row As Long ' current row in pattern
        num_rows As Long ' number of rows in current pattern
        frame As Long ' current frame
        speed As Long ' current replay speed
        bpm As Long ' current bpm
        time As Long ' current module time in ms
        total_time As Long ' estimated replay time in ms*/
        frame_time As Long ' frame replay time in us
        buffer As _Offset ' pointer to sound buffer
        buffer_size As Long ' used buffer size
        total_size As Long ' total buffer size
        volume As Long ' current master volume
        loop_count As Long ' loop counter
        virt_channels As Long ' number of virtual channels
        virt_used As Long ' used virtual channels
        sequence As Long ' current sequence
        channel_info As String * Xmp_channel_info_array_size ' current channel information
    End Type

    ' QB64 specific stuff
    Type __XMPPlayerType
        context As _Offset ' this is a libxmp context
        isPlaying As _Byte ' set to true if tune is playing
        isPaused As _Byte ' set to true if tune is paused
        isLooping As _Byte ' set to true if tune is looping
        frameInfo As xmp_frame_info ' current frame info. This is used to check if we are looping or playback is done
        testInfo As xmp_test_info ' this will have the MOD name and type
        errorCode As Long ' this hold the error code from a previous XMP function
        soundBuffer As _MEM ' this is the buffer that holds the rendered samples from libxmp
        soundBufferBytes As _Unsigned Long ' size of the render buffer in bytes
        soundBufferFrames As _Unsigned Long ' size of the render buffer in frames
        soundHandle As Long ' the sound pipe that we wll use to play the rendered samples
    End Type
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' EXTERNAL LIBRARIES
    '-------------------------------------------------------------------------------------------------------------------
    ' HELP NEEDED: macOS support is trivial but missing becuase I do not own an Apple system to compile a Libxmp .dylib
    $If WINDOWS Then
        $If 32BIT Then
                DECLARE DYNAMIC LIBRARY "./libxmp32"
        $Else
            Declare Dynamic Library "./libxmp64"
            $End If
        $ElseIf LINUX Then
            $If 32BIT Then
                $ERROR 32-bit Linux not supported
                DECLARE DYNAMIC LIBRARY "./xmp32"
            $Else
                DECLARE DYNAMIC LIBRARY "./xmp64" ' QB64 removes the 'lib' prefix on Linux
            $End If
        $ElseIf MACOSX Then
            $If 32BIT Then
                $ERROR 32-bit macOS not supported
                DECLARE DYNAMIC LIBRARY "./xmp32"
            $Else
                $ERROR 64-bit macOS not supported yet
                DECLARE DYNAMIC LIBRARY "./xmp64"
            $End If
        $Else
            $ERROR Unknown platform
            DECLARE DYNAMIC LIBRARY "./xmp"
        $End If
        Function xmp_create_context%&
        Sub xmp_free_context (ByVal context As _Offset)
        Function xmp_test_module& (path As String, test_info As xmp_test_info)
        Function xmp_test_module_from_memory& (buffer As String, Byval size As _Unsigned Long, test_info As xmp_test_info)
        Function xmp_load_module& (ByVal context As _Offset, path As String)
        Function xmp_load_module_from_memory& (ByVal context As _Offset, buffer As String, Byval size As _Unsigned Long)
        Sub xmp_release_module (ByVal context As _Offset)
        Function xmp_start_player& (ByVal context As _Offset, Byval rate As Long, Byval format As Long)
        Sub xmp_end_player (ByVal context As _Offset)
        Function xmp_play_buffer& (ByVal context As _Offset, Byval buffer As _Offset, Byval size As Long, Byval loops As Long)
        Sub xmp_get_frame_info (ByVal context As _Offset, frame_info As xmp_frame_info)
        Function xmp_get_player& (ByVal context As _Offset, Byval param As Long)
        Function xmp_set_player& (ByVal context As _Offset, Byval param As Long, Byval value As Long)
        Function xmp_next_position& (ByVal context As _Offset)
        Function xmp_prev_position& (ByVal context As _Offset)
        Function xmp_set_position& (ByVal context As _Offset, Byval posi As Long)
        Sub xmp_restart_module (ByVal context As _Offset)
        Function xmp_seek_time& (ByVal context As _Offset, Byval msecs As Long)
    End Declare
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    ' GLOBAL VARIABLES
    '-------------------------------------------------------------------------------------------------------------------
    Dim __XMPPlayer As __XMPPlayerType
    '-------------------------------------------------------------------------------------------------------------------
$End If
'-----------------------------------------------------------------------------------------------------------------------
